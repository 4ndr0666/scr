#!/usr/bin/env bash
# shellcheck disable=SC2015
# File: optimize_go.sh
# Author: 4ndr0666
# Date: 2024-11-24
# Description: Optimizes Go environment.

set -euo pipefail
IFS=$'\n\t'

# PKG_PATH is expected to be set and exported by common.sh, sourced by main.sh
# Source common.sh to ensure logging functions and PKG_PATH are available
# shellcheck source=4ndr0tools/4ndr0service/common.sh
source "$PKG_PATH/common.sh"

# Ensure CONFIG_FILE is available
create_config_if_missing

check_directory_writable() {
	local dir_path="$1"
	if [[ -w "$dir_path" ]]; then
		log_info "Directory $dir_path is writable."
	else
		handle_error "Directory $dir_path is not writable."
	fi
}

install_go() {
	if command -v go &>/dev/null; then
		log_info "Go is already installed: $(go version)."
		return 0
	fi

	if command -v pacman &>/dev/null; then
		log_info "Installing Go using pacman..."
		sudo pacman -Syu --needed go || handle_error "Failed to install Go with pacman."
	elif command -v apt-get &>/dev/null; then
		log_info "Installing Go using apt-get..."
		sudo apt-get update && sudo apt-get install -y golang || handle_error "Failed to install Go with apt-get."
	elif command -v dnf &>/dev/null; then
		log_info "Installing Go using dnf..."
		sudo dnf install -y golang || handle_error "Failed to install Go with dnf."
	elif command -v brew &>/dev/null; then
		log_info "Installing Go using Homebrew..."
		brew install go || handle_error "Failed to install Go with Homebrew."
	else
		handle_error "Unsupported package manager. Go installation aborted."
	fi
	log_info "Go installed successfully."
}

update_go() {
	if command -v pacman &>/dev/null; then
		log_info "Updating Go using pacman..."
		sudo pacman -Syu --needed go || handle_error "Failed to update Go with pacman."
		log_info "Go updated successfully with pacman."
	elif command -v apt-get &>/dev/null; then
		log_info "Updating Go using apt-get..."
		sudo apt-get update && sudo apt-get install --only-upgrade -y golang || handle_error "Failed to update Go with apt-get."
		log_info "Go updated successfully with apt-get."
	elif command -v dnf &>/dev/null; then
		log_info "Updating Go using dnf..."
		sudo dnf upgrade -y golang || handle_error "Failed to update Go with dnf."
		log_info "Go updated with dnf."
	elif command -v brew &>/dev/null; then
		log_info "Updating Go using Homebrew..."
		brew upgrade go || handle_error "Failed to update Go with Homebrew."
		log_info "Go updated with Homebrew."
	else
		handle_error "No recognized package manager => cannot update Go."
	fi
}

setup_go_paths() {
	local go_path="${XDG_DATA_HOME:-$HOME/.local/share}/go"
	local go_bin="${go_path}/bin"
	ensure_dir "$go_bin"
	if [[ ":$PATH:" != *":$go_bin:"* ]]; then
		export PATH="$go_bin:$PATH"
		log_info "Added $go_bin to PATH."
	fi
}

install_go_tools() {
	local -a GO_TOOLS
	mapfile -t GO_TOOLS < <(jq -r '.go_tools[]' "$CONFIG_FILE")

	log_info "Installing or updating Go tools..."
	for tool in "${GO_TOOLS[@]}"; do
		log_info "Installing/updating $tool..."
		go install "$tool" 2>/dev/null || log_warn "Warning: $tool install/update failed."
	done
}

manage_permissions() {
	log_info "Ensuring Go directories have correct permissions..."
	local go_mod_cache="${GOMODCACHE:-$(go env GOMODCACHE 2>/dev/null || echo "$HOME/go/pkg/mod")}"
	if [[ -n "$go_mod_cache" ]]; then
		chmod -R u+rw "${go_mod_cache}" 2>/dev/null || true
	fi
}

manage_go_versions() {
	log_info "Managing multi-version Go support (placeholder)..."
	true
}

validate_go_installation() {
	if ! command -v go &>/dev/null; then
		handle_error "Go command not found after installation."
	fi
	go version &>/dev/null || handle_error "Go installation seems broken."
}

perform_go_cleanup() {
	if [[ -n "${GOMODCACHE:-}" ]]; then
		log_info "Cleaning up $GOMODCACHE/tmp..."
		rm -rf "${GOMODCACHE:?}/tmp" || log_warn "Warning: Failed to remove tmp in $GOMODCACHE."
		log_info "Cleaned up $GOMODCACHE/tmp."
	fi
	log_info "Final cleanup completed."
}

optimize_go_service() {
	log_info "Starting Go environment optimization..."
	log_info "Checking if Go is installed and up to date..."
	install_go

	local current_go_version
	current_go_version="$(go version | awk '{print $3}')"
	local latest_go_version
	latest_go_version="$(get_latest_go_version || echo "")"
	if [[ -n "$latest_go_version" && "$current_go_version" != "$latest_go_version" ]]; then
		log_info "Updating Go from $current_go_version to $latest_go_version..."
		update_go
	else
		log_info "Go is up to date: $current_go_version."
	fi

	log_info "Ensuring Go environment variables are correct..."
	setup_go_paths

	log_info "Installing or updating Go tools..."
	install_go_tools

	log_info "Checking and managing permissions..."
	manage_permissions

	log_info "Managing multi-version Go support..."
	manage_go_versions

	log_info "Validating Go installation..."
	validate_go_installation

	log_info "Performing final cleanup..."
	perform_go_cleanup

	log_info "Go environment optimization complete."
	log_info "GOPATH: $GOPATH"
	log_info "GOROOT: $GOROOT"
	log_info "GOMODCACHE: $GOMODCACHE"
	log_info "Go version: $(go version)"
}

get_latest_go_version() {
	if command -v pacman &>/dev/null; then
		pacman -Si go | grep -F "Version" | awk '{print $3}'
	elif command -v apt-cache &>/dev/null; then
		apt-cache policy golang | grep -F "Candidate:" | awk '{print $2}'
	elif command -v brew &>/dev/null; then
		brew info go --json=v1 | jq -r '.[0].versions.stable'
	else
		echo ""
	fi
}

# Run optimization if executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	optimize_go_service
fi
