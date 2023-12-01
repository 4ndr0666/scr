#!/bin/bash
#
# --- // 4ndr0666 Permissions Script:
#                                                 .__
#  ______   ___________  _____   ______      _____|  |__
#  \____ \_/ __ \_  __ \/     \ /  ___/     /  ___/  |  \
#  |  |_> >  ___/|  | \/  Y Y  \\___ \      \___ \|   Y  \
#  |   __/ \___  >__|  |__|_|  /____  > /\ /____  >___|  /
#  |__|        \/            \/     \/  \/      \/     \/


# ---- // AUTO-ESCALATE:
if [ "$(id -u)" -ne 0 ]; then
  sudo "$0" "$@"
  exit $?
fi

# ---- // LOGGING:
log() {
    local message="$1"
    local log_dir="/tmp"
    local log_file="$log_dir/perms.log"

    [ ! -d "$log_dir" ] && sudo mkdir -p "$log_dir" && sudo chmod 700 "$log_dir"
    [ ! -f "$log_file" ] && sudo touch "$log_file" && sudo chmod 600 "$log_file"

    echo "$(date): $message" | sudo tee -a "$log_file" > /dev/null
}

# ---- // CONFIG SETUP:
CONFIG_FILE="$(dirname "$0")/config.cfg"
CONFIGURED=false
DEFAULT_USER=""
DEFAULT_GROUP=""

RECURSIVE_CHANGE=false

# --- // PROCESS_ARGS:
while getopts ":r" opt; do
  case $opt in
    r)
      RECURSIVE_CHANGE=true
      shift # Remove the processed argument
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done


# ---- // LOAD_USER_CONFIG:
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        [ -z "$DEFAULT_USER" ] && CONFIGURED=false
        [ -z "$DEFAULT_GROUP" ] && CONFIGURED=false
    else
        CONFIGURED=false
    fi
}

# ---- // SAVE_USER_CONFIG:
save_config() {
    echo "CONFIGURED=true" > "$CONFIG_FILE"
    echo "DEFAULT_USER=$1" >> "$CONFIG_FILE"
    echo "DEFAULT_GROUP=$2" >> "$CONFIG_FILE"
    sudo chmod 600 "$CONFIG_FILE"
}

# --- // FIRST_RUN_USER_CONFIG:
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

# ---- // BACKUP_STACK:
backup_stack=()

backup_file() {
    local original_file="$1"
    local backup_file
    backup_file="${original_file}.backup_$(date +%s)"
    cp "$original_file" "$backup_file" || { log "Backup failed for $original_file"; return 1; }
    backup_stack+=("$backup_file")
}

# --- // ROLLBACK_STACK:
rollback() {
    for backup in "${backup_stack[@]}"; do
        original="${backup%.backup_*}"
        mv "$backup" "$original" || { log "Rollback failed for $backup"; }
    done
    backup_stack=()
}

# --- // ERROR_HANDLING:
handle_error() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo "Error occurred. Rolling back..."
        rollback
        log "Error occurred with exit code $exit_code. Rolled back changes."
        exit $exit_code
    fi
}

# --- // DIR_VALIDATION:
validate_directory() {
    local directory="$1"
    if [[ ! -d "$directory" ]]; then
        log "Error: Directory '$directory' does not exist."
        echo "Error: Directory '$directory' does not exist."
        exit 1
    fi
}

# --- // CONFIRMATION:
confirm_action() {
    local message="$1"
    echo -n "$message (y/n): "
    read -r confirm
    [[ "$confirm" == "y" || "$confirm" == "Y" ]]
}

# --- // PERMISSIONS_HELPER:
set_directory_permissions() {
    local mode=$1
    shift
    local directories=("$@")
    echo "Setting mode $mode for ${directories[*]}"
    sudo chmod "$mode" "${directories[@]}" || { log "Failed to set directory permissions."; exit 1; }
}

# --- // CHMOD_DOCUMENTATION:
display_help() {
    clear
    echo "Common Permission Modes:"
    echo "----------------------"
    echo "- chmod 751: +rwx for owner, +rx for group, +x for others"
    echo "- chmod 755: +rwx for owner, +rwx for group, +rx for others"
    echo "- chmod 744: +wx for owner, no permissions for group, +r for others"
    echo "- chmod 711: +rwx for owner, no permissions for group, +x for others"
    echo "- chmod 700: +rwx for owner, no permissions for group or others"
    echo "- chmod 640: +rwx for owner, +r for group, no permissions for others"
    echo "- chmod 644: +rw for owner, no permissions for group, +r for others"
    echo "- chmod 777: +rwx for owner, +rwx for group, +rwx for others"
    echo "- chmod 666: +rw for owner, +rw for group, +rw for others"
    echo "- chmod 600: +rw for owner, no permissions for group or others"
    echo "- chmod 400: +r for owner, no permissions for group or others"
    echo ""
    echo "Press any key to return to the main menu."
    read -rn 1
}

