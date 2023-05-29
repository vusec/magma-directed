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

if [ ! -f "$MAGMA_BUG_FILE" ]; then
    printf >&2 "MAGMA_BUG_FILE=%q is not a file\n" "$MAGMA_BUG_FILE"
    exit 1
fi

export AFLGO_TARGETS="$OUT/aflgo_targets.txt"
"$MAGMA"/showlinenum.awk path=1 show_header=0 <"$MAGMA_BUG_FILE" \
    | gawk -F':' -v repo_path="$TARGET/repo/" \
        'BEGIN { cmd_base = "readlink -f " repo_path }
        $1 ~ /\.(c|cc|cpp|h|hpp)$/ && $3 ~ /^\+/ {
            cmd = cmd_base $1; cmd | getline path;
            print path ":" $2
        }' >"$AFLGO_TARGETS"

if [ "$(wc -l <"$AFLGO_TARGETS")" -lt 1 ]; then
    printf >&2 "No targets found in %q\n" "$MAGMA_BUG_FILE"
    exit 1
fi

"$MAGMA/build.sh"

export AFLGO_CLANG=clang-15
export CC="libaflgo_${AFLGO_FUZZER}_cc"
export CXX="libaflgo_${AFLGO_FUZZER}_cxx"

SANITIZERS="-fsanitize=address"
export CFLAGS="$CFLAGS $SANITIZERS"
export CXXFLAGS="$CXXFLAGS $SANITIZERS"

export LIB_FUZZING_ENGINE="$OUT/stub_rt.a"

"$TARGET/build.sh"
