#!/bin/sh

for x in $(ls /etc/snapper/configs/) ;
do
    RANGE=$(snapper -c $x list | tail -n1 | cut -d" " -f1)
    if [ $RANGE -gt 0 ]; then
        echo Deleting snapshots in $x
        snapper -c $x delete 0-$RANGE
    else
        echo Nothing to delete in $x
    fi
done
