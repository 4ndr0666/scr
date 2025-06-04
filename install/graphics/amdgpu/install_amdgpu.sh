#!/bin/bash
# shellcheck disable=all
# File: install_amdgpu.sh
# Author: 4ndr0666
# Date: 2025-01-21
# Desc: Automates the setup and configuration of the amdgpu driver on Arch Linux with Wayfire and Wayland.
set -e

# =================== // INSTALL_AMDGPU.SH //
GRUB_CONFIG="/etc/default/grub"
WAYFIRE_CONFIG_DIR="$HOME/.config/wayfire"
BACKUP_SUFFIX=".backup_$(date +%F_%T)"
PACMAN_PACKAGES=("mesa" "vulkan-radeon" "vulkan-mesa-layers" "wayfire" "waybar" "pipewire" "pipewire-pulse" "wireplumber" "vulkan-tools" "linux-firmware" "wl-clipboard" "swaybg" "wlr-randr" "kanshi" "nwg-displays")
DEPENDENCIES=("yay" "git" "base-devel")
GRUB_PARAMETERS="amdgpu.si_support=1 radeon.si_support=0"
BLACKLIST_FILE="/etc/modprobe.d/blacklist-radeon.conf"
LOGFILE="/var/log/setup_amdgpu.log"

# Redirect all output to log file with timestamps
exec > >(tee -a "$LOGFILE") 2>&1

# Functions

# Automatic Privilege Escalation
ensure_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Script is not running as root. Attempting to elevate privileges..."
        exec sudo bash "$0" "$@"
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
    echo "  -h, --help               Display this help message and exit."
    echo "  install-deps             Install necessary dependencies (e.g., yay)."
    echo "  install                  Install Mesa packages, Wayfire, Wayland tools, Vulkan support, and Vulkan Mesa layers."
    echo "  install-firmware         Install required firmware for amdgpu."
    echo "  configure-grub           Modify GRUB configuration to prefer amdgpu driver."
    echo "  blacklist-radeon        Blacklist the radeon driver to prevent it from loading."
    echo "  rebuild-initramfs        Rebuild initramfs to apply changes."
    echo "  configure-wayfire        Configure Wayfire settings for optimal performance."
    echo "  install-wayland-tools    Install essential Wayland tools and libraries."
    echo "  reboot                   Reboot the system to apply changes."
    echo "  verify                   Verify driver usage and renderer."
    echo "  all                      Execute all setup steps in order."
    echo ""
    echo "If no valid option is provided, the help message will be displayed."
}

# Install Dependencies
install_dependencies() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Checking and installing necessary dependencies..."
    for dep in "${DEPENDENCIES[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Installing dependency: $dep"
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
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Dependency '$dep' is already installed. Skipping."
        fi
    done
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Dependency installation completed."
}

# Install Official Repository Packages
install_packages() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Checking and installing necessary official packages..."
    for pkg in "${PACMAN_PACKAGES[@]}"; do
        if ! pacman -Qs "^${pkg}$" > /dev/null ; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Installing package: $pkg"
            pacman -S --noconfirm "$pkg"
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Package '$pkg' is already installed. Skipping."
        fi
    done
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Official package installation completed."
}

# Install required firmware for amdgpu
install_firmware() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Installing required firmware for amdgpu..."
    if pacman -Qs "^linux-firmware$" > /dev/null ; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Package 'linux-firmware' is already installed. Skipping."
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Installing 'linux-firmware'..."
        pacman -S --noconfirm linux-firmware
    fi
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Firmware installation completed."
}

# Modify GRUB configuration
configure_grub() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Configuring GRUB to prefer amdgpu driver..."
    if grep -q "$GRUB_PARAMETERS" "$GRUB_CONFIG"; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - GRUB is already configured with the necessary parameters. Skipping."
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Backing up existing GRUB configuration..."
        cp "$GRUB_CONFIG" "${GRUB_CONFIG}${BACKUP_SUFFIX}"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Adding amdgpu parameters to GRUB_CMDLINE_LINUX..."
        sed -i "s/^GRUB_CMDLINE_LINUX=\"\(.*\)\"/GRUB_CMDLINE_LINUX=\"\1 $GRUB_PARAMETERS\"/" "$GRUB_CONFIG"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Updating GRUB configuration..."
        grub-mkconfig -o /boot/grub/grub.cfg
        echo "$(date '+%Y-%m-%d %H:%M:%S') - GRUB configuration updated successfully."
    fi
}

# Blacklist the radeon driver
blacklist_radeon() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Blacklisting the radeon driver to prevent it from loading..."
    if [ -f "$BLACKLIST_FILE" ]; then
        if grep -q "blacklist radeon" "$BLACKLIST_FILE"; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - The radeon driver is already blacklisted. Skipping."
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Adding blacklist entry for radeon driver."
            echo "blacklist radeon" >> "$BLACKLIST_FILE"
        fi
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Creating blacklist configuration file and blacklisting radeon driver."
        echo "blacklist radeon" | tee "$BLACKLIST_FILE" > /dev/null
    fi
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Blacklisting completed."
}

# Rebuild initramfs
rebuild_initramfs() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Rebuilding initramfs to apply changes..."
    mkinitcpio -P
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Initramfs rebuilt successfully."
}

