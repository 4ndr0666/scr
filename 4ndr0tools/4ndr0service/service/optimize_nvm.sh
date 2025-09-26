#!/usr/bin/env bash
# shellcheck disable=SC2015
# File: optimize_nvm.sh
# Description: Standalone NVM environment optimization (XDG-compliant).

set -euo pipefail
IFS=$'\n\t'

# PKG_PATH is expected to be set and exported by common.sh, sourced by main.sh
# Source common.sh to ensure logging functions and PKG_PATH are available
# shellcheck source=4ndr0tools/4ndr0service/common.sh
source "$PKG_PATH/common.sh"

# Ensure CONFIG_FILE is available
create_config_if_missing

remove_npmrc_prefix_conflict() {
	local npmrcfile="$HOME/.npmrc"
	if [[ -f "$npmrcfile" ]] && grep -Eq '^(prefix|globalconfig)=' "$npmrcfile"; then
		log_warn "Detected prefix/globalconfig in ~/.npmrc → removing for NVM compatibility."
		sed -i '/^\(prefix\|globalconfig\)=/d' "$npmrcfile" || handle_error "Failed removing prefix/globalconfig from ~/.npmrc."
		log_info "Removed prefix/globalconfig from ~/.npmrc for NVM compatibility."
	fi
}

install_nvm_for_nvm_service() {
	log_info "Installing NVM..."
	if command -v curl &>/dev/null; then
		LATEST_NVM_VERSION=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | jq -r '.tag_name')
		curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${LATEST_NVM_VERSION}/install.sh" | bash ||
			handle_error "Failed to install NVM (curl)."
	elif command -v wget &>/dev/null; then
		LATEST_NVM_VERSION=$(wget -qO- https://api.github.com/repos/nvm-sh/nvm/releases/latest | jq -r '.tag_name')
		wget -qO- "https://raw.githubusercontent.com/nvm-sh/nvm/${LATEST_NVM_VERSION}/install.sh" | bash ||
			handle_error "Failed to install NVM (wget)."
	else
		handle_error "No curl or wget → cannot install NVM."
	fi

	export NVM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvm"
	ensure_dir "$NVM_DIR" || handle_error "Failed to create NVM directory."

	if [[ -d "$HOME/.nvm" && "$HOME/.nvm" != "$NVM_DIR" ]]; then
		mv "$HOME/.nvm" "$NVM_DIR" || handle_error "Failed moving ~/.nvm → $NVM_DIR."
	fi

	export PROVIDED_VERSION="" # avoid unbound in older nvm

	set +u
	# shellcheck disable=SC1091
	# shellcheck disable=SC1091
	[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" || handle_error "Failed sourcing nvm.sh post-install."
	# shellcheck disable=SC1091
	[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion" || handle_error "Failed sourcing nvm bash_completion."
	set -u

	if command -v nvm &>/dev/null; then
		log_info "NVM installed successfully."
	else
		handle_error "NVM missing after installation."
	fi
}

optimize_nvm_service() {
	local node_version
	node_version=$(jq -r '.node_version' "$CONFIG_FILE")

	log_info "Optimizing NVM environment..."
	remove_npmrc_prefix_conflict

	if command -v nvm &>/dev/null; then
		log_info "NVM is already installed."
	else
		log_info "NVM not installed. Installing..."
		install_nvm_for_nvm_service
	fi

	export NVM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvm"
	export PROVIDED_VERSION=""

	set +u
	# shellcheck disable=SC1091
	[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" || handle_error "Failed to source NVM script."
	set -u

	log_info "Installing latest LTS Node.js via NVM..."
	if nvm install "$node_version"; then
		log_info "LTS Node installed."
	else
		log_warn "Warning: nvm install $node_version failed."
	fi

	if nvm use "$node_version"; then
		log_info "Using LTS Node."
	else
		log_warn "Warning: nvm use $node_version failed."
	fi

	if nvm alias default "$node_version"; then
		log_info "Set default alias to $node_version."
	else
		log_warn "Warning: could not set default alias."
	fi

	log_info "NVM optimization complete."
}

# Execute when run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	optimize_nvm_service
fi
