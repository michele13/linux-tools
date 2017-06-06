#!/bin/bash

#exit on error and show commands for debugging
set -ex

#turn off bash's hash function
set +h

TOP=$(PWD)
TRIPLE=arm-linux-musleabi
PREFIX=$TOP/output
ARM_ARCH=armv7
TARGET_ARCH=arm
export PATH=${PREFIX}/bin:$PATH

#download
mkdir $TOP/dl && cd $TOP/dl
wget -c -i ../dl.list

#prefix
mkdir -p ${PREFIX}/${TRIPLE}
ln -s . ${PREFIX}/${TRIPLE}/usr

#make temp directory to unpack and build the toolchain
mkdir $TOP/tmp && cd $TOP/tmp

#Linux headers
tar xf $TOP/dl/linux-*.tar.*
cd linux-*
make mrproper
make ARCH=${TARGET_ARCH} headers_check
make ARCH=${TARGET_ARCH} INSTALL_HDR_PATH=${PREFIX}/${TRIPLE} headers_install

#binutils
tar xf $TOP/dl/binutils-*.tar.*
cd binutils-*
mkdir build && cd build
../configure --target=${TRIPLE} --prefix=${PREFIX} --disable-nls --disable-multilib
make
make install

cd $TOP/tmp

#GCC1
tar xf $TOP/dl/gcc-*.tar.*
cd gcc-*
tar xf $TOP/dl/gmp-*.tar.*
mv gmp-* gmp
tar xf $TOP/dl/mpfr-*.tar.*
mv mpfr-* mpfr
tar xf $TOP/dl/mpc-*.tar.*
mv mpc-* mpc
mkdir ../build-gcc && cd ../build-gcc
../gcc-*/configure --target=${TRIPLE} --prefix=${PREFIX} --disable-nls --disable-shared --disable-multilib --with-newlib --disable-headers --disable-libmudflap --disable-libgomp --disable-decimal-float --disable-libquadmath --disable-threads --disable-libssp --disable-libatomic --disable-libstdcxx --disable-libsanitizer --with-float=soft --with-arch=${ARM_ARCH} --enable-languages=c.c++
make all-gcc all-target-libgcc
make install-gcc install-target-libgcc

cd $TOP/tmp

#Musl

tar xf $TOP/dl/musl-*.tar.*
cd musl-*
CC=${TRIPLE}-gcc ./configure --prefix=/ --target=${TRIPLE}
CC=${TRIPLE}-gcc make
DESTDIR=${PREFIX}/${TRIPLE} make install

cd $TOP/tmp

#GCC2
rm -rf $TOP/build-gcc/*
cd $TOP/build-gcc/
../gcc-*/configure --target=${TRIPLE} --prefix=${PREFIX} --disable-nls --enalbe-languages=c,c++ --enable-c99 --enable-long-long --disable-libmudflap --disable-multilib --disable-libmpx --fith-float=soft --with-arch=${ARM_ARCH}
make
make install