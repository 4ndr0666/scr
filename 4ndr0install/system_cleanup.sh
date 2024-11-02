#!/usr/bin/env bash

# --- System Cleanup ---

LOG_FILE="/var/log/system_cleanup.log"

# Function to log messages with timestamp
log_message() {
    local message="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"
}

# Function to clean the package cache
clean_package_cache() {
    log_message "Cleaning package cache..."
    sudo pacman -Scc --noconfirm >/dev/null 2>&1
    log_message "Package cache cleaned."
}

# Function to vacuum the journal logs
vacuum_logs() {
    log_message "Vacuuming journal logs..."
    sudo journalctl --vacuum-time=2weeks >/dev/null 2>&1
    log_message "Log vacuum completed."
}

# Function to clean up temporary files
cleanup_temp_files() {
    log_message "Cleaning up temporary files..."
    sudo find /tmp -type f -atime +10 -delete
    log_message "Temporary files cleanup completed."
}

# Main function to run all cleanup tasks
main() {
    clean_package_cache
    vacuum_logs
    cleanup_temp_files
}

# Execute the main function
main
