#!/usr/bin/env bash
# Author: 4ndr0666
# ============================== // 4NDR0BASE.SH //
## Description: Quick setup script for basic requirements on a new machine.
# ------------------------------------------------

## Constants

AUR_HELPER="yay"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

## Colors

export TERM=ansi # Generally not needed, let the terminal handle TERM

RC='\033[0m'
RED='\033[31m'
YELLOW='\033[33m'
CYAN='\033[36m'
GREEN='\033[32m'
BOLD='\033[1m'

## Package Lists

PKGS_OFFICIAL=(
    base-devel
    debugedit
    unzip
    archlinux-keyring
    github-cli
    git-delta
    exa
    fd
    micro
    expac
    bat
    bash-completion
    pacdiff
    neovim
    xorg-xhost
    xclip
    ripgrep
    diffuse
    fzf
    zsh-syntax-highlighting
    zsh-history-substring-search
    zsh-autosuggestions
    lsd
    git-extras
)
PKGS_AUR=(
    sysz
    brave-beta-bin
    bashmount-git
    breeze-hacked-cursor-theme-git
    lf-git
)


## Helpers

print_step() {
    printf "%b\n" "${BOLD}${CYAN}:: $@${RC}"
}

error() {
    printf "%b\n" "${RED}ERROR: $1${RC}" >&2
    exit 1
}

check_arch() {
    if ! grep -q "Arch Linux" /etc/os-release; then
        error "This script is intended for Arch Linux only."
    fi
}

## Chaotic AUR

setuprepos() {
    print_step "Setting up Chaotic AUR repository..."

    # Refresh Keyrings
    printf "%b\n" "  Refreshing archlinux-keyring..."
    sudo pacman --noconfirm -Sy archlinux-keyring || error "Failed to refresh archlinux-keyring."

    # Import and sign Chaotic-AUR key
    printf "%b\n" "  Importing and signing Chaotic-AUR key..."
    sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com || error "Failed to receive Chaotic-AUR key."
    sudo pacman-key --lsign-key 3056513887B78AEB || error "Failed to sign Chaotic-AUR key."

    # Install Chaotic-AUR keyring and mirrorlist
    printf "%b\n" "  Installing Chaotic-AUR Keyring and Mirrorlist..."
    sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' || error "Failed to install Chaotic-AUR packages."

    # Add Repo To pacman.conf if not already present
    printf "%b\n" "  Adding Chaotic-AUR repo to pacman.conf..."
    if ! grep -q "^\[chaotic-aur\]" /etc/pacman.conf; then
        echo "[chaotic-aur]
Include = /etc/pacman.d/mirrorlist-arch" | sudo tee -a /etc/pacman.conf >/dev/null || error "Failed to add Chaotic-AUR repo to pacman.conf."
    else
        printf "%b\n" "  Chaotic-AUR repo already exists in pacman.conf, skipping."
    fi

    # Sync pacman databases
    printf "%b\n" "  Syncing pacman databases..."
    sudo pacman -Sy --noconfirm || error "Failed to sync pacman databases after adding Chaotic-AUR."

    # Populate archlinux keys (good practice after sync)
    printf "%b\n" "  Populating archlinux keys..."
    sudo pacman-key --populate archlinux || error "Failed to populate archlinux keys."

    printf "%b\n" "${GREEN}Chaotic AUR setup complete.${RC}"
}

## Nerd Font

setupfont() {
    print_step "Setting up Meslo Nerd Font..."
    local FONT_DIR="$HOME/.local/share/fonts"
    local FONT_ZIP="$FONT_DIR/Meslo.zip"
    local FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip"
    local FONT_INSTALLED=$(fc-list | grep -i "Meslo")

    if [ -n "$FONT_INSTALLED" ]; then
        printf "%b\n" "${GREEN}  Meslo Nerd-fonts are already installed.${RC}"
        return 0
    fi

    printf "%b\n" "  Meslo Nerd-fonts not found, installing..."

    if [ ! -d "$FONT_DIR" ]; then
        printf "%b\n" "  Creating font directory: $FONT_DIR"
        mkdir -p "$FONT_DIR" || error "Failed to create directory: $FONT_DIR"
    else
        printf "%b\n" "  $FONT_DIR exists, skipping creation."
    fi

    if [ ! -f "$FONT_ZIP" ]; then
        printf "%b\n" "  Downloading Meslo Nerd-fonts from $FONT_URL..."
        # Download the font zip file
        curl -sSLo "$FONT_ZIP" "$FONT_URL" || error "Failed to download Meslo Nerd-fonts from $FONT_URL"
    else
        printf "%b\n" "  Meslo.zip already exists in $FONT_DIR, skipping download."
    fi

    # Check if the zip file was successfully downloaded/exists before attempting unzip
    if [ -f "$FONT_ZIP" ]; then
        if [ ! -d "$FONT_DIR/Meslo" ]; then
             printf "%b\n" "  Unzipping Meslo Nerd-fonts..."
             # Unzip into the font directory
             unzip "$FONT_ZIP" -d "$FONT_DIR" || error "Failed to unzip $FONT_ZIP"
             # Remove the zip file after successful unzip
             printf "%b\n" "  Removing zip file: $FONT_ZIP"
             rm "$FONT_ZIP" || printf "%b\n" "${YELLOW}Warning: Failed to remove $FONT_ZIP${RC}\n" # Non-critical failure
        else
             printf "%b\n" "  Meslo font files already unzipped in $FONT_DIR, skipping unzip."
             # If already unzipped, remove the zip if it exists
             if [ -f "$FONT_ZIP" ]; then
                 printf "%b\n" "  Removing existing zip file: $FONT_ZIP"
                 rm "$FONT_ZIP" || printf "%b\n" "${YELLOW}Warning: Failed to remove $FONT_ZIP${RC}\n" # Non-critical failure
             fi
        fi
    else
        error "Font zip file not found after download attempt."
    fi


    printf "%b\n" "  Rebuilding font cache..."
    fc-cache -fv || error "Failed to rebuild font cache"

    printf "%b\n" "${GREEN}Meslo Nerd-fonts installed.${RC}"
}

