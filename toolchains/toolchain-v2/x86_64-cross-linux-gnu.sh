#!/bin/sh -e

# Copyright (c) 2024, Michele Bucca
# Distributed under the terms of the ISC License

# Versions
binutils_ver=2.41
gcc_ver=13.2.0
glibc_ver=2.38
gmp_ver=6.3.0
mpc_ver=1.3.1
mpfr_ver=4.2.0
linux_ver=6.4.12


cd $(dirname $0) ; CWD=$(pwd); SRC=$CWD/sources; WORK=$CWD/work/$TARGET

INSTALL_DIR=$CWD/cross
TARGET=x86_64-cross-linux-gnu

# Linux ARCH
LARCH=x86_64

# Extra configure parameters
# to pass when building GCC. By default is empty
GCC_CONFIGURE_EXTRA=""
# Configure parameters that will be added to every build
COMMON_CONFIG=""

# Download Tarballs

mkdir -p $CWD/downloads $SRC $WORK
cd $CWD/downloads
wget -c https://sourceware.org/pub/binutils/releases/binutils-$binutils_ver.tar.xz
wget -c https://ftp.gnu.org/gnu/gcc/gcc-$gcc_ver/gcc-$gcc_ver.tar.xz
wget -c https://ftp.gnu.org/gnu/glibc/glibc-$glibc_ver.tar.xz
wget -c https://ftp.gnu.org/gnu/gmp/gmp-$gmp_ver.tar.xz
wget -c https://ftp.gnu.org/gnu/mpc/mpc-$mpc_ver.tar.gz
wget -c https://ftp.gnu.org/gnu/mpfr/mpfr-$mpfr_ver.tar.xz
wget -c https://www.kernel.org/pub/linux/kernel/v6.x/linux-$linux_ver.tar.xz

# Extract tarballs
for t in *.tar*; do tar --skip-old-files -xvf $t -C $SRC; done
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
mkdir -p build-binutils
cd build-binutils

$SRC/binutils-$binutils_ver/configure --prefix=$INSTALL_DIR --with-sysroot --target=$TARGET --disable-multilib --disable-nls --disable-werror $COMMON_CONFIG
make -j$(nproc)
make install-strip 

# Build Linux Kernel Headers

cd ../
mkdir -p build-headers
cd build-headers
make -C $SRC/linux-$linux_ver mrproper

# make headers_install requires rsync now, so we use a different approach
#make -C ../linux-$linux_ver O=$(pwd) ARCH=x86_64 INSTALL_HDR_PATH=$INSTALL_DIR/$TARGET headers_install
make -C $SRC/linux-$linux_ver O=$(pwd) ARCH=x86_64 headers
find usr/include -type f ! -name '*.h' -delete
cp -rv usr/include $INSTALL_DIR/$TARGET



# Build GCC (core only)
cd ../
mkdir -p build-gcc
cd build-gcc
# Disable libsanitizer is necessary to build GCC without libcrypt installed
$SRC/gcc-$gcc_ver/configure --prefix=$INSTALL_DIR --target=$TARGET --enable-languages=c,c++ --disable-nls --disable-multilib --disable-libsanitizer $COMMON_CONFIG $GCC_CONFIGURE_EXTRA
make -j$(nproc) all-gcc
make install-strip-gcc

# Build GLIBC headers and startup files
cd ../
mkdir -p build-glibc
cd build-glibc
$SRC/glibc-$glibc_ver/configure --prefix=$INSTALL_DIR/$TARGET --host=$TARGET --with-headers=$INSTALL_DIR/$TARGET/include --disable-multilib --disable-nls $COMMON_CONFIG
make -j$(nrpoc) install-bootstrap-headers=yes install-headers
make -j$(nproc) csu/subdir_lib
install csu/crt1.o csu/crti.o csu/crtn.o $INSTALL_DIR/$TARGET/lib
$TARGET-gcc -nostdlib -nostartfiles -shared  -x c /dev/null -o $INSTALL_DIR/$TARGET/lib/libc.so
touch $INSTALL_DIR/$TARGET/include/gnu/stubs.h

# Build libgcc
cd ../build-gcc
make -j$(nproc) all-target-libgcc
make install-strip-target-libgcc

# Finish building glibc
cd ../build-glibc
make -j$(nproc)
make install

# Finish building GCC
cd ../build-gcc
make -j$(nproc)
make install-strip

echo  -e "\n FINISHED SUCCESSFULLY"

