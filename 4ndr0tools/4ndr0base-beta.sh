#!/usr/bin/env bash
Author: 4ndr0666

============================== // 4NDR0BASE.SH //

Description: Quick setup script for basic requirements

              on a new machine.

------------------------------------------------


Exit immediately if a command exits with a non-zero status.

Treat unset variables as an error.

Cause a pipeline to return the exit status of the last command that failed.

set -euo pipefail

Constants


Use declare -r for constants, -ra for read-only indexed arrays

declare -r AUR_HELPER="yay"

Colors


declare -r RC='\033[0m'
declare -r RED='\033[31m'
declare -r YELLOW='\033[33m'
declare -r CYAN='\033[36m'
declare -r GREEN='\033[32m'
declare -r BOLD='\033[1m'
export RC RED YELLOW CYAN GREEN BOLD # Optional, printf %b handles escapes without export



Package Lists


Use declare -ra for read-only indexed arrays

declare -ra PKGS_OFFICIAL=(
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
)
Use declare -ra for read-only indexed arrays

declare -ra PKGS_AUR=(
	git-extras
	pacdiff
    sysz
   # brave-beta-bin # Commented out in original, keep commented

    bashmount-git
    breeze-hacked-cursor-theme-git
    lf-git
)


Helpers


print_step: Prints a formatted step message

Fix SC2145: Use "$*" to pass all arguments as a single string

print_step() {
    printf "%b\n" "${BOLD}${CYAN}:: $*${RC}"
}

error: Prints a formatted error message and exits

error() {
    printf "%b\n" "${RED}ERROR: $1${RC}" >&2
    exit 1
}

check_command: Checks if a required command exists

check_command() {
    local cmd="$1"
    print_step "Checking for required command: $cmd..."
    # Use >/dev/null 2>&1 instead of &>/dev/null as requested
    if ! command -v "$cmd" >/dev/null 2>&1; then
        error "Required command '$cmd' not found. Please install it before running this script."
    fi
    printf "%b\n" "${GREEN}  Command '$cmd' found.${RC}"
}

check_arch: Verifies the system is Arch Linux

check_arch() {
    print_step "Checking if system is Arch Linux..."
    if ! grep -q "Arch" /etc/os-release; then
        error "This script is intended for Arch Linux only."
    fi
    printf "%b\n" "${GREEN}  System is Arch Linux.${RC}"
}

Chaotic AUR


setuprepos: Configures the Chaotic AUR repository