# Configure Wayfire settings
configure_wayfire() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Configuring Wayfire for optimal amdgpu performance..."
    mkdir -p "$WAYFIRE_CONFIG_DIR"
    
    WAYFIRE_CONFIG_FILE="$WAYFIRE_CONFIG_DIR/wayfire.ini"
    
    if [ ! -f "$WAYFIRE_CONFIG_FILE" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Creating default Wayfire configuration..."
        cat <<EOF > "$WAYFIRE_CONFIG_FILE"
[core]
backend = wayland

[core-output]
disable-effects = none

[debug]
log-level = info
EOF
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Wayfire configuration created at $WAYFIRE_CONFIG_FILE"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Wayfire configuration already exists. Skipping creation."
    fi
    
    # Additional Wayfire-specific configurations can be added here
    # For example, enabling specific plugins or performance tweaks
}

# Install essential Wayland tools and libraries
install_wayland_tools() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Installing essential Wayland tools and libraries..."
    local wayland_tools=("wl-clipboard" "swaybg" "waybar" "wlr-randr" "kanshi" "nwg-displays")
    for tool in "${wayland_tools[@]}"; do
        if ! pacman -Qs "^${tool}$" > /dev/null ; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Installing Wayland tool: $tool"
            pacman -S --noconfirm "$tool"
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Wayland tool '$tool' is already installed. Skipping."
        fi
    done
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Wayland tools installation completed."
}

# Reboot the system
reboot_system() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Rebooting the system to apply changes..."
    reboot
}

# Verify driver usage and renderer
verify_setup() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Verifying driver usage and renderer..."
    
    echo ""
    echo "Checking active GPU drivers:"
    lspci -k | grep -EA3 'VGA|3D|Display'
    
    echo ""
    echo "Checking if amdgpu module is loaded:"
    if lsmod | grep amdgpu >/dev/null 2>&1; then
        echo "amdgpu module is loaded."
    else
        echo "amdgpu module is not loaded. Attempting to load amdgpu..."
        modprobe amdgpu || {
            echo "Failed to load amdgpu module. Please check dmesg for errors."
            exit 1
        }
        echo "amdgpu module loaded successfully."
    fi
    
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
    
    echo ""
    echo "Checking Vulkan Mesa layers:"
    if pacman -Qs "^vulkan-mesa-layers$" > /dev/null ; then
        echo "vulkan-mesa-layers is installed."
    else
        echo "vulkan-mesa-layers is not installed. Installing..."
        pacman -S --noconfirm vulkan-mesa-layers
        echo "vulkan-mesa-layers installed successfully."
    fi
    
    echo ""
    echo "Checking Wayfire compositor status:"
    if pgrep wayfire >/dev/null 2>&1; then
        echo "Wayfire is running."
    else
        echo "Wayfire is not running. Starting Wayfire..."
        wayfire &
        sleep 5
        if pgrep wayfire >/dev/null 2>&1; then
            echo "Wayfire started successfully."
        else
            echo "Failed to start Wayfire. Please check Wayfire configurations."
        fi
    fi
    
    # Additional Dynamic Remediation Steps
    echo ""
    echo "Performing dynamic remediation based on system state..."
    
    # Verify Firmware Files
    echo "Checking for required firmware files..."
    REQUIRED_FIRMWARE=("si_pitcairn_le.bin")
    MISSING_FIRMWARE=()
    for fw in "${REQUIRED_FIRMWARE[@]}"; do
        if [ ! -f "/usr/lib/firmware/amdgpu/$fw" ]; then
            echo "Missing firmware file: $fw"
            MISSING_FIRMWARE+=("$fw")
        fi
    done
    
    if [ "${#MISSING_FIRMWARE[@]}" -ne 0 ]; then
        echo "Attempting to install missing firmware..."
        pacman -S --noconfirm linux-firmware || {
            echo "Failed to install linux-firmware. Please install it manually."
            exit 1
        }
        echo "Missing firmware installed. Rebuilding initramfs..."
        rebuild_initramfs
        echo "Rebooting to apply firmware changes..."
        reboot_system
    else
        echo "All required firmware files are present."
    fi
    
    echo ""
    echo "Verification completed successfully."
}

# Handle Unrecognized Commands
unrecognized_command() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Error: Unrecognized command '$1'"
    echo ""
    show_help
    exit 1
}

# Enhanced Error Handling
handle_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - An unexpected error occurred. Please check the log file at $LOGFILE for details."
    exit 1
}

# Execute All Setup Steps
execute_all() {
    install_dependencies
    install_packages
    install_firmware
    configure_grub
    blacklist_radeon
    rebuild_initramfs
    configure_wayfire
    install_wayland_tools
    reboot_system
}

# Main Script Logic

# Ensure the script is run as root
ensure_root "$@"

# Trap interrupt signals
trap_interrupt

# Trap any unexpected errors
trap 'handle_error' ERR

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
    install-firmware)
        install_firmware
        ;;
    configure-grub)
        configure_grub
        ;;
    blacklist-radeon)
        blacklist_radeon
        ;;
    rebuild-initramfs)
        rebuild_initramfs
        ;;
    configure-wayfire)
        configure_wayfire
        ;;
    install-wayland-tools)
        install_wayland_tools
        ;;
    reboot)
        reboot_system
        ;;
    verify)
        verify_setup
        ;;
    all)
        execute_all
        ;;
    *)
        unrecognized_command "$1"
        ;;
esac
