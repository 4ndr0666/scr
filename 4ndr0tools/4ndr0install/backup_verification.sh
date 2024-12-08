#!/usr/bin/env bash

# --- Backup Verification ---

LOG_FILE="/var/log/backup_verification.log"

# Function to log messages with timestamp
log_message() {
    local message="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"
}

# Function to verify backup integrity
verify_backup() {
    log_message "Starting backup verification in /var/recover..."
    if [ ! -d "/var/recover" ]; then
        log_message "Directory /var/recover does not exist."
        return 1
    fi

    local found_files=0
    for file in /var/recover/*.tar.gz; do
        if [ -f "$file" ]; then
            found_files=1
            if tar -tzf "$file" >/dev/null 2>&1; then
                log_message "$file is valid."
            else
                log_message "Error: $file is corrupted!"
            fi
        fi
    done

    if [ $found_files -eq 0 ]; then
        log_message "No backup tarballs found in /var/recover."
        return 1
    fi

    log_message "Backup verification completed."
}

# Main function to execute backup verification
main() {
    verify_backup
}

# Execute the main function
main
