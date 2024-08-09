#!/bin/bash

# --- System Health Check ---

# Function to check the filesystem for errors
check_filesystem() {
    echo "Checking filesystem integrity..."
    sudo fsck -Af -M
    echo "Filesystem check completed."
}

# Function to check for failed systemd services
check_systemd_services() {
    echo "Checking systemd services..."
    sudo systemctl --failed
    echo "Systemd services check completed."
}

# Function to check for critical log messages
check_logs() {
    echo "Checking for critical logs..."
    sudo journalctl -p 3 -xb
    echo "Log check completed."
}

# Main function to run all checks
main() {
    check_filesystem
    check_systemd_services
    check_logs
}

# Execute the main function
main
