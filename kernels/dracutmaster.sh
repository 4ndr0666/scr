#!/bin/bash

# Script to clean up old kernels, update to the latest kernel, and regenerate initramfs

echo "Starting Kernel cleanup and update process..."

# Check for and install the latest kernel
echo "Installing the latest kernel..."
sudo pacman -Syu --noconfirm linux linux-headers

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
        sudo rm -rf /lib/modules/$kernel
        sudo rm -f /boot/vmlinuz-$kernel
        sudo rm -f /boot/initramfs-$kernel.img
        sudo rm -f /boot/initramfs-$kernel-fallback.img
    fi
done

# Rebuild initramfs for the current kernel
echo "Rebuilding initramfs for the current kernel: $current_kernel"
sudo dracut --force --kver $current_kernel

# Update GRUB configuration
echo "Updating GRUB configuration..."
sudo grub-mkconfig -o /boot/grub/grub.cfg

echo "Kernel cleanup and update process complete. System is now up-to-date."

# Prompt to reboot the system
read -p "Would you like to reboot now? (y/N): " reboot_now
if [[ $reboot_now =~ ^[Yy]$ ]]; then
    echo "Rebooting..."
    sudo reboot
else
    echo "You can reboot later to apply the changes."
fi