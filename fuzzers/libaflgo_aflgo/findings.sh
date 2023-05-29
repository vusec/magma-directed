#!/bin/bash

##
# Pre-requirements:
# - $1: if 0 grab crashes, if 1 grab all (default: 0)
# - env SHARED: path to directory shared with host (to store results)
##

MODE=${1:-0}

CRASH_DIR="$SHARED/findings/crashes"
QUEUE_DIR="$SHARED/findings/queue"

if [ ! -d "$CRASH_DIR" ]; then
    exit 1
fi

find "$CRASH_DIR" -maxdepth 1 -type f \! -name '.*'

if [ "$MODE" = 0 ]; then
    exit
elif [ ! -d "$QUEUE_DIR" ]; then
    exit 1
fi
find "$QUEUE_DIR" -maxdepth 1 -type f \! -name '.*'
