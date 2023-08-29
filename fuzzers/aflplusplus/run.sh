#!/bin/bash -e

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

if nm "$OUT/afl/$PROGRAM" | grep -E '^[0-9a-f]+\s+[Ww]\s+main$'; then
    ARGS="-"
fi

source "$MAGMA/sanitizers.sh"
set_sanitizer_options 1
echo "\
+ ASAN_OPTIONS=$ASAN_OPTIONS
+ UBSAN_OPTIONS=$UBSAN_OPTIONS" >&2
set -x

mkdir -p "$SHARED/findings"

export AFL_SKIP_CPUFREQ=1
export AFL_NO_AFFINITY=1
export AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1
export AFL_NO_UI=1
export AFL_MAP_SIZE=256000
export AFL_IGNORE_UNKNOWN_ENVS=1
export AFL_FAST_CAL=1
export AFL_NO_WARN_INSTABILITY=1
export AFL_DISABLE_TRIM=1

dict_flags=()
for i in $OUT/*.dict $OUT/*.dic $OUT/afl/*.dict $OUT/afl/*.dic; do
  if [ -f "$i" ]; then
    dict_flags+=(-x "$i")
  fi
done

ulimit -c unlimited
cd "$SHARED"

"$FUZZER/repo/afl-fuzz" -i "$TARGET/corpus/$PROGRAM" -o "$SHARED/findings" \
    -l2 -c "$OUT/cmplog/$PROGRAM" "${dict_flags[@]}" \
    $FUZZARGS -- "$OUT/afl/$PROGRAM" $ARGS 2>&1
