#!/usr/bin/env bash

# Author: 4ndr0666
# ============================== // 4NDR0BASE.SH //
# Description: Quick setup script for basic requirements on a new machine.

set -euo pipefail

## Constants

declare -r AUR_HELPER="yay"

## Colors
declare -r RC='\033[0m'
declare -r RED='\033[31m'
declare -r YELLOW='\033[33m'
declare -r CYAN='\033[36m'
declare -r GREEN='\033[32m'
declare -r BOLD='\033[1m'
export RC RED YELLOW CYAN GREEN BOLD

DRY_RUN=false

usage() {
	cat <<EOF
Usage: ${0##*/} [--dry-run] [--help]

Options:
  --dry-run   Print commands without executing them
  --help      Show this help message and exit
EOF
}

parse_args() {
	while [ "$#" -gt 0 ]; do
		case $1 in
		--dry-run)
			DRY_RUN=true
			;;
		--help | -h)
			usage
			exit 0
			;;
		*)
			error "Unknown option: $1"
			;;
		esac
		shift
	done
}

run_cmd() {
	if [ "$DRY_RUN" = true ]; then
		printf "%b\n" "${YELLOW}[DRY-RUN] $*${RC}"
	else
		"$@" || error "Command failed: $*"
	fi
}

## Package Lists

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
# AUR package list

declare -ra PKGS_AUR=(
	git-extras
	pacdiff
	sysz
	# brave-beta-bin # Commented out in original, keep commented

	bashmount-git
	breeze-hacked-cursor-theme-git
	lf-git
)

#
# # Helpers

# print_step: Prints a formatted step message

# Fix SC2145: Use "$*" to pass all arguments as a single string

print_step() {
	printf "%b\n" "${BOLD}${CYAN}:: $*${RC}"
}

# error: Prints a formatted error message and exits

error() {
	printf "%b\n" "${RED}ERROR: $1${RC}" >&2
	exit 1
}
#
# check_command: Checks if a required command exists

check_command() {
	local cmd="$1"
	print_step "Checking for required command: $cmd..."
	# Use >/dev/null 2>&1 instead of &>/dev/null as requested
	if ! command -v "$cmd" >/dev/null 2>&1; then
		error "Required command '$cmd' not found. Please install it before running this script."
	fi
	printf "%b\n" "${GREEN}  Command '$cmd' found.${RC}"
}

# check_arch: Verifies the system is Arch Linux

check_arch() {
	if [ "$DRY_RUN" = true ]; then
		printf "%b\n" "${YELLOW}[DRY-RUN] Skipping Arch Linux check${RC}"
		return 0
	fi
	print_step "Checking if system is Arch Linux..."
	if ! grep -q "Arch" /etc/os-release; then
		error "This script is intended for Arch Linux only."
	fi
	printf "%b\n" "${GREEN}  System is Arch Linux.${RC}"
}

# Chaotic AUR

# setuprepos: Configures the Chaotic AUR repository

setuprepos() {
	print_step "Setting up Chaotic AUR repository..."

	# Refresh Keyrings
	printf "%b\n" "  Refreshing archlinux-keyring..."
	# Added --noconfirm for consistency
	run_cmd sudo pacman --noconfirm -Sy archlinux-keyring

	# Import and sign Chaotic-AUR key
	printf "%b\n" "  Importing and signing Chaotic-AUR key..."
	# Ensure curl is available (checked at script start)
	run_cmd sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
	run_cmd sudo pacman-key --lsign-key 3056513887B78AEB

	# Install Chaotic-AUR keyring and mirrorlist
	printf "%b\n" "  Installing Chaotic-AUR Keyring and Mirrorlist..."
	# Ensure curl is available (checked at script start)
	run_cmd sudo pacman -U https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst --noconfirm

	# Add Repo To pacman.conf if not already present
	printf "%b\n" "  Adding Chaotic-AUR repo to pacman.conf..."
	if ! grep -q "^\[chaotic-aur\]" /etc/pacman.conf 2>/dev/null; then
		# Corrected tee error handling: check tee's exit status directly
		if [ "$DRY_RUN" = true ]; then
			printf "%b\n" "${YELLOW}[DRY-RUN] Append Chaotic AUR repo to /etc/pacman.conf${RC}"
		else
			echo "[chaotic-aur]
Include = /etc/pacman.d/mirrorlist-arch" | sudo tee -a /etc/pacman.conf || error "Failed to add Chaotic-AUR repo to pacman.conf."
		fi
	else
		printf "%b\n" "  Chaotic-AUR repo already exists in pacman.conf, skipping."
	fi

	# Sync pacman databases
	printf "%b\n" "  Syncing pacman databases..."
	run_cmd sudo pacman -Sy --noconfirm

	# Populate archlinux keys (good practice after sync)
	printf "%b\n" "  Populating archlinux keys..."
	run_cmd sudo pacman-key --populate archlinux

	printf "%b\n" "${GREEN}Chaotic AUR setup complete.${RC}"
}

