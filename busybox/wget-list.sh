#!/bin/sh
#downloads a list of files from a text file containing urls

help() {
echo "Downloads a list of files from a text file containing urls"
echo "usage: wget-list.sh [TEXT FILE]"
exit;}


#usage: wget-list.sh [TEXT FILE]


if [ -z $1 ]; then help; fi

# fix -why this does not work? Commenting out
#if [ "$INPUT"=="--help" ]; then help
#else

cat $1 | while read file; do
busybox wget $file
done

#fi
