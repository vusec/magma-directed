#!/bin/bash
set -e

##
# Pre-requirements:
# - env TARGET: path to target work dir
# - env OUT: path to directory where artifacts are stored
# - env CC, CXX, FLAGS, LIBS, etc...
##

if [ ! -d "$TARGET/repo" ]; then
    echo "fetch.sh must be executed first."
    exit 1
fi

cd "$TARGET/repo"

# build lua library
make -j$(nproc) clean
make -j$(nproc) liblua.a
cp liblua.a "$OUT/"

# build main lua binary
make -j$(nproc) MYLDFLAGS="$CFLAGS" lua
cp lua "$OUT/"

# build driver
cp "$TARGET/src/fuzz_lua.c" .
$CC $CFLAGS -c fuzz_lua.c -o fuzz_lua.o
$CXX $CXXFLAGS $LIB_FUZZING_ENGINE fuzz_lua.o -o "$OUT/fuzz_lua" "$OUT/liblua.a" $LDFLAGS $LIBS
