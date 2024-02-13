#!/bin/bash

# AUTO_ESCALATE
if [ "$(id -u)" -ne 0 ]; then
    sudo "$0" "$@"
    exit $?
fi

BACKUP_FILE="permissions_backup.txt"
LOG_FILE="apply_permissions_log_$(date +%Y%m%d_%H%M%S).txt"
DRY_RUN=false

# Check for dry-run flag
while getopts ":d" opt; do
  case $opt in
    d)
      DRY_RUN=true
      echo "Dry run enabled - no changes will be made."
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done

# Verify backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo "Permissions backup file does not exist: $BACKUP_FILE"
    exit 1
fi

# Apply permissions from the backup file
while IFS=' ' read -r perm path; do
    if [ -e "$path" ]; then
        if [ "$DRY_RUN" = false ]; then
            chmod "$perm" "$path" && echo "Applied $perm to $path" >> "$LOG_FILE"
        else
            echo "Would apply $perm to $path" >> "$LOG_FILE"
        fi
    else
        echo "Warning: Path does not exist - $path" >> "$LOG_FILE"
    fi
done < "$BACKUP_FILE"

echo "Permissions have been applied from $BACKUP_FILE. See $LOG_FILE for details."
