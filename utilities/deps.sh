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

# Function to display prominent messages
prominent() {
    echo -e "${BOLD}${GREEN}$1${NC}"
}

# Function for errors
bug() {
    echo -e "${BOLD}${RED}$1${NC}"
}

# Spinner
spinner() {
    local pid=$!
    local delay=0.1
    local spinstr='|/-\\'
    tput civis # Hide cursor
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "      \b\b\b\b\b\b"
    tput cnorm # Show cursor
}

check_installed() {
    if pacman -Qi "$1" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

install_package() {
    local package=$1

    if check_installed "$package"; then
        prominent "$INFO $package is already installed."
        return 0
    fi

    echo "$EXPLOSION Installing $package..."
    sudo pacman -S --noconfirm "$package" & spinner
    wait $! && echo -e "\r$GREEN$SUCCESS Package $package installed successfully!$NC   "
}

# Function to check and install dependencies for a single package
check_and_install_deps_for_package() {
    local package=$1

    if ! check_installed "$package"; then
        install_package "$package"
    fi

    local deps=$(pactree -u "$package")

    for dep in $deps; do
        if ! check_installed "$dep"; then
            install_package "$dep"
        fi
    done

    prominent "$SUCCESS All dependencies for $package are satisfied."
}

# Main function to check and install system-wide dependencies
check_and_install_deps_system_wide() {
    local all_packages=$(pacman -Qq)

    for pkg in $all_packages; do
        check_and_install_deps_for_package "$pkg"
    done

    prominent "$SUCCESS All system dependencies are satisfied."
}

# Usage and Help Message
usage() {
    echo -e "${GREEN}Usage example - $0 [pkg] ${NC}${INFO} install any missing dependencies for that pkg only."
    echo -e "               ${GREEN} $0 ${NC}${INFO} install all missing dependencies systemwide."
    echo -e "\n"
    echo -e "help:"
    echo -e "${GREEN}pacman -Qi [pkg]${NC}${INFO} check if the pkg is installed."
    echo -e "${GREEN}pactree -u [pkg]${NC}${INFO} get the pkg dependencies."
}

# Check if an argument is provided, if so, check that package's dependencies.
# If no argument is provided, check all system packages.
# If the argument is -h or --help, display the usage message.
if [ $# -eq 1 ]; then
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        usage
        exit 0
    fi
    check_and_install_deps_for_package "$1"
elif [ $# -eq 0 ]; then
    check_and_install_deps_system_wide
else
    bug "Invalid number of arguments."
    usage
    exit 1
fi
