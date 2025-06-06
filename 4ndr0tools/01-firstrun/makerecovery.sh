#!/bin/bash
# shellcheck disable=all
# File: makerecovery-etc
# Author: 4ndr0666
# Edited: 12-15-24

# ============================== // MAKERECOVERY-ETC //
# --- // Auto-escalate:
if [ "$(id -u)" -ne 0 ]; then
    sudo "$0" "$@"
    exit $?
fi

# --- // Colors:
#tput setaf 0 = black
#tput setaf 1 = red
#tput setaf 2 = green
#tput setaf 3 = yellow
#tput setaf 4 = dark blue
#tput setaf 5 = purple
#tput setaf 6 = cyan
#tput setaf 7 = gray
#tput setaf 8 = light blue

# --- // Logging:
log_message() {
    local message="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $message" | tee -a /var/log/makerecover2-etc.log
}

# --- // Help:
show_help() {
    cat << EOF
Usage: ${0##*/} [OPTIONS]

This script provides backup and restore functionalities for critical /etc configuration files, with added support for comparison using meld.

Options:
  -h, --help             Display this help message and exit.
  backup                 Create a backup of critical /etc files and directories. This is the default action if no options are provided.
  restore                Restore files from a backup and compare them with the current /etc configurations using meld.
  
Example Usage:
  ${0##*/} backup        Create a backup of critical /etc files and directories.
  ${0##*/} restore       Restore and compare files from a selected backup using meld.

EOF
}

# Function to create a backup tarball of specified files and directories
create_backup() {
    local backup_dir="/tmp/etc_backup"
    local recover_dir="/var/recover"
    local timestamp
    timestamp="$(date -u "+%h-%d-%Y_%H.%M%p")"
    local tarball_name="etc_backup_$timestamp.tar.gz"
    local target_list=(
        "arch-release" "audit" "avahi" "borgmatic" "binfmt.s" "conf.d" "cloud" "cron.d" "cron.daily"
        "cron.deny" "cron.hourly" "cron.monthly" "cron.weekly" "crontab" "default" "depmod.d" "dhcpd.conf"
        "dnsmasq.conf" "drbl" "environment" "fstab" "group" "grub.d" "gshadow" "gss" "gssproxy" "gtk-2.0"
        "gtk-3.0" "host.conf" "hostname" "hosts" "ipsec.conf" "ipsec.d" "iptables" "iscsi" "ld.so.conf"
        "ld.so.conf.d" "libaudit" "locale.conf" "locale.gen" "makepkg.conf" "mkepkg.config.d" "mkinicpio.conf"
        "mkinitcpio.conf.d" "modprobe.d" "modules-load.d" "nanorc" "netconfig" "NetworkManager" "nfs.conf"
        "nfsmount.conf" "nftables" "nsswitch.conf" "nvme" "openvpn" "pacman.conf" "pacman.d" "pam.d" "paru.conf"
        "passwd" "pinentry" "pipewire" "plymouth" "polkit-1" "powerpill" "profile" "profile.d" "pulse"
        "reflector-simple-tool.conf" "reflector-simple.conf" "resolv.conf" "resolv.conf.expressvpn-orig"
        "screenrc" "sddm.conf" "sddm.conf.d" "security" "services" "skel" "ssh" "sudo.conf" "sudoers" "sysctl.d"
        "systemd" "timeshift" "timeshift-autosnap.conf" "tmpfiles.d" "udev" "udisks2" "ufw" "vconsole.conf"
        "wpa_supplicant" "X11" "xdg" "zsh"
    )

    # Create the temporary backup directory if it doesn't exist
    [ ! -d "$backup_dir" ] && mkdir -p "$backup_dir" || log_message "Using existing backup directory."

    # Total number of items to backup
    local total_items=${#target_list[@]}
    local current_item=0

    # Copy each file and directory to the temporary backup directory
    {
        for item in "${target_list[@]}"; do
            current_item=$((current_item + 1))
            if [[ -e "/etc/$item" ]]; then
                rsync -a --ignore-existing "/etc/$item" "$backup_dir" || log_message "Failed to copy /etc/$item"
            fi
            local progress=$((current_item * 100 / total_items))
            echo $progress
        done
    } | whiptail --gauge "Backing up files..." 6 50 0

    # Ensure the recovery directory exists
    [ ! -d "$recover_dir" ] && sudo mkdir -p "$recover_dir" || log_message "Using existing recovery directory."

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
    tar -czf "$recover_dir/$tarball_name" -C "$backup_dir" . >/dev/null 2>&1 || { log_message "Failed to create tarball."; exit 1; }

    # Clean up the temporary directory
    rm -rf "$backup_dir" || log_message "Failed to clean up temporary backup directory."

    # Lock the recovery tarball
    chattr +i "$recover_dir/$tarball_name" || { log_message "Failed to lock the tarball."; exit 1; }

    # Notify the user with whiptail
    local notification="Acquired and secured.\\n\\nUsage:\\n  lock <path>   # Lock a file or directory\\n  unlock <path> # Unlock a file or directory\\n\\nLocation: $recover_dir"
    whiptail --title "Asset: /etc" --msgbox "$notification" 12 70
    log_message "Acquired and secured. Location: $recover_dir"
}

# Function to restore from a backup and compare using meld
restore_backup() {
    local recover_dir="/var/recover"
    local restore_dir="/tmp/etc_restore"
    
    # Ask the user to select a backup to restore
    local tarball_name
    tarball_name=$(whiptail --title "Select Backup" --radiolist "Choose a backup to restore:" 15 60 6 \
        $(ls "$recover_dir"/*.tar.gz | xargs -n1 basename | awk '{print $0 " " NR " OFF"}') 3>&1 1>&2 2>&3)
    
    if [[ -z "$tarball_name" ]]; then
        log_message "Restore cancelled."
        return 1
    fi
    
    # Ensure the restore directory exists and is empty
    rm -rf "$restore_dir"
    mkdir -p "$restore_dir" || { log_message "Failed to create restore directory."; return 1; }

    # Extract the selected tarball to the restore directory
    tar -xzf "$recover_dir/$tarball_name" -C "$restore_dir" || { log_message "Failed to extract tarball."; return 1; }

    # Compare the files in the restore directory with the current /etc using meld
    for item in "$restore_dir"/*; do
        local item_name
        item_name=$(basename "$item")
        if [[ -e "/etc/$item_name" ]]; then
            meld "$restore_dir/$item_name" "/etc/$item_name" || log_message "Failed to compare /etc/$item_name with backup."
        else
            log_message "No current /etc/$item_name found. Restoring from backup."
            cp -r "$restore_dir/$item_name" "/etc/$item_name" || log_message "Failed to restore /etc/$item_name."
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
        "$HOME/.bashrc"
        "$HOME/.zshrc"
        "/root/.bashrc"
        "/root/.zshrc"
    )

    for config_file in "${shell_config_files[@]}"; do
        if [[ -f "$config_file" ]]; then
            # Add alias if not already present
            if ! grep -q "alias lock='sudo chattr +i '" "$config_file"; then
                echo "alias lock='sudo chattr +i '" >> "$config_file" || log_message "Failed to add lock alias to $config_file"
            fi
            if ! grep -q "alias unlock='sudo chattr -i '" "$config_file"; then
                echo "alias unlock='sudo chattr -i '" >> "$config_file" || log_message "Failed to add unlock alias to $config_file"
            fi
            if ! grep -q "source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh 2>/dev/null"; then
                echo "source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh 2>/dev/null" >> "$config_file" || log_message "Failed to add zsh-autosuggestions to $config_file"
            fi
            if ! grep -q "source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh 2>/dev/null"; then
                echo "source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh 2>/dev/null" >> "$config_file" || log_message "Failed to add zsh-syntax-highlighting to $config_file"
            fi
        fi
    done

    # Source the shell configuration for the current user
    if [[ -f "$HOME/.bashrc" ]]; then
        source "$HOME/.bashrc"
    elif [[ -f "$HOME/.zshrc" ]]; then
        source "$HOME/.zshrc"
    fi
}
install_deps() {
    sudo pacman -Sy  
    sudo pacman -S zsh-syntax-highlighting zsh-autosuggestions --noconfirm
    touch "$HOME/.cache/zshhistory"
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k
    echo 'source ~/powerlevel10k/powerlevel10k.zsh-theme' >>! ~/.zshrc
}

# Main function to execute the backup or restore process
main() {
    case "$1" in
        backup|"") # Default action is to create a backup if no option is provided
            log_message "Starting the backup process..."
            create_backup
            add_aliases
            log_message "Backup process completed."
            ;;
        restore)
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

main "$@"
