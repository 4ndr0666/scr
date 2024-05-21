#!/bin/bash

# Function to display a menu
display_menu() {
    echo "Choose an option:"
    echo "1) Create Backup"
    echo "2) Restore Backup"
    echo "3) Exit"
}

# Function to check for root privileges
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "This script requires root privileges. Please run as root or use sudo."
        exit 1
    fi
}

# Function to create a backup
create_backup() {
    read -p "Enter the backup directory path: " backup_dir
    if [ -z "$backup_dir" ]; then
        echo "Backup directory path cannot be empty."
        exit 1
    fi

    mkdir -p "$backup_dir"
    if [ $? -ne 0 ]; then
        echo "Failed to create backup directory. Check your permissions."
        exit 1
    fi

    rsync -aAXv --exclude={"/proc/*","/sys/*","/dev/*","/run/*","/tmp/*","/mnt/*","/media/*","/lost+found","$backup_dir"} / "$backup_dir/backup/"
    if [ $? -ne 0 ]; then
        echo "Failed to create backup. Check your permissions and available disk space."
        exit 1
    fi

    find / -path /proc -prune -o -path /sys -prune -o -path /dev -prune -o -path /run -prune -o -path /tmp -prune -o -path "$backup_dir" -prune -o -print0 | xargs -0 getfacl --skip-base > "$backup_dir/acls.backup"
    if [ $? -ne 0 ]; then
        echo "Failed to create ACL backup. Check your permissions."
        exit 1
    fi

    echo "Backup created successfully in $backup_dir."
}

# Function to restore a backup
restore_backup() {
    read -p "Enter the backup directory path: " backup_dir
    read -p "Enter the old user name: " old_user
    read -p "Enter the target user name: " target_user

    if [ -z "$backup_dir" ] || [ -z "$old_user" ] || [ -z "$target_user" ]; then
        echo "Backup directory path, old user name, and target user name cannot be empty."
        exit 1
    fi

    # Ensure the backup files exist
    if [ ! -d "$backup_dir/backup" ] || [ ! -f "$backup_dir/acls.backup" ]; then
        echo "Backup files not found in $backup_dir."
        exit 1
    fi

    rsync -aAXv "$backup_dir/backup/" /
    if [ $? -ne 0 ]; then
        echo "Failed to restore backup. Check your permissions and available disk space."
        exit 1
    fi

    # Align the ACL file to the target user
    sed -i "s/$old_user/$target_user/g" "$backup_dir/acls.backup"
    if [ $? -ne 0 ]; then
        echo "Failed to adjust ACL file. Check your permissions."
        exit 1
    fi

    # Restore the ACLs
    setfacl --restore="$backup_dir/acls.backup"
    if [ $? -ne 0 ]; then
        echo "Failed to restore ACLs. Check your permissions."
        exit 1
    fi

    echo "Backup restored successfully to the target user $target_user."
}

# Function for auto privilege escalation
auto_escalate() {
    if [ "$EUID" -ne 0 ]; then
        echo "This script requires root privileges. Attempting to escalate privileges..."
        exec sudo "$0" "$@"
        exit 1
    fi
}

# Main script logic
auto_escalate "$@"

while true; do
    display_menu
    read -p "Select an option (1-3): " option

    case $option in
        1)
            create_backup
            ;;
        2)
            restore_backup
            ;;
        3)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option. Please try again."
            ;;
    esac
done