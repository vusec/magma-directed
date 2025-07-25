#!/bin/bash
set -ex

##
# Pre-requirements:
# - env TARGET: path to target work dir
# - env OUT: path to directory where artifacts are stored
# - env CC, CXX, FLAGS, LIBS, etc...
# + env REQUIRE_GET_BITCODE: command to use to extract bitcode for each program
##

if [ ! -d "$TARGET/repo" ]; then
    echo "fetch.sh must be executed first."
    exit 1
fi

# build the sqlite3 library
cd "$TARGET/repo"

export WORK="$TARGET/work"
rm -rf "$WORK"
mkdir -p "$WORK"
cd "$WORK"

export CFLAGS="$CFLAGS -Wno-all \
               -DSQLITE_MAX_LENGTH=128000000 \
               -DSQLITE_MAX_SQL_LENGTH=128000000 \
               -DSQLITE_MAX_MEMORY=25000000 \
               -DSQLITE_PRINTF_PRECISION_LIMIT=1048576 \
               -DSQLITE_DEBUG=1 \
               -DSQLITE_MAX_PAGE_COUNT=16384"

"$TARGET/repo"/configure --disable-shared --disable-amalgamation --enable-rtree
make clean
make -j$(nproc)

$CC $CFLAGS -I. \
    "$TARGET/repo/test/ossfuzz.c" \
    -o "$OUT/sqlite3_fuzz" \
    .libs/libsqlite3.a \
    $LDFLAGS $LIBS -lpthread -ldl -lm

if [ -n "$REQUIRE_GET_BITCODE" ]; then
    $REQUIRE_GET_BITCODE "$OUT/sqlite3_fuzz"
fi