setuprepos() {
    print_step "Setting up Chaotic AUR repository..."

    # Refresh Keyrings
    printf "%b\n" "  Refreshing archlinux-keyring..."
    # Added --noconfirm for consistency
    sudo pacman --noconfirm -Sy archlinux-keyring || error "Failed to refresh archlinux-keyring."

    # Import and sign Chaotic-AUR key
    printf "%b\n" "  Importing and signing Chaotic-AUR key..."
    # Ensure curl is available (checked at script start)
    sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com || error "Failed to receive Chaotic-AUR key."
    sudo pacman-key --lsign-key 3056513887B78AEB || error "Failed to sign Chaotic-AUR key."

    # Install Chaotic-AUR keyring and mirrorlist
    printf "%b\n" "  Installing Chaotic-AUR Keyring and Mirrorlist..."
    # Ensure curl is available (checked at script start)
    sudo pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' --noconfirm || error "Failed to install Chaotic-AUR packages."

    # Add Repo To pacman.conf if not already present
    printf "%b\n" "  Adding Chaotic-AUR repo to pacman.conf..."
    if ! grep -q "^\[chaotic-aur\]" /etc/pacman.conf; then
        # Corrected tee error handling: check tee's exit status directly
        echo "[chaotic-aur]
Include = /etc/pacman.d/mirrorlist-arch" | sudo tee -a /etc/pacman.conf || error "Failed to add Chaotic-AUR repo to pacman.conf."
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

Nerd Font


setupfont: Downloads and installs Meslo Nerd Font

setupfont() {
    print_step "Setting up Meslo Nerd Font..."
    local font_dir="$HOME/.local/share/fonts" # Use lowercase for local vars
    local font_zip="$font_dir/Meslo.zip"
    local font_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip"

    # SC2155: Declare and assign separately
    local font_installed_check # Declare first
    # Check if font is already installed using fc-list
    font_installed_check=$(fc-list | grep -i "Meslo") # Assign

    if [ -n "$font_installed_check" ]; then
        printf "%b\n" "${GREEN}  Meslo Nerd-fonts are already installed.${RC}"
        return 0
    fi

    printf "%b\n" "  Meslo Nerd-fonts not found, installing..."

    # Create font directory if it doesn't exist (-p is idempotent)
    if [ ! -d "$font_dir" ]; then
        printf "%b\n" "  Creating font directory: $font_dir"
        mkdir -p "$font_dir" || error "Failed to create directory: $font_dir"
    else
        printf "%b\n" "  $font_dir exists, skipping creation."
    fi

    # Download the font zip file if it doesn't exist
    if [ ! -f "$font_zip" ]; then
        printf "%b\n" "  Downloading Meslo Nerd-fonts from $font_url..."
        # Ensure curl is available (checked at script start)
        curl -sSLo "$font_zip" "$font_url" || error "Failed to download Meslo Nerd-fonts from $font_url"
    else
        printf "%b\n" "  $font_zip already exists, skipping download."
    fi

    # Check if the zip file was successfully downloaded/exists before attempting unzip
    if [ -f "$font_zip" ]; then
        printf "%b\n" "  Unzipping Meslo Nerd-fonts..."
        # Unzip into the font directory (-o overwrites existing files, idempotent)
        # Ensure unzip is available (installed via PKGS_OFFICIAL)
        unzip -o "$font_zip" -d "$font_dir" || error "Failed to unzip $font_zip"

        # Remove the zip file after successful unzip
        printf "%b\n" "  Removing zip file: $font_zip"
        rm "$font_zip" || printf "%b\n" "${YELLOW}Warning: Failed to remove $font_zip${RC}\n" # Non-critical failure
    else
        # This case should ideally not be reached if set -e is active and download failed
        error "Font zip file not found after download attempt."
    fi

    printf "%b\n" "  Rebuilding font cache..."
    fc-cache -fv || error "Failed to rebuild font cache"

    printf "%b\n" "${GREEN}Meslo Nerd-fonts installed.${RC}"
}

Install Yay


install_yay: Builds and installs the AUR helper yay

install_yay() {
    print_step "Installing AUR helper ($AUR_HELPER)..."
    # Check if yay is already installed
    # Use >/dev/null 2>&1 instead of &>/dev/null as requested
    if ! command -v "$AUR_HELPER" >/dev/null 2>&1; then
        printf "%b\n" "  $AUR_HELPER not found, installing..."
        local yay_tmp_dir="/tmp/$AUR_HELPER" # Use lowercase for local vars

        printf "%b\n" "  Cloning $AUR_HELPER repository..."
        # Ensure git is available (installed via PKGS_OFFICIAL)
        git clone "https://aur.archlinux.org/$AUR_HELPER.git" "$yay_tmp_dir" || {
            error "Failed to clone $AUR_HELPER repository."
        }

        printf "%b\n" "  Building and installing $AUR_HELPER..."
        # Use pushd/popd with checks and redirect output
        pushd "$yay_tmp_dir" > /dev/null || error "Failed to change directory to $yay_tmp_dir."
        # Do NOT suppress makepkg output - it's crucial for debugging AUR build failures
        # Ensure base-devel is installed (via PKGS_OFFICIAL)
        # Run makepkg as the user, not root (important for AUR)
        sudo -u "$USER" makepkg --noconfirm -si || {
            local status=$? # Capture status before popd
            popd > /dev/null || error "Failed to return to original directory."
            error "Failed to build and install $AUR_HELPER. makepkg exited with status $status."
        }
        popd > /dev/null || error "Failed to return to original directory."

        # Clean up the temporary directory
        printf "%b\n" "  Cleaning up temporary directory $yay_tmp_dir..."
        rm -rf "$yay_tmp_dir"

        printf "%b\n" "${GREEN}$AUR_HELPER installed successfully.${RC}"
    else
        printf "%b\n" "${GREEN}  ($AUR_HELPER) is already installed.${RC}"
    fi
}

install_official_pkgs: Installs packages from the official Arch repositories

install_official_pkgs() {
    print_step "Installing official packages..."
    # Check if list is empty
    if [ ${#PKGS_OFFICIAL[@]} -eq 0 ]; then
        printf "%b\n" "${YELLOW}  No official packages listed, skipping installation.${RC}"
        return 0
    fi

    printf "%b\n" "  Packages: ${PKGS_OFFICIAL[*]}\n"
    # Sync pacman databases first
    sudo pacman -Sy --noconfirm || error "Failed to sync pacman databases before installing official packages."
    # Install packages using --needed for idempotency
    # Do NOT suppress pacman output - it's crucial for debugging installation failures
    sudo pacman -S --noconfirm --needed "${PKGS_OFFICIAL[@]}" || error "Failed to install official packages."
    printf "%b\n" "${GREEN}Official packages installed.${RC}"
}

install_aur_pkgs: Installs packages from the AUR using the configured helper

install_aur_pkgs() {
    print_step "Installing AUR packages using $AUR_HELPER..."
    # Ensure yay is available before attempting to use it
    # Use >/dev/null 2>&1 instead of &>/dev/null as requested
    if ! command -v "$AUR_HELPER" >/dev/null 2>&1; then
        error "$AUR_HELPER is not installed. Cannot install AUR packages."
    fi

    # Check if AUR package list is empty
    if [ ${#PKGS_AUR[@]} -eq 0 ]; then
        printf "%b\n" "${YELLOW}  No AUR packages listed, skipping AUR installation.${RC}"
        return 0
    fi

    printf "%b\n" "  Packages: ${PKGS_AUR[*]}\n"
    # Install packages using --needed for idempotency
    # Do NOT suppress yay output - it's crucial for debugging AUR build/installation failures
    "$AUR_HELPER" -S --noconfirm --needed "${PKGS_AUR[@]}" || error "Failed to install AUR packages."
    printf "%b\n" "${GREEN}AUR packages installed.${RC}"
}

setup_post_install: Performs post-installation tweaks

setup_post_install() {
    print_step "Performing post-installation tweaks..."

    # Build bat cache
    printf "%b\n" "  Building bat cache..."
    # Check if bat is installed before trying to build cache
    # Use >/dev/null 2>&1 instead of &>/dev/null as requested
    if command -v bat >/dev/null 2>&1; then
        bat cache --build || printf "%b\n" "${YELLOW}Warning: Failed to build bat cache.${RC}\n" # Non-critical failure
    else
        printf "%b\n" "${YELLOW}Warning: bat not found, skipping bat cache build.${RC}\n"
    fi

    # Add other post-install steps here if needed

    printf "%b\n" "${GREEN}Post-installation tweaks complete.${RC}"
}

Main Entry Point


main: Orchestrates the setup process

main() {
    printf "%b\n" "Welcome ${CYAN}4ndr0666!${RC}"
    sleep 1 # Cosmetic delay
	printf "%b\n" "One second while I setup the machine up..."

    # --- Initial Checks ---
    check_arch
    # Check for essential commands needed early
    check_command "curl"
    check_command "git" # Needed for yay install

    # --- Setup Steps (Order matters based on dependencies) ---
    setuprepos # Needs pacman, pacman-key, curl, tee
    install_official_pkgs # Needs pacman, installs git, unzip, base-devel etc.
    install_yay # Needs git (from base-devel)
	setupfont # Needs curl, unzip (from official pkgs)
    install_aur_pkgs # Needs yay
    setup_post_install # Needs bat (from official pkgs)

    printf "\n%b\n" "${GREEN}${BOLD}Machine is ready to go!${RC}"
}

Execute the main function with any command line arguments

main "$@"
