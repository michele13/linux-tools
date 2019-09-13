#!/bin/bash
# PM is a package manager that looks for source tarballs inside a repository
# and lets you know its location. You can also ask "him" to extract it
# it is useful to keep multiple versions of source packages in one location 

export REPO=/home/michele/sources/

echo "the repository is located in: $REPO"
echo ""


case "$1" in
	search)
	  find $REPO -iname "$2*.tar.*" -print
	  ;;
	
	extract)
	  shift
	for file in "$@"; do
	  for pkg in $(find $REPO -iname "$file*.tar.*" -print); do
	    #tar xf $REPO/$file*.tar.*
	    tar xf $pkg
	  done
	done
	  ;;
	*) echo "Usage: $0 {search|extract} package-version (ex. gcc-8.1.0)"
	exit 1
esac
