#!/bin/bash

# --- // AUTO_ESCALATE:
if [ "$(id -u)" -ne 0 ]; then
      sudo "$0" "$@"
    exit $?
fi

# Define the source directory you want to backup permissions for
SOURCE_DIR="/"

# Define where you want to save the permissions backup
BACKUP_FILE="permissions_backup.txt"

# Backup permissions using find, stat, and redirecting output to a file
find "$SOURCE_DIR" -exec stat --format="%a %n" {} \; > "$BACKUP_FILE"

# Print a completion message
echo "Permissions backup completed and saved to $BACKUP_FILE"
