#!/bin/bash
set -ex

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
##

git clone --no-checkout https://github.com/HexHive/SieveFuzz.git "$FUZZER/repo"
git -C "$FUZZER/repo" checkout 1751673ed6c56b7dc69b71ef07ace49867e3cfa4
