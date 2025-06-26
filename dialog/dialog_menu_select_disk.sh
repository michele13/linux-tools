#!/bin/bash

rm /tmp/devices.txt 2>/dev/null

echo "# find devices"

for DEVICE in /dev/* ; do
  DEV=$(echo "${DEVICE##*/}")
  SYSDEV=$(echo "/sys/class/block/$DEV")

  case $DEV in
    *loop*) continue ;;
  esac

  if [ ! -d "$SYSDEV" ] ; then
    continue
  fi
  
  echo $DEVICE >> /tmp/devices.txt

done


echo "# Begin Dialog Menu"

WIDTH=0
HEIGHT=0
TITLE="Disk Selection"
MENU_HEIGHT=0
MENU_TEXT="Choice a disk or partition:"

declare -a OPTIONS

echo "# while read"

count=1
while IFS= read -r line; do
  OPTIONS+=( $((count++)) "$line" )
done < /tmp/devices.txt

echo "# Dialog"

CHOICE=$(dialog --stdout --clear \
	--title "$TITLE" \
	--menu "$MENU_TEXT" \
	$HEIGHT $WIDTH $MENU_HEIGHT \
	"${OPTIONS[@]}" \
	)

d=$(sed -n "${CHOICE}p" "/tmp/devices.txt")

echo $d



