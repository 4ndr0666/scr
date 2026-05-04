#!/usr/bin/env bash
# File: install.sh
# Description: Enterprise-grade installer for 4ndr0service Suite.
#
# Capabilities:
#   - Idempotent: safe to run multiple times; detects and migrates prior layouts.
#   - Atomic:     all filesystem mutations occur inside a POSIX trap so partial
#                 installs are detected and rolled back on abort or error.
#   - Dry-run:    full simulation with no writes.
#   - Uninstall:  complete teardown with lock/symlink cleanup.
#   - Migration:  detects the old test/src/ layout and moves files to test/.
#   - Systemd:    deploys and activates the env_maintenance timer automatically.
#   - Backwards compatible: gracefully handles installations from prior versions.

set -euo pipefail
IFS=$'\n\t'

# ── CONFIGURATION ─────────────────────────────────────────────────────────────
SOURCE_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]:-$0}")")" && pwd -P)"
DEFAULT_INSTALL_LOCATION="/opt/4ndr0service"
BIN_DIR="/usr/local/bin"
SYMLINK_PATH="${BIN_DIR}/4ndr0service"
DRY_RUN=false
UNINSTALL=false
SKIP_SYSTEMD=false
_ROLLBACK_NEEDED=false
_INSTALL_LOCATION=""   # set after prompt; used by rollback trap

# ── LOGGING (standalone; common.sh not yet sourced) ───────────────────────────
log_info()   { printf "\033[1;32m[INFO]\033[0m    %s\n" "$*"; }
log_warn()   { printf "\033[1;33m[WARN]\033[0m    %s\n" "$*" >&2; }
log_error()  { printf "\033[1;31m[ERROR]\033[0m   %s\n" "$*" >&2; }
log_step()   { printf "\033[1;36m[STEP]\033[0m    %s\n" "$*"; }
log_ok()     { printf "\033[1;32m[OK]\033[0m      %s\n" "$*"; }
log_dry()    { printf "\033[1;34m[DRY-RUN]\033[0m %s\n" "$*"; }

# ── DRY-RUN WRAPPER ───────────────────────────────────────────────────────────
# Every filesystem-mutating call goes through run() so dry-run is guaranteed.
run() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_dry "Would run: $*"
        return 0
    fi
    "$@"
}

# ── ROLLBACK TRAP ─────────────────────────────────────────────────────────────
# Akasha Directive 3: The Iron FINALLY block.
# If the installer exits non-zero after filesystem mutations have begun,
# remove the partially-installed tree and symlink to leave the host pristine.
_rollback() {
    local exit_code=$?
    [[ "$DRY_RUN" == "true" ]] && return 0
    if [[ "$_ROLLBACK_NEEDED" == "true" && $exit_code -ne 0 ]]; then
        log_error "Install aborted (exit $exit_code). Rolling back..."
        [[ -L "$SYMLINK_PATH" || -e "$SYMLINK_PATH" ]] && sudo rm -f "$SYMLINK_PATH" 2>/dev/null || true
        if [[ -n "$_INSTALL_LOCATION" && -d "$_INSTALL_LOCATION" ]]; then
            sudo rm -rf "$_INSTALL_LOCATION" 2>/dev/null || true
            log_warn "Removed partial installation at $_INSTALL_LOCATION"
        fi
    fi
}
trap '_rollback' EXIT

