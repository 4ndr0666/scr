#!/usr/bin/env bash
# 4ndr0service Systemd Env Maintenance Installer
set -euo pipefail

# PKG_PATH is expected to be set and exported by common.sh, sourced by main.sh
# Source common.sh to ensure logging functions and PKG_PATH are available
# shellcheck source=4ndr0tools/4ndr0service/common.sh
source "$PKG_PATH/common.sh"

SYSTEMD_USER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
ensure_dir "$SYSTEMD_USER_DIR"

# Install main.sh into ~/.local/bin/4ndr0service for unit invocation
LOCAL_BIN_DIR="$HOME/.local/bin/4ndr0service"
ensure_dir "$LOCAL_BIN_DIR"

if install -Dm755 "$PKG_PATH/main.sh" \
	"$LOCAL_BIN_DIR/main.sh"; then
	log_info "Installed $LOCAL_BIN_DIR/main.sh"
else
	log_warn "Warning: failed to install main.sh" >&2
fi

# Copy or symlink units
install_unit() {
	local src="$1"
	local dest
	dest="$SYSTEMD_USER_DIR/$(basename "$src")"
	cp -f "$src" "$dest"
	log_info "Installed $dest"
}

# Install units
for unit in "$PKG_PATH/systemd/user/"*; do
	[ -e "$unit" ] || continue
	install_unit "$unit"
done

log_info "Reloading systemd user units..."
systemctl --user daemon-reload

log_info "Enabling 4ndr0service environment maintenance timer..."
systemctl --user enable --now env_maintenance.timer

log_info "Done."
