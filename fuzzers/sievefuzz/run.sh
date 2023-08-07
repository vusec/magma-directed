#!/bin/bash
# shellcheck disable=SC2086

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
# - env TARGET: path to target work dir
# - env OUT: path to directory where artifacts are stored
# - env SHARED: path to directory shared with host (to store results)
# - env PROGRAM: name of program to run (should be found in $OUT)
# - env ARGS: extra arguments to pass to the program
# - env FUZZARGS: extra arguments to pass to the fuzzer
##

if [ -z "$MAGMA_BUG" ]; then
    echo "MAGMA_BUG must be set to the bug id."
    exit 1
fi

grep -rIn 'MAGMA_LOG("'"$MAGMA_BUG" "$TARGET/repo" \
    | sed -E 's/^(.+:[0-9]+):.*$/\1/' \
    | sort -u >"$OUT/target_locations.txt"

if [ "$(wc -l <"$OUT/target_locations.txt")" -eq 0 ]; then
    echo "No target locations found for bug $MAGMA_BUG."
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
done <"$OUT/target_locations.txt"

if [ "$(wc -l < <(sort "$OUT/target_functions.txt" | uniq))" -ne 1 ]; then
    echo "No unique target function found for bug $MAGMA_BUG." >&2
    echo "Target functions:" >&2
    sort "$OUT/target_functions.txt" | uniq >&2
    exit 1
fi

fn=$(llvm-cxxfilt-9 <"$OUT/target_functions.txt")
echo "Targeting bug $MAGMA_BUG in function $fn." >&2

# shellcheck source=magma/sanitizers.sh
source "$MAGMA/sanitizers.sh"
set_sanitizer_options 1
echo "\
+ ASAN_OPTIONS=$ASAN_OPTIONS
+ UBSAN_OPTIONS=$UBSAN_OPTIONS" >&2
set -x

mkdir -p "$SHARED/findings"

export AFL_SKIP_CPUFREQ=1
export AFL_NO_AFFINITY=1

TPDIR="$FUZZER/repo/third_party"

"$TPDIR"/SVF/Release-build/bin/svf-ex \
    -p=6200 -f="$fn" \
    --tag="$SHARED/findings/000" \
    --activation="$OUT/fn_indices.txt" \
    --get-indirect \
    --run-server \
    --stat=false \
    --dump-stats \
    "$OUT/$PROGRAM.bc" 2>&1 &
svf_pid=$!
sleep 30
"$TPDIR"/sievefuzz/afl-fuzz -m none -P 6200 \
    -i "$TARGET/corpus/$PROGRAM" -o "$SHARED/findings" \
    $FUZZARGS -- "$OUT/$PROGRAM" $ARGS 2>&1
exit_code=$?

kill "$svf_pid" || true
exit $exit_code
