#!/usr/bin/env bash
# shellcheck disable=SC2015
# File: optimize_venv.sh
# Description: Python venv & pipx optimization (XDG-compliant).

set -euo pipefail
IFS=$'\n\t'

# PKG_PATH is expected to be set and exported by common.sh, sourced by main.sh
# Source common.sh to ensure logging functions and PKG_PATH are available
# shellcheck source=4ndr0tools/4ndr0service/common.sh
source "$PKG_PATH/common.sh"

# Ensure CONFIG_FILE is available
create_config_if_missing

check_directory_writable() {
	local dir="$1"
	if [[ -w "$dir" ]]; then
		log_info "Dir '$dir' writable."
	else
		handle_error "Directory $dir not writable."
	fi
}

pipx_install_or_update() {
	local pkg="$1"
	if pipx list | grep -q "$pkg"; then
		log_info "Upgrading $pkg via pipx..."
		pipx upgrade "$pkg" &&
			log_info "$pkg upgraded." ||
			log_warn "Warning: pipx upgrade failed for $pkg."
	else
		log_info "Installing $pkg via pipx..."
		pipx install "$pkg" &&
			log_info "$pkg installed." ||
			log_warn "Warning: pipx install failed for $pkg."
	fi
}

optimize_venv_service() {
	local -a VENV_PIPX_PACKAGES
	mapfile -t VENV_PIPX_PACKAGES < <(jq -r '.venv_pipx_packages[]' "$CONFIG_FILE")

	log_info "Optimizing Python venv environment..."

	command -v python3 &>/dev/null || handle_error "python3 not found."

	VENV_HOME="${VENV_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/virtualenv}"
	VENV_PATH="$VENV_HOME/.venv"
	ensure_dir "$VENV_HOME"
	if [[ ! -d "$VENV_PATH" ]]; then
		log_info "Creating venv at $VENV_PATH..."
		python3 -m venv "$VENV_PATH" || handle_error "venv creation failed."
	else
		log_info "Venv already exists at $VENV_PATH."
	fi

	# shellcheck disable=SC1091
	source "$VENV_PATH/bin/activate" || handle_error "Failed activating venv."

	pip install --upgrade pip || log_warn "Warning: pip upgrade failed."

	for pkg in "${VENV_PIPX_PACKAGES[@]}"; do
		pipx_install_or_update "$pkg"
	done

	check_directory_writable "$VENV_PATH"

	log_info "venv optimization complete."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	optimize_venv_service
fi
