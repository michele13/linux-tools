#!/bin/sh
set -eux

# --- ENVIRONMENT VARIABLES --- #

# Main Environment Variables
BUILDROOT=$(pwd)
TCDIR="$BUILDROOT/toolchain"
SYSROOT="$TCDIR/sysroot"
SOURCES="$BUILDROOT/sources"
STAGE="$BUILDROOT/build/stage"
export PATH="$TCDIR/bin:$PATH"

# Environment Variables for toolchain build
HOST="$(uname -m)-linux-gnu"
TARGET="$(uname -m)-lfs-linux-gnu"
LINUX_ARCH=x86

# Compiler flags
export CFLAGS="-Os -g0"
export CXXFLAGS="-Os -g0"
export LDFLAGS="-s"

# --- FUNCTIONS --- #

# This function extract a source tarball into an empty directory
# thanks to this we don't need to know the extension of the tarball
# or the version of the program
extract_sources() (
mkdir -p $BUILDROOT/sources/$1
tar xf $BUILDROOT/sources/$1*.tar.* -C $BUILDROOT/sources/$1/
)

# This function will print the path where the sources of a package are
# located. Usually they are unpacked into a subdirectory that has the name of
# the package (eg $BUILDROOT/binutils/binutils-2.34)
findsrc() (
ls -d $BUILDROOT/sources/$1/*
)

# --- THE SCRIPTS BEGINS HERE --- #


# Remove previous build directory and create directory structure if not present
rm -rf "build"
mkdir -p "$TCDIR/bin" "build" "$SOURCES" "$SYSROOT"

# Downloading sources
wget -c -P "$BUILDROOT/sources" http://www.linuxfromscratch.org/lfs/downloads/stable/wget-list
wget -c -P "$BUILDROOT/sources" -i "$BUILDROOT/sources/wget-list"
wget -c -P "$BUILDROOT/sources" https://musl.libc.org/releases/musl-1.2.2.tar.gz
wget -c -P "$BUILDROOT/sources" https://www.busybox.net/downloads/busybox-1.34.1.tar.bz2

# Build SYSROOT filesystem hierarchy
mkdir -p "$SYSROOT/bin" "$SYSROOT/lib"
mkdir -p "$SYSROOT/usr/share" "$SYSROOT/usr/include"

[ ! -e "$SYSROOT/usr/bin" ] && ln -s "../bin" "$SYSROOT/usr/bin" 2>/dev/null || true
[ ! -e "$SYSROOT/usr/lib" ] && ln -s "../lib" "$SYSROOT/usr/lib" 2>/dev/null || true
[ ! -e "$SYSROOT/lib64" ] && ln -s lib $SYSROOT/lib64 2>/dev/null || true
[ ! -e "$SYSROOT/usr/lib64" ] && ln -s lib $SYSROOT/usr/lib64 2>/dev/null || true

# Build Cross Compiler

echo "1. Kernel Headers"
extract_sources linux
export KBUILD_OUTPUT="$BUILDROOT/build/linux/"
mkdir -p "$KBUILD_OUTPUT"
cd `findsrc linux`
make O="$KBUILD_OUTPUT" ARCH="$LINUX_ARCH" headers_check
make O="$KBUILD_OUTPUT" ARCH="$LINUX_ARCH" INSTALL_HDR_PATH="$SYSROOT/usr" headers_install
cd "$BUILDROOT"

echo "2. cross-binutils"
extract_sources binutils
mkdir -p $BUILDROOT/build/binutils	
cd $BUILDROOT/build/binutils
srcdir="$(findsrc binutils)"
$srcdir/configure --prefix="$TCDIR" --target="$TARGET" \
    --disable-nls --disable-multilib
make configure-host
make -j$(nproc)
make install
cd $BUILDROOT

echo "3. cross-gcc (compiler)"
extract_sources gcc
extract_sources gmp
extract_sources mpc
extract_sources mpfr
srcdir="$(findsrc gcc)"
ln -s `findsrc gmp` $srcdir/gmp || true
ln -s `findsrc mpc` $srcdir/mpc || true
ln -s `findsrc mpfr` $srcdir/mpfr || true
mkdir -p $BUILDROOT/build/gcc
cd $BUILDROOT/build/gcc
$srcdir/configure --prefix="$TCDIR" --target="$TARGET" --build="$HOST" --host="$HOST" \
    --with-sysroot="$SYSROOT" --disable-nls --disable-libsanitizer --disable-libmpx \
    --disable-multilib --enable-languages=c,c++
make -j$(nproc) all-gcc
make install-gcc
cd $BUILDROOT

echo "4. GLibc Headers and Startup files"
extract_sources glibc
srcdir="$(findsrc glibc)"
mkdir -p $BUILDROOT/build/glibc
cd $BUILDROOT/build/glibc
$srcdir/configure --host="$TARGET" --prefix=/usr \
     --build=$($srcdir/scripts/config.guess) \
     --with-headers=$SYSROOT/usr/include \
     --disable-werror
     
make install-headers DESTDIR=$SYSROOT
# These files are needed to build libgcc
touch $SYSROOT/usr/include/gnu/stubs.h

# Startup files and libc.so stub
make -j$(nproc) csu/subdir_lib
install csu/crt1.o csu/crti.o csu/crtn.o $SYSROOT/usr/lib
$TARGET-gcc -nostdlib -nostartfiles -shared -x c /dev/null -o $SYSROOT/usr/lib/libc.so

echo "5. cross-gcc (libgcc)"
cd $BUILDROOT/build/gcc
make -j$(nproc) all-target-libgcc
make install-target-libgcc

echo "6. GLibc (full)"
cd $BUILDROOT/build/glibc
make -j$(nproc)
make DESTDIR=$SYSROOT install

echo "7. cross-gcc (all)"
cd $BUILDROOT/build/gcc
make -j$(nproc)
make install

# When we built GCC it has installed a partial version of `limits.h` internal header
# with the following commands we are going to install the full internal header
srcdir="$(findsrc gcc)"
cat $srcdir/gcc/limitx.h $srcdir/glimits.h gcc/limity.h >
  `dirname $($TARGET-gcc -print-libgcc-file-name)`/install-tools/include/limits.h
gcc_ver=`$TARGET-gcc -v 2>&1 | tail -n1 | cut -d" " -f3`
$TCDIR/libexec/gcc/$TARGET/$gcc_ver/install-tools/mkheaders

