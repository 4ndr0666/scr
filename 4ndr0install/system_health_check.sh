#!/usr/bin/env bash

# --- System Health Check ---

LOG_FILE="/var/log/system_health_check.log"

# Function to log messages with timestamp
log_message() {
    local message="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"
}

# Function to check the filesystem for errors
check_filesystem() {
    log_message "Checking filesystem integrity..."
    sudo fsck -Af -M >/dev/null 2>&1
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
    check_filesystem
    check_systemd_services
    check_logs
    display_summary
}

# Execute the main function
main
