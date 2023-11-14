#!/bin/bash

# ---- // AUTO-ESCALATE:
if [ "$(id -u)" -ne 0 ]; then
  sudo "$0" "$@"
  exit $?
fi

# --- Banner
echo -e "\033[34m"
cat << "EOF"
#                                                 .__
#  ______   ___________  _____   ______      _____|  |__
#  \____ \_/ __ \_  __ \/     \ /  ___/     /  ___/  |  \
#  |  |_> >  ___/|  | \/  Y Y  \\___ \      \___ \|   Y  \
#  |   __/ \___  >__|  |__|_|  /____  > /\ /____  >___|  /
#  |__|        \/            \/     \/  \/      \/     \/
EOF
echo -e "\033[0m"

# ---- // LOGGING:
log() {
    local message="$1"
    local log_dir="/var/log/permissions_script"
    local log_file="$log_dir/log.txt"

    [ ! -d "$log_dir" ] && sudo mkdir -p "$log_dir" && sudo chmod 700 "$log_dir"
    [ ! -f "$log_file" ] && sudo touch "$log_file" && sudo chmod 600 "$log_file"

    echo "$(date): $message" | sudo tee -a "$log_file" > /dev/null
}

# ---- // CONFIG SETUP:
CONFIG_FILE="$(dirname "$0")/config.cfg"
CONFIGURED=false
DEFAULT_USER=""
DEFAULT_GROUP=""

# ---- Load configuration:
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        [ -z "$DEFAULT_USER" ] && CONFIGURED=false
        [ -z "$DEFAULT_GROUP" ] && CONFIGURED=false
    else
        CONFIGURED=false
    fi
}

# ---- Save configuration:
save_config() {
    echo "CONFIGURED=true" > "$CONFIG_FILE"
    echo "DEFAULT_USER=$1" >> "$CONFIG_FILE"
    echo "DEFAULT_GROUP=$2" >> "$CONFIG_FILE"
    sudo chmod 600 "$CONFIG_FILE"
}

# ---- First run config:
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

# ---- // BACKUP FUNCTIONS:
backup_stack=()

backup_file() {
    local original_file="$1"
    local backup_file="${original_file}.backup_$(date +%s)"
    cp "$original_file" "$backup_file" || { log "Backup failed for $original_file"; return 1; }
    backup_stack+=("$backup_file")
}

rollback() {
    for backup in "${backup_stack[@]}"; do
        original="${backup%.backup_*}"
        mv "$backup" "$original" || { log "Rollback failed for $backup"; }
    done
    backup_stack=()
}

handle_error() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "Error occurred. Rolling back..."
        rollback
        log "Error occurred with exit code $exit_code. Rolled back changes."
        exit $exit_code
    fi
}

validate_directory() {
    local directory="$1"
    if [[ ! -d "$directory" ]]; then
        log "Error: Directory '$directory' does not exist."
        echo "Error: Directory '$directory' does not exist."
        exit 1
    fi
}

confirm_action() {
    local message="$1"
    echo -n "$message (y/n): "
    read -r confirm
    [[ "$confirm" == "y" || "$confirm" == "Y" ]]
}

set_directory_permissions() {
    local mode=$1
    shift
    local directories=("$@")
    echo "Setting mode $mode for ${directories[@]}"
    sudo chmod $mode "${directories[@]}" || { log "Failed to set directory permissions."; exit 1; }
}

# --- Help Documentation:
display_help() {
    clear
    echo "Linux Permissions Help"
    echo "----------------------"
    echo ""
    echo "Permissions in Linux are managed through a system of ownership and predefined permissions associated with objects like files and directories. The permissions system is divided into three distinct scopes: Owner, Group, and Others."
    echo ""
    echo "Understanding Permissions:"
    echo "Permissions are represented as a three-digit number, where each digit corresponds to the permissions for the Owner, Group, and Others respectively."
    echo ""
    echo "Each scope can have the following permissions:"
    echo "- Read (r): Permission to read the contents."
    echo "- Write (w): Permission to modify or delete."
    echo "- Execute (x): Permission to execute."
    echo ""
    echo "Numerically, these permissions are represented as follows:"
    echo "- Read: 4"
    echo "- Write: 2"
    echo "- Execute: 1"
    echo ""
    echo "Common Permission Modes:"
    echo "- chmod 751: +rwx for owner, +rx for group, +x for others"
    echo "- chmod 755: +rwx for owner, +rwx for group, +rx for others"
    echo "- chmod 744: +wx for owner, no permissions for group, +r for others"
    echo "- ... and so on."
    echo ""
    echo "Menu Options Explained:"
    echo "1. Change Ownership (Chown): Changes the ownership of the specified directory recursively."
    echo "2. Compare Permissions: Checks system files and compares their current permissions against the package defaults."
    echo "3. Get ACL (Access Control List): Displays the ACL for the specified directory."
    echo "4. Help on Permissions: Displays this help documentation."
    echo "5. Reset Permissions to Defaults: Resets permissions on certain system directories to sensible defaults."
    echo "6. Exit: Exits the script."
    echo ""
    echo "Usage:"
    echo "1. Launch the script."
    echo "2. Follow the on-screen prompts to select an option from the menu."
    echo "3. For Chown and Get ACL options, you may be prompted to enter a directory path if not provided as an argument when launching the script."
    echo ""
    echo "Note:"
    echo "- It's advisable to have a backup before making changes to permissions, especially on system directories."
    echo "- Incorrect permissions can lead to system instability or security risks."
    echo ""
    echo "Press any key to return to the main menu."
    read -n 1
}

