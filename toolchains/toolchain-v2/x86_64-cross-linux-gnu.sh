#!/bin/sh

# Copyright (c) 2024, Michele Bucca
# Distributed under the terms of the ISC License

# Exit on error. We moved it here so it works
# even if the she script is called using a command like "sh -x scrpitname.sh"
set -e

# Versions
binutils_ver=2.41
gcc_ver=13.2.0
glibc_ver=2.38
gmp_ver=6.3.0
mpc_ver=1.3.1
mpfr_ver=4.2.0
linux_ver=6.4.12


cd $(dirname $0) ; CWD=$(pwd); SRC=$CWD/sources 
[ -f $CWD/env ] && . $CWD/env


TARGET=x86_64-cross-linux-gnu
INSTALL_DIR=$CWD/cross/$TARGET
WORK=$CWD/work/$TARGET
JOBS=$(nproc)
#JOBS=1

# CPU ARCH
#XARCH="armv8-a"

# Linux ARCH
LARCH=x86

# Extra configure parameters
# to pass when building GCC or GLIBC. By default they are empty
GCC_CONFIGURE_EXTRA=""
GLIBC_CONFIGURE_EXTRA=""
# Configure parameters that will be added to every build
COMMON_CONFIG=""

# Optimization - static
CC="gcc -static --static"
CXX="g++ -static --static"
export CC CXX

#CFLAGS="-Os -g0"
#CXXFLAGS="-Os -g0"
#LDDFLAGS="-s"
#export CFLAGS CXXFLAGS LDFLAGS

# Download Tarballs

mkdir -pv $CWD/downloads $SRC $WORK
cd $CWD/downloads

[ -z "$OFFLINE" ] && OFFLINE=0
if [  "$OFFLINE" = "0" ]; then
unset OFFLINE

wget -c https://sourceware.org/pub/binutils/releases/binutils-$binutils_ver.tar.xz
wget -c https://ftp.gnu.org/gnu/gcc/gcc-$gcc_ver/gcc-$gcc_ver.tar.xz
wget -c https://ftp.gnu.org/gnu/glibc/glibc-$glibc_ver.tar.xz
wget -c https://ftp.gnu.org/gnu/gmp/gmp-$gmp_ver.tar.xz
wget -c https://ftp.gnu.org/gnu/mpc/mpc-$mpc_ver.tar.gz
wget -c https://ftp.gnu.org/gnu/mpfr/mpfr-$mpfr_ver.tar.xz
wget -c https://www.kernel.org/pub/linux/kernel/v6.x/linux-$linux_ver.tar.xz
echo "OFFLINE=1" >> $CWD/env
fi
# Extract tarballs
[ -z "$EXTRACTED" ] && EXTRACTED=0
if [ "$EXTRACTED" = "0"  ]; then
unset EXTRACTED

for t in *.tar*; do tar --skip-old-files -xvf $t -C $SRC; done
echo "EXTRACTED=1" >> $CWD/env
fi

cd $SRC

# Prepare gcc source dir

cd gcc-$gcc_ver
ln -sf ../gmp-$gmp_ver gmp
ln -sf ../mpfr-$mpfr_ver mpfr
ln -sf ../mpc-$mpc_ver mpc

# Export PATH
export PATH=$INSTALL_DIR/bin:$PATH
cd $WORK

# Creating SYSROOT structure in $INSTALL_DIR/$TARGET
mkdir -p $INSTALL_DIR/$TARGET
# ln sometimes does not work, so we added this "OR true" to prevent the script from exiting
ln -sf . $INSTALL_DIR/$TARGET/usr || true 


# Build Binutils

echo "=> BINUTILS"
mkdir -p build-binutils
cd build-binutils

[ -z "$BINUTILS" ] && BINUTILS=0
if [ "$BINUTILS" = "0" ]; then
unset BINUTILS

$SRC/binutils-$binutils_ver/configure --with-sysroot=/$TARGET --prefix= --target=$TARGET --disable-multilib --disable-nls --enable-gprofng=no --enable-default-hash-style=gnu --disable-werror $COMMON_CONFIG
make -j$JOBS
make install-strip DESTDIR=$INSTALL_DIR
echo "BINUTILS=1" >> $CWD/env
fi 

# Build Linux Kernel Headers
echo "=> LINUX KERNEL HEADERS"

cd ../
mkdir -p build-headers
cd build-headers

[ -z "$KERNEL_HEADERS" ] && KERNEL_HEADERS=0
if [ "$KERNEL_HEADERS" = "0" ]; then
unset KERNEL_HEADERS

