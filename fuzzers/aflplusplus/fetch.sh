#!/bin/bash
set -e

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
##

git clone --no-checkout https://github.com/AFLplusplus/AFLplusplus "$FUZZER/repo"
git -C "$FUZZER/repo" checkout v4.08c

sed -i '80,81c\
__attribute__((weak)) int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size) { return 0; }
' "$FUZZER/repo/utils/aflpp_driver/aflpp_driver.c"
