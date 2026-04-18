#!/usr/bin/env bash
# File: systemd/install_env_maintenance.sh
# Description: Deployment engine for systemd environment healing.
#
# Tree location: PROJECT_ROOT/systemd/install_env_maintenance.sh
# dirname x1 of this script's physical path = PROJECT_ROOT/systemd/
# dirname x2 = PROJECT_ROOT  (where common.sh lives)

set -euo pipefail
IFS=$'\n\t'

# ── PATH RESOLUTION ───────────────────────────────────────────────────────────
# Always self-resolve PKG_PATH from BASH_SOURCE[0] — never trust the inherited
# environment, which may be stale or point to a parent directory.
_SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"

# This script lives at PROJECT_ROOT/systemd/ — one dirname up is the project root.
# FIX: The previous version (written for test/src/ layout) used dirname x2,
#      landing one level too high. The actual tree puts this file at
#      systemd/install_env_maintenance.sh, so only one dirname is needed.
_COMPUTED_PKG_PATH="$(dirname "$_SCRIPT_DIR")"

if [[ ! -f "$_COMPUTED_PKG_PATH/common.sh" ]]; then
    echo "[FATAL] Cannot locate common.sh. Expected: $_COMPUTED_PKG_PATH/common.sh" >&2
    exit 1
fi

export PKG_PATH="$_COMPUTED_PKG_PATH"

# shellcheck source=../common.sh
source "$PKG_PATH/common.sh"

# ── SYSTEMD USER DIRECTORY ────────────────────────────────────────────────────
SYSTEMD_USER_DIR="${XDG_CONFIG_HOME}/systemd/user"
ensure_dir "$SYSTEMD_USER_DIR"

# ── UNIT DEPLOYMENT ───────────────────────────────────────────────────────────
# FIX: SYSTEMD_SRC_DIR was "$PKG_PATH/systemd/user" (looking for a user/ subdir
#      that does not exist in the current flat tree layout). Unit files are now
#      stored directly in PROJECT_ROOT/systemd/. The script is one level inside
#      that directory, so the source dir is _SCRIPT_DIR itself.
SYSTEMD_SRC_DIR="$_SCRIPT_DIR"

install_unit() {
    local src="$1"
    local dest="$SYSTEMD_USER_DIR/$(basename "$src")"
    sed "s|ExecStart=.*|ExecStart=$PKG_PATH/main.sh --fix --report|g" "$src" > "$dest"
    log_info "Patched and deployed: $dest"
}

# FIX: The companion .service unit was never shipped.  A systemd timer with
#      WantedBy=timers.target cannot be enabled without a matching .service.
#      Generate the .service file inline if it does not already exist in the
#      source directory, then deploy both units.
_SERVICE_SRC="$SYSTEMD_SRC_DIR/env_maintenance.service"
if [[ ! -f "$_SERVICE_SRC" ]]; then
    log_info "Generating missing env_maintenance.service unit..."
    cat > "$_SERVICE_SRC" << SERVICEEOF
[Unit]
Description=4ndr0service Environment Maintenance Run
After=network.target

[Service]
Type=oneshot
ExecStart=$PKG_PATH/main.sh --fix --report
StandardOutput=journal
StandardError=journal
SERVICEEOF
    log_success "Generated: $_SERVICE_SRC"
fi

# Deploy .service first so the timer can reference it
for unit in "$SYSTEMD_SRC_DIR"/*.service; do
    [[ -f "$unit" ]] && install_unit "$unit"
done
for unit in "$SYSTEMD_SRC_DIR"/*.timer; do
    [[ -f "$unit" ]] && install_unit "$unit"
done

# ── ACTIVATION ────────────────────────────────────────────────────────────────
log_info "Reloading systemd user daemon..."
systemctl --user daemon-reload

log_info "Enabling Maintenance Sentinel..."
if systemctl --user list-unit-files env_maintenance.timer &>/dev/null; then
    systemctl --user enable --now env_maintenance.timer
    log_success "4ndr0service Healing Loop ACTIVE."
else
    log_warn "env_maintenance.timer not found after deployment. Check unit files in $SYSTEMD_USER_DIR."
fi
