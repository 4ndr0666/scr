#!/bin/bash

# Script Name: setup_amdgpu.sh
# Description: Automates the setup and configuration of the amdgpu driver on Arch Linux.
# Author: ChatGPT
# Date: 2025-01-21
# Version: 1.2

# Exit immediately if a command exits with a non-zero status.
set -e

# Variables
GRUB_CONFIG="/etc/default/grub"
XORG_CONFIG="/etc/X11/xorg.conf"
BACKUP_SUFFIX=".backup_$(date +%F_%T)"
AMDGPU_PACKAGES=("amdgpu" "mesa" "mesa-vulkan-radeon")
DEPENDENCIES=("yay" "git" "base-devel")
GRUB_PARAMETERS="amdgpu.si_support=1 radeon.si_support=0"

# Functions

# Automatic Privilege Escalation
ensure_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Script is not running as root. Attempting to elevate privileges..."
        exec sudo "$0" "$@"
    fi
}

# Trap Interrupt Signals
trap_interrupt() {
    trap "echo 'Script interrupted by user. Exiting...'; exit 1" INT TERM
}

# Display Help
show_help() {
    echo "Usage: sudo bash setup_amdgpu.sh [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help         Display this help message and exit."
    echo "  install            Install amdgpu and related packages."
    echo "  configure-grub     Modify GRUB configuration to prefer amdgpu driver."
    echo "  backup-xorg        Backup existing Xorg configuration."
    echo "  generate-xorg      Generate new Xorg configuration for amdgpu."
    echo "  update-mesa        Update Mesa packages."
    echo "  install-deps       Install necessary dependencies (e.g., yay)."
    echo "  reboot             Reboot the system to apply changes."
    echo "  verify             Verify driver usage and renderer."
    echo ""
    echo "If no valid option is provided, the help message will be displayed."
}

# Install Dependencies
install_dependencies() {
    echo "Checking and installing necessary dependencies..."
    for dep in "${DEPENDENCIES[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            echo "Installing dependency: $dep"
            if [ "$dep" == "yay" ]; then
                pacman -S --needed git base-devel --noconfirm
                git clone https://aur.archlinux.org/yay.git /tmp/yay
                cd /tmp/yay && makepkg -si --noconfirm
                cd ~
                rm -rf /tmp/yay
            else
                pacman -S --needed "$dep" --noconfirm
            fi
        else
            echo "Dependency '$dep' is already installed. Skipping."
        fi
    done
    echo "Dependency installation completed."
}

# Install amdgpu and related packages
install_packages() {
    echo "Checking and installing necessary packages..."
    for pkg in "${AMDGPU_PACKAGES[@]}"; do
        if ! pacman -Qs "^${pkg}$" > /dev/null ; then
            echo "Installing package: $pkg"
            pacman -S --noconfirm "$pkg"
        else
            echo "Package '$pkg' is already installed. Skipping."
        fi
    done
    echo "Package installation completed."
}

# Modify GRUB configuration
configure_grub() {
    echo "Configuring GRUB to prefer amdgpu driver..."
    if grep -q "$GRUB_PARAMETERS" "$GRUB_CONFIG"; then
        echo "GRUB is already configured with the necessary parameters. Skipping."
    else
        echo "Backing up existing GRUB configuration..."
        cp "$GRUB_CONFIG" "${GRUB_CONFIG}${BACKUP_SUFFIX}"
        echo "Adding amdgpu parameters to GRUB_CMDLINE_LINUX..."
        sed -i "s/^GRUB_CMDLINE_LINUX=\"\(.*\)\"/GRUB_CMDLINE_LINUX=\"\1 $GRUB_PARAMETERS\"/" "$GRUB_CONFIG"
        echo "Updating GRUB configuration..."
        grub-mkconfig -o /boot/grub/grub.cfg
        echo "GRUB configuration updated successfully."
    fi
}

# Backup Xorg configuration
backup_xorg() {
    echo "Backing up existing Xorg configuration..."
    if [ -f "$XORG_CONFIG" ]; then
        cp "$XORG_CONFIG" "${XORG_CONFIG}${BACKUP_SUFFIX}"
        echo "Backup created at ${XORG_CONFIG}${BACKUP_SUFFIX}"
    else
        echo "No existing Xorg configuration found. Skipping backup."
    fi
}

# Generate new Xorg configuration for amdgpu
generate_xorg() {
    echo "Generating new Xorg configuration for amdgpu..."
    Xorg -configure &> /dev/null
    if [ -f "$HOME/xorg.conf.new" ]; then
        mv "$HOME/xorg.conf.new" "$XORG_CONFIG"
        echo "New Xorg configuration generated at $XORG_CONFIG"
    else
        echo "Failed to generate new Xorg configuration. Please check X server logs."
        exit 1
    fi
}

# Update Mesa packages
update_mesa() {
    echo "Updating Mesa packages..."
    pacman -Syu --noconfirm mesa mesa-vulkan-radeon
    echo "Mesa packages updated successfully."
}

# Reboot the system
reboot_system() {
    echo "Rebooting the system to apply changes..."
    reboot
}

# Verify driver usage and renderer
verify_setup() {
    echo "Verifying driver usage..."
    lspci -k | grep -EA3 'VGA|3D|Display'

    echo ""
    echo "Checking OpenGL renderer:"
    if command -v glxinfo >/dev/null 2>&1; then
        glxinfo | grep "OpenGL renderer"
    else
        echo "'glxinfo' is not installed. Installing mesa-demos for glxinfo..."
        pacman -S mesa-demos --noconfirm
        glxinfo | grep "OpenGL renderer"
    fi

    echo ""
    echo "Checking Vulkan renderer:"
    if command -v vulkaninfo >/dev/null 2>&1; then
        vulkaninfo | grep "deviceName"
    else
        echo "'vulkaninfo' is not installed. Installing vulkan-tools..."
        pacman -S vulkan-tools --noconfirm
        vulkaninfo | grep "deviceName"
    fi
}

# Handle Unrecognized Commands
unrecognized_command() {
    echo "Error: Unrecognized command '$1'"
    echo ""
    show_help
    exit 1
}

# Enhanced Error Handling
handle_error() {
    echo "An unexpected error occurred. Exiting..."
    exit 1
}

# Main Script Logic

# Ensure the script is run as root
ensure_root "$@"

# Trap interrupt signals
trap_interrupt

# If no arguments are provided, show help
if [ "$#" -eq 0 ]; then
    show_help
    exit 0
fi

# Parse command-line arguments
case "$1" in
    -h|--help)
        show_help
        ;;
    install-deps)
        install_dependencies
        ;;
    install)
        install_packages
        ;;
    configure-grub)
        configure_grub
        ;;
    backup-xorg)
        backup_xorg
        ;;
    generate-xorg)
        generate_xorg
        ;;
    update-mesa)
        update_mesa
        ;;
    reboot)
        reboot_system
        ;;
    verify)
        verify_setup
        ;;
    *)
        unrecognized_command "$1"
        ;;
esac

# Trap any unexpected errors
trap 'handle_error' ERR
