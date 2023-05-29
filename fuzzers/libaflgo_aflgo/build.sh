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
SVF_DIR="$FUZZER/svf"

rm -rf "$BUILD" "$SVF_DIR"
mkdir -p "$BUILD"
cd "$BUILD"

cmake -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=clang-15 \
    -DCMAKE_CXX_COMPILER=clang++-15 \
    "$FUZZER/repo"
cmake --build .
sudo -E cmake --install .

clang-15 -c "$FUZZER/stub_rt.c"
ar r "$OUT/stub_rt.a" stub_rt.o

cd -
mv "$BUILD/_deps/svf-src" "$SVF_DIR"
rm -rf "$BUILD"
