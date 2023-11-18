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

# build Beacon
cd "$FUZZER/repo"
BEACON=$(pwd) ./scripts/build.sh

# build external SVF
cd "$FUZZER/SVF"
LLVM_DIR=$(llvm-config-15 --prefix) ./build.sh
