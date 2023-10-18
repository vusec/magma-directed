#!/bin/bash
set -ex

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
##

git clone --no-checkout https://github.com/5hadowblad3/Beacon_artifact.git "$FUZZER/repo"
git -C "$FUZZER/repo" checkout 87bc7f079a970689384ee5c995f8ecc48b7118b5

# fetch external SVF
git clone --no-checkout https://github.com/SVF-tools/SVF.git "$FUZZER/SVF"
git -C "$FUZZER/SVF" checkout 0e9dabd9478f4f638cc54ecfeb3ba2191e7eab33
