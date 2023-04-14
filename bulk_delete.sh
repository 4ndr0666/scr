#!/bin/bash
# Author: 4ndr0666
# Purpose: Delete multiple files from a list
# -------------------------------------------------- 
## SET ME FIRST ##
_input="/path/to/list.txt"
 
if [ ! -f "$_input" ]; then
    echo "File ${_input} not found."
    exit 1
fi
 
while read -r line
do 
    if [ -f "$line" ]; then
        rm -f "$line"
    fi
done < "$_input"
