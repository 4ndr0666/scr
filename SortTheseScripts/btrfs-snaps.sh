#!/bin/bash

# By 4ndr0666 <4ndr0666@icould.com>
# License Apache 2.0.


# This lets you create sets of snapshots at any interval (I use hourly,
# daily, and weekly) and delete the older ones automatically.


# Usage:
# This is called from /etc/cron.d like so:
0 * * * * root btrfs-snaps hourly 5 | egrep -v '(Create a snapshot of|Will delete the oldest|Delete subvolume|Making snapshot of )'
1 0 * * * root btrfs-snaps daily  10 | egrep -v '(Create a snapshot of|Will delete the oldest|Delete subvolume|Making snapshot of )'
2 0 * * 0 root btrfs-snaps weekly 4 | egrep -v '(Create a snapshot of|Will delete the oldest|Delete subvolume|Making snapshot of )'


: ${BTRFSROOT:=/mnt/btrfs_pool1}
DATE="$(date '+%Y%m%d_%H:%M:%S')"


type=${1:-hourly}
keep=${2:-3}


cd "$BTRFSROOT"


for i in $(btrfs subvolume list -q . | grep "parent_uuid -" | awk '{print $11}')
do
    # Skip duplicate dirs once a year on DST 1h rewind.
    test -d "$BTRFSROOT/${i}_${type}_$DATE" && continue
    echo "Making snapshot of $type"
    btrfs subvolume snapshot "$BTRFSROOT"/$i "$BTRFSROOT/${i}_${type}_$DATE"
    count="$(ls -d ${i}_${type}_* | wc -l)"
    clip=$(( $count - $keep ))
    if [ $clip -gt 0 ]; then
	echo "Will delete the oldest $clip snapshots for $type"
	for sub in $(ls -d ${i}_${type}_* | head -n $clip)
	do
	    #echo "Will delete $sub"
	    btrfs subvolume delete "$sub"
	done
    fi
done
