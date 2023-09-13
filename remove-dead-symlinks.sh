#! /bin/bash

# recursively remove dead symlinks

shopt -s globstar

# non-recursive version: 'for itm in *'
for itm in **/*
do
    if [ -h "$itm" ]
    then
        target=$(readlink -fn "$itm")
        if [ ! -e "$target" ]
        then
            echo "$itm is a dead symlink."
            read -p "Do you want to delete it? [y/n]: " answer
            case "$answer" in
                [yY]|[yY][eE][sS])
                    rm "$itm"
                    echo "$itm deleted."
                    ;;
                [nN]|[nN][oO])
                    echo "$itm not deleted."
                    ;;
                *)
                    echo "Invalid input. $itm not deleted."
                    ;;
            esac
        fi
    fi
done
