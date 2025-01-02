#!/bin/bash
#
# --- // 4ndr0666 Permissions Script:
#                                                 .__
#  ______   ___________  _____   ______      _____|  |__
#  \____ \_/ __ \_  __ \/     \ /  ___/     /  ___/  |  \
#  |  |_> >  ___/|  | \/  Y Y  \\___ \      \___ \|   Y  \
#  |   __/ \___  >__|  |__|_|  /____  > /\ /____  >___|  /
#  |__|        \/            \/     \/  \/      \/     \/

# Uncomment the below line only if you need strict error handling
# set -euo pipefail

# ---- // AUTO-ESCALATE:
if [ "$(id -u)" -ne 0 ]; then
    sudo "$0" "$@"
    exit $?
fi

# Define a dictionary (associative array) for menu options
declare -A menu_map=(
    ["1"]="Change Ownership/Permissions"
    ["2"]="Compare Package Permissions"
    ["3"]="Get Directory ACL"
    ["4"]="Help"
    ["5"]="CompAudit"
    ["6"]="Exit"
)

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
CONFIG_FILE="/etc/perms_config.cfg"
DEFAULT_USER=""
DEFAULT_GROUP=""
RECURSIVE_CHANGE=false

# ---- // LOAD CONFIG:
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        [ -z "$DEFAULT_USER" ] || [ -z "$DEFAULT_GROUP" ] && echo "Invalid config file. Please reconfigure." && prompt_config
    else
        prompt_config
    fi
}

# ---- // SAVE CONFIG:
save_config() {
    echo "DEFAULT_USER=$1" | sudo tee "$CONFIG_FILE" > /dev/null
    echo "DEFAULT_GROUP=$2" | sudo tee -a "$CONFIG_FILE" > /dev/null
    sudo chmod 600 "$CONFIG_FILE"
    echo "Configuration saved."
}

# --- // PROMPT CONFIGURATION:
prompt_config() {
    echo "First run configuration:"
    read -rp "Enter default user: " user
    read -rp "Enter default group: " group
    save_config "$user" "$group"
    echo "Please rerun the script."
    exit 0
}

# ---- // BACKUP HANDLING (IDEMPOTENCY):
backup_stack=()

backup_file() {
    local original_file="$1"
    local backup_file="${original_file}.backup_$(date +%s)"
    cp "$original_file" "$backup_file" || { log "Backup failed for $original_file"; return 1; }
    backup_stack+=("$backup_file")
}

rollback() {
    for backup in "${backup_stack[@]}"; do
        local original="${backup%.backup_*}"
        mv "$backup" "$original" || { log "Rollback failed for $backup"; }
    done
    backup_stack=()
}

# ---- // VALIDATE DIRECTORY:
validate_directory() {
    local directory="$1"
    if [[ ! -d "$directory" ]]; then
        log "Error: Directory '$directory' does not exist."
        echo "Error: Directory '$directory' does not exist."
        exit 1
    fi
}

# ---- // CONFIRMATION:
confirm_action() {
    local message="$1"
    read -rp "$message (y/n): " confirm
    [[ "$confirm" == "y" || "$confirm" == "Y" ]]
}

# ---- // PRINT CURRENT DIRECTORY PERMISSIONS:
print_current_directory_permissions() {
    local target="${1:-$PWD}"
    local owner=$(stat -c '%U' "$target")
    local group=$(stat -c '%G' "$target")
    
    # Set text color to cyan
    tput setaf 6
    
    echo "# dir: $target"
    echo "# owner: $owner"
    echo "# group: $group"
    
    getfacl --absolute-names "$target" 2>/dev/null | grep -E 'user::|group::|other::'
    
    # Reset text color
    tput sgr0
    
    echo
}

