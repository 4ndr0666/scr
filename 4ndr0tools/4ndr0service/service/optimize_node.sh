#!/usr/bin/env bash
# shellcheck disable=all
# File: optimize_node.sh
# Description: Node.js environment optimization for the 4ndr0service suite.
# Ensures Node.js (via nvm) and global CLI tools are set up using XDG directories.

set -euo pipefail
IFS=$'\n\t'

# Establish root path for sourcing and configuration
PKG_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../common.sh
source "$PKG_PATH/common.sh"

# Define XDG-compliant paths for nvm
export NVM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvm"
export NODE_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/node"
export NODE_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/node"

# Ensure nvm is installed and loaded
install_nvm() {
	if [[ -s "$NVM_DIR/nvm.sh" ]]; then
		# shellcheck disable=SC1090
		source "$NVM_DIR/nvm.sh"
		log_info "NVM loaded from $NVM_DIR/nvm.sh"
		return 0
	fi
	log_info "NVM not found, installing via official installer..."
	curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
	# shellcheck disable=SC1090
	source "$NVM_DIR/nvm.sh"
	log_info "NVM installed and loaded."
}

install_node() {
	local node_version="lts/*"
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
	local tools=(npm yarn pnpm typescript eslint prettier)
	for tool in "${tools[@]}"; do
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
	export NODE_PATH="$(npm root -g)"

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
