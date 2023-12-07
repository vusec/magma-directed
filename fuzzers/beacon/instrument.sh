#!/bin/bash
# shellcheck disable=SC2030,SC2031
set -ex

##
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
# - env TARGET: path to target work dir
# - env MAGMA: path to Magma support files
# - env OUT: path to directory where artifacts are stored
# - env CFLAGS and CXXFLAGS must be set to link against Magma instrumentation
##

(
    # make bitcode
    export LLVM_COMPILER=clang
    export CC=wllvm
    export CXX=wllvm++
    export LIBS="$LIBS -l:driver.o -lstdc++"
    # shellcheck disable=SC2086
    $CXX $CXXFLAGS -c "$FUZZER/src/driver.cpp" -fPIC -o "$OUT/driver.o"
    "$MAGMA/build.sh"
    REQUIRE_GET_BITCODE=extract-bc \
        "$TARGET/build.sh"
    if [[ "$TARGET" == *"/openssl" ]]; then
        cp "$TARGET/repo/libcrypto.a" "$OUT/libcrypto.a"
        cp "$TARGET/repo/libssl.a" "$OUT/libssl.a"
    fi
)

MODERN_BITCODE="$OUT/modern_bitcode"

(
    # make bitcode for external SVF
    LLVM_VERSION=15
    export LLVM_COMPILER=clang
    export LLVM_CC_NAME=clang-$LLVM_VERSION
    export LLVM_CXX_NAME=clang++-$LLVM_VERSION
    export CC=wllvm
    export CXX=wllvm++
    export LIBS="$LIBS -l:driver.o -lstdc++"
    export CFLAGS="$CFLAGS -Xclang -no-opaque-pointers"
    export CXXFLAGS="$CXXFLAGS -Xclang -no-opaque-pointers"
    rm -rf "$MODERN_BITCODE"
    mkdir -p "$MODERN_BITCODE"
    OUT="$MODERN_BITCODE"
    # shellcheck disable=SC2086
    $CXX $CXXFLAGS -c "$FUZZER/src/driver.cpp" -fPIC -o "$OUT/driver.o"
    "$MAGMA/build.sh"
    REQUIRE_GET_BITCODE="extract-bc -l llvm-link-$LLVM_VERSION -a llvm-ar-$LLVM_VERSION" \
        "$TARGET/build.sh"
)

# extract target locations
TARGET_NAME="$(basename "$TARGET")"

# shellcheck source=magma/directed.sh
source "$MAGMA/directed.sh"

MAGMA_LOG_LINES="$OUT/magma_log_lines.txt"
store_magma_log_lines "$MAGMA_LOG_LINES"

TARGETS_FILE="$OUT/beacon_targets.txt"
make_magma_log_lines_unique "$MAGMA_LOG_LINES" >"$TARGETS_FILE"

TARGETS_JUST_FILENAME="$(rev "$TARGETS_FILE" | cut -d/ -f1 | rev)"

set +x

(
    printf "\n########\n\nUsing targets:\n"
    cat "$TARGETS_FILE"
    printf "\nW/o path:\n%s\n" "$TARGETS_JUST_FILENAME"
    printf "\n########\n\n"
) >&2

check_unique_targets "$TARGETS_FILE"

set -x

# instrument bitcode

# shellcheck source=/dev/null
source "$TARGET/configrc"

meta_var() {
    local name value
    name="$(eval echo "$1")"
    name="${name}[@]"
    value="${!name}"
    echo "${value[@]}"
}

if [ -f "$FUZZER/configrc" ]; then
    # shellcheck source=/dev/null
    source "$FUZZER/configrc"
    if [[ -v "${TARGET_NAME}_BUILD_PROGRAMS" ]]; then
        # shellcheck disable=SC2207     # items should not contain spaces
        PROGRAMS=($(meta_var "${TARGET_NAME}_BUILD_PROGRAMS"))
    fi
fi

for p in "${PROGRAMS[@]}"; do
    folder="$OUT/output-$p"
    rm -rf "$folder"
    mkdir -p "$folder"
    cd "$folder"

    "$FUZZER/repo/precondInfer/build/bin/precondInfer" \
        "$OUT/$p.bc" --target-file="$TARGETS_FILE" --join-bound=5

    "$FUZZER/SVF/Release-build/bin/wpa" -ander -dump-icfg "$MODERN_BITCODE/$p.bc"
    # "$FUZZER/src/icfg_index.py" "$TARGETS_JUST_FILENAME" icfg_final.dot
    "$FUZZER/reachability-fast" "$TARGETS_JUST_FILENAME" icfg_final.dot bbreaches-external-svf.txt

    # -byte \
    # -blocks="$folder/bbreaches.txt" \
    "$FUZZER/repo/Ins/build/Ins" \
        -afl \
        -src \
        -blocks="$folder/bbreaches-external-svf.txt" \
        -load="$folder/range_res.txt" \
        -log="$folder/Ins.log" \
        -output="$folder/fuzz.bc" \
        "$folder/transed.bc"

    plibs='-lstdc++ -lrt'
    if [[ -v "PROGRAM_LIBS[$p]" ]]; then
        for lib in ${PROGRAM_LIBS[$p]}; do
            if [[ $plibs != *"$lib"* ]]; then
                plibs="$plibs $lib"
            fi
        done
    fi

    # shellcheck disable=SC2086
    clang++ $CXXFLAGS "$folder/fuzz.bc" \
        -o "$OUT/$p" \
        "$FUZZER/repo/Fuzzer/afl-llvm-rt.o" \
        $LDFLAGS \
        $plibs
done
