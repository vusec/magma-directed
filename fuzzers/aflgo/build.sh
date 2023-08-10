#!/bin/bash
set -ex

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
##

if [ ! -d "$FUZZER/repo" ]; then
    echo "fetch.sh must be executed first."
    exit 1
fi

LLVM_VERSION=11
export LLVM_CONFIG=llvm-config-$LLVM_VERSION
export CC=clang-$LLVM_VERSION
export CXX=clang++-$LLVM_VERSION
export AFL_CC=$CC
export AFL_CXX=$CXX

cd "$FUZZER/repo"
git reset --hard
git apply "$FUZZER/src/fuzzer.patch"
make clean all
(cd llvm_mode && make clean all)
(cd distance_calculator && cmake -GNinja . && cmake --build .)
./afl-clang-fast++ $CXXFLAGS -std=c++11 -c "$FUZZER/src/afl_driver.cpp" -fPIC -o "$OUT/afl_driver.o"
