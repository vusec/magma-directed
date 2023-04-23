#!/bin/bash

if [ $# -lt 1 ]; then
    echo >&2 "usage: $0 <testcase>"
    exit 1
fi

export TIMELIMIT=1s
export MEMLIMIT_MB=200
export SANCOV_OUT_FILE="${SANCOV_OUT_FILE:-/tmp/cov.csv}"
export SANCOV_INDICALLS_OUT_FILE="${SANCOV_INDICALLS_OUT_FILE:-/tmp/indicalls.csv}"

run_limited()
{
    set -e
    ulimit -Sv $((MEMLIMIT_MB << 10));
    "${@:1}"
}
export -f run_limited

args="${ARGS/@@/"'$1'"}"
if [ -z "$args" ]; then
    args="'$1'"
fi

timeout --kill-after 3s --preserve-status $TIMELIMIT bash -c \
    "run_limited '$OUT/indicalls/$PROGRAM' $args"
