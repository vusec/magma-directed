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

THIRD_PARTY="$FUZZER/repo/third_party"

# make bitcode
SVF_BIN="$THIRD_PARTY/SVF/Release-build/bin"
export CC="$SVF_BIN/gclang"
export CXX="$SVF_BIN/gclang++"
export LIBS="$LIBS -l:driver.o -lstdc++"
$CXX $CXXFLAGS -c "$FUZZER/src/driver.cpp" -fPIC -o "$OUT/driver.o"
"$MAGMA/build.sh"
CFLAGS="$CFLAGS -fsanitize=address" \
CXXFLAGS="$CXXFLAGS -fsanitize=address" \
REQUIRE_GET_BITCODE="$SVF_BIN/get-bc -a llvm-ar-9 -l llvm-link-9" \
    "$TARGET/build.sh"

# make instrumented executables
export CC="$THIRD_PARTY/sievefuzz/afl-clang-fast"
export CXX="$THIRD_PARTY/sievefuzz/afl-clang-fast++"
rm -f /tmp/fn_indices.txt /tmp/fn_counter.txt
$CXX $CXXFLAGS -c "$FUZZER/src/driver.cpp" -fPIC -o "$OUT/driver.o"
"$MAGMA/build.sh"
CFLAGS="$CFLAGS -fsanitize=address" \
CXXFLAGS="$CXXFLAGS -fsanitize=address" \
    "$TARGET/build.sh"

# copy function indices
rm /tmp/fn_counter.txt
mv /tmp/fn_indices.txt "$OUT/"

# sanity check
cat "$OUT/fn_indices.txt" | rev | cut -d: -f1 | rev | sort -n \
    | awk 'NR == 1 { prev=$1 }
           NR != 1 && $1 != prev+1 {
               print "error: non successive indices " $1 " <= " prev; exit 1
           }
           NR != 1 { prev=$1 }'
