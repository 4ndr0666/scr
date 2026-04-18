#!/usr/bin/env bash
# File: test/src/install_env_maintenance.sh
# Description: Deployment engine for systemd environment healing.

set -euo pipefail
IFS=$'\n\t'

# ── PATH RESOLUTION ───────────────────────────────────────────────────────────
# FIX: The previous version used `PKG_PATH="${PKG_PATH:-$(dirname...)}"`
# which short-circuits when PKG_PATH is already set in the environment (e.g.
# inherited from a parent 4ndr0service process, a zshrc alias, or a prior
# invocation).  When the script lives at test/src/ inside a source tree rooted
# at a non-standard location (e.g. /home/git/clone/.../4ndr0tools/4ndr0service),
# the stale inherited PKG_PATH pointed one level too high (4ndr0tools/) and
# common.sh was never found.
#
# Rule: standalone scripts that need PKG_PATH MUST always self-resolve it from
# BASH_SOURCE[0] and NEVER trust the inherited environment.  Only export after
# self-computed validation.
# ─────────────────────────────────────────────────────────────────────────────
_SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"

# This script is at test/src/ — two dirnames up is the project root.
_COMPUTED_PKG_PATH="$(dirname "$(dirname "$_SCRIPT_DIR")")"

if [[ ! -f "$_COMPUTED_PKG_PATH/common.sh" ]]; then
    echo "[FATAL] Cannot locate common.sh relative to this script." \
         "Expected: $_COMPUTED_PKG_PATH/common.sh" >&2
    exit 1
fi

# Override any stale inherited PKG_PATH unconditionally.
export PKG_PATH="$_COMPUTED_PKG_PATH"

# shellcheck source=../../common.sh
source "$PKG_PATH/common.sh"

# ── DEPLOYMENT LOGIC ─────────────────────────────────────────────────────────
SYSTEMD_USER_DIR="${XDG_CONFIG_HOME}/systemd/user"
ensure_dir "$SYSTEMD_USER_DIR"

install_unit() {
    local src="$1"
    local dest="$SYSTEMD_USER_DIR/$(basename "$src")"
    sed "s|ExecStart=.*|ExecStart=$PKG_PATH/main.sh --fix --report|g" "$src" > "$dest"
    log_info "Patched and deployed: $dest"
}

SYSTEMD_SRC_DIR="$PKG_PATH/systemd/user"

if [[ ! -d "$SYSTEMD_SRC_DIR" ]]; then
    log_warn "systemd unit source directory not found: $SYSTEMD_SRC_DIR"
    log_warn "Skipping unit deployment. Create $SYSTEMD_SRC_DIR with .service/.timer files."
else
    for unit in "$SYSTEMD_SRC_DIR"/*.service; do
        [[ -f "$unit" ]] && install_unit "$unit"
    done
    for unit in "$SYSTEMD_SRC_DIR"/*.timer; do
        [[ -f "$unit" ]] && install_unit "$unit"
    done
fi

log_info "Reloading systemd user daemon..."
systemctl --user daemon-reload

log_info "Enabling Maintenance Sentinel..."
if systemctl --user list-unit-files env_maintenance.timer &>/dev/null; then
    systemctl --user enable --now env_maintenance.timer
    log_success "4ndr0service Healing Loop ACTIVE."
else
    log_warn "env_maintenance.timer not found after deployment. Verify unit files in $SYSTEMD_SRC_DIR."
fi
