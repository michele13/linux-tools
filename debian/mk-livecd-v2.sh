#!/bin/bash

# Copyright (C) 2015 Michele Bucca (michele.bucca@gmail.com)

#This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.



DEBIAN_VERSION="$2"
WORKDIR="$PWD/$3"
MIRROR="http://httpredir.debian.org/debian/"
ROOT="$WORKDIR/chroot"
PACKAGES="grub-pc squashfs-tools aufs-tools man manpages alsa-base alsa-utils alsa-tools live-boot dbus console-data zip unzip bzip2 xz-utils keyboard-configuration tzdata"
#KERNEL_VERSION="3.16.0-4-"
KERNEL="linux-image-686-pae"
FIRMWARE="firmware-linux firmware-linux-free firmware-linux-nonfree firmware-b43-installer firmware-b43legacy-installer firmware-atheros firmware-brcm80211 firmware-intelwimax firmware-ipw2x00 firmware-iwlwifi firmware-libertas firmware-myricom firmware-netxen firmware-qlogic firmware-ralink firmware-realtek firmware-zd1211"
KEYRING="debian-archive-keyring"
ISOFILE="$WORKDIR/$4"

function usage
{
echo "usage: $0 FUNCTION DEBIAN_VERSION DIRECTORY ISOFILE"
echo ""
echo "list of executable functions:"
echo ""
echo "install (installs the programs that are needed in order to make this script work)"
echo "create (executes all the funcions listed below in order to make a Live CD)"
echo "bootstrap (create the root filesystem of the squashfs file)"
echo "mount_chroot (mounts essential filesystems on the chroot)"
echo "configure (creates essential configuration files)"
echo "install_software (include essential packages in the Live CD)"
echo "clean_chroot (cleans the root filesystem before it is compressed into a squashfs file)"
echo "make_livecd_tree (builds the Live CD final structure)"
echo "make_iso (create a ISO from the Live CD tree)"
exit
}


function check_root
{
if [ $UID -ne 0 ]
then
echo you must run this script as root!
exit
fi
}

# install dependencies

function install
{
apt-get update
apt-get -y install genisoimage debootstrap squashfs-tools grub-pc
exit
}

function bootstrap 
{
mkdir -p "$WORKDIR/binary"
debootstrap "$DEBIAN_VERSION" "$ROOT" "$MIRROR"
}

function mount_chroot
{
mount none -t proc "$ROOT/proc/"
mount none -t sysfs "$ROOT/sys/"
mount none -t devpts "$ROOT/dev/pts/"

}

function configure
{
# change hostname
echo debian > "$ROOT/etc/hostname"

# writes sources.list file
rm "$ROOT/etc/apt/sources.list"

echo "deb http://httpredir.debian.org/debian $DEBIAN_VERSION main contrib non-free" >> "$ROOT/etc/apt/sources.list"
echo "#deb-src http://httpredir.debian.org/debian $DEBIAN_VERSION main contrib non-free" >> "$ROOT/etc/apt/sources.list"
echo "" >> "$ROOT/etc/apt/sources.list"
echo "deb http://httpredir.debian.org/debian $DEBIAN_VERSION-updates main contrib non-free" >> "$ROOT/etc/apt/sources.list"
echo "#deb-src http://httpredir.debian.org/debian $DEBIAN_VERSION-updates main contrib non-free" >> "$ROOT/etc/apt/sources.list"
echo "" >> "$ROOT/etc/apt/sources.list"
echo "deb http://security.debian.org/ $DEBIAN_VERSION/updates main contrib non-free" >> "$ROOT/etc/apt/sources.list"
echo "#deb-src http://security.debian.org/ $DEBIAN_VERSION/updates main contrib non-free" >> "$ROOT/etc/apt/sources.list"


# avoids installation of recommended and suggested packages
cat << "EOF" > "$ROOT/etc/apt/apt.conf.d/99Recommends"

Apt::Install-Recommends "false";
Apt::Install-Suggests "false";
EOF

# set empty root password
chroot "$ROOT" passwd -d root

}

function install_software
{
# install software
chroot "$ROOT" apt-get update
chroot "$ROOT" apt-get -y dist-upgrade
chroot "$ROOT" apt-get -y install $KEYRING

#ISSUE: this passage still needs the intervention of a user, how can I make it automatic?
chroot "$ROOT" apt-get -y --install-recommends install $KERNEL $PACKAGES $FIRMWARE

}

function clean_chroot
{
# clean up $ROOT
chroot "$ROOT" apt-get clean
umount -l "$ROOT/proc" #BUG: could not umount $ROOT/proc because it's in use. Using LAZY UMOUNT
umount "$ROOT/dev/pts" 
umount "$ROOT/sys" 
rm -r $ROOT/tmp/
mkdir $ROOT/tmp/
rm -r $ROOT/var/lib/apt/lists/
mkdir $ROOT/var/lib/apt/lists/
## chroot "$ROOT" history -c #this should be a bash functionality
}

function make_livecd_tree
{
# create CD structure

mkdir -p "$WORKDIR/binary/boot/grub/"
mkdir "$WORKDIR/binary/live/"

# move kernel to the live cd
cp $ROOT/vmlinuz $WORKDIR/binary/live/vmlinuz
cp $ROOT/initrd.img $WORKDIR/binary/live/initrd.img

# create root squashfs image
mksquashfs "$ROOT" "$WORKDIR/binary/live/000-core.squashfs" -b 1M -comp xz -Xbcj x86 -e boot

# generate grub LiveCD menu
cat << "EOF" > "$WORKDIR/binary/boot/grub/grub.cfg"
menuentry "Debian (persistence)" {
linux /live/vmlinuz boot=live persistence
initrd /live/initrd.img
}

menuentry "Debian (no persistence)" {
linux /live/vmlinuz boot=live
initrd /live/initrd.img
}
EOF
}

function list 
{
ls $ROOT/boot/vmlinuz-*
ls $ROOT/boot/initrd-*
}

function make_iso
{
grub-mkrescue -o "$ISOFILE" "$WORKDIR/binary/"
}

function create 
{
bootstrap
mount_chroot
configure
install_software
clean_chroot
make_livecd_tree
make_iso
}


# if the number of arguments is equal to 0 print usage
if [ "$#" -eq "0" ]
then usage
fi

check_root

# if the first argument is "install" execute the install function
if [ "$1" == "install" ]
 then install
fi


# if the number of arguments is NOT equal to 4 print usage
if [ "$#" -ne "4" ]
then
usage
fi


"$1" "$@"
