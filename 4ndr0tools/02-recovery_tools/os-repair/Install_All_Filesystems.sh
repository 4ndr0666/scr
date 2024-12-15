#!/bin/bash

# File: fs_repair.sh
# Description: Diagnoses and fixes file system recognition issues by ensuring necessary kernel modules are loaded.
# Usage: Run this script as root to load essential file system modules and install required utilities.

# Exit on error, undefined variable usage, or pipeline failure
set -euo pipefail

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
    echo "$(date): $1" >> /var/log/fs_repair_script.log
}

# Function to check and load kernel modules
check_load_modules() {
    prominent "Checking and loading necessary kernel modules..."

    # List of commonly used file system modules
    local modules=("ext4" "btrfs" "xfs" "vfat" "fuse" "ntfs" "nfs" "iso9660" "reiserfs")

    # Determine current kernel version
    local kernel_version
    kernel_version=$(uname -r)

    echo "Current kernel version: $kernel_version"

    # Iterate over each module and attempt to load it
    for module in "${modules[@]}"; do
        if ! lsmod | grep -q "$module"; then
            echo "Loading $module module..."
            if modprobe "$module"; then
                echo "$module module loaded successfully."
                log "$module module loaded successfully."
            else
                bug "Failed to load $module module. Please check the system logs for details."
                log "Failed to load $module module."
            fi
        else
            echo "$module module is already loaded."
        fi
    done
}

# Function to install file system utilities
install_fs_utilities() {
    prominent "Installing file system utilities..."

    # List of file system utilities to install
    local packages=("btrfs-progs" "xfsprogs" "dosfstools" "ntfs-3g" "nfs-utils" "reiserfsprogs" "fuse3" "e2fsprogs" "udftools")

    # Iterate over each package and install it if not already installed
    for package in "${packages[@]}"; do
        if ! pacman -Qi "$package" > /dev/null 2>&1; then
            echo "Installing $package..."
            if pacman -S --noconfirm "$package"; then
                echo "$package installed successfully."
                log "$package installed successfully."
            else
                bug "Failed to install $package. Please check for errors and try again."
                log "Failed to install $package."
                exit 1
            fi
        else
            echo "$package is already installed."
        fi
    done
}

# Function to prompt user for confirmation
confirm() {
    while true; do
        read -r -p "Do you want to proceed with this step? (y/n): " choice
        case "$choice" in 
            y|Y ) return 0;;
            n|N ) return 1;;
            * ) echo "Invalid choice, please enter 'y' or 'n'.";;
        esac
    done
}

# Main Function
main() {
    check_load_modules
    if confirm "Do you want to install file system utilities (btrfs-progs, xfsprogs, dosfstools, ntfs-3g, nfs-utils, reiserfsprogs, fuse3, e2fsprogs, udftools)?"; then
        install_fs_utilities
    fi
    prominent "File system repair tasks completed."
}

# Execute Main Function
main
