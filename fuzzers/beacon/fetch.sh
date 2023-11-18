#!/bin/bash
set -ex

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
##

git clone --no-checkout https://github.com/5hadowblad3/Beacon_artifact.git "$FUZZER/repo"
git -C "$FUZZER/repo" checkout 87bc7f079a970689384ee5c995f8ecc48b7118b5
sed -i '465a\
             // skip constexpr stdlib functions\
             && fname.rfind("_ZNSt", 0) == std::string::npos
' "$FUZZER/repo/Ins/main.cpp"

# fetch external SVF
git clone --no-checkout https://github.com/SVF-tools/SVF.git "$FUZZER/SVF"
git -C "$FUZZER/SVF" checkout 0e9dabd9478f4f638cc54ecfeb3ba2191e7eab33
# enable dumping final ICFG
sed -i '118a\
    _pta->getICFG()->updateCallGraph(_pta->getPTACallGraph());\
    // icfg_final is dumped by updateCallGraph if -dump-icfg flag is passed
' "$FUZZER/SVF/svf/lib/WPA/WPAPass.cpp"
# add missing newline
sed -i '69c\
         O << "Writing " << Filename << "...\n";
' "$FUZZER/SVF/svf/include/Graphs/GraphPrinter.h"
# skip test suite
# sed -i '124,138d' "$FUZZER/SVF/build.sh"
# sed -i '44d;57,59d' "$FUZZER/SVF/CMakeLists.txt"
