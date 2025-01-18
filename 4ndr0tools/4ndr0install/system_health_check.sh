#!/usr/bin/env bash
# File: system_health_check.sh
# Date: 12-15-2024
# Author: 4ndr0666
# Edited: 12-2-24

# --- // System Health Check Script ---

# --- // Environment Variables:
if [ -n "$SUDO_USER" ]; then
    INVOKING_USER="$SUDO_USER"
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    echo "Error: Unable to determine the invoking user's home directory."
    exit 1
fi

export XDG_CONFIG_HOME="$USER_HOME/.config"
export XDG_DATA_HOME="$USER_HOME/.local/share"
export XDG_CACHE_HOME="$USER_HOME/.cache"
export XDG_STATE_HOME="$USER_HOME/.local/state"
export GNUPGHOME="$XDG_DATA_HOME/gnupg"

# --- // Logging:
LOG_FILE="${XDG_DATA_HOME}/logs/system_health_check.log"
mkdir -p "$(dirname "$LOG_FILE")"

exec > >(tee -a "$LOG_FILE") 2>&1

log_message() {
    local message="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $message"
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

# Function to check disk usage
check_disk_usage() {
    log_message "Checking disk usage..."
    df -h | tee -a "$LOG_FILE"
    log_message "Disk usage check completed."
}

# Function to check memory usage
check_memory_usage() {
    log_message "Checking memory usage..."
    free -h | tee -a "$LOG_FILE"
    log_message "Memory usage check completed."
}

# Function to check CPU load
check_cpu_load() {
    log_message "Checking CPU load..."
    uptime | tee -a "$LOG_FILE"
    log_message "CPU load check completed."
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
    check_disk_usage
    check_memory_usage
    check_cpu_load
    display_summary

    log_message "System health check completed."
}

# Execute the main function
main
