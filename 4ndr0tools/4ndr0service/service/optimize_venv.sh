#!/usr/bin/env bash
# shellcheck disable=all
# File: optimize_venv.sh
# Description: Python venv & pipx optimization (XDG-compliant).

set -euo pipefail
IFS=$'\n\t'

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

pipx_install_or_update() {
	local pkg="$1"
	if pipx list | grep -q "$pkg"; then
		echo "🔄 Upgrading $pkg via pipx..."
		pipx upgrade "$pkg" &&
			log "$pkg upgraded." ||
			log "Warning: pipx upgrade failed for $pkg."
	else
		echo "📦 Installing $pkg via pipx..."
		pipx install "$pkg" &&
			log "$pkg installed." ||
			log "Warning: pipx install failed for $pkg."
	fi
}

optimize_venv_service() {
	echo "🔧 Optimizing Python venv environment..."

	command -v python3 &>/dev/null || handle_error "python3 not found."

	VENV_HOME="${VENV_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/virtualenv}"
	VENV_PATH="$VENV_HOME/.venv"
	mkdir -p "$VENV_HOME"
	if [[ ! -d "$VENV_PATH" ]]; then
		echo "Creating venv at $VENV_PATH..."
		python3 -m venv "$VENV_PATH" || handle_error "venv creation failed."
	else
		echo "Venv already exists at $VENV_PATH."
	fi

	source "$VENV_PATH/bin/activate" || handle_error "Failed activating venv."

	pip install --upgrade pip || log "Warning: pip upgrade failed."

	pipx_install_or_update black
	pipx_install_or_update flake8
	pipx_install_or_update mypy
	pipx_install_or_update pytest

	check_directory_writable "$VENV_PATH"

	echo -e "${GREEN}🎉 venv optimization complete.${NC}"
	log "venv optimization completed."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	optimize_venv_service
fi
