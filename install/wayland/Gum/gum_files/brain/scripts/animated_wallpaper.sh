#!/bin/bash
directory="$HOME/custom_wallpapers/animated/"
# Check if the directory exists
if [[ -d "$directory" ]]; then
  # Get a list of files in the directory
  files=("$directory"/*)

  # Get the number of files
  num_files=${#files[@]}

  # If there are files in the directory, pick a random one
  if [[ $num_files -gt 0 ]]; then
    random_index=$(shuf -i 0-$((num_files - 1)) -n 1)
    random_file=${files[$random_index]}
    swww img --transition-step '255' --transition-type 'random' "$random_file"

  fi
fi
