#!/bin/bash

GREEN='\033[0;32m'
BOLD='\033[1m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Symbols for visual feedback
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
  local pid=$1
  local delay=0.1
  local spinstr='|/-\'
  while kill -0 "$pid" 2>/dev/null; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  printf "      \b\b\b\b\b\b"
}

# Function to check if a package is installed
is_installed() {
    pacman -Qi "$1" &> /dev/null
}

# Function to install a package
install_package() {
    prominent -n "$EXPLOSION Installing $1..."
    (sudo pacman -S --noconfirm "$1" &>/dev/null) & # Run installation in the background
    spinner $! # Pass the PID of the background process to spinner
    prominent "$SUCCESS Installed."
}

# Main function
check_and_install_deps() {
    local pkg="$1"

    if [[ -z "$pkg" ]]; then
        echo "Usage: $0 [package-name]"
        exit 1
    fi

    if ! is_installed "$pkg"; then
        prominent "$FAILURE Package $pkg is not installed. Exiting."
        exit 1
    fi

    prominent "$INFO Checking dependencies for $pkg..."

    # List all dependencies
    local deps
    deps=$(pactree -u "$pkg")

    for dep in $deps; do
        if ! is_installed "$dep"; then
            install_package "$dep"
        else
            prominent "$INFO $dep is already installed."
        fi
    done

    prominent "$SUCCESS All dependencies for $pkg are satisfied."
}

# Run the main function with the provided package name
check_and_install_deps "$1"
