#!/bin/bash -e

##
# Pre-requirements:
# - $1: path to test case
# - env FUZZER: path to fuzzer work dir
# - env TARGET: path to target work dir
# - env OUT: path to directory where artifacts are stored
# - env PROGRAM: name of program to run (should be found in $OUT)
##

export TIMELIMIT=0.3s

source "$MAGMA/sanitizers.sh"
set_sanitizer_options 0

args="${ARGS/@@/"'$1'"}"
if [ -z "$args" ]; then
    args="'$1'"
fi

timeout -s KILL --preserve-status $TIMELIMIT bash -c \
    "'$OUT/$PROGRAM' $args"
