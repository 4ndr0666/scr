#!/usr/bin/env bash
# shellcheck disable=SC2015
# File: optimize_cargo.sh
# Description: Rust/Cargo environment optimization (XDG-compliant, Arch Linux).

set -euo pipefail
IFS=$'\n\t'

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Logging
LOG_FILE="${LOG_FILE:-$HOME/.cache/4ndr0service/logs/service_optimization.log}"
mkdir -p "$(dirname "$LOG_FILE")" || {
	echo "Failed to create log directory."
	exit 1
}

log() {
	local msg="$1"
	echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $msg" >>"$LOG_FILE"
}

handle_error() {
	local msg="$1"
	echo -e "${RED}❌ Error: $msg${NC}" >&2
	log "ERROR: $msg"
	exit 1
}

check_directory_writable() {
	local dir="$1"
	[[ -w "$dir" ]] &&
		log "Dir '$dir' writable." ||
		handle_error "Directory $dir not writable."
}

export CARGO_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/cargo"
export RUSTUP_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/rustup"
export PATH="$CARGO_HOME/bin:$PATH"

install_rustup() {
	echo -e "${CYAN}📦 Installing rustup...${NC}"
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path ||
		handle_error "rustup install failed."
        # shellcheck disable=SC1091
        [ -s "$CARGO_HOME/env" ] && source "$CARGO_HOME/env" || handle_error "Failed sourcing rustup env."
	log "rustup installed."
}

update_rustup_and_cargo() {
	echo -e "${CYAN}🔄 Updating rustup + toolchain...${NC}"
	rustup self update 2>/dev/null || log "Warning: rustup self-update failed."
	rustup update stable 2>/dev/null || log "Warning: toolchain update failed."
	rustup default stable 2>/dev/null || log "Warning: setting default toolchain failed."
	log "Rustup and Cargo updated."
}

cargo_install_or_update() {
	local pkg="$1"
	if cargo install --list | grep -q "^$pkg "; then
		echo -e "${CYAN}🔄 Updating $pkg...${NC}"
		cargo install "$pkg" --force 2>/dev/null &&
			log "$pkg updated." ||
			log "Warning: update failed for $pkg."
	else
		echo -e "${CYAN}📦 Installing $pkg...${NC}"
		cargo install "$pkg" 2>/dev/null &&
			log "$pkg installed." ||
			log "Warning: install failed for $pkg."
	fi
}

optimize_cargo_service() {
	echo "🔧 Optimizing Cargo environment..."

	command -v rustup &>/dev/null || install_rustup
	update_rustup_and_cargo

	mkdir -p "$CARGO_HOME" "$RUSTUP_HOME"
	check_directory_writable "$CARGO_HOME"
	check_directory_writable "$RUSTUP_HOME"

	for tool in cargo-update cargo-audit; do
		cargo_install_or_update "$tool"
	done

	echo -e "${GREEN}🎉 Cargo & rustup optimization complete.${NC}"
	log "Cargo optimization completed."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	optimize_cargo_service
fi
