#!/usr/bin/env bash

# PermMaster - Restore Execute Permissions with Interactive Confirmation
# Edited: 2024-04-27
# Desc: A script to retroactively restore execute permissions on executables within a specified directory,
#       with interactive confirmations for each change.

# ========================== // PERMMASTER EXEC RESTORER //

# --- // Colors for Enhanced Readability:
RED=$(tput setaf 1)
GRN=$(tput setaf 2)
CYA=$(tput setaf 6)
YEL=$(tput setaf 3)
NC=$(tput sgr0)        # No Color
BOLD=$(tput bold)
UNDERLINE=$(tput smul)

# --- // Symbols for Status Indicators:
SUCCESS="${GRN}[✓]${NC}"
FAILURE="${RED}[✗]${NC}"
INFO="${CYA}[i]${NC}"
WARNING="${YEL}[!]${NC}"

# --- // Logging Setup:
LOG_FILE="/var/log/perm_master_restorer.log"

log_action() {
    local message="$1"
    local level="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] $message" >> "$LOG_FILE"
}

# --- // Function to Validate Directory Path:
validate_directory() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        echo "$dir"
    else
        echo "${FAILURE} Directory '$dir' does not exist."
        log_action "Invalid directory: $dir" "ERROR"
        exit 1
    fi
}

# --- // Function to Determine if a File Should Be Executable:
is_executable() {
    local file="$1"
    # Check for shebang (#!) indicating a script
    if head -n 1 "$file" | grep -q '^#!'; then
        return 0
    fi
    # Check if the file is an ELF binary
    if file "$file" | grep -q 'ELF'; then
        return 0
    fi
    # Additional checks can be added here if necessary
    return 1
}

# --- // Function to Restore Execute Permissions with Confirmation:
restore_execute_permissions() {
    local target_dir="$1"
    
    echo "${INFO} Scanning '$target_dir' for executables..."
    log_action "Scanning '$target_dir' for executables." "INFO"
    
    # Find all regular files within the target directory
    find "$target_dir" -type f -print0 | while IFS= read -r -d '' file; do
        # Determine if the file should be executable
        if is_executable "$file"; then
            # Check if execute permission is missing for user, group, or others
            if [[ ! -x "$file" ]]; then
                # Display file details
                echo ""
                echo "${INFO} File: $file"
                echo -n "Current Permissions: "
                ls -l "$file" | awk '{print $1}'
                echo -n "Set execute permission? [y/N]: "
                
                # Read user input for confirmation
                read -r choice
                case "$choice" in
                    [Yy]* )
                        chmod +x "$file" && {
                            echo "${SUCCESS} Execute permission set on '$file'."
                            log_action "Set execute permission on '$file'." "INFO"
                        } || {
                            echo "${FAILURE} Failed to set execute permission on '$file'."
                            log_action "Failed to set execute permission on '$file'." "ERROR"
                        }
                        ;;
                    * )
                        echo "${WARNING} Skipped '$file'."
                        log_action "Skipped setting execute permission on '$file'." "WARNING"
                        ;;
                esac
            fi
        fi
    done
    
    echo ""
    echo "${SUCCESS} Execute permissions restoration process completed."
    log_action "Execute permissions restoration completed for '$target_dir'." "INFO"
}

# --- // Main Execution Flow:

# Ensure the script is run as root
if [[ "$(id -u)" -ne 0 ]]; then
    echo "${FAILURE} This script must be run as root. Attempting to escalate privileges..."
    exec sudo "$0" "$@"
fi

# Define the target directory
TARGET_DIR="/home/andro/.config"

# Validate the target directory
TARGET_DIR=$(validate_directory "$TARGET_DIR")

# Start the restoration process
restore_execute_permissions "$TARGET_DIR"
