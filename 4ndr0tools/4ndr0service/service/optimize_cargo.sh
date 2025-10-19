#!/usr/bin/env bash
# shellcheck disable=SC2015
# File: optimize_cargo.sh
# Description: Rust/Cargo environment optimization (XDG-compliant, Arch Linux).

set -euo pipefail
IFS=$'\n\t'

# PKG_PATH is expected to be set and exported by common.sh, sourced by main.sh
# Source common.sh to ensure logging functions and PKG_PATH are available
# shellcheck source=4ndr0tools/4ndr0service/common.sh
source "$PKG_PATH/common.sh"

# Ensure CONFIG_FILE is available
create_config_if_missing

export CARGO_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/cargo"
export RUSTUP_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/rustup"
export PATH="$CARGO_HOME/bin:$PATH"

check_directory_writable() {
	local dir="$1"
	if [[ -w "$dir" ]]; then
		log_info "Dir '$dir' writable."
	else
		handle_error "Directory $dir not writable."
	fi
}

install_rustup() {
	log_info "Installing rustup..."
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path ||
		handle_error "rustup install failed."
	# shellcheck disable=SC1091
	[ -s "$CARGO_HOME/env" ] && source "$CARGO_HOME/env" || handle_error "Failed sourcing rustup env."
	log_info "rustup installed."
}

update_rustup_and_cargo() {
	log_info "Updating rustup + toolchain..."
	rustup self update 2>/dev/null || log_warn "Warning: rustup self-update failed."
	rustup update stable 2>/dev/null || log_warn "Warning: toolchain update failed."
	rustup default stable 2>/dev/null || log_warn "Warning: setting default toolchain failed."
	log_info "Rustup and Cargo updated."
}

cargo_install_or_update() {
	local pkg="$1"
	if cargo install --list | grep -q "^$pkg "; then
		log_info "Updating $pkg..."
		cargo install "$pkg" --force 2>/dev/null &&
			log_info "$pkg updated." ||
			log_warn "Warning: update failed for $pkg."
	else
		log_info "Installing $pkg..."
		cargo install "$pkg" 2>/dev/null &&
			log_info "$pkg installed." ||
			log_warn "Warning: install failed for $pkg."
	fi
}

optimize_cargo_service() {
	log_info "Optimizing Cargo environment..."

	if ! command -v jq &>/dev/null; then
		log_error "jq is not installed. Please install it to proceed."
		return 1
	fi

	local -a CARGO_TOOLS
	# Provide a default empty array `[]` if .cargo_tools is null or missing to prevent jq error
	mapfile -t CARGO_TOOLS < <(jq -r '(.cargo_tools // [])[]' "$CONFIG_FILE")

	if ! command -v rustup &>/dev/null; then
		install_rustup
	else
		log_info "rustup is already installed."
	fi
	update_rustup_and_cargo

	ensure_dir "$CARGO_HOME"
	ensure_dir "$RUSTUP_HOME"
	check_directory_writable "$CARGO_HOME"
	check_directory_writable "$RUSTUP_HOME"

	if [[ ${#CARGO_TOOLS[@]} -eq 0 ]]; then
		log_info "No cargo tools to install from config."
	else
		for tool in "${CARGO_TOOLS[@]}"; do
			# Skip if the tool name is empty for any reason
			if [[ -z "$tool" ]]; then
				continue
			fi
			cargo_install_or_update "$tool"
		done
	fi

	log_info "Cargo & rustup optimization complete."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	optimize_cargo_service
fi