# Nerd Font

# setupfont: Downloads and installs Meslo Nerd Font

setupfont() {
	print_step "Setting up Meslo Nerd Font..."
	local font_dir="$HOME/.local/share/fonts" # Use lowercase for local vars
	local font_zip="$font_dir/Meslo.zip"
	local font_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip"

	# SC2155: Declare and assign separately
	local font_installed_check=""
	if command -v fc-list >/dev/null 2>&1; then
		font_installed_check=$(fc-list | grep -i "Meslo" || true)
	fi

	if [ -n "$font_installed_check" ]; then
		printf "%b\n" "${GREEN}  Meslo Nerd-fonts are already installed.${RC}"
		return 0
	fi

	if [ "$DRY_RUN" = true ]; then
		printf "%b\n" "${YELLOW}[DRY-RUN] Installing Meslo Nerd Font${RC}"
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
		run_cmd curl -sSLo "$font_zip" "$font_url"
	else
		printf "%b\n" "  $font_zip already exists, skipping download."
	fi

	# Check if the zip file was successfully downloaded/exists before attempting unzip
	if [ -f "$font_zip" ]; then
		printf "%b\n" "  Unzipping Meslo Nerd-fonts..."
		# Unzip into the font directory (-o overwrites existing files, idempotent)
		# Ensure unzip is available (installed via PKGS_OFFICIAL)
		run_cmd unzip -o "$font_zip" -d "$font_dir"

		# Remove the zip file after successful unzip
		printf "%b\n" "  Removing zip file: $font_zip"
		if [ "$DRY_RUN" = true ]; then
			printf "%b\n" "${YELLOW}[DRY-RUN] rm '$font_zip'${RC}"
		else
			rm "$font_zip" || printf "%b\n" "${YELLOW}Warning: Failed to remove $font_zip${RC}\n"
		fi
	else
		# This case should ideally not be reached if set -e is active and download failed
		error "Font zip file not found after download attempt."
	fi

	printf "%b\n" "  Rebuilding font cache..."
	if command -v fc-cache >/dev/null 2>&1; then
		run_cmd fc-cache -fv
	else
		printf "%b\n" "${YELLOW}Warning: fc-cache not found, skipping font cache rebuild.${RC}"
	fi

	printf "%b\n" "${GREEN}Meslo Nerd-fonts installed.${RC}"
}

# Install Yay

# install_yay: Builds and installs the AUR helper yay

install_yay() {
	print_step "Installing AUR helper ($AUR_HELPER)..."
	# Check if yay is already installed
	# Use >/dev/null 2>&1 instead of &>/dev/null as requested
	if ! command -v "$AUR_HELPER" >/dev/null 2>&1; then
		printf "%b\n" "  $AUR_HELPER not found, installing..."
		local yay_tmp_dir="/tmp/$AUR_HELPER" # Use lowercase for local vars

		printf "%b\n" "  Cloning $AUR_HELPER repository..."
		# Ensure git is available (installed via PKGS_OFFICIAL)
		run_cmd git clone "https://aur.archlinux.org/$AUR_HELPER.git" "$yay_tmp_dir"

		printf "%b\n" "  Building and installing $AUR_HELPER..."
		# Use pushd/popd with checks and redirect output
		if [ "$DRY_RUN" = true ]; then
			printf "%b\n" "${YELLOW}[DRY-RUN] build $AUR_HELPER${RC}"
		else
			pushd "$yay_tmp_dir" >/dev/null || error "Failed to change directory to $yay_tmp_dir."
			sudo -u "$USER" makepkg --noconfirm -si || {
				local status=$?
				popd >/dev/null || error "Failed to return to original directory."
				error "Failed to build and install $AUR_HELPER. makepkg exited with status $status."
			}
			popd >/dev/null || error "Failed to return to original directory."
		fi

		# Clean up the temporary directory
		printf "%b\n" "  Cleaning up temporary directory $yay_tmp_dir..."
		if [ "$DRY_RUN" = true ]; then
			printf "%b\n" "${YELLOW}[DRY-RUN] rm -rf '$yay_tmp_dir'${RC}"
		else
			rm -rf "$yay_tmp_dir"
		fi

		printf "%b\n" "${GREEN}$AUR_HELPER installed successfully.${RC}"
	else
		printf "%b\n" "${GREEN}  ($AUR_HELPER) is already installed.${RC}"
	fi
}

