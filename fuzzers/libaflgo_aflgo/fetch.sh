#!/bin/bash
set -ex

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
##

mkdir -m 0700 ~/.ssh && ssh-keyscan github.com >> ~/.ssh/known_hosts
git clone --no-checkout git@github.com:vusec/aflgo-new.git "$FUZZER/repo"
git -C "$FUZZER/repo" checkout 2b03f663422a52f4d363c3b18c9753d27c182169
