#!/bin/bash -ex

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
##

git clone --depth 1 --branch llvmorg-15.0.7 \
    https://github.com/llvm/llvm-project.git "$FUZZER/repo"
