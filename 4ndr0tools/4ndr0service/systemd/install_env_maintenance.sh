#!/usr/bin/env bash
# File: systemd/install_env_maintenance.sh
# Description: Deployment engine for systemd environment healing.
#
# Tree location: PROJECT_ROOT/systemd/install_env_maintenance.sh
# dirname x1 of this script's physical path = PROJECT_ROOT/systemd/
# dirname x2 = PROJECT_ROOT  (where common.sh lives)

set -euo pipefail
IFS=$'\n\t'

# ── SUITE ROOT RESOLUTION (canonical, v1.5.1) ─────────────────────────────────
# The suite root is the directory containing common.sh, resolved from THIS
# file's own physical location — never from the caller's current working
# directory. An inherited PKG_PATH is honored only when this file is being
# SOURCED and that path is valid (the sandbox/test contract); executed entry
# points always self-resolve, so a stale exported PKG_PATH can never silently
# redirect the suite to a foreign copy. Every self-resolved candidate must
# carry the 4ndr0service sentinel — an unrelated common.sh in a parent
# directory can never be adopted.
if [[ "${BASH_SOURCE[0]}" != "$0" && -n "${PKG_PATH:-}" && -f "${PKG_PATH}/common.sh" ]]; then
    :   # sourced with a valid suite context — honor it
else
    _4NDR0_SELF_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]:-$0}")")" && pwd -P)"
    _4NDR0_FOUND=""
    for _4NDR0_CAND in "$_4NDR0_SELF_DIR" "$(dirname "$_4NDR0_SELF_DIR")" "$(dirname "$(dirname "$_4NDR0_SELF_DIR")")"; do
        [[ -f "${_4NDR0_CAND}/common.sh" ]] || continue
        _4NDR0_MARKED=0
        while IFS= read -r _4NDR0_LINE; do
            if [[ "${_4NDR0_LINE}" == *4ndr0service* ]]; then
                _4NDR0_MARKED=1
                break
            fi
        done 2>/dev/null < "${_4NDR0_CAND}/common.sh" || true
        [[ "${_4NDR0_MARKED}" == 1 ]] || continue
        _4NDR0_FOUND="${_4NDR0_CAND}"
        break
    done
    if [[ -z "${_4NDR0_FOUND}" ]]; then
        printf '[FATAL] %s: cannot locate the 4ndr0service suite root (common.sh) near %s\n' \
            "${BASH_SOURCE[0]:-$0}" "${_4NDR0_SELF_DIR}" >&2
        exit 1
    fi
    export PKG_PATH="${_4NDR0_FOUND}"
fi
# shellcheck source=/dev/null
source "${PKG_PATH}/common.sh"
unset _4NDR0_SELF_DIR _4NDR0_FOUND _4NDR0_CAND _4NDR0_MARKED _4NDR0_LINE

# The unit template source directory is this script's own directory (systemd/).
_SCRIPT_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"

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
    # v1.5.1 (P-5): patch BOTH the executable path and the suite-root
    # environment hint — a custom install location previously left the stale
    # template default Environment=PKG_PATH=/opt/4ndr0service behind in
    # deployed units (ExecStart was rewritten, Environment was not).
    sed -e "s|^Environment=PKG_PATH=.*|Environment=PKG_PATH=${PKG_PATH}|g" \
        -e "s|^ExecStart=.*|ExecStart=${PKG_PATH}/main.sh --fix --report|g" \
        "$src" > "$dest"
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
Environment=PKG_PATH=$PKG_PATH
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

# ── AUDITD RULE PROVISIONING ──────────────────────────────────────────────────
# GAP-04 FIX: Provision auditd rules on every deploy so fresh installs never
# produce audit warnings on first run. Delegates to provision_auditd_rules()
# defined in test/final_audit.sh to keep a single authoritative implementation.
if command -v auditctl &>/dev/null; then
    log_info "Provisioning auditd rules..."
    _FINAL_AUDIT="$PKG_PATH/test/final_audit.sh"
    if [[ -f "$_FINAL_AUDIT" ]]; then
        # Source with PKG_PATH already set; the standalone guard in final_audit.sh
        # ([[ "${BASH_SOURCE[0]}" == "$0" ]]) prevents run_audit from executing.
        # shellcheck source=../test/final_audit.sh
        source "$_FINAL_AUDIT"
        provision_auditd_rules
    else
        log_warn "final_audit.sh not found at $_FINAL_AUDIT — auditd rules not provisioned"
    fi
fi
