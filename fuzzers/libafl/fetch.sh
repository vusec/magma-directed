#!/bin/bash
set -ex

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
##

mkdir -m 0700 ~/.ssh && ssh-keyscan github.com >> ~/.ssh/known_hosts
git clone --no-checkout git@github.com:vusec/LibAFL-directed.git "$FUZZER/repo"
git -C "$FUZZER/repo" checkout 024d6b1674c26c8581ab7128d3fde334fab6ff6d

cd "$FUZZER/repo"
sed -i '30c\
            .silence(env::var("LIBAFL_CC_VERBOSE").is_err())\
            // Honor -O0 flag\
            .dont_optimize()
' fuzzers/fuzzbench/src/bin/libafl_cc.rs
