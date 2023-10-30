#!/usr/bin/env bash
# Extract runs tarballs and parse fuzzers performance stats.
# Usage: check_perf_stats.sh <fuzzer_kind> <runs_base_dir>
#  fuzzer_kind: libafl or afl
#  runs_base_dir: directory containing runs tarballs;
#                 the script will grab all tarballs in this directory tree
set -euo pipefail

process_libafl() {
    grep 'objectives: 0,' "$1/libafl.log" \
        | tail -n1 \
        | perl -ne 'print $4 / ((3600*$1)+(60*$2)+$3) . "\n"
            if /time: (\d+)h-(\d+)m-(\d+)s.+executions: (\d+)/ && ($1 > 0 || $2 > 0 || $3 > 0)'
}

process_afl() {
    grep 'execs_per_sec' "$1/findings/fuzzer_stats" \
        | awk '{print $3}'
}

main() {
    local fuzzer_kind=$1
    local runs_base_dir=$2

    if [ ! -d "$runs_base_dir" ]; then
        echo "Directory $runs_base_dir does not exist" >&2
        exit 1
    fi

    local fn
    case $fuzzer_kind in
    libafl) fn=process_libafl ;;
    afl) fn=process_afl ;;
    *)
        echo "Unknown fuzzer kind: $fuzzer_kind" >&2
        exit 1
        ;;
    esac

    local archives
    readarray -t archives < <(find "$runs_base_dir" -type f -name "*.tar" | sort)

    local ar tmp_dir
    for ar in "${archives[@]}"; do
        echo "$ar" >&2
        tmp_dir=$(mktemp -dt 'check_perf_stats.XXXXXX')
        tar -xf "$ar" -C "$tmp_dir"
        $fn "$tmp_dir"
        rm -rf "$tmp_dir"
    done \
        | tee /dev/stderr \
        | awk 'BEGIN {tot=0; n=0} {x=strtonum($0)}
            /.+k/ {x*=1000} /.+M/ {x*=1000000}
            {if (x > 0) { tot+=x; n++ }} END {print "tot: " (tot/n)}'
}

main "$@"
