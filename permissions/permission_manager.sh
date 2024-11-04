#!/usr/bin/env bash

# ------------------------------------------------------------------
# Permissions Manager Script
# ------------------------------------------------------------------
# Description:
# A comprehensive script to manage system permissions on Arch Linux.
# It allows backing up, restoring, auditing, and fixing permissions
# using various methods, including pacman, pacutils, and custom policies.
#
# Author: Your Name
# Date: YYYY-MM-DD
# ------------------------------------------------------------------

# Exit immediately if a command exits with a non-zero status
set -e

# --- Configuration ---
CONFIG_FILE="/etc/permissions_manager.conf"
LOG_FILE="/var/log/permissions_manager.log"
BACKUP_DIR="/var/backups/permissions"
DEFAULT_USER="root"
DEFAULT_GROUP="root"

# --- Import Configuration ---
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "CONFIG_FILE='$CONFIG_FILE'" > "$CONFIG_FILE"
    echo "LOG_FILE='$LOG_FILE'" >> "$CONFIG_FILE"
    echo "BACKUP_DIR='$BACKUP_DIR'" >> "$CONFIG_FILE"
    echo "DEFAULT_USER='$DEFAULT_USER'" >> "$CONFIG_FILE"
    echo "DEFAULT_GROUP='$DEFAULT_GROUP'" >> "$CONFIG_FILE"
fi

# --- Logging Function ---
log_action() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE" > /dev/null
}

# --- Ensure Root Privileges ---
if [[ "$EUID" -ne 0 ]]; then
    echo "This script requires root privileges. Please run as root or use sudo."
    exit 1
fi

# --- Install Required Packages ---
install_dependencies() {
    local dependencies=("pacutils" "acl")
    local to_install=()

    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            to_install+=("$dep")
        fi
    done

    if [ "${#to_install[@]}" -ne 0 ]; then
        echo "Installing dependencies: ${to_install[*]}"
        pacman -S --noconfirm --needed "${to_install[@]}"
    else
        echo "All dependencies are already installed."
    fi
}

# --- Backup Permissions ---
backup_permissions() {
    echo "Starting backup of permissions and ownerships..."
    mkdir -p "$BACKUP_DIR"

    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local acl_backup="$BACKUP_DIR/permissions_acl_$timestamp.gz"
    local ownership_backup="$BACKUP_DIR/ownerships_$timestamp.csv"

    echo "Backing up ACLs..."
    getfacl -R --absolute-names --skip-base / 2>/dev/null | gzip -c > "$acl_backup"

    echo "Backing up ownerships and permissions..."
    find / -xdev \( -path /proc -o -path /sys -o -path /dev -o -path /run -o -path /tmp -o -path /mnt -o -path /media -o -path /lost+found \) -prune -o -print0 | \
    xargs -0 stat --format '%n,%a,%U,%G' > "$ownership_backup"

    echo "Backup completed successfully."
    log_action "Backup completed: ACLs at $acl_backup, Ownerships at $ownership_backup"
}

# --- Restore Permissions ---
restore_permissions() {
    echo "Starting restoration of permissions and ownerships..."

    local acl_backup
    local ownership_backup

    # Find the latest backups
    acl_backup=$(ls -t "$BACKUP_DIR"/permissions_acl_*.gz 2>/dev/null | head -n 1 || true)
    ownership_backup=$(ls -t "$BACKUP_DIR"/ownerships_*.csv 2>/dev/null | head -n 1 || true)

    if [[ ! -f "$acl_backup" ]] || [[ ! -f "$ownership_backup" ]]; then
        echo "Backup files not found in $BACKUP_DIR"
        exit 1
    fi

    echo "Restoring ACLs from $acl_backup..."
    gunzip -c "$acl_backup" | setfacl --restore=-

    echo "Restoring ownerships and permissions from $ownership_backup..."
    while IFS=',' read -r filepath mode owner group; do
        if [[ -e "$filepath" ]]; then
            chmod "$mode" "$filepath"
            chown "$owner:$group" "$filepath"
        else
            echo "File $filepath does not exist. Skipping."
        fi
    done < "$ownership_backup"

    echo "Restoration completed successfully."
    log_action "Restoration completed using ACLs from $acl_backup and ownerships from $ownership_backup"
}