spin() {
    local pid=$1
    local delay=0.05
    local spinstr='|/-\\'
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf "\e[1;34m\r[*] \e[1;32mIt will take time..Please wait...  [\e[1;33m%c\e[1;32m]\e[0m  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\e[1;33m[Done]\e[0m\n"
}

load_config
if [[ "$CONFIGURED" != "true" ]]; then
    prompt_config
fi

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

directory="$PWD"

if [ -n "$directory" ]; then
    validate_directory "$directory"
fi

change_ownership_permissions() {
    local directory="$1"
    if ! sudo chown "$DEFAULT_USER":"$DEFAULT_GROUP" -R "$directory"; then
        log "Failed to change ownership."
        echo "Failed to change ownership."
        exit 1
    fi

    if ! sudo chmod ug+rwx -R "$directory"; then
        log "Failed to change permissions."
        echo "Failed to change permissions."
        exit 1
    fi

    echo "Ownership and permissions updated successfully."
}

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

get_directory_acl() {
    local directory="$1"
    echo "Getting ACL of the directory..."
    sudo getfacl -R "$directory"
}

reset_permissions() {
    local backup_file="/var/backups/permissions/backup_$(date +%F_%T).acl"
    echo "Initiating automatic backup..."
    echo "Backup in progress..."

    (sudo     getfacl -R -p /lib /lib64 /bin /sbin /srv /home /dev /run /boot /etc /usr /root /proc /sys /tmp | sudo tee "$backup_file" > /dev/null 2>&1) & spin $!

    echo "Backup completed successfully."
    echo "$backup_file" >> "$backup_stack" || { log "Backup failed! Aborting..."; exit 1; }
    trap "echo; echo 'Operation aborted.'; exit 1" SIGINT SIGTERM

    echo "Updating directory permissions..."

    set_directory_permissions 755 /lib /lib64 /bin /sbin /srv /home /dev /run /boot /etc "Essential system directories should be readable and executable by all, but only writable by root."
    set_directory_permissions 775 /usr "The /usr directory contains many user commands and can be written to by root and the staff group."
    set_directory_permissions 750 /root "The root user's home directory should only be accessible to root."
    set_directory_permissions 555 /proc /sys "These directories provide a view into the system's status and should be read-only for all users."
    set_directory_permissions 1777 /tmp "The temporary directory should be world-writable with the sticky bit set to prevent users from deleting each other's files."

    if [[ -d "/lost+found" ]]; then
        set_directory_permissions 700 /lost+found "The /lost+found directory is used by the system to recover files and should be restricted to root."
    else
        echo "/lost+found directory not found, skipping..."
    fi

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
                read -e directory
                validate_directory "$directory"
            fi

            if confirm_action "Are you sure you want to change ownership to $DEFAULT_USER:$DEFAULT_GROUP recursively?"; then
                change_ownership_permissions "$directory"
            else
                echo "Operation cancelled."
            fi
            ;;
        2)
            echo "Checking package permissions against current permissions..."
            (compare_package_permissions & spin $!)
            ;;
        3)
            if [ -z "$directory" ]; then
                echo "Enter the directory path:"
                read -e directory
                validate_directory "$directory"
            fi

            get_directory_acl "$directory"
            ;;
        4)
            display_help
            ;;
        5)
            echo -n "Would you like to create a backup? (y/n): "
            read -r backup_choice
            if [[ "$backup_choice" == "y" || "$backup_choice" == "Y" ]]; then
                reset_permissions
            else
                echo "Skipping backup and resetting permissions..."
                reset_permissions_without_backup
            fi
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
