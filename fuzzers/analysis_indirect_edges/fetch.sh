#!/bin/bash
set -e

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
##

export GOPATH="$FUZZER/repo/go"
mkdir -p $GOPATH
go install github.com/SRI-CSL/gllvm/cmd/...@latest

# XXX: we need to install as magma user in the container, do not move to preinstall.sh
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
    | sh -s -- -y --profile minimal --default-toolchain nightly
