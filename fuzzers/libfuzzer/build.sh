#!/bin/bash -ex

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
##

export CC=clang-15
export CXX=clang++-15
# C++14 is required by libFuzzer because of the use of user-defined literals
CXXSTD=c++14

# We need the version of LLVM which has the LLVMFuzzerRunDriver exposed
cd "$FUZZER/repo/compiler-rt/lib/fuzzer"
for f in *.cpp; do
  $CXX -g -O2 -fno-omit-frame-pointer -std=$CXXSTD $f -c
done
rm -f "$OUT/libFuzzer.a"
ar ru "$OUT/libFuzzer.a" Fuzzer*.o
rm -f Fuzzer*.o
$CXX $CXXFLAGS -std=$CXXSTD -c "$FUZZER/src/driver.cpp" -fPIC -o "$OUT/driver.o"
