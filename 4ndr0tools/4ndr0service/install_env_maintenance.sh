#!/usr/bin/env bash
# File: test/src/install_env_maintenance.sh
# Hardened systemd timer installer with retry + path embedding

set -euo pipefail
IFS=$'\n\t'

source "$PKG_PATH/common.sh"

SYSTEMD_USER_DIR="${XDG_CONFIG_HOME}/systemd/user"
ensure_dir "$SYSTEMD_USER_DIR"

install_unit() {
    local src="$1" dest="$SYSTEMD_USER_DIR/$(basename "$src")"
    cp -f "$src" "$dest" && log_info "Installed $dest"
}

for unit in "$PKG_PATH/systemd/user/"*.service "$PKG_PATH/systemd/user/"*.timer; do
    [[ -f "$unit" ]] && install_unit "$unit"
done

log_info "Reloading systemd daemon..."
retry systemctl --user daemon-reload

log_info "Enabling daily healing timer..."
retry systemctl --user enable --now env_maintenance.timer

log_info "4ndr0service daily self-healing activated."
