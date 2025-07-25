#!/bin/bash -e

##
# Pre-requirements:
# - env FUZZER: fuzzer name (from fuzzers/)
# - env TARGET: target name (from targets/)
# - env PROGRAM: program name (name of binary artifact from $TARGET/build.sh)
# - env ARGS: program launch arguments
# - env FUZZARGS: fuzzer arguments
# - env POLL: time (in seconds) between polls
# - env TIMEOUT: time to run the campaign
# + env BUG: determines the image name (defaul: unset)
# + env STOP_ON_BUG: if set, stop the campaign when the target/all bugs are triggered
# + env SHARED: path to host-local volume where fuzzer findings are saved
#       (default: no shared volume)
# + env AFFINITY: the CPU to bind the container to (default: no affinity)
# + env ENTRYPOINT: a custom entry point to launch in the container (default:
#       $MAGMA/run.sh)
##

cleanup() {
    if [ ! -t 1 ]; then
        docker rm -f "$container_id" &>/dev/null
    fi
    exit 0
}

trap cleanup EXIT SIGINT SIGTERM

if [ -z "$FUZZER" ] || [ -z "$TARGET" ] || [ -z "$PROGRAM" ]; then
    echo '$FUZZER, $TARGET, and $PROGRAM must be specified as' \
        'environment variables.'
    exit 1
fi

MAGMA=${MAGMA:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/../../" >/dev/null 2>&1 && pwd)"}
export MAGMA
source "$MAGMA/tools/captain/common.sh"

IMG_NAME=$(magma_image_name)
flags=(--cap-add=SYS_PTRACE --security-opt seccomp=unconfined
    --env=PROGRAM="$PROGRAM" --env=ARGS="$ARGS"
    --env=FUZZARGS="$FUZZARGS" --env=POLL="$POLL"
    --env=TIMEOUT="$TIMEOUT" --env=STOP_ON_BUG="$STOP_ON_BUG")

if [ -n "$AFFINITY" ]; then
    flags+=(--cpuset-cpus="$AFFINITY" --env=AFFINITY="$AFFINITY")
fi

if [ -n "$ENTRYPOINT" ]; then
    flags+=(--entrypoint="$ENTRYPOINT")
fi

if [ -n "$SHARED" ]; then
    SHARED="$(realpath "$SHARED")"
    flag_volume="--volume=$SHARED:/magma_shared"
    if docker --version 2>&1 | grep -q -i podman; then
        flag_volume="$flag_volume:U,Z"
    fi
    flags+=("$flag_volume")
fi

if [ -t 1 ]; then
    set -x
    docker run -it "${flags[@]}" "$IMG_NAME"
    set +x
else
    set -x
    container_id=$(
        docker run -dt "${flags[@]}" --network=none "$IMG_NAME"
    )
    set +x
    container_id=$(cut -c-12 <<<"$container_id")
    echo_time "Container for $FUZZER/$TARGET${BUG:+/$BUG}/$PROGRAM started in $container_id"
    docker logs -f "$container_id" &
    exit_code=$(docker wait "$container_id")
    exit "$exit_code"
fi
