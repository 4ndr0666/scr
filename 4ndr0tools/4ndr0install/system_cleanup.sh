#!/usr/bin/env bash
# File: system_cleanup.sh
# Date: 12-15-2024
# Author: 4ndr0666

# --- // System Cleanup Script ---

# --- // Logging:
LOG_FILE="${XDG_DATA_HOME}/logs/system_cleanup.log"
mkdir -p "$(dirname "$LOG_FILE")"

exec > >(tee -a "$LOG_FILE") 2>&1

log_message() {
    local message="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $message"
}

# Ensure the script is run with root privileges
if [ "$(id -u)" -ne 0 ]; then
    log_message "Please run as root."
    exit 1
fi

# Function to clean the package cache
clean_package_cache() {
    log_message "Cleaning package cache..."
    pacman -Scc --noconfirm >/dev/null 2>&1 || {
        log_message "Failed to clean package cache."
    }
    log_message "Package cache cleaned."
}

# Function to vacuum the journal logs
vacuum_logs() {
    log_message "Vacuuming journal logs..."
    journalctl --vacuum-time=2weeks >/dev/null 2>&1 || {
        log_message "Failed to vacuum journal logs."
    }
    log_message "Journal logs vacuumed."
}

# Function to clean up temporary files
cleanup_temp_files() {
    log_message "Cleaning up temporary files..."
    find /tmp -type f -atime +10 -delete >/dev/null 2>&1 || {
        log_message "Failed to clean temporary files."
    }
    log_message "Temporary files cleanup completed."
}

# Function to remove orphaned packages
remove_orphans() {
    log_message "Removing orphaned packages..."
    pacman -Qtdq | pacman -Rns --noconfirm - || {
        log_message "Failed to remove orphaned packages or no orphans found."
    }
    log_message "Orphaned packages removed."
}

# Function to remove unused dependencies
remove_unused_dependencies() {
    log_message "Removing unused dependencies..."
    pacman -Qtdq | pacman -Rns --noconfirm - || {
        log_message "Failed to remove unused dependencies or no unused dependencies found."
    }
    log_message "Unused dependencies removed."
}

# Function to clean the thumbnail cache
clean_thumbnail_cache() {
    log_message "Cleaning thumbnail cache..."
    rm -rf "$XDG_CACHE_HOME/thumbnails/"* || {
        log_message "Failed to clean thumbnail cache."
    }
    log_message "Thumbnail cache cleaned."
}

# Function to clear user caches
clear_user_caches() {
    log_message "Clearing user caches..."
    rm -rf "$XDG_CACHE_HOME/"* || {
        log_message "Failed to clear user caches."
    }
    log_message "User caches cleared."
}

# Main function to run all cleanup tasks
main() {
    log_message "Starting system cleanup..."

    clean_package_cache
    vacuum_logs
    cleanup_temp_files
    remove_orphans
    remove_unused_dependencies
    clean_thumbnail_cache
    clear_user_caches

    log_message "System cleanup completed successfully."
    whiptail --title "System Cleanup" --msgbox "System cleanup completed successfully." 8 60
}

# Execute main function
main
