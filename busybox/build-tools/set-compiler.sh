#!/bin/bash

# this script sets some environment variables to make it easier to compile programs on a system that does not have a GNU Tooolchain
# installed on your system.

# If your toolchain is not in your PATH already uncomment the line below and set it as you see fit.
#export PATH=/opt/bin:/opt/cross/i486-linux-musl/bin:/opt/cross/arm-linux-musleabi/bin:$PATH

export TRIPLE=$1
export CC=${TRIPLE}-gcc
export CXX=${TRIPLE}-g++
export AR=${TRIPLE}-ar
export AS=${TRIPLE}-as
export LD=${TRIPLE}-ld
export READELF=${TRIPLE}-readelf
export RANLIB=${TRIPLE}-ranlib
export STRIP=${TRIPLE}-strip
exec /bin/bash
