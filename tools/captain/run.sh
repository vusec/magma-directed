#!/bin/bash -e

##
# Pre-requirements:
# + $1: path to captainrc (default: ./captainrc)
##

if [ -z "$1" ]; then
    set -- "./captainrc"
fi

# load the configuration file (captainrc)
set -a
# shellcheck source=tools/captain/captainrc
source "$1"
set +a

if [ -z "$WORKDIR" ] || [ -z "$REPEAT" ]; then
    echo '$WORKDIR and $REPEAT must be specified as environment variables.'
    exit 1
fi
MAGMA=${MAGMA:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/../../" >/dev/null 2>&1 && pwd)"}
export MAGMA
source "$MAGMA/tools/captain/common.sh"

if [ -z "$WORKER_POOL" ]; then
    WORKER_MODE=${WORKER_MODE:-1}
    mapfile -t WORKERS_ALL < <(lscpu -b -p \
        | sed '/^#/d' | sort -u -t, -k "${WORKER_MODE}g" | cut -d, -f1)
    WORKERS=${WORKERS:-${#WORKERS_ALL[@]}}
    export WORKER_POOL="${WORKERS_ALL[@]:0:WORKERS}"
fi
export CAMPAIGN_WORKERS=${CAMPAIGN_WORKERS:-1}

TMPFS_SIZE=${TMPFS_SIZE:-50g}
export POLL=${POLL:-5}
export TIMEOUT=${TIMEOUT:-1m}

WORKDIR="$(realpath "$WORKDIR")"
export ARDIR="$WORKDIR/ar"
export CACHEDIR="$WORKDIR/cache"
export LOGDIR="$WORKDIR/log"
export POCDIR="$WORKDIR/poc"
export LOCKDIR="$WORKDIR/lock"
mkdir -p "$ARDIR"
mkdir -p "$CACHEDIR"
mkdir -p "$LOGDIR"
mkdir -p "$POCDIR"
mkdir -p "$LOCKDIR"

shopt -s nullglob
rm -f "$LOCKDIR"/*
shopt -u nullglob

export MUX_TAR=magma_tar
export MUX_CID=magma_cid

get_next_cid() {
    ##
    # Pre-requirements:
    # - $1: the directory where campaigns are stored
    ##
    shopt -s nullglob
    campaigns=("$1"/*)
    if [ ${#campaigns[@]} -eq 0 ]; then
        echo 0
        dir="$1/0"
    else
        mapfile -t cids < <(sort -n < <(basename -a "${campaigns[@]}"))
        for ((i = 0; ; i++)); do
            if [ -z "${cids[i]}" ] || [ "${cids[i]}" -ne "$i" ]; then
                echo "$i"
                dir="$1/$i"
                break
            fi
        done
    fi
    # ensure the directory is created to prevent races
    mkdir -p "$dir"
    while [ ! -d "$dir" ]; do sleep 1; done
}
export -f get_next_cid

mutex() {
    ##
    # Pre-requirements:
    # - $1: the mutex ID (file descriptor)
    # - $2..N: command to run
    ##
    trap 'rm -f "$LOCKDIR/$mux"' EXIT
    mux=$1
    shift
    (
        flock -xF 200 &>/dev/null
        "${@}"
    ) 200>"$LOCKDIR/$mux"
}
export -f mutex

start_campaign() {
    launch_campaign() {
        export SHARED="$CAMPAIGN_CACHEDIR/$CACHECID"
        mkdir -p "$SHARED" && chmod 777 "$SHARED"

        local CONTAINER_NAME="$FUZZER/$TARGET${BUG:+/$BUG}/$PROGRAM/$ARCID"
        echo_time "Container $CONTAINER_NAME started on CPU $AFFINITY"
        LOGFILE="${LOGDIR}/${FUZZER}_${TARGET}${BUG:+_$BUG}_${PROGRAM}_${ARCID}_container.log"
        "$MAGMA"/tools/captain/start.sh &>"$LOGFILE"
        echo_time "Container $CONTAINER_NAME stopped (exit code $?)"

        if [ -n "$POC_EXTRACT" ]; then
            "$MAGMA"/tools/captain/extract.sh
        fi

        sudo chown -R "$(id -u "$USER"):$(id -g "$USER")" "$SHARED"

        if [ -z "$NO_ARCHIVE" ]; then
            # only one tar job runs at a time, to prevent out-of-storage errors
            mutex $MUX_TAR \
                tar -cf "${CAMPAIGN_ARDIR}/${ARCID}/${TARBALL_BASENAME}.tar" -C "$SHARED" . &>/dev/null \
                && rm -rf "$SHARED"
        else
            # overwrites empty $ARCID directory with the $SHARED directory
            mv -T "$SHARED" "${CAMPAIGN_ARDIR}/${ARCID}"
        fi
    }
    export -f launch_campaign

    while :; do
        export CACHECID CAMPAIGN_CACHEDIR="$CACHEDIR/$FUZZER/$TARGET${BUG:+/$BUG}/$PROGRAM"
        CACHECID=$(mutex $MUX_CID get_next_cid "$CAMPAIGN_CACHEDIR")

        export ARCID CAMPAIGN_ARDIR="$ARDIR/$FUZZER/$TARGET${BUG:+/$BUG}/$PROGRAM"
        ARCID=$(mutex $MUX_CID get_next_cid "$CAMPAIGN_ARDIR")

        errno_lock=69
        SHELL=/bin/bash flock -xnF -E $errno_lock "${CAMPAIGN_CACHEDIR}/${CACHECID}" \
            flock -xnF -E $errno_lock "${CAMPAIGN_ARDIR}/${ARCID}" \
            -c launch_campaign \
            || if [ $? -eq $errno_lock ]; then
                continue
            fi
        break
    done
}
export -f start_campaign

start_ex() {
    release_workers() {
        IFS=','
        read -r -a workers <<<"$AFFINITY"
        unset IFS
        for i in "${workers[@]}"; do
            rm -rf "$LOCKDIR/magma_cpu_$i"
        done
    }
    trap release_workers EXIT

    start_campaign
    exit 0
}
export -f start_ex

allocate_workers() {
    ##
    # Pre-requirements:
    # - env NUMWORKERS
    # - env WORKERSET
    ##
    cleanup() {
        IFS=','
        read -r -a workers <<<"$WORKERSET"
        unset IFS
        for i in "${workers[@]:1}"; do
            rm -rf "$LOCKDIR/magma_cpu_$i"
        done
        exit 0
    }
    trap cleanup SIGINT

    while [ "$NUMWORKERS" -gt 0 ]; do
        for i in $WORKER_POOL; do
            if (
                set -o noclobber
                >"$LOCKDIR/magma_cpu_$i"
            ) &>/dev/null; then
                export WORKERSET="$WORKERSET,$i"
                export NUMWORKERS=$((NUMWORKERS - 1))
                allocate_workers
                return
            fi
        done
        # This times-out every 1 second to force a refresh, since a worker may
        #   have been released by the time inotify instance is set up.
        inotifywait -qq -t 1 -e delete "$LOCKDIR" &>/dev/null
    done
    cut -d',' -f2- <<<"$WORKERSET"
}
export -f allocate_workers

# set up a RAM-backed fs for fast processing of canaries and crashes
if [ -z "$CACHE_ON_DISK" ]; then
    echo_time "Obtaining sudo permissions to mount tmpfs"
    if mountpoint -q -- "$CACHEDIR"; then
        sudo umount -f "$CACHEDIR"
    fi
    sudo mount -t tmpfs -o "size=$TMPFS_SIZE,uid=$(id -u "$USER"),gid=$(id -g "$USER")" \
        tmpfs "$CACHEDIR"
fi

cleanup() {
    trap 'echo Cleaning up...' SIGINT
    echo_time "Waiting for jobs to finish"
    for job in $(jobs -p); do
        if ! wait "$job"; then
            continue
        fi
    done

    find "$LOCKDIR" -type f | while read -r lock; do
        if inotifywait -qq -e delete_self "$lock" &>/dev/null; then
            continue
        fi
    done

    if [ -z "$CACHE_ON_DISK" ]; then
        echo_time "Obtaining sudo permissions to umount tmpfs"
        sudo umount "$CACHEDIR"
    fi
}

trap cleanup EXIT

# schedule campaigns
for FUZZER in "${FUZZERS[@]}"; do
    export FUZZER NUMWORKERS
    NUMWORKERS="$(get_var_or_default "$FUZZER" CAMPAIGN_WORKERS)"
    DIRECTED="$(meta_var "$FUZZER" DIRECTED)"

    IFS=' ' read -r -a TARGETS <<<"$(get_var_or_default "$FUZZER" TARGETS)"
    for TARGET in "${TARGETS[@]}"; do
        export TARGET FUZZARGS
        FUZZARGS="$(get_var_or_default "$FUZZER" "$TARGET" FUZZARGS)"

        # build the Docker image

        if [ -n "$DIRECTED" ]; then
            BUGS_BUILT=()
            IFS=' ' read -r -a BUGS <<<"$(get_var_or_default "$FUZZER" "$TARGET" BUGS)"
            for BUG in "${BUGS[@]}"; do
                if [ -z "$SKIP_BUILDS" ]; then
                    export BUG
                    IMG_NAME=$(magma_image_name)
                    echo_time "Building $IMG_NAME"
                    LOGFILE="${LOGDIR}/${FUZZER}_${TARGET}_${BUG}_build.log"
                    if ! "$MAGMA"/tools/captain/build.sh &>"$LOGFILE"; then
                        echo_time "Failed to build $IMG_NAME. Check build log for info."
                        continue
                    fi
                fi
                BUGS_BUILT+=("$BUG")
            done
            # unset so it does not get passed to a call to build.sh that does not need it
            unset BUG
        elif [ -z "$SKIP_BUILDS" ]; then
            IMG_NAME=$(magma_image_name)
            echo_time "Building $IMG_NAME"
            LOGFILE="${LOGDIR}/${FUZZER}_${TARGET}_build.log"
            if ! "$MAGMA"/tools/captain/build.sh &>"$LOGFILE"; then
                echo_time "Failed to build $IMG_NAME. Check build log for info."
                continue
            fi
        fi

        if [ -n "$JUST_BUILD" ]; then
            continue
        fi

        IFS=' ' read -r -a PROGRAMS <<<"$(get_var_or_default "$FUZZER" "$TARGET" PROGRAMS)"
        for PROGRAM in "${PROGRAMS[@]}"; do
            export PROGRAM ARGS
            ARGS="$(get_var_or_default "$FUZZER" "$TARGET" "$PROGRAM" ARGS)"

            if [ -n "$DIRECTED" ]; then
                for BUG in "${BUGS_BUILT[@]}"; do
                    export BUG
                    echo_time "Starting campaigns for bug $BUG: $PROGRAM $ARGS"
                    for ((i = 0; i < REPEAT; i++)); do
                        export AFFINITY
                        AFFINITY=$(allocate_workers)
                        start_ex &
                    done
                done
                # same as above
                unset BUG
            else
                echo_time "Starting campaigns for $PROGRAM $ARGS"
                for ((i = 0; i < REPEAT; i++)); do
                    export AFFINITY
                    AFFINITY=$(allocate_workers)
                    start_ex &
                done
            fi
        done
    done
done
