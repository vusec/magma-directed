#!/bin/bash
set -e

apt-get update && \
    apt-get install -y make build-essential daemontools git gawk vim gdb time
