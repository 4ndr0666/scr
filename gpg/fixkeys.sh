#!/bin/bash
#
##File: /usr/local/bin/fixkeys.sh
#Author: 4ndr0666
#Edited: 02-07-2024

# ----------------------- // FIX_KEYS.SH // ========
auto_escalate() {
    if [ "$(id -u)" -ne 0 ]; then
        sudo "$0" "$@"
        exit $?
    fi
}
    
GREEN_COLOR='\033[0;32m'
RED_COLOR='\033[0;31m'
NO_COLOR='\033[0m' # No Color
SUCCESS="✔️"
FAILURE="❌"
INFO="➡️"
EXPLOSION="💥"

prominent() {
    local message="$1"
    local color="${2:-$GREEN_COLOR}"
    echo -e "${BOLD}${color}$message${NO_COLOR}"
}

bug() {
    local message="$1"
    local color="${2:-$RED_COLOR}"
    echo -e "${BOLD}${color}$message${NO_COLOR}"
}


# --- // FUNCTIONS:
reinstall() {
    prominent "${EXPLOSION}Reinstalling the arch-keyring..."
    sleep 2
    pacman -Sy archlinux-keyring --noconfirm
}

clean() {
    prominent "${INFO} Removing old sync data and gpg dir..."
    sleep 2
    rm -rf /var/lib/pacman/sync/*
    rm -rf /etc/pacman.d/gnupg/*
}

init() {
    prominent "${SUCCESS}Initializing new pacman key..."
    sleep 2
    pacman-key --init
}

populate() {
    prominent "${SUCCESS}Populating the keyring and explicitly adding the ubuntu keyserver..."
    sleep 2
    pacman-key --populate
    echo "keyserver hkp://keyserver.ubuntu.com:80" | sudo tee --append /etc/pacman.d/gnupg/gpg.conf
}

sync() {
    prominent "${SUCCESS}Creating fresh repo databases..."
    pacman -Sy
}

# --- // MAIN:
main() {
    auto_escalate
#    banner
    reinstall
    clean
    init
    populate
    sync
    prominent "${EXPLOSION}done!${EXPLOSION}"
    sleep 1
    exit 0
}

main "$@"
