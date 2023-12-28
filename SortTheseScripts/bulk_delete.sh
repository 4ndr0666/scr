#!/bin/bash

# Function to display help information
display_help() {
  echo "Usage: $0 [OPTIONS] FILE"
  echo "  -p, --path PATH       Path to the reference directory for searching files"
  echo "  -d, --delete          Delete files without confirmation"
  echo "  -r, --dry-run         Perform a dry run without actually deleting files"
  echo "  -h, --help            Display this help message"
  echo "Example:"
  echo "  $0 -r -p /path/to/your/reference_directory /path/to/your/exported_file.csv"
}

# Parse command-line options
delete_without_confirmation=false
dry_run=false
reference_path=""
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -p|--path) reference_path="$2"; shift; shift;;
    -d|--delete) delete_without_confirmation=true; shift;;
    -r|--dry-run) dry_run=true; shift;;
    -h|--help) display_help; exit 0;;
    *) break;;
  esac
  shift
done

# Check if the file and reference path are provided
if [ -z "$1" ]; then
  echo "Please provide the path to the exported file from DupeGuru (CSV, TXT, JSON, or HTML)."
  display_help
  exit 1
fi
if [ -z "$reference_path" ]; then
  echo "Please provide the path to the reference directory for searching files."
  display_help
  exit 1
fi

_input="$1"

# No editing below
[ ! -f "$_input" ] && { echo "File ${_input} not found."; exit 1; }

# Determine the file type and extract the file paths accordingly
file_ext="${_input##*.}"
if [ "$file_ext" == "csv" ]; then
  file_list=$(tail -n +2 "$_input" | cut -d ',' -f 2)
elif [ "$file_ext" == "txt" ] || [ "$file_ext" == "json" ]; then
  file_list=$(cat "$_input")
elif [ "$file_ext" == "html" ]; then
  file_list=$(grep -oP '(?<=<a href=")[^"]*' "$_input")
else
  echo "Unsupported file type. Please use CSV, TXT, JSON, or HTML."
  exit 1
fi

# Check if the file list is empty
if [ -z "$file_list" ]; then
  echo "No files found in the file."
  exit 0
fi

# Find files in the reference directory
found_files=""
for file in $file_list; do
  found_file=$(find "$reference_path" -type f -name "$file")
  found_files+="$found_file"$'\n'
done

# Perform a dry run or delete files with or without confirmation
if [ "$dry_run" = true ]; then
  echo "Dry run: The following files would be deleted:"
  echo "$found_files"
elif [ "$delete_without_confirmation" = true ]; then
  echo "Deleting files without confirmation:"
  echo "$found_files" | xargs -d '\n' -I {} sudo rm -v "{}"
else
  echo "The following files will be deleted:"
  echo "$found_files"
read -p "Do you want to proceed with deletion? (y/N) " response

if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
echo "$found_files" | xargs -d '\n' -I {} sudo rm -v "{}"
echo "Files deleted."
else
echo "No files were deleted."
fi
fi
