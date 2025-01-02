#!/bin/bash

# Define GnuPG directory path and log file location
GNUPG_DIR="/home/andro/.gnupg"
LOG_FILE="$HOME/gnupg_permissions.log"

# Ensure the script is not run as root
if [ "$(id -u)" -eq 0 ]; then
    echo "This script should not be run as root. Please run as your normal user."
    exit 1
fi

# Initialize or clear the log file
> "$LOG_FILE"

# Function to append messages to a log file
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Check if GNUPG_DIR exists
if [ ! -d "$GNUPG_DIR" ]; then
    echo "GnuPG directory $GNUPG_DIR does not exist."
    log "GnuPG directory $GNUPG_DIR does not exist. No actions were taken."
    exit 1
fi

# Ask for backup
read -p "Create a backup of the GnuPG directory before proceeding? (y/n): " backup_choice
if [ "$backup_choice" = "y" ]; then
    if cp -r "$GNUPG_DIR" "${GNUPG_DIR}_backup_$(date '+%Y%m%d_%H%M%S')"; then
        echo "Backup created successfully."
        log "Backup of ${GNUPG_DIR} created."
    else
        echo "Backup creation failed. Please check manually."
        log "Backup creation failed."
        exit 1
    fi
fi

# Interactive mode for user confirmation before making changes
read -p "Do you want to proceed with fixing GnuPG permissions? (y/n): " choice
if [ "$choice" != "y" ]; then
    echo "Exiting script without making any changes."
    exit 0
fi

# Function to change ownership and permissions with error handling
change_perms() {
    local cmd=$1
    local target=$2
    local msg_success=$3
    local msg_fail=$4

    if $cmd; then
        echo "$msg_success"
        log "$msg_success"
    else
        echo "$msg_fail"
        log "$msg_fail"
        exit 1
    fi
}

# Changing ownership
change_perms "chown -R $(whoami):$(whoami) $GNUPG_DIR" \
             "$GNUPG_DIR" \
             "Changed ownership of $GNUPG_DIR to $(whoami)" \
             "Failed to change ownership of $GNUPG_DIR."

# Fixing directory permissions
echo "Setting correct directory permissions..."
if find "${GNUPG_DIR}" -type d -exec chmod 700 {} \; ; then
    log "Set correct directory permissions for ${GNUPG_DIR}"
else
    echo "Failed to set directory permissions for ${GNUPG_DIR}."
    log "Failed to set directory permissions for ${GNUPG_DIR}."
    exit 1
fi

# Fixing file permissions
echo "Setting correct file permissions..."
if find "${GNUPG_DIR}" -type f -exec chmod 600 {} \; ; then
    log "Set correct file permissions for ${GNUPG_DIR}"
else
    echo "Failed to set file permissions for ${GNUPG_DIR}."
    log "Failed to set file permissions for ${GNUPG_DIR}."
    exit 1
fi

# Function to verify that permissions and ownership have been correctly applied
verify_permissions() {
    # Check for any directories not set to 700
    local dir_perms_correct=$(find "${GNUPG_DIR}" -type d ! -perm 700 | wc -l)
    # Check for any files not set to 600
    local file_perms_correct=$(find "${GNUPG_DIR}" -type f ! -perm 600 | wc -l)
    
    if [ "$dir_perms_correct" -eq 0 ] && [ "$file_perms_correct" -eq 0 ]; then
        echo "Permissions successfully applied."
        log "Permissions and ownership verification passed."
    else
        echo "Permissions verification failed. Please check manually."
        log "Permissions and ownership verification failed."
    fi
}

# Execute the verification function after making changes
verify_permissions

echo "GnuPG permissions fixed."
log "GnuPG permissions fixed successfully."


