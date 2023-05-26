#!/bin/bash -e

##
# Pre-requirements:
# - $1: path to test case
# - env FUZZER: path to fuzzer work dir
# - env TARGET: path to target work dir
# - env OUT: path to directory where artifacts are stored
# - env PROGRAM: name of program to run (should be found in $OUT)
##

export TIMELIMIT=0.1s

timeout -s KILL --preserve-status $TIMELIMIT bash -c \
    "'$OUT/$PROGRAM' '$1'"
