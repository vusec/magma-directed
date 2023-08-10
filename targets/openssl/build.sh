#!/bin/bash
set -ex

##
# Pre-requirements:
# - env TARGET: path to target work dir
# - env OUT: path to directory where artifacts are stored
# - env CC, CXX, FLAGS, LIBS, etc...
# + env REQUIRE_COPY_BITCODE: set to require copying bitcode files into OUT
# + env REQUIRE_GET_BITCODE: command to use to extract bitcode for each program
##

if [ ! -d "$TARGET/repo" ]; then
    echo "fetch.sh must be executed first."
    exit 1
fi

if [ -f "$FUZZER/configrc" ]; then
    # shellcheck source=/dev/null
    source "$FUZZER/configrc"
fi

PAR_JOBS=${PAR_JOBS:-$(nproc)}

# build the libpng library
cd "$TARGET/repo"

CONFIGURE_FLAGS=""
if [[ $CFLAGS = *sanitize=memory* ]]; then
  CONFIGURE_FLAGS="no-asm"
fi

# the config script supports env var LDLIBS instead of LIBS
export LDLIBS="$LIBS"

./config --debug enable-fuzz-libfuzzer enable-fuzz-afl disable-tests -DPEDANTIC \
    -DFUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION no-shared no-module \
    enable-tls1_3 enable-rc5 enable-md2 enable-ec_nistp_64_gcc_128 enable-ssl3 \
    enable-ssl3-method enable-nextprotoneg enable-weak-ssl-ciphers \
    -fno-sanitize=alignment $CONFIGURE_FLAGS

if [ "${#openssl_BUILD_PROGRAMS[@]}" -eq 0 ]; then
    # shellcheck source=targets/openssl/configrc
    source "$TARGET/configrc"
    openssl_BUILD_PROGRAMS=("${PROGRAMS[@]}")
fi

programs=()
for p in "${openssl_BUILD_PROGRAMS[@]}"; do
    programs+=("fuzz/$p")
done

make -j"$PAR_JOBS" clean
make -j"$PAR_JOBS" LDCMD="$CXX $CXXFLAGS" build_libs
make -j"$PAR_JOBS" LDCMD="$CXX $CXXFLAGS" "${programs[@]}"

# fuzzers=$(find fuzz -executable -type f '!' -name \*.py '!' -name \*-test '!' -name \*.pl)
for f in "${programs[@]}"; do
    fname=$(basename "$f")
    cp "$f" "$OUT/"
    if [ -n "$REQUIRE_COPY_BITCODE" ]; then
        cp "$f"*.bc "$OUT/"
    fi
    if [ -n "$REQUIRE_GET_BITCODE" ]; then
        $REQUIRE_GET_BITCODE "$OUT/$fname"
    fi
done
