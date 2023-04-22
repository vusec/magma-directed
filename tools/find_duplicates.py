#!/usr/bin/env python3
import argparse
from pathlib import Path

MAGMA = Path(__file__).resolve().parent.parent


def cli() -> dict:
    parser = argparse.ArgumentParser(
        description="Find duplicate files in other fuzzers"
    )
    parser.add_argument("file", type=Path)
    return vars(parser.parse_args())


def main(file: Path) -> int:
    contents = file.read_text()
    for fuzzer in (MAGMA / "fuzzers").iterdir():
        if fuzzer.name == file.parent.name:
            continue

        other_file = fuzzer / file.name
        if not other_file.is_file():
            continue

        if contents == other_file.read_text():
            print(fuzzer.name)

    return 0


if __name__ == "__main__":
    exit(main(**cli()))
