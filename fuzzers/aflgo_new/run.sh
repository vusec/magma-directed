#!/bin/bash -ex

##
# Pre-requirements:
# - env TARGET: path to target work dir
# - env OUT: path to directory where artifacts are stored
# - env SHARED: path to directory shared with host (to store results)
# - env PROGRAM: name of program to run (should be found in $OUT)
# - env ARGS: extra arguments to pass to the program
# - env FUZZARGS: extra arguments to pass to the fuzzer
##

mkdir -p "$SHARED/findings"

"$OUT/$PROGRAM" \
    --input "$TARGET/corpus/$PROGRAM" \
    --output "$SHARED/findings" \
    $FUZZARGS $ARGS
