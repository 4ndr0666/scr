#!/usr/bin/env bash
# shellcheck disable=all
# File: makerecovery-etc.sh
# Date: 12-15-2024
# Author: 4ndr0666

# --- // Make Recovery for /etc ---

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
LOG_FILE="/var/log/makerecovery-etc.log"
mkdir -p "$(dirname "$LOG_FILE")"

exec > >(tee -a "$LOG_FILE") 2>&1

log_message() {
    local message="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $message"
}

# Function to display help information
show_help() {
    cat << EOF
Usage: ${0##*/} [OPTIONS]

This script provides backup and restore functionalities for critical /etc configuration files, with added support for
comparison using meld.

Options:
  -h, --help             Display this help message and exit.
  backup                 Create a backup of critical /etc files and directories. This is the default action if no options are provided.
  restore                Restore files from a backup and compare them with the current /etc configurations using meld.

Example Usage:
  sudo ${0##*/} backup        Create a backup of critical /etc files and directories.
  sudo ${0##*/} restore       Restore and compare files from a selected backup using meld.
EOF
}

# Function to create a backup tarball of specified files and directories
create_backup() {
    local backup_dir="/tmp/etc_backup"
    local recover_dir="/var/recover"
    local timestamp
    timestamp="$(date -u "+%Y-%m-%d_%H.%M%p")"
    local tarball_name="etc_backup_$timestamp.tar.gz"
    local target_list=(
        "arch-release" "audit" "avahi" "borgmatic" "binfmt.d" "conf.d" "cron.d" "cron.daily"
        "cron.deny" "cron.hourly" "cron.monthly" "cron.weekly" "crontab" "default" "depmod.d"
        "dhcpd.conf" "dnsmasq.conf" "drbl" "environment" "fstab" "group" "grub.d" "gshadow"
        "gss" "gssproxy" "gtk-2.0" "gtk-3.0" "host.conf" "hostname" "hosts" "ipsec.conf"
        "ipsec.d" "iptables" "iscsi" "ld.so.conf" "ld.so.conf.d" "libaudit" "locale.conf"
        "locale.gen" "makepkg.conf" "mkepkg.config.d" "mkinitcpio.conf" "mkinitcpio.conf.d"
        "modprobe.d" "modules-load.d" "nanorc" "netconfig" "NetworkManager" "nfs.conf"
        "nfsmount.conf" "nftables" "nsswitch.conf" "nvme" "openvpn" "pacman.conf" "pacman.d"
        "pam.d" "paru.conf" "passwd" "pinentry" "pipewire" "plymouth" "polkit-1" "powerpill"
        "profile" "profile.d" "pulse" "reflector-simple-tool.conf" "reflector-simple.conf"
        "resolv.conf" "resolv.conf.expressvpn-orig" "screenrc" "sddm.conf" "sddm.conf.d"
        "security" "services" "skel" "ssh" "sudo.conf" "sudoers" "sysctl.d" "systemd"
        "timeshift" "timeshift-autosnap.conf" "tmpfiles.d" "udev" "udisks2" "ufw"
        "vconsole.conf" "wpa_supplicant" "X11" "xdg" "zsh"
    )

    # Create the temporary backup directory if it doesn't exist
    [ ! -d "$backup_dir" ] && mkdir -p "$backup_dir"

    # Total number of items to backup
    local total_items=${#target_list[@]}
    local current_item=0

    # Create a progress bar using whiptail
    {
    for item in "${target_list[@]}"; do
        current_item=$((current_item + 1))
        if [[ -e "/etc/$item" ]]; then
            rsync -a --ignore-existing --ignore-times --update --recursive "/etc/$item" "$backup_dir" || log_message "Failed to copy /etc/$item"
        fi
        local progress=$((current_item * 100 / total_items))
        echo $progress
    done
    } | whiptail --gauge "Backing up files..." 6 50 0

    # Ensure the recovery directory exists
    [ ! -d "$recover_dir" ] && mkdir -p "$recover_dir"

    # Check if a tarball with the same name already exists and version it
    if [[ -f "$recover_dir/$tarball_name" ]]; then
        local counter=1
        while [[ -f "$recover_dir/${tarball_name%.tar.gz}_v$counter.tar.gz" ]]; do
            counter=$((counter + 1))
        done
        tarball_name="${tarball_name%.tar.gz}_v$counter.tar.gz"
        log_message "Existing tarball found. Creating versioned tarball: $tarball_name"
    fi

    # Create a tarball of the backup directory
    log_message "Creating tarball $tarball_name..."
    tar -czf "$recover_dir/$tarball_name" -C "$backup_dir" . || { log_message "Failed to create tarball."; exit 1; }

    log_message "Tarball $tarball_name created successfully."

    # Clean up the backup directory
    rm -rf "$backup_dir" || log_message "Failed to clean up $backup_dir."

    # Lock the recovery tarball
    chattr +i "$recover_dir/$tarball_name" || { log_message "Failed to lock the tarball."; exit 1; }

    # Add lock and unlock aliases to shell configuration files
    add_aliases

    # Notify the user
    local notification="Backup acquired and secured.\n\nUsage:\n  lock <path>   # Lock a file or directory\n  unlock <path> # Unlock a file or directory\n\nLocation: $recover_dir"
    whiptail --title "Recovery Directory" --msgbox "$notification" 12 70
    log_action "Backup created and secured at $recover_dir/$tarball_name."
}

# Function to restore from a backup and compare using meld
restore_backup() {
    local recover_dir="/var/recover"
    local restore_dir="/tmp/etc_restore"

    if [ ! -d "$recover_dir" ]; then
        log_action "Recovery directory $recover_dir does not exist."
        exit 1
    fi

    shopt -s nullglob
    # List available backups
    local backups=("$recover_dir"/*.tar.gz)
    shopt -u nullglob
    if [ ${#backups[@]} -eq 0 ]; then
        log_action "No backups found in $recover_dir."
        exit 1
    fi

    # Prompt user to select a backup
    PS3="Select a backup to restore: "
    echo "Available Backups:"
    select tarball_name in "${backups[@]}"; do
        if [ -n "$tarball_name" ]; then
            break
        else
            echo "Invalid selection."
        fi
    done

    log_action "Selected backup: $tarball_name"

    # Ensure the restore directory exists and is empty
    rm -rf "$restore_dir"
    mkdir -p "$restore_dir" || { log_action "Failed to create restore directory."; return 1; }

    # Extract the selected tarball to the restore directory
    tar -xzf "$tarball_name" -C "$restore_dir" || {
        log_action "Failed to extract tarball: $tarball_name"
        return 1
    }

    # Compare the files in the restore directory with the current /etc using meld
    for item in "$restore_dir"/*; do
        local item_name
        item_name=$(basename "$item")
        if [[ -e "/etc/$item_name" ]]; then
            meld "$restore_dir/$item_name" "/etc/$item_name" || log_action "Failed to compare /etc/$item_name with backup."
        else
            log_action "No current /etc/$item_name found. Restoring from backup."
            cp -r "$restore_dir/$item_name" "/etc/$item_name" || log_action "Failed to restore /etc/$item_name."
        fi
    done

    # Clean up the restore directory
    rm -rf "$restore_dir" || log_message "Failed to clean up restore directory."

    log_message "Restore and comparison completed."
    whiptail --title "Restore Complete" --msgbox "Restore and comparison completed successfully." 8 60
}

# Function to add lock and unlock aliases to shell configuration files
add_aliases() {
    local shell_config_files=(
        "$USER_HOME/.bashrc"
        "$USER_HOME/.zshrc"
    )

    for config_file in "${shell_config_files[@]}"; do
        if [[ -f "$config_file" ]]; then
            # Add alias if not already present
            if ! grep -q "alias lock=" "$config_file"; then
                echo "alias lock='sudo chattr +i '" >> "$config_file"
                log_action "Added lock alias to $config_file"
            fi
            if ! grep -q "alias unlock=" "$config_file"; then
                echo "alias unlock='sudo chattr -i '" >> "$config_file"
                log_action "Added unlock alias to $config_file"
            fi
        else
            log_action "Shell configuration file $config_file not found."
        fi
    done
    # Source the shell configuration for the current user
    if [[ -f "$USER_HOME/.bashrc" ]]; then
        sudo -u "$INVOKING_USER" bash -c "source '$USER_HOME/.bashrc'"
    elif [[ -f "$USER_HOME/.zshrc" ]]; then
        sudo -u "$INVOKING_USER" zsh -c "source '$USER_HOME/.zshrc'"
    fi
}

# Main function to execute the backup or restore process
main() {
    case "$1" in
        backup|"") # Default action is to create a backup if no option is provided
            log_action "Starting the backup process..."
            create_backup
            log_action "Backup process completed."
            ;;
        restore)
            log_action "Starting the restore process..."
            restore_backup
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Error: Unrecognized command '$1'"
            show_help
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
