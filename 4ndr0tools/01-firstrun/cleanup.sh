#!/bin/bash
# shellcheck disable=all

# --- System Cleanup ---

# Function to clean the package cache
clean_package_cache() {
    echo "Cleaning package cache..."
    sudo pacman -Scc --noconfirm
    echo "Package cache cleaned."
}

# Function to vacuum the journal logs
vacuum_logs() {
    echo "Vacuuming journal logs..."
    sudo journalctl --vacuum-time=2weeks
    echo "Log vacuum completed."
}

# Function to clean up temporary files
cleanup_temp_files() {
    echo "Cleaning up temporary files..."
    sudo find /tmp -type f -atime +10 -delete
    echo "Temporary files cleanup completed."
}

# Main function to run all cleanup tasks
main() {
    clean_package_cache
    vacuum_logs
    cleanup_temp_files
}

# Execute the main function
main
