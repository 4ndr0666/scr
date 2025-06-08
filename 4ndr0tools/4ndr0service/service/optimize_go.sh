#!/usr/bin/env bash
# shellcheck disable=all
# File: optimize_go.sh
# Author: 4ndr0666
# Date: 2024-11-24
# Description: Optimizes Go environment.

set -euo pipefail
IFS=$'\n\t'

CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

LOG_FILE="${LOG_FILE:-$HOME/.cache/4ndr0service/logs/service_optimization.log}"
mkdir -p "$(dirname "$LOG_FILE")" || {
	echo "Failed to create log directory."
	exit 1
}

log() {
	local message="$1"
	echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $message" >>"$LOG_FILE"
}

handle_error() {
	local error_message="$1"
	echo -e "${RED}❌ Error: $error_message${NC}" >&2
	log "ERROR: $error_message"
	exit 1
}

check_directory_writable() {
	local dir_path="$1"
	if [[ -w "$dir_path" ]]; then
		echo "✅ Directory $dir_path is writable."
		log "Directory '$dir_path' is writable."
	else
		handle_error "Directory $dir_path is not writable."
	fi
}

install_go() {
	if command -v go &>/dev/null; then
		echo "✅ Go is already installed: $(go version)."
		log "Go is already installed."
		return 0
	fi

	if command -v pacman &>/dev/null; then
		echo "Installing Go using pacman..."
		sudo pacman -Syu --needed go || handle_error "Failed to install Go with pacman."
	elif command -v apt-get &>/dev/null; then
		echo "Installing Go using apt-get..."
		sudo apt-get update && sudo apt-get install -y golang || handle_error "Failed to install Go with apt-get."
	elif command -v dnf &>/dev/null; then
		echo "Installing Go using dnf..."
		sudo dnf install -y golang || handle_error "Failed to install Go with dnf."
	elif command -v brew &>/dev/null; then
		echo "Installing Go using Homebrew..."
		brew install go || handle_error "Failed to install Go with Homebrew."
	else
		handle_error "Unsupported package manager. Go installation aborted."
	fi
	echo "✅ Go installed successfully."
	log "Go installed successfully."
}

update_go() {
	if command -v pacman &>/dev/null; then
		echo "🔄 Updating Go using pacman..."
		sudo pacman -Syu --needed go || handle_error "Failed to update Go with pacman."
		echo "✅ Go updated successfully with pacman."
		log "Go updated with pacman."
	elif command -v apt-get &>/dev/null; then
		echo "🔄 Updating Go using apt-get..."
		sudo apt-get update && sudo apt-get install --only-upgrade -y golang || handle_error "Failed to update Go with apt-get."
		echo "✅ Go updated successfully with apt-get."
		log "Go updated with apt-get."
	elif command -v dnf &>/dev/null; then
		echo "🔄 Updating Go using dnf..."
		sudo dnf upgrade -y golang || handle_error "Failed to update Go with dnf."
		echo "✅ Go updated with dnf."
		log "Go updated with dnf."
	elif command -v brew &>/dev/null; then
		echo "🔄 Updating Go using Homebrew..."
		brew upgrade go || handle_error "Failed to update Go with Homebrew."
		echo "✅ Go updated with Homebrew."
		log "Go updated with Homebrew."
	else
		handle_error "No recognized package manager => cannot update Go."
	fi
}

setup_go_paths() {
	local go_path="${XDG_DATA_HOME:-$HOME/.local/share}/go"
	local go_bin="${go_path}/bin"
	mkdir -p "$go_bin"
	if [[ ":$PATH:" != *":$go_bin:"* ]]; then
		export PATH="$go_bin:$PATH"
		echo "Added $go_bin to PATH."
		log "Added $go_bin to PATH."
	fi
}

install_go_tools() {
	# Example: install or update common Go tools
	echo "Installing or updating Go tools (gopls, golangci-lint)..."
	go install golang.org/x/tools/gopls@latest 2>/dev/null || log "Warning: gopls install/update failed."
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest 2>/dev/null || log "Warning: golangci-lint install/update failed."
}

manage_permissions() {
	# Example placeholder for managing Go-related file permissions
	echo "Ensuring Go directories have correct permissions..."
	local go_mod_cache="${GOMODCACHE:-$(go env GOMODCACHE 2>/dev/null || echo "$HOME/go/pkg/mod")}"
	if [[ -n "$go_mod_cache" ]]; then
		chmod -R u+rw "${go_mod_cache}" 2>/dev/null || true
	fi
}

manage_go_versions() {
	# Placeholder: Could handle multiple Go versions if needed
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
		echo "🗑️ Cleaning up $GOMODCACHE/tmp..."
		rm -rf "${GOMODCACHE:?}/tmp" || log "Warning: Failed to remove tmp in $GOMODCACHE."
		log "Cleaned up $GOMODCACHE/tmp."
	fi
	echo "🧼 Final cleanup completed."
	log "Go final cleanup tasks completed."
}

optimize_go_service() {
	echo "🔧 Starting Go environment optimization..."
	echo "🔍 Checking if Go is installed and up to date..."
	install_go

	local current_go_version
	current_go_version="$(go version | awk '{print $3}')"
	local latest_go_version
	latest_go_version="$(get_latest_go_version || echo "")"
	if [[ -n "$latest_go_version" && "$current_go_version" != "$latest_go_version" ]]; then
		echo "⏫ Updating Go from $current_go_version to $latest_go_version..."
		update_go
	else
		echo "✅ Go is up to date: $current_go_version."
		log "Go is up to date: $current_go_version."
	fi

	echo "🛠️ Ensuring Go environment variables are correct..."
	setup_go_paths

	echo "🔧 Installing or updating Go tools..."
	install_go_tools

	echo "🔐 Checking and managing permissions..."
	manage_permissions

	echo "🔄 Managing multi-version Go support..."
	manage_go_versions

	echo "✅ Validating Go installation..."
	validate_go_installation

	echo "🧼 Performing final cleanup..."
	perform_go_cleanup

	echo "🎉 Go environment optimization complete."
	echo -e "${CYAN}GOPATH:${NC} $GOPATH"
	echo -e "${CYAN}GOROOT:${NC} $GOROOT"
	echo -e "${CYAN}GOMODCACHE:${NC} $GOMODCACHE"
	echo -e "${CYAN}Go version:${NC} $(go version)"
	log "Go environment optimization completed."
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
