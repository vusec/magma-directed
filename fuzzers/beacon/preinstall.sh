#!/bin/bash
set -ex

export DEBIAN_FRONTEND=noninteractive

apt-get update --fix-missing
apt-get install -y git wget curl unzip \
                   gnupg lsb-release software-properties-common \
                   libtinfo-dev libcap-dev zlib1g-dev \
                   libtinfo5 xz-utils \
                   python3 python3-dev python3-pip

add-apt-repository -y ppa:ubuntu-toolchain-r/test

# install LLVM version required by Beacon
wget -q https://releases.llvm.org/4.0.0/clang+llvm-4.0.0-x86_64-linux-gnu-ubuntu-16.10.tar.xz
tar -xf clang+llvm-4.0.0-x86_64-linux-gnu-ubuntu-16.10.tar.xz
rm -f clang+llvm-4.0.0-x86_64-linux-gnu-ubuntu-16.10.tar.xz
cp -r clang+llvm-4.0.0-x86_64-linux-gnu-ubuntu-16.10 /usr/llvm
cp -r /usr/llvm/bin/* /usr/bin/
cp -r /usr/llvm/lib/* /usr/lib/
cp -r /usr/llvm/include/* /usr/include/
cp -r /usr/llvm/share/* /usr/share/

# install latest LLVM version for "latest" SVF
curl -O https://apt.llvm.org/llvm.sh
chmod +x llvm.sh
./llvm.sh 15
rm llvm.sh

# install recent version of cmake to compile SVF
curl -Lo cmake.tar.gz https://github.com/Kitware/CMake/releases/download/v3.26.4/cmake-3.26.4-linux-x86_64.tar.gz
tar xf cmake.tar.gz -C /usr/local --strip-components=1
rm cmake.tar.gz

# install wllvm to extract bitcode and networkx for reachability analysis script
pip3 install --upgrade pip
pip3 install wllvm networkx pydot

# clean apt cache
apt-get clean -y
