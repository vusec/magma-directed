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

AFLGO_FUZZER=dafl

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

# because of no targets when compiling units w/o targets or when running
# compiler checks in stuff like ./configure, cmake, etc.
export AFLGO_SKIP_TARGETS_CHECK=1

SANITIZERS="-fsanitize=address -mllvm -asan-stack=0"
export CFLAGS="$CFLAGS $SANITIZERS"
export CXXFLAGS="$CXXFLAGS $SANITIZERS"

export LIB_FUZZING_ENGINE="$OUT/stub_rt.a"

remove_flags() {
    local flag
    FLAGS=()
    for flag in "$@"; do
        if [ "$flag" != -O0 ]; then
            FLAGS+=("$flag")
        fi
    done
}

# build w/ optimizations and compute DAFL scores
rm -rf "$OUT/dafl"
mkdir -p "$OUT/dafl"
DAFL_OUTPUT="$OUT/dafl/scores.csv"
# XXX: required to stop ./configure, cmake, etc. complaining about missing file
touch "$DAFL_OUTPUT"
(
    export AFLGO_DAFL_OUTPUT="$DAFL_OUTPUT"

    ADDFLAGS="-O3 -fno-inline-functions"
    # shellcheck disable=SC2086
    remove_flags $CFLAGS
    export CFLAGS="${FLAGS[*]} $ADDFLAGS"
    # shellcheck disable=SC2086
    remove_flags $CXXFLAGS
    export CXXFLAGS="${FLAGS[*]} $ADDFLAGS"

    "$TARGET/build.sh"
)

printf "\n\n\n##############\n\n\n" >&2

# build normally and use scores
(
    export AFLGO_DAFL_INPUT="$DAFL_OUTPUT"
    "$TARGET/build.sh"
)
