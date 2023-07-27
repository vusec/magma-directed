#!/bin/bash
set -e

##
# Pre-requirements:
# - env TARGET: path to target work dir
# - env OUT: path to directory where artifacts are stored
# - env CC, CXX, FLAGS, LIBS, etc...
# + env REQUIRE_BITCODE: set to require copying bitcode files into OUT
##

if [ ! -d "$TARGET/repo" ]; then
    echo "fetch.sh must be executed first."
    exit 1
fi

if [ -f "$FUZZER/configrc" ]; then
    source "$FUZZER/configrc"
fi

PAR_JOBS=${PAR_JOBS:-$(nproc)}

cd "$TARGET/repo"
export ONIG_CFLAGS="-I$PWD/oniguruma/src"
export ONIG_LIBS="-L$PWD/oniguruma/src/.libs -l:libonig.a"

# PHP's zend_function union is incompatible with the object-size sanitizer
export EXTRA_CFLAGS="$CFLAGS -fno-sanitize=object-size"
export EXTRA_CXXFLAGS="$CXXFLAGS -fno-sanitize=object-size"

unset CFLAGS
unset CXXFLAGS

#build the php library
./buildconf
LIB_FUZZING_ENGINE="-Wall" ./configure \
    --disable-all \
    --enable-option-checking=fatal \
    --enable-fuzzer \
    --enable-exif \
    --enable-phar \
    --enable-intl \
    --enable-mbstring \
    --without-pcre-jit \
    --disable-phpdbg \
    --disable-cgi \
    --with-pic

make -j"$PAR_JOBS" clean

# build oniguruma and link statically
pushd oniguruma
autoreconf -vfi
./configure --disable-shared
make -j"$PAR_JOBS"
popd

if [ "${#php_BUILD_PROGRAMS[@]}" -eq 0 ]; then
    php_BUILD_PROGRAMS=(json exif unserialize parser)
fi

programs=()
for p in "${php_BUILD_PROGRAMS[@]}"; do
    programs+=("sapi/fuzzer/php-fuzz-$p")
done

make -j"$PAR_JOBS" cli
for p in "${programs[@]}"; do
    make -j"$PAR_JOBS" "$p"
done

# Generate seed corpora
sapi/cli/php sapi/fuzzer/generate_unserialize_dict.php
sapi/cli/php sapi/fuzzer/generate_parser_corpus.php

for fuzzer_path in "${programs[@]}"; do
    f=$(basename "$fuzzer_path")
    cp -v "$fuzzer_path" "$OUT/${f/php-fuzz-/}"
    if [ -n "$REQUIRE_BITCODE" ]; then
        for bitcode in "$fuzzer_path"*.bc; do
            bitcode_f=$(basename "$bitcode")
            cp -v "$bitcode" "$OUT/${bitcode_f/php-fuzz-/}"
        done
    fi
done

for fuzzerName in `ls sapi/fuzzer/corpus`; do
    mkdir -p "$TARGET/corpus/${fuzzerName}"
    cp sapi/fuzzer/corpus/${fuzzerName}/* "$TARGET/corpus/${fuzzerName}/"
done