# install_official_pkgs: Installs packages from the official Arch repositories

install_official_pkgs() {
	print_step "Installing official packages..."
	# Check if list is empty
	if [ ${#PKGS_OFFICIAL[@]} -eq 0 ]; then
		printf "%b\n" "${YELLOW}  No official packages listed, skipping installation.${RC}"
		return 0
	fi

	printf "%b\n" "  Packages: ${PKGS_OFFICIAL[*]}\n"
	# Sync pacman databases first
	run_cmd sudo pacman -Sy --noconfirm
	# Install packages using --needed for idempotency
	# Do NOT suppress pacman output - it's crucial for debugging installation failures
	if [ "$DRY_RUN" = true ]; then
		printf "%b\n" "${YELLOW}[DRY-RUN] sudo pacman -S --noconfirm --needed ${PKGS_OFFICIAL[*]}${RC}"
	else
		sudo pacman -S --noconfirm --needed "${PKGS_OFFICIAL[@]}" || error "Failed to install official packages."
	fi
	printf "%b\n" "${GREEN}Official packages installed.${RC}"
}

# install_aur_pkgs: Installs packages from the AUR using the configured helper

install_aur_pkgs() {
	print_step "Installing AUR packages using $AUR_HELPER..."
	if [ "$DRY_RUN" != true ]; then
		if ! command -v "$AUR_HELPER" >/dev/null 2>&1; then
			error "$AUR_HELPER is not installed. Cannot install AUR packages."
		fi
	fi

	# Check if AUR package list is empty
	if [ ${#PKGS_AUR[@]} -eq 0 ]; then
		printf "%b\n" "${YELLOW}  No AUR packages listed, skipping AUR installation.${RC}"
		return 0
	fi

	printf "%b\n" "  Packages: ${PKGS_AUR[*]}\n"
	# Install packages using --needed for idempotency
	# Do NOT suppress yay output - it's crucial for debugging AUR build/installation failures
	if [ "$DRY_RUN" = true ]; then
		printf "%b\n" "${YELLOW}[DRY-RUN] $AUR_HELPER -S --noconfirm --needed ${PKGS_AUR[*]}${RC}"
	else
		"$AUR_HELPER" -S --noconfirm --needed "${PKGS_AUR[@]}" || error "Failed to install AUR packages."
	fi
	printf "%b\n" "${GREEN}AUR packages installed.${RC}"
}

# setup_post_install: Performs post-installation tweaks

setup_post_install() {
	print_step "Performing post-installation tweaks..."

	# Build bat cache
	printf "%b\n" "  Building bat cache..."
	# Check if bat is installed before trying to build cache
	# Use >/dev/null 2>&1 instead of &>/dev/null as requested
	if command -v bat >/dev/null 2>&1; then
		if [ "$DRY_RUN" = true ]; then
			printf "%b\n" "${YELLOW}[DRY-RUN] bat cache --build${RC}"
		else
			bat cache --build || printf "%b\n" "${YELLOW}Warning: Failed to build bat cache.${RC}\n"
		fi
	else
		printf "%b\n" "${YELLOW}Warning: bat not found, skipping bat cache build.${RC}\n"
	fi

	# Add other post-install steps here if needed

	printf "%b\n" "${GREEN}Post-installation tweaks complete.${RC}"
}

# Main Entry Point

# main: Orchestrates the setup process

main() {
	parse_args "$@"
	printf "%b\n" "Welcome ${CYAN}4ndr0666!${RC}"
	sleep 1 # Cosmetic delay
	printf "%b\n" "One second while I setup the machine up..."

	# --- Initial Checks ---
	check_arch
	# Check for essential commands needed early
	check_command "curl"
	check_command "git" # Needed for yay install

	# --- Setup Steps (Order matters based on dependencies) ---
	setuprepos            # Needs pacman, pacman-key, curl, tee
	install_official_pkgs # Needs pacman, installs git, unzip, base-devel etc.
	install_yay           # Needs git (from base-devel)
	setupfont             # Needs curl, unzip (from official pkgs)
	install_aur_pkgs      # Needs yay
	setup_post_install    # Needs bat (from official pkgs)

	printf "\n%b\n" "${GREEN}${BOLD}Machine is ready to go!${RC}"
}

# Execute the main function with any command line arguments

main "$@"
