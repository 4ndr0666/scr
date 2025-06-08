#!/usr/bin/env bash
# shellcheck disable=all
# File: optimize_meson.sh
# Description: Meson & Ninja build tools optimization (XDG-compliant).

set -euo pipefail
IFS=$'\n\t'

# Determine root and source common
PKG_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=../common.sh
source "$PKG_PATH/common.sh"

install_meson() {
	if ! command -v meson &>/dev/null; then
		log_info "Installing Meson via pacman."
		sudo pacman -S --needed --noconfirm meson &&
			log_info "Meson installed." ||
			log_warn "Meson pacman install failed."
	else
		log_info "Meson already present: $(meson --version)"
	fi
}

install_ninja() {
	if ! command -v ninja &>/dev/null; then
		log_info "Installing Ninja via pacman."
		sudo pacman -S --needed --noconfirm ninja &&
			log_info "Ninja installed." ||
			log_warn "Ninja pacman install failed."
	else
		log_info "Ninja present: $(ninja --version)"
	fi
}

optimize_meson() {
	log_info "🔧 Optimizing Meson & Ninja..."
	install_meson
	install_ninja
	log_info "Meson & Ninja optimization done."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	optimize_meson
fi
