#!/bin/bash

# Function to display a menu
display_menu() {
    echo "Choose an option:"
    echo "1) Backup System Permissions"
    echo "2) Restore System Permissions"
    echo "3) Change Username"
    echo "4) Lock File"
    echo "5) Unlock File"
    echo "6) Apply Permissions to Specific Directory"
    echo "7) Exit"
}

# Function to check for root privileges
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "This script requires root privileges. Please run as root or use sudo."
        exit 1
    fi
}

# Function to secure the ACL directory
secure_acl_dir() {
    sudo chattr +i /var/acl_manager
}

# Function to unsecure the ACL directory
unsecure_acl_dir() {
    sudo chattr -i /var/acl_manager
}

# Function to load or create the initial ACL file
load_or_create_acl() {
    unsecure_acl_dir
    mkdir -p /var/acl_manager

    acl_file="/var/acl_manager/system_perms.acl"
    if [ ! -f "$acl_file" ]; then
        echo "No ACL file found at $acl_file."
        read -rp "Do you want to create an ACL file with current system settings? (y/n): " create_acl
        if [ "$create_acl" == "y" ]; then
            echo "Creating ACL file with current system settings..."
            sudo getfacl -Rn --one-file-system / > "$acl_file" || { echo "Failed to create ACL file."; secure_acl_dir; exit 1; }
            echo "ACL file created at $acl_file."
        else
            echo "No ACL file and no option to create one. Exiting..."
            secure_acl_dir
            exit 1
        fi
    else
        echo "ACL file found at $acl_file. Using this as the default settings."
    fi
    secure_acl_dir
}

# Function to create a backup
backup_system_permissions() {
    unsecure_acl_dir
    backup_dir="/var/acl_manager/backups"
    mkdir -p "$backup_dir"

    echo "Backing up system permissions..."
    sudo getfacl -Rn --one-file-system / > "$backup_dir/system_perms.acl" || { echo "Failed to backup system permissions."; secure_acl_dir; exit 1; }

    echo "Backing up system ownerships..."
    sudo find / \( -path /proc -o -path /sys -o -path /dev -o -path /run -o -path /tmp -o -path /mnt -o -path /media -o -path /lost+found \) -prune -o -exec stat --format '%A %a %u %g %n' {} \; > "$backup_dir/system_ownerships.txt" || { echo "Failed to backup system ownerships."; secure_acl_dir; exit 1; }

    echo "System ownerships and permissions successfully backed up in $backup_dir."
    secure_acl_dir
}

# Function to restore a backup
restore_system_permissions() {
    unsecure_acl_dir
    backup_dir="/var/acl_manager/backups"

    read -rp "Do you need to align usernames? (y/n): " align_usernames
    if [ "$align_usernames" == "y" ]; then
        read -rp "Enter the old user name: " old_user
        read -rp "Enter the target user name: " target_user
    fi

    # Ensure the backup files exist
    [ -f "$backup_dir/system_ownerships.txt" ] || { echo "Ownership backup not found in $backup_dir."; secure_acl_dir; exit 1; }
    [ -f "$backup_dir/system_perms.acl" ] || { echo "Permissions backup not found in $backup_dir."; secure_acl_dir; exit 1; }

    if [ "$align_usernames" == "y" ]; then
        echo "Aligning the ACL file to the target user..."
        sudo sed -i "s/\\b$old_user\\b/$target_user/g" "$backup_dir/system_perms.acl"
    fi

    echo "Restoring ACLs..."
    sudo setfacl --restore="$backup_dir/system_perms.acl"

    if [ "$align_usernames" == "y" ]; then
        echo "Restoring ownerships and permissions for user $old_user to $target_user..."
    else
        echo "Restoring ownerships and permissions..."
    fi

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
        if [ "$align_usernames" == "y" ]; then
            if [[ "$owner" == "$old_user" ]]; then
                owner="$target_user"
            fi
            if [[ "$group" == "$old_user" ]]; then
                group="$target_user"
            fi
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
    done

    echo "System ownerships and permissions successfully restored."
    secure_acl_dir
}

# Function to change username comprehensively
change_username() {
    unsecure_acl_dir
    local old_user="$1"
    local new_user="$2"

    # Validate input
    [ -z "$old_user" ] || [ -z "$new_user" ] && { echo "Old username and new username cannot be empty."; secure_acl_dir; exit 1; }

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
    sudo find /home/$new_user -user $old_user -exec chown -h $new_user {} \;
    sudo find / -path /proc -prune -o -path /sys -prune -o -path /dev -prune -o -path /run -prune -o -path /tmp -prune -o -path /mnt -prune -o -path /media -prune -o -path /lost+found -prune -o -user $old_user -exec chown -h $new_user {} \;

    # Update ACLs
    sudo find /home/$new_user -exec getfacl {} + > /tmp/acl_backup.txt
    sudo sed -i "s/\\b$old_user\\b/$new_user/g" /tmp/acl_backup.txt
    sudo setfacl --restore=/tmp/acl_backup.txt

    echo "Username changed from $old_user to $new_user successfully."
    secure_acl_dir
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

# Function to set permissions and ownership for a directory and its contents
set_permissions() {
    local dir=$1
    local owner=$2
    local group=$3
    local dir_perms=$4
    local file_perms=$5

    # Set ownership
    sudo chown -R "$owner":"$group" "$dir"

    # Set directory permissions
    find "$dir" -type d -exec chmod "$dir_perms" {} \;

    # Set file permissions
    find "$dir" -type f -exec chmod "$file_perms" {} \;
}

# Function to intelligently set permissions for a specific directory
apply_permissions_to_specific_dir() {
    read -rp "Enter the directory path: " dir_path

    # Suggest default values
    default_owner=$(getfacl -cp "$dir_path" | grep "^owner:" | cut -d: -f2)
    default_group=$(getfacl -cp "$dir_path" | grep "^group:" | cut -d: -f2)
    default_dir_perms=$(stat -c "%a" "$dir_path")
    default_file_perms=$(stat -c "%a" "$dir_path"/* | sort | uniq | head -n 1)

    echo "Recommended settings:"
    echo "Owner: $default_owner"
    echo "Group: $default_group"
    echo "Directory permissions: $default_dir_perms"
    echo "File permissions: $default_file_perms"

    read -rp "Enter owner (default: $default_owner): " owner
    read -rp "Enter group (default: $default_group): " group
    read -rp "Enter directory permissions (default: $default_dir_perms): " dir_perms
    read -rp "Enter file permissions (default: $default_file_perms): " file_perms

    # Use defaults if inputs are empty
    owner=${owner:-$default_owner}
    group=${group:-$default_group}
    dir_perms=${dir_perms:-$default_dir_perms}
    file_perms=${file_perms:-$default_file_perms}

    set_permissions "$dir_path" "$owner" "$group" "$dir_perms" "$file_perms"

    echo "Permissions and ownership for $dir_path have been set."
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

# Unsecure the ACL directory, load or create the ACL file, and then secure the directory again
unsecure_acl_dir
load_or_create_acl
secure_acl_dir

while true; do
    display_menu
    read -rp "Select an option (1-7): " option

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
            apply_permissions_to_specific_dir
            ;;
        7)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option. Please try again."
            ;;
    esac
done
