#!/bin/bash

# Colors and Symbols for visual feedback
GREEN='\033[0;32m'
BOLD='\033[1m'
RED='\033[0;31m'
NC='\033[0m' # No Color
SUCCESS="✔️"
FAILURE="❌"
INFO="➡️"
EXPLOSION="💥"

prominent() { printf "${BOLD}${GREEN}%s${NC}\n" "$1"; }
bug() { printf "${BOLD}${RED}%s${NC}\n" "$1"; }

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\\'
    tput civis # Hide cursor
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep "$delay"
        printf "\r\b\b\b\b\b\b"
    done
    printf "      \r\b\b\b\b\b\b"
    tput cnorm # Show cursor
}

check_installed() {
    pacman -Qi "$1" &>/dev/null
}

install_package() {
    local package=$1

    if check_installed "$package"; then
        prominent "$INFO $package is already installed."
        return
    fi

    printf "%s Installing %s...\n" "$EXPLOSION" "$package"
    sudo pacman -S --noconfirm "$package" & spinner $!
    wait $! && printf "\r%s Package %s installed successfully!   \n" "$GREEN$SUCCESS" "$package"
}

check_and_install_deps_for_package() {
    local package=$1

    if ! check_installed "$package"; then
        install_package "$package"
    fi

    local deps
    deps=$(pactree -u "$package")

    for dep in $deps; do
        if ! check_installed "$dep"; then
            install_package "$dep"
        fi
    done

    prominent "$SUCCESS All dependencies for $package are satisfied."
}

check_and_install_deps_system_wide() {
    local all_packages
    all_packages=$(pacman -Qq)

    for pkg in $all_packages; do
        check_and_install_deps_for_package "$pkg"
    done

    prominent "$SUCCESS All system dependencies are satisfied."
}

usage() {
    printf "${GREEN}Usage example - %s [pkg] ${NC}${INFO} install any missing dependencies for that pkg only.\n" "$0"
    printf "               ${GREEN} %s ${NC}${INFO} install all missing dependencies systemwide.\n\n" "$0"
    printf "help:\n"
    printf "${GREEN}pacman -Qi [pkg]${NC}${INFO} check if the pkg is installed.\n"
    printf "${GREEN}pactree -u [pkg]${NC}${INFO} get the pkg dependencies.\n"
}

if [ "$#" -eq 1 ]; then
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        usage
        exit 0
    fi
    check_and_install_deps_for_package "$1"
elif [ "$#" -eq 0 ]; then
    check_and_install_deps_system_wide
else
    bug "Invalid number of arguments."
    usage
    exit 1
fi
