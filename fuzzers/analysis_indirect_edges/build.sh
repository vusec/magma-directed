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

# compile llvm pass
dir="$(mktemp -d)"
pushd "$dir"
cmake -GNinja -DCMAKE_BUILD_TYPE=Release "$FUZZER/pass"
ninja
mv "IndirectBranchCounter.so" "$OUT/"
popd
rm -rf "$dir"
