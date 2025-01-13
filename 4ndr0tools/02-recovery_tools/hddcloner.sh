#!/bin/zsh

# Script: clone_drive.sh
# Purpose: Clone a failing hard drive to a new one using ddrescue with enhanced safety and automation.
# Usage: sudo ./clone_drive.sh

set -euo pipefail

# Variables
LOG="/var/log/ddrescue_clone_drive.log"

# Function to log messages
log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") : $1" | tee -a "$LOG"
}

# Function to check dependencies
check_dependencies() {
  local dependencies=(ddrescue lsblk fsck)
  for cmd in "${dependencies[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
      log "Dependency '$cmd' is not installed. Installing..."
      sudo pacman -Sy --noconfirm "$cmd"
      if ! command -v "$cmd" &>/dev/null; then
        log "Failed to install '$cmd'. Exiting."
        exit 1
      fi
      log "Installed '$cmd' successfully."
    fi
  done
}

# Function to select drive
select_drive() {
  local prompt="$1"
  lsblk -o NAME,SIZE,TYPE,MOUNTPOINT
  echo "Enter the device name for $prompt (e.g., sda): "
  read -r DRIVE
  if [[ ! -b "/dev/$DRIVE" ]]; then
    log "Device /dev/$DRIVE does not exist. Exiting."
    exit 1
  fi
  echo "/dev/$DRIVE"
}

# Function to confirm selection
confirm_selection() {
  echo "Source: $1"
  echo "Target: $2"
  echo "Are you sure you want to proceed? (yes/no): "
  read -r CONFIRM
  if [[ "$CONFIRM" != "yes" ]]; then
    log "Operation aborted by user."
    exit 0
  fi
}

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run with sudo or as root."
  exit 1
fi

log "Starting clone_drive.sh script."

# Check and install dependencies
check_dependencies

# Select source and target drives
SOURCE=$(select_drive "SOURCE drive (failing)")
TARGET=$(select_drive "TARGET drive (new)")

# Confirm selections
confirm_selection "/dev/$SOURCE" "/dev/$TARGET"

# Unmount drives if mounted
for DRIVE in "$SOURCE" "$TARGET"; do
  mountpoints=$(lsblk -no MOUNTPOINT "/dev/$DRIVE")
  if [[ -n "$mountpoints" ]]; then
    log "Unmounting /dev/$DRIVE..."
    umount "/dev/$DRIVE" || { log "Failed to unmount /dev/$DRIVE. Exiting."; exit 1; }
  fi
done

# Start cloning with ddrescue
log "Starting initial ddrescue cloning from /dev/$SOURCE to /dev/$TARGET."
ddrescue -f -n "/dev/$SOURCE" "/dev/$TARGET" "$LOG" || { log "ddrescue initial pass failed. Exiting."; exit 1; }

# Retry bad sectors
log "Retrying bad sectors with ddrescue."
ddrescue -d -f -r3 "/dev/$SOURCE" "/dev/$TARGET" "$LOG" || { log "ddrescue retry failed. Exiting."; exit 1; }

# Verify the cloned drive
PARTITION="${TARGET}1"
if [[ -b "/dev/$PARTITION" ]]; then
  log "Running fsck on /dev/$PARTITION."
  fsck -f "/dev/$PARTITION" || { log "fsck failed on /dev/$PARTITION. Exiting."; exit 1; }
else
  log "Partition /dev/$PARTITION does not exist. Skipping fsck."
fi

log "Drive cloning completed successfully."

exit 0