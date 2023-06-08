#!/bin/bash
# Run given executable and print time and memory usage

if [ $# -lt 1 ]; then
    echo "usage: $0 <executable> [args...]"
    exit 1
fi

/usr/bin/time -v "$@" &
pid=$!

max_mem=0
while [ -d /proc/$pid ]; do
    mem=$(free -t | grep Total | awk '{print $3}')
    if [ "$mem" -gt $max_mem ]; then
        max_mem=$mem
    fi
    sleep 5
done
wait $pid
exit_code=$?
printf '\n\nMax memory usage: %d\n' "$max_mem" >&2
exit $exit_code
