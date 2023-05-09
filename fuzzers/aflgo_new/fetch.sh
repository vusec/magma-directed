#!/bin/bash
set -ex

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
##

mkdir -m 0700 ~/.ssh && ssh-keyscan github.com >> ~/.ssh/known_hosts
git clone --no-checkout git@github.com:vusec/aflgo-new.git "$FUZZER/repo"
git -C "$FUZZER/repo" checkout 5774faf7cacd341f3bbf77eeb308e1f0e83b865e
