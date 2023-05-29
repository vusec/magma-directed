#!/bin/bash -e

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
# - env TARGET: path to target work dir
# - env OUT: path to directory where artifacts are stored
# - env SHARED: path to directory shared with host (to store results)
# - env PROGRAM: name of program to run (should be found in $OUT)
# - env ARGS: extra arguments to pass to the program
# - env FUZZARGS: extra arguments to pass to the fuzzer
##

source "$MAGMA/sanitizers.sh"
address_sanitizer_options[detect_leaks]=0
set_sanitizer_options 1
echo "\
+ ASAN_OPTIONS=$ASAN_OPTIONS
+ UBSAN_OPTIONS=$UBSAN_OPTIONS" >&2
set -x

mkdir -p "$SHARED"/findings/{crashes,queue}

"$OUT/$PROGRAM" \
    -detect_leaks=0 \
    -print_final_stats=1 -close_fd_mask=3 \
    -fork=1 -ignore_timeouts=1 -ignore_crashes=1 -ignore_ooms=1 \
    -artifact_prefix="$SHARED/findings/crashes/" $FUZZARGS \
    "$SHARED/findings/queue/" "$TARGET/corpus/$PROGRAM"
