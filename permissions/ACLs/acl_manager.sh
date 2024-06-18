#!/bin/bash

# Function to display a menu
display_menu() {
    echo "Choose an option:"
    echo "1) Backup System Permissions"
    echo "2) Restore System Permissions"
    echo "3) Change Username"
    echo "4) Lock File"
    echo "5) Unlock File"
    echo "6) Exit"
}

# Function to check for root privileges
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "This script requires root privileges. Please run as root or use sudo."
        exit 1
    fi
}

# Function to create a backup
backup_system_permissions() {
    read -rp "Enter the backup directory path: " backup_dir
    [ -z "$backup_dir" ] && { echo "Backup directory path cannot be empty."; exit 1; }

    mkdir -p "$backup_dir" || { echo "Failed to create backup directory. Check your permissions."; exit 1; }

    echo "Backing up system permissions..."
    sudo getfacl -Rn --one-file-system / > "$backup_dir/system_perms.acl" || { echo "Failed to backup system permissions."; exit 1; }

    echo "Backing up system ownerships..."
    sudo find / \( -path /proc -o -path /sys -o -path /dev -o -path /run -o -path /tmp -o -path /mnt -o -path /media -o -path /lost+found \) -prune -o -exec stat --format '%A %a %u %g %n' {} \; > "$backup_dir/system_ownerships.txt" || { echo "Failed to backup system ownerships."; exit 1; }

    echo "System ownerships and permissions successfully backed up in $backup_dir."
}

# Function to restore a backup
restore_system_permissions() {
    read -rp "Enter the backup directory path: " backup_dir
    read -rp "Enter the old user name: " old_user
    read -rp "Enter the target user name: " target_user

    [ -z "$backup_dir" ] || [ -z "$old_user" ] || [ -z "$target_user" ] && { echo "Backup directory path, old user name, and target user name cannot be empty."; exit 1; }

    # Ensure the backup files exist
    [ -f "$backup_dir/system_ownerships.txt" ] || { echo "Ownership backup not found in $backup_dir."; exit 1; }
    [ -f "$backup_dir/system_perms.acl" ] || { echo "Permissions backup not found in $backup_dir."; exit 1; }

    echo "Aligning the ACL file to the target user..."
    sudo sed -i "s/\\b$old_user\\b/$target_user/g" "$backup_dir/system_perms.acl"
    #|| { echo "Failed to change username in ACL file."; exit 1; }

    echo "Restoring ACLs..."
    sudo setfacl --restore="$backup_dir/system_perms.acl"
    #|| { echo "Failed to restore system permissions."; exit 1; }

    echo "Restoring ownerships and permissions for user $old_user to $target_user..."
    backup_file="$backup_dir/system_ownerships.txt"

    while IFS= read -r line; do
        if [[ "$line" =~ ^total ]]; then
            continue
        fi

        perms=$(echo "$line" | awk '{print $1}')
        owner=$(echo "$line" | awk '{print $3}')
        group=$(echo "$line" | awk '{print $4}')
        path=$(echo "$line" | awk '{print substr($0, index($0,$9))}')

        # Change ownership only if it matches the old_user
        if [[ "$owner" == "$old_user" ]]; then
            owner="$target_user"
        fi
        if [[ "$group" == "$old_user" ]]; then
            group="$target_user"
        fi

        if [[ -e "$path" ]]; then
            sudo chown "$owner:$group" "$path" || echo "Failed to chown $path"
            sudo chmod "$perms" "$path" || echo "Failed to chmod $path"
        else
            echo "Warning: $path does not exist, skipping."
        fi
    done < "$backup_file"

    echo "Restoring critical system files ownership to root..."
    # Explicitly ensure critical system files are owned by root
    critical_paths=(
        "/etc"
        "/bin"
        "/sbin"
        "/usr"
        "/lib"
        "/lib64"
        "/var"
        "/boot"
        "/root"
    )
    for critical_path in "${critical_paths[@]}"; do
        sudo chown -R root:root "$critical_path"
	#|| echo "Failed to set ownership for $critical_path"
    done

    echo "System ownerships and permissions successfully restored and set to $target_user."
}

# Function to change username comprehensively
change_username() {
    local old_user="$1"
    local new_user="$2"

    # Validate input
    [ -z "$old_user" ] || [ -z "$new_user" ] && { echo "Old username and new username cannot be empty."; exit 1; }

    echo "Changing username from $old_user to $new_user..."

    # Backup important files
    echo "Creating backups of important files..."
    sudo cp /etc/passwd /etc/passwd.bak
    sudo cp /etc/group /etc/group.bak
    sudo cp /etc/shadow /etc/shadow.bak
    sudo cp /etc/gshadow /etc/gshadow.bak

    # Change username in system files
    sudo sed -i "s/\\b$old_user\\b/$new_user/g" /etc/passwd
    sudo sed -i "s/\\b$old_user\\b/$new_user/g" /etc/group
    sudo sed -i "s/\\b$old_user\\b/$new_user/g" /etc/shadow
    sudo sed -i "s/\\b$old_user\\b/$new_user/g" /etc/gshadow

    # Rename home directory
    sudo mv "/home/$old_user" "/home/$new_user"
    sudo usermod -d "/home/$new_user" -l "$new_user" "$old_user"

    # Update ownership of home directory and files
    sudo find /home/$new_user -user $old_user -exec chown -h $new_user {} \\;
    sudo find / -path /proc -prune -o -path /sys -prune -o -path /dev -prune -o -path /run -prune -o -path /tmp -prune -o -path /mnt -prune -o -path /media -prune -o -path /lost+found -prune -o -user $old_user -exec chown -h $new_user {} \\;

    # Update ACLs
    sudo find /home/$new_user -exec getfacl {} + > /tmp/acl_backup.txt
    sudo sed -i "s/\\b$old_user\\b/$new_user/g" /tmp/acl_backup.txt
    sudo setfacl --restore=/tmp/acl_backup.txt

    echo "Username changed from $old_user to $new_user successfully."
}

# Function to lock a file
lock_file() {
    read -rp "Enter the file path to lock: " file_path
    if [ -e "$file_path" ]; then
        sudo chattr +i "$file_path" || { echo "Failed to lock $file_path"; exit 1; }
        echo "File $file_path locked successfully."
    else
        echo "File $file_path does not exist."
        exit 1
    fi
}

# Function to unlock a file
unlock_file() {
    read -rp "Enter the file path to unlock: " file_path
    if [ -e "$file_path" ]; then
        sudo chattr -i "$file_path" || { echo "Failed to unlock $file_path"; exit 1; }
        echo "File $file_path unlocked successfully."
    else
        echo "File $file_path does not exist."
        exit 1
    fi
}

# Function for auto privilege escalation
auto_escalate() {
    if [ "$EUID" -ne 0 ]; then
        echo "This script requires root privileges. Attempting to escalate privileges..."
        exec sudo "$0" "$@"
    fi
}

# Main script logic
auto_escalate "$@"

while true; do
    display_menu
    read -rp "Select an option (1-6): " option

    case $option in
        1)
            backup_system_permissions
            ;;
        2)
            restore_system_permissions
            ;;
        3)
            read -rp "Enter the old username: " old_username
            read -rp "Enter the new username: " new_username


            change_username "$old_username" "$new_username"
            ;;
        4)
            lock_file
            ;;
        5)
            unlock_file
            ;;
        6)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option. Please try again."
            ;;
    esac
done
