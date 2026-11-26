#!/usr/bin/env bash
set -euo pipefail

# Configuration (expand $HOME cleanly — quoted tilde never expands in Bash)
config_file="${config_file:-backup_iso_config.cfg}"
work_dir="${work_dir:-${HOME}/arch-iso}"
out_dir="${out_dir:-${HOME}/arch-iso/out}"
required_packages=("archiso" "git" "rsync" "cdrtools")

load_config() {
  if [[ -f "$config_file" ]]; then
    # shellcheck source=/dev/null
    source "$config_file"
  fi
}

install_packages() {
  local pkg
  for pkg in "${required_packages[@]}"; do
    if ! pacman -Qi "$pkg" &>/dev/null; then
      echo "Installing $pkg..."
      sudo pacman -S --noconfirm --needed "$pkg"
    else
      echo "$pkg is already installed."
    fi
  done
}

install_yay() {
  if command -v yay &>/dev/null; then
    return 0
  fi
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    echo "Cannot build yay with makepkg as root." >&2
    return 1
  fi
  echo "Installing yay..."
  local tmpdir
  tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/system-iso-yay.XXXXXX")"
  trap 'rm -rf -- "$tmpdir"' RETURN
  git clone --depth 1 https://aur.archlinux.org/yay.git "$tmpdir/yay"
  (
    cd -- "$tmpdir/yay"
    makepkg -si --noconfirm
  )
}

install_user_packages() {
  local pkglist="${work_dir}/packages.x86_64"
  if [[ ! -f "$pkglist" ]]; then
    echo "No package list found at $pkglist — skipping user package install."
    return 0
  fi
  local pkg
  while IFS= read -r pkg; do
    pkg="${pkg%%#*}"
    pkg="${pkg//[[:space:]]/}"
    [[ -n "$pkg" ]] || continue
    if ! pacman -Qi "$pkg" &>/dev/null; then
      echo "Installing package $pkg..."
      sudo pacman -S --noconfirm --needed "$pkg"
    else
      echo "Package $pkg is already installed."
    fi
  done < "$pkglist"
}

create_backup() {
  local dest="$1"
  [[ -n "$dest" ]] || { echo "Backup directory cannot be empty." >&2; return 1; }
  mkdir -p -- "$dest"
  echo "Creating system backup..."
  sudo rsync -aAXv --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} / "$dest"
}

create_arch_iso() {
  mkdir -p -- "${out_dir}"
  echo "Creating Arch ISO..."
  sudo mkarchiso -v -w "${work_dir}/work" -o "${out_dir}" "${work_dir}"
}

create_backup_iso() {
  mkdir -p -- "${out_dir}"
  echo "Creating ISO from backup..."
  sudo mkisofs -o "${out_dir}/backup.iso" "$1"
}

main() {
  load_config
  install_packages
  install_yay
  install_user_packages

  local backup_dir
  read -rp "Enter the backup directory: " backup_dir
  create_backup "$backup_dir"
  create_arch_iso
  create_backup_iso "$backup_dir"

  echo "Done. ISOs created at ${out_dir}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
