#!/bin/bash

set -e
set -o pipefail

DEBUG=1

# Check if configuration file exists and read it
CONFIG="$HOME/.config/markdown.conf"
[ -r "$CONFIG" ] && . "$CONFIG"

# ---- if $CONFIG does not exists we set some DEFAULTS ----

# Set default document language if not defined
[ -z "$HTML_LANG" ] && HTML_LANG="en"

# Set default author if not defined
[ -z "$AUTHOR" ] && AUTHOR="$USER"


# 	------- Functions -------

debug(){
  echo "DEBUG: $@"
}

# Set title in HEAD TITLE tag
get_title(){
  local t=$(head -n1 ${INPUT})
  t=${t##\#\ }
  echo $t
}



# --- Paragraphs <p></p> ---

check_paragraph() {
  local ret=0
  echo $line | grep -q -E "^$" || ret=1
 
  if [ "$ret" = "0" ]; then
    p_open=$(tag_toggle p $p_open)
    debug "OUTPUT "
    echo "" >> $OUTPUT
  fi
}

# If a tag is open it closes it or vice versa
tag_toggle() {
  local tag=$1
  local var=$2
  if [ "$var" = "n" ]; then
      debug "output <$tag>"
      echo -n "<$tag>" >> $OUTPUT
      echo "y"
    else
      debug "output </$tag>"
      echo -n "</$tag>" >> $OUTPUT
      echo "n"
  fi
}



# --- Headers <h*></h*> ---
html_header() {
  # how many "#" do we have? 
  local n=$(echo $1 | wc -m)
  n=$((n-1)) # remove '\n' from count
  
  # Remove '#'
  local t=$line
  t=$(echo $t | sed -E 's/(#)+ //')
  
  # if we have a paragraph open, we close it
  if [ "$p_open" = "y" ]; then 
    p_open=$(tag_toggle p $p_open)
    echo "" >> $OUTPUT
  fi

  # Output the header
  debug "OUTPUT <h$n>$t</h$n>" 
  echo "<h$n>$t</h$n>" >> $OUTPUT
}

# --- bold, italics and both <i> <b> ---

itabold(){
  # how many "*" do we have? 
  local n=$(echo $1 | grep -E -o '\*+' | wc -m)
  n=$((n-1)) # remove '\n' from count
  
  # Get the word
  local w=$(echo $1 | sed 's/(\*+)//g')
  
  
  case $n in
    3)
      strong_open=$(tag_toggle strong $strong_open)
      em_open=$(tag_toggle em $em_open)
      echo -n "$w " >> $OUTPUT ;;
    2)
      strong_open=$(tag_toggle strong $strong_open)
      echo -n "$w " >> $OUTPUT ;;
    1)
      strong_open=$(tag_toggle em $em_open)
      echo -n "$w " >> $OUTPUT ;;      
    *) echo -n "$w " >> $OUTPUT ;;  
  
  esac    
  echo $w
}

# Check the word and call the correct funcion. If it contains "*" call itabold()
# if it contains "`" call code()
format_word() {
  local wrd=$(itabold $1)
  debug "The word is '$wrd'"
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

# Other formatting tags, we assume they are not open
strong_open=n
em_open=n
code_open=n
codeblock_open=n

ln=0
# We parse every line
while IFS= read -r line; do
  #ln=$(($ln + 1)) 
  debug "reading '$line'"
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

  format_word $word
 
 done


done < $INPUT

# Print HTML end    
cat >> $OUTPUT << "EOF"
</body></html>
EOF

# End of output
exit 0

