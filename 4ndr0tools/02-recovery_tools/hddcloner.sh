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
      pacman -Sy --noconfirm "$cmd"
      if ! command -v "$cmd" &>/dev/null; then
        log "Failed to install '$cmd'. Exiting."
        exit 1
      fi
      log "Installed '$cmd' successfully."
    fi
  done
}

# Function to select drive with timeout
select_drive() {
  local prompt="$1"
  lsblk -o NAME,SIZE,TYPE,MOUNTPOINT
  echo "Enter the device name for $prompt (e.g., sda): "
  if read -r -t 60 DRIVE; then
    if [[ ! -b "/dev/$DRIVE" ]]; then
      log "Device /dev/$DRIVE does not exist. Exiting."
      exit 1
    fi
    echo "/dev/$DRIVE"
  else
    log "No input received for $prompt. Exiting."
    exit 1
  fi
}

# Function to confirm selection with timeout
confirm_selection() {
  echo "Source: $1"
  echo "Target: $2"
  echo "Are you sure you want to proceed? (yes/no): "
  if read -r -t 30 CONFIRM; then
    if [[ "$CONFIRM" != "yes" ]]; then
      log "Operation aborted by user."
      exit 0
    fi
  else
    log "No confirmation received. Exiting."
    exit 1
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
confirm_selection "$SOURCE" "$TARGET"

# Unmount drives if mounted
for DRIVE in "$SOURCE" "$TARGET"; do
  mountpoints=$(lsblk -no MOUNTPOINT "$DRIVE")
  if [[ -n "$mountpoints" ]]; then
    log "Unmounting $DRIVE..."
    umount "$DRIVE" || { log "Failed to unmount $DRIVE. Exiting."; exit 1; }
  fi
done

# Start cloning with ddrescue
log "Starting initial ddrescue cloning from $SOURCE to $TARGET."
ddrescue -f -n "$SOURCE" "$TARGET" "$LOG" || { log "ddrescue initial pass failed. Exiting."; exit 1; }

# Retry bad sectors
log "Retrying bad sectors with ddrescue."
ddrescue -d -f -r3 "$SOURCE" "$TARGET" "$LOG" || { log "ddrescue retry failed. Exiting."; exit 1; }

# Verify the cloned drive
PARTITIONS=($(lsblk -ln -o NAME "$TARGET" | grep -E "^$TARGET[0-9]+$"))
if [[ ${#PARTITIONS[@]} -gt 0 ]]; then
  for PART in "${PARTITIONS[@]}"; do
    PARTITION="/dev/$PART"
    log "Running fsck on $PARTITION."
    fsck -f "$PARTITION" || { log "fsck failed on $PARTITION. Exiting."; exit 1; }
  done
else
  log "No partitions found on $TARGET. Skipping fsck."
fi

log "Drive cloning completed successfully."

exit 0