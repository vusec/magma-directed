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

export CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse
export LIBAFL_EDGES_MAP_SIZE=2621440

BUILD="$FUZZER/build"
rm -rf "$BUILD"
mkdir -p "$BUILD"
cd "$BUILD"
cmake -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=clang-16 \
    -DCMAKE_CXX_COMPILER=clang++-16 \
    "$FUZZER/repo"
ninja
sudo -E ninja install
clang-16 -c "$FUZZER/stub_rt.c"
cp stub_rt.o "$OUT/stub_rt.o"
cd -
rm -rf "$BUILD"
