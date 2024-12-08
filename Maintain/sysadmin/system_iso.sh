#!/bin/bash

# Configuration
config_file="backup_iso_config.cfg"
work_dir="~/arch-iso"
out_dir="~/arch-iso/out"
required_packages=("archiso" "git" "rsync" "cdrtools")

# Load configuration
load_config() {
  if [[ -f "$config_file" ]]; then
    source "$config_file"
  fi
}

# Install required packages
install_packages() {
  for pkg in "${required_packages[@]}"; do
    if ! pacman -Qi "$pkg" &>/dev/null; then
      echo "Installing $pkg..."
      sudo pacman -S --noconfirm --needed "$pkg"
    else
      echo "$pkg is already installed."
    fi
  done
}

# Install yay package manager
install_yay() {
  if ! pacman -Qs yay &>/dev/null; then
    echo "Installing yay..."
    git clone https://aur.archlinux.org/yay.git
    pushd yay || exit
    makepkg -si --noconfirm
    popd
    rm -rf yay
  fi
}

# Install user-defined packages
install_user_packages() {
  packages=$(cat "${work_dir}/packages.x86_64")
  for pkg in $packages; do
    if ! pacman -Qi "$pkg" &>/dev/null; then
      echo "Installing package $pkg..."
      sudo pacman -S --noconfirm --needed "$pkg"
    else
      echo "Package $pkg is already installed."
    fi
  done
}

# Create system backup
create_backup() {
  echo "Creating system backup..."
  sudo rsync -aAXv --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} / "$1"
}

# Create Arch ISO
create_arch_iso() {
  echo "Creating Arch ISO..."
  sudo mkarchiso -v -w "${work_dir}/work" -o "${out_dir}" "${work_dir}"
}

# Create ISO from backup
create_backup_iso() {
  echo "Creating ISO from backup..."
  sudo mkisofs -o "${out_dir}/backup.iso" "$1"
}

# Main execution
main() {
  load_config
  install_packages
  install_yay
  install_user_packages

  read -rp "Enter the backup directory: " backup_dir
  create_backup "$backup_dir"
  create_arch_iso
  create_backup_iso "$backup_dir"

  echo "Done. ISOs created at ${out_dir}"
}

main
