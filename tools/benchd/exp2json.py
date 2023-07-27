#!/usr/bin/env python3

import argparse
from collections import defaultdict, namedtuple
import csv
import errno
import json
import logging
from multiprocessing import Pool
import os
import shutil
import subprocess
import sys
from tempfile import mkdtemp

import pandas as pd

ddr = lambda: defaultdict(ddr)


def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "Collects data from the experiment workdir and outputs a summary as "
            "a JSON file."
        )
    )
    parser.add_argument(
        "--workers", default=4, help="The number of concurrent processes to launch."
    )
    parser.add_argument("workdir", help="The path to the Captain tool output workdir.")
    parser.add_argument(
        "outfile",
        default="-",
        help="The file to which the output will be written, or - for stdout.",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="count",
        default=0,
        help=(
            "Controls the verbosity of messages. "
            "-v prints info. -vv prints debug. Default: warnings and higher."
        ),
    )
    return parser.parse_args()


Campaign = namedtuple("Campaign", ["path", "fuzzer", "target", "program", "run", "bug"])


def find_campaigns(workdir):
    ar_dir = os.path.join(workdir, "ar")
    for fuzzer in os.listdir(ar_dir):
        fuzzer_dir = os.path.join(ar_dir, fuzzer)
        for target in os.listdir(fuzzer_dir):
            target_dir = os.path.join(fuzzer_dir, target)
            # subfolders of fuzzer/target can be programs (undirected) or bugs (directed)
            for program_or_bug in os.listdir(target_dir):
                program_or_bug_dir = os.path.join(target_dir, program_or_bug)
                runs_or_programs = os.listdir(program_or_bug_dir)
                # if fuzzer/target/program_or_bug/* contains only numbers,
                # then it's undirected and program_or_bug is a program
                if all(run_or_program.isdigit() for run_or_program in runs_or_programs):
                    # undirected fuzzer, these are runs
                    for run in runs_or_programs:
                        yield Campaign(
                            os.path.join(program_or_bug_dir, run),
                            fuzzer,
                            target,
                            program_or_bug,
                            run,
                            None,
                        )
                    continue
                # directed fuzzer, these are bugs
                for program in runs_or_programs:
                    program_dir = os.path.join(program_or_bug_dir, program)
                    runs = os.listdir(program_dir)
                    if all(run.isdigit() for run in runs):
                        for run in runs:
                            yield Campaign(
                                os.path.join(program_dir, run),
                                fuzzer,
                                target,
                                program,
                                run,
                                program_or_bug,
                            )


def ensure_dir(path):
    try:
        os.makedirs(path)
    except OSError as e:
        if e.errno != errno.EEXIST:
            raise


def clear_dir(path):
    for filename in os.listdir(path):
        file_path = os.path.join(path, filename)
        try:
            if os.path.isfile(file_path) or os.path.islink(file_path):
                os.unlink(file_path)
            elif os.path.isdir(file_path):
                shutil.rmtree(file_path)
        except Exception as e:
            logging.exception("Failed to delete %s. Reason: %s", file_path, e)


def extract_monitor_dumps(tarball, dest):
    clear_dir(dest)
    # get the path to the monitor dir inside the tarball
    monitor = subprocess.check_output(
        f'tar -tf "{tarball}" | grep -Po ".*monitor" | uniq', shell=True
    )
    monitor = monitor.decode().rstrip()
    # strip all path components until and excluding the monitor dir
    ccount = len(monitor.split("/")) - 1
    os.system(f'tar -xf "{tarball}" --strip-components={ccount} -C "{dest}" {monitor}')


