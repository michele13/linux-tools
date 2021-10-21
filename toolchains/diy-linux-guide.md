# Prerequisites and Directory Setup

This section deals with the packages we need on our system to cross bootstrap
our mini distro, as well as the basic directory setup before we get started.

## Prerequisites

For compiling the packages you will need:

* gcc
* g++
* make
* flex
* bison
* gperf
* makeinfo
* ncurses (with headers)
* awk
* automake
* help2man
* curl
* pkg-config
* libtool
* openssl (with headers)


In case you wonder: even if you don't build any C++ package, you need the C++
compiler to build GCC. The GCC code base mainly uses C99, but with some
additional C++ features. `makeinfo` is used by the GNU utilities that generate
info pages from texinfo. ncurses is mainly needed by the kernel build system
for `menuconfig`. OpenSSL is also requried to compile the kernel later on.

The list should be fairly complete, but I can't guarantee that I didn't miss
something. Normally I work on systems with tons of development tools and
libraries already installed, so if something is missing, please install it
and maybe let me know.

## Directory Setup

First of all, you should create an empty directory somewhere where you want
to build the cross toolchain and later the entire system.

For convenience, we will store the absolute path to this directory inside a
shell variable called **BUILDROOT** and create a few directories to organize
our stuff in:

    BUILDROOT=$(pwd)

    mkdir -p "build" "src" "download" "toolchain/bin" "sysroot"

I stored the downloaded packages in the **download** directory and extracted
them to a directory called **src**.

We will later build packages outside the source tree (GCC even requires that
nowadays), inside a sub directory of **build**.

Our final toolchain will end up in a directory called **toolchain**.

We store the toolchain location inside another shell variable that I called
**TCDIR** and prepend the executable path of our toolchain to the **PATH**
variable:

    TCDIR="$BUILDROOT/toolchain"
    export PATH="$TCDIR/bin:$PATH"


The **sysroot** directory will hold the cross compiled binaries for our target
system, as well as headers and libraries used for cross compiling stuff. It is
basically the `/` directory of the system we are going to build. For
convenience, we will also store its absolute path in a shell variable:

    SYSROOT="$BUILDROOT/sysroot"


### The Filesystem Hierarchy

