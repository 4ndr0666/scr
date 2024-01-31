#!/bin/bash

# List of files to delete
files_to_delete=(
"/usr/share/icons/garuda/garuda-black.png"
"/usr/share/icons/garuda/garuda-blue-FK.png"
"/usr/share/icons/garuda/garuda-blue.png"
"/usr/share/icons/garuda/garuda-blue.svg"
"/usr/share/icons/garuda/garuda-frost.png"
"/usr/share/icons/garuda/garuda-frost.svg"
"/usr/share/icons/garuda/garuda-gray.svg"
"/usr/share/icons/garuda/garuda-green.png"
"/usr/share/icons/garuda/garuda-orange.svg"
"/usr/share/icons/garuda/garuda-pink.png"
"/usr/share/icons/garuda/garuda-pink.svg"
"/usr/share/icons/garuda/garuda-purple.png"
"/usr/share/icons/garuda/garuda-purple.svg"
"/usr/share/icons/garuda/garuda-red.png"
"/usr/share/icons/garuda/garuda-white.png"
"/usr/share/icons/garuda/garuda-white.svg"
"/usr/share/icons/garuda/garuda-yellow.svg"
"/usr/share/icons/hicolor/scalable/apps/distributor-logo-garudalinux.svg"
"/usr/share/icons/hicolor/scalable/apps/garudalinux-logo-icon.svg"
"/usr/share/icons/hicolor/scalable/apps/garudalinux-logo.svg"
"/usr/share/icons/hicolor/scalable/apps/garudalinux.svg"
"/usr/share/icons/hicolor/scalable/apps/start-here-garudalinux.svg"
)

# Loop through each file and delete it
for file in "${files_to_delete[@]}"; do
  if [ -f "$file" ]; then
    echo "Deleting $file"
    rm -f "$file"
  else
    echo "File $file does not exist"
  fi
done
