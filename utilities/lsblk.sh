#!/bin/bash

#File: lsblk.sh
#Author: 4ndr0666
#Edited: 05-09-24
#
# --- // LSBLK.SH // ========

# --- // CONSTANTS:
color_reset=$(tput sgr0)        # Reset
color_disk=$(tput setaf 2)      # Yellow = disk headers
color_partition=$(tput setaf 4) # Dark blue = partitions
color_btrfs=$(tput setaf 8)     # Light blue  = btrfs subvolumes
color_zram=$(tput setaf 1)      # Red  = ZRAM info
color_lsblk=$(tput setaf 2)     # Yellow = lsblk

# --- // BLK_FORMATTING:
print_disk_info() {
  for disk in /dev/sd[a-z]; do
    if [ -b "$disk" ]; then
      local serial=$(udevadm info --query=property --name=$disk | grep ID_SERIAL= | cut -d= -f2)
      echo "${color_disk}DISK: $serial${color_reset}"
      
      lsblk -n -o NAME,FSTYPE,SIZE,FSAVAIL,FSUSE%,TYPE,HOTPLUG,MOUNTPOINT $disk | while read line; do
        local name=$(echo $line | awk '{print $1}')
        local fstype=$(echo $line | awk '{print $2}')
        local mount=$(echo $line | awk '{print $NF}')

        if [[ "$name" == sd* ]]; then
          echo "${color_partition}    $line"
        else
          echo "${color_partition}        ├─$line"
        fi
        
        if [[ "$fstype" == "btrfs" && -d "/$mount" ]]; then
          sudo btrfs subvolume list /$mount | awk -v prefix="$color_btrfs" -v reset="$color_reset" '{print prefix "            | "$0 reset}'
        fi
      done
      echo ""
    fi
  done
}

# --- // ZRAM:
print_zram_info() {
  for zram in /dev/zram*; do
    if [ -b "$zram" ]; then
      echo "${color_zram}ZRAM:${color_reset}"
      lsblk -n -o NAME,SIZE,TYPE,HOTPLUG,MOUNTPOINT $zram | awk -v prefix="$color_zram" -v reset="$color_reset" '{print prefix "    "$0 reset}'
      echo ""
    fi
  done
}
print_disk_info
print_zram_info

if command -v 'lsblk' >/dev/null 2>&1; then
  echo "${color_lsblk} "
  lsblk -o NAME,FSTYPE,SIZE,FSAVAIL,TYPE,HOTPLUG,MOUNTPOINT
fi

