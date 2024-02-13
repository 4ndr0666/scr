#!/bin/bash

# Define global variables
BACKUP_DIR="/mnt/data"  # Adjust this path as needed
DEFAULT_BACKUP_FILE="${BACKUP_DIR}/standardpermissions.acl"

# Ensure running as root or with sudo
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Trying to escalate..."
    sudo "$0" "$@"
    exit $?
fi

# Function to backup permissions
backup_permissions() {
    local backup_file=$1
    echo "Starting permissions backup..."
    getfacl -R / > "$backup_file"
    echo "Permissions backup completed and saved to $backup_file"
}

# Function to restore permissions
restore_permissions() {
    local backup_file=$1
    if [ -f "$backup_file" ]; then
        echo "Restoring permissions from $backup_file..."
        setfacl --restore="$backup_file"
        echo "Permissions have been restored."
    else
        echo "Backup file does not exist: $backup_file"
        return 1
    fi
}

# Function to display the menu
show_menu() {
    echo "Permissions Management Script"
    echo "1) Backup Permissions"
    echo "2) Restore Permissions"
    echo "3) Exit"
    echo -n "Enter your choice (1-3): "
}

# Main loop
while true; do
    show_menu
    read choice
    case "$choice" in
        1)
            echo -n "Enter filename for backup (default: ${DEFAULT_BACKUP_FILE}): "
            read backup_file
            backup_file="${backup_file:-$DEFAULT_BACKUP_FILE}"
            backup_permissions "$backup_file"
            ;;
        2)
            echo -n "Enter filename to restore from (default: ${DEFAULT_BACKUP_FILE}): "
            read backup_file
            backup_file="${backup_file:-$DEFAULT_BACKUP_FILE}"
            restore_permissions "$backup_file"
            ;;
        3)
            echo "Exiting..."
            break
            ;;
        *)
            echo "Invalid choice, please select 1, 2, or 3."
            ;;
    esac
done