## Install Yay

install_yay() {
    print_step "Installing AUR helper ($AUR_HELPER)..."
    if ! command -v "$AUR_HELPER" &>/dev/null; then
        printf "%b\n" "  $AUR_HELPER not found, installing..."
        local YAY_TMP_DIR="/tmp/$AUR_HELPER"

        printf "%b\n" "  Cloning $AUR_HELPER repository..."
        git clone "https://aur.archlinux.org/$AUR_HELPER.git" "$YAY_TMP_DIR" || {
            error "Failed to clone $AUR_HELPER repository."
        }

        printf "%b\n" "  Building and installing $AUR_HELPER..."
        pushd "$YAY_TMP_DIR" || error "Failed to change directory to $YAY_TMP_DIR."
        # Do NOT suppress makepkg output - it's crucial for debugging AUR build failures
        sudo -u "$USER" makepkg --noconfirm -si || {
            local status=$?
            popd || error "Failed to return to original directory."
            error "Failed to build and install $AUR_HELPER. makepkg exited with status $status."
        }
        popd || error "Failed to return to original directory."

        # Clean up the temporary directory
        printf "%b\n" "  Cleaning up temporary directory $YAY_TMP_DIR..."
        rm -rf "$YAY_TMP_DIR"

        printf "%b\n" "${GREEN}$AUR_HELPER installed successfully.${RC}"
    else
        printf "%b\n" "${GREEN}  ($AUR_HELPER) is already installed.${RC}"
    fi
}

## Pacman Pkgs

install_official_pkgs() {
    print_step "Installing official packages..."
    printf "%b\n" "  Packages: ${PKGS_OFFICIAL[*]}\n"
    # Do NOT suppress pacman output - it's crucial for debugging installation failures
    sudo pacman -Sy && sudo pacman -S --noconfirm --needed "${PKGS_OFFICIAL[@]}" || error "Failed to install official packages."
    printf "%b\n" "${GREEN}Official packages installed.${RC}"
}

## Yay Pkgs

install_aur_pkgs() {
    print_step "Installing AUR packages using $AUR_HELPER..."
    # Ensure yay is available before attempting to use it
    if ! command -v "$AUR_HELPER" &>/dev/null; then
        error "$AUR_HELPER is not installed. Cannot install AUR packages."
    fi

    printf "%b\n" "  Packages: ${PKGS_AUR[*]}\n"
    # Do NOT suppress yay output - it's crucial for debugging AUR build/installation failures
    "$AUR_HELPER" -S --noconfirm --needed "${PKGS_AUR[@]}" || error "Failed to install AUR packages."
    printf "%b\n" "${GREEN}AUR packages installed.${RC}"
}

## Post-installation tweaks

setup_post_install() {
    print_step "Performing post-installation tweaks..."

    # Build bat cache
    printf "%b\n" "  Building bat cache..."
    bat cache --build || printf "%b\n" "${YELLOW}Warning: Failed to build bat cache.${RC}\n" # Non-critical failure

    # Add other post-install steps here if needed

    printf "%b\n" "${GREEN}Post-installation tweaks complete.${RC}"
}


## Main Entry Point

main() {
    check_arch
    printf "%b\n" "Welcome ${CYAN}4ndr0666!${RC}"
	printf "%b\n" "One second while I setup the machine up..."
	sleep 1 # Optional delay

    setuprepos
	setupfont
    install_yay
    install_official_pkgs
    install_aur_pkgs
    setup_post_install

    printf "\n%b\n" "${GREEN}${BOLD}Machine is ready to go!${RC}"
}

main "$@"
