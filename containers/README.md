# Unshare Containers

Added an example of container with the unshare command (from util-linux). 

## Requirements

- a static copy of **Busybox** installed in the container
- **util-linux** installed on the system

## list of files

- **`unshare.sh`**: Use this script to enter the container
- **`init`**: the init script executed by unshare.
- **`profile.sh`**: it behaves like `$HOME/.profile` on a normal system

## Create the container

```shell

mkdir -p container/{bin,proc,sys,dev}
cp busybox-i686 container/bin/busybox
cd container/bin

for prog in $(./busybox --list); do
  ln -s busybox $prog
done

```
