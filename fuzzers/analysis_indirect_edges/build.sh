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

export GOPATH="$FUZZER/repo/go"
export PATH="$GOPATH/bin:$PATH"

CC="gclang"
CXX="gclang++"

CFLAGS="$CFLAGS -fno-discard-value-names"
CXXFLAGS="$CXXFLAGS -fno-discard-value-names"

# compile standalone driver
$CC $CFLAGS -c "$FUZZER/src/StandaloneFuzzTargetMain.c" -fPIC \
    -o "$OUT/StandaloneFuzzTargetMain.o"

unset CC CXX CFLAGS CXXFLAGS
CC=clang
CXX=clang++

dir="$(mktemp -d)"
cmake -GNinja -DCMAKE_BUILD_TYPE=release -S "$FUZZER" -B "$dir"
pushd "$dir"
ninja
mv wrapper/indicalls_cc pass/IndirectBranchCounter.so libsancov_dumper.a libsancov_dumper.so "$OUT/"
cp "$OUT/indicalls_cc" "$OUT/indicalls_cxx"
popd
rm -rf "$dir"
