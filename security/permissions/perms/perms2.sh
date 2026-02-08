#!/bin/bash
#
# --- // 4ndr0666 Permissions Script:
#                                                 .__
#  ______   ___________  _____   ______      _____|  |__
#  \____ \_/ __ \_  __ \/     \ /  ___/     /  ___/  |  \
#  |  |_> >  ___/|  | \/  Y Y  \\___ \      \___ \|   Y  \
#  |   __/ \___  >__|  |__|_|  /____  > /\ /____  >___|  /
#  |__|        \/            \/     \/  \/      \/     \/

# --- // Strict Error Handling:
# Exit immediately if a command exits with a non-zero status.
# Treat unset variables as an error.
# The return value of a pipeline is the status of the last command to exit with a non-zero status,
# or zero if all commands exit successfully.
set -euo pipefail

# ---- // AUTO-ESCALATE:
# Check if the script is running as root. If not, re-execute with sudo.
if [ "$(id -u)" -ne 0 ]; then
    echo "This script requires root privileges. Attempting to re-run with sudo..."
    exec sudo "$0" "$@" # Use exec to replace the current process
    # If exec fails, the script will continue here (unlikely for sudo)
    echo "Failed to escalate privileges. Exiting." >&2
    exit 1
fi

# Define a dictionary (associative array) for menu options
declare -A menu_map=(
    ["1"]="Change Ownership/Permissions"
    ["2"]="Compare Package Permissions"
    ["3"]="Get Directory ACL"
    ["4"]="Help"
    ["5"]="CompAudit (Zsh)"
    ["6"]="Exit"
)

# ---- // LOGGING:
# Logs messages to a file and optionally to stdout.
# This function no longer uses 'sudo' as the script is expected to be run as root.
log() {
    local message="$1"
    local log_dir="/tmp"
    local log_file="$log_dir/perms.log"

    # Ensure log directory exists and has correct permissions
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir" || { echo "Error: Could not create log directory '$log_dir'. Logging disabled." >&2; return 1; }
        chmod 700 "$log_dir" || { echo "Warning: Could not set permissions on log directory '$log_dir'." >&2; }
    fi

    # Ensure log file exists and has correct permissions
    if [[ ! -f "$log_file" ]]; then
        touch "$log_file" || { echo "Error: Could not create log file '$log_file'. Logging disabled." >&2; return 1; }
        chmod 600 "$log_file" || { echo "Warning: Could not set permissions on log file '$log_file'." >&2; }
    fi

    # Write message to log file and suppress stdout from tee
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $message" | tee -a "$log_file" > /dev/null || { echo "Warning: Failed to write to log file '$log_file'." >&2; }
}

# ---- // CONFIG SETUP:
CONFIG_FILE="/etc/perms_config.cfg"
DEFAULT_USER=""
DEFAULT_GROUP=""
RECURSIVE_CHANGE=false # Global flag for recursive operations

# ---- // HELPER: Check if a command exists
check_command() {
    command -v "$1" >/dev/null 2>&1
}

# ---- // LOAD CONFIG:
# Safely loads configuration from CONFIG_FILE.
# This function parses the file line by line to prevent arbitrary code execution
# that could occur if 'source' were used on a compromised config file.
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        local user_found=""
        local group_found=""
        log "Loading configuration from $CONFIG_FILE"
        while IFS='=' read -r key value || [[ -n "$key" ]]; do
            # Remove leading/trailing whitespace from key and value
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)
            case "$key" in
                DEFAULT_USER) DEFAULT_USER="$value"; user_found="true" ;;
                DEFAULT_GROUP) DEFAULT_GROUP="$value"; group_found="true" ;;
                # Ignore unknown keys for future compatibility
                *) ;;
            esac
        done < "$CONFIG_FILE"

        # Check if required variables are set and not empty
        if [[ -z "$user_found" || -z "$group_found" || -z "$DEFAULT_USER" || -z "$DEFAULT_GROUP" ]]; then
            echo "Invalid or incomplete configuration file. Please reconfigure."
            prompt_config
        fi
    else
        echo "Configuration file not found. Running first-time setup."
        prompt_config
    fi
}

