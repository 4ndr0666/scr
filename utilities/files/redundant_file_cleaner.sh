#!/bin/zsh

# Script: remove_duplicates.sh
# Purpose: Automatically identify and delete duplicate files with intelligent safeguards.
# Usage: sudo ./remove_duplicates.sh /path/to/directory [--dry-run]
# Options:
#   --dry-run : Perform a trial run without deleting any files.

set -euo pipefail

# Variables
LOG_FILE="$HOME/remove_duplicates.log"
TRASH_DIR="$HOME/.local/share/Trash/files"

# Function to log messages
log() {
  echo "$(date +"%Y-%m-%d %H:%M:%S") : $1" | tee -a "$LOG_FILE"
}

# Function to display usage
usage() {
  echo "Usage: $0 /path/to/directory [--dry-run]"
  exit 1
}

# Parse arguments
DRY_RUN=false
if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
fi

TARGET_DIR="$1"

if [[ $# -eq 2 ]]; then
  if [[ "$2" == "--dry-run" ]]; then
    DRY_RUN=true
  else
    usage
  fi
fi

# Check if script is run as root for writing to log
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run with sudo or as root for logging purposes."
  exit 1
fi

log "Starting remove_duplicates.sh script."

# Check if TARGET_DIR exists
if [[ ! -d "$TARGET_DIR" ]]; then
  log "Error: Directory '$TARGET_DIR' does not exist."
  exit 1
fi

# Create log file if it doesn't exist
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"

log "Scanning directory: $TARGET_DIR"
log "Dry-run mode: $DRY_RUN"

# Ensure Trash directory exists
mkdir -p "$TRASH_DIR"

# Find and process duplicates
find "$TARGET_DIR" -type f | while read -r FILE; do
  DIR=$(dirname "$FILE")
  BASENAME=$(basename "$FILE")
  
  # Match files with pattern 'name.ext', 'name 1.ext', 'name 2.ext', etc.
  if [[ "$BASENAME" =~ ^(.+)\ ([0-9]+)\.(.+)$ ]]; then
    ORIGINAL="${match[1]}.${match[3]}"
    DUPLICATE="$FILE"
    
    # Check if original exists
    if [[ -f "$DIR/$ORIGINAL" ]]; then
      if [[ "$DRY_RUN" == true ]]; then
        log "DRY RUN: Would move '$DUPLICATE' to Trash."
      else
        mv "$DUPLICATE" "$TRASH_DIR/" 2>/dev/null
        if [[ $? -eq 0 ]]; then
          log "Moved '$DUPLICATE' to Trash."
        else
          log "Error: Failed to move '$DUPLICATE' to Trash."
        fi
      fi
    fi
  fi
done

log "Duplicate removal process completed."
if [[ "$DRY_RUN" == true ]]; then
  echo "Dry-run completed. No files were moved."
else
  echo "Duplicate files have been moved to Trash."
fi

exit 0