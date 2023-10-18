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

cd "$TARGET/repo"
make -j"$(nproc)" clean
make -j"$(nproc)" all
cp -v bin/* "$OUT/"

if [ -n "$REQUIRE_GET_BITCODE" ]; then
    # shellcheck source=/dev/null
    source "$TARGET/configrc"
    for p in "${PROGRAMS[@]}"; do
        $REQUIRE_GET_BITCODE "$OUT/$p"
    done
fi
