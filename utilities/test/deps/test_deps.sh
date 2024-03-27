#!/bin/bash

# Colors and visual feedback symbols
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
CHECK_MARK="\u2714"
CROSS_MARK="\u274c"

# Ensure script is run with sudo
if [[ "$EUID" -ne 0 ]]; then
    echo -e "${RED}This script must be run as root.${NC}"
    exit 1
fi

# Logging setup
LOG_FILE="/var/log/dep_install.log"
touch "$LOG_FILE"
echo "Log File: $LOG_FILE"

# Function definitions
log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

confirm() {
    while true; do
        read -r -p "$1 [Y/n]: " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

check_pkgfile() {
    if ! command -v pkgfile &> /dev/null; then
        log "${RED}pkgfile is not installed. Installing...${NC}"
        pacman -Sy pkgfile --noconfirm
        pkgfile --update
    else
        pkgfile --update
    fi
}

install_pkg() {
    local pkg=$1
    if pacman -Qi "$pkg" &> /dev/null; then
        log "${CHECK_MARK} $pkg is already installed."
    else
        if confirm "Install $pkg?"; then
            pacman -S "$pkg" --noconfirm && log "${CHECK_MARK} Installed $pkg successfully." || log "${CROSS_MARK} Failed to install $pkg."
        else
            log "Installation of $pkg was skipped by the user."
        fi
    fi
}

# Example of a function calling another function
process_packages() {
    local packages=("pkgfile" "yay")
    for pkg in "${packages[@]}"; do
        install_pkg "$pkg"
    done
}

# Main function to orchestrate the script
main() {
    log "Starting dependency checks..."
    check_pkgfile
    process_packages
    log "Dependency checks complete."
}

main










