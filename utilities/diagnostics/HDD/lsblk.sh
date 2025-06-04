#!/bin/bash
# shellcheck disable=all

# File: lsblk_aligned_v1.sh
# Description:
# Lists block devices and partitions, numbers them sequentially, 
# and allows users to copy the UUID of a selected device to the clipboard.
# This version aligns output based on a terminal width of 82 columns.

# --- // CONSTANTS:
color_reset=$(tput sgr0)        # Reset
color_disk=$(tput setaf 2)      # Green for disks
color_partition=$(tput setaf 4) # Blue for partitions
color_zram=$(tput setaf 1)      # Red for ZRAM info
color_summary=$(tput setaf 3)   # Yellow for summary
color_error=$(tput setaf 1)     # Red for errors

# --- // VARIABLES:
declare -A device_map=() # Associative array to map device numbers to UUIDs

# --- // FUNCTIONS:

# Function to initialize and check dependencies
initialize() {
  if ! command -v wl-copy &>/dev/null; then
    echo "${color_error}Error: wl-clipboard is not installed.${color_reset}" >&2
    exit 1
  fi
}

# Function to print the list of devices with numbering and hierarchy
list_devices() {
  local device_number=1
  for disk in /dev/sd[a-z]; do
    if [ -b "$disk" ]; then
      local serial=$(udevadm info --query=property --name=$disk | grep ID_SERIAL= | cut -d= -f2)
      echo "${color_disk}[${device_number}] DISK: $serial ($disk)${color_reset}"
      device_map["$device_number"]=$disk

      lsblk -n -o NAME,UUID,FSTYPE,SIZE,FSAVAIL,FSUSE%,TYPE,MOUNTPOINT $disk | while read -r line; do
        local name=$(echo $line | awk '{print $1}')
        local uuid=$(echo $line | awk '{print $2}')
        local fstype=$(echo $line | awk '{print $3}')
        local size=$(echo $line | awk '{print $4}')
        local avail=$(echo $line | awk '{print $5}')
        local use_percent=$(echo $line | awk '{print $6}')
        local mount=$(echo $line | awk '{print $NF}')

        # Assign default values if data is missing
        uuid=${uuid:-N/A}
        fstype=${fstype:-N/A}
        avail=${avail:-N/A}
        use_percent=${use_percent:-N/A}
        mount=${mount:-N/A}

        # Format output based on type (disk or partition)
        if [[ "$name" == sd* ]]; then
          echo "${color_partition}    ├─ [DEVICE] $name ($size)"
          echo "       │  UUID: $uuid, Type: $fstype, Avail: $avail, Used: $use_percent, Mount: $mount${color_reset}"
        else
          echo "${color_partition}        ├─ [PARTITION] $name ($size)"
          echo "           │  UUID: $uuid, Type: $fstype, Avail: $avail, Used: $use_percent, Mount: $mount${color_reset}"
        fi
      done
      echo ""
      ((device_number++))
    fi
  done

  # Display ZRAM devices with numbering
  for zram in /dev/zram*; do
    if [ -b "$zram" ]; then
      local size=$(lsblk -n -o SIZE $zram)
      local mountpoint=$(lsblk -n -o MOUNTPOINT $zram | tr -d ' ')
      local uuid="N/A"

      echo "${color_zram}[${device_number}] ZRAM: $zram${color_reset}"
      echo "    ├─ [DEVICE] $zram ($size)"
      echo "       │  UUID: $uuid, Type: disk, Avail: N/A, Used: N/A, Mount: ${mountpoint:-[SWAP]}${color_reset}"
      
      device_map["$device_number"]=$zram
      echo ""
      ((device_number++))
    fi
  done
}

# Function to print the summary of devices
print_summary() {
  echo "${color_summary}===== SUMMARY =====${color_reset}"
  printf "%-7s %-35s %-6s %-8s %-8s %-8s %-10s\n" "DEVICE" "UUID" "FSTYPE" "SIZE" "AVAIL" "USED" "MOUNTPOINT"
  for index in "${!device_map[@]}"; do
    local device=${device_map[$index]}
    lsblk -n -o NAME,UUID,FSTYPE,SIZE,FSAVAIL,FSUSE%,MOUNTPOINT "$device" | while read -r line; do
      local name=$(echo $line | awk '{print $1}')
      local uuid=$(echo $line | awk '{print $2}')
      local fstype=$(echo $line | awk '{print $3}')
      local size=$(echo $line | awk '{print $4}')
      local avail=$(echo $line | awk '{print $5}')
      local used=$(echo $line | awk '{print $6}')
      local mount=$(echo $line | awk '{print $7}')

      # Set default values if not available
      uuid=${uuid:-N/A}
      fstype=${fstype:-N/A}
      avail=${avail:-N/A}
      used=${used:-N/A}
      mount=${mount:-N/A}

      # Print formatted summary line
      printf "%-7s %-35s %-6s %-8s %-8s %-8s %-10s\n" "$name" "$uuid" "$fstype" "$size" "$avail" "$used" "$mount"
    done
  done
}

# Function to copy UUID to clipboard
copy_to_clipboard() {
  local selection=$1
  local selected_device=${device_map[$selection]}
  local uuid=$(blkid -s UUID -o value "$selected_device" 2>/dev/null || echo "N/A")

  if [[ -z "$uuid" || "$uuid" == "N/A" ]]; then
    echo "${color_error}Invalid selection or UUID not available. Please choose a valid device number.${color_reset}"
    exit 1
  fi
  echo -n "$uuid" | wl-copy
  echo "${color_summary}UUID $uuid copied to clipboard.${color_reset}"
}

# Function to display usage information
display_usage() {
  echo "${color_error}Usage: $0 [-<number> (e.g., -1 to select device)]${color_reset}"
  echo "       Run without arguments to list devices and partitions."
  echo "       Use '-<number>' to copy the UUID of the specified device to the clipboard."
  exit 1
}

# Main script execution
initialize
if [[ "$1" =~ ^-[0-9]+$ ]]; then
  device_number=${1:1}
  list_devices
  copy_to_clipboard "$device_number"
  print_summary
elif [[ -z "$1" ]]; then
  list_devices
  print_summary
else
  display_usage
fi
