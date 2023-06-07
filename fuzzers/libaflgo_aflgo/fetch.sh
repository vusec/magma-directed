#!/bin/bash
set -ex

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
##

mkdir -m 0700 ~/.ssh && ssh-keyscan github.com >> ~/.ssh/known_hosts
git clone --no-checkout git@github.com:vusec/aflgo-new.git "$FUZZER/repo"
git -C "$FUZZER/repo" checkout 86bb56a785d90c81b0dd730593b6122a96e0ebfd