# ---- // CHANGE OWNERSHIP AND PERMISSIONS:
change_ownership_permissions() {
    local target_directory=${1:-$PWD}
    echo "'1' Ownership, '2' Permissions, '3' Both:"
    read -r change_type

    local chmod_options=""
    local chown_options=""
    [ "$RECURSIVE_CHANGE" = true ] && chmod_options="-R" && chown_options="-R"

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

# ---- // COMPARE PACKAGE PERMISSIONS:
compare_package_permissions() {
    echo "Checking package permissions against current permissions..."
    sudo pacman -Qlq | while read -r file; do
        [ -e "$file" ] && [[ "$(stat -c "%a" "$file")" != "$(sudo pacman -Qkk "$file" | awk '{print $2}')" ]] && echo "Mismatch: $file"
    done
}

# ---- // GET DIRECTORY ACL:
get_directory_acl() {
    local directory="$1"
    echo "Getting ACL of the directory..."
    sudo getfacl -R "$directory"
}

# ---- // COMPAUDIT:
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

# ---- // DISPLAY HELP:
display_help() {
    clear

    # Check if terminal supports colors
    if [[ -t 1 ]]; then
        ncolors=$(tput colors)
        if [[ -n "$ncolors" && "$ncolors" -ge 8 ]]; then
            bold=$(tput bold)
            underline=$(tput smul)
            reset=$(tput sgr0)
            blue=$(tput setaf 4)
            yellow=$(tput setaf 3)
            green=$(tput setaf 2)
            magenta=$(tput setaf 5)
        fi
    fi

    echo -e "${blue}# --- // CHMOD_INDEX // ========${reset}"
    echo ""

    echo -e "${yellow}DEFAULT SUDOERS:${reset}"
    echo "  chown -c root:root /etc/sudoers"
    echo "  chmod -c 0440 /etc/sudoers"
    echo ""
    
    echo -e "${yellow}COMMON PERMISSION SETTINGS:${reset}"
    
    printf "%-6s %-20s %-50s\n" "CHMOD" "SYMBOLIC" "DESCRIPTION"
    printf "%-6s %-20s %-50s\n" "-----" "--------" "-----------"
    printf "%-6s %-20s %-50s\n" "400" "r--------" "Read-only for owner"
    printf "%-6s %-20s %-50s\n" "600" "rw-------" "Read and write for owner"
    printf "%-6s %-20s %-50s\n" "644" "rw-r--r--" "Owner read/write; others read"
    printf "%-6s %-20s %-50s\n" "700" "rwx------" "Full permissions for owner"
    printf "%-6s %-20s %-50s\n" "755" "rwxr-xr-x" "Owner full; others read/execute"
    printf "%-6s %-20s %-50s\n" "775" "rwxrwxr-x" "Owner & group full; others read/execute"
    printf "%-6s %-20s %-50s\n" "777" "rwxrwxrwx" "All users have full permissions"
    printf "%-6s %-20s %-50s\n" "440" "r--r--r--" "Read-only for owner and group"
    printf "%-6s %-20s %-50s\n" "550" "r-xr-x---" "Read/execute for owner and group"
    printf "%-6s %-20s %-50s\n" "750" "rwxr-x---" "Full for owner; read/execute for group"
    printf "%-6s %-20s %-50s\n" "664" "rw-rw-r--" "Read/write for owner and group; read for others"
    printf "%-6s %-20s %-50s\n" "666" "rw-rw-rw-" "Read/write for everyone"
    printf "%-6s %-20s %-50s\n" "744" "rwxr--r--" "Owner read/write/execute; others read"
    printf "%-6s %-20s %-50s\n" "711" "rwx--x--x" "Owner full; others execute only"
    echo ""

    echo -e "${yellow}SPECIAL PERMISSION BITS:${reset}"
    printf "%-6s %-20s %-50s\n" "BIT" "SYMBOLIC" "DESCRIPTION"
    printf "%-6s %-20s %-50s\n" "----" "--------" "-----------"
    printf "%-6s %-20s %-50s\n" "4xxx" "Setuid" "Executes with file owner's permissions"
    printf "%-6s %-20s %-50s\n" "2xxx" "Setgid" "Executes with group's permissions; new files inherit group ID"
    printf "%-6s %-20s %-50s\n" "1xxx" "Sticky Bit" "Only owner/root can delete/modify within directory"
    echo ""

    echo -e "${yellow}DEFAULT PERMISSIONS FOR COMMON SYSTEM FILES AND DIRECTORIES:${reset}"
    printf "%-30s %-10s %-10s %-10s %-10s\n" "FILE/DIRECTORY" "OWNER" "GROUP" "CHMOD" "DESCRIPTION"
    printf "%-30s %-10s %-10s %-10s %-10s\n" "--------------" "-----" "-----" "-----" "-----------"
    printf "%-30s %-10s %-10s %-10s %-10s\n" "/etc/sudoers" "root" "root" "0440" "Sudo privileges config"
    printf "%-30s %-10s %-10s %-10s %-10s\n" "/etc/passwd" "root" "root" "0644" "User account info"
    printf "%-30s %-10s %-10s %-10s %-10s\n" "/etc/shadow" "root" "shadow" "0640" "Secure passwords"
    printf "%-30s %-10s %-10s %-10s %-10s\n" "/etc/ssh/ssh_config" "root" "root" "0644" "SSH client config"
    printf "%-30s %-10s %-10s %-10s %-10s\n" "~/.ssh/id_rsa" "user" "user" "0600" "Private SSH key"
    printf "%-30s %-10s %-10s %-10s %-10s\n" "~/.ssh/id_rsa.pub" "user" "user" "0644" "Public SSH key"
    printf "%-30s %-10s %-10s %-10s %-10s\n" "~/.gnupg/" "user" "user" "0700" "GnuPG config and keys"
    printf "%-30s %-10s %-10s %-10s %-10s\n" "/usr/bin/" "root" "root" "0755" "Executable binaries"
    printf "%-30s %-10s %-10s %-10s %-10s\n" "/var/www/" "root" "www-data" "0775" "Web server files"
    echo ""

    echo -e "${yellow}TIPS FOR MANAGING PERMISSIONS:${reset}"
    echo " 1. ${bold}Least Privilege Principle${reset}: Grant the minimum permissions necessary for functionality."
    echo " 2. ${bold}Regular Audits${reset}: Periodically check permissions using tools like \`ls -l\` or \`stat\`."
    echo " 3. ${bold}Use Groups Effectively${reset}: Manage collaborative access by assigning users to appropriate groups."
    echo " 4. ${bold}Automate with Scripts${reset}: Use your functions and aliases to enforce consistent permission settings."
    echo " 5. ${bold}Backup Before Changes${reset}: Always backup important configurations before modifying permissions."
    echo ""

    echo -e "${blue}Press any key to return to the main menu.${reset}"
    read -rn 1
}

# ---- // SPINNER:
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

# ---- // MAIN SCRIPT LOGIC:
load_config

# Process recursive flag
while getopts ":rRh" opt; do
  case $opt in
    r|R)
      RECURSIVE_CHANGE=true
      shift # Remove the processed argument
      ;;
    h)
      display_help
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      display_help
      exit 1
      ;;
  esac
