#!/bin/bash
# shellcheck disable=all
#File: Backupconfigs.sh
#Author: 4ndr0666
#Edited: 06-03-24
#Description: This script performs system backups ensuring idempotency and adherence to ISO standards.

# --- // AUTO_ESCALATE:
if [ "$(id -u)" -ne 0 ]; then
  sudo "$0" "$@"
  exit $?
fi

echo -e "\033[34m"
cat << "EOF"
┏┓ ┏━┓┏━╸╻┏ ╻ ╻┏━┓╻ ╻┏━┓┏━╸┏━┓┏┓╻┏━╸╻┏━╸┏━┓ ┏━┓╻ ╻
┣┻┓┣━┫┃  ┣┻┓┃ ┃┣━┛┃ ┃┣━┛┃  ┃ ┃┃┗┫┣╸ ┃┃╺┓┗━┓ ┗━┓┣━┫
┗━┛╹ ╹┗━╸╹ ╹┗━┛╹  ┗━┛╹  ┗━╸┗━┛╹ ╹╹  ╹┗━┛┗━┛╹┗━┛╹ ╹
EOF
echo -e "\033[0m"
sleep 1
echo "💀WARNING💀 - you are now operating as root..."
sleep 1
echo

# --- // FUNCTIONS:

# Error Handling
handle_error() {
    local log_file="$1"
    if [ $? -ne 0 ]; then
        echo "Error encountered. Check ${log_file} for details."
        exit 1
    fi
}

# Logging
log_message() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ${message}" >> "$log_file"
}

# Progress Bar
progress_bar() {
    local total=$1
    local current=$2
    local width=50
    local percent=$((current * 100 / total))
    local hashes=$((current * width / total))
    printf "\r\033[38;5;6mProgress: [%-50s] %d%%\033[0m" "$(printf "%${hashes}s" | tr ' ' '#')" "$percent"
}

# Input Validation
confirm_action() {
    read -p "$1 [y/n]: " choice
    [[ "$choice" == "y" || "$choice" == "Y" ]]
}

# Check for existing backup
check_existing_backup() {
    local dir="$1"
    local base_name="$2"
    if [ -f "${dir}/${base_name}.tar.gz" ]; then
        return 0
    else
        return 1
    fi
}

# System Backup
perform_system_backup() {
    echo "Performing system backup..."
    mkdir -p "$backup_dir" || handle_error "${backup_dir}/system_backup.log"
    local base_name="system-backup-$(date +'%Y%m%d%H%M%S')"
    log_file="${backup_dir}/${base_name}.log"
    touch "$log_file"

    local system_dirs=(
        "/etc"
        "/var/spool/cron/crontabs"
        "/etc/pacman.conf"
        "/etc/pacman.d"
        "/etc/systemd/system"
        "/etc/X11"
        "/etc/default"
        "/etc/environment"
        "/usr/local"
        "/boot"
        "/bin"
        "/sbin"
        "/lib"
        "/lib64"
        "/usr"
        "/var"
        "/run"
    )

    mkdir -p "${backup_dir}/${base_name}" || handle_error "$log_file"

    local total_dirs="${#system_dirs[@]}"
    local current_dir=0

    for dir in "${system_dirs[@]}"; do
        current_dir=$((current_dir + 1))
        progress_bar "$total_dirs" "$current_dir"
        local backup_file="${backup_dir}/${base_name}/$(basename ${dir}).tar.gz"
        if check_existing_backup "$backup_dir/$base_name" "$(basename ${dir})"; then
            log_message "Backup for ${dir} already exists. Skipping..."
        else
            if [ -d "$dir" ]; then
                log_message "Backing up ${dir}..."
                tar -czf "$backup_file" "$dir" >> "${log_file}" 2>&1 || handle_error "$log_file"
                log_message "Backup for ${dir} completed."
            else
                log_message "Directory ${dir} does not exist, skipping..."
            fi
        fi
    done

    echo "System backup completed successfully. Details logged in ${log_file}."

    if confirm_action "Would you like to review the log file now?"; then
        less "${log_file}" || handle_error "$log_file"
    fi
}

# --- // MAIN // ========
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

# Prompt for backup directory using autocomplete
read -e -p "Enter the backup directory: " backup_dir
backup_dir="${backup_dir:-/backup/SystemBackup}"
base_name="system-backup-$(date +'%Y%m%d%H%M%S')"
log_file="${backup_dir}/backup.log"

# Create backup directory and initialize log file
mkdir -p "${backup_dir}"
echo "Backup Log - $(date)" > "${log_file}"

perform_system_backup
  
        
    
    
    
    
exit 0

