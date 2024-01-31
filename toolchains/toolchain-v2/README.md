# Toolchain-v2
This is the latest script that i've wrote to build a toolchain for cross-compiling.
It has been tested various times and installs the cross-toolchain inside the *cross* subdirectory.

## Features

* It's a simple and self-contained script. No complex syntax is used.
* Static compiling enabled by default.
* Compiles under alpine.
* It can resume the build from where it left.
* You can run an **offline build** 


## Requirements

The following packages are required to run the script: \
gcc, g++, make, tar, wget, xz, bison, flex, texinfo, gawk, python3


**Note:** gawk and python are only required if you want to build glibc

### Alpine Linux (Musl Libc)
Install the following packages in Alpine:

    apk add gcc g++ make tar wget xz bison flex texinfo gawk python3
    

###  Debian 12 (GNU/Linux)

Install the following packages in Debian:

    apt-get install gcc g++ make tar wget xz bison flex texinfo gawk python3

## Offline build
if you have already downloaded the source tarballs inside the `downloads` directory
you can run an **offline** build using this command:

    echo OFFLINE=1 >> env
    ./[script-name].sh


or

    OFFLINE=1 ./[script-name].sh

## The `./env` file
Now when you interrupt a build or if it fails, you can resume it by running the script again.
this happens thanks to a file called `env`, located alongside the script.

This file, if exists, is loaded by the main script and allows you see what was the latest successful step of the build. 
It also allows you to ***repeat*** or ***skip*** certain steps.
an `env` file is automatically created when a step is completed without errors.

The folowing is sample `env` file produced by a complete build:

```
OFFLINE=1
EXTRACTED=1
BINUTILS=1
KERNEL_HEADERS=1
GCC_CORE=1
LIBC_HEADERS=1
LIBC_CRT=1
LIBGCC=1
GLIBC=1
GCC=1

```

## Archive a toolchain for later use

you can use TAR to archive the toolchain:

    tar cvpJf archive.tar.xz ./cross/$TARGET
    
and you can extract it later with:

    tar xvpf archive.tar.xz
