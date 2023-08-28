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

cd "$FUZZER/repo"
LLVM_VERSION=15
export CC=clang-$LLVM_VERSION
export CXX=clang++-$LLVM_VERSION
export LLVM_CONFIG=llvm-config-$LLVM_VERSION
export AFL_NO_X86=1
export PYTHON_INCLUDE=/
make -j"$(nproc)"
make -C utils/aflpp_driver

mkdir -p "$OUT/afl" "$OUT/cmplog"
