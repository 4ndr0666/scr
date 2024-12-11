#!/usr/bin/env bash
# File: fix_pacman_db_dupes_final.sh
# Purpose: Resolves duplicated pacman database entries by removing all duplicates first,
#          then reinstalling all affected packages in a single operation.

set -euo pipefail
IFS=$'\n\t'

# List of affected packages
PACKAGES=(
    spirv-tools
    pkgconf
    ffmpeg
    systemd-sysvcompat
    fluidsynth
    systemd-resolvconf
    shaderc
    noto-fonts
    libplacebo
    gnupg
    libbpf
    python-coverage
    libtool
)

# Step 1: Remove all duplicated DB entries
echo "Removing duplicated pacman database entries..."
for pkg in "${PACKAGES[@]}"; do
    echo "Processing package: $pkg"
    sudo pacman -D --dbonly --remove "$pkg" || echo "Warning: Failed to remove $pkg from pacman DB."
done

# Step 2: Reinstall all packages in a single Pacman operation
echo "Reinstalling all affected packages in a single operation..."
sudo pacman -S --noconfirm "${PACKAGES[@]}"

echo "Duplicated pacman database entries resolved successfully."

# Step 3: Re-enable Pacman hooks
echo "Re-enabling Pacman hooks..."
sudo mv /usr/share/libalpm/hooks.disabled /usr/share/libalpm/hooks

echo "Pacman hooks re-enabled."
