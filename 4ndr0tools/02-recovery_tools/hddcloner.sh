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

# Function to prompt for resume or start anew
prompt_resume() {
  echo "A previous cloning operation was detected."
  echo "Do you want to resume the cloning process? (yes/no): "
  read -r RESUME
  if [[ "$RESUME" == "yes" ]]; then
    echo "Resuming cloning..."
    log "User opted to resume cloning."
    return 0
  else
    echo "Starting a fresh cloning process."
    log "User opted to start a fresh cloning process."
    # Remove existing log to start fresh
    rm -f "$LOG"
    return 1
  fi
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

# Function to display ddrescue progress
show_progress() {
  echo "Cloning in progress. Press Ctrl+C to abort."
  tail -f "$LOG" &
  TAIL_PID=$!
  wait
}

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run with sudo or as root."
  exit 1
fi

log "Starting clone_drive.sh script."

# Check and install dependencies
check_dependencies

# Check if log file exists
if [[ -f "$LOG" ]]; then
  prompt_resume
  RESUME_CHOICE=$?
else
  RESUME_CHOICE=1
fi

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
if [[ $RESUME_CHOICE -eq 0 ]]; then
  log "Resuming ddrescue cloning from $SOURCE to $TARGET."
  ddrescue -d -f -r3 "$SOURCE" "$TARGET" "$LOG"
else
  log "Starting initial ddrescue cloning from $SOURCE to $TARGET."
  ddrescue -n "$SOURCE" "$TARGET" "$LOG"
  log "Retrying bad sectors with ddrescue."
  ddrescue -d -f -r3 "$SOURCE" "$TARGET" "$LOG"
fi

# Display progress
show_progress

# Verify the cloned drive
PARTITIONS=($(lsblk -ln -o NAME "$TARGET" | grep -E "^$(basename "$TARGET")[0-9]+$"))
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

# Kill the tail process if it's still running
if ps -p $TAIL_PID > /dev/null 2>&1; then
  kill $TAIL_PID
fi

exit 0