# --- // SPINNER:
spin() {
    local pid=$1
    local delay=0.05
    local spinstr='|/-\\'    
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf "\e[1;34m\r[*] \e[1;32mIt will take time..Please wait...  [\e[1;33m%c\e[1;32m]\e[0m  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\e[1;33m[Done]\e[0m\n"
}

# --- // CALL_CONFIG:
load_config
if [[ "$CONFIGURED" != "true" ]]; then
    prompt_config
fi

# --- // SHOW_MENU:
display_menu() {
    local recursive_display=""
    if [ "$RECURSIVE_CHANGE" = true ]; then
        recursive_display=" (R)"
    fi

    printf "1. Chown%s     |    4. Modes\n" "$recursive_display"
    printf "2. Compare   |    5. CompAudit\n"
    printf "3. Getfacl   |    6. Exit\n\n"
    echo -n "$: "
}

# --- // COMMAND_SUMMARY:
print_facl() {
    local target="$1"
    getfacl "$target"
}

# --- // CHANGE_PERMISSIONS:
change_ownership_permissions() {
    local target_directory=${1:-$PWD}
    echo "'1' Ownership, '2' Permissions, '3' Both:"
    read -r change_type

    # Determine the chmod and chown options based on the recursive flag
    local chmod_options=""
    local chown_options=""
    if [ "$RECURSIVE_CHANGE" = true ]; then
        chmod_options="-R"
        chown_options="-R"
    fi

    case $change_type in
        1) sudo chown $chown_options "$DEFAULT_USER:$DEFAULT_GROUP" "$target_directory" ;;
        2) sudo chmod $chmod_options ug+rwx "$target_directory" ;;
        3) 
           sudo chown $chown_options "$DEFAULT_USER:$DEFAULT_GROUP" "$target_directory" 
           sudo chmod $chmod_options ug+rwx "$target_directory"
           ;;
        *) echo "Invalid selection. Operation cancelled." ;;
    esac
    log "Changed ownership and permissions for $target_directory"
    print_facl "$target_directory"
}



# --- // COMPARE_PERMISSIONS:
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

# --- // GETFACL:
get_directory_acl() {
    local directory="$1"
    echo "Getting ACL of the directory..."
    sudo getfacl -R "$directory"
}

# --- // ZSH_COMPAUDIT:
compaudit() {
    echo "Performing CompAudit for Zsh configuration..."
    mapfile -t insecure_items < <(compaudit)
    local total_insecure=${#insecure_items[@]}

    if [[ $total_insecure -eq 0 ]]; then
        echo "No insecure directories or files found."
    else
        echo "Insecure directories/files found:"
        for item in "${insecure_items[@]}"; do
            echo "$item"
        done
        echo "Total insecure items: $total_insecure"
    fi
    log "CompAudit for Zsh completed with $total_insecure insecure items"
}

set -e

# --- // ARGUMENT_VALIDATION:
directory=${1:-$PWD}
if [ -n "$1" ]; then
    # Validate if the path is a directory or a file
    if [ -d "$directory" ]; then
        validate_directory "$directory"
        echo "Dir: $directory/"
    elif [ -f "$directory" ]; then
        # If it's a file, you might want a separate validation function or handle it here
        echo "File: $directory"
    else
        log "Error: '$directory' is not a valid directory or file."
        echo "Error: '$directory' is not a valid directory or file."
        exit 1
    fi
fi

# --- MENU_LOOP:
while true; do
    display_menu
    read -r choice

    case $choice in
        1)
            if [ -z "$1" ]; then
                echo "Enter the directory path:"
                read -re directory
                validate_directory "$directory"
            fi
            
            change_ownership_permissions "$directory"
            ;;
        2)
            echo "Checking package permissions against current permissions..."
            (compare_package_permissions & spin $!)
            ;;
        3)
            if [ -z "$directory" ]; then
                echo "Enter the directory path:"
                read -re directory
                validate_directory "$directory"
            fi

            get_directory_acl "$directory"
            ;;
        4)
            display_help
            ;;
        5)
            compaudit
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
