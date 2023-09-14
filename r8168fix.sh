#!/bin/bash

# Function to display colored ASCII art
display_ascii_art() {
    echo -e "\e[32m" # Set color to green
    cat << "EOF"
          ______  ____  ________  ______  
  _______ /  __  \/_   |/  _____/ /  __  \ 
  \_  __ \>      < |   /   __  \  >      < 
   |  | \/   --   \|   \  |__\  \/   --   \
   |__|  \______  /|___|\_____  /\______  /
                \/            \/        \/ 
EOF
    echo -e "\e[0m" # Reset color
}

# Call the function to display the ASCII art
display_ascii_art

# Detect current kernel version
current_kernel=$(uname -r)
echo "Current Kernel Version: $current_kernel"

# Install necessary packages
echo "Installing necessary packages..."
sudo pacman -Sy --needed git dkms make gcc

# Backup current kernel modules
echo "Backing up current kernel modules..."
sudo cp -a /usr/lib/modules/$(uname -r) /usr/lib/modules/backup/

# Remove current initramfs images
echo "Removing current initramfs images..."
sudo rm -f /boot/initramfs-$(uname -r).img

# Remove current DKMS modules
echo "Removing current DKMS modules..."
sudo dkms remove r8168/$(dkms status r8168 | awk '{print $2}' | head -n 1) --all

# Copy backed up modules for the current kernel version
echo "Restoring backed up kernel modules..."
sudo rsync -AHXal --ignore-existing /usr/lib/modules/backup/$(uname -r) /usr/lib/modules/

# Update module dependencies
echo "Updating module dependencies..."
sudo depmod

# Install new DKMS modules
echo "Installing new DKMS modules..."
sudo dkms install r8168/$(dkms status r8168 | awk '{print $2}' | head -n 1)

# Reload the new driver
echo "Reloading the r8168 driver..."
sudo modprobe -r r8169
sudo modprobe r8168

echo "Driver installation complete."
