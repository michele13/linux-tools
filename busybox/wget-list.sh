#!/bin/sh
cat $1 | while read file; do
busybox wget $file
done
