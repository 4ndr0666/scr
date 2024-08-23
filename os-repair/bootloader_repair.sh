#!/bin/bash

# Ensure the script adheres to strict error handling and security practices
set -euo pipefail

# Define a dictionary (associative array) for bootloader options
declare -A bootloader_map=( ["1"]="GRUB" ["2"]="systemd-boot" )

# Function to display help
display_help() {
    echo "Usage: $(basename "$0") [OPTION]"
    echo "Options:"
    echo "  -h, --help          Display this help message and exit"
    echo "  1                   Reinstall GRUB bootloader"
    echo "  2                   Reinstall systemd-boot bootloader"
    echo "  3, --exit           Exit the script"
}

# Function to display a menu
display_menu() {
    echo "Choose a bootloader to reinstall:"
    echo "1) GRUB"
    echo "2) systemd-boot"
    echo "3) Exit"
}

# Function for automatic privilege escalation
auto_escalate() {
    if [ "$EUID" -ne 0 ]; then
        echo "This script requires root privileges. Attempting to escalate privileges..."
        exec sudo "$0" "$@"
    fi
}

# Function to validate user input for partitions
validate_partition_input() {
    local partition="$1"
    if [[ ! "$partition" =~ ^/dev/[a-zA-Z0-9]+$ ]]; then
        echo "Invalid partition input: $partition"
        exit 1
    fi
}

# Function to mount necessary filesystems for a Btrfs setup
mount_filesystems() {
    read -rp "Enter the root partition (e.g., /dev/sda2): " root_partition
    validate_partition_input "$root_partition"

    read -rp "Enter the EFI partition (e.g., /dev/sda1): " efi_partition
    validate_partition_input "$efi_partition"

    local mount_point="/mnt"

    # Check if the root partition is already mounted as "/"
    if mount | grep "on / type" | grep -q "$root_partition"; then
        echo "It appears that you are already booted into the root partition ($root_partition)."
        echo "This script is intended to be run from a live environment or a different root partition."
        exit 1
    fi

    echo "Mounting the root partition to $mount_point..."
    # Mount the root subvolume
    mount -o subvol=/@ "$root_partition" "$mount_point" || { echo "Failed to mount the root subvolume."; exit 1; }

    # Mount additional subvolumes
    for subvol in @home @root @srv @cache @log @tmp; do
        local subvol_mount_point="$mount_point/$(echo "$subvol" | sed 's/@//')"
        mkdir -p "$subvol_mount_point"
        mount -o subvol="/$subvol" "$root_partition" "$subvol_mount_point" || { echo "Failed to mount subvolume $subvol."; exit 1; }
    done

    # Mount the EFI partition
    echo "Mounting the EFI partition to $mount_point/boot/efi..."
    mkdir -p "$mount_point/boot/efi"
    mount "$efi_partition" "$mount_point/boot/efi" || { echo "Failed to mount the EFI partition."; exit 1; }

    # Bind mount necessary filesystems
    for dir in dev proc sys; do
        mount --bind "/$dir" "$mount_point/$dir" || { echo "Failed to bind mount /$dir."; exit 1; }
    done
}

# Function to reinstall GRUB
install_grub() {
    arch-chroot "$mount_point" /bin/bash <<EOF
pacman -Syu grub efibootmgr --noconfirm
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
EOF

    if [ $? -ne 0 ]; then
        echo "Failed to install and configure GRUB."
        exit 1
    fi
}

# Function to reinstall systemd-boot
install_systemd_boot() {
    arch-chroot "$mount_point" /bin/bash <<EOF
bootctl install
EOF

    if [ $? -ne 0 ]; then
        echo "Failed to install systemd-boot."
        exit 1
    fi

    cat > "$mount_point/boot/loader/entries/arch.conf" <<EOF
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=UUID=$(blkid -s UUID -o value "$root_partition") rw rootflags=subvol=@
EOF
}

# Function to unmount filesystems
unmount_filesystems() {
    echo "Unmounting filesystems from $mount_point..."
    umount -R "$mount_point" || { echo "Failed to unmount filesystems."; exit 1; }
}

# Main script logic
auto_escalate "$@"

if [[ $# -eq 0 ]] || [[ "$1" =~ ^(-h|--help)$ ]]; then
    display_help
    exit 0
fi

while true; do
    if [[ -n "${bootloader_map[$1]:-}" ]]; then
        display_menu
        read -rp "Select an option (1-3): " option
    else
        echo "Invalid option. Please try again."
        display_help
        exit 1
    fi

    case $option in
        1)
            mount_filesystems
            install_grub
            unmount_filesystems
            echo "GRUB installed successfully. You can now reboot your system."
            exit 0
            ;;
        2)
            mount_filesystems
            install_systemd_boot
            unmount_filesystems
            echo "systemd-boot installed successfully. You can now reboot your system."
            exit 0
            ;;
        3|--exit)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option. Please try again."
            display_help
            ;;
    esac
done
