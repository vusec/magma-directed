#!/usr/bin/env python3
import argparse
from pathlib import Path

MAGMA = Path(__file__).resolve().parent.parent
FUZZERS = MAGMA / "fuzzers"


def cli() -> dict:
    parser = argparse.ArgumentParser(
        description="Find duplicate files in other fuzzers"
    )
    parser.add_argument("file", type=Path)
    return vars(parser.parse_args())


def main(file: Path) -> int:
    file_rel_fuzzers = file.resolve().relative_to(FUZZERS)
    fuzzer_og = file_rel_fuzzers.parts[0]
    file_path = file_rel_fuzzers.relative_to(fuzzer_og)
    contents = file.read_text()
    for fuzzer in FUZZERS.iterdir():
        if fuzzer.name == fuzzer_og:
            continue

        other_file = fuzzer / file_path
        if not other_file.is_file():
            continue

        if contents == other_file.read_text():
            print(fuzzer.name)

    return 0


if __name__ == "__main__":
    exit(main(**cli()))
