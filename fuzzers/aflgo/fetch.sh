#!/bin/bash
set -ex

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
##

git clone --no-checkout https://github.com/aflgo/aflgo.git "$FUZZER/repo"
git -C "$FUZZER/repo" checkout ac9246a4fe7c0bba15e36c994c456af14d89b698
