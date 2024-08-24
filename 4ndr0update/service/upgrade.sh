#!/bin/bash
# Unified Arch Linux update script with integrated configuration, package checks, and dependency verification

# Pacman Configuration
PACMAN_CONF="/etc/pacman.conf"

# Function to update pacman.conf with necessary settings
update_pacman_conf() {
    if ! grep -q "ParallelDownloads = 5" "$PACMAN_CONF"; then
        sudo sed -i '/^#ParallelDownloads =/c\ParallelDownloads = 5' "$PACMAN_CONF"
        echo "Enabled parallel downloads in pacman.conf"
    fi
    sudo sed -i '/^#Color/c\Color' "$PACMAN_CONF"
    sudo sed -i '/^#CheckSpace/c\CheckSpace' "$PACMAN_CONF"
    sudo sed -i '/^#ILoveCandy/c\ILoveCandy' "$PACMAN_CONF"
    echo "Pacman configuration updated for ParallelDownloads, Color, CheckSpace, and ILoveCandy."
}

# Ensure Reflector is set up correctly
configure_reflector() {
    if ! systemctl is-enabled reflector.timer > /dev/null 2>&1; then
        sudo systemctl enable --now reflector.timer
        echo "Reflector is now set to automatically update mirror lists."
    else
        echo "Reflector timer already enabled."
    fi

    printf "\n"
    read -r -p "Do you want to get an updated mirrorlist? [y/N] "
    if [[ "$REPLY" =~ [yY] ]]; then
        printf "Updating mirrorlist...\n"
        reflector --country "$MIRRORLIST_COUNTRY" --latest 200 --age 24 --sort rate --save /etc/pacman.d/mirrorlist
        printf "...Mirrorlist updated\n"
    fi
}

# Function to check and install a package if it is missing
ensure_package_installed() {
    local pkg="$1"
    if ! pacman -Qs "$pkg" > /dev/null; then
        echo "Package $pkg is missing. Installing..."
        if ! sudo pacman -S --noconfirm "$pkg"; then
            echo "Error: Failed to install $pkg. Please check your internet connection or package availability."
            exit 1
        fi
    else
        echo "Package $pkg is already installed."
    fi
}

# Function to verify and install missing dependencies for a package
check_and_install_dependencies() {
    local pkg="$1"
    echo "Checking dependencies for $pkg..."

    local dependencies
    dependencies=$(pactree -u -d1 "$pkg" | tail -n +2)

    for dep in $dependencies; do
        ensure_package_installed "$dep"
    done
}

# Set up AUR directory using trizen
aur_setup() {
    printf "\n"
    read -r -p "Do you want to set up the AUR package directory at $AUR_DIR? [y/N] "
    if [[ "$REPLY" =~ [yY] ]]; then
        printf "Setting up AUR package directory...\n"
        if [[ ! -d "$AUR_DIR" ]]; then
            mkdir -p "$AUR_DIR"
            chown "$SUDO_USER:$SUDO_USER" "$AUR_DIR"
        fi

        chgrp "$SUDO_USER" "$AUR_DIR"
        chmod g+ws "$AUR_DIR"
        setfacl -d --set u::rwx,g::rx,o::rx "$AUR_DIR"
        setfacl -m u::rwx,g::rwx,o::- "$AUR_DIR"
        printf "...AUR package directory set up at $AUR_DIR\n"
    fi
}

# Function to rebuild AUR packages using trizen as non-root user
rebuild_aur() {
    printf "\n"
    read -r -p "Do you want to rebuild all AUR packages using trizen? [y/N] "
    if [[ "$REPLY" =~ [yY] ]]; then
        echo "Rebuilding AUR packages with trizen..."
        sudo -u "$SUDO_USER" trizen -Syu --noconfirm
        echo "...AUR packages rebuilt."
    fi
}

# Handle pacfiles
handle_pacfiles() {
    printf "\nChecking for pacfiles...\n"
    pacdiff
    printf "...Done checking for pacfiles\n"
}

# Minimal pacman.conf for non-standard setups
minimal_pacman_conf() {
    local TEMP_CONF
    TEMP_CONF=$(mktemp)
    echo -e "[archlinux]\nServer = https://mirror.archlinux.org/\$repo/os/\$arch" >"$TEMP_CONF"
    echo "$TEMP_CONF"
}

# Perform a system update using powerpill and trizen
system_update() {
    local EXTRA_PARAMS=()

    ensure_package_installed "powerpill"
    check_and_install_dependencies "powerpill"

    echo "Updating package database..."
    sudo pacman -Sy || { echo "Error: Failed to update package database."; exit 1; }

    echo "Upgrading system packages with powerpill..."
    if ! sudo powerpill -Su; then
        echo "Error: System upgrade failed. Please check your system logs for more details."
        exit 1
    fi

    echo "Upgrading AUR packages with trizen..."
    sudo -u "$SUDO_USER" trizen -Syu --noconfirm --needed --refresh --sysupgrade
    echo "...AUR packages upgraded."
}

# Elevate privileges if not root
if [[ $EUID -ne 0 ]]; then
    exec sudo --preserve-env="PACMAN_EXTRA_OPTS" "$0" "$@"
    exit 1
fi