You might be familiar with the [Linux Filesyste Hiearchy Standard](https://en.wikipedia.org/wiki/Filesystem_Hierarchy_Standard)
which strives to standardize the root filesytem layout across GNU/Linux distros.

This layout of course goes back to the [directory hierarchy on Unix Systems](https://en.wikipedia.org/wiki/Unix_directory_structure)
which in turn hasn't been designed in any particular way, but evolved over the
course of history.

One issue that we will run into is that there are multiple possible places that
libraries and program binaries could be installed to:
 - `/bin`
 - `/sbin`
 - `/lib`
 - `/usr/bin`
 - `/usr/sbin`
 - `/usr/lib`

Yes, I know that there is an additional `/usr/local` sub-sub-hierarchy, but we'll
ignore that once, since *nowadays** nobody outside the BSD world actually uses
that.

The split between `/` and `/usr` has historical reasons. The `/usr` directory
used to be the home directory for the system users (e.g. `/usr/ken` was Ken
Thompsons and `/usr/dmr` that of Dennis M. Ritchie) and was mounted from a
separate disk during boot. At some point space on the primary disk grew tight
and programs that weren't essential for system booting were moved from `/bin`
to `/usr/bin` to free up some space. The home directories were later moved to
an additional disk, mounted to `/home`. [So basically this split is a historic artifact](http://lists.busybox.net/pipermail/busybox/2010-December/074114.html).

Anyway, for the system we are building, I will get rid of the pointless `/bin`
and `/sbin` split, as well as the `/usr` sub-hiearchy split, but some programs
are stubborn and use hard coded paths (remember the last time you
used `#!/usr/bin/env` to make a script "portable"? You just replaced one
portabillity problem with another one). So we will set up symlinks in `/usr`
pointing back to `/bin` and `/lib`.

Enough for the ranting, lets setup our directory hierarchy:

    mkdir -p "$SYSROOT/bin" "$SYSROOT/lib"
    mkdir -p "$SYSROOT/usr/share" "$SYSROOT/usr/include"

    ln -s "../bin" "$SYSROOT/usr/bin"
    ln -s "../lib" "$SYSROOT/usr/lib"


# Building a Cross Compiler Toolchain

As it turns out, building a cross compiler toolchain with recent GCC and
binutils is a lot easier nowadays than it used to be.

I'm building the toolchain on an AMD64 (aka x86_64) system. The steps have
been tried on [Fedora](https://getfedora.org/) as well as on
[OpenSUSE](https://www.opensuse.org/).

The toolchain we are building generates 32 bit ARM code intended to run on
a Raspberry Pi 3. [Musl](https://www.musl-libc.org/) is used as a C standard
library implementation.

## Downloading and unpacking everything

The following source packages are required for building the toolchain. The
links below point to the exact versions that I used.

* [Linux](https://github.com/raspberrypi/linux/archive/raspberrypi-kernel_1.20201201-1.tar.gz).
  Linux is a very popular OS kernel that we will use on our target system.
  We need it to build the the C standard library for our toolchain.
* [Musl](https://www.musl-libc.org/releases/musl-1.2.2.tar.gz). A tiny
  C standard library implementation.
* [Binutils](https://ftp.gnu.org/gnu/binutils/binutils-2.36.tar.xz). This
  contains the GNU assembler, linker and various tools for working with
  executable files.
* [GCC](https://ftp.gnu.org/gnu/gcc/gcc-10.2.0/gcc-10.2.0.tar.xz), the GNU
  compiler collection. Contains compilers for C and other languages.

Simply download the packages listed above into `download` and unpack them
into `src`.

For convenience, I provided a small shell script called `download.sh` that,
when run inside `$BUILDROOT` does this and also verifies the `sha256sum`
of the packages, which will further make sure that you are using the **exact**
same versions as I am.

Right now, you should have a directory tree that looks something like this:

* build/
* toolchain/
   * bin/
* src/
   * binutils-2.36/
   * gcc-10.2.0/
   * musl-1.2.2/
   * linux-raspberrypi-kernel_1.20201201-1/
* download/
   * binutils-2.36.tar.xz
   * gcc-10.2.0.tar.xz
   * musl-1.2.2.tar.gz
   * raspberrypi-kernel_1.20201201-1.tar.gz
* sysroot/

For building GCC, we will need to download some additional support libraries.
Namely gmp, mfpr, mpc and isl that have to be unpacked inside the GCC source
tree. Luckily, GCC nowadays provides a shell script that will do that for us:

	cd "$BUILDROOT/src/gcc-10.2.0"
	./contrib/download_prerequisites
	cd "$BUILDROOT"


# Overview

From now on, the rest of the process itself consists of the following steps:

1. Installing the kernel headers to the sysroot directory.
2. Compiling cross binutils.
3. Compiling a minimal GCC cross compiler with minimal `libgcc`.
4. Cross compiling the C standard library (in our case Musl).
5. Compiling a full version of the GCC cross compiler with complete `libgcc`.

The main reason for compiling GCC twice is the inter-dependency between the
compiler and the standard library.

First of all, the GCC build system needs to know *what* kind of C standard
library we are using and *where* to find it. For dynamically linked programs,
it also needs to know what loader we are going to use, which is typically
also provided by the C standard library. For more details, you can read this
high level overview [how dyncamically linked ELF programs are run](elfstartup.md).

Second, there is [libgcc](https://gcc.gnu.org/onlinedocs/gccint/Libgcc.html).
`libgcc` contains low level platform specific helpers (like exception handling,
soft float code, etc.) and is automatically linked to programs built with GCC.
Libgcc source code comes with GCC and is compiled by the GCC build system
specifically for our cross compiler & libc combination.

However, some functions in the `libgcc` need functions from the C standard
library. Some libc implementations directly use utility functions from `libgcc`
such as stack unwinding helpers (provided by `libgcc_s`).

After building a GCC cross compiler, we need to cross compile `libgcc`, so we
can *then* cross compile other stuff that needs `libgcc` **like the libc**. But
we need an already cross compiled libc in the first place for
compiling `libgcc`.

The solution is to build a minimalist GCC that targets an internal stub libc
and provides a minimal `libgcc` that has lots of features disabled and uses
the stubs instead of linking against libc.

We can then cross compile the libc and let the compiler link it against the
minimal `libgcc`.

With that, we can then compile the full GCC, pointing it at the C standard
library for the target system and build a fully featured `libgcc` along with
it. We can simply install it *over* the existing GCC and `libgcc` in the
toolchain directory (dynamic linking for the rescue).

## Autotools and the canonical target tuple

Most of the software we are going to build is using autotools based build
systems. There are a few things we should know when working with autotools
based packages.

GNU autotools makes cross compilation easy and has checks and workarounds for
the most bizarre platforms and their misfeatures. This was especially important
in the early days of the GNU project when there were dozens of incompatible
Unices on widely varying hardware platforms and the GNU packages were supposed
to build and run on all of them.

Nowadays autotools offers *decades* of being used in practice and is in my
experience a lot more mature than more modern build systems. Also, having a
semi standard way of cross compiling stuff with standardized configuration
knobs is very helpful.

In contrast to many modern build systems, you don't need Autotools to run an
Autotools based build system. The final build system it generates for the
release tarballs just uses shell and `make`.

### The configure script

Pretty much every novice Ubuntu user has probably already seen this on Stack
Overflow (and copy-pasted it) at least once:

    ./configure
    make
    make install


The `configure` shell script generates the actual `Makefile` from a
template (`Makefile.in`) that is then used for building the package.

The `configure` script itself and the `Makefile.in` are completely independent
from autotools and were generated by `autoconf` and `automake`.

If we don't want to clobber the source tree, we can also build a package
*outside the source tree* like this:

    ../path/to/source/configure
    make

The `configure` script contains *a lot* of system checks and default flags that
we can use for telling the build system how to compile the code.

The main ones we need to know about for cross compiling are the following
three options:

* The **--build** option specifies what system we are *building* the
  package on.
* The **--host** option specifies what system the binaries will run on.
* The **--target** option is specific for packages that contain compilers
  and specify what system to generate output for.

Those options take as an argument a dash seperated tuple that describes
a system and is made up the following way:

	<architecture>-<vendor>-<kernel>-<userspace>

The vendor part is completely optional and we will only use 3 components to
discribe our toolchain. So for our 32 bit ARM system, running a Linux kernel
with a Musl based user space, is described like this:

	arm-linux-musleabihf

The user space component itself specifies that we use `musl` and we want to
adhere to the ARM embedded ABI specification (`eabi` for short) with hardware
float `hf` support.

If you want to determine the tuple for the system *you are running on*, you can
use the script [config.guess](https://git.savannah.gnu.org/gitweb/?p=config.git;a=tree):

	$ HOST=$(./config.guess)
	$ echo "$HOST"
	x86_64-pc-linux-gnu

There are reasons for why this script exists and why it is that long. Even
on Linux distributions, there is no consistent way, to pull a machine triple
out of a shell one liner.

Some guides out there suggest using a shell builtin **MACHTYPE**:

    $ echo "$MACHTYPE"
    x86_64-redhat-linux-gnu

The above is what I got on Fedora, however on Arch Linux I got this:

    $ echo "$MACHTYPE"
    x86_64

Some other guides suggest using `uname` and **OSTYPE**:

    $ HOST=$(uname -m)-$OSTYPE
    $ echo $HOST
    x86_64-linux-gnu

This works on Fedora and Arch Linux, but fails on OpenSuSE:

	$ HOST=$(uname -m)-$OSTYPE
    $ echo $HOST
    x86_64-linux

If you want to safe yourself a lot of headache, refrain from using such
adhockery and simply use `config.guess`. I only listed this here to warn you,
because I have seen some guides and tutorials out there using this nonsense.

As you saw here, I'm running on an x86_64 system and my user space is `gnu`,
which tells autotools that the system is using `glibc`.

You also saw that the `vendor` is sometimes used for branding, so use that
field if you must, because the others have exact meaning and are parsed by
the buildsystem.

### The Installation Path

When running `make install`, there are two ways to control where the program
we just compiled is installed to.

First of all, the `configure` script has an option called `--prefix`. That can
be used like this:

	./configure --prefix=/usr
	make
	make install

In this case, `make install` will e.g. install the program to `/usr/bin` and
install resources to `/usr/share`. The important thing here is that the prefix
is used to generate path variables and the program "knows" what it's prefix is,
i.e. it will fetch resource from `/usr/share`.

But if instead we run this:

	./configure --prefix=/opt/yoyodyne
	make
	make install

The same program is installed to `/opt/yoyodyne/bin` and its resource end up
in `/opt/yoyodyne/share`. The program again knows to look in the later path for
its resources.

The second option we have is using a Makefile variable called `DESTDIR`, which
controls the behavior of `make install` *after* the program has been compiled:

	./configure --prefix=/usr
	make
	make DESTDIR=/home/goliath/workdir install

In this example, the program is installed to `/home/goliath/workdir/usr/bin`
and the resources to `/home/goliath/workdir/usr/share`, but the program itself
doesn't know that and "thinks" it lives in `/usr`. If we try to run it, it
thries to load resources from `/usr/share` and will be sad because it can't
find its files.

## Building our Toolchain

At first, we set a few handy shell variables that will store the configuration
of our toolchain:

    TARGET="arm-linux-musleabihf"
	HOST="x86_64-linux-gnu"
    LINUX_ARCH="arm"
    MUSL_CPU="arm"
    GCC_CPU="armv6"

The **TARGET** variable holds the *target triplet* of our system as described
above.

We also need the triplet for the local machine that we are going to build
things on. For simplicity, I also set this manually.

The **MUSL_CPU**, **GCC_CPU** and **LINUX_ARCH** variables hold the target
CPU architecture. The variables are used for musl, gcc and linux respecitively,
because they cannot agree on consistent architecture names (except sometimes).

### Installing the kernel headers

We create a build directory called **$BUILDROOT/build/linux**. Building the
kernel outside its source tree works a bit different compared to autotools
based stuff.

To keep things clean, we use a shell variable **srcdir** to remember where
we kept the kernel source. A pattern that we will repeat later:

    export KBUILD_OUTPUT="$BUILDROOT/build/linux"
    mkdir -p "$KBUILD_OUTPUT"

    srcdir="$BUILDROOT/src/linux-raspberrypi-kernel_1.20201201-1"

    cd "$srcdir"
    make O="$KBUILD_OUTPUT" ARCH="$LINUX_ARCH" headers_check
    make O="$KBUILD_OUTPUT" ARCH="$LINUX_ARCH" INSTALL_HDR_PATH="$SYSROOT/usr" headers_install
    cd "$BUILDROOT"


According to the Makefile in the Linux source, you can either specify an
environment variable called **KBUILD_OUTPUT**, or set a Makefile variable
called **O**, where the later overrides the environment variable. The snippet
above shows both ways.

The *headers_check* target runs a few trivial sanity checks on the headers
we are going to install. It checks if a header includes something nonexistent,
if the declarations inside the headers are sane and if kernel internals are
leaked into user space. For stock kernel tar-balls, this shouldn't be
necessary, but could come in handy when working with kernel git trees,
potentially with local modifications.

Lastly (before switching back to the root directory), we actually install the
kernel headers into the sysroot directory where the libc later expects them
to be.

The `sysroot` directory should now contain a `usr/include` directory with a
number of sub directories that contain kernel headers.

Since I've seen the question in a few forums: it doesn't matter if the kernel
version exactly matches the one running on your target system. The kernel
system call ABI is stable, so you can use an older kernel. Only if you use a
much newer kernel, the libc might end up exposing or using features that your
kernel does not yet support.

If you have some embedded board with a heavily modified vendor kernel (such as
in our case) and little to no upstream support, the situation is a bit more
difficult and you may prefer to use the exact kernel.

Even then, if you have some board where the vendor tree breaks the
ABI **take the board and burn it** (preferably outside; don't inhale
the fumes).

### Compiling cross binutils

We will compile binutils outside the source tree, inside the directory
**build/binutils**. So first, we create the build directory and switch into
it:

    mkdir -p "$BUILDROOT/build/binutils"
    cd "$BUILDROOT/build/binutils"

    srcdir="$BUILDROOT/src/binutils-2.36"

From the binutils build directory we run the configure script:

    $srcdir/configure --prefix="$TCDIR" --target="$TARGET" \
                      --with-sysroot="$SYSROOT" \
                      --disable-nls --disable-multilib

We use the **--prefix** option to actually let the toolchain know that it is
being installed in our toolchain directory, so it can locate its resources and
helper programs when we run it.

We also set the **--target** option to tell the build system what target the
assembler, linker and other tools should generate **output** for. We don't
explicitly set the **--host** or **--build** because we are compiling binutils
to run on the local machine.

We would only set the **--host** option to cross compile binutils itself with
an existing toolchain to run on a different system than ours.

The **--with-sysroot** option tells the build system that the root directory
of the system we are going to build is in `$SYSROOT` and it should look inside
that to find libraries.

We disable the feature **nls** (native language support, i.e. cringe worthy
translations of error messages to your native language, such as Deutsch
or 中文), mainly because we don't need it and not doing something typically
saves time.

Regarding the multilib option: Some architectures support executing code for
other, related architectures (e.g. an x86_64 machine can run 32 bit x86 code).
On GNU/Linux distributions that support that, you typically have different
versions of the same libraries (e.g. in *lib/* and *lib32/* directories) with
programs for different architectures being linked to the appropriate libraries.
We are only interested in a single architecture and don't need that, so we
set **--disable-multilib**.


Now we can compile and install binutils:

    make configure-host
    make
    make install
    cd "$BUILDROOT"

The first make target, *configure-host* is binutils specific and just tells it
to check out the system it is *being built on*, i.e. your local machine and
make sure it has all the tools it needs for compiling. If it reports a problem,
**go fix it before continuing**.

We then go on to build the binutils. You may want to speed up compilation by
running a parallel build with **make -j NUMBER-OF-PROCESSES**.

Lastly, we run *make install* to install the binutils in the configured
toolchain directory and go back to our root directory.

The `toolchain/bin` directory should now already contain a bunch of executables
such as the assembler, linker and other tools that are prefixed with the host
triplet.

There is also a new directory called `toolchain/arm-linux-musleabihf` which
contains a secondary system root with programs that aren't prefixed, and some
linker scripts.

### First pass GCC

Similar to above, we create a directory for building the compiler, change
into it and store the source location in a variable:

    mkdir -p "$BUILDROOT/build/gcc-1"
    cd "$BUILDROOT/build/gcc-1"

    srcdir="$BUILDROOT/src/gcc-10.2.0"

Notice, how the build directory is called *gcc-1*. For the second pass, we
will later create a different build directory. Not only does this out of tree
build allow us to cleanly start afresh (because the source is left untouched),
but current versions of GCC will *flat out refuse* to build inside the
source tree.

    $srcdir/configure --prefix="$TCDIR" --target="$TARGET" --build="$HOST" \
                      --host="$HOST" --with-sysroot="$SYSROOT" \
                      --disable-nls --disable-shared --without-headers \
                      --disable-multilib --disable-decimal-float \
                      --disable-libgomp --disable-libmudflap \
                      --disable-libssp --disable-libatomic \
                      --disable-libquadmath --disable-threads \
                      --enable-languages=c --with-newlib \
                      --with-arch="$GCC_CPU" --with-float=hard \
                      --with-fpu=neon-vfpv3

The **--prefix**, **--target** and **--with-sysroot** work just like above for
binutils.

This time we explicitly specify **--build** (i.e. the system that we are going
to compile GCC on) and **--host** (i.e. the system that the GCC will run on).
In our case those are the same. I set those explicitly for GCC, because the GCC
build system is notoriously fragile. Yes, *I have seen* older versions of GCC
throw a fit or assume complete nonsense if you don't explicitly specify those
and at this point I'm no longer willing to trust it.

The option **--with-arch** gives the build system slightly more specific
information about the target processor architecture. The two options after that
are specific for our target and tell the buildsystem that GCC should use the
hardware floating point unit and can emit neon instructions for vectorization.

We also disable a bunch of stuff we don't need. I already explained *nls*
and *multilib* above. We also disable a bunch of optimization stuff and helper
libraries. Among other things, we also disable support for dynamic linking and
threads as we don't have the libc yet.

The option **--without-headers** tells the build system that we don't have the
headers for the libc *yet* and it should use minimal stubs instead where it
needs them. The **--with-newlib** option is *more of a hack*. It tells that we
are going to use the [newlib](http://www.sourceware.org/newlib/) as C standard
library. This isn't actually true, but forces the build system to disable some
[libgcc features that depend on the libc](https://gcc.gnu.org/ml/gcc-help/2009-07/msg00368.html).

The option **--enable-languages** accepts a comma separated list of languages
that we want to build compilers for. For now, we only need a C compiler for
compiling the libc.

If you are interested: [Here is a detailed list of all GCC configure options.](https://gcc.gnu.org/install/configure.html)

Now, lets build the compiler and `libgcc`:

    make all-gcc all-target-libgcc
    make install-gcc install-target-libgcc

    cd "$BUILDROOT"

We explicitly specify the make targets for *GCC* and *cross-compiled libgcc*
for our target. We are not interested in anything else.

For the first make, you **really** want to specify a *-j NUM-PROCESSES* option
here. Even the first pass GCC we are building here will take a while to compile
on an ordinary desktop machine.

### C standard library

We create our build directory and change there:

    mkdir -p "$BUILDROOT/build/musl"
    cd "$BUILDROOT/build/musl"

    srcdir="$BUILDROOT/src/musl-1.2.2"

Musl is quite easy to build but requires some special handling, because it
doesn't use autotools. The configure script is actually a hand written shell
script that tries to emulate some of the typical autotools handling:

    CC="${TARGET}-gcc" $srcdir/configure --prefix=/ --includedir=/usr/include \
                                         --target="$TARGET"

We override the shell variable **CC** to point to the cross compiler that we
just built. Remember, we added **$TCDIR/bin** to our **PATH**.

We also set the compiler for actually compiling musl and we explicitly set
the **DESTDIR** variable for installing:

    CC="${TARGET}-gcc" make
    make DESTDIR="$SYSROOT" install

    cd "$BUILDROOT"

The important part here, that later also applies for autotools based stuff, is
that we don't set **--prefix** to the sysroot directory. We set the prefix so
that the build system "thinks" it compiles the library to be installed
in `/`, but then we install the compiled binaries and headers to the sysroot
directory.

The `sysroot/usr/include` directory should now contain a bunch of standard
headers. Likewise, the `sysroot/usr/lib` directory should now contain a
`libc.so`, a bunch of dummy libraries, and the startup object code provided
by Musl.

The prefix is set to `/` because we want the libraries to be installed
to `/lib` instead of `/usr/lib`, but we still want the header files
in `/usr/include`, so we explicitly specifiy the **--includedir**.

### Second pass GCC

We are reusing the same source code from the first stage, but in a different
build directory:

    mkdir -p "$BUILDROOT/build/gcc-2"
    cd "$BUILDROOT/build/gcc-2"

    srcdir="$BUILDROOT/src/gcc-10.2.0"

Most of the configure options should be familiar already:

    $srcdir/configure --prefix="$TCDIR" --target="$TARGET" --build="$HOST" \
                      --host="$HOST" --with-sysroot="$SYSROOT" \
                      --disable-nls --enable-languages=c,c++ \
                      --enable-c99 --enable-long-long \
                      --disable-libmudflap --disable-multilib \
                      --disable-libsanitizer --with-arch="$CPU" \
                      --with-native-system-header-dir="/usr/include" \
                      --with-float=hard --with-fpu=neon-vfpv3

For the second pass, we also build a C++ compiler. The options **--enable-c99**
and **--enable-long-long** are actually C++ specific. When our final compiler
runs in C++98 mode, we allow it to expose C99 functions from the libc through
a GNU extension. We also allow it to support the *long long* data type
standardized in C99.

You may wonder why we didn't have to build a **libstdc++** between the
first and second pass, like the libc. The source code for the *libstdc++*
comes with the **g++** compiler and is built automatically like `libgcc`.
On the one hand, it is really just a library that adds C++ stuff
*on top of libc*, mostly header only code that is compiled with the actual
C++ programs. On the other hand, C++ does not have a standard ABI and it is
all compiler and OS specific. So compiler vendors will typically ship their
own `libstdc++` implementation with the compiler.

We **--disable-libsanitizer** because it simply won't build for musl. I tried
fixing it, but it simply assumes too much about the nonstandard internals
of the libc. A quick Google search reveals that it has **lots** of similar
issues with all kinds of libc & kernel combinations, so even if I fix it on
my system, you may run into other problems on your system or with different
versions of packets. It even has different problems with different versions
of glibc. Projects like buildroot simply disable it when using musl. It "only"
provides a static code analysis plugin for the compiler.

The option **--with-native-system-header-dir** is of special interest for our
cross compiler. We explicitly tell it to look for headers in `/usr/include`,
relative to our **$SYSROOT** directory. We could just as easily place the
headers somewhere else in the previous steps and have it look there.

All that's left now is building and installing the compiler:

    make
    make install

    cd "$BUILDROOT"

This time, we are going to build and install *everything*. You *really* want to
do a parallel build here. On my AMD Ryzen based desktop PC, building with
`make -j 16` takes about 3 minutes. On my Intel i5 laptop it takes circa 15
minutes. If you are using a laptop, you might want to open a window (assuming
it is cold outside, i.e. won't help if you are in Taiwan).

### Testing the Toolchain

We quickly write our average hello world program into a file called **test.c**:

    #include <stdio.h>

    int main(void)
    {
        puts("Hello, world");
        return 0;
    }

We can now use our cross compiler to compile this C file:

    $ ${TARGET}-gcc test.c

Running the program `file` on the resulting `a.out` will tell us that it has
been properly compiled and linked for our target machine:

    $ file a.out
    a.out: ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), dynamically linked, interpreter /lib/ld-musl-armhf.so.1, not stripped

Of course, you won't be able to run the program on your build system. You also
won't be able to run it on Raspbian or similar, because it has been linked
against our cross compiled Musl.

Statically linking it should solve the problem:

    $ ${TARGET}-gcc -static test.c
    $ file a.out
    a.out: ELF 32-bit LSB executable, ARM, EABI5 version 1 (SYSV), statically linked, with debug_info, not stripped
    $ readelf -d a.out

    There is no dynamic section in this file.

This binary now does not require any libraries, any interpreters and does
system calls directly. It should now run on your favourite Raspberry Pi
distribution as-is.

# Running dynamically linked programs on Linux

This section provides a high level overview of the startup process of a
dynamically linked program on Linux.

When using the `exec` system call to run a program, the kernel looks at the
first few bytes of the target file and tries to determine what kind of
executable. Based on the type of executable, some data structures are
parsed and the program is run. For a statically linked ELF program, this means
fiddling the entry point address out of the header and jumping to it (with
a kernel to user space transition of course).

The kernel also supports exec-ing programs that require an interpreter to be
run. This mechanism is also used for implementing dynamically linked programs.

Similar to how scripts have an interpreter field (`#!/bin/sh`
or `#!/usr/bin/perl`), ELF files can also have an interpreter section. For
dynamically linked ELF executables, the compiler sets the interpreter field
to the run time linker (`ld-linux.so` or similar), also known as "loader".

The `ld-linux.so` loader is typically provided by the `libc` implementation
(i.e. Musl, glibc, ...). It maps the actual executable into memory
with `mmap(2)`, parses the dynamic section and mmaps the used libraries
(possibly recursively since libraries may need other libraries), does
some relocations if applicable and then jumps to the entry point address.

The kernel itself actually has no concept of libraries. Thanks to this
mechanism, it doesn't even have to.

The whole process of using an interpreter is actually done recursively. An
interpreter can in-turn also have an interpreter. For instance if you exec
a shell script that starts with `#!/bin/sh`, the kernel detects it to be a
script (because it starts with `#!`), extracts the interpreter and then
runs `/bin/sh <script-path>` instead. The kernel then detects that `/bin/sh`
is an ELF binary (because it starts with `\x7fELF`) and extracts the
interpreter field, which is set to `/lib/ld-linux.so`. So now the kernel
tries to run `/lib/ld-linux.so /bin/sh <script-path>`. The `ld-linux.so` has
no interpreter field set, so the kernel maps it into memory, extracts the
entry point address and runs it.

If `/bin/sh` were statically linked, the last step would be missing and the
kernel would start executing right there. Linux actually has a hard limit for
interpreter recursion depth, typically set to 3 to support this exact standard
case (script, interpreter, loader).

The entry point of the ELF file that the loader jumps to is of course NOT
the `main` function of the C program. It points to setup code provided by
the libc implementation that does some initialization first, such as stack
setup, getting the argument vector, initializing malloc or whatever other
internals and then calls the `main` function. When `main` returns, the
startup code calls the `exit` system call with the return value from `main`.

The startup code is provided by the libc, typically in the form of an object
file in `/lib`, e.g. `/lib/crt0.o`. The C compiler links executable programs
against this object file and expects it to have a symbol called `_start`. The
entry point address of the ELF file is set to the location of `_start` and the
interpreter is set to the path of the loader.

Finally, somewhere inside the `main` function of `/bin/sh`, it eventually opens
the file it has been provided on the command line and starts interpreting your
shell script.

## Take Away Message

In summary, the compiler needs to know the following things about the libc:
 - The path to the loader for dynamically linked programs.
 - The path to the startup object code it needs to link against.
 - The path of the libc itself to link against.

If you try to run a program and you get the possibly most useless error
message `no such file or directory`, it could have the following reasons:
 - The kernel couldn't find the program you are trying to run.
 - The kernel couldn't find the interpreter set by the program.
 - The kernel couldn't find the interpreter of the interpreter.
 - The loader couldn't find a library used by either your program, the
   interpreter of your program, or another library that it loaded.

So if you see that error message, don't panic, try to figure out the root
cause by walking through this checklist. You can use the `ldd` program (that
is provided by the libc) to display libraries that the loader would try to
load. But **NEVER** use `ldd` on untrusted programs. Typical implementations
of ldd try to execute the interpreter with special options to collect
dependencies. An attacker could set this to something other than `ld-linux.so`
and gain code execution.


# Building a Bootable Kernel and Initial RAM Filesystem

This section outlines how to use the cross compiler toolchain you just built
for cross-compiling a bootable kernel, and how to get the kernel to run on
the Raspberry Pi.

## The Linux Boot Process at a High Level

When your system is powered on, it usually won't run the Linux kernel directly.
Even on a very tiny embedded board that has the kernel baked into a flash
memory soldered directly next to the CPU. Instead, a chain of boot loaders will
spring into action that do basic board bring-up and initialization. Part of this
chain is typically comprised of proprietary blobs from the CPU or board vendor
that considers hardware initialization as a mystical secret that must not be
shared. Each part of the boot loader chain is typically very restricted in what
it can do, hence the need to chain load a more complex loader after doing some
hardware initialization.

The chain of boot loaders typically starts with some mask ROM baked into the
CPU and ends with something like [U-Boot](https://www.denx.de/wiki/U-Boot),
[BareBox](https://www.barebox.org/), or in the case of an x86 system like your
PC, [Syslinux](https://syslinux.org/) or (rarely outside of the PC world)
[GNU GRUB](https://www.gnu.org/software/grub/).

The final stage boot loader then takes care of loading the Linux kernel into
memory and executing it. The boot loader typically generates some informational
data structures in memory and passes a pointer to the kernel boot code. Besides
system information (e.g. RAM layout), this typically also contains a command
line for the kernel.

On a very high level, after the boot loader jumps into the kernel, the kernel
decompresses itself and does some internal initialization, initializes built-in
hardware drivers and then attempts to mount the root filesystem. After mounting
the root filesystem, the kernel creates the very first process with PID 1.

At this point, boot strapping is done as far as the kernel is concerned. The
process with PID 1 usually spawns (i.e. `fork` + `exec`) and manages a bunch
of daemon processes. Some of them allowing users to log in and get a shell.

### Initial RAM Filesystem

For very simple setups, it can be sufficient to pass a command line option to
the kernel that tells it what device to mount for the root filesystem. For more
complex setups, Linux supports mounting an *initial RAM filesystem*.

This basically means that in addition to the kernel, the boot loader loads
a compressed archive into memory. Along with the kernel command line, the boot
loader gives the kernel a pointer to archive start in memory.

The kernel then mounts an in-memory filesystem as root filesystem, unpacks the
archive into it and runs the PID 1 process from there. Typically this is a
script or program that then does a more complex mount setup, transitions to
the actual root file system and does an `exec` to start the actual PID 1
process. If it fails at some point, it usually drops you into a tiny rescue
shell that is also packed into the archive.

For historical reasons, Linux uses [cpio](https://en.wikipedia.org/wiki/Cpio)
archives for the initial ram filesystem.

Systems typically use [BusyBox](https://busybox.net/) as a tiny shell
interpreter. BusyBox is a collection of tiny command line programs that
implement basic commands available on Unix-like system, ranging from `echo`
or `cat` all the way to a small `vi` and `sed` implementation and including
two different shell implementations to choose from.

BusyBox gets compiled into a single, monolithic binary. For the utility
programs, symlinks or hard links are created that point to the binary.
BusyBox, when run, will determine what utility to execute from the path
through which it has been started.

**NOTE**: The initial RAM filesystem, or **initramfs** should not be confused
with the older concept of an initial RAM disk, or **initrd**. The initial RAM
disk actually uses a disk image instead of an archive and the kernel internally
emulates a block device that reads blocks from RAM. A regular filesystem driver
is used to mount the RAM backed block device as root filesystem.

### Device Tree

On a typical x86 PC, your hardware devices are attached to the PCI bus and the
kernel can easily scan it to find everything. The devices have nice IDs that
the kernel can query and the drivers tell the kernel what IDs that they can
handle.

On embedded machines running e.g. ARM based SoCs, the situation is a bit
different. The various SoC vendors buy licenses for all the hardware "IP cores",
slap them together and multiplex them onto the CPU cores memory bus. The
hardware registers end up mapped to SoC specific memory locations and there is
no real way to scan for possibly present hardware.

In the past, Linux had something called "board files" that where SoC specific
C files containing SoC & board specific initialization code, but this was
considered too inflexible.

Linux eventually adopted the concept of a device tree binary, which is
basically a binary blob that hierarchically describes the hardware present on
the system and how the kernel can interface with it.

The boot loader loads the device tree into memory and tells the kernel where it
is, just like it already does for the initial ramfs and command line.

In theory, a kernel binary can now be started on a number of different boards
with the same CPU architecture, without recompiling (assuming it has all the
drivers). It just needs the correct device tree binary for the board.

The device tree binary (dtb) itself is generated from a number of source
files (dts) located in the kernel source tree under `arch/<cpu>/boot/dts`.
They are compiled together with the kernel using a device tree compiler that
is also part of the kernel source.

On a side note, the device tree format originates from the BIOS equivalent
of SPARC workstations. The format is now standardized through a specification
provided by the Open Firmware project and Linux considers it part of its ABI,
i.e. a newer kernel should *always* work with an older DTB file.

## Overview

In this section, we will cross compile BusyBox, build a small initial ramfs,
cross compile the kernel and get all of this to run on the Raspberry Pi.

Unless you have used the `download.sh` script from [the cross toolchain](01_crosscc.md),
you will need to download and unpack the following:

* [BusyBox](https://busybox.net/downloads/busybox-1.32.1.tar.bz2)
* [Linux](https://github.com/raspberrypi/linux/archive/raspberrypi-kernel_1.20201201-1.tar.gz)

You should still have the following environment variables set from building the
cross toolchain:

    BUILDROOT=$(pwd)
    TCDIR="$BUILDROOT/toolchain"
    SYSROOT="$BUILDROOT/sysroot"
    TARGET="arm-linux-musleabihf"
	HOST="x86_64-linux-gnu"
    LINUX_ARCH="arm"
    export PATH="$TCDIR/bin:$PATH"


## Building BusyBox

The BusyBox build system is basically the same as the Linux kernel build system
that we already used for [building a cross toolchain](01_crosscc.md).

Just like the kernel (which we haven't built yet), BusyBox uses has a
configuration file that contains a list of key-value pairs for enabling and
tuning features.

I prepared a file `bbstatic.config` with the configuration that I used. I
disabled a lot of stuff that we don't need inside an initramfs, but most
importantly, I changed the following settings:

 - **CONFIG_INSTALL_NO_USR** set to yes, so BusyBox creates a flat hierarchy
   when installing itself.
 - **CONFIG_STATIC** set to yes, so BusyBox is statically linked and we don't
   need to pack any libraries or a loader into our initramfs.

If you want to customize my configuration, copy it into a freshly extracted
BusyBox tarball, rename it to `.config` and run the menuconfig target:

    mv bbstatic.config .config
    make menuconfig

The `menuconfig` target builds and runs an ncurses based dialog that lets you
browse and configure features.

Alternatively you can start from scratch by creating a default configuration:

    make defconfig
    make menuconfig

To compile BusyBox, we'll first do the usual setup for the out-of-tree build:

    srcdir="$BUILDROOT/src/busybox-1.32.1"
    export KBUILD_OUTPUT="$BUILDROOT/build/bbstatic"

    mkdir -p "$KBUILD_OUTPUT"
    cd "$KBUILD_OUTPUT"

At this point, you have to copy the BusyBox configuration into the build
directory. Either use your own, or copy my `bbstatic.config` over, and rename
it to `.config`.

By running `make oldconfig`, we let the buildsystem sanity check the config
file and have it ask what to do if any option is missing.

    make -C "$srcdir" CROSS_COMPILE="${TARGET}-" oldconfig

We need to edit 2 settings in the config file: The path to the sysroot and
the prefix for the cross compiler executables. This can be done easily with
two lines of `sed`:

    sed -i "$KBUILD_OUTPUT/.config" -e 's,^CONFIG_CROSS_COMPILE=.*,CONFIG_CROSS_COMPILE="'$TARGET'-",'
    sed -i "$KBUILD_OUTPUT/.config" -e 's,^CONFIG_SYSROOT=.*,CONFIG_SYSROOT="'$SYSROOT'",'

What is now left is to compile BusyBox.

    make -C "$srcdir" CROSS_COMPILE="${TARGET}-"

Before returning to the build root directory, I installed the resulting binary
to the sysroot directory as `bbstatic`.

    cp busybox "$SYSROOT/bin/bbstatic"
    cd "$BUILDROOT"

## Compiling the Kernel

First, we do the same dance again for the kernel out of tree build:

    srcdir="$BUILDROOT/src/linux-raspberrypi-kernel_1.20201201-1"
    export KBUILD_OUTPUT="$BUILDROOT/build/linux"

    mkdir -p "$KBUILD_OUTPUT"
    cd "$KBUILD_OUTPUT"

I provided a configuration file in `linux.config` which you can simply copy
to `$KBUILD_OUTPUT/.config`.

Or you can do the same as I did and start out by initializing a default
configuration for the Raspberry Pi and customizing it:

    make -C "$srcdir" ARCH="$LINUX_ARCH" bcm2709_defconfig
    make -C "$srcdir" ARCH="$LINUX_ARCH" menuconfig

I mainly changed **CONFIG_SQUASHFS** and **CONFIG_OVERLAY_FS**, turning them
both from `<M>` to `<*>`, so they get built in instead of being built as
modules.

Hint: you can also search for things in the menu config by typing `/` and then
browsing through the popup dialog. Pressing the number printed next to any
entry brings you directly to the option. Be aware that names in the menu
generally don't contain **CONFIG_**.

Same as with BusyBox, we insert the cross compile prefix into the configuration
file:

    sed -i "$KBUILD_OUTPUT/.config" -e 's,^CONFIG_CROSS_COMPILE=.*,CONFIG_CROSS_COMPILE="'$TARGET'-",'

And then finally build the kernel:

    make -C "$srcdir" ARCH="$LINUX_ARCH" CROSS_COMPILE="${TARGET}-" oldconfig
    make -C "$srcdir" ARCH="$LINUX_ARCH" CROSS_COMPILE="${TARGET}-" zImage dtbs modules

The `oldconfig` target does the same as on BusyBox. More intersting are the
three make targets in the second line. The `zImage` target is the compressed
kernel binary, the `dtbs` target builds the device tree binaries and `modules`
are the loadable kernel modules (i.e. drivers). You really want to insert
a `-j NUMBER_OF_JOBS` in the second line, or it may take a considerable amount
of time.

Also, you *really* want to specify an argument after `-j`, otherwise the kernel
build system will spawn processes until kingdome come (i.e. until your system
runs out of resources and the OOM killer steps in).

Lastly, I installed all of it into the sysroot for convenience:

    mkdir -p "$SYSROOT/boot"
    cp arch/arm/boot/zImage "$SYSROOT/boot"
    cp -r arch/arm/boot/dts "$SYSROOT/boot"

    make -C "$srcdir" ARCH="$LINUX_ARCH" CROSS_COMPILE="${TARGET}-" INSTALL_MOD_PATH="$SYSROOT" modules_install
    cd $BUILDROOT

The `modules_install` target creates a directory hierarchy `sysroot/lib/modules`
containing a sub directory for each kernel version with the kernel modules and
dependency information.

The kernel binary will be circa 6 MiB in size and produce another circa 55 MiB
worth of modules because the Raspberry Pi default configuration has all bells
and whistles turned on. Fell free to adjust the kernel configuration and throw
out everything you don't need.

## Building an Inital RAM Filesystem

First of all, although we do everything by hand here, we are going to create a
build directory to keep everything neatly separated:

    mkdir -p "$BUILDROOT/build/initramfs"
	cd "$BUILDROOT/build/initramfs"

Technically, the initramfs image is a simple cpio archive. However, there are
some pitfalls here:

* There are various versions of the cpio format, some binary, some text based.
* The `cpio` command line tool is utterly horrible to use.
* Technically, the POSIX standard considers it lagacy. See the big fat warning
  in the man page.

So instead of the `cpio` tool, we are going to use a tool from the Linux kernel
tree called `gen_init_cpio`:

    gcc "$BUILDROOT/src/linux-raspberrypi-kernel_1.20201201-1/usr/gen_init_cpio.c" -o gen_init_cpio

This tool allows us to create a cpio image from a very simple file listing and
produces exactely the format that the kernel understands.

Here is the simple file listing that I used:

    cat > initramfs.files <<_EOF
    dir boot 0755 0 0
    dir dev 0755 0 0
    dir lib 0755 0 0
    dir bin 0755 0 0
    dir sys 0755 0 0
    dir proc 0755 0 0
    dir newroot 0755 0 0
    slink sbin bin 0777 0 0
    nod dev/console 0600 0 0 c 5 1
    file bin/busybox $SYSROOT/bin/bbstatic 0755 0 0
    slink bin/sh /bin/busybox 0777 0 0
    file init $BUILDROOT/build/initramfs/init 0755 0 0
    _EOF

In case you are wondering about the first and last line, this is called a
[heredoc](https://en.wikipedia.org/wiki/Here_document) and can be copy/pasted
into the shell as is.

The format itself is actually pretty self explantory. The `dir` lines are
directories that we want in our archive with the permission and ownership
information after the name. The `slink` entry creates a symlink, namely
redirecting `/sbin` to `/bin`.

The `nod` entry creates a devices file. In this case, a character
device (hence `c`) with device number `5:1`. Just like how symlinks are special
files that have a target string stored in them and get special treatment from
the kernel, a device file is also just a special kind of file that has a device
number stored in it. When a program opens a device file, the kernel maps the
device number to a driver and redirects file I/O to that driver.

This decice number `5:1` refers to a special text console on which the kernel
prints out messages during boot. BusyBox will use this as standard input/output
for the shell.

Next, we actually pack our statically linked BusyBox, into the archive, but
under the name `/bin/busybox`. We then create a symlink to it, called `bin/sh`.

The last line packs a script called `init` (which we haven't written yet) into
the archive as `/init`.

The script called `/init` is what we later want the kernel to run as PID 1
process. For the moment, there is not much to do and all we want is to get
a shell when we power up our Raspberry Pi, so we start out with this stup
script:

    cat > init <<_EOF
    #!/bin/sh

    PATH=/bin

    /bin/busybox --install
    /bin/busybox mount -t proc none /proc
    /bin/busybox mount -t sysfs none /sys
    /bin/busybox mount -t devtmpfs none /dev

    exec /bin/busybox sh
    _EOF

Running `busybox --install` will cause BusyBox to install tons of symlinks to
itself in the `/bin` directory, one for each utility program. The next three
lines run the `mount` utiltiy of BusyBox to mount the following pseudo
filesystems:

* `proc`, the process information filesystem which maps processes and other
  various kernel variables to a directory hierchy. It is mounted to `/proc`.
  See `man 5 proc` for more information.
* `sysfs` a more generic, cleaner variant than `proc` for exposing kernel
  objects to user space as a filesystem hierarchy. It is mounted to `/sys`.
  See `man 5 sysfs` for more information.
* `devtmpfs` is a pseudo filesystem that takes care of managing device files
  for us. We mount it over `/dev`.

We can now finally put everything together into an XZ compressed archive:

    ./gen_init_cpio initramfs.files | xz --check=crc32 > initramfs.xz
    cp initramfs.xz "$SYSROOT/boot"
    cd "$BUILDROOT"

The option `--check=crc32` forces the `xz` utility to create CRC-32 checksums
instead of using sha256. This is necessary, because the kernel built in
xz library cannot do sha256, will refuse to unpack the image otherwise and the
system won't boot.


## Putting everything on the Raspberry Pi and Booting it

Remember how I mentioned earlier that the last step of our boot loader chain
would involve something sane, like U-Boot or BareBox? Well, not on the
Raspberry Pi.

In addition to the already bizarro hardware, the Raspberry Pi has a lot of
proprietary magic baked directly into the hardware. The boot process is
controlled by the GPU, since the SoC is basically a GPU with an ARM CPU slapped
on to it.

The GPU loads a binary called `bootcode.bin` from the SD card, which contains a
proprietary boot loader blob for the GPU. This in turn does some initialization
and chain loads `start.elf` which contains a firmware blob for the GPU. The GPU
is running an RTOS called [ThreadX OS](https://en.wikipedia.org/wiki/ThreadX)
and somewhere around [>1M lines](https://www.raspberrypi.org/forums/viewtopic.php?t=53007#p406247)
worth of firmware code.

There are different versions of `start.elf`. The one called `start_x.elf`
contains an additional driver for the camera interface, `start_db.elf` is a
debug version and `start_cd.elf` is a version with a cut-down memory layout.

The `start.elf` file uses an aditional file called `fixup.dat` to configure
the RAM partitioning between the GPU and the CPU.

In the end, the GPU firmware loads and parses a file called `config.txt` from
the SD card, which contains configuration parameters, and `cmdline.txt` which
contains the kernel command line. After parsing the configuration, it finally
loads the kernel, the initramfs, the device tree binaries and runs the kernel.

Depending on the configuration, the GPU firmway may patch the device tree
in-memory before running the kernel.

### Copying the Files Over

First, we need a micro SD card with a FAT32 partition on it. How to create the
partition is left as an exercise to the reader.

Onto this partition, we copy the proprietary boot loader blobs:

* [bootcode.bin](firmware/bootcode.bin)
* [fixup.dat](firmware/fixup.data)
* [start.elf](firmware/start.elf)

We create a minimal [config.txt](firmware/config.txt) in the root directory:

	dtparam=
	kernel=zImage
	initramfs initramfs.xz followkernel

The first line makes sure the boot loader doesn't mangle the device tree. The
second one specifies the kernel binary that should be loaded and the last one
specifies the initramfs image. Note that there is no `=` sign in the last
line. This field has a different format and the boot loader will ignore it if
there is an `=` sign. The `followkernel` attribute tells the boot loader to put
the initramfs into memory right after the kernel binary.

Then, we'll put the [cmdline.txt](firmware/cmdline.txt) onto the SD card:

	console=tty0

The `console` parameter tells the kernel the tty where it prints its boot
messages and that it uses as the standard input/output tty for our init script.
We tell it to use the first video console which is what we will get at the HDMI
output of the Raspberry Pi.

Whats left are the device tree binaries and lastly the kernel and initramfs:

    mkdir -p overlays
    cp $SYSROOT/boot/dts/*-rpi-3-*.dtb .
    cp $SYSROOT/boot/dts/overlays/*.dtbo overlays/

    cp $SYSROOT/boot/initramfs.xz .
    cp $SYSROOT/boot/zImage .

If you are done, unmount the micro SD card and plug it into your Raspberr Pi.


### Booting It Up

If you connect the HDMI port and power up the Raspberry Pi, it should boot
directly into the initramfs and you should get a BusyBox shell.

The PATH is propperly set and the most common shell commands should be there, so
you can poke around the root filesystem which is in memory and has been unpacked
from the `initramfs.xz`.

Don't be alarmed by the kernel boot prompt suddenly stopping. Even after the
BusyBox shell starts, the kernel continues spewing messages for a short while
and you may not see the shell prompt. Just hit the enter key a couple times.

Also, the shell itself is running as PID 1. If you exit it, the kernel panics
because PID 1 just died.

# Building a More Sophisticated Userspace

## Helper Functions

Because we are going to build a bunch of autotools based packages, I am going to
use two simple helper functions to make things a lot easier.

For simplicity, I added a script called `util.sh` that already contains those
functions. You can simply source it in your shell using `. <path>/util.sh`.

The first helper function runs the `configure` script for us with some
default options:

    run_configure() {
        "$srcdir/configure" --host="$TARGET" --prefix="" --sbindir=/bin \
                            --includedir=/usr/include --datarootdir=/usr/share\
                            --libexecdir=/lib/libexec --disable-static \
                            --enable-shared $@
    }

The host-touple is set to our target machine touple, the prefix is left empty,
which means install everything into `/` of our target filesystem.

In case the package wants to install programs into `/sbin`, we explicitly tell
it that sbin-programs go into `/bin`.

However, despite having `/` as our prefix, we want headers to go
into `/usr/include` and any possible data files into `/usr/share`.

If a package wants to install helper programs that are regular executables, but
not intended to be used by a user on the command line, those are usually
installed into a `libexec` sub directory. We explicitly tell the configure
script to install those in the historic `/lib/libexec` location instead of
clobbering the filesystem root with an extra directory.

The last two switches **--disable-static** and **--enable-shared** tell any
libtool based packages to prefer building shared libraries over static ones.

If a package doesn't use libtool and maybe doesn't even install libraries, it
will simply issue a warning that it doesn't know those switches, but will
otherwise ignore them and compile just fine.

The `$@` at the end basically paste any arguments passed to this function, so we
can still pass along package specific configure switches.

The second function encapsulates the entire dance for building a package that
we already did several times:

    auto_build() {
        local pkgname="$1"
        shift

        mkdir -p "$BUILDROOT/build/$pkgname"
        cd "$BUILDROOT/build/$pkgname"
        srcdir="$BUILDROOT/src/$pkgname"

        run_configure $@
        make -j `nproc`
        make DESTDIR="$SYSROOT" install
        cd "$BUILDROOT"
    }

The package name is specified as first argument, the remaining arguments are
passed to `run_configure`, again using `$@`. The `shift` command removes the
first argument, so we can do this without passing the package name along.

Another noticable difference is the usage of `nproc` to determine the number of
available CPU cores and pass it to `make -j` to speed up the build.

## About pkg-config and libtool

We will build a bunch of packages that either provide libraries, or depend on
libraries provided by other packages. This also means that the programs that
require libraries need a way to locate them, i.e. find out what compiler flags
to add in order to find the headers and what linker flags to add in order to
actually link against a library. Especially since a library may itself have
dependencies that the program needs to link against.

The [pkg-config program](https://en.wikipedia.org/wiki/Pkg-config) tries to
provide a unified solution for this problem. Packages that provide a library
can install a configuration file at a special location (in our
case `$SYSROOT/lib/pkgconfig`) and packages that need a library can
use `pkg-config` to query if the library is present, and what compiler/linker
flags are required to use it.

With most autotools based packages, this luckily isn't that much of an issue.
Most of them use standard macros for querying `pkg-config` that automagically
generate `configure` flags and variables that can be used to override the
results from `pkg-config`.

We are basically going to use the `pkg-config` version installed on our build
system and just need to set a few environment variables to instruct it to look
at the right place instead of the system defaults. The `util.sh` script also
sets those:

    export PKG_CONFIG_SYSROOT_DIR="$SYSROOT"
    export PKG_CONFIG_LIBDIR="$SYSROOT/lib/pkgconfig"
    export PKG_CONFIG_PATH="$SYSROOT/lib/pkgconfig"

The later two are actually *both* paths where `pkg-config` looks for its input
files, the LIBDIR has nothing to do with shared libraries. Setting
the `PKG_CONFIG_SYSROOT_DIR` variable instructs `pkg-config` to re-target any
paths it generates to point to the correct root filesystem directory.

The GNU `libtool` is a wrapper script for building shared libraries in an
autotools project and takes care of providing reasonable fallbacks on ancient
Unix systems where this works either qurky or not at all.

At the same time, it also tries to serve a similar purpose as `pkg-config` and
install libtool archives (with an `.la` file extension) to the `/lib`
directory. However, the way it does this is horribly broken and when using
`make install` with a `DESTDIR` argument, it will *always* store full path in
the `.la` file, which breaks the linking step of any other `libtool` based
package that happens to pick it up.

We will go with the easy solution and simply delete those files when they are
installed. Since we have `pkg-config` and a flat `/lib` directory, most
packages will find their libraries easily (except for `ncurses`, where,
historical reason, some programs stubbornly try their own way for).


## Building GNU Bash

In order to build Bash, we first build two support libraries: `ncurses`
and `readline`.

### Ncurses

The `ncurses` library is itself an extension/reimplementation of the `pcurses`
and `curses` libraries dating back to the System V and BSD era. At the time
that they were around, the landscape of terminals was much more diverse,
compared to nowadays, where everyone uses a different variant of Frankensteins
DEC VTxxx emulator.

As a result `curses` internally used the `termcap` library for handling terminal
escape codes, which was later replaced with `terminfo`. Both of those libraries
have their own configuration formats for storing terminal capabilities.

The `ncurses` library can work with both `termcap` and `terminfo` files and
thankfully provides the later for a huge number of terminals.

We can build ncurses as follows:

    auto_build "ncurses-6.2" --disable-stripping --with-shared --without-debug \
               --enable-pc-files --with-pkg-config-libdir=/lib/pkgconfig \
               --enable-widec --with-termlib

A few configure clutches are required, because it is one of those packages where
the maintainer tried to be clever and work around autotools semantics, so we
have to explicitly tell it to *not strip debug symbols* when installing the
binaries and explicitly tell it to generate shared libraries. We also need to
tell it to generate pkg-config files and where to put them.

If the **--disable-stripping** flag wasn't set, the `make install` would fail
later, because it would try to strip the debug information using the host
systems `strip` program, which will choke on the ARM binaries.

The **--enable-widec** flag instructs the build system to generate an `ncurses`
version with multi byte, wide character unicode support. The **--with-termlib**
switch instructs it to generate build the `terminfo` library as a separate
library instead of having it built into ncurses.

In addition to a bunch of libraries and header files, `ncurses` also installs
a few programs for handling `terminfo` files, such as the terminfo
compiler `tic` or the `tset` program for querying the database
(e.g. `tput reset` fully resets your terminal back into a sane state, in a way
that is supported by your terminal).

It also installs the terminal database files into `$SYSROOT/usr/share/terminfo`
and `$SYSROOT/usr/share/tabset`, as well as a hand full of man pages
to `$SYSROOT/usr/share/man`. For historical/backwards compatibillity reasons,
a symlink to the `terminfo` directory is also added to `$SYSROOT/lib`.

Because we installed the version with wide charater and unicode support, the
libraries that `ncurses` installs all have a `w` suffix at the end (as well as
the `pkg-config` files it installs), so it's particularly hard for other
programs to find the libraries.

So we add a bunch of symlinks for the programs that don't bother to check both:

    ln -s "$SYSROOT/lib/pkgconfig/formw.pc" "$SYSROOT/lib/pkgconfig/form.pc"
    ln -s "$SYSROOT/lib/pkgconfig/menuw.pc" "$SYSROOT/lib/pkgconfig/menu.pc"
    ln -s "$SYSROOT/lib/pkgconfig/ncursesw.pc" "$SYSROOT/lib/pkgconfig/ncurses.pc"
    ln -s "$SYSROOT/lib/pkgconfig/panelw.pc" "$SYSROOT/lib/pkgconfig/panel.pc"
    ln -s "$SYSROOT/lib/pkgconfig/tinfow.pc" "$SYSROOT/lib/pkgconfig/tinfo.pc"

In addition to `pkg-config` scripts, the `ncurses` package also provides a
shell script that tries to implement the same functionality.

Some packages (like `util-linux`) try to run that first and may accidentally
pick up a version you have installed on your host system.

So we copy that over from the `$SYSROOT/bin` directory to `$TCDIR/bin`:

    cp "$SYSROOT/bin/ncursesw6-config" "$TCDIR/bin/ncursesw6-config"
    cp "$SYSROOT/bin/ncursesw6-config" "$TCDIR/bin/$TARGET-ncursesw6-config"

### Readline

Having built the ncurses library, we can now build the `readline` library,
which implements a highly configurable command prompt with a search-able
history, auto completion and Emacs style key bindings.

Unlike `ncurses` that it is based on, it does not requires any special
configure flags:

    auto_build "readline-8.1"

It only installs the library (`libreadline` and `libhistory`) and headers
for the libraries, but no programs.

A bunch of documentation files are installed to `$SYSROOT/usr/share`, including
not only man pages, but info pages, plain text documentation in a `doc` sub
directory.

### Bash

For Bash itself, I used only two extra configure flags:

    auto_build "bash-5.1" --without-bash-malloc --with-installed-readline

The **--without-bash-malloc** flag tells it to use the standard `libc` malloc
instead of its own implementation and the **--with-installed-readline** flag
tells it to use the readline library that we just installed, instead of an
outdated, internal stub implementation.

The `make install` step installs bash to `$SYSROOT/bin/bash`, but also adds an
additional script `$SYSROOT/bin/bashbug` which is intended to report bugs you
may encounter back to the bash developers.

Bash has a plugin style support for builtin commands, which in can load as
libraries from a special directory (in our case `$SYSROOT/lib/bash`). So it will
install a ton of builtins there by default, as well as development headers
in `$SYSROOT/usr/include` that for third party packages that implement their own
builtins.

Just like readline, Bash brings along a bunch of documentation that it installs
to `$SYSROOT/usr/share`. Namely HTML documentation in `doc`, more info pages
and man pages.

Bash is also the first program we build that installs localized text messages
in the `$SYSROOT/usr/share/locale` directory.

Of course we are no where near done with Bash yet, as we still have some
plumbing to do regarding the bash start-up script, but we will get back to that
later when we put everything together.


## Basic Command Line Programs

### Basic GNU Packages

The standard comamnd line programs, such as `ls`, `cat`, `rm` and many more are
provided by the [GNU Core Utilities](https://www.gnu.org/software/coreutils/)
package.

It is fairly simple to build and install:

    auto_build "coreutils-8.32" --enable-single-binary=symlinks

The **--enable-single-binary** configure switch is a relatively recent feature
that instructs coreutils to build a single, monolithic binary in the same style
as BusyBox and install a bunch of symlinks to it, instead of installing dozens
of separate programs.

A few additional, very useful programs are provided by the [GNU diffutils](https://www.gnu.org/software/diffutils/)
and [GNU findutils](https://www.gnu.org/software/findutils/).

Namely, the diffutils provide `diff`, `patch` and `cmp`, while the findutils
provide `find`, `locate`, `updatedb` and `xargs`.

The GNU implementation of the `grep` program, as well as the `less` pager are
packaged separately.

All of those are relatively easy to build and install:

    auto_build "diffutils-3.7"
    auto_build "findutils-4.8.0"
    auto_build "grep-3.6"
    auto_build "less-563"

Again those packages also install a bunch of documentation in the `/usr/share`
directory in addition to the program binaries.

Coreutils installs a helper library in `$SYSROOT/lib/libexec/coretuils` and
findutils installs a libexec helper program as well (`frcode`).

The findutils package also creates an empty `$SYSROOT/var` directory, because
this is where `locate` expects to find a filesystem index database that can be
generated using `updatedb`.

### Sed and AWK

We have already used `sed`, the *stream editor* for simple file substitution
in the previous sections for building the kernel and BusyBox.

AWK is a much more advanced stream editing program that actually implements a
powerful scripting language for the purpose.

For both programs, we will use the GNU implementations (the GNU AWK
implementation is called `gawk`).

Both are fairly straight forward to build for our system:

    auto_build "sed-4.8"
    auto_build "gawk-5.1.0"

Again, we not only get the programs, but also a plethora of documentation and
extra files.

In fact, gawk will install an entire AWK library in `$SYSROOT/usr/share/awk` as
well as a number of plugin libraries in `$SYSROOT/lib/gawk`, some helper
programs in `$SYSROOT/lib/libexec/awk` and necessary development headers to
build external plugins.


### procps aka procps-ng

As the name suggests, the `procps` package supplies a few handy command line
programs for managing processes. More precisely, we install the following
list of programs:

 - `free`
 - `watch`
 - `w`
 - `vmstat`
 - `uptime`
 - `top`
 - `tload`
 - `sysctl`
 - `slabtop`
 - `pwdx`
 - `ps`
 - `pmap`
 - `pkill`
 - `pidof`
 - `pgrep`
 - `vmstat`

And their common helper library `libprocps.so` plus accompanying documentation.
The package would also supply the `kill` program, but we don't install that
here, sine it is also provided by the `util-linux` package and the later has a
few extra features.

Sadly, we don't get a propper release tarball for `procps`, but only a dump from
the git repository. Because the `configure` script and Makefile templates are
generated by autoconf and automake, they are not checked into the repository.

Many autotools based projects have a `autogen.sh` scrip that checks for the
required tools and takes care of generating the actual build system from the
configuration.

So the frist thing we do, is goto into the `procps` source tree and generate
the build system ourselves:

    cd "$BUILDROOT/src/procps-v3.3.16"
    ./autogen.sh
    cd "$BUILDROOT"

Now, we can build `procps`:

    export ac_cv_func_malloc_0_nonnull=yes
    export ac_cv_func_realloc_0_nonnull=yes
    auto_build "procps-v3.3.16" --enable-watch8bit --disable-kill --with-gnu-ld

As you can see, some clutches are required here. First of all, the configure
script attempts to find out if `malloc(0)` and `realloc(0)` return NULL or
something else.

Technically, when trying to allocate 0 bytes of memory, the C standard permits
the standard library to return a `NULL` pointer instead of a valid pointer to
some place in memory. Some libraries like the widely used `glibc` opted to
instead return a valid point. Many programs pass a programatically generated
size to `malloc` and assume that `NULL` means "out of memory" or similar
dramatic failure, especially if `glibc` behaviour encourages this.

Instead of fixing this, some programs instead decided to add a compile time
check and add a wrappers for `malloc`, `realloc` and `free` if it
returns `NULL`. Since we are cross compiling, this check cannot be run. So
we set the result variables manually, the `configure` script "sees" that and
skips the check.

The `--enable-watch8bit` flag enables propper UTF-8 support for the `watch`
program, for which it requires `ncursesw` instead of regular `ncurses` (but
ironically this is one of the packages that fails without the symlink
of `ncurses` to `ncursesw`).

The other flag `--disable-kill` compiles the package without the `kill` program
for the reasons stated above and the final flag `--with-gnu-ld` tells it that
the linker is the GNU version of `ld` which it, by default, assumes to not be
the case.


### psmisc

The `psmisc` package contains a hand full of extra programs for process
management that aren't already in `procps`, namely it contains `fuser`,
`killall`, `peekfd`, `prtstat` and `pstree`.

Similar to `procps`, we need to generate the build system ourselves, but we will
also take the opertunity to apply some changes using `sed`:

    cd "$BUILDROOT/src/psmisc-v22.21"
    sed -i 's/ncurses/ncursesw/g' configure.ac
    sed -i 's/tinfo/tinfow/g' configure.ac
    sed -i "s#./configure \"\$@\"##" autogen.sh
    ./autogen.sh
    cd "$BUILDROOT"

The frist two `sed` lines patch the configure script to try `ncursesw`
and `tinfow` instead of `ncruses` and `tinfo` respectively.

The third `sed` line makes sure that the `autogen.sh` _does not_ run the
configure script once it is done.

With that done, we can now build `psmisc` with largely the similar fixes:

    export ac_cv_func_malloc_0_nonnull=yes
    export ac_cv_func_realloc_0_nonnull=yes
    export CFLAGS="-O2 -include limits.h -include sys/sysmacros.h"
    auto_build "psmisc-v22.21"

The first two are explained in the `procps` build, the final `export CFLAGS`
line passes some additional flags to the C compiler. The underlying problem
is that this release of `psmisc` uses the `PATH_MAX` macro from `limits.h`
in some places and the `makedev` macro from `sys/sysmacros.h`, but includes
neither of those headers. This works for them, because `glibc` includes those
from other headers that they include, but `musl` doesn't. Using the `-incldue`
option, we force `gcc` to include those headers before processign any C file.

When you are don with this, don't forget to

    unset CFLAGS

Lastly, we get rid of the `libtool` archive installed by `procps`:

    rm "$SYSROOT/lib/libprocps.la"

### The GNU nano text editor

GNU nano is an `ncurses` based text editor that is fairly user friendly and
installed by default on many Debian based distributions. Being a GNU program,
it knows how to use autotools and is fairly simple to build and install:

    auto_build "nano-5.6.1"

Along with the program itself it also installs a lot of scripts for syntax
highlighting. There is not much more to say here, other than maybe that it
has an easter egg, that we could disable through a `configure` flag.


## Archival and Compression Programs

### GNU tar and friends

On Unix-like systems `tar`, the **t**ape **ar**chive program, is
basically *the standard* archival program.

The tar format itself is dead simple. Files are simply glued together with
a 512 byte header in front of every file and null bytes at the end to round
it up to a multiple of 512 bytes. Directories and the like simply use a single
header with no content following. This is also the reason why you can't create
an empty tar file: it would simply be an empty file. Also, tarballs have no
index. You cannot do random access and in order to unpack a single file,
the `tar` program has to scan across the entire file.

Tar itself doesn't do compression. When you see a compressed tarball, such
as a `*.tar.gz` file, it has been fed through a compression program like `gzip`
and must be uncompressed before the `tar` program can handle it. Programs
like `gzip` only do compression of individual files and have no idea what they
process. As a result, `gzip` will compress across tar headers and you really
need to unpack and scan the entire thing when you want to unpack a single file.

The `tar` program *can* actually work with compressed tar archives, but what
it does (or at least what GNU tar does) internally is, checking at run time if
the compressor program is available and starting it as a child process that it
through which it feeds the data.

Compression formats typically used together with `tar` are `xz`, `gzip`
and `bzip2`. Nowadays `Zstd` is also slowly gaining adoption.

The xz-uilities, GNU gzip and GNU tar are fairly simple to build, since they
all use the GNU build system:

    auto_build "xz-5.2.5"
    auto_build "gzip-1.10"
    auto_build "tar-1.34"

Of course, they will also install development headers, libraries, a bunch of
wrapper shell script that allow using `grep`, `less` or `diff` on compressed
files, and a lot of documentation.

The `xz` package installs a `libtool` archive that we simply remove:

    rm "$SYSROOT/lib/liblzma.la"

The GNU tar package also installs a `libexec` helper called `rmt`,
the **r**e**m**ote **t**ape drive server.


Of course, the `bzip2` program is a bit more involved, since it uses a custom
Makefile.

We first setup our build directory in the usual way:

    mkdir -p "$BUILDROOT/build/bzip2-1.0.8"
    cd "$BUILDROOT/build/bzip2-1.0.8"
    srcdir="$BUILDROOT/src/bzip2-1.0.8"

Then we copy over the source files:

    cp "$srcdir"/*.c .
    cp "$srcdir"/*.h .
	cp "$srcdir"/words* .
    cp "$srcdir/Makefile" .

We manually compile the Makefile targets that we are interested in:

    make CFLAGS="-Wall -Winline -O2 -D_FILE_OFFSET_BITS=64 -O2 -Os" \
         CC=${TARGET}-gcc AR=${TARGET}-ar \
         RANLIB=${TARGET}-ranlib libbz2.a bzip2 bzip2recover

The compiler, archive tool `ar` for building static libraries, and `ranlib`
(indexing tool for static libraries) are manually specified on the command
line.

We copy the programs, library and header over manually:

    cp bzip2 "$SYSROOT/bin"
    cp bzip2recover "$SYSROOT/bin"
    cp libbz2.a "$SYSROOT/lib"
    cp bzlib.h "$SYSROOT/usr/include"
    ln -s bzip2 "$SYSROOT/bin/bunzip2"
    ln -s bzip2 "$SYSROOT/bin/bzcat"

The symlinks `bunzip2` and `bzcat` both point to the `bzip2` binary which
when run deduces from the path that it should act as a decompression tool
instead.

Bzip2 also provides a bunch of wrapper scripts like gzip and xz:

    cp "$srcdir/bzdiff" "$SYSROOT/bin"
    cp "$srcdir/bzdiff" "$SYSROOT/bin"
    cp "$srcdir/bzmore" "$SYSROOT/bin"
    cp "$srcdir/bzgrep" "$SYSROOT/bin"
    ln -s bzgrep "$SYSROOT/bin/bzegrep"
    ln -s bzgrep "$SYSROOT/bin/bzfgrep"
    ln -s bzmore "$SYSROOT/bin/bzless"
    ln -s bzdiff "$SYSROOT/bin/bzcmp"
    cd "$BUILDROOT"


### Zlib

Zlib is a library that implements the deflate compression algorithm that is used
for data compression in formats like `gzip` or `zip` (and thanks to `zlib` also
in a bunch of other formats).

In case you are wondering why we install `zlib` this after `gzip` if it uses the
same base compression algorithm: the later has it's own implmentation and won't
benefit from an installed version of zlib.

Because `zlib` also rolls it's own configure script, we do the same dance again
with copying the required stuff over into our build directory:

    mkdir -p "$BUILDROOT/build/zlib-1.2.11"
    cd "$BUILDROOT/build/zlib-1.2.11"
    srcdir="$BUILDROOT/src/zlib-1.2.11"

    cp "$srcdir"/*.c "$srcdir"/*.h "$srcdir"/zlib.pc.in .
    cp "$srcdir"/configure "$srcdir"/Makefile* .

We can then proceed to cross compile the static `libz.a` library:

    CROSS_PREFIX="${TARGET}-" prefix="/usr" ./configure
    make libz.a

The target is named explicitly here, because by default the `Makefile` would
try to compile a couple test programs as well.

With everything compiled, we can then copy the result over into our
sysroot directory and go back to the build root:

    cp libz.a "$SYSROOT/usr/lib/"
    cp zlib.h "$SYSROOT/usr/include/"
    cp zconf.h "$SYSROOT/usr/include/"
    cp zlib.pc "$SYSROOT/usr/lib/pkgconfig/"
	cd "$BUILDROOT"


## Miscellaneous

### The file program

The `file` command line program can magically identify and describe tons of
file types. The core functionallity is actually implemented in a library
called `libmagic` that comes with a data base of magic numbers.

There is one little quirk tough, in order to cross compile `file`, we need
the same version of `file` already installed, so it can build the magic data
base.

So first, we manually compile `file` and install it in our toolchain directory:

    srcdir="$BUILDROOT/src/file-5.40"
    mkdir -p "$BUILDROOT/build/file-host"
    cd "$BUILDROOT/build/file-host"

    unset PKG_CONFIG_SYSROOT_DIR
    unset PKG_CONFIG_LIBDIR
    unset PKG_CONFIG_PATH

    $srcdir/configure --prefix="$TCDIR" --build="$HOST" --host="$HOST"
    make
    make install

At this point, it should be fairly straight forward to understand what this
does. The 3 `unset` lines revert the `pkg-config` paths so that we can propperly
link it against our host libraries.

After that, we of course need to reset the `pkg-config` exports:

    export PKG_CONFIG_SYSROOT_DIR="$SYSROOT"
    export PKG_CONFIG_LIBDIR="$SYSROOT/lib/pkgconfig"
    export PKG_CONFIG_PATH="$SYSROOT/lib/pkgconfig"

After that, we can simply install `file`, `libmagic` and the data base:

    auto_build "file-5.40"

Of course, `libmagic` installs a `libtool` archive, so we delete that:

    rm "$SYSROOT/lib/libmagic.la"

The reason for building this after all the other tools is that `file` can make
use of the compressor libraries we installed previously to peek into compressed
files, so for instance, it can identify a gzip compressed tarball as such
instead of telling you it's a gzip compressed whatever.

### The util-linux collection

The `util-linux` pacakge contains a large collection of command line tools that
implement Linux specific functionallity that is missing from more generic
collections like the GNU core utilities. Among them are essentials like
the `mount` program, loop back device control or `rfkill`. I won't list all of
them, since we individually enable them throught he `configure` script, so a you
can see a detailed list below.

The package can easily be built with our autotools helper:

    auto_build "util-linux-2.36" --without-systemd --without-udev \
        --disable-all-programs --disable-bash-completion --disable-pylibmount \
        --disable-makeinstall-setuid --disable-makeinstall-chown \
        --enable-mount --enable-losetup --enable-fsck --enable-mountpoint \
        --enable-fallocate --enable-unshare --enable-nsenter \
        --enable-hardlink --enable-eject --enable-agetty --enable-wdctl \
        --enable-cal --enable-switch_root --enable-pivot_root \
        --enable-lsmem --enable-ipcrm --enable-ipcs --enable-irqtop \
        --enable-lsirq --enable-rfkill --enable-kill --enable-last \
        --enable-mesg --enable-raw --enable-rename --enable-ul --enable-more \
        --enable-setterm --enable-libmount --enable-libblkid --enable-libuuid \
        --enable-libsmartcols --enable-libfdisk

As mentioned before, the lengthy list of `--enable-<foo>` is only there because
of the `--disable-all-programs` switch that turns everything off that we don't
excplicitly enable.

Among the things we skip are programs like `login` or `su` that handle user
authentication. However, the `agetty` program which implements the typical
terminal login promt is explicitly enabled. We will get back to that later
on, when setting up an init system and `shadow-utils` for the user
authentication.

After the build is done, some cleanup steps need to be taken care of:

    mv "$SYSROOT"/sbin/* "$SYSROOT/bin"
    rm "$SYSROOT/lib"/*.la
    rmdir "$SYSROOT/sbin"

Even when configuring util-linux to install into `/bin` instead of `/sbin`,
it will still stubbornly install `rfkill` into `/sbin`.

The `*.la` files that are removed are from the helper libraries `libblkid.so`,
`libsmartcols.so`, `libuuid.so` and`libfdisk.so`.


## Cleaning up

A signifficant portion of the compiled binaries consists of debugging symbols
that a can easily be removed using a strip command.

The following command line uses the `find` command to locate all regular
files `-type f`, i.e. it won't print symlinks or directories and for each of
them runs the `file` command to identify their file type. The list is fed
through `grep ELF` to filter out the ones identified as ELF files (because
there are also some shell scripts in there, which we obviously can't strip)
and then fed through`'sed` to remove the `: ELF...` description.

The resulting list of excutable files is then passed on to the `${TARGET}-strip`
program from our toolchain using `xargs`:

    find "$SYSROOT/bin" -type f -exec file '{}' \; | \
    grep ELF | sed 's/: ELF.*$//' | xargs ${TARGET}-strip -xs

On my Fedora system, this drastically cuts the size of the `/bin` directory
from ~67.5 MiB (28,595,781 bytes) down to ~7 MiB (7,346,105 bytes).

We do the same thing a second time for the `/lib` directory. Please note the
extra argument `! -path '*/lib/modules/*'` for the `find` command to make sure
we skip the kernel modules.

    find "$SYSROOT/lib" -type f ! -path '*/lib/modules/*' -exec file '{}' \; |\
    grep ELF | sed 's/: ELF.*$//' | xargs ${TARGET}-strip -xs

On my system, this reduces the size of the `/lib` directory
from ~67 MiB (70,574,158 bytes) to ~60 MiB (63,604,818 bytes).

If you are the kind of person who loves to ramble about "those pesky shared
libraries" and insist on statically linking everything, you should take a look
of what uses up that much space:

The largest chunk of the `/lib` directory, is kernel modules. On my system
those make up ~54.5 MiB (57,114,381 bytes) of the two numbers above. So if you
are bent on cutting the size down, you should start by tossing out modules you
don't need.


## Packing into a SquashFS Filesystem

SquashFS is a highly compressed, read-only filesystem that is packed offline
into an archive that can than be mounted by Linux.

Besides the high compression, which drastically reduces the on-disk memory
footprint, being immutable and read-only has a number of advantages in itself.
Our system will stay in a well defined state and the lack of write operations
reduces wear on the SD card. Writable directories (e.g. for temporary files
in `/tmp` or for things like log files that you actually want to write) are
typically achieved by mounting another filesystem to a directory on the
SquashFS root (e.g. from another SD card partition, or simply mounting
a `tmpfs`).

This can also be combined with an `overlayfs`, where a directory on the
SquashFS can be merged with a directory from a writable filesystem. Any changes
to existing files are implemented by transparentyl copying the file to the
writable filesystem first and editing it there. Erasing the writable directory
essentially causes a "factory reset" to the initial content.

We will revisit this topic later on, for now we are just interested in packing
the filesystem and testing it out.

For packing a SquashFS image, we use [squashfs-tools-ng](https://github.com/AgentD/squashfs-tools-ng).

The reason for using `squashfs-tools-ng` is that it contains a handy tool
called `gensquashfs` that takes an input listing similar to `gen_init_cpio`.

On some systems, you can just install it from the package repository. But be
aware that I'm going to use a few features that were introduced in version 1.1,
which currently isn't packaged on some systems.

If you are building the package yourself, you need the devlopment packages for
at least one of the compressors that SquashFS supports (e.g. xz-utils or Zstd).

Because we compile a host tool again, we need to unset the `pkg-config` path
variables first:

    unset PKG_CONFIG_SYSROOT_DIR
    unset PKG_CONFIG_LIBDIR
    unset PKG_CONFIG_PATH

We build the package the same way as other host tools and install it into
the toolchain directory:

    srcdir="$BUILDROOT/src/squashfs-tools-ng-1.1.0"
    mkdir -p "$BUILDROOT/build/squashfs-tools-ng-1.1.0"

    cd "$BUILDROOT/build/squashfs-tools-ng-1.1.0"
    $srcdir/configure --prefix=$TCDIR --host=$HOST --build=$HOST

    make
    make install
    cd "$BUILDROOT"

The listing file for the SquashFS archive is a little bit longer than the
one for the initital ramfs. I included [a prepared version](list.txt).

If you examine the list, you will find that many files of the sysroot aren't
packed. Specifically the header files, man pages (plus other documentation)
and static libraries. The development files are omitted, because without
development tools (e.g. gcc, ...) they are useless on the target system.
Likewise, we don't have any tools yet to actually view the documentation files.
Omitting those safes us some space.

Using the listing, we can pack the root filesystem using `gensquashfs`:

    gensquashfs --pack-dir "$SYSROOT" --pack-file list.txt -f rootfs.sqfs


On my system, the resulting archive is ~18.3 MiB in size (19,238,912 bytes).

For comparison, I also tried the unstripped binaries, resuling in a SquashFS
archive of ~26.7 MiB (27,971,584 bytes) and packing without any kernel modules,
resulting in only ~4.4 MiB (4,583,424 bytes).


## Testing it on Hardware

First of, we will revise the `/init` script of our initial ram filesystem as
follows:

    cd "$BUILDROOT/build/initramfs"

    cat > init <<_EOF
    #!/bin/sh

    PATH=/bin

    /bin/busybox --install
    /bin/busybox mount -t proc none /proc
    /bin/busybox mount -t sysfs none /sys
    /bin/busybox mount -t devtmpfs none /dev

    boot_part="mmcblk0p1"
    root_sfs="rootfs.sqfs"

    while [ ! -e "/dev/$boot_part" ]; do
        echo "Waiting for device $boot_part"
        busybox sleep 1
    done

    mount "/dev/$boot_part" "/boot"

    if [ ! -e "/boot/${root_sfs}" ]; then
        echo "${root_sfs} not found!"
        exec /bin/busybox sh
        exit 1
    fi

    mount -t squashfs /boot/${root_sfs} /newroot
    umount -l /boot

    umount -l /dev
    umount /sys
    umount /proc

    unset -v root_sfs boot_part

    exec /bin/busybox switch_root /newroot /bin/bash
    _EOF

This new init script starts out pretty much the same way, but instead of
dropping directly into a `busybox` shell, we first mount the primrary
partition of the SD card (in my case `/dev/mmcblk0p1`) to `/boot`.

As the device node may not be present yet in the `/dev` filesystem, we wait
in a loop for it to pop up.

From the SD card, we then mount the `rootfs.sqfs` that we just generated,
to `/newroot`. There is a bit of trickery involved here, because traditional,
Unix-like operating systems can only mount devices directly. The mount point
has a filesystem driver associated with it, and an underlying device number.
In order to mount an archive from a file, Linux has a loop back block device,
which works like a regular block device, but reflects read/write access back
to an existing file in the filesystem. The `mount` command transparently takes
care of setting up the loop device for us, and then actually.

After that comes a bit of a mind screw. We cleanup after ourselves, i.e. unset
the environment variables, but also unmount everything, *including* the `/boot`
directory, from which the SquashFS archive was mounted.

Note the `-l` parameter for the mount, which means *lazy*. The kernel detaches
the filesystem from the hierarchy, but keeps it open until the last reference
is removed (in our case, held by the loop back block device).

The final `switch_root` works somewhat similar to a `chroot`, except that it
actually does change the underlying mountpoints and also gets rid of the
initial ram filesystem for us.

After extending the init script, we can rebuild the initramfs:

    ./gen_init_cpio initramfs.files | xz --check=crc32 > initramfs.xz
    cp initramfs.xz "$SYSROOT/boot"
    cd "$BUILDROOT"

We, again, copy everything over to the SD card (don't forget the rootfs.sqfs)
and boot up the Raspberry Pi.

This should now drop you directly into a `bash` shell on the SquashFS image.

If you try to run certain commands like `mount`, keep in mind that `/proc`
and `/sys` aren't mounted, causing the resulting error messages. But if you
manually mount them again, everything should be fine again.

# Building a More Sophisticated Userspace

After revisiting the structure of our `sysroot` directory, we will build
and install some basic packages:

* `tzdata`
* `ncurses`
* `readline`
* `zlib`
* `bash`
* `bash-completion` scripts from Debian
* `coreutils`
* `diffutils`
* `findutils`
* `util-linux`
* `grep`
* `less`
* `xz`
* `gzip`
* `bzip2`
* `tar`
* `sed`
* `gawk`
* `procps-ng`
* `psmisc`
* `file`
* `shadow`
* `inetutils`
* `nano`
* [gcron](https://github.com/pygos/cron)
* [usyslog](https://github.com/pygos/usyslog)
* [pygos init](https://github.com/pygos/init)
* `init-scripts`

Those should provide us with a pretty decent base system and GNU/Linux command
line environment to work in. It's a lot of stuff, so I'd advise you to automate
most of setps in some way using shell scripts. I will also provide some usefull
utility functions below.

I chose `nano` as text editor because it's dead simple to use. Furthermore, I
used the init system from Pygos because it's configuration is a little more
sophisticated and simpler than having to write dozens of shell scripts for a
System V style init. Also, it requires basically no dependencies.

Although networking is listed below, we need at least the `hostname` program
from the `inetutils` package, so I added it to the list of the base system.

After building this base system, we will again put it all together, i.e.
package the whole thing into a SquashFS image, modify and rebuild the initrd,
and take a closer look at the bootstrap processes through our `init` all the
way to spawning `getty` instances on the console (remember, the goal here is
to actually understand what's going on in the end).

Once everything is working, we build a few more packages for wired networking:

* `openssl`
* `ldns`
* `ntp`
* `iana-etc`
* `libmnl`
* `libnftnl`
* `gmp`
* `iproute2`
* `nftables`
* `dhcpcd`
* `libnl3`
* `libpcup`
* `tcpdump`
* `openssh`

We will modify the init scripts to obtain an IPv4 network configuration via
DHCP on the wired Ethernet interface, configure basic firewalling
through `nftables`, discussing a little bit of Linux network configuration
and debugging along the way.

An init script and a script for `dhcpcd` are added to fetch current date
and time via `ntp`, since the Raspberry Pi does not have a real time clock
on board.

As a final step, we will take a look at setting up a wireless access point
that NAT forwards traffic from its clients via the wired Ethernet port. This
requires the following additional packages:

* `libbsd`
* `expat`
* `unbound`
* `dnsmasq`
* `hostapd`
* `iw`

# TODO: write the remaining documentation


