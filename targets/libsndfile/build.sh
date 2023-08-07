#!/bin/bash
set -ex

##
# Pre-requirements:
# - env TARGET: path to target work dir
# - env OUT: path to directory where artifacts are stored
# - env CC, CXX, FLAGS, LIBS, etc...
# + env REQUIRE_COPY_BITCODE: set to require copying bitcode files into OUT
# + env REQUIRE_GET_BITCODE: command to use to extract bitcode for each program
##

if [ ! -d "$TARGET/repo" ]; then
    echo "fetch.sh must be executed first."
    exit 1
fi

cd "$TARGET/repo"
./autogen.sh
./configure --disable-shared --enable-ossfuzzers
make -j$(nproc) clean
make -j$(nproc) ossfuzz/sndfile_fuzzer

cp -v ossfuzz/sndfile_fuzzer $OUT/
if [ -n "$REQUIRE_COPY_BITCODE" ]; then
    cp -v ossfuzz/sndfile_fuzzer*.bc $OUT/
fi
if [ -n "$REQUIRE_GET_BITCODE" ]; then
    $REQUIRE_GET_BITCODE "$OUT/sndfile_fuzzer"
fi
