#!/bin/bash

# Enhanced permissions management script
# Includes safety checks, user confirmation, and logging

log_file="/var/log/permission_changes.log"

# Function to display verbose help and usage instructions
show_help() {
    echo "Usage: $(basename $0) [option] [directory]"
    echo "Enhanced permissions management for files and directories."
    echo
    echo "Options:"
    echo "  -a         Apply default permissions (files: 0600, directories: 0700)"
    echo "  -d         Apply directory permissions (0700)"
    echo "  -f         Apply file permissions (0600)"
    echo "  --chmod=   Apply custom chmod mode (e.g., --chmod=755)"
    echo "  --reset    Reset to factory settings for standard files and directories"
    echo "  -h         Display this help and exit"
    echo
    echo "Examples:"
    echo "  $(basename $0) -a ./project   # Apply default permissions recursively to 'project'"
    echo "  $(basename $0) --chmod=644 ./file.txt   # Apply custom permissions to 'file.txt'"
    echo "  $(basename $0) --reset       # Reset permissions to factory settings"
}

# Log actions to a file
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$log_file"
}

# Reset permissions to factory settings with confirmation and detailed logging
reset_to_factory_settings() {
    echo "Warning: This will reset permissions for system directories and files."
    read -p "Are you sure you want to continue? (y/n) " response
    if [[ $response =~ ^[Yy]$ ]]; then
        log_action "Starting reset to factory settings."
        
        # Directories
        if chmod 755 /bin /etc /lib /opt /sbin /usr /var; then
            log_action "System directories permissions set to 755."
        else
            log_action "Error setting permissions for system directories."
            return 1
        fi

        # Home directories
        if chmod 700 /home/*; then
            log_action "Home directories permissions set to 700."
        else
            log_action "Error setting permissions for home directories."
            return 1
        fi

        # Configuration files
        if chmod 644 /etc/*; then
            log_action "Configuration files permissions set to 644."
        else
            log_action "Error setting permissions for configuration files."
            return 1
        fi

        echo "Permissions have been reset. Please review the log at $log_file."
    else
        echo "Reset aborted by user."
    fi
}

# Auto-escalate to root if not already running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Attempting to escalate privileges..."
    sudo "$0" "$@"
    exit $?
fi

opt=${1:-'-h'}
dir=${2:-'.'}

# Process options
case "$opt" in
    -a)
        find "$dir" -type d -exec chmod 0700 "{}" \; -o -type f -exec chmod 0600 "{}" \;
        log_action "Applied default permissions to $dir"
        ;;
    -d)
        find "$dir" -type d -exec chmod 0700 "{}" \;
        log_action "Applied directory permissions to $dir"
        ;;
    -f)
        find "$dir" -type f -exec chmod 0600 "{}" \;
        log_action "Applied file permissions to $dir"
        ;;
    --chmod=*)
        custom_mode="${opt#*=}"
        find "$dir" -exec chmod "$custom_mode" "{}" \;
        log_action "Applied custom mode $custom_mode to $dir"
        ;;
    --reset)
        reset_to_factory_settings
        ;;
    -h|*)
        show_help
        ;;
esac


