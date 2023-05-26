#!/bin/bash -ex

##
# Pre-requirements:
# - env TARGET: path to target work dir
# - env OUT: path to directory where artifacts are stored
# - env SHARED: path to directory shared with host (to store results)
# - env PROGRAM: name of program to run (should be found in $OUT)
# - env FUZZARGS: extra arguments to pass to the fuzzer
##

mkdir -p "$SHARED/findings"

export ASAN_OPTIONS="\
abort_on_error=1:detect_leaks=0:\
malloc_context_size=0:symbolize=0:\
allocator_may_return_null=1:\
detect_odr_violation=0:handle_segv=0:\
handle_sigbus=0:handle_abort=0:\
handle_sigfpe=0:handle_sigill=0"

"$OUT/$PROGRAM" \
    -i "$TARGET/corpus/$PROGRAM" \
    -o "$SHARED/findings" \
    $FUZZARGS
