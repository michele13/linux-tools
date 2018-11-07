#!/bin/bash
TOP=$PWD
if [ -d out ]; then rm -rf out; fi
mkdir -p out/{obj,inst}
cd out/obj
time { $TOP/binutils/configure --target=$(uname -m)-test-linux-gnu --prefix=$TOP/out/inst --disable-nls --disable-werror && make -j$1 && make install; }