#!/bin/bash

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
# - env TARGET: path to target work dir
# - env OUT: path to directory where artifacts are stored
# - env SHARED: path to directory shared with host (to store results)
# - env PROGRAM: name of program to run (should be found in $OUT)
# - env ARGS: extra arguments to pass to the program
# - env FUZZARGS: extra arguments to pass to the fuzzer
# - env POLL: time (in seconds) to sleep between polls
# - env TIMEOUT: time to run the campaign
# + env STOP_ON_BUG: if set, stop the campaign when the target/all bugs are triggered
# - env MAGMA: path to Magma support files
# + env LOGSIZE: size (in bytes) of log file to generate (default: 1 MiB)
##

# set default max log size to 1 MiB
LOGSIZE=${LOGSIZE:-$((1 << 20))}

export MONITOR="$SHARED/monitor"
mkdir -p "$MONITOR"

# change working directory to somewhere accessible by the fuzzer and target
cd "$SHARED"

CORPUS="$TARGET/corpus/$PROGRAM"

# XXX: fix corpus for all fuzzers
# shellcheck source=magma/fix_seeds.sh
source "$MAGMA/fix_seeds.sh"

for seed in "${SEEDS_TO_REMOVE[@]}"; do
    echo "MAGMA deleting seed: $seed"
    rm "$CORPUS/$seed"
done

shopt -s nullglob
seeds=("$CORPUS"/*)
shopt -u nullglob
if [ ${#seeds[@]} -eq 0 ]; then
    echo "No seeds remaining! Campaign will not be launched."
    exit 1
fi

# launch fuzzer prerun script in parallel (if exists)
if [ -f "$FUZZER/prerun.sh" ]; then
    export MAGMA_PRERUN_DONE="$SHARED/prerun-done.txt"
    rm -f "$MAGMA_PRERUN_DONE"
    "$FUZZER/prerun.sh" &
    prerun_pid=$!
    prerun_time=0
    # wait until prerun is terminated or the MAGMA_PRERUN_DONE file is created
    while [ ! -f "$MAGMA_PRERUN_DONE" ] && kill -0 "$prerun_pid" 2>/dev/null; do
        sleep 1
        prerun_time=$((prerun_time + 1))
    done
    if [ -f "$MAGMA_PRERUN_DONE" ]; then
        echo "Preprocessing script finished in $prerun_time seconds; contents:"
        cat "$MAGMA_PRERUN_DONE"
        echo
    else
        echo "Preprocessing script terminated after $prerun_time seconds"
        kill -9 "$prerun_pid"
        exit 1
    fi
fi

# launch the fuzzer in parallel with the monitor
rm -f "$MONITOR/tmp"*
shopt -s nullglob
polls=("$MONITOR"/*)
shopt -u nullglob
if [ ${#polls[@]} -eq 0 ]; then
    counter=0
else
    timestamps=($(sort -n < <(basename -a "${polls[@]}")))
    last=${timestamps[-1]}
    counter=$((last + POLL))
fi

monitor_flags=(--dump row)
if [ -n "$STOP_ON_BUG" ]; then
    if [ -z "$MAGMA_BUG" ]; then
        echo "warning: STOP_ON_BUG is not supported for undirected campaigns" >&2
    else
        monitor_stop_on_bug_out="$SHARED/stop_on_bug.out"
        monitor_flags+=(--select-bug "$MAGMA_BUG" --select-bug-out "$monitor_stop_on_bug_out")
    fi
fi

fuzzer_pid_file="$SHARED/fuzzer.pid"

while true; do
    if "$OUT/monitor" "${monitor_flags[@]}" >"$MONITOR/tmp"; then
        mv "$MONITOR/tmp" "$MONITOR/$counter"
        if [ -n "$monitor_stop_on_bug_out" ] \
            && [ -f "$monitor_stop_on_bug_out" ] \
            && [ "$(cat "$monitor_stop_on_bug_out")" -gt 0 ]; then
            echo "Bug $MAGMA_BUG triggered at $(date '+%F %R') ($counter)!"
            kill "$(cat "$fuzzer_pid_file")"
            break
        fi
    else
        rm "$MONITOR/tmp"
        [ -f "$monitor_stop_on_bug_out" ] && rm "$monitor_stop_on_bug_out"
    fi
    counter=$((counter + POLL))
    sleep "$POLL"
done &

function start_fuzzer {
    timeout "$TIMEOUT" "$FUZZER/run.sh" \
        | multilog n2 "s$LOGSIZE" "$SHARED/log"
    return "${PIPESTATUS[0]}"
}
start_fuzzer &
fuzzer_pid=$!
echo $fuzzer_pid >"$fuzzer_pid_file"
echo "Campaign launched at $(date '+%F %R')"
wait $fuzzer_pid
code=$?

if [ -f "$SHARED/log/current" ]; then
    cat "$SHARED/log/current"
fi

echo "Campaign terminated at $(date '+%F %R') (exit code $code)"

for job_leader in $(jobs -p); do
    [ -n "$job_leader" ] && kill "$job_leader"
done
exit "$code"
