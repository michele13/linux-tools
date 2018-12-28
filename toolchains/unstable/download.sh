#!/bin/bash

LINUX_VER=4.19.12
GLIBC_VER=2.28
MUSL_VER=1.1.20
GMP_VER=6.1.2
MPC_VER=1.1.0
MPFR_VER=4.0.1
BINUTILS_VER=2.31.1
GCC_VER=8.2.0


if [ ! -d sources ]; then mkdir sources; fi
cd sources

wget -c https://www.kernel.org/pub/linux/kernel/v4.x/linux-$LINUX_VER.tar.xz
wget -c http://ftp.gnu.org/gnu/glibc/glibc-$GLIBC_VER.tar.xz
wget -c http://ftp.gnu.org/gnu/gmp/gmp-$GMP_VER.tar.xz
wget -c https://ftp.gnu.org/gnu/mpc/mpc-$MPC_VER.tar.gz
wget -c http://www.mpfr.org/mpfr-$MPFR_VER/mpfr-$MPFR_VER.tar.xz
wget -c http://ftp.gnu.org/gnu/binutils/binutils-$BINUTILS_VER.tar.xz
wget -c http://ftp.gnu.org/gnu/gcc/gcc-$GCC_VER/gcc-$GCC_VER.tar.xz
wget -c https://www.musl-libc.org/releases/musl-$MUSL_VER.tar.gz

echo "Extracting Linux sources"
tar xf linux-$LINUX_VER.tar.xz
mv -v linux-$LINUX_VER linux

echo "Extracting Glibc sources"
tar xf glibc-$GLIBC_VER.tar.xz
mv -v glibc-$GLIBC_VER glibc

echo "Extracting Musl sources"
tar xf musl-$MUSL_VER.tar.gz
mv -v musl-$MUSL_VER musl

echo "Extractiong GMP sources"
tar xf gmp-$GMP_VER.tar.xz
mv -v gmp-$GMP_VER gmp

echo "Extracting MPC sources"
tar xf mpc-$MPC_VER.tar.gz
mv -v mpc-$MPC_VER mpc

echo "Extracting MPFR sources"
tar xf mpfr-$MPFR_VER.tar.xz
mv -v mpfr-$MPFR_VER mpfr

echo "Extracting Binutils sources"
tar xf binutils-$BINUTILS_VER.tar.xz
mv -v binutils-$BINUTILS_VER binutils

echo "Extracting GCC sources"
tar xf gcc-$GCC_VER.tar.xz
mv -v gcc-$GCC_VER gcc

ln -sv ../mpfr gcc/mpfr
ln -sv ../mpc gcc/mpc
ln -sv ../gmp gcc/gmp
