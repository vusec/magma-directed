#!/bin/bash
set -e

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
##

git clone --no-checkout https://github.com/AFLplusplus/AFLplusplus "$FUZZER/repo"
git -C "$FUZZER/repo" checkout v4.08c

sed -i 's/\(__afl_sharedmem_fuzzing\) = 1/\1 = 0/' "$FUZZER/repo/utils/aflpp_driver/aflpp_driver.c"
