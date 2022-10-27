#!/bin/bash
# Author: 4ndr0666
# Purpose: Delete a file using shell script in bulk
# -------------------------------------------------- 
## SET ME FIRST ##
_input="/home/andro/cinnamonfiles.txt"
 
## No editing below ##
[ ! -f "$_input" ] && { echo "File ${_input} not found."; exit 1; }
while IFS= read -r line
do 
	[ -f "$line" ] && rm -f "$line"
done < "${_input}"
