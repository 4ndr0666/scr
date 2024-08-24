#!/bin/bash
# Unified Arch Linux update script with integrated configuration, package checks, and dependency verification
# This script adheres to production-ready standards, including error handling, idempotency, and educational content.

# Pacman Configuration
PACMAN_CONF="/etc/pacman.conf"
UR_DIR="/home/build"  # Update this path as needed

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

# Set up yay and related hooks for optimized performance
setup_yay_and_hooks() {
    ensure_package_installed "yay"

    echo "Ensuring hooks are correctly installed:"
    for hook in yaycache-hook check-broken-packages-pacman-hook-git kernel-modules-hook paccache-hook reflector-pacman-hook-git systemd-boot-pacman-hook; do
        ensure_package_installed "$hook"
        check_and_install_dependencies "$hook"
    done
}

# Function to set up the AUR directory
aur_setup() {
    printf "\n"
    read -r -p "Do you want to set up the AUR package directory at $AUR_DIR? [y/N] "
    if [[ "$REPLY" =~ [yY] ]]; then
        printf "Setting up AUR package directory...\n"
        if [[ ! -d "$AUR_DIR" ]]; then
            mkdir -p "$AUR_DIR"
            test -n "$SUDO_USER" && chown "$SUDO_USER" "$AUR_DIR"
        fi

        chgrp "$1" "$AUR_DIR"
        chmod g+ws "$AUR_DIR"
        setfacl -d --set u::rwx,g::rx,o::rx "$AUR_DIR"
        setfacl -m u::rwx,g::rwx,o::- "$AUR_DIR"
        printf "...AUR package directory set up at $AUR_DIR\n"
    fi
}

# Function to rebuild AUR packages
rebuild_aur() {
    AUR_DIR_GROUP="nobody"
    test -n "$SUDO_USER" && AUR_DIR_GROUP="$SUDO_USER"

    if [[ -w "$AUR_DIR" ]] && sudo -u "$AUR_DIR_GROUP" test -w "$AUR_DIR"; then
        printf "\n"
        read -r -p "Do you want to rebuild the AUR packages in $AUR_DIR? [y/N] "
        if [[ "$REPLY" =~ [yY] ]]; then
            printf "Rebuilding AUR packages...\n"
            if [[ -n "$(ls -A $AUR_DIR)" ]]; then
                starting_dir="$(pwd)"
                for aur_pkg in "$AUR_DIR"/*/; do
                    if [[ -d "$aur_pkg" ]]; then
                        if ! sudo -u "$AUR_DIR_GROUP" test -w "$aur_pkg"; then
                            chmod -R g+w "$aur_pkg"
                        fi
                        cd "$aur_pkg"
                        if [[ "$AUR_UPGRADE" == "true" ]]; then
                            git pull origin master
                        fi
                        source PKGBUILD
                        pacman -S --needed --asdeps "${depends[@]}" "${makedepends[@]}" --noconfirm
                        sudo -u "$AUR_DIR_GROUP" makepkg -fc --noconfirm
                        pacman -U "$(sudo -u $AUR_DIR_GROUP makepkg --packagelist)" --noconfirm
                    fi
                done
                cd "$starting_dir"
                printf "...Done rebuilding AUR packages\n"
            else
                printf "...No AUR packages in $AUR_DIR\n"
            fi
        fi
    else
        printf "\nAUR package directory not set up"
        aur_setup "$AUR_DIR_GROUP"
    fi
}

# Function to handle pacfiles
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

# Perform a system update using powerpill and yay
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

    echo "Upgrading AUR packages with yay..."
    if ! yay -Syu --noconfirm --cleanafter --needed --refresh --sysupgrade --useask=false; then
        echo "Error: AUR upgrade failed. Please check yay logs for more details."
        exit 1
    fi
}

# Elevate privileges if not root
#if [[ $EUID -ne 0 ]]; then
#    exec sudo --preserve-env="PACMAN_EXTRA_OPTS" "$0" "$@"
#    exit 1
#fi

# Run the configuration steps
#update_pacman_conf
#configure_reflector
#setup_yay_and_hooks

# Run the AUR setup and rebuild if needed
#aur_setup
#rebuild_aur

# Handle pacfiles
#handle_pacfiles

# Run the system update
#system_update "$@"

#echo "System update completed successfully."

# End of script
