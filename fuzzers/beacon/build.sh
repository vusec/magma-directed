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
git reset --hard
sed -i '465a\
             // skip constexpr stdlib functions\
             && fname.rfind("_ZNSt", 0) == std::string::npos
' Ins/main.cpp
BEACON=$(pwd) ./scripts/build.sh

# build external SVF
cd "$FUZZER/SVF"
git reset --hard
# enable dumping final ICFG
sed -i '118a\
    _pta->getICFG()->updateCallGraph(_pta->getPTACallGraph());\
    // icfg_final is dumped by updateCallGraph if -dump-icfg flag is passed
' svf/lib/WPA/WPAPass.cpp
# skip test suite
# sed -i '124,138d' build.sh
# sed -i '44d;57,59d' CMakeLists.txt
LLVM_DIR=$(llvm-config-15 --prefix) ./build.sh