# ---- // SAVE CONFIG:
# Saves configuration to CONFIG_FILE.
# This function no longer uses 'sudo' as the script is expected to be run as root.
save_config() {
    local user="$1"
    local group="$2"
    echo "DEFAULT_USER=$user" | tee "$CONFIG_FILE" > /dev/null
    echo "DEFAULT_GROUP=$group" | tee -a "$CONFIG_FILE" > /dev/null
    chmod 600 "$CONFIG_FILE" # Set secure permissions for the config file
    log "Configuration saved: DEFAULT_USER=$user, DEFAULT_GROUP=$group"
    echo "Configuration saved."
}

# --- // PROMPT CONFIGURATION:
# Prompts the user for default user and group, validating their existence.
prompt_config() {
    echo "First run configuration:"
    local user group

    # Loop until a valid user is entered
    while true; do
        read -rp "Enter default user: " user
        if id -u "$user" >/dev/null 2>&1; then
            break
        else
            echo "Error: User '$user' does not exist. Please enter a valid user."
        fi
    done

    # Loop until a valid group is entered
    while true; do
        read -rp "Enter default group: " group
        if id -g "$group" >/dev/null 2>&1; then
            break
        else
            echo "Error: Group '$group' does not exist. Please enter a valid group."
        fi
    done

    save_config "$user" "$group"
    echo "Please rerun the script to apply changes."
    exit 0 # Exit after configuration to ensure the new config is loaded cleanly
}

# ---- // BACKUP HANDLING (IDEMPOTENCY):
# A stack to keep track of created backups for potential rollback.
backup_stack=()

# Backs up a single file. Not suitable for recursive directory backups.
# This function no longer uses 'sudo'.
backup_file() {
    local original_file="$1"
    # Create a unique backup file name
    local backup_file="${original_file}.backup_$(date +%s)"

    if [[ ! -e "$original_file" ]]; then
        log "Warning: Cannot backup '$original_file', it does not exist."
        return 0 # Not an error if file doesn't exist for backup
    fi

    cp -p "$original_file" "$backup_file" || { log "Backup failed for $original_file"; echo "Error: Failed to create backup for '$original_file'."; return 1; }
    backup_stack+=("$backup_file")
    log "Backed up '$original_file' to '$backup_file'"
    return 0
}