done

# Validate and set directory argument
directory=${1:-$PWD}
if [ -n "$1" ]; then
    if [ -d "$directory" ]; then
        validate_directory "$directory"
        echo "Directory: $directory/"
    elif [ -f "$directory" ]; then
        echo "File: $directory"
    else
        log "Error: '$directory' is not a valid directory or file."
        echo "Error: '$directory' is not a valid directory or file."
        exit 1
    fi
fi

# Menu loop with Recursive mode indicator and PWD permissions display
while true; do
    print_current_directory_permissions "$directory"

    echo "Please choose an option:"
    for key in "${!menu_map[@]}"; do
        # Display the number and (R) indicator in cyan
        tput setaf 6
        echo -n "$key)"
        if [ "$RECURSIVE_CHANGE" = true ]; then
            echo -n " (R)"
        fi
        # Reset text color and display the menu option description
        tput sgr0
        echo " ${menu_map[$key]}"
    done

    read -rp "Select an option: " choice

    if [ -z "$directory" ]; then
        echo "Enter the directory path:"
        read -re directory
        validate_directory "$directory"
    fi

    case $choice in
        1)
            change_ownership_permissions "$directory"
            ;;
        2)
            echo "Checking package permissions against current permissions..."
            (compare_package_permissions & spin $!)
            ;;
        3)
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
