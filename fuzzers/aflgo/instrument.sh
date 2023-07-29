#!/bin/bash
set -ex

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
# - env TARGET: path to target work dir
# - env MAGMA: path to Magma support files
# - env OUT: path to directory where artifacts are stored
# - env CFLAGS and CXXFLAGS must be set to link against Magma instrumentation
##

source "$MAGMA/directed.sh"
AFLGO_TMP="$OUT/aflgo_tmp"
mkdir -p "$AFLGO_TMP"
AFLGO_TARGETS="$AFLGO_TMP/BBtargets.txt"
store_target_lines "$AFLGO_TARGETS"

"$MAGMA/build.sh"

LLVM_VERSION=11
export AFL_CC=clang-$LLVM_VERSION
export AFL_CXX=clang++-$LLVM_VERSION
export CC="$FUZZER/repo/afl-clang-fast"
export CXX="$FUZZER/repo/afl-clang-fast++"
export LIBS="$LIBS -l:afl_driver.o -lstdc++"
SANITIZER_FLAGS="-fsanitize=address"
CFLAGS_COPY="$CFLAGS $SANITIZER_FLAGS"
CXXFLAGS_COPY="$CXXFLAGS $SANITIZER_FLAGS"

# get call graph, CFG
ADDITIONAL="-targets=$AFLGO_TARGETS -outdir=$AFLGO_TMP -flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"
export CFLAGS="$CFLAGS_COPY $ADDITIONAL"
export CXXFLAGS="$CXXFLAGS_COPY $ADDITIONAL"
REQUIRE_COPY_BITCODE=1 "$TARGET/build.sh"

# clean up
cat "$AFLGO_TMP/BBnames.txt" | grep -v '^$' | rev | cut -d: -f2- | rev | sort | uniq >"$AFLGO_TMP/BBnames2.txt"
mv "$AFLGO_TMP/BBnames2.txt" "$AFLGO_TMP/BBnames.txt"
cat "$AFLGO_TMP/BBcalls.txt" | grep -Ev '^[^,]*$|^([^,]*,){2,}[^,]*$' | sort | uniq >"$AFLGO_TMP/BBcalls2.txt"
mv "$AFLGO_TMP/BBcalls2.txt" "$AFLGO_TMP/BBcalls.txt"

# generate distance
PATH="$(llvm-config-$LLVM_VERSION --bindir):$PATH" \
    "$FUZZER/repo/scripts/gen_distance_fast.py" "$OUT" "$AFLGO_TMP"

head -n5 "$AFLGO_TMP/distance.cfg.txt"
echo "..."
tail -n5 "$AFLGO_TMP/distance.cfg.txt"

# instrument target
export CFLAGS="$CFLAGS_COPY -distance=$AFLGO_TMP/distance.cfg.txt"
export CXXFLAGS="$CXXFLAGS_COPY -distance=$AFLGO_TMP/distance.cfg.txt"
"$TARGET/build.sh"
