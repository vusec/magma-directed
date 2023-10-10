#!/bin/bash

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
# - env TARGET: path to target work dir
# - env OUT: path to directory where artifacts are stored
# - env SHARED: path to directory shared with host (to store results)
# - env PROGRAM: name of program to run (should be found in $OUT)
##

if [ -z "$MAGMA_BUG" ]; then
    echo "MAGMA_BUG must be set to the bug id." >&2
    exit 1
fi

if [ -z "$MAGMA_PRERUN_DONE" ]; then
    echo "MAGMA_PRERUN_DONE must be set to a file path." >&2
    exit 1
fi

# shellcheck source=magma/directed.sh
source "$MAGMA/directed.sh"
MAGMA_LOG_LINES="$OUT/magma_log_locations.txt"
store_magma_log_lines "$MAGMA_LOG_LINES" || exit 1

if [ "$(wc -l <"$MAGMA_LOG_LINES")" -eq 0 ]; then
    echo "No target locations found for bug $MAGMA_BUG." >&2
    exit 1
fi

find_function_cmd=("$FUZZER"/find_function_by_line.py)
if [ "$(basename "$TARGET")" = poppler ]; then
    find_function_cmd+=(--db-dir "$OUT")
fi

truncate -s0 "$OUT/target_functions.txt"
while read -r location; do
    file="$(echo "$location" | cut -d: -f1)"
    line="$(echo "$location" | cut -d: -f2)"
    if ! "${find_function_cmd[@]}" "$file" "$line" >>"$OUT/target_functions.txt"; then
        echo "error: could not find function for $location" >&2
        exit 1
    fi
done <"$MAGMA_LOG_LINES"

if [ "$(wc -l < <(sort "$OUT/target_functions.txt" | uniq))" -ne 1 ]; then
    echo "No unique target function found for bug $MAGMA_BUG." >&2
    echo "Target functions:" >&2
    sort "$OUT/target_functions.txt" | uniq >&2
    exit 1
fi

fn=$(llvm-cxxfilt-9 <"$OUT/target_functions.txt")
echo "Targeting bug $MAGMA_BUG in function $fn." >&2

exec "$FUZZER"/repo/third_party/SVF/Release-build/bin/svf-ex \
    -p=6200 -f="$fn" \
    --preprocessing-done="$MAGMA_PRERUN_DONE" \
    --tag="$SHARED/findings/000" \
    --activation="$OUT/fn_indices.txt" \
    --get-indirect \
    --run-server \
    --stat=false \
    --dump-stats \
    "$OUT/$PROGRAM.bc" 2>&1
