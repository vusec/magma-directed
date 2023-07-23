#!/bin/bash
set -ex

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
##

mkdir -m 0700 ~/.ssh && ssh-keyscan github.com >> ~/.ssh/known_hosts
git clone --depth 1 git@github.com:vusec/LibAFL-directed.git "$FUZZER/repo"
