=======================
LFS FROM CROSS COMPILER
=======================

We compile LFS using only busybox and a cross-compiler


1- Prerequisites
================

Setting up environment
----------------------

first, when you setup your environment,
 you need to export CC CXX AR AS LD OBJDUMP RANLIB READELF STRIP
to your cross-compiler.


GNU Make
--------

We need make to build everything

  ./configure --host=i686-linux-musl --prefix= \
    --disable-dependency-tracking

we compile the package now

  ./build.sh


2. Cross-Tools
==============

Binutils and GCC
----------------

Binutils and GCC build just file

Linux Headers
-------------

We now build the linux headers:

  make CC="$CC" HOSTCC="$HOSTCC" mrproper headers

Install the headers.

  find usr/include -type f ! -name '*.h' -delete
  cp -rv usr/include $LFS/usr


Glibc
-----

**Build Dependencies:** Gawk, Bison and Python

Bison
-----

**Build Dependencies: m4**
