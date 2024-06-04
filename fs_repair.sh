#!/bin/bash
# File: FixFileSystems.sh
# Author: 4ndr0666
# Edited: 02-06-24
# Description: Diagnoses and fixes file system recognition issues in Garuda Linux.

# --- // Functions

# Check and Load Kernel Modules
check_load_modules() {
    echo "Checking and loading necessary kernel modules..."
    local modules=("ext4" "btrfs" "xfs")
    for module in "${modules[@]}"; do
        if ! lsmod | grep -q "$module"; then
            echo "Loading $module module..."
            sudo modprobe "$module"
        else
            echo "$module module is already loaded."
        fi
    done
}

# Update System
update_system() {
    echo "Updating system..."
    sudo pacman -Syu
}

# Install File System Utilities
install_fs_utilities() {
    echo "Installing file system utilities..."
    sudo pacman -S btrfs-progs xfsprogs
}

# Check Kernel Messages for Errors
check_dmesg_errors() {
    echo "Checking kernel messages for file system errors..."
    dmesg | grep -i filesystem
}

# Main Function
main() {
    check_load_modules
    update_system
    install_fs_utilities
    check_dmesg_errors
}

# Execute Main Function
main