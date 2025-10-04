#!/usr/bin/env bash
# shellcheck disable=SC2015
# File: optimize_electron.sh
# Description: Electron environment optimization (XDG-compliant).

set -euo pipefail
IFS=$'\n\t'

# PKG_PATH is expected to be set and exported by common.sh, sourced by main.sh
# Source common.sh to ensure logging functions and PKG_PATH are available
# shellcheck source=4ndr0tools/4ndr0service/common.sh
source "$PKG_PATH/common.sh"

# Ensure CONFIG_FILE is available
create_config_if_missing

export ELECTRON_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/electron"

npm_global_install_or_update() {
	local pkg="$1"
	if npm ls -g "$pkg" --depth=0 &>/dev/null; then
		log_info "Updating $pkg globally..."
		npm update -g "$pkg" &&
			{
				log_info "$pkg updated."
			} ||
			{
				log_warn "Warning: update failed for $pkg."
			}
	else
		log_info "Installing $pkg globally..."
		npm install -g "$pkg" &&
			{
				log_info "$pkg installed."
			} ||
			{
				log_warn "Warning: install failed for $pkg."
			}
	fi
}

optimize_electron_service() {
	local -a ELECTRON_TOOLS
	mapfile -t ELECTRON_TOOLS < <(jq -r '.electron_tools[]' "$CONFIG_FILE")

	log_info "Optimizing Electron environment..."

	command -v npm &>/dev/null || handle_error "npm not found; install Node.js first."

	if npm ls -g electron --depth=0 &>/dev/null; then
		log_info "Electron already installed."
	else
		log_info "Installing Electron..."
		npm install -g electron &&
			{
				log_info "Electron installed."
			} ||
			handle_error "Failed to install Electron."
	fi

	for tool in "${ELECTRON_TOOLS[@]}"; do
		npm_global_install_or_update "$tool"
	done

	log_info "Setting ELECTRON_OZONE_PLATFORM_HINT=wayland-egl"
	export ELECTRON_OZONE_PLATFORM_HINT="wayland-egl"

	ensure_dir "$ELECTRON_CACHE" || handle_error "Cannot create $ELECTRON_CACHE."
	check_directory_writable "$ELECTRON_CACHE"

	log_info "Cleaning old Electron cache..."
	rm -rf "${ELECTRON_CACHE:?}/"* 2>/dev/null || log_warn "Skipped cache cleanup."

	log_info "Verifying Electron..."
	if command -v electron &>/dev/null; then
		log_info "Electron → $(electron --version)"
		log_info "Electron verified."
	else
		handle_error "Electron verification failed."
	fi

	log_info "Electron optimization complete."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	optimize_electron_service
fi
