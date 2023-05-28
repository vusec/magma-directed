#!/bin/bash -ex

apt-get update && \
    apt-get install -y make build-essential wget git \
                       lsb-release software-properties-common gnupg

apt-add-repository -y ppa:ubuntu-toolchain-r/test

wget https://apt.llvm.org/llvm.sh
chmod +x llvm.sh
./llvm.sh 15