# Rolls back changes by restoring files from the backup stack.
# This function no longer uses 'sudo'.
rollback() {
    if [[ ${#backup_stack[@]} -eq 0 ]]; then
        echo "No backups to roll back."
        return 0
    fi

    echo "Attempting to roll back changes..."
    for backup in "${backup_stack[@]}"; do
        local original="${backup%.backup_*}" # Extract original file name
        if [[ -f "$backup" ]]; then
            mv "$backup" "$original" || { log "Rollback failed for $backup to $original"; echo "Error: Failed to restore '$original' from '$backup'."; }
            log "Restored '$original' from '$backup'"
        else
            log "Warning: Backup file '$backup' not found during rollback."
        fi
    done
    backup_stack=() # Clear the stack after rollback attempt
    echo "Rollback attempt completed."
}

# ---- // VALIDATE PATH:
# Checks if a given path (file or directory) exists.
# Returns 0 for success (path exists), 1 for failure (path does not exist).
validate_path() {
    local path="$1"
    if [[ ! -e "$path" ]]; then
        log "Error: Path '$path' does not exist."
        echo "Error: Path '$path' does not exist."
        return 1
    fi
    return 0
}

# ---- // CONFIRMATION:
# Prompts the user for confirmation.
confirm_action() {
    local message="$1"
    read -rp "$message (y/n): " confirm
    [[ "$confirm" == "y" || "$confirm" == "Y" ]]
}

# ---- // PRINT CURRENT DIRECTORY/FILE PERMISSIONS:
# Displays ownership, group, and ACLs for a given path.
# This function no longer uses 'sudo'.
print_current_permissions() {
    local target="${1:-$PWD}"

    if ! validate_path "$target"; then
        echo "Cannot display permissions for non-existent path: '$target'"
        return 1
    fi

    local owner=$(stat -c '%U' "$target")
    local group=$(stat -c '%G' "$target")
    local permissions=$(stat -c '%a' "$target") # Octal permissions

    # Set text color to cyan
    tput setaf 6 || true # '|| true' to prevent set -e from exiting if tput fails

    echo "# Path: $target"
    echo "# Owner: $owner"
    echo "# Group: $group"
    echo "# Permissions (octal): $permissions"

    # Display ACLs if getfacl is available
    if check_command "getfacl"; then
        echo "# ACLs:"
        getfacl --absolute-names "$target" 2>/dev/null | grep -E 'user::|group::|other::|mask::|default:' || true
    else
        echo "# getfacl command not found. Cannot display ACLs."
    fi

    # Reset text color
    tput sgr0 || true

    echo
    return 0
}

# ---- // CHANGE OWNERSHIP AND PERMISSIONS:
# Allows changing ownership, permissions, or both for a given path.
# This function no longer uses 'sudo'.
change_ownership_permissions() {
    local target_path="$1"
    local change_type
    local new_mode
    local chmod_options=""
    local chown_options=""

    if [[ "$RECURSIVE_CHANGE" = true ]]; then
        chmod_options="-R"
        chown_options="-R"
        echo "Recursive mode is ON. Changes will apply to contents of '$target_path'."
    else
        echo "Recursive mode is OFF. Changes will apply only to '$target_path'."
    fi

    echo "Change options for '$target_path':"
    echo "  1) Change Ownership (User:Group)"
    echo "  2) Change Permissions (chmod mode)"
    echo "  3) Change Both"
    read -rp "Select an option (1-3): " change_type

    case "$change_type" in
        1)
            if confirm_action "Are you sure you want to change ownership of '$target_path' to $DEFAULT_USER:$DEFAULT_GROUP $chown_options?"; then
                backup_file "$target_path" || { echo "Operation aborted due to backup failure."; return 1; }
                chown $chown_options "$DEFAULT_USER:$DEFAULT_GROUP" "$target_path" || { log "Failed to change ownership for $target_path"; echo "Error: Failed to change ownership."; rollback; return 1; }
                log "Changed ownership for $target_path to $DEFAULT_USER:$DEFAULT_GROUP"
            else
                echo "Operation cancelled."
            fi
            ;;
        2)
            read -rp "Enter new permissions (e.g., 755, ug+rwx): " new_mode
            if confirm_action "Are you sure you want to change permissions of '$target_path' to $new_mode $chmod_options?"; then
                backup_file "$target_path" || { echo "Operation aborted due to backup failure."; return 1; }
                chmod $chmod_options "$new_mode" "$target_path" || { log "Failed to change permissions for $target_path"; echo "Error: Failed to change permissions."; rollback; return 1; }
                log "Changed permissions for $target_path to $new_mode"
            else
                echo "Operation cancelled."
            fi
            ;;
        3)
            read -rp "Enter new permissions (e.g., 755, ug+rwx): " new_mode
            if confirm_action "Are you sure you want to change ownership to $DEFAULT_USER:$DEFAULT_GROUP and permissions to $new_mode for '$target_path' $chown_options $chmod_options?"; then
                backup_file "$target_path" || { echo "Operation aborted due to backup failure."; return 1; }
                chown $chown_options "$DEFAULT_USER:$DEFAULT_GROUP" "$target_path" || { log "Failed to change ownership for $target_path"; echo "Error: Failed to change ownership."; rollback; return 1; }
                chmod $chmod_options "$new_mode" "$target_path" || { log "Failed to change permissions for $target_path"; echo "Error: Failed to change permissions."; rollback; return 1; }
                log "Changed ownership to $DEFAULT_USER:$DEFAULT_GROUP and permissions to $new_mode for $target_path"
            else
                echo "Operation cancelled."
            fi
            ;;
        *)
            echo "Invalid selection. Operation cancelled."
            return 1
            ;;
    esac
    print_current_permissions "$target_path" # Corrected function call
    return 0
}

