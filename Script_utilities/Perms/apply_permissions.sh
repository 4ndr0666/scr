#!/bin/bash

# --- // AUTO_ESCALATE:
if [ "$(id -u)" -ne 0 ]; then
      sudo "$0" "$@"
    exit $?
fi

# Define where the permissions backup file is located
BACKUP_FILE="permissions_backup.txt"

# Ensure the script is being run with root privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

# Check if the backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo "Permissions backup file does not exist: $BACKUP_FILE"
    exit 1
fi

# Apply permissions from the backup file
while IFS=' ' read -r perm path; do
  # Check if the file or directory exists before applying permissions
  if [ -e "$path" ]; then
    chmod "$perm" "$path"
  else
    echo "Warning: Path does not exist - $path"
  fi
done < "$BACKUP_FILE"

# Print a completion message
echo "Permissions have been applied from $BACKUP_FILE"
