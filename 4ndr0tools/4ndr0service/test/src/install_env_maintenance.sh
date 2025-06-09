#!/usr/bin/env bash
# shellcheck disable=all
# 4ndr0service Systemd Env Maintenance Installer
set -euo pipefail

# Compute PKG_PATH relative to this script
PKG_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# shellcheck source=../common.sh
source "$PKG_PATH/common.sh"

SYSTEMD_USER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
ensure_dir "$SYSTEMD_USER_DIR"

# Install verify_environment.sh into ~/.local/bin for unit invocation
LOCAL_BIN="$HOME/.local/bin"
ensure_dir "$LOCAL_BIN"
if install -Dm755 "$PKG_PATH/test/src/verify_environment.sh" \
	"$LOCAL_BIN/verify_environment.sh"; then
	echo "Installed $LOCAL_BIN/verify_environment.sh"
else
	echo "Warning: failed to install verify_environment.sh" >&2
fi

# Copy or symlink units
install_unit() {
	local src="$1"
	local dest="$SYSTEMD_USER_DIR/$(basename "$src")"
	cp -f "$src" "$dest"
	echo "Installed $dest"
}

# Install units
for unit in "$PKG_PATH/systemd/user/"*; do
	[ -e "$unit" ] || continue
	install_unit "$unit"
done

echo "Reloading systemd user units..."
systemctl --user daemon-reload

echo "Enabling 4ndr0service environment maintenance timer..."
systemctl --user enable --now env_maintenance.timer

echo "Done."
