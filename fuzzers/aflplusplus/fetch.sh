#!/bin/bash
set -e

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
##

git clone --no-checkout https://github.com/AFLplusplus/AFLplusplus "$FUZZER/repo"
git -C "$FUZZER/repo" checkout v4.08c

# Fix for https://github.com/AFLplusplus/AFLplusplus/issues/1845
curl -sSL https://github.com/AFLplusplus/AFLplusplus/commit/5f6c76e192bcfde6abcf9d4156bfbb87d5480e23.diff \
    | git -C "$FUZZER/repo" apply

sed -i '80,81c\
__attribute__((weak)) int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size) { return 0; }
' "$FUZZER/repo/utils/aflpp_driver/aflpp_driver.c"
