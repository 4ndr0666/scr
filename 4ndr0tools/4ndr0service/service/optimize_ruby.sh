#!/usr/bin/env bash
# shellcheck disable=SC2015
# File: optimize_ruby.sh
# Description: Ruby environment optimization (XDG-compliant).

set -euo pipefail
IFS=$'\n\t'

# PKG_PATH is expected to be set and exported by common.sh, sourced by main.sh
# Source common.sh to ensure logging functions and PKG_PATH are available
# shellcheck source=4ndr0tools/4ndr0service/common.sh
source "$PKG_PATH/common.sh"

# Ensure CONFIG_FILE is available
create_config_if_missing

# Set XDG-compliant paths for RubyGems. This is the single source of truth.
export GEM_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/gem"
export GEM_PATH="$GEM_HOME"
export PATH="$GEM_HOME/bin:$PATH"

check_directory_writable() {
	local dir="$1"
	if [[ -w "$dir" ]]; then
		log_info "Directory $dir writable."
	else
		handle_error "Directory $dir not writable."
	fi
}

install_ruby() {
	if ! command -v ruby &>/dev/null; then
		log_info "Installing Ruby..."
		# This assumes pacman. Add other package managers if needed.
		sudo pacman -S --needed --noconfirm ruby ||
			handle_error "Failed to install Ruby."
		log_info "Ruby installed."
	else
		log_info "Ruby present: $(ruby --version)"
		log_info "Ruby already installed."
	fi
}
gem_install_or_update() {
	local gem="$1"
	# Use a more robust check to avoid partial matches
	if gem list --installed "^$gem$" &>/dev/null; then
		log_info "Updating gem $gem..."
		gem update "$gem" &&
			log_info "Gem $gem updated." ||
			log_warn "Warning: update failed for gem $gem."
	else
		log_info "Installing gem $gem..."
		# Remove `--user-install` as it ignores GEM_HOME, violating XDG compliance.
		gem install "$gem" --no-document &&
			log_info "Gem $gem installed." ||
			log_warn "Warning: install failed for gem $gem."
	fi
}

optimize_ruby_service() {
	if ! command -v jq &>/dev/null; then
		log_error "jq is not installed. Please install it to proceed."
		return 1
	fi

	local -a RUBY_GEMS
	# Provide a default empty array `[]` if .ruby_gems is null or missing
	mapfile -t RUBY_GEMS < <(jq -r '(.ruby_gems // [])[]' "$CONFIG_FILE")

	log_info "Optimizing Ruby environment..."

	install_ruby

	# Ensure base directories exist. gem command will handle versioned subdirs.
	ensure_dir "$GEM_HOME"
	ensure_dir "${XDG_CONFIG_HOME:-$HOME/.config}/gem"
	ensure_dir "${XDG_CACHE_HOME:-$HOME/.cache}/gem" ||
		handle_error "Failed to create Ruby dirs."

	log_info "Checking permissions..."
	check_directory_writable "$GEM_HOME"

	if [[ ${#RUBY_GEMS[@]} -eq 0 ]]; then
		log_info "No Ruby gems to install from config."
	else
		for g in "${RUBY_GEMS[@]}"; do
			if [[ -n "$g" ]]; then
				gem_install_or_update "$g"
			fi
		done
	fi

	log_info "Ruby → $(ruby -v)"
	log_info "Ruby optimization completed."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	optimize_ruby_service
fi
