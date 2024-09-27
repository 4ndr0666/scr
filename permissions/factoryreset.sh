#!/bin/bash

# --- Factory Reset Permissions Script ---
# Description: This script resets the permissions of critical system directories and files
# to their factory default settings. It ensures the proper permissions for specific directories
# and files based on security best practices and the current environment setup.

# --- AUTO_ESCALATE ---
if [ "$(id -u)" -ne 0 ]; then
    echo "This script requires root privileges. Please enter your password to continue."
    exec sudo "$0" "$@"
fi

# --- Set -euo Pipefail for strict error handling ---
set -euo pipefail

# --- Define default permissions for critical directories and files ---
declare -A dir_permissions=(
    ["/boot"]=755
    ["/dev"]=755
    ["/etc"]=755
    ["/home"]=700
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
    ["/var/log"]=755
    ["/var/cache"]=755
    ["/boot/efi"]=755
    ["/usr/local"]=755
    ["$HOME/.config"]=700
    ["$HOME/.local"]=700
    ["$HOME/.cache"]=700
    ["$HOME/.gnupg"]=700
    ["$HOME/.ssh"]=700
)

declare -A file_permissions=(
    ["/etc/sudoers"]=440
    ["/etc/shadow"]=600
    ["/etc/gshadow"]=600
    ["/etc/passwd"]=644
    ["/etc/group"]=644
    ["/etc/fstab"]=644
    ["/etc/hosts"]=644
    ["/etc/hostname"]=644
    ["/var/log/syslog"]=640
    ["/var/log/auth.log"]=640
    ["$HOME/.gnupg/gpg.conf"]=600
    ["$HOME/.ssh/authorized_keys"]=600
    ["$HOME/.ssh/config"]=600
)

# --- Centralized log file ---
log_file="/var/log/permissions_audit.log"

# --- Logging function ---
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | sudo tee -a "$log_file" > /dev/null
}

# --- Backup existing permissions ---
backup_permissions() {
    local backup_file="/tmp/permissions_backup_$(date +%Y%m%d%H%M%S).txt"
    log_action "Backing up current permissions to $backup_file..."
    for dir in "${!dir_permissions[@]}"; do
        if [[ -d $dir ]]; then
            sudo find "$dir" -exec stat -c "%a %n" {} \; >> "$backup_file"
        fi
    done
    for file in "${!file_permissions[@]}"; do
        if [[ -e $file ]]; then
            sudo stat -c "%a %n" "$file" >> "$backup_file"
        fi
    done
    log_action "Backup completed."
}

# --- Reset directory permissions ---
reset_dir_permissions() {
    local dry_run=$1
    for dir in "${!dir_permissions[@]}"; do
        if [[ -d $dir ]]; then
            local current_perm
            current_perm=$(stat -c "%a" "$dir")
            if [[ "$current_perm" -ne "${dir_permissions[$dir]}" ]]; then
                if [[ "$dry_run" == true ]]; then
                    echo "Dry Run: sudo chmod ${dir_permissions[$dir]} $dir"
                else
                    sudo chmod "${dir_permissions[$dir]}" "$dir"
                    log_action "Permissions set for $dir to ${dir_permissions[$dir]}."
                fi
            else
                log_action "Permissions for $dir are already correct."
            fi
        else
            log_action "Directory $dir does not exist; skipping."
        fi
    done
}

# --- Reset file permissions ---
reset_file_permissions() {
    local dry_run=$1
    for file in "${!file_permissions[@]}"; do
        if [[ -e $file ]]; then
            local current_perm
            current_perm=$(stat -c "%a" "$file")
            if [[ "$current_perm" -ne "${file_permissions[$file]}" ]]; then
                if [[ "$dry_run" == true ]]; then
                    echo "Dry Run: sudo chmod ${file_permissions[$file]} $file"
                else
                    sudo chmod "${file_permissions[$file]}" "$file"
                    log_action "Permissions set for $file to ${file_permissions[$file]}."
                fi
            else
                log_action "Permissions for $file are already correct."
            fi
        else
            log_action "File $file does not exist; skipping."
        fi
    done
}

# --- Special handling for subdirectories ---
reset_subdir_file_permissions() {
    local dry_run=$1
    local dir=$2
    if [[ -d "$dir" ]]; then
        if [[ "$dry_run" == true ]]; then
            echo "Dry Run: sudo find $dir -type d -exec chmod 755 {} \\;"
            echo "Dry Run: sudo find $dir -type f -exec chmod 644 {} \\;"
            echo "Dry Run: sudo find $dir -type f -perm /u+x -exec chmod 755 {} \\;"
        else
            sudo find "$dir" -type d -exec chmod 755 {} \;
            sudo find "$dir" -type f -exec chmod 644 {} \;
            sudo find "$dir" -type f -perm /u+x -exec chmod 755 {} \;
            log_action "Permissions reset for files and directories within $dir."
        fi
    fi
}

# --- Handle special permissions (setuid, setgid, sticky bit) ---
handle_special_permissions() {
    local dir=$1
    if [[ -d "$dir" ]]; then
        log_action "Handling special permissions for $dir..."
        sudo find "$dir" -type f -perm -4000 -exec chmod u+s {} \;  # setuid
        sudo find "$dir" -type f -perm -2000 -exec chmod g+s {} \;  # setgid
        sudo find "$dir" -type d -perm -1000 -exec chmod +t {} \;   # sticky bit
    fi
}

# --- Main logic ---
main() {
    # Confirmation before proceeding
    read -r -p "This will reset system permissions. Continue? (y/N) " response
    if [[ "$response" != "y" && "$response" != "Y" ]]; then
        log_action "Operation cancelled."
        exit 0
    fi

    # Option for a dry run
    read -r -p "Would you like to perform a dry run first? (y/N) " DRY_RUN
    if [[ "$DRY_RUN" =~ ^[Yy]$ ]]; then
        dry_run=true
        log_action "Performing a dry run..."
    else
        dry_run=false
        log_action "Backing up current permissions..."
        backup_permissions
    fi

    # Reset directory permissions
    log_action "Resetting directory permissions..."
    reset_dir_permissions "$dry_run"

    # Reset file permissions
    log_action "Resetting file permissions..."
    reset_file_permissions "$dry_run"

    # Handle special subdirectories
    reset_subdir_file_permissions "$dry_run" "/etc"
    reset_subdir_file_permissions "$dry_run" "/var"
    reset_subdir_file_permissions "$dry_run" "$HOME/.config"
    reset_subdir_file_permissions "$dry_run" "$HOME/.local"

    # Handle special permissions
    handle_special_permissions "/tmp"
    handle_special_permissions "/usr"
    handle_special_permissions "/var"

    log_action "Permissions reset complete."
}

# --- Execute the main function ---
main