# ---- // COMPARE PACKAGE PERMISSIONS:
# Compares installed package file permissions against their expected values.
# This function is specific to Arch Linux (pacman).
# This function no longer uses 'sudo'.
compare_package_permissions() {
    if ! check_command "pacman"; then
        echo "Error: 'pacman' command not found. This feature is for Arch Linux based systems."
        return 1
    fi

    echo "Checking package permissions against current permissions..."
    echo "This may take a while for large installations."
    log "Starting pacman package permission comparison."

    # Get all files owned by pacman and pass them to pacman -Qkk
    # Filter for lines indicating permission mismatches
    # Example output: file /usr/bin/ls (Permissions: 0755 != 0777)
    # Use xargs to pass multiple files to pacman -Qkk for efficiency.
    local mismatches_found=false
    if pacman -Qlq | xargs pacman -Qkk 2>/dev/null | grep -E 'Permissions: .* != ' | \
       sed -E 's/file (.*) \(Permissions: (.*) != (.*)\)/\1 (Expected: \2, Current: \3)/'; then
        mismatches_found=true
    fi

    if [[ "$mismatches_found" = false ]]; then
        echo "No permission mismatches found for installed packages."
    else
        echo "Permission mismatches found. Consider restoring affected files."
    fi
    log "Pacman package permission comparison completed."
    return 0
}

# ---- // GET DIRECTORY ACL:
# Displays ACLs for a given directory, optionally recursively.
# This function no longer uses 'sudo'.
get_directory_acl() {
    local target_path="$1"
    if ! check_command "getfacl"; then
        echo "Error: 'getfacl' command not found. Cannot get ACLs."
        return 1
    fi

    echo "Getting ACL of '$target_path'..."
    if [[ "$RECURSIVE_CHANGE" = true ]]; then
        echo "Recursive mode is ON. Displaying ACLs recursively."
        getfacl -R "$target_path" || { log "Failed to get recursive ACL for $target_path"; echo "Error: Failed to get recursive ACL."; return 1; }
    else
        getfacl "$target_path" || { log "Failed to get ACL for $target_path"; echo "Error: Failed to get ACL."; return 1; }
    fi
    log "Retrieved ACL for $target_path"
    return 0
}

# ---- // COMPAUDIT:
# Runs Zsh's compaudit to check for insecure directories/files.
# This function no longer uses 'sudo'.
compaudit() {
    if ! check_command "zsh"; then
        echo "Error: 'zsh' command not found. CompAudit requires Zsh."
        return 1
    fi

    echo "Performing CompAudit for Zsh configuration..."
    log "Starting CompAudit for Zsh."
    # compaudit is a Zsh builtin, so we need to run it via zsh
    # Redirect stderr to /dev/null to suppress potential zsh startup warnings
    mapfile -t insecure_items < <(zsh -c 'compaudit' 2>/dev/null)
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
    return 0
}

