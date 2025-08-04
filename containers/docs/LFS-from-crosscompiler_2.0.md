# LFS from Nothing

We will build LFS starting from a static busybox binary and a static musl cross-compiler.

## 1. Preparations

create a directory where to build LFS. We will be using a unsare container.

```shell

mkdir -pv unshare-host/{bin,proc,sys,dev,root}
cp /bin/busybox unshare-host/bin/busybox

```

### Setting up the Environment

create a `.profile` file inside the root *HOME* directory of the container

```shell

cat > unshare-host/root/.profile << "EOF"

PATH=/bin:/tools/bin:$PATH
export PATH
EOF

```

create a script that will be used to enter inside the container:

```shell

cd unshare-host

cat > init << "EOF"
#!/bin/sh
ROOT=$1
[ -n "$ROOT" ] || ROOT="$PWD"
$ROOT/bin/busybox unshare -m -u -i -n -p -U -f -r --mount-proc chroot $ROOT /bin/busybox ash shell.sh
EOF

cat > shell.sh << "EOF"
#!/bin/busybox ash
[ -z "$NOCLEAR" ] && exec env -i NOCLEAR=1 busybox ash "$0"
unset NOCLEAR
HOME=/root
TERM=$TERM
LANG=C
LC_ALL=C
PS1='\u:\w$ '
PATH=/tools/bin:/usr/bin:/bin
export PATH HOME TERM PS1 LANG LC_ALL
busybox mount -t proc none /proc
busybox ash -l
EOF

chmod 755 init
chmod 755 shell.sh

```


### Installing the Cross Compiler

Download and install a static cross-toolchain

```shell

wget -c https://musl.cc/i686-linux-musl-cross.tgz
tar xf i686-linux-cross.tgz
mv i686-linux-cross cross-tools

```

### GNU Make

We need make to build everything

```shell

  ./configure --host=i686-linux-musl --prefix= \
    --disable-dependency-tracking

```    

we compile the package now

```shell

  ./build.sh

```

## 2. Build LFS tools

### Binutils and GCC


Binutils and GCC build just fine

### Linux Headers


We now build the linux headers:

```shell

  make CC="$CC" HOSTCC="$HOSTCC" mrproper headers

```

Install the headers.

```shell

  find usr/include -type f ! -name '*.h' -delete
  cp -rv usr/include $LFS/usr

```

### Glibc


**Build Dependencies:** Gawk, Bison and Python

### Bison


**Build Dependencies:** m4
