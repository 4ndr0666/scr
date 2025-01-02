#!/bin/bash

# Automatically escalate privileges if not running as root
if [ "$(id -u)" -ne 0 ]; then
    sudo "$0" "$@"
    exit $?
fi

# Color and formatting definitions
GREEN='\033[0;32m'
BOLD='\033[1m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Symbols for visual feedback
SUCCESS="✔️"
FAILURE="❌"
INFO="➡️"
EXPLOSION="💥"

# Function to display prominent messages
prominent() {
    echo -e "${BOLD}${GREEN}$1${NC}"
}

# Function for errors
bug() {
    echo -e "${BOLD}${RED}$1${NC}"
}

# Logging function
log() {
    echo "$(date): $1" >> /var/log/r8169_module_script.log
}

# Function to mount necessary filesystems for chroot
mount_chroot() {
    local chroot_dir=$1
    mount --bind /dev "$chroot_dir/dev"
    mount --bind /proc "$chroot_dir/proc"
    mount --bind /sys "$chroot_dir/sys"
    mount --bind /run "$chroot_dir/run"
}

# Function to unmount filesystems after chroot
umount_chroot() {
    local chroot_dir=$1
    umount "$chroot_dir/dev"
    umount "$chroot_dir/proc"
    umount "$chroot_dir/sys"
    umount "$chroot_dir/run"
}

# Main function to manage and configure Garuda environment
manage_garuda() {
    local garuda_dir=$1
    
    prominent "$INFO Mounting necessary filesystems..."
    mount_chroot "$garuda_dir"

    prominent "$INFO Chrooting into Garuda environment..."
    chroot "$garuda_dir" /bin/bash -c "
        set -e

        # Ensure system is updated
        pacman -Syu

        # Install r8168 driver
        pacman -S r8168

        # Blacklist r8169 driver
        echo 'blacklist r8169' | tee -a /etc/modprobe.d/blacklist.conf

        # Remove r8168 from blacklist (if necessary)
        sed -i '/blacklist r8168/d' /etc/modprobe.d/blacklist.conf

        # Update initramfs
        mkinitcpio -P
    "

    prominent "$INFO Unmounting filesystems..."
    umount_chroot "$garuda_dir"

    prominent "$EXPLOSION Completed $EXPLOSION"
}

# Verify that the Garuda partition is specified
if [ -z "$1" ]; then
    bug "No Garuda partition specified. Usage: $0 /path/to/garuda"
    exit 1
fi

# Execute the main function with the provided Garuda directory
manage_garuda "$1"