#!/bin/bash

# Maximum retries for system commands
MAX_RETRIES=3
RETRY_DELAY=2  # seconds

# Function to retry a command with a delay if it fails
retry_command() {
    local retries="$MAX_RETRIES"
    local delay="$RETRY_DELAY"
    local cmd="$*"

    until $cmd; do
        ((retries--)) || { echo "Error: Command failed after $MAX_RETRIES attempts: $cmd"; exit 1; }
        echo "Retrying... ($retries attempts left)"
        sleep "$delay"
    done
}

configure_reflector() {
    if ! systemctl is-enabled reflector.timer > /dev/null 2>&1; then
        sudo systemctl enable --now reflector.timer
        echo "Reflector is now set to automatically update mirror lists."
    else
        echo "Reflector timer already enabled."
    fi
    printf "\n"

    read -r -p "Do you want to get an updated mirrorlist? [y/N]"
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
        retry_command sudo pacman -S --noconfirm "$pkg"
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

# Set up AUR directory using the chosen AUR helper (from settings.sh)
aur_setup() {
    printf "\n"
    read -r -p "Do you want to setup the AUR package directory at $AUR_DIR? [y/N] "
    if [[ "$REPLY" =~ ^[yY]$ ]]; then
        printf "Setting up AUR package directory...\n"
        if [[ ! -d "$AUR_DIR" ]]; then
            mkdir -p "$AUR_DIR"
        fi
        # Adjust permissions if necessary
        chmod u+rwx "$AUR_DIR"
        printf "...AUR package directory set up at %s\n" "$AUR_DIR"
    fi
}

# Function to rebuild AUR packages
rebuild_aur() {
    if [[ -w "$AUR_DIR" ]]; then
        printf "\n"
        read -r -p "Do you want to rebuild the AUR packages in $AUR_DIR? [y/N] "
        if [[ "$REPLY" =~ ^[yY]$ ]]; then
            printf "Rebuilding AUR packages...\n"
            if [[ -n "$(ls -A "$AUR_DIR")" ]]; then
                starting_dir="$(pwd)"
                for aur_pkg in "$AUR_DIR"/*/; do
                    if [[ -d "$aur_pkg" ]]; then
                        if [[ ! -w "$aur_pkg" ]]; then
                            chmod -R u+w "$aur_pkg"
                        fi
                        cd "$aur_pkg" || continue
                        if [[ "$AUR_UPGRADE" == "true" ]]; then
                            git pull origin master
                        fi
                        # Source PKGBUILD to get depends and makedepends arrays
                        if [[ -f PKGBUILD ]]; then
                            source PKGBUILD
                            # Install dependencies
                            if [[ "${#depends[@]}" -gt 0 || "${#makedepends[@]}" -gt 0 ]]; then
                                sudo pacman -S --needed --asdeps "${depends[@]}" "${makedepends[@]}" --noconfirm
                            fi
                            # Build package
                            makepkg -fc --noconfirm
                            # Install package
                            sudo pacman -U "$(makepkg --packagelist)" --noconfirm
                        else
                            printf "No PKGBUILD found in %s, skipping...\n" "$aur_pkg"
                        fi
                        cd "$starting_dir" || exit
                    fi
                done
                printf "...Done rebuilding AUR packages\n"
            else
                printf "...No AUR packages in %s\n" "$AUR_DIR"
            fi
        else
            printf "...Skipping AUR package rebuild.\n"
        fi
    else
        printf "\nAUR package directory not set up or not writable.\n"
        aur_setup
    fi
}

# Function to check for .pacnew and .pacsave files
handle_pacfiles() {
    printf "\nChecking for pacfiles...\n"
    if [[ -n "$(sudo find /etc -type f \( -name '*.pacnew' -o -name '*.pacsave' \) 2>/dev/null)" ]]; then
        echo "The following .pacnew or .pacsave files were found:"
        sudo find /etc -type f \( -name '*.pacnew' -o -name '*.pacsave' \)
        read -r -p "Do you want to view and merge these files now? [y/N] "
        if [[ "$REPLY" =~ ^[yY]$ ]]; then
            sudo DIFFPROG=meld pacdiff
        fi
    else
        echo "...No .pacnew or .pacsave files found."
    fi
}

# Handle pacfiles
#handle_pacfiles() {
#    printf "\nChecking for pacfiles...\n"
#    pacdiff
#    printf "...Done checking for pacfiles\n"
#}

# Perform a system update using powerpill and the chosen AUR helper
system_update() {
    local EXTRA_PARAMS=(--noconfirm --needed --disable-download-timeout --timeupdate --singlelineresults --assume-installed ffmpeg)

    printf "\nPerforming system upgrade...\n"
    retry_command sudo /usr/bin/pacman -Syyu --noconfirm
#    retry_command sudo powerpill -Su --noconfirm

    if ! retry_command sudo /usr/bin/pacman -Syyu --noconfirm; then
        echo "Error: System update failed."
        return 1
    fi

#    /usr/bin/yay -Su "${EXTRA_PARAMS[@]}"
# 

    printf "System updated!\n"
}
