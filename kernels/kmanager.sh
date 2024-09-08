#!/bin/bash
# Refactored and Comprehensive Kernel Management Script

# Function to check hardware compatibility before kernel operations
check_hardware() {
    echo "Checking hardware compatibility..."

    if systemd-detect-virt --vm &>/dev/null; then
        echo "Running in a virtual machine. Ensure kernel operations are compatible."
    fi

    local cpu_vendor
    cpu_vendor=$(grep -m1 -w "^vendor_id" /proc/cpuinfo | awk '{print $3}')
    case "$cpu_vendor" in
        GenuineIntel)
            echo "Intel CPU detected."
            ;;
        AuthenticAMD)
            echo "AMD CPU detected."
            ;;
        *)
            echo "Unrecognized CPU type."
            ;;
    esac
}

# Function to list installed kernels
list_kernels() {
    echo "Listing installed kernels..."
    local kernels
    kernels=$(pacman -Qqe | grep -E '^linux[0-9]{0,1}(-lts|-zen|-hardened)?$')
    
    if [ -n "$kernels" ]; then
        for kernel in $kernels; do
            local name version release arch
            name=$(echo "$kernel" | sed -E 's/([a-zA-Z0-9@_+][a-zA-Z0-9@._+-]+)-([0-9:]*[^:/\-\ \t]+)-([0-9.]+)-([a-z0-9_]+)$/\1/')
            version=$(echo "$kernel" | sed -E 's/.*-([0-9:]*[^:/\-\ \t]+)-([0-9.]+)-([a-z0-9_]+)$/\1/')
            release=$(echo "$kernel" | sed -E 's/.*-([0-9.]+)-([a-z0-9_]+)$/\1/')
            arch=$(echo "$kernel" | sed -E 's/.*-([a-z0-9_]+)$/\1/')
            echo "Name: $name, Version: $version, Release: $release, Arch: $arch"
        done
    else
        echo "No installed kernels found."
    fi
}

# Function to list available kernels
list_available_kernels() {
    echo "Listing available kernels..."
    local kernels
    kernels=$(pacman -Ssq linux | grep -E '^linux[0-9]{0,1}(-lts|-zen|-hardened)?$')
    
    if [ -n "$kernels" ]; then
        for kernel in $kernels; do
            local name version release arch
            name=$(echo "$kernel" | sed -E 's/([a-zA-Z0-9@_+][a-zA-Z0-9@._+-]+)-([0-9:]*[^:/\-\ \t]+)-([0-9.]+)-([a-z0-9_]+)$/\1/')
            version=$(echo "$kernel" | sed -E 's/.*-([0-9:]*[^:/\-\ \t]+)-([0-9.]+)-([a-z0-9_]+)$/\1/')
            release=$(echo "$kernel" | sed -E 's/.*-([0-9.]+)-([a-z0-9_]+)$/\1/')
            arch=$(echo "$kernel" | sed -E 's/.*-([a-z0-9_]+)$/\1/')
            echo "Name: $name, Version: $version, Release: $release, Arch: $arch"
        done
    else
        echo "No available kernels found."
    fi
}

# Function to install a kernel and optionally its headers
install_kernel() {
    local kernel_name="$1"
    echo "Installing kernel: $kernel_name"

    # Optimize mirrorlist using reflector (simplified)
    local best_mirror
    best_mirror=$(curl -s "https://archlinux.org/mirrorlist/?country=all&protocol=https&use_mirror_status=on" | grep "^## " | head -n 1 | awk '{print $2}')
    sudo reflector --country "$best_mirror" --latest 200 --age 24 --sort rate --save /etc/pacman.d/mirrorlist

    # Execute commands with root privileges
    sudo pacman -Syu --noconfirm "$kernel_name" "$kernel_name-headers"

    rebuild_initramfs_or_dracut
    update_grub
}

# Function to remove a kernel and optionally its headers
remove_kernel() {
    local kernel_name="$1"
    echo "Removing kernel: $kernel_name"

    sudo pacman -Rns --noconfirm "$kernel_name" "$kernel_name-headers"

    update_grub
}

# Function to rebuild initramfs or dracut
rebuild_initramfs_or_dracut() {
    if command -v dracut >/dev/null 2>&1; then
        echo "Rebuilding initramfs with dracut..."
        sudo dracut --force
    else
        echo "Rebuilding initramfs with mkinitcpio..."
        sudo mkinitcpio -P
    fi
}

# Function to update GRUB configuration
update_grub() {
    echo "Updating GRUB configuration..."
    sudo grub-mkconfig -o /boot/grub/grub.cfg
}

# Function to display a waiting indicator (simplified)
show_waiting_indicator() {
    echo -n "Processing..."
    for i in {1..10}; do
        echo -n "."
        sleep 1
    done
    echo " Done."
}

# Function to run commands in a terminal (simplified)
run_in_terminal() {
    local cmd="$*"
    x-terminal-emulator -e "$cmd"
}

# Function to set keyboard layout based on location (simplified)
set_keyboard_layout() {
    local country
    country=$(curl -s https://ipapi.co/country_code/ | tr '[:upper:]' '[:lower:]')
    case "$country" in
        'de'|'fi'|'se')
            setxkbmap "$country"
            echo "Setting keyboard layout to: $country"
            ;;
        *)
            echo "No specific keyboard layout set for country code: $country"
            ;;
    esac
}

# Function to introduce a sleep counter for long-running tasks (simplified)
sleep_counter() {
    local seconds="$1"
    local prompt="$2"
    for ((s=seconds; s>0; s--)); do
        echo -ne "$prompt ($s seconds remaining)\r"
        sleep 1
    done
    echo -ne "\n"
}

# Main function to handle user options
main() {
    case "$1" in
        check-hardware)
            check_hardware
            ;;
        list-kernels)
            list_kernels
            ;;
        list-available)
            list_available_kernels
            ;;
        install)
            if [ -z "$2" ]; then
                echo "Usage: $0 install <kernel_name>"
                exit 1
            fi
            show_waiting_indicator &
            install_kernel "$2"
            ;;
        remove)
            if [ -z "$2" ]; then
                echo "Usage: $0 remove <kernel_name>"
                exit 1
            fi
            show_waiting_indicator &
            remove_kernel "$2"
            ;;
        rebuild-initramfs-or-dracut)
            rebuild_initramfs_or_dracut
            ;;
        update-grub)
            update_grub
            ;;
        set-keyboard-layout)
            set_keyboard_layout
            ;;
        sleep-counter)
            sleep_counter "${@:2}"
            ;;
        run-in-terminal)
            run_in_terminal "${@:2}"
            ;;
        *)
            echo "Usage: $0 {check-hardware|list-kernels|list-available|install|remove|rebuild-initramfs-or-dracut|update-grub|set-keyboard-layout|sleep-counter|run-in-terminal}"
            exit 1
            ;;
    esac
}

# Elevate privileges if not root
if [[ $EUID -ne 0 ]]; then
    exec sudo --preserve-env="PACMAN_EXTRA_OPTS" "$0" "$@"
    exit 1
fi

main "$@"
