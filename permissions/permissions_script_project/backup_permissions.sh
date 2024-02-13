#!/bin/bash

# AUTO_ESCALATE
if [ "$(id -u)" -ne 0 ]; then
    sudo "$0" "$@"
    exit $?
fi

SOURCE_DIR="/"
BACKUP_FILE="permissions_backup_$(date +%Y%m%d_%H%M%S).txt"

# Excluding directories that generally don't need permission backups
EXCLUDES="--path /proc --prune -o --path /sys --prune -o --path /dev --prune -o --path /run --prune -o"

# Backup permissions, excluding certain paths
echo "Starting permissions backup..."
find "$SOURCE_DIR" $EXCLUDES -o -exec stat --format="%a %n" {} + > "$BACKUP_FILE"
echo "Permissions backup completed and saved to $BACKUP_FILE"
