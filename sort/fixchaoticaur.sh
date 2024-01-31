#!/bin/bash

# Check if the script is running as root
if (( EUID != 0 )); then
    echo "Please run as root"
    exit
fi

# Check if the public GPG key exists
if ! gpg --list-keys ultimatelytrust@example.com >/dev/null 2>&1; then
    # Create a new public GPG key
    echo "Creating new public GPG key..."
    if ! gpg --batch --gen-key <<EOF
        %no-protection
        Key-Type: RSA
        Key-Length: 4096
        Subkey-Type: RSA
        Subkey-Length: 4096
        Name-Real: Ultimately Trust
        Name-Email: ultimatelytrust@example.com
        Expire-Date: 0
        %commit
EOF
    then
        echo "Failed to generate GPG key"
        exit 1
    fi
fi

# Import the Chaotic AUR key
pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com

# Sign the key locally
pacman-key --lsign-key 3056513887B78AEB

# Install the Chaotic AUR keyring and mirrorlist
pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

# Append (adding to the end of the file) to /etc/pacman.conf
echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" >> /etc/pacman.conf

# Refresh the package databases
pacman --refresh --refresh

# Upgrade the packages with pamac
pamac upgrade --overwrite="*"
