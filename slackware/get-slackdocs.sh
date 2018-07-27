#!/bin/bash

#This should download the whole slackdocs wiki and convert the links for offline usage.
#The links in the page toc:start.html do not get converted for some strange reason

wget --no-check-certificate -E -r -k -p http://docs.slackware.com/doku.php?id=toc:start -l 1 --header="X-DokuWiki-Do: export_html"