# ── PATH NORMALISATION ────────────────────────────────────────────────────────
normalize_path() {
    local p="$1"
    [[ "$p" == "~"* ]] && p="${HOME}${p#~}"
    [[ "$p" != /* ]]   && p="$(pwd -P)/$p"
    p="$(readlink -f "$p" 2>/dev/null || printf '%s' "$p")"
    printf '%s' "${p%/}"
}

# ── USAGE ─────────────────────────────────────────────────────────────────────
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  -n, --dry-run       Simulate all actions; no filesystem changes made.
  -u, --uninstall     Full teardown: remove install dir, symlink, and lock files.
  --skip-systemd      Skip systemd unit deployment and activation.
  -h, --help          Show this help.

Examples:
  sudo $(basename "$0")               # Standard install to /opt/4ndr0service
  sudo $(basename "$0") -n            # Dry-run simulation
  sudo $(basename "$0") -u            # Uninstall
EOF
}

# ── ARGUMENT PARSING ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--dry-run)      DRY_RUN=true;      shift ;;
        -u|--uninstall)    UNINSTALL=true;     shift ;;
        --skip-systemd)    SKIP_SYSTEMD=true;  shift ;;
        -h|--help)         usage; exit 0 ;;
        *)                 log_error "Unknown option: $1"; usage; exit 1 ;;
    esac
done

# ── UNINSTALL ─────────────────────────────────────────────────────────────────
if [[ "$UNINSTALL" == "true" ]]; then
    log_step "Initiating Scorch Protocol..."
    [[ -L "$SYMLINK_PATH" || -e "$SYMLINK_PATH" ]] && run sudo rm -f "$SYMLINK_PATH"
    [[ -d "$DEFAULT_INSTALL_LOCATION" ]]            && run sudo rm -rf "$DEFAULT_INSTALL_LOCATION"
    run sudo rm -f /tmp/4ndr0service_*.lock
    # Disable and remove deployed systemd units if present
    local_systemd="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
    for unit in env_maintenance.service env_maintenance.timer; do
        if [[ -f "$local_systemd/$unit" ]]; then
            run systemctl --user disable --now "${unit%.service}" 2>/dev/null || true
            run rm -f "$local_systemd/$unit"
        fi
    done
    run systemctl --user daemon-reload 2>/dev/null || true
    log_ok "Teardown complete. Zero traces remain."
    exit 0
fi

# ── INSTALL LOCATION PROMPT ───────────────────────────────────────────────────
if [[ "$DRY_RUN" == "false" ]]; then
    printf "\033[1;36m[PROMPT]\033[0m Install location [default: %s]: " "$DEFAULT_INSTALL_LOCATION"
    read -r _USER_INPUT
else
    _USER_INPUT=""
fi
INSTALL_LOCATION="$(normalize_path "${_USER_INPUT:-$DEFAULT_INSTALL_LOCATION}")"
_INSTALL_LOCATION="$INSTALL_LOCATION"   # captured for rollback trap

log_step "Source:  $SOURCE_DIR"
log_step "Target:  $INSTALL_LOCATION"
[[ "$DRY_RUN" == "true" ]] && log_info "DRY-RUN mode active — no changes will be made."

# ── TREE MIGRATION (BACKWARDS COMPATIBILITY) ─────────────────────────────────
# If an older installation exists with the test/src/ layout, migrate it before
# rsync overwrites with the new canonical layout. This prevents stale files
# under test/src/ from persisting alongside the new test/ flat layout.
_migrate_old_tree() {
    local dest="$1"
    local old_src_dir="$dest/test/src"
    local old_verify="$old_src_dir/verify_environment.sh"
    local old_install="$old_src_dir/install_env_maintenance.sh"
    local new_test_dir="$dest/test"

    if [[ -d "$old_src_dir" ]]; then
        log_step "Detected legacy test/src/ layout — migrating to flat test/ layout..."

        if [[ -f "$old_verify" && ! -f "$new_test_dir/verify_environment.sh" ]]; then
            run sudo mv "$old_verify" "$new_test_dir/verify_environment.sh"
            log_info "Migrated: test/src/verify_environment.sh → test/verify_environment.sh"
        fi

        if [[ -f "$old_install" ]]; then
            # install_env_maintenance.sh moved to systemd/ — remove the old copy
            run sudo rm -f "$old_install"
            log_info "Removed stale: test/src/install_env_maintenance.sh (now at systemd/)"
        fi

        # Remove src/ dir if now empty
        if run sudo find "$old_src_dir" -mindepth 1 -maxdepth 1 2>/dev/null | grep -q .; then
            log_warn "test/src/ still contains files after migration; leaving in place."
        else
            run sudo rmdir "$old_src_dir" 2>/dev/null || true
            log_info "Removed empty directory: test/src/"
        fi
    fi

    # Remove test/bats/ if empty (it was never populated)
    local bats_dir="$dest/test/bats"
    if [[ -d "$bats_dir" ]]; then
        if ! find "$bats_dir" -mindepth 1 -maxdepth 1 2>/dev/null | grep -q .; then
            run sudo rmdir "$bats_dir" 2>/dev/null || true
            log_info "Removed empty directory: test/bats/"
        fi
    fi
}

# ── FILE SYNCHRONISATION ──────────────────────────────────────────────────────
if [[ "$SOURCE_DIR" != "$INSTALL_LOCATION" ]]; then
    log_step "Synchronising source tree to $INSTALL_LOCATION..."

    # Ensure parent and target directories exist
    PARENT_DIR="$(dirname "$INSTALL_LOCATION")"
    [[ -d "$PARENT_DIR" ]] || run sudo mkdir -p "$PARENT_DIR"
    [[ -d "$INSTALL_LOCATION" ]] || run sudo mkdir -p "$INSTALL_LOCATION"

    # Migrate any legacy layout BEFORE rsync so --delete doesn't remove
    # files that are still in the process of being moved.
    if [[ -d "$INSTALL_LOCATION" && "$DRY_RUN" == "false" ]]; then
        _migrate_old_tree "$INSTALL_LOCATION"
    fi

    _ROLLBACK_NEEDED=true   # filesystem mutations begin here

    if command -v rsync &>/dev/null; then
        run sudo rsync -av --delete --progress \
            --exclude '.git/' \
            --exclude '__pycache__/' \
            --exclude '*.bak' \
            --exclude '.gemini/' \
            --exclude '.github/' \
            "${SOURCE_DIR}/" "${INSTALL_LOCATION}/"
    else
        log_warn "rsync not found — falling back to cp (mirror via wipe-then-copy)."
        if [[ "$DRY_RUN" == "false" ]]; then
            sudo find "$INSTALL_LOCATION" -mindepth 1 -delete
        fi
        run sudo cp -r "${SOURCE_DIR}/"* "${INSTALL_LOCATION}/"
    fi
else
    log_info "Source and target are the same directory. Skipping file sync."
    # Still run migration if target already exists with old layout
    [[ "$DRY_RUN" == "false" ]] && _migrate_old_tree "$INSTALL_LOCATION"
    _ROLLBACK_NEEDED=true
fi

# ── PERMISSIONS ───────────────────────────────────────────────────────────────
log_step "Setting execute permissions on all .sh payloads..."
run sudo find "$INSTALL_LOCATION" -type f -name "*.sh" -exec chmod +x {} +

# ── INVOCATION SYMLINK ────────────────────────────────────────────────────────
log_step "Establishing invocation symlink: $SYMLINK_PATH → $INSTALL_LOCATION/main.sh"
[[ -d "$BIN_DIR" ]] || run sudo mkdir -p "$BIN_DIR"
[[ -L "$SYMLINK_PATH" || -e "$SYMLINK_PATH" ]] && run sudo rm -f "$SYMLINK_PATH"
run sudo ln -s "$INSTALL_LOCATION/main.sh" "$SYMLINK_PATH"

# ── DEPENDENCY GATE ───────────────────────────────────────────────────────────
log_step "Verifying runtime dependencies..."
if ! command -v jq &>/dev/null; then
    log_warn "jq not found — required for JSON config parsing."
    if command -v pacman &>/dev/null; then
        run sudo pacman -S --noconfirm --needed jq
    else
        log_error "Install jq manually before using the suite."
    fi
else
    log_ok "jq: $(jq --version)"
fi

# ── SYSTEMD DEPLOYMENT ────────────────────────────────────────────────────────
# Deploy and activate the environment maintenance timer for the CURRENT user.
# Skipped if --skip-systemd is passed or if systemd user session is unavailable.
if [[ "$SKIP_SYSTEMD" == "false" ]]; then
    log_step "Deploying systemd maintenance units..."
    _systemd_installer="$INSTALL_LOCATION/systemd/install_env_maintenance.sh"

    if [[ -x "$_systemd_installer" ]]; then
        if systemctl --user status &>/dev/null 2>&1 || systemctl --user list-units &>/dev/null 2>&1; then
            if [[ "$DRY_RUN" == "false" ]]; then
                # Run as the current (non-root) user; install.sh may be run with sudo
                # but systemd --user must run as the actual user.
                if [[ "${SUDO_USER:-}" != "" ]]; then
                    sudo -u "$SUDO_USER" bash "$_systemd_installer"
                else
                    bash "$_systemd_installer"
                fi
            else
                log_dry "Would run: bash $_systemd_installer"
            fi
        else
            log_warn "Systemd user session not available. Run '$_systemd_installer' manually after login."
        fi
    else
        log_warn "systemd/install_env_maintenance.sh not found or not executable at $_systemd_installer"
        log_warn "Run it manually to activate the maintenance timer."
    fi
else
    log_info "Skipping systemd deployment (--skip-systemd)."
fi

# ── INITIAL VERIFICATION ─────────────────────────────────────────────────────
log_step "Running post-install verification (--report)..."
if [[ "$DRY_RUN" == "false" ]]; then
    "$INSTALL_LOCATION/main.sh" --report || log_warn "--report returned non-zero; review output above."
else
    log_dry "Would run: $INSTALL_LOCATION/main.sh --report"
fi

# ── DONE ──────────────────────────────────────────────────────────────────────
_ROLLBACK_NEEDED=false   # disarm the rollback trap — install succeeded
log_ok "Deployment complete. 4ndr0service is installed at $INSTALL_LOCATION"
[[ "$DRY_RUN" == "false" ]] && log_info "Invoke with: 4ndr0service  (ensure $BIN_DIR is in PATH)"
