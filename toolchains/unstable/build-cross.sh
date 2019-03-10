#!/bin/bash

# exit on Error
set -ex

# Speedup Compiling by disabling optimization and by using multiple threads
export MAKEFLAGS="-j2"
export CFLAGS="-g0 -O0"
export CXXFLAGS="-g0 -O0"

TOP=$PWD
SRC=$TOP/src/
TARGET=i486-linux-musl
OBJ=$TOP/obj
OUT=$TOP/out
ARCH=x86
export PATH=$OUT/bin:$PATH

# Create output directories
mkdir -p $SRC $OBJ $OUT/$TARGET
#ln -sf . $OUT/$TARGET/usr

# Linux Headers
cd $SRC/linux
make mrproper
make ARCH=$ARCH headers_check
make ARCH=$ARCH INSTALL_HDR_PATH=$OUT/$TARGET/ headers_install

# Binutils
mkdir -p $OBJ/build-binutils
cd $OBJ/build-binutils
$SRC/binutils/configure --prefix=$OUT --target=$TARGET --disable-shared --disable-nls --disable-multilib --disable-werror
make
make install

# GCC 1
mkdir -p $OBJ/build-gcc
cd $OBJ/build-gcc
$SRC/gcc/configure --prefix=$OUT --target=$TARGET --enable-languages=c,c++ --disable-nls --disable-multilib --with-newlib --without-headers --disable-werror --disable-decimal-float --disable-threads --disable-libatomic --disable-libgomp --disable-libmpx --disable-libquadmath --disable-libssp --disable-libvtv --disable-libstdcxx --disable-libsanitizer --disable-shared
make
make install

# Libc
cd $SRC/libc 
./configure --host=$TARGET --disable-shared --prefix=$OUT/$TARGET/
make
make install

# LibstdC++
mkdir -p $OBJ/build-libstdcxx
cd $OBJ/build-libstdcxx
$SRC/gcc/libstdc++v3/configure --host=$TARGET --prefix=$OUT/$TARGET --disable-nls --disable-shared --disable-multilib --disable-libstdcxx-threads --disable-libstdcxx-pch
make
make install