# --- Audit Permissions ---
audit_permissions() {
    echo "Starting audit of permissions and ownerships..."
    local discrepancies=()

    # Using pacman to verify package files
    local permission_errors
    permission_errors=$(pacman -Qkk 2>/dev/null | grep -E 'Permissions differ|Ownership differs')

    if [[ -n "$permission_errors" ]]; then
        discrepancies+=("$permission_errors")
    fi

    # Additional checks can be added here

    if [[ "${#discrepancies[@]}" -eq 0 ]]; then
        echo "No discrepancies found."
        log_action "Audit completed: No discrepancies found."
    else
        echo "Discrepancies found:"
        for discrepancy in "${discrepancies[@]}"; do
            echo "$discrepancy"
            log_action "Discrepancy: $discrepancy"
        done
    fi
}

# --- Fix Permissions ---
fix_permissions() {
    echo "Starting fix of permissions and ownerships..."

    # Reset permissions using pacman
    echo "Fixing permissions of package-managed files..."
    # Generate list of files with incorrect permissions
    local files_to_fix
    files_to_fix=$(pacman -Qkk 2>/dev/null | grep -E 'Permissions differ|Ownership differs' | awk '{print $2}')

    if [[ -n "$files_to_fix" ]]; then
        while read -r file; do
            if [[ -e "$file" ]]; then
                # Get the package that owns the file
                pkg=$(pacman -Qo "$file" 2>/dev/null | awk '{print $5}')
                if [[ -n "$pkg" ]]; then
                    # Extract the file from the package and reset its permissions
                    echo "Restoring $file from package $pkg"
                    # Use bsdtar to extract file permissions and ownership
                    pkgfile="/var/cache/pacman/pkg/${pkg}-$(pacman -Qi "$pkg" | grep Version | awk '{print $3}').pkg.tar.zst"
                    if [[ -f "$pkgfile" ]]; then
                        bsdtar -xpf "$pkgfile" -C / "$file" --numeric-owner
                    else
                        echo "Package file $pkgfile not found. Skipping $file."
                    fi
                else
                    echo "Package for $file not found. Skipping."
                fi
            else
                echo "File $file does not exist. Skipping."
            fi
        done <<< "$files_to_fix"
    else
        echo "No package-managed files with incorrect permissions found."
    fi

    # Reset specific directories and files
    echo "Resetting permissions of common system directories..."
    declare -A dir_permissions=(
        ["/etc"]=755
        ["/var"]=755
        ["/usr"]=755
        ["/bin"]=755
        ["/sbin"]=755
        ["/lib"]=755
        ["/lib64"]=755
        ["/opt"]=755
        ["/home"]=755
        ["/root"]=750
        ["/tmp"]=1777
        ["/srv"]=755
        ["/mnt"]=755
        ["/media"]=755
    )

    for dir in "${!dir_permissions[@]}"; do
        if [[ -d "$dir" ]]; then
            chmod "${dir_permissions[$dir]}" "$dir"
            chown root:root "$dir"
        fi
    done

    echo "Resetting permissions in /etc..."
    find /etc -type f -exec chmod 644 {} \;
    find /etc -type d -exec chmod 755 {} \;
    chmod 600 /etc/shadow /etc/gshadow
    chmod 644 /etc/passwd /etc/group
    chmod 440 /etc/sudoers

    echo "Resetting user home directories..."
    for dir in /home/*; do
        if [[ -d "$dir" ]]; then
            user=$(basename "$dir")
            chown -R "$user":"$user" "$dir"
            chmod 700 "$dir"
            find "$dir" -type d -exec chmod 700 {} \;
            find "$dir" -type f -exec chmod 600 {} \;
        fi
    done

    echo "Resetting permissions of special files..."
    chmod 4755 /bin/su
    chmod 4755 /usr/bin/sudo

    echo "Fix completed successfully."
    log_action "Permissions and ownerships have been reset to defaults."
}

# --- Interactive Menu ---
show_menu() {
    echo "Permissions Manager"
    echo "-------------------"
    echo "1) Backup Permissions"
    echo "2) Restore Permissions"
    echo "3) Audit Permissions"
    echo "4) Fix Permissions"
    echo "5) Exit"
    echo -n "Enter your choice [1-5]: "
}

# --- Main Loop ---
main() {
    install_dependencies

    while true; do
        show_menu
        read -r choice

        case $choice in
            1)
                backup_permissions
                ;;
            2)
                restore_permissions
                ;;
            3)
                audit_permissions
                ;;
            4)
                fix_permissions
                ;;
            5)
                echo "Exiting..."
                exit 0
                ;;
            *)
                echo "Invalid choice. Please select a valid option."
                ;;
        esac
        echo
    done
}

# --- Run Main Function ---
main
