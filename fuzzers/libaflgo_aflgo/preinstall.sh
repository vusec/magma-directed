#!/bin/bash
set -ex

export DEBIAN_FRONTEND=noninteractive

apt-get update && \
    apt-get install -y git wget curl \
                       gnupg lsb-release software-properties-common \
                       ninja-build

alias curl="curl --proto '=https' --tlsv1.2 -sSf"

add-apt-repository -y ppa:ubuntu-toolchain-r/test

curl -O https://apt.llvm.org/llvm.sh
chmod +x llvm.sh
./llvm.sh 15
rm -f llvm.sh

curl -Lo cmake.tar.gz https://github.com/Kitware/CMake/releases/download/v3.26.4/cmake-3.26.4-linux-x86_64.tar.gz
tar xf cmake.tar.gz -C /usr/local --strip-components=1
rm cmake.tar.gz

apt-get clean -y

curl https://sh.rustup.rs | sudo -u magma HOME="$MAGMA_HOME" sh -s -- -y --profile minimal
