#!/bin/bash

##
# Pre-requirements:
# + $1: path to captainrc (default: ./captainrc)
# + env ANALYSIS: analysis to run
##

cleanup() {
    sudo chown -R "$(id -u "$USER"):$(id -g "$USER")" "$TMPDIR"
    rm -rf "$TMPDIR"
}

trap cleanup EXIT

if [ -z "$1" ]; then
    set -- "./captainrc"
fi

# load the configuration file (captainrc)
set -a
# shellcheck source=tools/captain/captainrc
source "$1"
set +a

MAGMA=${MAGMA:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/../../" >/dev/null 2>&1 && pwd)"}
export MAGMA
source "$MAGMA/tools/captain/common.sh"

has_errors=0
if [ -z "$ANALYSIS" ] || [ ! -d "$MAGMA/fuzzers/$ANALYSIS" ]; then
    has_errors=1
    echo >&2 "\$ANALYSIS is required to be a folder in $MAGMA/fuzzers"
fi
if [ -z "$WORKDIR" ] || [ ! -d "$WORKDIR" ]; then
    has_errors=1
    echo >&2 "\$WORKDIR=$WORKDIR is not a directory"
fi

if [ $has_errors = 1 ]; then
    exit 1
fi

WORKDIR="$(realpath "$WORKDIR")"
export ARDIR="$WORKDIR/ar"
export ANALYSISDIR="$WORKDIR/analysis"
export CACHEDIR="$WORKDIR/cache"
export LOGDIR="$WORKDIR/log"
export POCDIR="$WORKDIR/poc"
export TMPDIR="$WORKDIR/tmp"
mkdir -p "$ARDIR"
mkdir -p "$ANALYSISDIR"
mkdir -p "$CACHEDIR"
mkdir -p "$LOGDIR"
mkdir -p "$POCDIR"
mkdir -p "$TMPDIR"

if [ -z "$ARDIR" ] || [ ! -d "$ARDIR" ]; then
    echo >&2 "Invalid archive directory!"
    exit 1
fi

PARALLEL_FILE="$TMPDIR/parallel.txt"
truncate -s0 "$PARALLEL_FILE"
BUILT_IMAGES="$TMPDIR/built_images.txt"
truncate -s0 "$BUILT_IMAGES"
export FUZZER TARGET PROGRAM ARGS CID SHARED

find_subdirs() { find "$1" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z; }

iterate_programs() {
    while read -r -d '' PROGRAMDIR; do
        PROGRAM="$(basename "$PROGRAMDIR")"
        ARGS="$(get_var_or_default "$FUZZER" "$TARGET" "$PROGRAM" ARGS)"
        while read -r -d '' CAMPAIGNDIR; do
            CID="$(basename "$CAMPAIGNDIR")"
            start_analysis
        done < <(find_subdirs "$PROGRAMDIR")
    done < <(find_subdirs "$1")
}

start_analysis() {
    SHARED="$TMPDIR/$FUZZER/$TARGET${BUG:+/$BUG}/$PROGRAM/$CID"

    # select whether to copy or untar
    if [ -f "$CAMPAIGNDIR/${TARBALL_BASENAME}.tar" ]; then
        echo_time "Extracting archive into $SHARED"
        mkdir -p "$SHARED"
        tar -C "$SHARED" -xf "$CAMPAIGNDIR/${TARBALL_BASENAME}.tar"
    else
        echo_time "Moving data folder into $SHARED"
        cp -r "$CAMPAIGNDIR" "$SHARED"
    fi

    ANALYSISDIR_THIS="${ANALYSISDIR}/${ANALYSIS}/${FUZZER}/${TARGET}${BUG:+/$BUG}/${PROGRAM}/${CID}"
    mkdir -p "$ANALYSISDIR_THIS"

    printf '%q/tools/captain/run_analysis_single.sh %q %q %q %q %q %q %q %q &>%q\n' \
        "$MAGMA" \
        "$ANALYSIS" \
        "$FUZZER" \
        "$TARGET" \
        "$BUG" \
        "$PROGRAM" \
        "$ARGS" \
        "$SHARED" \
        "$ANALYSISDIR_THIS" \
        "${LOGDIR}/${ANALYSIS}_${FUZZER}_${TARGET}${BUG:+_$BUG}_${PROGRAM}_${CID}_container.log" \
        >>"$PARALLEL_FILE"
}

find_subdirs "$ARDIR" | while read -r -d '' FUZZERDIR; do
    FUZZER="$(basename "$FUZZERDIR")"
    DIRECTED="$(meta_var "$FUZZER" DIRECTED)"
    find_subdirs "$FUZZERDIR" | while read -r -d '' TARGETDIR; do
        TARGET="$(basename "$TARGETDIR")"

        # build the Docker image
        IMG_NAME="$(magma_analysis_image_name)"
        if [ -z "$SKIP_BUILDS" ] && ! grep -q "$IMG_NAME" "$BUILT_IMAGES"; then
            echo_time "Building $IMG_NAME"
            LOGFILE="${LOGDIR}/${ANALYSIS}_${TARGET}_build.log"
            if ! "$MAGMA"/tools/captain/build.sh "$ANALYSIS" &>"$LOGFILE"; then
                echo_time "Failed to build $IMG_NAME. Check build log for info."
                continue
            fi
            echo "$IMG_NAME" >>"$BUILT_IMAGES"
        fi

        if [ -n "$JUST_BUILD" ]; then
            continue
        fi

        if [ -n "$DIRECTED" ]; then
            find_subdirs "$TARGETDIR" | while read -r -d '' BUGDIR; do
                BUG="$(basename "$BUGDIR")"
                iterate_programs "$BUGDIR"
            done
        else
            iterate_programs "$TARGETDIR"
        fi
    done
done

if [ -n "$JUST_BUILD" ]; then
    echo_time "Done building"
    exit
fi

if ! NUMBER_OF_TASKS=$(wc -l <"$PARALLEL_FILE"); then
    echo_time "Failed to get number of lines from $PARALLEL_FILE."
    exit 1
elif [ "$NUMBER_OF_TASKS" -gt 0 ]; then
    echo_time "Running $NUMBER_OF_TASKS tasks."
    parallel -j-2 <"$PARALLEL_FILE"
    ec=$?
    echo_time "Parallel tasks completed, exit code $ec"
    exit $ec
else
    echo_time "No tasks to run..."
fi
