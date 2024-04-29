#!/bin/bash

case "$1" in
    list)
        echo "Current binfmt_misc entries:"
        ls /proc/sys/fs/binfmt_misc/
        ;;
    remove)
        echo "Removing $2..."
        echo -1 > "/proc/sys/fs/binfmt_misc/$2"
        ;;
    add)
        echo "Adding new entry..."
        echo "$3" > /proc/sys/fs/binfmt_misc/register
        ;;
    *)
        echo "Usage: $0 {list|add|remove} [entry_name] [entry_definition]"
        echo "Example: $0 add DOSWin ':DOSWin:M::MZ::/usr/bin/wine:'"
        ;;
esac
