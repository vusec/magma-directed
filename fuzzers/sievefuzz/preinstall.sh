#!/bin/bash
set -ex

export DEBIAN_FRONTEND=noninteractive

apt-get update && \
    apt-get install -y git wget curl \
                       gnupg lsb-release software-properties-common \
                       python3-dev

alias curl="curl --proto '=https' --tlsv1.2 -sSf"

LLVM_VERSION=9
curl -O https://apt.llvm.org/llvm.sh
chmod +x llvm.sh
./llvm.sh $LLVM_VERSION
rm -f llvm.sh

update-alternatives --install /usr/bin/clang clang /usr/bin/clang-$LLVM_VERSION 10 \
                    --slave /usr/bin/clang++ clang++ /usr/bin/clang++-$LLVM_VERSION \
                    --slave /usr/bin/opt opt /usr/bin/opt-$LLVM_VERSION
update-alternatives --install /usr/lib/llvm llvm /usr/lib/llvm-$LLVM_VERSION 20 \
                    --slave /usr/bin/llvm-config llvm-config /usr/bin/llvm-config-$LLVM_VERSION \
                    --slave /usr/bin/llvm-link llvm-link /usr/bin/llvm-link-$LLVM_VERSION

apt-get install -y python3-clang-$LLVM_VERSION

apt-get clean -y

curl -Lo cmake.tar.gz https://github.com/Kitware/CMake/releases/download/v3.26.4/cmake-3.26.4-linux-x86_64.tar.gz
tar xf cmake.tar.gz -C /usr/local --strip-components=1
rm cmake.tar.gz
