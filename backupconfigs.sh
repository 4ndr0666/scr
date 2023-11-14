#!/bin/bash

# --- Escalate
if [ "$(id -u)" -ne 0 ]; then
  sudo "$0" "$@"
  exit $?
fi

# --- Banner
echo -e "\033[34m"
cat << "EOF"
__________                __                                     _____.__                         .__
\______   \_____    ____ |  | ____ ________   ____  ____   _____/ ____\__| ____  ______      _____|  |__
 |    |  _/\__  \ _/ ___\|  |/ /  |  \____ \_/ ___\/  _ \ /    \   __\|  |/ ___\/  ___/     /  ___/  |  \
 |    |   \ / __ \\  \___|    <|  |  /  |_> >  \__(  <_> )   |  \  |  |  / /_/  >___ \      \___ \|   Y  \
 |______  /(____  /\___  >__|_ \____/|   __/ \___  >____/|___|  /__|  |__\___  /____  > /\ /____  >___|  /
        \/      \/     \/     \/     |__|        \/           \/        /_____/     \/  \/      \/     \/
EOF
echo -e "\033[0m"

# Initialize variables
LOG_DIR="/var/log/permissions_script"
CONFIG_FILE="$(dirname "$0")/config.cfg"
BACKUP_DIR="/var/backups/permissions"

# Functions
log() { echo "$(date): $1" | sudo tee -a "$LOG_DIR/log.txt" > /dev/null; }

create_log_dir() {
    [ ! -d "$LOG_DIR" ] && sudo mkdir -p "$LOG_DIR" && sudo touch "$LOG_DIR/log.txt";
}

load_config() {
    [[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE" || CONFIGURED=false;
}

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

save_config() {
    echo "CONFIGURED=true" > "$CONFIG_FILE"
    echo "DEFAULT_USER=$1" >> "$CONFIG_FILE"
    echo "DEFAULT_GROUP=$2" >> "$CONFIG_FILE"
}

backup_file() {
    local original_file="$1"
    local backup_file="${original_file}.backup_$(date +%s)"
    cp "$original_file" "$backup_file" || return 1
    backup_stack+=("$backup_file")
}

rollback() {
    for backup in "${backup_stack[@]}"; do
        original="${backup%.backup_*}"
        mv "$backup" "$original"
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
    sudo chmod $mode "${directories[@]}" || { echo "Failed to set directory permissions."; exit 1; }
}

display_help() {
    clear
    cat help.txt | less
    echo
    echo "Press any key to return to the main menu."
    read -n 1
}

spin() {
    local pid=$1
    local delay=0.05
    local spinstr='|/-\\'
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf "\r[%c] Please wait... " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    echo -e "\nDone."
}

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
    (sudo getfacl -R -p /lib /lib64 /bin /sbin /srv /home /dev /run /boot /etc /usr /root /proc /sys /tmp | sudo tee "$backup_file" > /dev/null 2>&1) & spin $!

    echo "Backup completed successfully."
    echo "$backup_file" >> "$backup_stack" || { echo "Backup failed! Aborting..."; exit 1; }
    trap "echo; echo 'Operation aborted.'; exit 1" SIGINT SIGTERM

    # Set directory permissions
    set_directory_permissions 755 /lib /lib64 /bin /sbin /srv /home /dev /run /boot /etc "System directories"
    set_directory_permissions 775 /usr "User commands directory"
    set_directory_permissions 750 /root "Root user directory"
    set_directory_permissions 555 /proc /sys "System status directories"
    set_directory_permissions 1777 /tmp "Temporary directory"

    [[ -d "/lost+found" ]] && set_directory_permissions 700 /lost+found "lost+found directory"

    echo "Permissions updated successfully."
}

# Main Script Logic
create_log_dir
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

while true; do
    display_menu
    read -r choice

    case $choice in
        1)  # Change Ownership and Permissions
            echo "Enter the directory path:"
            read -e directory
            validate_directory "$directory"
            confirm_action "Change ownership to $DEFAULT_USER:$DEFAULT_GROUP recursively?" && change_ownership_permissions "$directory"
            ;;
        2)  # Compare Package Permissions
            (compare_package_permissions & spin $!)
            ;;
        3)  # Get Directory ACL
            echo "Enter the directory path:"
            read -e directory
            validate_directory "$directory"
            get_directory_acl "$directory"
            ;;
        4)  # Display Help
            display_help
            ;;
        5)  # Reset Permissions to Defaults
            confirm_action "Create a backup before resetting permissions?" && reset_permissions
            ;;
        6)  # Exit Script
            echo "Exiting..."
            exit 0
            ;;
        *)  # Invalid Choice
            echo "Invalid choice. Please try again."
            ;;
    esac
done
