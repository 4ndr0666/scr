#!/bin/bash
# shellcheck disable=all

# Script to clean up old kernels, update to the latest kernel, and regenerate initramfs

set -euo pipefail  # Enable strict error handling

# Log the start of the script
echo "Initilizing DracutMaster..."

# Update the package database and upgrade installed packages, including the kernel
echo "Ensuring the latest Zen kernel..."
sudo pacman -S --noconfirm --needed --overwrite="*" linux-zen linux-zen-headers

# Get the current running kernel version
current_kernel=$(uname -r)

# Get a list of all installed kernels
installed_kernels=$(ls /lib/modules)

echo "Current Kernel: $current_kernel"
echo "Installed Kernels:"
echo "$installed_kernels"

# Loop through all installed kernels and remove those that are not the current running kernel
for kernel in $installed_kernels; do
    if [ "$kernel" != "$current_kernel" ]; then
        echo "Removing old kernel: $kernel"
        
        # Use safe deletion with checks
        sudo rm -rf /lib/modules/"$kernel"
        [ -e /boot/vmlinuz-"$kernel" ] && sudo rm -f /boot/vmlinuz-"$kernel"
        [ -e /boot/initramfs-"$kernel".img ] && sudo rm -f /boot/initramfs-"$kernel".img
        [ -e /boot/initramfs-"$kernel"-fallback.img ] && sudo rm -f /boot/initramfs-"$kernel"-fallback.img
    fi
done

# Rebuild initramfs for the current kernel
echo "Rebuilding initramfs for the current kernel: $current_kernel"
sudo dracut --fstab --early-microcode --enhanced-cpio --force --kver=$current_kernel /boot/initramfs-linux-zen.img 

# Update GRUB configuration
echo "Updating GRUB configuration..."
sudo grub-install && grub-mkconfig -o /boot/grub/grub.cfg

echo "Kernel cleanup and update process complete. System is now up-to-date."

# Prompt to reboot the system
read -rp "Would you like to reboot now? (y/N): " reboot_now
if [[ $reboot_now =~ ^[Yy]$ ]]; then
    echo "Rebooting..."
    sudo reboot
else
    echo "You can reboot later to apply the changes."
fi