make -C $SRC/linux-$linux_ver mrproper

# make headers_install requires rsync now, so we use a different approach
#make -C ../linux-$linux_ver O=$(pwd) ARCH=x86_64 INSTALL_HDR_PATH=$INSTALL_DIR/$TARGET headers_install
make -C $SRC/linux-$linux_ver O=$(pwd) ARCH=x86_64 headers
find usr/include -type f ! -name '*.h' -delete
cp -rv usr/include $INSTALL_DIR/$TARGET
echo "KERNEL_HEADERS=1" >> $CWD/env
fi


# Build GCC (core only)
echo "=> GCC CORE"

cd ../
mkdir -p build-gcc
cd build-gcc

[ -z "$GCC_CORE" ] && GCC_CORE=0
if [ "$GCC_CORE" = "0" ]; then
unset GCC_CORE

# Disable libsanitizer is necessary to build GCC without libcrypt installed
$SRC/gcc-$gcc_ver/configure --prefix= --target=$TARGET --enable-languages=c,c++ --disable-nls --disable-multilib --with-build-sysroot=$INSTALL_DIR/$TARGET --with-sysroot=/$TARGET --disable-libsanitizer --disable-nls $COMMON_CONFIG $GCC_CONFIGURE_EXTRA
make -j$JOBS all-gcc
make install-strip-gcc DESTDIR=$INSTALL_DIR
echo "GCC_CORE=1" >> $CWD/env
fi

# Build GLIBC headers and startup files
echo "=> GLIBC HEADERS"

cd ../
mkdir -p build-glibc
cd build-glibc

[ -z "$LIBC_HEADERS" ] && LIBC_HEADERS=0
if [ "$LIBC_HEADERS" = "0" ]; then
unset LIBC_HEADERS

COMMON_CONFIG="" $SRC/glibc-$glibc_ver/configure --prefix=/usr --host=$TARGET --with-headers=$INSTALL_DIR/$TARGET/include --disable-multilib --disable-nls --disable-werror $GLIBC_CONFIGURE_EXTRA $COMMON_CONFIG
make -j$JOBS DESTDIR=$INSTALL_DIR/$TARGET install-bootstrap-headers=yes install-headers 
echo "LIBC_HEADERS=1" >> $CWD/env
fi

echo "=> GLIBC STARTUP FILES"
[ -z "$LIBC_CRT" ] && LIBC_CRT=0
if [ "$LIBC_CRT" = "0" ]; then
unset LIBC_CRT

make -j$JOBS csu/subdir_lib CC=gcc CXX=g++  
install csu/crt1.o csu/crti.o csu/crtn.o $INSTALL_DIR/$TARGET/lib
$TARGET-gcc -nostdlib -nostartfiles -shared  -x c /dev/null -o $INSTALL_DIR/$TARGET/lib/libc.so
touch $INSTALL_DIR/$TARGET/include/gnu/stubs.h
echo "LIBC_CRT=1" >> $CWD/env
fi

# Build libgcc
echo "=> LIBGCC"

cd ../build-gcc

[ -z "$LIBGCC" ] && LIBGCC=0
if [ "$LIBGCC" = "0" ]; then
unset LIBGCC

make -j$JOBS all-target-libgcc
make install-strip-target-libgcc DESTDIR=$INSTALL_DIR
echo "LIBGCC=1" >> $CWD/env
fi

# Finish building glibc
echo "=> FINISH GLIBC"

cd ../build-glibc

[ -z "$GLIBC" ] && GLIBC=0
if [ "$GLIBC" = "0" ]; then
unset GLIBC
make -j$JOBS CC=gcc CXX=g++
make install DESTDIR=$INSTALL_DIR/$TARGET
echo "GLIBC=1" >> $CWD/env
fi

# Finish building GCC
echo "=> FINISH GCC"
cd ../build-gcc

[ -z "$GCC" ] && GCC=0
if [ "$GCC" = "0" ]; then
unset GCC

make -j$JOBS
make install-strip DESTDIR=$INSTALL_DIR
cat $SRC/gcc-$gcc_ver/gcc/limitx.h $SRC/gcc-$gcc_ver/gcc/glimits.h $SRC/gcc-$gcc_ver/gcc/limity.h > \
  $INSTALL_DIR/lib/gcc/$TARGET/$gcc_ver/include/limits.h
echo "GCC=1" >> $CWD/env

fi
echo  -e "\n FINISHED SUCCESSFULLY"

