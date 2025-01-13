#!/bin/bash

# Script: remove_duplicates.sh
# Purpose: Remove duplicate files with patterns like 'file.ext', 'file 1.ext', 'file 2.ext', etc.
# Usage: ./remove_duplicates.sh /path/to/directory

# Check if directory is provided
if [ -z "$1" ]; then
  echo "Usage: $0 /path/to/directory"
  exit 1
fi

TARGET_DIR="$1"
LOG_FILE="/var/log/remove_duplicates.log"

# Ensure the target directory exists
if [ ! -d "$TARGET_DIR" ]; then
  echo "Error: Directory '$TARGET_DIR' does not exist."
  exit 1
fi

# Create log file if it doesn't exist
sudo touch "$LOG_FILE"
sudo chmod 644 "$LOG_FILE"

echo "Starting duplicate removal in '$TARGET_DIR'..."
echo "Log file: $LOG_FILE"

# Find all files and process them
find "$TARGET_DIR" -type f | while read -r FILE; do
  DIR=$(dirname "$FILE")
  BASENAME=$(basename "$FILE")
  
  # Match files with pattern 'name.ext', 'name 1.ext', 'name 2.ext', etc.
  if [[ "$BASENAME" =~ ^(.+)\ ([0-9]+)\.(.+)$ ]]; then
    ORIGINAL="${BASH_REMATCH[1]}.${BASH_REMATCH[3]}"
    DUPLICATE="$FILE"
    
    # Check if original exists
    if [ -f "$DIR/$ORIGINAL" ]; then
      echo "Removing duplicate: $DUPLICATE (Original: $DIR/$ORIGINAL)"
      
      # Move duplicate to Trash instead of deleting
      mv "$DUPLICATE" "$HOME/.local/share/Trash/files/" 2>/dev/null
      if [ $? -eq 0 ]; then
        echo "$(date): Moved '$DUPLICATE' to Trash." | sudo tee -a "$LOG_FILE"
      else
        echo "Error: Failed to move '$DUPLICATE' to Trash." | sudo tee -a "$LOG_FILE"
      fi
    fi
  fi
done

echo "Duplicate removal completed."