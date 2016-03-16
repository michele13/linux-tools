#!/bin/bash
echo "Content-type: text/html"
echo ""
echo "<!DOCTYPE html>"
echo "<html>"
echo "<head>"
echo "<title>Index of $REQUEST_URI </title>"
echo "</head>"
echo "<body>"
echo "<h1>Index of $REQUEST_URI</h1>"
echo "<ul>"
if [ $REQUEST_URI != "/" ]; then
echo "<li><a href=\"..\">Parent Directory</a></li>"
fi
ls -p ..$REQUEST_URI | while read file; do
echo "<li><a href=\"$file\">$file</a></li>"
done
echo "</ul>"
echo "</body>"
echo "</html>"
