#!/bin/bash -ex
# shellcheck disable=SC2086

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

export WORK="$TARGET/work"
rm -rf "$WORK"
mkdir -p "$WORK"
mkdir -p "$WORK/lib" "$WORK/include"

pushd "$TARGET/freetype2"
./autogen.sh
./configure --prefix="$WORK" --disable-shared PKG_CONFIG_PATH="$WORK/lib/pkgconfig"
make -j"$(nproc)" clean
make -j"$(nproc)"
make install

mkdir -p "$WORK/poppler"
cd "$WORK/poppler"
rm -rf ./*

EXTRA=""
test -n "$AR" && EXTRA="$EXTRA -DCMAKE_AR=$AR"
test -n "$RANLIB" && EXTRA="$EXTRA -DCMAKE_RANLIB=$RANLIB"

cmake "$TARGET/repo" \
    $EXTRA \
    -DCMAKE_BUILD_TYPE=debug \
    -DBUILD_SHARED_LIBS=OFF \
    -DFONT_CONFIGURATION=generic \
    -DBUILD_GTK_TESTS=OFF \
    -DBUILD_QT5_TESTS=OFF \
    -DBUILD_CPP_TESTS=OFF \
    -DENABLE_LIBPNG=ON \
    -DENABLE_LIBTIFF=ON \
    -DENABLE_LIBJPEG=ON \
    -DENABLE_SPLASH=ON \
    -DENABLE_UTILS=ON \
    -DWITH_Cairo=ON \
    -DENABLE_CMS=none \
    -DENABLE_LIBCURL=OFF \
    -DENABLE_GLIB=OFF \
    -DENABLE_GOBJECT_INTROSPECTION=OFF \
    -DENABLE_QT5=OFF \
    -DENABLE_LIBCURL=OFF \
    -DWITH_NSS3=OFF \
    -DFREETYPE_INCLUDE_DIRS="$WORK/include/freetype2" \
    -DFREETYPE_LIBRARY="$WORK/lib/libfreetype.a" \
    -DICONV_LIBRARIES="/usr/lib/x86_64-linux-gnu/libc.so" \
    -DCMAKE_EXE_LINKER_FLAGS_INIT="$LIBS"

if [ "${#poppler_BUILD_PROGRAMS[@]}" -eq 0 ]; then
    # shellcheck source=targets/poppler/configrc
    source "$TARGET/configrc"
    poppler_BUILD_PROGRAMS=("${PROGRAMS[@]}")
fi

programs=()
for program in "${poppler_BUILD_PROGRAMS[@]}"; do
    if [[ $program =~ ^(pdfimages|pdftoppm)$ ]]; then
        programs+=("$program")
        poppler_BUILD_PROGRAMS=("${poppler_BUILD_PROGRAMS[@]/$program/}")
    fi
done

make -j"$(nproc)" poppler poppler-cpp "${programs[@]}"
EXTRA=""

for program in "${programs[@]}"; do
    cp -v "$WORK/poppler/utils/$program" "$OUT/"
    if [ -n "$REQUIRE_COPY_BITCODE" ]; then
        cp -v "$WORK/poppler/utils/$program"*.bc "$OUT/"
    fi
    if [ -n "$REQUIRE_GET_BITCODE" ]; then
        $REQUIRE_GET_BITCODE "$OUT/$program"
    fi
done

for program in "${poppler_BUILD_PROGRAMS[@]}"; do
    if [ "$program" = pdf_fuzzer ]; then
        $CXX $CXXFLAGS -std=c++11 -I"$WORK/poppler/cpp" -I"$TARGET/repo/cpp" \
            "$TARGET/src/pdf_fuzzer.cc" -o "$OUT/pdf_fuzzer" \
            "$WORK/poppler/cpp/libpoppler-cpp.a" "$WORK/poppler/libpoppler.a" \
            "$WORK/lib/libfreetype.a" $LDFLAGS $LIBS -ljpeg -lz \
            -lopenjp2 -lpng -ltiff -llcms2 -lm -lpthread -pthread
        if [ -n "$REQUIRE_GET_BITCODE" ]; then
            $REQUIRE_GET_BITCODE "$OUT/pdf_fuzzer"
        fi
    fi
done