# ---- // DISPLAY HELP:
# Displays a comprehensive help message with chmod index and tips.
display_help() {
    clear

    # Check if terminal supports colors
    local bold="" underline="" reset="" blue="" yellow="" green="" magenta=""
    if [[ -t 1 ]]; then
        local ncolors=$(tput colors)
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
    printf "%-6s %-20s %-50s\n" "777" "rwxrwxrwx" "All users have full permissions (USE WITH CAUTION!)"
    printf "%-6s %-20s %-50s\n" "440" "r--r--r--" "Read-only for owner and group"
    printf "%-6s %-20s %-50s\n" "550" "r-xr-x---" "Read/execute for owner and group"
    printf "%-6s %-20s %-50s\n" "750" "rwxr-x---" "Full for owner; read/execute for group"
    printf "%-6s %-20s %-50s\n" "664" "rw-rw-r--" "Read/write for owner and group; read for others"
    printf "%-6s %-20s %-50s\n" "666" "rw-rw-rw-" "Read/write for everyone (USE WITH CAUTION!)"
    printf "%-6s %-20s %-50s\n" "744" "rwxr--r--" "Owner read/write/execute; others read"
    printf "%-6s %-20s %-50s\n" "711" "rwx--x--x" "Owner full; others execute only"
    echo ""

    echo -e "${yellow}SPECIAL PERMISSION BITS:${reset}"
    printf "%-6s %-20s %-50s\n" "BIT" "SYMBOLIC" "DESCRIPTION"
    printf "%-6s %-20s %-50s\n" "----" "--------" "-----------"
    printf "%-6s %-20s %-50s\n" "4xxx" "Setuid" "Executes with file owner's permissions (for executables)"
    printf "%-6s %-20s %-50s\n" "2xxx" "Setgid" "Executes with group's permissions; new files inherit group ID (for directories)"
    printf "%-6s %-20s %-50s\n" "1xxx" "Sticky Bit" "Only owner/root can delete/modify files within directory (for directories)"
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
# Displays a spinner while a background process runs.
spin() {
    local pid=$1
    local delay=0.05
    local spinstr='|/-\\'
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf "\e[1;34m\r[*] \e[1;32mIt will take time..Please wait...  [\e[1;33m%c\e[1;32m]\e[0m  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep "$delay"
    done
    printf "\e[1;33m[Done]\e[0m\n"
}

# ---- // MAIN SCRIPT LOGIC:
load_config # Load configuration at script start

# Process recursive flag and help flag using getopts
while getopts ":rRh" opt; do
  case "$opt" in
    r|R)
      RECURSIVE_CHANGE=true
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
# Shift positional parameters so that $1 refers to the first non-option argument
shift "$((OPTIND-1))"

# Determine the target path: from argument or current directory
target_path="${1:-$PWD}"

# Validate the initial target path. If invalid, default to PWD.
if ! validate_path "$target_path"; then
    echo "Invalid path provided: '$target_path'. Using current directory as default: '$PWD'"
    target_path="$PWD"
fi

# Menu loop with Recursive mode indicator and PWD permissions display
while true; do
    echo "----------------------------------------------------"
    print_current_permissions "$target_path" # Display permissions of the current target path

    echo "Please choose an option for '$target_path':"
    for key in "${!menu_map[@]}"; do
        # Display the number and (R) indicator in cyan
        tput setaf 6 || true
        echo -n "$key)"
        if [ "$RECURSIVE_CHANGE" = true ]; then
            echo -n " (R)"
        fi
        # Reset text color and display the menu option description
        tput sgr0 || true
        echo " ${menu_map[$key]}"
    done
    echo "----------------------------------------------------"

    read -rp "Select an option: " choice

    # Allow changing the target path within the loop
    if confirm_action "Do you want to change the target path (currently '$target_path')?"; then
        local new_target_path
        read -rp "Enter new target path: " new_target_path
        if validate_path "$new_target_path"; then
            target_path="$new_target_path"
            echo "Target path changed to: '$target_path'"
        else
            echo "Invalid new target path. Keeping current path: '$target_path'"
        fi
    fi

    case "$choice" in
        1)
            change_ownership_permissions "$target_path"
            ;;
        2)
            # Run compare_package_permissions in background with spinner
            (compare_package_permissions & spin $!)
            ;;
        3)
            get_directory_acl "$target_path"
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
    echo # Add a newline for better readability between iterations
done
