#!/bin/bash

set -e
set -o pipefail

DEBUG=1

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 file.md"
    exit 1
fi

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



countchar() {
  n=$(echo $1 | wc -m)
  n=$((n-1))
}  

header() {
  debug "$line"
  if [ -n "$line" ]; then
    # how many "#" are in the line  ?
    n=$(echo $1 | wc -m)
    n=$((n-1))
    content=$(echo "$line" | sed -E "s/($header_pattern)//")
    result="<h$n>$content</h$n>"
    debug "$result"
    echo "$result" >> $OUTPUT
  fi
}

ol() {
  if [ -n "$line" ]; then
  debug "$line"
    if [ $in_ol -eq 0 ]; then
      debug "<ol>" 
      echo "<ol>" >> $OUTPUT
      in_ol=1
    fi
  content=$(echo "$line" | sed -E "s/$ol_pattern//")
  result="<li>$content</li>"
  debug "$result"
  echo "$result" >> $OUTPUT
  fi
}

ul() {
  if [ -n "$line" ]; then
  debug "$line"
    if [ $in_ul -eq 0 ]; then
      debug "<ul>" 
      echo "<ul>" >> $OUTPUT
      in_ul=1
    fi
  content=$(echo "$line" | sed -E "s/$ul_pattern//")
  result="<li>$content</li>"
  debug "$result"
  echo "$result" >> $OUTPUT
  fi
  
}

strong(){
  if [ $in_strong -eq 0 ]; then
            in_strong=1
            debug BEFORE: $line
            line=$(echo "$line" | sed -E "s/$strong_pattern/<strong>\1/")
            debug AFTER: $line
            echo $line
          else
            in_strong=0
            line=$(echo "$line" | sed -E "s/$strong_end_pattern/\1<\/strong>/")
            echo $line
  fi
}

# Are we inside a <TAG>? 
in_ul=0
in_ol=0
in_p=0
in_em=0
in_strong=0


close_ul() {
  if [ $in_ul -eq 1 ]; then
   debug "</ul>"
   echo "</ul>" >> "$OUTPUT"
   in_ul=0
  fi
}


close_ol() {
  if [ $in_ol -eq 1 ]; then
   echo "</ol>" >> "$OUTPUT"
   debug "</ol>"
   in_ol=0
  fi
}

close_p() {
  if [ $in_p -eq 1 ]; then
   echo "</p>" >> "$OUTPUT"
   debug "</p>"
   in_p=0
  fi
}


# ---- MAIN PROGRAM ---- #

# Parsing Arguments
INPUT="$1"
OUTPUT="${INPUT%.md}.html"

# If we can't read the INPUT file EXIT (Error 404)
if [ ! -r $INPUT ]; then
  echo ERROR: File \"$1\" not found
  exit 404
fi

# --- convertion --- #

TITLE=$(get_title)

{
# Print HTML Head 
cat << EOF > "$OUTPUT"
<!doctype html>
<html lang="$HTML_LANG"><head>
<title>$TITLE</title>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta charset="utf-8">
<meta name="author" content="$AUTHOR">
</head><body>    
EOF

# Process Markdown

#   Markdown Patterns

    header_pattern="^\#+ "
    ul_pattern="(^\* )|(^\- )"
    ol_pattern="^[0-9]+\. "
    strong_pattern="\*\*([^*]+)\*\*"
    em_pattern="\*([^*]+)\*"

l=1

# The OR statement is needed to read the last line of the file if id does not contain a newline
while IFS= read -r line || [ -n "$line" ]; do
  
  # DEBUG: What are we reading?
  debug "line $l: $line"
  l=$((l+1))
  
  # blank line
  if [ "$line" = "$(echo "$line" | grep -E "^$")" ]; then
    close_ol
    close_ul
    close_p
  fi  



  # Header
  if [ "$line" = "$(echo "$line" | grep -E "$header_pattern")" ]; then
    close_ol
    close_ul
    close_p
    header $line
    continue
  fi

  # <ul> Lists
  if [ "$line" = "$(echo "$line" | grep -E "$ul_pattern")" ]; then
    close_ol
    close_p
    ul $line
    continue
  fi

# <ol> Lists
  if [ "$line" = "$(echo "$line" | grep -E "$ol_pattern")" ]; then
    close_ul
    close_p
    ol $line
    continue
  fi


  # Paragraphs

  # Format bold and Italic.
  # WARNING! Leave this line AFTER the list implementation to avoid unexpected results
  line=$(echo $line | sed -E "s/$strong_pattern/<strong>\1<\/strong>/g ; s/$em_pattern/<em>\1<\/em>/g")


 echo $line >> $OUTPUT


done < "$INPUT"

close_ol
close_ul
close_p


# Footer
cat << "EOF" >> "$OUTPUT"
</body></html>
EOF
}