def generate_monitor_df(workdir, campaign, dumpdir):
    def row_generator():
        files = os.listdir(dumpdir)
        if "tmp" in files:
            files.remove("tmp")
        files.sort(key=int)
        for timestamp in files:
            fname = os.path.join(dumpdir, timestamp)
            try:
                with open(fname, newline="") as csvfile:
                    reader = csv.DictReader(csvfile)
                    row = next(reader)
                    row["TIME"] = timestamp
                    yield row
            except StopIteration:
                logging.debug("Truncated monitor file contains no rows!")
                continue

    # use a list in case pd.DataFrame() can pre-allocate ahead of time
    rows = list(row_generator())
    if len(rows) == 0:
        name = f"{campaign.fuzzer}/{campaign.target}"
        if campaign.bug is not None:
            name += "/" + campaign.bug
        name += f"/{campaign.program}/{campaign.run}"
        logfile = os.path.join(
            workdir, "log", f"{name.replace('/', '_')}_container.log"
        )
        logging.warning(
            "%s contains no monitor logs. Check the corresponding campaign "
            "log file for more information: %s",
            name,
            logfile,
        )

    df = pd.DataFrame(rows)
    df.set_index("TIME", inplace=True)
    df.fillna(0, inplace=True)
    df = df.astype(int)
    del rows
    return df


def process_one_campaign(workdir, campaign):
    logging.info("Processing %s", campaign.path)

    tarball = os.path.join(campaign.path, "ball.tar")
    istarball = False
    if os.path.isfile(tarball):
        istarball = True
        dumpdir = mkdtemp(dir=tmpdir)
        logging.debug("Campaign is tarballed. Extracting to %s", dumpdir)
        extract_monitor_dumps(tarball, dumpdir)
    else:
        dumpdir = campaign.path

    df = None
    try:
        df = generate_monitor_df(workdir, campaign, os.path.join(dumpdir, "monitor"))
    except Exception as ex:
        logging.exception(
            "Encountered exception when processing %s. Details: " "%s",
            campaign.path,
            ex,
        )
    finally:
        if istarball:
            clear_dir(dumpdir)
            os.rmdir(dumpdir)
    return campaign, df


def collect_experiment_data(workdir, workers):
    def init(*args):
        global tmpdir
        (tmpdir,) = tuple(args)

    experiment = {}
    tmpdir = os.path.join(workdir, "tmp")
    ensure_dir(tmpdir)

    with Pool(processes=workers, initializer=init, initargs=(tmpdir,)) as pool:
        results = pool.starmap(
            process_one_campaign, ((workdir, c) for c in find_campaigns(workdir))
        )
        for c, df in results:
            if df is not None:
                experiment[c] = df
            else:
                # TODO add an empty df so that the run is accounted for
                logging.warning("%s has been omitted!", c.path)
    return experiment


def get_ttb_from_df(df):
    reached = {}
    triggered = {}

    bugs = set(x[:-2] for x in df.columns)
    logging.debug("Bugs found: %s", bugs)
    for bug in bugs:
        R = df[df[f"{bug}_R"] > 0]
        if not R.empty:
            reached[bug] = int(R.index[0])
        T = df[df[f"{bug}_T"] > 0]
        if not T.empty:
            triggered[bug] = int(T.index[0])
    return reached, triggered


def default_to_regular(d):
    if isinstance(d, defaultdict):
        d = {k: default_to_regular(v) for k, v in d.items()}
    return d


def get_experiment_summary(experiment):
    summary = ddr()
    for c, df in experiment.items():
        reached, triggered = get_ttb_from_df(df)
        if c.bug is None:
            summary[c.fuzzer][c.target][c.program][c.run] = {
                "reached": reached,
                "triggered": triggered,
            }
        else:
            summary[c.fuzzer][c.target][c.bug][c.program][c.run] = {
                "reached": reached,
                "triggered": triggered,
            }
    return default_to_regular(summary)


def configure_verbosity(level):
    mapping = {0: logging.WARNING, 1: logging.INFO, 2: logging.DEBUG}
    # will raise exception when level is invalid
    numeric_level = mapping[level]
    logging.basicConfig(level=numeric_level)


def main():
    args = parse_args()
    configure_verbosity(args.verbose)
    experiment = collect_experiment_data(args.workdir, int(args.workers))
    summary = get_experiment_summary(experiment)

    output = {
        "results": summary,
        # TODO add configuration options and other experiment parameters
    }

    data = json.dumps(output).encode()
    if args.outfile == "-":
        sys.stdout.buffer.write(data)
    else:
        with open(args.outfile, "wb") as f:
            f.write(data)


if __name__ == "__main__":
    main()
