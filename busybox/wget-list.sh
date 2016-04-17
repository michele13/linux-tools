#!/bin/sh
#usage: wget-list.sh [TEXT FILE]
cat $1 | while read file; do
busybox wget $file
done
