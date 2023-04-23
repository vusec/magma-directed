#!/bin/bash -e
# shellcheck disable=SC2016

##
# Pre-requirements:
# - 1 or env ANALYSIS: analysis name (from fuzzers/)
# - 2 or env FUZZER: fuzzer name (from fuzzers/)
# - 3 or env TARGET: target name (from targets/)
# - 4 or env PROGRAM: program name (name of binary artifact from $TARGET/build.sh)
# - 5 or env ARGS: program launch arguments
# - 6 or env SHARED: path to host-local volume where fuzzer findings are saved
# - 7 or env ANALYSIS_OUT: path to move analysis output to
##

ANALYSIS="${1:-$ANALYSIS}"
FUZZER="${2:-$FUZZER}"
TARGET="${3:-$TARGET}"
PROGRAM="${4:-$PROGRAM}"
ARGS="${5:-$ARGS}"
SHARED="${6:-$SHARED}"
ANALYSIS_OUT="${7:-$ANALYSIS_OUT}"

MAGMA=${MAGMA:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/../../" >/dev/null 2>&1 && pwd)"}
export MAGMA
# shellcheck source=tools/captain/common.sh
source "$MAGMA/tools/captain/common.sh"

has_errors=0
if [ -z "$ANALYSIS" ] || [ ! -d "$MAGMA/fuzzers/$ANALYSIS" ]; then
    has_errors=1
    echo >&2 "\$ANALYSIS is required to be a folder in $MAGMA/fuzzers"
fi
if [ -z "$FUZZER" ] || [ ! -d "$MAGMA/fuzzers/$FUZZER" ]; then
    has_errors=1
    echo >&2 "\$FUZZER is required to be a folder in $MAGMA/fuzzers"
fi
if [ -z "$TARGET" ] || [ ! -d "$MAGMA/targets/$TARGET" ]; then
    has_errors=1
    echo >&2 "\$TARGET is required to be a folder in $MAGMA/targets"
fi
if [ -z "$PROGRAM" ]; then
    has_errors=1
    echo >&2 '$PROGRAM is required'
fi
if [ ! -d "$SHARED" ]; then
    has_errors=1
    echo >&2 "\$SHARED=$SHARED is not a directory"
fi
if [ -z "$ANALYSIS_OUT" ] || [ ! -d "$ANALYSIS_OUT" ]; then
    has_errors=1
    echo >&2 "\$ANALYSIS_OUT=$ANALYSIS_OUT is not a directory"
fi

if [ $has_errors = 1 ]; then
    exit 1
fi

ANALYSIS_ENTRYPOINT=${ANALYSIS_ENTRYPOINT:-'$FUZZER/analysis_entrypoint'}

cleanup() {
    docker rm -f "$container_id" 1>/dev/null 2>&1
}

trap cleanup EXIT

IMG_NAME="magma/$ANALYSIS/$TARGET"

flag_mount="--mount=type=bind,src=$(realpath "$SHARED"),dst=/magma_shared,readonly"
if docker --version 2>&1 | grep -q -i podman; then
    flag_mount="$flag_mount,U,Z"
fi

set -x
container_id=$(
    docker run -dt --entrypoint bash "$flag_mount" \
        --label="magma/$ANALYSIS/$FUZZER/$TARGET/$PROGRAM" \
        --env=PROGRAM="$PROGRAM" --env=ARGS="$ARGS" \
        --env=REAL_FUZZER="$FUZZER" \
        --env=ANALYSIS_OUT=/magma_out/analysis_out \
        "$IMG_NAME" -c "$ANALYSIS_ENTRYPOINT"
)
set +x
container_id=$(cut -c-12 <<<"$container_id")
echo_time "Container for $ANALYSIS/$FUZZER/$TARGET/$PROGRAM started in $container_id"
docker logs -f "$container_id" &
exit_code=$(docker wait "$container_id")
if [ "$exit_code" != 0 ]; then
    echo_time "Container exit code $exit_code"
    exit "$exit_code"
fi

echo_time "Copying analysis output into $ANALYSIS_OUT/ball.tar.gz"
docker cp "$container_id:/magma_out/analysis_out/ball.tar.gz" "$ANALYSIS_OUT/ball.tar.gz"
