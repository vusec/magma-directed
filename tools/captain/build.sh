#!/bin/bash -e

##
# Pre-requirements:
# - 1 or env FUZZER: fuzzer name (from fuzzers/)
# - env TARGET: target name (from targets/)
# + env MAGMA: path to magma root (default: ../../)
# + env ISAN: if set, build the benchmark with ISAN/fatal canaries (default:
#       unset)
# + env HARDEN: if set, build the benchmark with hardened canaries (default:
#       unset)
# + env BUG: set to a bug ID for directed fuzzing (default: unset)
##

FUZZER=${1:-$FUZZER}

if [ -z "$FUZZER" ] || [ -z "$TARGET" ]; then
    echo '$FUZZER and $TARGET must be specified as environment variables.'
    exit 1
fi
MAGMA=${MAGMA:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/../../" >/dev/null 2>&1 && pwd)"}
source "$MAGMA/tools/captain/common.sh"

has_errors=0
if [ ! -d "$MAGMA/fuzzers/$FUZZER" ]; then
    echo >&2 "Unknown fuzzer $FUZZER"
    has_errors=1
fi
if [ -n "$BUG" ] && [ ! -f "$(magma_patch_for_bug)" ]; then
    echo >&2 "Unknown bug $BUG"
    has_errors=1
fi
if [ $has_errors = 1 ]; then
    exit 1
fi

CANARY_MODE=${CANARY_MODE:-1}

case $CANARY_MODE in
1)
    mode_flag=(--build-arg canaries=1)
    ;;
2)
    mode_flag=()
    ;;
3)
    mode_flag=(--build-arg fixes=1)
    ;;
esac

if [ -n "$ISAN" ]; then
    isan_flag=(--build-arg isan=1)
fi
if [ -n "$HARDEN" ]; then
    harden_flag=(--build-arg harden=1)
fi
if [ -n "$BUG" ]; then
    bug_flag=(--build-arg "bug=$BUG")
fi

IMG_NAME=$(magma_image_name)

set -x
docker build \
    -t "$IMG_NAME" \
    --ssh default \
    --build-arg fuzzer_name="$FUZZER" \
    --build-arg target_name="$TARGET" \
    --build-arg USER_ID="$(id -u "$USER")" \
    --build-arg GROUP_ID="$(id -g "$USER")" \
    "${mode_flag[@]}" "${isan_flag[@]}" "${harden_flag[@]}" "${bug_flag[@]}" \
    -f "$MAGMA/docker/Dockerfile" "$MAGMA"
set +x

echo "$IMG_NAME"
