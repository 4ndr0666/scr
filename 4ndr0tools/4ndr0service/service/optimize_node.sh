#!/usr/bin/env bash
# File: optimize_node.sh
# Description: Node.js environment optimization for the 4ndr0service suite.
# Ensures Node.js (via nvm) and global CLI tools are set up using XDG directories.

set -euo pipefail
IFS=$'\n\t'

# PKG_PATH is expected to be set and exported by common.sh, sourced by main.sh
# Source common.sh to ensure logging functions and PKG_PATH are available
# shellcheck source=4ndr0tools/4ndr0service/common.sh
source "$PKG_PATH/common.sh"

# Ensure CONFIG_FILE is available
create_config_if_missing

# Define XDG-compliant paths for nvm
export NVM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvm"
export NODE_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/node"
export NODE_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/node"

# Ensure nvm is installed and loaded
install_nvm() {
	if [[ -s "$NVM_DIR/nvm.sh" ]]; then
		# shellcheck disable=SC1090,SC1091
		source "$NVM_DIR/nvm.sh"
		log_info "NVM loaded from $NVM_DIR/nvm.sh"
		return 0
	fi
	log_info "NVM not found, installing via official installer..."
	curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
	# shellcheck disable=SC1090,SC1091
	source "$NVM_DIR/nvm.sh"
	log_info "NVM installed and loaded."
}

install_node() {
	local node_version
	node_version=$(jq -r '.node_version' "$CONFIG_FILE")
	if ! command -v node &>/dev/null; then
		log_info "Installing latest LTS Node.js via nvm."
		nvm install "$node_version"
		nvm use "$node_version"
		nvm alias default "$node_version"
	else
		log_info "Node.js already installed: $(node --version)"
	fi
}

install_global_npm_tools() {
	local -a NPM_GLOBAL_PACKAGES
	mapfile -t NPM_GLOBAL_PACKAGES < <(jq -r '.npm_global_packages[]' "$CONFIG_FILE")

	for tool in "${NPM_GLOBAL_PACKAGES[@]}"; do
		if ! npm list -g --depth=0 | grep -qw "$tool"; then
			log_info "Installing global NPM tool: $tool"
			npm install -g "$tool"
		else
			log_info "$tool already installed globally."
		fi
	done
}
optimize_node_service() {
	log_info "🔧 Starting Node.js environment optimization..."
	# Create NVM and node config/data directories
	mkdir -p "$NVM_DIR" "$NODE_DATA_HOME" "$NODE_CONFIG_HOME"
	install_nvm
	install_node
	install_global_npm_tools

	# Set NODE_PATH for globally installed node modules
	local global_node_path
	global_node_path="$(npm root -g)"
	export NODE_PATH="$global_node_path"

	log_info "Node.js environment optimization complete."
	log_info "Node: $(node --version 2>/dev/null || echo 'not found')"
	log_info "NPM: $(npm --version 2>/dev/null || echo 'not found')"
	log_info "Yarn: $(yarn --version 2>/dev/null || echo 'not found')"
	log_info "NODE_PATH: $NODE_PATH"
	log_info "NVM_DIR: $NVM_DIR"
	log_info "NODE_DATA_HOME: $NODE_DATA_HOME"
	log_info "NODE_CONFIG_HOME: $NODE_CONFIG_HOME"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	optimize_node_service
fi
