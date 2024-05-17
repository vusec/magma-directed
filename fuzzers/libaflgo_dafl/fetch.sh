#!/bin/bash
set -ex

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
##

mkdir -m 0700 ~/.ssh && ssh-keyscan github.com >> ~/.ssh/known_hosts
git clone --no-checkout git@github.com:vusec/aflgo-new.git "$FUZZER/repo"
git -C "$FUZZER/repo" checkout 5df44ab2f462440cd4463184a56d9e138bd095c3
