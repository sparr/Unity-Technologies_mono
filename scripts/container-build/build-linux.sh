#!/bin/sh
# Runs inside the Linux build container with an unconfigured source tree at /src.
# FULL_VERSION is embedded in the library, e.g. 2019.4.18f1-gc-roots-fix.2/6015e75b7b
#
# ac_cv_func_getrandom/getentropy=no: use /dev/urandom like the stock library,
# avoiding a GLIBC_2.25 dependency.
# -fPIC: bdwgc builds libgc-static.la with -static (non-PIC), but it is linked
# into the shared runtime.
set -e
: "${FULL_VERSION:?set FULL_VERSION}"
cd /src
NOCONFIGURE=1 ./autogen.sh > autogen.log 2>&1
./configure --host=x86_64-pc-linux-gnu --disable-mcs-build --with-glib=embedded \
  --disable-nls --disable-btls --with-mcs-docs=no --with-unityjit=yes \
  --with-unityaot=yes --disable-parallel-mark --disable-boehm \
  --prefix=/src/_install ac_cv_func_getrandom=no ac_cv_func_getentropy=no \
  CFLAGS='-Os -g -std=gnu11 -fcommon -fPIC' CXXFLAGS='-Os -g -std=gnu++14 -fcommon -fPIC' \
  > configure.log 2>&1
# The version.h rule depends on mono/mini/Makefile; keep this copy newer so make keeps it.
echo "#define FULL_VERSION \"$FULL_VERSION\"" > mono/mini/version.h
touch -d '+1 hour' mono/mini/version.h
make -j"$(nproc)" > make.log 2>&1
mkdir -p _out
strip -o _out/libmonobdwgc-2.0.so mono/mini/.libs/libmonobdwgc-2.0.so
glibc=$(objdump -T _out/libmonobdwgc-2.0.so | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -n 1)
echo "_out/libmonobdwgc-2.0.so requires $glibc"
