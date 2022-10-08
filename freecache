#!/bin/bash
# This command frees only RAM cache
#echo "echo 3 > /proc/sys/vm/drop_caches"
# This command frees RAM cache and swap
su -c "echo 3 >'/proc/sys/vm/drop_caches' && swapoff -a && swapon -a && printf '\n%s\n' 'Ram-cache and Swap Cleared'" root
