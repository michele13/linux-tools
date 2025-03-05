#!/bin/bash

set -e
set -o pipefail

DEBUG=1

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 file.md [output.html]"
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
  if [ $DEBUG -eq 1 ]; then
  echo ""
  printf "DEBUG: %s\n" "$*"
  fi
}

# Set title in HEAD TITLE tag
get_title(){
  local t=$(head -n1 ${INPUT})
  t=${t##\#\ }
  echo $t
  }



header() {
  if [ -n "$line" ]; then
  debug "HEADER INPUT: $line"
    # how many "#" are in the line  ?
    n=$(echo $1 | wc -m)
    n=$((n-1))
    content=$(echo "$line" | sed -E "s/($header_pattern)//")
    result="<h$n>$content</h$n>"
    debug "HEADER RESULT: $result"
    line="$result"
  fi
}

ol() {
  if [ -n "$line" ]; then
  debug "$line"
    if [ $in_ol -eq 0 ]; then
      debug "<ol>" 
      echo "<ol>" >> "$OUTPUT"
      in_ol=1
    fi
  content=$(echo "$line" | sed -E "s/$ol_pattern//")
  result="<li>$content</li>"
  debug "$result"
  line="$result"
  fi
}

ul() {
  if [ -n "$line" ]; then
  debug "$line"
    if [ $in_ul -eq 0 ]; then
      debug "<ul>" 
      echo "<ul>" >> "$OUTPUT"
      in_ul=1
    fi
  content=$(echo "$line" | sed -E "s/$ul_pattern//")
  result="<li>$content</li>"
  debug "$result"
  line="$result" 
  fi
  
}

print_paragraph() {
  if [ $in_p -eq 0 ]; then
      in_p=1
      echo -n "<p>$line" >> "$OUTPUT"
    else
      if [ $in_p -eq 1 ]; then
        echo -n " $line" >> "$OUTPUT"
      fi  
    fi  
}

codeblock() {
  if [ $in_codeblock -eq 0 ]; then
    in_codeblock=1
    echo "<pre><code>" >> $OUTPUT
  else
    in_codeblock=0
    echo "</pre></code>" >> $OUTPUT
  fi
}

code() {
  debug "INPUT OF CODE: $line"
  content=$(echo "$line" | sed -E "s/.*\`([^\`]+)\`.*/\1/")
  debug "EXTRACTED CONTENT: $content"
  
  #escaped_content="a"
  escape_string
  line=$(echo "$line" | sed -E "s/$code_pattern/<code>$escaped_content<\/code>/g")
  debug "OUTPUT OF CODE: $line"
}

escape_string(){
  debug "ESCAPE STRING INPUT: "$content""
# ; s/\//&#47;/g
   escaped_content=$(echo "$content" | sed "s/\&/\&amp;/g ; s/</\&lt;/g ; s/*/\&#42;/g ; s/>/\&gt;/g")

  debug "ESCAPE STRING OUTPUT: "$content""
}

inline_strong_em(){
  line=$(echo "$line" | sed -E "s/$strong_pattern/<strong>\1<\/strong>/g ; s/$em_pattern/<em>\1<\/em>/g")
}

# Are we inside a <TAG>? 
in_ul=0
in_ol=0
in_p=0
in_em=0
in_strong=0
in_codeblock=0


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
OUTPUT="$2"
[ -z "$OUTPUT" ] &&  OUTPUT="${INPUT%.md}.html";

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
    ul_pattern="(^\*\ )|(^\-\ )"
    ol_pattern="^[0-9]+\. "
    strong_pattern="\*\*([^*]+)\*\*"
    em_pattern="\*([^*]+)\*"
    code_pattern='`([^`]+)`'
    p_pattern="[0-9a-zA-Z ]+"
    codeblock_pattern='```'

l=1

# The OR statement is needed to read the last line of the file if id does not contain a newline
while IFS= read -r line || [ -n "$line" ]; do
  
  # DEBUG: What are we reading?
  debug "line $l: $line"
  
  # save next line into variable
  nl=$((l+1))
  next_line="$(sed "${nl}!d" $INPUT)"
  debug "NEXT LINE: $next_line"

  l=$nl
  
  # blank line
  if [ "$line" = "$(echo "$line" | grep -E "^$")" ]; then
    close_ol
    close_ul
    close_p
  fi  


  
  # Code blocks
  if echo "$line" | grep -qE "$codeblock_pattern"; then
    close_ol
    close_ul
    close_p
    codeblock
    continue  
  fi

if [ $in_codeblock -eq 0 ]; then
  
  # Header
  if [ "$line" = "$(echo "$line" | grep -E "$header_pattern")" ]; then
    close_ol
    close_ul
    close_p
    header $line
    code; inline_strong_em
    echo "$line" >> "$OUTPUT"
    continue
  fi

  # <ul> Lists
  if [ "$line" = "$(echo "$line" | grep -E "$ul_pattern")" ]; then
    close_ol
    close_p
    ul; code; inline_strong_em
    echo "$line" >> "$OUTPUT"
    continue
  fi

# <ol> Lists
  if [ "$line" = "$(echo "$line" | grep -E "$ol_pattern")" ]; then
    close_ul
    close_p
    ol; code; inline_strong_em
    echo "$line" >> "$OUTPUT"
    continue
  fi


# code line here, before other inline stuff
  if echo "$line" | grep -qE "$code_pattern"; then
    code
    print_paragraph
    continue
  fi


# Format bold and Italic.
  # WARNING! Leave this line AFTER the list implementation to avoid unexpected results

  inline_strong_em


  # Paragraphs

  
  # If we have a paragraph pattern. and are not inside one, start a paragraph
   if echo "$line" | grep -qE "$p_pattern"; then
      print_paragraph
   fi

else

  content="$line"
  escape_string
  echo "$escaped_content" >> $OUTPUT

fi

done < "$INPUT"

close_ol
close_ul
close_p


# Footer
cat << "EOF" >> "$OUTPUT"
</body></html>
EOF
}


