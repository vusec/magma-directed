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

export LLVM_DIR=$(llvm-config --prefix)
cd "$FUZZER/repo"
patch patches/afl/afl-fuzz.c "$FUZZER/src/afl-fuzz.diff"
patch patches/afl/afl-llvm-pass.so.cc "$FUZZER/src/afl-llvm-pass.diff"
patch patches/svf/util.cpp "$FUZZER/src/svf-util.diff"
./build.sh
cp -v ./gllvm_bins/* third_party/SVF/Release-build/bin/
