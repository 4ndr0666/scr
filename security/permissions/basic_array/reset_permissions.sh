#!/bin/bash

# ----------------------------------------- // RESET_PERMISSIONS:
# Script: reset_permissions.sh
# Description: Safely resets permissions on critical system directories to default "factory" settings.
# Author: 4ndr0666 (Revised)
# Date: 2024-12-15

set -e

LOG_FILE="/var/log/reset_permissions.log"
BACKUP_FILE="/tmp/permissions_backup_$(date +%Y%m%d%H%M%S).txt"

# Only root may run this script!
if [[ "$EUID" -ne 0 ]]; then
    echo "❌ Must be run as root. Aborting." | tee -a "$LOG_FILE"
    exit 1
fi

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
    ["/boot/efi"]=755
)

EXCLUDED_PATHS=("/dev" "/proc" "/sys" "/run" "/tmp" "/mnt" "/media" "/lost+found")

# Helper: join exclusions for 'find'
find_exclude() {
    local args=()
    for path in "${EXCLUDED_PATHS[@]}"; do
        args+=("-path" "$path" "-prune" "-o")
    done
    echo "${args[@]}"
}

log() {
    echo -e "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"
}

backup_permissions() {
    log "🔄 Backing up permissions to $BACKUP_FILE"
    for dir in "${!dir_permissions[@]}"; do
        if [[ -d $dir ]]; then
            find "$dir" -not -type l -exec stat -c "%a %U %G %n" {} \; >> "$BACKUP_FILE" 2>>"$LOG_FILE"
        fi
    done
    log "✅ Permissions backup complete."
}

reset_dir_permissions() {
    local dry_run=$1
    for dir in "${!dir_permissions[@]}"; do
        if [[ -d $dir ]]; then
            current_perm=$(stat -c "%a" "$dir" 2>/dev/null)
            expected_perm="${dir_permissions[$dir]}"
            if [[ "$current_perm" -ne "$expected_perm" ]]; then
                if [[ "$dry_run" == true ]]; then
                    log "🟡 Dry Run: Would set $dir to $expected_perm"
                else
                    if chmod "$expected_perm" "$dir" 2>>"$LOG_FILE"; then
                        log "✔️ $dir set to $expected_perm"
                    else
                        log "❌ Failed to set permissions for $dir"
                    fi
                fi
            else
                log "🔍 $dir already has correct permissions; skipping."
            fi
        else
            log "⚠️ $dir does not exist; skipping."
        fi
    done
}

reset_file_permissions() {
    local dry_run=$1
    local dir=$2

    # Don’t traverse excluded system mounts
    for path in "${EXCLUDED_PATHS[@]}"; do
        [[ "$dir" == "$path"* ]] && return 0
    done

    if [[ -d "$dir" ]]; then
        if [[ "$dry_run" == true ]]; then
            log "🟡 Dry Run: Would run find $dir -type d -not -type l -exec chmod 755 {} \\;"
            log "🟡 Dry Run: Would run find $dir -type f -not -type l -exec chmod 644 {} \\;"
            log "🟡 Dry Run: Would run find $dir -type f -perm /u+x -not -type l -exec chmod 755 {} \\;"
        else
            find "$dir" -type d -not -type l -exec chmod 755 {} \; 2>>"$LOG_FILE"
            find "$dir" -type f -not -type l -exec chmod 644 {} \; 2>>"$LOG_FILE"
            find "$dir" -type f -perm /u+x -not -type l -exec chmod 755 {} \; 2>>"$LOG_FILE"
            log "✔️ Permissions reset for $dir"
        fi
    fi
}

handle_boot_efi() {
    local dry_run=$1
    local dir="/boot/efi"
    if [[ -d "$dir" ]]; then
        current_perm=$(stat -c "%a" "$dir" 2>/dev/null)
        if [[ "$current_perm" -ne "755" ]]; then
            if [[ "$dry_run" == true ]]; then
                log "🟡 Dry Run: Would set $dir to 755"
            else
                if chmod 755 "$dir" 2>>"$LOG_FILE"; then
                    log "✔️ $dir set to 755"
                else
                    log "❌ Failed to set $dir to 755"
                fi
            fi
        else
            log "🔍 $dir already at 755"
        fi
    fi
}

display_summary() {
    log "✅ Permissions reset process completed."
}

confirm_prompt() {
    read -r -p "$1 (y/N): " reply
    [[ "$reply" =~ ^[Yy]$ ]]
}

main() {
    [[ ! -f "$LOG_FILE" ]] && touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"

    log "----------------------------------------"
    log "🔧 Starting Permissions Reset: $(date)"
    log "----------------------------------------"

    echo "⚠️  This will reset permissions on critical system directories to their defaults."
    if ! confirm_prompt "Continue?"; then
        log "❌ Operation canceled."
        exit 0
    fi

    if confirm_prompt "🔍 Perform a dry run first?"; then
        dry_run=true
        log "🟡 Dry run mode enabled."
    else
        dry_run=false
        backup_permissions
    fi

    log "🔄 Setting default permissions for system directories..."
    reset_dir_permissions "$dry_run"

    log "🔄 Setting file/subdirectory permissions for /etc and /var..."
    reset_file_permissions "$dry_run" "/etc"
    reset_file_permissions "$dry_run" "/var"

    handle_boot_efi "$dry_run"
    display_summary
}

main
