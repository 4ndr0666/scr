#!/bin/bash
# shellcheck disable=all

# Define backup directory and filename
BACKUP_DIR="/Nas/Backups/"
BACKUP_FILE="pacman_backup_$(date +%Y%m%d%H%M%S).tar.gz"

# Create backup directory if it doesn't exist
mkdir -pv "$BACKUP_DIR"

# Create a tarball of the pacman directory
tar -czvf "$BACKUP_DIR/$BACKUP_FILE" /var/lib/pacman

# Verify if the backup was created successfully
if [ $? -eq 0 ]; then
    echo "Backup created successfully: $BACKUP_DIR/$BACKUP_FILE"
else
    echo "Backup creation failed!"
fi
