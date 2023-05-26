#!/bin/bash
set -ex

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
##

git clone --depth 1 --branch 0.10.1 \
    https://github.com/AFLplusplus/LibAFL.git "$FUZZER/repo"
