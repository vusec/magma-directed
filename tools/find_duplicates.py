#!/usr/bin/env python3
import argparse
import os
from pathlib import Path

MAGMA = Path(__file__).resolve().parent.parent
FUZZERS = MAGMA / "fuzzers"


def cli() -> dict:
    parser = argparse.ArgumentParser(
        description="Find duplicate files in other fuzzers"
    )
    parser.add_argument(
        "-s",
        "--same-name",
        action="store_true",
        default=False,
        help="Search duplicated with same filename",
    )
    parser.add_argument("file", type=Path)
    return vars(parser.parse_args())


def main(file: Path, same_name: bool) -> int:
    file_rel_fuzzers = file.resolve().relative_to(FUZZERS)
    fuzzer_og = file_rel_fuzzers.parts[0]
    contents = file.read_bytes()
    file_path = file_rel_fuzzers.relative_to(fuzzer_og)

    for fuzzer in FUZZERS.iterdir():
        if fuzzer.name == fuzzer_og:
            continue

        if same_name:
            other_file = fuzzer / file_path
            if not other_file.is_file():
                continue

            if contents == other_file.read_bytes():
                print(fuzzer.name)

        else:
            for dir, _, files in os.walk(fuzzer):
                for other_file in files:
                    other_file = Path(dir) / other_file
                    if other_file.is_file() and contents == other_file.read_bytes():
                        print(f"{fuzzer.name:32s} {other_file.relative_to(fuzzer)}")

    return 0


if __name__ == "__main__":
    exit(main(**cli()))
