#!/usr/bin/env bash
# File: system_health_check.sh
# Date: 12-15-2024
# Author: 4ndr0666
# Edited: 12-2-24

# --- // System Health Check Script ---

# --- // Logging:
LOG_FILE="${XDG_DATA_HOME}/logs/system_health_check.log"
mkdir -p "$(dirname "$LOG_FILE")"

log_message() {
    local message="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"
}

# Function to check the filesystem for errors
check_filesystem() {
    log_message "Checking filesystem integrity..."
    sudo fsck -Af -M >/dev/null 2>&1 || {
        log_message "Failed to check filesystem integrity."
    }
    log_message "Filesystem check completed."
}

# Function to check for failed systemd services
check_systemd_services() {
    log_message "Checking for failed systemd services..."
    local failed_services
    failed_services=$(systemctl --failed --no-legend)
    if [ -n "$failed_services" ]; then
        log_message "Failed services detected:"
        echo "$failed_services" | tee -a "$LOG_FILE"
    else
        log_message "No failed services."
    fi
}

# Function to check for critical log messages
check_logs() {
    log_message "Checking for critical logs..."
    local critical_logs
    critical_logs=$(journalctl -p 0..3 -xb --no-pager)
    if [ -n "$critical_logs" ]; then
        log_message "Critical logs found:"
        echo "$critical_logs" | tee -a "$LOG_FILE"
    else
        log_message "No critical logs."
    fi
}

# Function to display summary to the user
display_summary() {
    whiptail --textbox "$LOG_FILE" 20 70
}

# Main function to run all checks
main() {
    log_message "Starting system health check..."

    check_filesystem
    check_systemd_services
    check_logs
    display_summary

    log_message "System health check completed."
}

# Execute the main function
main
