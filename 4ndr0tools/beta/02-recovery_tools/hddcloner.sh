#!/bin/zsh
# shellcheck disable=all

# Script: clone_drive.sh
# Purpose: Clone a failing hard drive to a new one using ddrescue with enhanced safety and automation.
# Usage: sudo ./clone_drive.sh

# NOTE:
# We intentionally do NOT use `set -e` to allow ddrescue to return non-zero exit codes
# (which can happen if there are bad sectors). Instead, we handle errors manually.

set -u  # Treat unset variables as an error
set -o pipefail  # Catch errors in pipelines

# Variables
LOG="/var/log/ddrescue_clone_drive.log"

###############################################################################
# Function: log
# Description: Logs messages with timestamps.
###############################################################################
log() {
  local TIMESTAMP
  TIMESTAMP="$(date +"%Y-%m-%d %H:%M:%S")"
  echo "${TIMESTAMP} : $1" | tee -a "$LOG"
}

###############################################################################
# Function: check_dependencies
# Description: Ensures ddrescue, lsblk, and fsck are installed.
###############################################################################
check_dependencies() {
  local dependencies=(ddrescue lsblk fsck)
  for cmd in "${dependencies[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
      log "Dependency '$cmd' is not installed. Attempting install..."
      pacman -Sy --noconfirm "$cmd"
      if ! command -v "$cmd" &>/dev/null; then
        log "Failed to install '$cmd'. Exiting."
        exit 1
      fi
      log "Installed '$cmd' successfully."
    fi
  done
}

###############################################################################
# Function: prompt_resume
# Description: Checks if we should resume from an existing ddrescue log or start fresh.
# Returns 0 for resume, 1 for fresh start.
###############################################################################
prompt_resume() {
  echo "A previous ddrescue log file was detected."
  echo "Do you want to resume the cloning process? (yes/no): "
  read -r RESUME
  local resume_lower
  resume_lower="$(echo "$RESUME" | tr '[:upper:]' '[:lower:]')"

  if [[ "$resume_lower" == "yes" ]]; then
    log "User opted to resume cloning."
    return 0
  else
    log "User opted to start a fresh cloning process."
    rm -f "$LOG"
    return 1
  fi
}

###############################################################################
# Function: select_drive
# Description: Lists all block devices, prompts user to choose one.
###############################################################################
select_drive() {
  local prompt="$1"
  echo "Available block devices:"
  lsblk -o NAME,SIZE,TYPE,MOUNTPOINT
  echo
  echo "Enter the device name for $prompt (e.g., sda):"
  read -r DRIVE
  if [[ ! -b "/dev/$DRIVE" ]]; then
    log "Device /dev/$DRIVE does not exist. Exiting."
    exit 1
  fi
  echo "/dev/$DRIVE"
}

###############################################################################
# Function: confirm_selection
# Description: Asks user for final confirmation before proceeding.
###############################################################################
confirm_selection() {
  echo "Source drive: $1"
  echo "Target drive: $2"
  echo "Are you sure you want to proceed? (yes/no):"
  read -r CONFIRM
  local confirm_lower
  confirm_lower="$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')"
  if [[ "$confirm_lower" != "yes" ]]; then
    log "Operation aborted by user."
    exit 0
  fi
}

###############################################################################
# Function: run_ddrescue
# Description: Runs ddrescue in the background and tails the log in the foreground.
#              If 'resume' is 0, we run ddrescue with -d -f -r3 in one shot.
#              If 'resume' is 1, we do the initial pass + bad sector retries.
###############################################################################
run_ddrescue() {
  local resume_choice="$1"   # 0 => resume, 1 => fresh
  local source_dev="$2"
  local target_dev="$3"

  if [[ "$resume_choice" -eq 0 ]]; then
    # Resume
    log "Resuming ddrescue cloning from $source_dev to $target_dev using existing log."
    ddrescue -d -f -r3 "$source_dev" "$target_dev" "$LOG" &
  else
    # Fresh
    log "Starting ddrescue initial pass from $source_dev to $target_dev."
    ddrescue -n "$source_dev" "$target_dev" "$LOG" &
    local ddrescue_initial_pid=$!
    wait $ddrescue_initial_pid  # Wait for the initial pass to finish

    log "Retrying bad sectors with ddrescue."
    ddrescue -d -f -r3 "$source_dev" "$target_dev" "$LOG" &
  fi

  # The ddrescue command is now running in the background. We capture its PID:
  DDRESCUE_PID=$!

  # Show progress by tailing the log in the foreground:
  tail -f "$LOG" &
  TAIL_PID=$!

  # Wait for ddrescue to finish
  wait "$DDRESCUE_PID"

  # ddrescue done, kill tail
  if ps -p "$TAIL_PID" &>/dev/null; then
    kill "$TAIL_PID"
  fi
}

###############################################################################
# Function: verify_cloned_drive
# Description: Runs fsck on each detected partition on the target drive.
###############################################################################
verify_cloned_drive() {
  local target_dev="$1"
  # Gather partitions for $target_dev, e.g. sdb1, sdb2, etc.:
  local partitions
  partitions=($(lsblk -ln -o NAME "$target_dev" | grep -E "^$(basename "$target_dev")[0-9]+$"))

  if [[ ${#partitions[@]} -gt 0 ]]; then
    for PART in "${partitions[@]}"; do
      local PARTITION="/dev/$PART"
      log "Running fsck on $PARTITION."
      fsck -f "$PARTITION" || {
        log "fsck failed on $PARTITION. Exiting."
        exit 1
      }
    done
  else
    log "No partitions found on $target_dev. Skipping fsck."
  fi
}

###############################################################################
# Main Script Execution
###############################################################################

# Ensure root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (sudo)."
  exit 1
fi

log "Starting clone_drive.sh script..."

# 1. Dependencies
check_dependencies

# 2. If log file exists AND non-empty, allow user to resume
RESUME_CHOICE=1
if [[ -f "$LOG" && -s "$LOG" ]]; then
  prompt_resume
  RESUME_CHOICE=$?
fi

# 3. Select Source / Target
SOURCE=$(select_drive "SOURCE drive (failing)")
TARGET=$(select_drive "TARGET drive (new)")

# 4. Confirm
confirm_selection "$SOURCE" "$TARGET"

# 5. Unmount drives if mounted
for dev in "$SOURCE" "$TARGET"; do
  mountpoints=$(lsblk -no MOUNTPOINT "$dev")
  if [[ -n "$mountpoints" ]]; then
    log "Unmounting $dev..."
    umount "$dev" || {
      log "Failed to unmount $dev. Exiting."
      exit 1
    }
  fi
done

# 6. Run ddrescue (in background), show progress, wait
run_ddrescue "$RESUME_CHOICE" "$SOURCE" "$TARGET"

# 7. Verify cloned drive
verify_cloned_drive "$TARGET"

log "Drive cloning completed successfully."

exit 0
