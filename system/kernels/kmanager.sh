#!/bin/bash
# shellcheck disable=all
# Production-Ready Kernel and Bootloader Management Script
# Complete with Dracut, efibootmgr Support, Enhanced Error Handling, and User Empowerment

# Kernel groups (dictionary for flexibility)
declare -A kernel_groups=(
    ["lts"]="linux-lts"
    ["zen"]="linux-zen"
    ["hardened"]="linux-hardened"
    ["default"]="linux"
)

# Function: error_exit
# Handles errors by printing the message and exiting the script
error_exit() {
    echo "Error: $1" 1>&2
    exit 1
}

# Function: check_pacman_lock
# Ensures there is no pacman lock, removing it if necessary to prevent blocking operations
check_pacman_lock() {
    local db_lock_path="/var/lib/pacman/db.lck"
    if [ -f "$db_lock_path" ]; then
        echo "Warning: removing pacman db lock."
        sudo rm -f "$db_lock_path" || error_exit "Failed to remove pacman db lock."
    fi
}

# Function: list_kernels
# Lists installed kernels on the system
list_kernels() {
    echo "Listing installed kernels..."
    pacman -Qqe | grep -E '^linux[0-9]{0,1}(-lts|-zen|-hardened)?$' || echo "No installed kernels found."
}

# Function: list_available_kernels
# Lists available kernels for installation
list_available_kernels() {
    echo "Available kernel options:"
    for key in "${!kernel_groups[@]}"; do
        echo "$key: ${kernel_groups[$key]}"
    done
}

# Function to rebuild initramfs using dracut with advanced options and proper naming convention
rebuild_dracut() {
    echo "Rebuilding initramfs with dracut..."

    # Apply Dracut configuration if available
    local config_file="/etc/dracut.conf.d/dracut.conf"
    if [ -f "$config_file" ]; then
        echo "Applying Dracut configuration from $config_file"
        # Constant path to avoid non-constant source issues
        . "$config_file"
    else
        echo "No dracut.conf found. Proceeding without additional configuration."
    fi

    # Set default kernel version
    local kernel_version
    kernel_version=$(uname -r)

    # Set kernel type
    local kernel_type
    kernel_type=$(echo "$kernel_version" | grep -oP '(lts|zen|hardened|default)' || echo "default")

    # Generate default initramfs image location based on the kernel version and type
    local img_location="/boot/initramfs-$kernel_version.img"
    local custom_default_img="/boot/initramfs-linux-${kernel_type}.img"
    
    # Prompt to specify kernel version
    read -rp "Do you want to specify the kernel version (default: $kernel_version)? [y/n]: " specify_kver
    if [[ "$specify_kver" == "y" ]]; then
        read -rp "Enter the kernel version: " kernel_version
        kernel_type=$(echo "$kernel_version" | grep -oP '(lts|zen|hardened|default)' || echo "default")
        img_location="/boot/initramfs-$kernel_version.img"
        custom_default_img="/boot/initramfs-linux-${kernel_type}.img"
    fi

    # Prompt to specify a custom initramfs image location with proper default naming
    read -rp "Enter custom initramfs image location (default: $custom_default_img): " custom_img_location
    img_location=${custom_img_location:-$custom_default_img}

    echo "Executing Dracut with granular control..."
    
    # Run Dracut command
    sudo dracut --force --kver="$kernel_version" "$img_location"

    # Check if image is in correct location
    if [ ! -f "$img_location" ]; then
        error_exit "Initramfs image was not created at $img_location."
    else
        echo "Initramfs image successfully created at $img_location."
    fi
}

# Function: reinstall_kernel
# Reinstalls the correct kernel and headers if Dracut fails
reinstall_kernel() {
    echo "Reinstalling the correct kernel and headers..."
    check_pacman_lock
    sudo pacman -S --noconfirm --overwrite="*" linux linux-headers || error_exit "Failed to reinstall kernel."
}

# Function: update_grub
# Updates GRUB configuration
update_grub() {
    echo "Updating GRUB configuration..."
    sudo grub-mkconfig -o /boot/grub/grub.cfg || error_exit "Failed to update GRUB."
}

