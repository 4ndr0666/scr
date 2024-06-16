#!/bin/bash

# Function to log messages
log_message() {
    local message="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $message"
}

# Function to create a backup tarball of specified files and directories
create_backup() {
    local backup_dir="/tmp/etc_backup"
    local recover_dir="/var/recover"
    local timestamp="$(date -u "+%h-%d-%Y_%H.%M%p")"
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

    # Create a temporary directory to hold the files
    mkdir -p "$backup_dir"

    # Copy each file and directory to the temporary backup directory
    for item in "${target_list[@]}"; do
        if [[ -e "/etc/$item" ]]; then
            cp -r "/etc/$item" "$backup_dir"
        else
            log_message "Warning: /etc/$item does not exist and will not be included in the backup."
        fi
    done

    # Ensure the recovery directory exists
    sudo mkdir -p "$recover_dir"

    # Check if a tarball with the same name already exists and version it
    if [[ -f "$recover_dir/$tarball_name" ]]; then
        local counter=1
        while [[ -f "$recover_dir/${tarball_name%.tar.gz}_v$counter.tar.gz" ]]; do
            counter=$((counter + 1))
        done
        tarball_name="${tarball_name%.tar.gz}_v$counter.tar.gz"
    fi

    # Create a tarball of the backup directory
    sudo tar -czvf "$recover_dir/$tarball_name" -C "$backup_dir" .

    # Clean up the temporary directory
    rm -rf "$backup_dir"

    # Lock the recovery tarball
    sudo chattr +i "$recover_dir/$tarball_name"

    # Notify the user with whiptail
    local notification="Recovery assets successfully cloned and locked at $recover_dir. <Usage: 'unlock/lock' dir>"
    whiptail --title "Backup Completed" --msgbox "$notification" 10 60
    log_message "$notification"
}

# Function to add lock and unlock aliases to shell configuration files
add_aliases() {
    local shell_config_files=(
        "$HOME/.bashrc"
        "$HOME/.zshrc"
        "$HOME/.config/fish/config.fish"
        "/root/.bashrc"
        "/root/.zshrc"
        "/root/.config/fish/config.fish"
    )

    for config_file in "${shell_config_files[@]}"; do
        if [[ -f "$config_file" ]]; then
            # Add alias if not already present
            if ! grep -q "alias lock='sudo chattr +i '" "$config_file"; then
                echo "alias lock='sudo chattr +i '" >> "$config_file"
            fi
            if ! grep -q "alias unlock='sudo chattr -i '" "$config_file"; then
                echo "alias unlock='sudo chattr -i '" >> "$config_file"
            fi
            # For fish shell, use different syntax
            if [[ "$config_file" == *"config.fish" ]]; then
                if ! grep -q "alias lock 'sudo chattr +i '" "$config_file"; then
                    echo "alias lock 'sudo chattr +i '" >> "$config_file"
                fi
                if ! grep -q "alias unlock 'sudo chattr -i '" "$config_file"; then
                    echo "alias unlock 'sudo chattr -i '" >> "$config_file"
                fi
            fi
        fi
    done

    # Source the shell configuration for the current user
    if [[ -f "$HOME/.bashrc" ]]; then
        source "$HOME/.bashrc"
    elif [[ -f "$HOME/.zshrc" ]]; then
        source "$HOME/.zshrc"
    elif [[ -f "$HOME/.config/fish/config.fish" ]]; then
        source "$HOME/.config/fish/config.fish"
    fi
}

# Main function to execute the backup process
main() {
    log_message "Starting the backup process..."
    create_backup
    add_aliases
    log_message "Backup process completed."
}

# Execute the main function
main
