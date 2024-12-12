#!/bin/sh

mkdir -pv .venv/bin
cp venv-activate.sh .venv/bin/activate.sh
ln -s /bin/busybox .venv/bin/busybox
ln -s /bin/bash .venv/bin/bash

for x in $(.venv/bin/busybox --list); do
  ln -s busybox .venv/bin/$x
done
