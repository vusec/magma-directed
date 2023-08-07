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

cd "$TARGET/repo"
./autogen.sh \
	--with-http=no \
	--with-python=no \
	--with-lzma=yes \
	--with-threads=no \
	--disable-shared
make -j$(nproc) clean
make -j$(nproc) all

cp -v xmllint "$OUT/"
if [ -n "$REQUIRE_COPY_BITCODE" ]; then
    cp -v xmllint*.bc "$OUT/"
fi

for fuzzer in libxml2_xml_read_memory_fuzzer libxml2_xml_reader_for_file_fuzzer; do
  $CXX $CXXFLAGS -std=c++11 -Iinclude/ -I"$TARGET/src/" \
      "$TARGET/src/$fuzzer.cc" -o "$OUT/$fuzzer" \
      .libs/libxml2.a $LDFLAGS $LIBS -lz -llzma
done

if [ -n "$REQUIRE_GET_BITCODE" ]; then
    $REQUIRE_GET_BITCODE "$OUT/xmllint"
    $REQUIRE_GET_BITCODE "$OUT/libxml2_xml_read_memory_fuzzer"
    $REQUIRE_GET_BITCODE "$OUT/libxml2_xml_reader_for_file_fuzzer"
fi
