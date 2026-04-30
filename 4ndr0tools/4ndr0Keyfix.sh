#!/usr/bin/env bash
# Author: 4ndr0666
set -euo pipefail
# ==================== // 4ndr0keyfix //

## Colors

readonly CYAN='\033[38;2;21;255;255m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[0;33m'
readonly NC='\033[0m' # No Color
readonly GOOD="✔️"
readonly INFO="➡️"
readonly ERROR_ICON="❌"
readonly EXPLOSION="💥"

boom() {
	echo -e "${EXPLOSION} $*${NC}"
}

success() {
	echo -e "${GOOD} ${CYAN}$*${NC}"
}

info() {
	echo -e "${INFO} ${CYAN}$*${NC}"
}

error() {
	echo -e "${ERROR_ICON} ${RED}Error: $*${NC}" >&2
	exit 1
}

## TRAP

cleanup() {
	# Add any necessary cleanup here (e.g., remove temp files, restore state)
	# echo "Cleanup complete." # Optional: Add a cleanup message
	: # No-op command if no cleanup is needed
}
trap cleanup EXIT

## Validate

check_commands() {
	info "Checking for required commands..."
	local required_commands=("pacman" "pacman-key" "sudo" "rm" "tee" "grep")
	for cmd in "${required_commands[@]}"; do
		if ! command -v "$cmd" &>/dev/null; then
			error "Required command '$cmd' not found. Please install it."
		fi
	done
	success "Required commands found."
}

## Help

usage() {
	echo "Usage: $(basename "$0")"
	echo "Fixes common Pacman key issues by reinitializing and repopulating the keyring."
	echo "Requires root privileges."
	exit 1 # Exit with error status for usage
}

## Removal

remove_databases_and_keys() {
	info "Removing corrupt pacman database and gpg files..."
	sleep 1
	# Remove sync databases
	info "Removing /var/lib/pacman/sync/*..."
	# rm -rf exits 0 even if files don't exist, which is fine.
	# It will only exit non-zero on permission errors or similar critical issues.
	if rm -rf /var/lib/pacman/sync/*; then
		success "Pacman sync databases removed."
		sleep 1
	else
		# If rm -rf failed, it's likely a permissions issue or similar.
		error "Failed to remove files in /var/lib/pacman/sync. Check permissions."
	fi

	# Remove gnupg files
	info "Removing /etc/pacman.d/gnupg/*..."
	if rm -rf /etc/pacman.d/gnupg/*; then
		success "/etc/pacman.d/gnupg files removed."
	else
		error "Failed to remove files in /etc/pacman.d/gnupg. Check permissions."
	fi
}

## Initialization

initialize_pacman_key() {
	info "Initializing Pacman-key keyring..."
	# --init requires sufficient entropy. May take time.
	if pacman-key --init; then
		success "Pacman-key keyring initialized."
	else
		error "Failed to initialize Pacman-key keyring."
	fi
}

## Populate

populate_pacman_key() {
	info "Populating Pacman-key with default distribution keys..."
	# Specify 'archlinux' to populate only the official Arch keyring.
	# Use --quiet to reduce output unless needed for debugging.
	if pacman-key --populate archlinux; then
		success "Pacman-key populated with archlinux keys."
	else
		error "Failed to populate Pacman-key with archlinux keys."
	fi

	# Optional: Add a fallback keyserver to gpg.conf if it doesn't exist
	# This can help if default keyservers used by pacman-key are unavailable.
	local gpg_conf="/etc/pacman.d/gnupg/gpg.conf"
	local keyserver_line="keyserver hkp://keyserver.ubuntu.com:80"
	info "Checking/Adding fallback keyserver to $gpg_conf..."
	if [ -f "$gpg_conf" ]; then
		if ! grep -q "^${keyserver_line}$" "$gpg_conf"; then
			if echo "$keyserver_line" | tee -a "$gpg_conf" >/dev/null; then
				success "Fallback keyserver added to $gpg_conf."
			else
				# tee failed - likely permissions
				error "Failed to add fallback keyserver to $gpg_conf. Check permissions."
			fi
		else
			info "Fallback keyserver already present in $gpg_conf."
		fi
	else
		# gpg.conf might not exist immediately after --init.
		# This case is less common but handle it.
		if echo "$keyserver_line" | tee "$gpg_conf" >/dev/null; then
			success "Fallback keyserver added to $gpg_conf (created file)."
		else
			error "Failed to add fallback keyserver to $gpg_conf (file not found/creatable). Check permissions."
		fi
	fi
}

## Sync

sync_and_reinstall_keyring() {
	info "Syncing pacman databases..."
	# Use --quiet to reduce output unless needed for debugging.
	if pacman -Sy --quiet; then
		success "Pacman databases synced."
	else
		error "Failed to sync pacman databases. Check network connection and mirrorlist."
	fi

	info "Reinstalling archlinux-keyring..."
	# Use -S to reinstall. -y is not needed again after the sync step.
	# --noconfirm is used as per original scripts, but be aware this bypasses prompts.
	# Consider removing --noconfirm in interactive use.
	if pacman -S archlinux-keyring --noconfirm --quiet; then
		success "archlinux-keyring reinstalled."
	else
		error "Failed to reinstall archlinux-keyring."
	fi
}

## Main Entry Point

main() {
	if [ "$#" -gt 0 ]; then
		usage
	fi
	check_commands
	if [[ "$EUID" -ne 0 ]]; then
		boom "Escalating Privileges..."
		sudo "$0" "$@"
		exit $?
	fi
	info "Starting Pacman key fix process..."

	# Execute core steps, relying on set -e for early exit on failure
	remove_databases_and_keys
	initialize_pacman_key
	populate_pacman_key
	sync_and_reinstall_keyring

	success "Pacman keys should now be fixed! You can try 'pacman -Syu' now."
	exit 0 # Explicitly exit with success status
}

main "$@"
