#!/bin/bash

# Set the working directory
work_dir="/home/andro/arch-iso"

# Set the directory where the final ISO will be stored
out_dir="/home/andro/arch-iso/out"

# Install required packages for creating Arch ISO
required_packages=("archiso" "git")
for pkg in "${required_packages[@]}"; do
  if ! pacman -Qi "$pkg" > /dev/null 2>&1; then
    echo "Installing $pkg..."
    sudo pacman -S --noconfirm --needed "$pkg"
  else
    echo "$pkg is already installed"
  fi
done

# Install yay package manager if not already installed
yay_installed=$(pacman -Qs yay)
if [[ -z "$yay_installed" ]]; then
  echo "Installing yay..."
  git clone https://aur.archlinux.org/yay.git
  cd yay || exit
  makepkg -si --noconfirm
  cd ..
  rm -rf yay
fi

# Define the packages to install
packages=$(cat "${work_dir}/packages.x86_64")

# Check if packages are already installed and only install if needed
for pkg in $packages; do
  if pacman -Qi "$pkg" > /dev/null 2>&1; then
    echo "Package $pkg is already installed"
  else
    echo "Installing package $pkg"
    sudo pacman -S --noconfirm --needed "$pkg"
  fi
done

# Create the Arch ISO
sudo mkarchiso -v -w "${work_dir}/work" -o "${out_dir}" "${work_dir}"
