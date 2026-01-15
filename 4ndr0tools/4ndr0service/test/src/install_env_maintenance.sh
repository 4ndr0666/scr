#!/usr/bin/env bash
# File: install_env_maintenance.sh
# Description: Installs and enables systemd maintenance units for 4ndr0service.

set -euo pipefail
IFS=$'\n\t'

# Source common for path and logging
# shellcheck source=../../common.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../..")" && pwd -P)/common.sh"

SYSTEMD_USER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
ensure_dir "$SYSTEMD_USER_DIR"

install_unit() {
    local src="$1"
    local dest="$SYSTEMD_USER_DIR/$(basename "$src")"
    
    # Update PKG_PATH in the service file to point to current installation
    sed "s|ExecStart=.*|ExecStart=$PKG_PATH/main.sh --fix --report|g" "$src" > "$dest"
    log_info "Installed and patched unit: $dest"
}

for unit in "$PKG_PATH/systemd/user/"*.{service,timer}; do
    if [[ -f "$unit" ]]; then
        install_unit "$unit"
    fi
done

log_info "Reloading systemd user daemon..."
systemctl --user daemon-reload

log_info "Enabling maintenance timer..."
systemctl --user enable --now env_maintenance.timer

log_success "4ndr0service maintenance scheduled."
