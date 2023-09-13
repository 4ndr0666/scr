#!/bin/bash

# Set the working directory
work_dir="~/arch-iso"

# Set the output directory
out_dir="~/arch-iso/out"

# Prompt the user for the backup directory
read -rp "Enter the backup directory: " backup_dir

# Install required packages for creating Arch ISO
required_packages=("archiso" "git" "rsync" "cdrtools")
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

# Create a backup of the system
echo "Creating system backup..."
sudo rsync -aAXv --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} / "$backup_dir"

# Create the Arch ISO
echo "Creating Arch ISO..."
sudo mkarchiso -v -w "${work_dir}/work" -o "${out_dir}" "${work_dir}"

# Create an ISO from the backup
echo "Creating ISO from backup..."
sudo mkisofs -o "${out_dir}/backup.iso" "$backup_dir"

echo "Done. ISOs created at ${out_dir}"

# To restore your system from the backup ISO, follow these steps:
# 1. Burn the backup ISO to a bootable USB drive.
# 2. Boot your system from the USB drive.
# 3. Mount your system's root partition (e.g., `sudo mount /dev/sdXY /mnt`).
# 4. Restore the backup (e.g., `sudo rsync -aAXv /path/to/backup/ /mnt`).
# 5. Reboot your system.
