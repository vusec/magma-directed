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

if [ ! -f "$MAGMA_BUG_FILE" ]; then
    printf >&2 "MAGMA_BUG_FILE=%q is not a file\n" "$MAGMA_BUG_FILE"
    exit 1
fi

export AFLGO_TARGETS="$OUT/aflgo_targets.txt"
"$MAGMA"/showlinenum.awk path=1 show_header=0 <"$MAGMA_BUG_FILE" \
    | gawk -F':' '$1 ~ /\.(c|cc|cpp|h|hpp)$/ && $3 ~ /^\+/ {print $1 ":" $2}' >"$AFLGO_TARGETS"

export AFLGO_CLANG=clang-16

"$MAGMA/build.sh"
export CC=libaflgo_cc
export CXX=libaflgo_cxx
"$TARGET/build.sh"

# NOTE: We pass $OUT directly to the target build.sh script, since the artifact
#       itself is the fuzz target. In the case of Angora, we might need to
#       replace $OUT by $OUT/fast and $OUT/track, for instance.
