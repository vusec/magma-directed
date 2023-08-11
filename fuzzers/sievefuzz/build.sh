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
git reset --hard
git apply "$FUZZER/src/repo.patch"
./build.sh
cp -v ./gllvm_bins/* third_party/SVF/Release-build/bin/
