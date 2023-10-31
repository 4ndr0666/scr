#!/bin/bash

# --- Auto-Escalate:
if [ "$(id -u)" -ne 0 ]; then
  sudo "$0" "$@"
  exit $?
fi

# --- Initialize a rollback stack for errors:
backup_stack=()

# --- Backup a file before modification:
backup_file() {
    local original_file="$1"
    local backup_file="${original_file}.backup_$(date +%s)"
    cp "$original_file" "$backup_file" || return 1
    backup_stack+=("$backup_file")
}

# --- Rollback changes:
rollback() {
    for backup in "${backup_stack[@]}"; do
        original="${backup%.backup_*}"
        mv "$backup" "$original"
    done
    backup_stack=()
}

# --- Enhanced error handler with rollback:
handle_error() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "Error occurred. Rolling back..."
        rollback
        log "Error occurred with exit code $exit_code. Rolled back changes."
        exit $exit_code
    fi
}

# --- Logging:
log() {
    local message="$1"
    local log_dir="/var/log/permissions_script"
    local log_file="$log_dir/log.txt"

    # Create log directory and file if they don't exist
    [ ! -d "$log_dir" ] && sudo mkdir -p "$log_dir" && sudo touch "$log_file"

    echo "$(date): $message" | sudo tee -a "$log_file" > /dev/null
}

# --- User Input Validation:
validate_directory() {
    local directory="$1"
    if [[ ! -d "$directory" ]]; then
        echo "Error: Directory '$directory' does not exist."
        exit 1
    fi
}

# --- Interactive Mode:
confirm_action() {
    local message="$1"
    echo -n "$message (y/n): "
    read -r confirm
    [[ "$confirm" == "y" || "$confirm" == "Y" ]]
}

# --- Help Documentation:
display_help() {
    clear
    cat help.txt
    echo
    echo "Press any key to return to the main menu."
    read -n 1
}

CONFIG_FILE="$(dirname "$0")/config.cfg"

# --- Load configuration:
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        CONFIGURED=false
    fi
}

# --- Save configuration:
save_config() {
    echo "CONFIGURED=true" > "$CONFIG_FILE"
    echo "DEFAULT_USER=$1" >> "$CONFIG_FILE"
    echo "DEFAULT_GROUP=$2" >> "$CONFIG_FILE"
}

# --- First run config:
prompt_config() {
    echo "First run configuration:"
    echo -n "Enter default user: "
    read -r user
    echo -n "Enter default group: "
    read -r group
    save_config "$user" "$group"
    echo "Configuration saved. Please rerun the script."
    exit 0
}

# === // Main script // ========||
load_config
if [[ "$CONFIGURED" != "true" ]]; then
    prompt_config
fi

# --- Menu:
display_menu() {
    printf "Menu:\n\
    1. Chown %s:%s -R\n\
    2. Compare package permissions against current permissions\n\
    3. Getfacl\n\
    4. Help on Permissions\n\
    5. Reset Permissions to Defaults\n\
    6. Exit\n\n\
    Enter your choice: " "$DEFAULT_USER" "$DEFAULT_GROUP"
}
directory="$1"

# --- Validate dir:
if [ -n "$directory" ]; then
    validate_directory "$directory"
fi

# --- Change ownership and permissions:
change_ownership_permissions() {
    local directory="$1"
    if ! sudo chown "$DEFAULT_USER":"$DEFAULT_GROUP" -R "$directory"; then
        echo "Failed to change ownership."
        exit 1
    fi

    if ! sudo chmod ug+rwx -R "$directory"; then
        echo "Failed to change permissions."
        exit 1
    fi

    echo "Ownership and permissions updated successfully."
}

# --- Compare package permissions against current permissions:
compare_package_permissions() {
    echo "Checking package permissions against current permissions..."
    sudo pacman -Qlq | while read -r file; do
        if [ -e "$file" ]; then
            if [ "$(stat -c "%a" "$file")" != "$(sudo pacman -Qkk "$file" | awk '{print $2}')" ]; then
                echo "Mismatch: $file"
            fi
        fi
    done
}

# --- Get ACL of the directory:
get_directory_acl() {
    local directory="$1"
    echo "Getting ACL of the directory..."
    sudo getfacl -R "$directory"
}

# --- Set standard permissions:
reset_permissions() {
    echo "Caution: This will reset permissions on system directories to defaults."
    echo "It's advisable to have a backup before proceeding."
    read -p "Would you like to create a backup now? (y/n): " create_backup
    if [[ "$create_backup" == "y" ]]; then
        echo "Backup in progress..."
        backup_file  # Replace this with your actual backup command or function
        echo "Backup completed."
    fi

    echo "Updating directory permissions..."

    if [[ -d "/lost+found" ]]; then
        chmod 700 /lost+found || { echo "Failed to set permissions on /lost+found"; exit 1; }
    else
        echo "/lost+found directory not found, skipping..."
    fi

    sudo chmod 755 /lib /lib64 /bin /sbin /srv /home /dev /run /boot /etc || { echo "Failed to set directory permissions."; exit 1; }
    sudo chmod 775 /usr || { echo "Failed to set directory permissions."; exit 1; }
    sudo chmod 750 /root || { echo "Failed to set directory permissions."; exit 1; }
    sudo chmod 555 /proc /sys || { echo "Failed to set directory permissions."; exit 1; }
    sudo chmod 1777 /tmp || { echo "Failed to set directory permissions."; exit 1; }
    echo "Permissions updated successfully."
}
set -e

while true; do
    display_menu
    read -r choice

    case $choice in
        1)
            if [ -z "$directory" ]; then
                echo "Enter the directory path:"
                read -r directory
                validate_directory "$directory"
            fi

            if confirm_action "Are you sure you want to change ownership to $DEFAULT_USER:$DEFAULT_GROUP recursively?"; then
                change_ownership_permissions "$directory"
            else
                echo "Operation cancelled."
            fi
            ;;
        2)
            compare_package_permissions
            ;;
        3)
            if [ -z "$directory" ]; then
                echo "Enter the directory path:"
                read -r directory
                validate_directory "$directory"
            fi

            get_directory_acl "$directory"
            ;;
        4)
            display_help
            ;;
        5)
            reset_permissions
            ;;
        6)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid choice. Please try again."
            ;;
    esac

    echo
done
