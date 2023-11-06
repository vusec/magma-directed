#!/bin/bash
set -ex

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
##

mkdir -m 0700 ~/.ssh && ssh-keyscan github.com >> ~/.ssh/known_hosts
git clone --depth 1 git@github.com:vusec/LibAFL-directed.git "$FUZZER/repo"

cd "$FUZZER/repo"
sed -i '30c\
            .silence(env::var("LIBAFL_CC_VERBOSE").is_err())\
            // Honor -O0 flag\
            .dont_optimize()
' fuzzers/fuzzbench/src/bin/libafl_cc.rs
