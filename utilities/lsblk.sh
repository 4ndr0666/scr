#!/bin/bash
# ~/.local/bin/driveinfo                        -*- coding: utf-8-auto-unix -*-
# Shows useful info about connected block devices/drives
#------------------------------------------------------------------------------

print_deviceinfo() {
  if [ "${#}" -lt 1 ]; then
    echo "${FUNCNAME[0]}() requires 1 argument (/dev block device path)" >&2
    return 1
  fi

  local DEV="$1"

  if [ -b "$DEV" ]; then
    if command -v 'udevadm' >/dev/null 2>&1; then
      #sernum=$(smartctl -a "$DEV" | grep "Serial Number:" | cut -d ":" -f 2 | sed 's/\ //g')
      sernum=$(udevadm info "$DEV" | cut -d " " -f "2-" | awk -F "=" '{ if ($1 == "ID_SERIAL") { print $2; } }')
      echo "$DEV : $sernum"
    else
      echo "${FUNCNAME[0]}(): Error: 'udevadm' command not found!" >&2
      return 1
    fi
  fi

  return 0
}


MAXNUMBER=99

# /dev/nvmeXnY - NVMe SSD drives
for ((x = 0; x <= MAXNUMBER; x++)); do
  for ((y = 0; y <= MAXNUMBER; y++)); do
    print_deviceinfo "/dev/nvme${x}n${y}"
  done
done

# /dev/sdX - SATA/SCSI drives
for x in {{a..z},{a..z}{a..z}}; do
  print_deviceinfo "/dev/sd${x}"
done

# /dev/mmcblkX - SD/MMC cards / eMMC storage devices
for ((x = 0; x <= MAXNUMBER; x++)); do
  print_deviceinfo "/dev/mmcblk${x}"
done

# /dev/srX - optical drives
for ((x = 0; x <= MAXNUMBER; x++)); do
  print_deviceinfo "/dev/sr${x}"
done


# lsblk output
if command -v 'lsblk' >/dev/null 2>&1; then
  echo ''
  lsblk -o NAME,FSTYPE,SIZE,FSAVAIL,TYPE,HOTPLUG,MOUNTPOINT
fi

# blkid output
#if command -v 'blkid' >/dev/null 2>&1; then
#  echo ''
#  blkid
#fi
