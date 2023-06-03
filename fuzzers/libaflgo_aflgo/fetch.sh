#!/bin/bash
set -ex

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
##

mkdir -m 0700 ~/.ssh && ssh-keyscan github.com >> ~/.ssh/known_hosts
git clone --no-checkout git@github.com:vusec/aflgo-new.git "$FUZZER/repo"
git -C "$FUZZER/repo" checkout 0be6003e6a13163d1884459c09a910067d0546b8
