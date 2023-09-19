#!/bin/bash
# Author: 4ndr0666
# Purpose: Delete multiple files from a list interactively
# -------------------------------------------------- 

# Prompt the user for the path to the list
read -p "Enter the path to the list of files you want to delete: " _input

# Check if the file exists
if [ ! -f "$_input" ]; then
    echo "File ${_input} not found."
    exit 1
fi

# Confirmation before proceeding
read -p "Are you sure you want to delete the files listed in ${_input}? [y/N]: " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

# Loop through each line in the file and delete if it exists
while read -r line
do 
    if [ -f "$line" ]; then
        echo "Deleting $line..."
        rm -f "$line"
    else
        echo "File $line not found."
    fi
done < "$_input"

echo "Operation completed."
