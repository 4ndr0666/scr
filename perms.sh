#!/bin/bash

opt=${1:-'-h'}
dir=${2:-'.'}

fmode=0644
dmode=0755

case "$1" in
    -a) # dirs and files
        find "$2" -type d -exec chmod $dmode "{}" +
        find "$2" -type f -exec chmod $fmode "{}" +
        ;;
    -d)
        find "$2" -type d -exec chmod $dmode "{}" +
        ;;
    -f) 
        find "$2" -type f -exec chmod $fmode "{}" +
        ;;
    -c)
        # Check package permissions against current permissions
        echo "Checking package permissions against current permissions..."
        pacman -Qlq | while read file; do
            if [ -e "$file" ]; then
                if [ "$(stat -c "%a" "$file")" != "$(pacman -Qkk "$file" | awk '{print $2}')" ]; then
                    echo "Mismatch: $file"
                fi
            fi
        done
        ;;
    *)
        printf "Usage: $(basename $0) option [directory]
  -a \t set permissions of files and directories to $fmode, resp. $dmode.
  -d \t set permissions of directories to $dmode.
  -f \t set permissions of files to $fmode.
  -c \t compare package permissions against current permissions.
  -h \t print this help.
"
        ;;
esac