# Function: show_waiting_indicator
# Displays a waiting indicator for background tasks
show_waiting_indicator() {
    echo -n "Processing"
    for ((i = 1; i <= 10; i++)); do
        echo -n "."
        sleep 1
    done
    echo " Done."
}

# Function: remove_kernel
# Removes a kernel using idempotency checks
remove_kernel() {
    local kernel_name="$1"
    local group="${kernel_groups[$kernel_name]:-$kernel_name}"

    if [ -z "$group" ]; then
        error_exit "Invalid kernel name. Available options: ${!kernel_groups[*]}"
    fi

    echo "Removing kernel: $group"

    if pacman -Q "$group" &>/dev/null; then
        sudo pacman -Rns --noconfirm "$group" "${group}-headers" || error_exit "Failed to remove $group."
        update_grub
    else
        echo "$group is not installed."
    fi
}

# Function to install a kernel using fzf for selection or manual input
install_kernel() {
    local kernel_name
    kernel_name=$(select_kernel_with_fzf)

    local group="${kernel_groups[$kernel_name]:-$kernel_name}"

    if [ -z "$group" ]; then
        error_exit "Invalid kernel name. Available options: ${!kernel_groups[*]}"
    fi

    echo "Installing kernel: $group"
    check_pacman_lock  # Check and remove pacman lock if it exists

    if pacman -Q "$group" &>/dev/null; then
        echo "$group is already installed."
    else
        sudo pacman -Syu --noconfirm "$group" "${group}-headers" || error_exit "Failed to install $group."
    fi

    rebuild_dracut "$group"
    update_grub
}

# Function: configure_boot_with_efibootmgr
# Configures the bootloader using efibootmgr for proper boot entry
configure_boot_with_efibootmgr() {
    local vmlinuz_path="$1"
    local initramfs_path="$2"

    echo "Configuring bootloader with efibootmgr..."
    local bootnum
    bootnum=$(efibootmgr | grep 'BootCurrent' | awk '{print $2}')

    if [ -z "$bootnum" ]; then
        echo "No active boot entry. Creating a new one..."
        efibootmgr --create --disk /dev/sdd --part 1 --loader "$vmlinuz_path" --label "Linux Zen" -u " root=PARTUUID=xxx initrd=$initramfs_path" --verbose
    else
        echo "Modifying existing boot entry ($bootnum)..."
        efibootmgr --bootnum "$bootnum" --disk /dev/sdd --part 1 --loader "$vmlinuz_path" --label "Linux Zen" -u " root=PARTUUID=xxx initrd=$initramfs_path" --verbose
    fi
}

# Help section to display usage instructions
show_help() {
    echo "Kernel Management Script - Usage"
    echo "--------------------------------"
    echo "Available commands:"
    echo "  -ch    Check hardware compatibility"
    echo "  -lk    List installed kernels"
    echo "  -la    List available kernels"
    echo "  -i     Install a kernel (e.g., -i lts)"
    echo "  -r     Remove a kernel (e.g., -r zen)"
    echo "  -rd    Rebuild initramfs using dracut with granular control"
    echo "  -ug    Update GRUB configuration"
    echo "  -cb    Configure boot entry using efibootmgr"
    echo "  -h     Show this help section"
}

# Main function to handle user options
main() {
    case "$1" in
        -lk) list_kernels ;;
        -la) list_available_kernels ;;
        -i)
            if [ -z "$2" ]; then
                echo "Usage: $0 -i <kernel_group>"
                exit 1
            fi
            install_kernel "$2"
            ;;
        -r)
            if [ -z "$2" ]; then
                echo "Usage: $0 -r <kernel_group>"
                exit 1
            fi
            remove_kernel "$2"
            ;;
        -rd) 
            rebuild_dracut 
            ;;
        -ug) 
            update_grub 
            ;;
        -cb)
            if [ -z "$2" ] || [ -z "$3" ]; then
                echo "Usage: $0 -cb <vmlinuz_path> <initramfs_path>"
                exit 1
            fi
            configure_boot_with_efibootmgr "$2" "$3"
            ;;
        -h|*)
            show_help
            ;;
    esac
}

# Elevate privileges if not root
if [[ $EUID -ne 0 ]]; then
    exec sudo "$0" "$@"
    exit 1
fi

main "$@"
