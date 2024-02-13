#!/bin/bash
#File: fixkeys.sh
#Author: 4ndr0666
#Edited: 02-07-2024

# --- // AUTO_ESCALATE:
auto_escalate() {
    if [ "$(id -u)" -ne 0 ]; then
        sudo "$0" "$@"
        exit $?
    fi
}

# --- // BANNER:
banner() {
    echo -e "\033[34m"
    cat << "EOF"
    #

    # --- //ASCII_ART//
    #
    EOF
    echo -e "\033[0m"
}

# --- // ECHO_WITH_COLOR:
# Success:
prominent() {
    local message="$1"
    local color="${2:-$GREEN_COLOR}"
    echo -e "${BOLD}${color}$message${NO_COLOR}"
}

# Error:
bug() {
    local message="$1"
    local color="${2:-$RED_COLOR}"
    echo -e "${BOLD}${color}$message${NO_COLOR}"
}

# --- // FUNCTIONS:
reinstall() {
    prominent "${EXPLOSION}Reinstalling the arch-keyring..."
    pacman -Sy archlinux-keyring --noconfirm
}

clean() {
    prominent "${INFO} Removing old sync data and gpg dir..."
    rm -rf /var/lib/pacman/sync/*
    rm -rf /etc/pacman.d/gnupg/*
    sleep 2
}

init() {
    prominent "${SUCCESS}Initializing new pacman key..."
    pacman-key --init
}

populate() {
    prominent "${SUCCESS}Populating the keyring and explicitly adding the ubuntu keyserver..."
    pacman-key --populate
    echo "keyserver hkp://keyserver.ubuntu.com:80" | sudo tee --append /etc/pacman.d/gnupg/gpg.conf
}

sync() {
    prominent "${SUCCESS}Creating fresh repo databases..."
    pacman -Sy
}

# --- // MAIN:
main() {
    # --- // DYNAMIC_COLOR:
    GREEN_COLOR='\033[0;32m'
    RED_COLOR='\033[0;31m'
    NO_COLOR='\033[0m' # No Color

    # --- // SYMBOLS:
    SUCCESS="✔️"
    FAILURE="❌"
    INFO="➡️"
    EXPLOSION="💥"

    auto_escalate
    banner
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
