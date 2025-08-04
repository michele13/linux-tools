#!/bin/sh
# Jail inside a chroot using util-linux unshare ( look for rootless containers)

if [ -z "$1" ]; then
  echo "Jail inside a chroot using util-linux unshare (look for rootless containers)"
  echo "You need to specify a directory to jail into and a program to start"
  exit 1
fi

jail(){
  unshare -m -f -u -U -r -i -p -n -T --map-auto /sbin/chroot $@
}

if [ -z "$2" ]; then
  if [ -x "$1/init" ]; then
      jail $1 /init
    else
      jail $1
  fi
fi  