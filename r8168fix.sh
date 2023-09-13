#!/bin/bash

# Detect current kernel version
current_kernel=$(uname -r)
echo "Current Kernel Version: $current_kernel"

# Install necessary packages
echo "Installing necessary packages..."
sudo pacman -Sy --needed git dkms make gcc

# Option to install from AUR or GitHub
read -p "Install from AUR or GitHub? (A/G): " choice

if [[ "$choice" == "A" || "$choice" == "a" ]]; then
  # Installing from AUR
  echo "Installing r8168-dkms from AUR..."
  git clone https://aur.archlinux.org/yay.git
  cd yay || exit
  makepkg -si
  cd .. || exit
  rm -rf yay
  yay -S r8168-dkms
elif [[ "$choice" == "G" || "$choice" == "g" ]]; then
  # Installing from GitHub
  echo "Installing r8168 from GitHub..."
  git clone https://github.com/mtorromeo/r8168.git
  cd r8168 || exit
  sudo make install
  cd .. || exit
  rm -rf r8168
else
  echo "Invalid choice. Exiting."
  exit 1
fi

# Reload the new driver
echo "Reloading the r8168 driver..."
sudo modprobe -r r8169
sudo modprobe r8168

echo "Driver installation complete."
