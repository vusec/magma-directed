# shellcheck shell=bash

##
# Pre-requirements:
# - env AFLGO_FUZZER: name of the libaflgo fuzzer
# - env FUZZER: path to fuzzer work dir
# - env TARGET: path to target work dir
# - env MAGMA: path to Magma support files
# - env OUT: path to directory where artifacts are stored
# - env CFLAGS and CXXFLAGS must be set to link against Magma instrumentation
# - env MAGMA_BUG_FILE: bug to target
##

if [ -z "$AFLGO_FUZZER" ]; then
    printf >&2 "AFLGO_FUZZER is not set\n"
    exit 1
fi

export AFLGO_TARGETS="$OUT/aflgo_targets.txt"
# shellcheck source=magma/directed.sh
source "$MAGMA/directed.sh"
store_target_lines "$AFLGO_TARGETS"

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
