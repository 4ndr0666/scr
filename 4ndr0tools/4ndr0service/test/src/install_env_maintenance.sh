#!/usr/bin/env bash
# File: install_env_maintenance.sh
# Description: Deployment engine for systemd environment healing.

set -euo pipefail
IFS=$'\n\t'

# Fixed Source Bootstrap
_SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"
# Path to common.sh relative to test/src/
source "$(dirname "$(dirname "$_SCRIPT_DIR")")/common.sh"

SYSTEMD_USER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
ensure_dir "$SYSTEMD_USER_DIR"

install_unit() {
    local src="$1"
    local dest="$SYSTEMD_USER_DIR/$(basename "$src")"

    # Patch the ExecStart to use the absolute PKG_PATH resolved at runtime
    sed "s|ExecStart=.*|ExecStart=$PKG_PATH/main.sh --fix --report|g" "$src" > "$dest"
    log_info "Patched and deployed: $dest"
}

# Deploy all units from the systemd/user/ source directory
for unit in "$PKG_PATH/systemd/user/"*.{service,timer}; do
    [[ -f "$unit" ]] && install_unit "$unit"
done

log_info "Reloading systemd user daemon..."
systemctl --user daemon-reload

log_info "Enabling Maintenance Sentinel..."
systemctl --user enable --now env_maintenance.timer

log_success "4ndr0service Healing Loop ACTIVE."
