#!/bin/bash

#exit on error and show commands for debugging
set -ex

#turn off bash's hash function
set +h

TOP=$(pwd)
TRIPLE=arm-linux-musleabi
PREFIX=$TOP/output
ARM_ARCH=armv7
TARGET_ARCH=arm
SRC=$TOP/tmp/src
export PATH=${PREFIX}/bin:$PATH
HOST=$(gcc -dumpmachine)

#create stage directory to store checkpoints so we don't have to run the build process from the beginning
if [ ! -e $TOP/stage ]; then mkdir $TOP/stage; fi

#download
if [ ! -e $TOP/dl ]; then mkdir $TOP/dl; fi
cd $TOP/dl
if [ ! -e $TOP/stage/download.done ]; then wget -c -i ../dl.list && touch $TOP/stage/download.done ; fi

#extract sources
if [ ! -e $TOP/stage/extract.done ]; then
mkdir -p $SRC
cd $SRC
tar xf $TOP/dl/linux-*.tar.*
mv linux-* linux
tar xf $TOP/dl/binutils-*.tar.*
mv binutils-* binutils
tar xf $TOP/dl/gcc-*.tar.*
mv gcc-* gcc
cd gcc
tar xf $TOP/dl/gmp-*.tar.*
mv gmp-* gmp
tar xf $TOP/dl/mpfr-*.tar.*
mv mpfr-* mpfr
tar xf $TOP/dl/mpc-*.tar.*
mv mpc-* mpc
cd $SRC
tar xf $TOP/dl/musl-*.tar.*
mv musl-* musl

touch $TOP/stage/extract.done
fi

#prefix
mkdir -p ${PREFIX}/${TRIPLE}
if [ ! -e ${PREFIX}/${TRIPLE}/usr ]; then ln -sfv . ${PREFIX}/${TRIPLE}/usr; fi

#make temporary directory to unpack and build the toolchain
if [ ! -e $TOP/tmp ]; then mkdir $TOP/tmp; fi
cd $TOP/tmp



#Linux headers
if [ ! -e $TOP/stage/headers.done ]; then
#tar xf $TOP/dl/linux-*.tar.*
cd $SRC/linux
make mrproper
make ARCH=${TARGET_ARCH} headers_check
make ARCH=${TARGET_ARCH} INSTALL_HDR_PATH=${PREFIX}/${TRIPLE} headers_install
touch $TOP/stage/headers.done
fi

 
cd $TOP/tmp

#binutils
if [ ! -e $TOP/stage/binutils.done ]; then
#tar xf $TOP/dl/binutils-*.tar.*
#cd binutils-* 
mkdir -p $TOP/tmp/binutils
cd $TOP/tmp/binutils
if [ ! -e $TOP/stage/binutils.configure ]; then $SRC/binutils/configure --host=${HOST} --build=${HOST} --target=${TRIPLE} --prefix=${PREFIX} --disable-nls --disable-multilib; touch $TOP/stage/binutils.configure; fi
if [ ! -e $TOP/stage/binutils.build ]; then 
make
touch $TOP/stage/binutils.build
fi
make install
cd ..
rm -rf build
touch $TOP/stage/binutils.done
fi

cd $TOP/tmp

#GCC1
#tar xf $TOP/dl/gcc-*.tar.*
#cd gcc-*
#tar xf $TOP/dl/gmp-*.tar.*
#mv gmp-* gmp
#tar xf $TOP/dl/mpfr-*.tar.*
#mv mpfr-* mpfr
#tar xf $TOP/dl/mpc-*.tar.*
#mv mpc-* mpc
if [ ! -e $TOP/stage/gcc1.done ]; then
if [ -e $TOP/tmp/build-gcc ]; then rm -rf $TOP/tmp/build-gcc; fi
mkdir -p $TOP/tmp/build-gcc
cd $TOP/tmp/build-gcc
if [ ! -e $TOP/stage/gcc1.configure ]; then $SRC/gcc/configure --host=${HOST} --build=${HOST} --target=${TRIPLE} --prefix=${PREFIX} --disable-nls --disable-shared --disable-multilib --with-newlib --disable-headers --disable-libmudflap --disable-libgomp --disable-decimal-float --disable-libquadmath --disable-threads --disable-libssp --disable-libatomic --disable-libstdcxx --disable-libsanitizer  --enable-languages=c,c++; touch $TOP/stage/gcc1.configure; fi #--with-float=soft --with-arch=${ARM_ARCH}
if [ ! -e $TOP/stage/gcc1.build ]; then make all-gcc all-target-libgcc; touch $TOP/stage/gcc1.build ; fi
make install-gcc install-target-libgcc
touch $TOP/stage/gcc1.done
fi

cd $TOP/tmp

#Musl
if [ ! -e $TOP/stage/musl.done ]; then
#tar xf $TOP/dl/musl-*.tar.*
cd $SRC/musl
if [ -e Makefile ]; then make distclean; fi
if [ ! -e $TOP/stage/musl.configure ]; then CC=${TRIPLE}-gcc ./configure --prefix=/ --target=${TRIPLE}; touch $TOP/stage/musl.configure; fi
if [ ! -e $TOP/stage/musl.build ]; then CC=${TRIPLE}-gcc make; fi
DESTDIR=${PREFIX}/${TRIPLE} make install
make distclean
touch $TOP/stage/musl.done
fi

cd $TOP/tmp

#GCC2
if [ ! -e $TOP/stage/gcc2.done ]; then
rm -rf $TOP/tmp/build-gcc/*
cd $TOP/tmp/build-gcc/
if [ ! -e $TOP/stage/gcc2.configure ]; then $SRC/gcc/configure --host=${HOST} --build=${HOST} --target=${TRIPLE} --prefix=${PREFIX} --disable-nls --enable-languages=c,c++ --enable-c99 --enable-long-long --disable-libmudflap --disable-multilib  --disable-libsanitizer --disable-libmpx; touch $TOP/stage/gcc2.configure; fi #--fith-float=soft --with-arch=${ARM_ARCH}
if [ ! -e $TOP/stage/gcc2.build ]; then make; touch $TOP/stage/gcc2.build; fi
make install
touch $TOP/stage/gcc2.done
fi