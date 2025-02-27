#!/bin/bash

set -e
set -o pipefail

# Check if configuration file exists and read it
CONFIG="$HOME/.config/markdown.conf"
[ -r "$CONFIG" ] && . "$CONFIG"

# ---- if $CONFIG does not exists we set some DEFAULTS ----

# Set default document language if not defined
[ -z "$HTML_LANG" ] && HTML_LANG="en"

# Set default author if not defined
[ -z "$AUTHOR" ] && AUTHOR="$USER"

# ---- Functions ----

# Set title in HEAD TITLE tag
get_title(){
  local t=$(head -n1 ${INPUT})
  t=${t##\#\ }
  echo $t
}

# Paragraphs <p></p> 
check_paragraph() {
  local ret=0
  echo $line | grep -q -E "^$" || ret=1
  if [ "$ret" = "0" ]; then
    paragraph_toggle
  fi
}

paragraph_toggle() {
  if [ "$p_open" = "n" ]; then
      echo "<p>" >> $OUTPUT
      p_open="y"
    else
      echo "</p>" >> $OUTPUT
      p_open="n"
  fi
}

# We output h1, h2, ..., to h5
html_header() {
  # how many "#" do we have? 
  local n=$(echo $1 | wc -m)
  n=$((n-1)) # remove '\n' from count
  
  # Remove '#'
  local t=$line
  t=$(echo $t | sed -E 's/(#)+ //')
  
  # if we have a paragraph open, we close it
  if [ "$p_open" = "y" ]; then paragraph_toggle; fi

  # Output the header
  echo "<h$n>$t</h$n>" >> $OUTPUT
}



# ---- MAIN PROGRAM ---- #

# Parsing Arguments
INPUT="$1"
OUTPUT="$2"

# If we can't read the INPUT file EXIT (Error 404)
if [ ! -r $INPUT ]; then
  echo ERROR: File \"$1\" not found
  exit 404
fi

# Start convertion..

# if $OUTPUT is not provided we use the input filename as a base
[ -z "$OUTPUT" ] && OUTPUT=${INPUT%%.md}.html
echo "Converting $INPUT to $OUTPUT"

# Output HTML

# Set title
TITLE=$(get_title)


# Print HTML Head
cat > $OUTPUT << EOF
<html lang="$HTML_LANG"><head>
<title>$TITLE</title>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta charset="utf-8">
<meta name="author" content="$AUTHOR">
</head><body>    
EOF

# Convert content - TODO

# A paragraph is text between two empty lines, we assume that the first line is not empty
p_open=n

# We parse every line
while read line; do

  # Is the line empty? if so we begin a paragraph
  check_paragraph $line

  # Is the line a header?
  pattern=$(echo $line | grep -E "^\#+") || true
  if [ -n "$pattern" ]; then 
    html_header $line
    continue
  fi
 
 # We parse every word
 for word in $line; do
  echo -n "DEBUG: "
  echo "$word "
 done
done < $INPUT

# Print HTML end    
cat >> $OUTPUT << "EOF"
</body></html>
EOF

# End of output
exit 0

