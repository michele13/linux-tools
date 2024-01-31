# Toolchain-v2
This is the latest script that i've wrote to build a toolchain for cross-compiling.
It has been tested various times and installs the cross-toolchain inside the *cross* subdirectory.

## Features

* It's a simple and self-contained script. No complex syntax is used.
* Static compiling enabled by default.
* Compiles under alpine


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
    
