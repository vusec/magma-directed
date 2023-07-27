#!/bin/bash
set -ex

export DEBIAN_FRONTEND=noninteractive

apt-get update && \
    apt-get install -y git wget curl ninja-build binutils-gold binutils-dev \
                       python3 python3-dev python3-pip libboost-all-dev \
                       gnupg lsb-release software-properties-common

alias curl="curl --proto '=https' --tlsv1.2 -sSf"

# add-apt-repository -y ppa:ubuntu-toolchain-r/test

curl -O https://apt.llvm.org/llvm.sh
chmod +x llvm.sh
LLVM_VERSION=11
./llvm.sh $LLVM_VERSION
rm -f llvm.sh

mkdir -p /usr/lib/bfd-plugins
cp /usr/lib/llvm-$LLVM_VERSION/lib/LLVMgold.so /usr/lib/bfd-plugins/
cp /usr/lib/llvm-$LLVM_VERSION/lib/libLTO.so /usr/lib/bfd-plugins/

apt-get clean -y

curl -Lo cmake.tar.gz https://github.com/Kitware/CMake/releases/download/v3.26.4/cmake-3.26.4-linux-x86_64.tar.gz
tar xf cmake.tar.gz -C /usr/local --strip-components=1
rm cmake.tar.gz

pip3 install networkx pydot pydotplus
