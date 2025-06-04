#!/bin/bash
# shellcheck disable=all

# Ensure the script runs with root privileges
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "This script requires root privileges. Please run as root or use sudo."
        exit 1
    fi
}

# Function to display a menu
display_menu() {
    echo "Choose an option:"
    echo "1) Mount Subvolumes"
    echo "2) Unmount Subvolumes"
    echo "3) Auto Chroot"
    echo "4) Exit"
}

# Variables to hold the mount points and device names
declare -a subvolumes
subvolumes=()

# Function to detect and mount subvolumes
mount_subvolumes() {
    read -rp "Enter the device to mount (e.g., /dev/sda1): " device
    read -rp "Enter the mount point (e.g., /mnt): " mount_point

    [ -z "$device" ] || [ -z "$mount_point" ] && { echo "Device and mount point cannot be empty."; exit 1; }

    mkdir -p "$mount_point"
    mount "$device" "$mount_point"

    echo "Detecting subvolumes..."
    btrfs subvolume list "$mount_point" | while read -r line; do
        subvol=$(echo "$line" | awk '{print $9}')
        subvolumes+=("$subvol")
    done

    echo "Mounting subvolumes..."
    for subvol in "${subvolumes[@]}"; do
        mkdir -p "$mount_point/$subvol"
        mount -o subvol="$subvol" "$device" "$mount_point/$subvol"
        echo "Mounted subvolume $subvol at $mount_point/$subvol"
    done
}

# Function to unmount subvolumes
unmount_subvolumes() {
    read -rp "Enter the mount point (e.g., /mnt): " mount_point

    [ -z "$mount_point" ] && { echo "Mount point cannot be empty."; exit 1; }

    echo "Unmounting subvolumes..."
    for subvol in "${subvolumes[@]}"; do
        umount "$mount_point/$subvol"
        echo "Unmounted subvolume $subvol from $mount_point/$subvol"
    done

    umount "$mount_point"
    echo "Unmounted device from $mount_point"
}

# Function to automatically setup chroot environment
auto_chroot() {
    read -rp "Enter the chroot directory (e.g., /mnt): " chroot_dir
    [ -z "$chroot_dir" ] && { echo "Chroot directory cannot be empty."; exit 1; }

    echo "Setting up chroot environment..."

    CHROOT_ACTIVE_MOUNTS=()
    trap 'chroot_teardown' EXIT

    chroot_add_mount proc "$chroot_dir/proc" -t proc -o nosuid,noexec,nodev &&
    chroot_add_mount sys "$chroot_dir/sys" -t sysfs -o nosuid,noexec,nodev,ro &&
    chroot_add_mount udev "$chroot_dir/dev" -t devtmpfs -o mode=0755,nosuid &&
    chroot_add_mount devpts "$chroot_dir/dev/pts" -t devpts -o mode=0620,gid=5,nosuid,noexec &&
    chroot_add_mount shm "$chroot_dir/dev/shm" -t tmpfs -o mode=1777,nosuid,nodev &&
    chroot_add_mount run "$chroot_dir/run" -t tmpfs -o nosuid,nodev,mode=0755 &&
    chroot_add_mount tmp "$chroot_dir/tmp" -t tmpfs -o mode=1777,strictatime,nodev,nosuid

    SHELL=/bin/bash chroot "$chroot_dir"
}

# Function to teardown the chroot environment
chroot_teardown() {
    if (( ${#CHROOT_ACTIVE_MOUNTS[@]} )); then
        umount "${CHROOT_ACTIVE_MOUNTS[@]}"
    fi
    unset CHROOT_ACTIVE_MOUNTS
}

# Helper function to add mounts
chroot_add_mount() {
    mount "$@" && CHROOT_ACTIVE_MOUNTS=("$2" "${CHROOT_ACTIVE_MOUNTS[@]}")
}

# Main script logic
check_root

while true; do
    display_menu
    read -rp "Select an option (1-4): " option

    case $option in
        1)
            mount_subvolumes
            ;;
        2)
            unmount_subvolumes
            ;;
        3)
            auto_chroot
            ;;
        4)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option. Please try again."
            ;;
    esac
done
