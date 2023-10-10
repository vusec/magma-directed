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

cd "$FUZZER/repo"
BEACON=$(pwd) ./scripts/build.sh

# build external SV
cd "$FUZZER/SVF"
git reset --hard
sed -i '118a\
    _pta->getICFG()->updateCallGraph(_pta->getPTACallGraph());\
    _pta->getICFG()->dump("icfg_final");
' svf/lib/WPA/WPAPass.cpp
LLVM_DIR=$(llvm-config-15 --prefix) ./build.sh
