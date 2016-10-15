#!/bin/bash
#Downloads apt indices so that you can copy them on a offline debian machine. 
#Copy the indices to /var/lib/apt/lists (you need to be root to perform this step)


#Downloads Release and Release.gpg
wget http://http.debian.net/debian/dists/jessie/Release -O http.debian.net_debian_dists_jessie_Release
wget http://http.debian.net/debian/dists/jessie/Release.gpg -O http.debian.net_debian_dists_jessie_Release.gpg

#Download the Packages.gz file of the "main" section
wget http://http.debian.net/debian/dists/jessie/main/binary-i386/Packages.gz
gzip -d Packages.gz
mv Packages http.debian.net_debian_dists_jessie_main_binary-i386_Packages

#Download Translation-en.gz (change the language special code if you need it)
#wget http://http.debian.net/debian/dists/jessie/main/i18n/Translation-en.bz2
