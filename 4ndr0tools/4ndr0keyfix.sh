#!/usr/bin/env bash
# Author: 4ndr0666

# ==================== // FIXKEYS.SH //

if [[ "$EUID" -ne 0 ]]; then
    sudo "$0" "$@"
    exit $?
fi

## Colors

GREEN='\033[0;32m'
NC='\033[0m' # No Color
GOOD="✔️"
INFO="➡️"
EXPLOSION="💥"
glow() {
    local message="$1"
    local color="${2:-$GREEN}"
    echo -e "${color}$message${NC}"
}

## Removal

removedb() {
    glow "Removing corrupt pacman database..."
    sleep 1
    rm /var/lib/pacman/sync/* || {
	    glow "${EXPLOSION} failed to remove databases"
    } exit 1

    glow "Removing corrupt gpg files..."
    sleep 1
    rm -rf /etc/pacman.d/gnupg/* || {
	    glow "${EXPLOSION} failed to remove /etc/pacman.d/gnupg files"
    } exit 1
}

## Initialization

initdb() {
    glow "Initializing Pacman-key..."
    pacman-key --init || {
        glow "Failed to execute Pacman-key --init."
    } exit 1

    glow "Downloading chaotic-aur keyrings and mirrorlists..."
    printf "\%b"
    sleep 1
    pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
    pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
#    tee -a /etc/pacman.conf << EOF
#[chaotic-aur]
#Include = /etc/pacman.d/chaotic-mirrorlist
#EOF

    glow "Signing keys and populating..."
    printf "\%b"
    sleep 1
    pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    pacman-key --lsign-key 3056513887B78AEB || {
	    glow "Failed to sign keys..."
    } exit 1
# echo "keyserver hkps://keyserver.ubuntu.com" | sudo tee --append /etc/pacman.d/gnupg/gpg.conf || \
# echo "keyserver hkps://keys.openpgp.org" | sudo tee --append /etc/pacman.d/gnupg/gpg.conf
}

## Syncing

syncdb() {
    glow "Syncing databases..."
    pacman-key --populate || echo "keyserver hkp://keyserver.ubuntu.com:80" | tee --append /etc/pacman.d/gnupg/gpg.conf
    pacman -Sy && pacman -Sy archlinux-keyring --noconfirm || {
	    glow "Failed to reinstall archlinux-keyring."
    } exit 1
}

## Main Entry Point

main() {
    removedb || glow "${EXPLOSION} failed to remove corrupt databases" exit 1
    initdb || glow "${EXPLOSION} failed to initialize keyring" exit 1
    syncdb || glow "${EXPLOSION} failed to refresh keys" exit 1
    glow "${GOOD} Pacman key is now functional!"
    exit 0
}

main
