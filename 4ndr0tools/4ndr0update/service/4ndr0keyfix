#!/usr/bin/env bash
# Author: 4ndr0666
#set -e

# ==================== // FIXKEYS.SH //

## Privileges

if [[ "$EUID" -ne 0 ]]; then
    echo "Acquiring SU privileges..."
    sudo "$0" "$@"
    exit $?
fi

## Colors

GREEN='\033[0;32m'
NC='\033[0m' # No Color
GOOD="✔️"
INFO="➡️"
EXPLOSION="💥"
prominent() {
    local message="$1"
    local color="${2:-$GREEN}"
    echo -e "${BOLD}${color}$message${NC}"
}

## Removal

remove() {
    prominent "${INFO} Removing the pacman databases..."
    rm /var/lib/pacman/sync/* || echo "failed to remove databases" exit 1
    prominent "${INFO} Removing /etc/pacman.d/gnupg files..."
    rm -rf /etc/pacman.d/gnupg/* || echo "failed to remove /etc/pacman.d/gnupg files" exit 1
}

## Pacman-key

initialize() {
    prominent "${INFO} Initializing Pacman-key..."
    pacman-key --init || echo "failed to initialize pacman-key." exit 1
    prominent "${INFO} Populating Pacman-key..."
    pacman-key --populate || echo "keyserver hkp://keyserver.ubuntu.com:80" | sudo tee --append /etc/pacman.d/gnupg/gpg.conf
                           # echo "keyserver hkps://keyserver.ubuntu.com" | sudo tee --append /etc/pacman.d/gnupg/gpg.conf || \
                           # echo "keyserver hkps://keys.openpgp.org" | sudo tee --append /etc/pacman.d/gnupg/gpg.conf
}

## New Databases

refresh() {
    prominent "${INFO} Getting new databases..."
    pacman -Sy || echo "failed to retreive new databases." exit 1
    prominent "${INFO} Reinstalling keyring..."
    pacman -Sy archlinux-keyring --noconfirm || echo "Failed to reinstall archlinux-keyring." exit 1
}

## Main Entry Point

main() {
    remove || echo "failed to remove corrupt databases" exit 1
    initialize || echo "failed to initialize keyring" exit 1
    refresh || echo "failed to refresh keys" exit 1
    prominent "${GOOD}Keys are now fixed!"
    exit 0
}

main 
