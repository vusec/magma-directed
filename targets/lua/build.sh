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

# build lua library
make -j$(nproc) clean
make -j$(nproc) liblua.a
cp -v liblua.a "$OUT/"

# build main lua binary
make -j$(nproc) MYLDFLAGS="$CFLAGS" lua
cp -v lua "$OUT/"
if [ -n "$REQUIRE_COPY_BITCODE" ]; then
    cp -v lua*.bc "$OUT/"
fi

# build driver
cp "$TARGET/src/fuzz_lua.c" .
$CC $CFLAGS -c fuzz_lua.c -o fuzz_lua.o
$CXX $CXXFLAGS $LIB_FUZZING_ENGINE fuzz_lua.o -o "$OUT/fuzz_lua" "$OUT/liblua.a" $LDFLAGS $LIBS

if [ -n "$REQUIRE_GET_BITCODE" ]; then
    $REQUIRE_GET_BITCODE "$OUT/lua"
    $REQUIRE_GET_BITCODE "$OUT/fuzz_lua"
fi
