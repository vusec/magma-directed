#!/bin/bash
set -e

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
# - env TARGET: path to target work dir
# - env MAGMA: path to Magma support files
# - env OUT: path to directory where artifacts are stored
# - env CFLAGS and CXXFLAGS must be set to link against Magma instrumentation
# - env MAGMA_BUG_FILE: bug to target
##

AFLGO_FUZZER=aflgo

export AFLGO_TARGETS="$OUT/aflgo_targets.txt"
# shellcheck source=magma/directed.sh
source "$MAGMA/directed.sh"
MAGMA_LOG_LINES="$OUT/magma_log_lines.txt"
store_magma_log_lines "$MAGMA_LOG_LINES"
make_magma_log_lines_unique "$MAGMA_LOG_LINES" >"$AFLGO_TARGETS"
printf "\n\n################\nFound %d targets\n" "$(wc -l <"$AFLGO_TARGETS")" >&2
cat "$AFLGO_TARGETS" >&2
printf "################\n\n" >&2
check_unique_targets "$AFLGO_TARGETS"

"$MAGMA/build.sh"

export SVF_DIR="$FUZZER/svf"
export AFLGO_CLANG=clang-15
export CC="libaflgo_${AFLGO_FUZZER}_cc"
export CXX="libaflgo_${AFLGO_FUZZER}_cxx"

SANITIZERS="-fsanitize=address"
export CFLAGS="$CFLAGS $SANITIZERS"
export CXXFLAGS="$CXXFLAGS $SANITIZERS"

export LIB_FUZZING_ENGINE="$OUT/stub_rt.a"

"$TARGET/build.sh"
