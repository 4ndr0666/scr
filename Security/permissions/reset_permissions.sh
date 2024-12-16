#!/bin/bash

# ----------------------------------------- // RESET_PERMISSIONS:
# Script: reset_permissions.sh
# Description: Resets permissions on critical system directories to their default "factory" settings.
# Author: 4ndr0666
# Date: 2024-12-15

# Exit immediately if a command exits with a non-zero status
set -e

# Define a mapping of directories to their correct "factory" permissions
declare -A dir_permissions=(
    ["/boot"]=755
    ["/dev"]=755
    ["/etc"]=755
    ["/home"]=755
    ["/media"]=755
    ["/mnt"]=755
    ["/opt"]=755
    ["/proc"]=555
    ["/root"]=700
    ["/run"]=755
    ["/srv"]=755
    ["/sys"]=555
    ["/tmp"]=1777
    ["/usr"]=755
    ["/var"]=755
    ["/boot/efi"]=755  # Specifically handle /boot/efi
)

# Log file for tracking permission changes
LOG_FILE="/var/log/reset_permissions.log"

# Function to back up current permissions
backup_permissions() {
    local backup_file="/tmp/permissions_backup_$(date +%Y%m%d%H%M%S).txt"
    echo "🔄 Backing up current permissions to $backup_file..." | tee -a "$LOG_FILE"
    local dir_count=0
    for dir in "${!dir_permissions[@]}"; do
        if [[ -d $dir ]]; then
            find "$dir" -exec stat -c "%a %n" {} \; >> "$backup_file" 2>>"$LOG_FILE"
            ((dir_count++))
        fi
    done
    echo "✅ Backup completed for $dir_count directories." | tee -a "$LOG_FILE"
}

# Function to reset directory permissions
reset_dir_permissions() {
    local dry_run=$1
    for dir in "${!dir_permissions[@]}"; do
        if [[ -d $dir ]]; then
            local current_perm
            current_perm=$(stat -c "%a" "$dir" 2>>"$LOG_FILE")
            if [[ "$current_perm" -ne "${dir_permissions[$dir]}" ]]; then
                if [[ "$dry_run" == true ]]; then
                    echo "🟡 Dry Run: chmod ${dir_permissions[$dir]} $dir" | tee -a "$LOG_FILE"
                else
                    if chmod "${dir_permissions[$dir]}" "$dir" 2>>"$LOG_FILE"; then
                        echo "✔️ Permissions set for $dir to ${dir_permissions[$dir]}." | tee -a "$LOG_FILE"
                    else
                        echo "❌ Failed to set permissions for $dir." | tee -a "$LOG_FILE" >&2
                    fi
                fi
            else
                echo "🔍 Permissions for $dir are already correct; skipping." | tee -a "$LOG_FILE"
            fi
        else
            echo "⚠️ Directory $dir does not exist; skipping." | tee -a "$LOG_FILE"
        fi
    done
}

# Function to reset file permissions within directories
reset_file_permissions() {
    local dry_run=$1
    local dir=$2

    if [[ -d "$dir" ]]; then
        if [[ "$dry_run" == true ]]; then
            echo "🟡 Dry Run: find $dir -type d -exec chmod 755 {} \;" | tee -a "$LOG_FILE"
            echo "🟡 Dry Run: find $dir -type f -exec chmod 644 {} \;" | tee -a "$LOG_FILE"
            echo "🟡 Dry Run: find $dir -type f -perm /u+x -exec chmod 755 {} \;" | tee -a "$LOG_FILE"
        else
            find "$dir" -type d -exec chmod 755 {} \; 2>>"$LOG_FILE" && \
            find "$dir" -type f -exec chmod 644 {} \; 2>>"$LOG_FILE" && \
            find "$dir" -type f -perm /u+x -exec chmod 755 {} \; 2>>"$LOG_FILE"
            echo "✔️ Permissions reset for $dir." | tee -a "$LOG_FILE"
        fi
    fi
}

# Function to set permissions for /boot/efi
handle_boot_efi() {
    local dry_run=$1
    local dir="/boot/efi"
    if [[ -d "$dir" ]]; then
        local current_perm
        current_perm=$(stat -c "%a" "$dir" 2>>"$LOG_FILE")
        if [[ "$current_perm" -ne "755" ]]; then
            if [[ "$dry_run" == true ]]; then
                echo "🟡 Dry Run: chmod 755 $dir" | tee -a "$LOG_FILE"
            else
                if chmod 755 "$dir" 2>>"$LOG_FILE"; then
                    echo "✔️ Permissions reset for $dir." | tee -a "$LOG_FILE"
                else
                    echo "❌ Failed to set permissions for $dir. Please check manually." | tee -a "$LOG_FILE" >&2
                fi
            fi
        else
            echo "🔍 Permissions for $dir are already set correctly." | tee -a "$LOG_FILE"
        fi
    fi
}

# Function to display a summary of changes
display_summary() {
    echo "✅ Permissions reset process completed." | tee -a "$LOG_FILE"
}

# Main Execution Flow
main() {
    # Ensure the log file exists and is writable
    if [[ ! -f "$LOG_FILE" ]]; then
        sudo touch "$LOG_FILE"
        sudo chmod 644 "$LOG_FILE"
    fi

    echo "----------------------------------------" | tee -a "$LOG_FILE"
    echo "🔧 Starting Permissions Reset Process at $(date)" | tee -a "$LOG_FILE"
    echo "----------------------------------------" | tee -a "$LOG_FILE"

    # Confirm before proceeding
    echo "⚠️ This will reset permissions on critical system directories to their defaults."
    read -r -p "Are you sure you want to continue? (y/N) " REPLY
    echo
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
        echo "❌ Operation canceled." | tee -a "$LOG_FILE"
        exit 0
    fi

    # Prompt for dry run
    read -r -p "🔍 Would you like to perform a dry run first? (y/N) " DRY_RUN
    echo
    if [[ "$DRY_RUN" =~ ^[Yy]$ ]]; then
        dry_run=true
        echo "🟡 Performing a dry run..." | tee -a "$LOG_FILE"
    else
        dry_run=false
        # Backup current permissions
        backup_permissions
    fi

    # Reset permissions for main directories
    echo "🔄 Setting default permissions for main directories..." | tee -a "$LOG_FILE"
    reset_dir_permissions "$dry_run"

    # Set appropriate permissions for files and subdirectories
    echo "🔄 Setting appropriate permissions for files and subdirectories..." | tee -a "$LOG_FILE"
    reset_file_permissions "$dry_run" "/etc"
    reset_file_permissions "$dry_run" "/var"

    # Handle /boot/efi separately
    handle_boot_efi "$dry_run"

    # Display summary
    display_summary
}

# Execute the main function
main
