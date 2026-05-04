#!/usr/bin/env bash
# File: purge_matrix.sh
# 4ndr0666OS: Null-Sector Purge Protocol (v1.4 — Suite-Integrated)
# - Logic: Mandatory --force gate for kinetic liquidation.
# - Integration: Aligned to 4ndr0service common.sh (XDG paths, logging).

set -euo pipefail
IFS=$'\n\t'

# ── SELF-LOCATE & SOURCE SUITE CORE ──────────────────────────────────────────
# Resolve PKG_PATH from BASH_SOURCE[0] unconditionally — never inherit a stale
# environment value (same pattern as install_env_maintenance.sh fix).
_PURGE_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"

_found_pkg=""
for _candidate in "$_PURGE_DIR" "$(dirname "$_PURGE_DIR")" "$(dirname "$(dirname "$_PURGE_DIR")")"; do
    if [[ -f "$_candidate/common.sh" ]]; then
        _found_pkg="$_candidate"
        break
    fi
done

if [[ -z "$_found_pkg" ]]; then
    echo -e "\033[38;5;196m[FATAL] Cannot locate common.sh from $_PURGE_DIR\033[0m" >&2
    exit 1
fi

export PKG_PATH="$_found_pkg"
# shellcheck source=./common.sh
source "$PKG_PATH/common.sh"

# ── VISUALS ───────────────────────────────────────────────────────────────────
# INTEGRATION NOTE: common.sh owns log_info, log_warn, log_success, log_error.
# Purge-specific prefix added without conflicting with suite logging.
log_purge() { echo -e "\033[38;5;196m[Ψ-PURGE]\033[0m $*"; }

# ── USAGE ─────────────────────────────────────────────────────────────────────
show_usage() {
    log_purge "Purge Protocol v1.4"
    echo -e "Usage: $(basename "$0") [options]"
    echo -e ""
    echo -e "${C_BLUE}Operational Vectors:${C_RESET}"
    echo -e "  -h, --help    Display this purge manifest."
    echo -e "  --force       Execute kinetic liquidation."
    echo -e ""
    echo -e "${C_GREEN}Required: Use --force to initiate system-wide rebuild.${C_RESET}"
}

# ── PURGE ─────────────────────────────────────────────────────────────────────
run_purge() {
    log_purge "INITIATING RECURSIVE SYSTEM AUTOCLEAN..."

    # 1. Hive Artifact Liquidation
    # INTEGRATION: The --site-packages and .venv garbage-dir removal was also
    # in optimize_venv.sh (section 5 scrub) and ascension.sh run_sync().
    # Kept here for standalone --force invocations; idempotent with the suite.
    log_info "Sterilizing virtualenv hive..."
    for garbage in "--site-packages" ".venv"; do
        local target="${VENV_HOME}/${garbage}"
        if [[ -d "$target" ]]; then
            rm -rf "$target"
            log_success "Liquidated: $target"
        fi
    done

    # 2. Ghost Link Audit — Broken Symlink Pruning in ~/.local/bin
    # UNIQUE: This logic exists nowhere else in the suite.
    log_info "Pruning ${BIN_DIR} for dead ghost links..."
    find -L "$BIN_DIR" -maxdepth 1 -type l -delete 2>/dev/null || true
    log_success "Broken symlinks purged from $BIN_DIR."

    # 3. Kinetic System Rebuild (AUR Orphan Recompile)
    # UNIQUE: AUR orphan detection and --rebuild invocation.  Not in the suite.
    local sys_py_ver
    sys_py_ver=$(/usr/bin/python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    log_info "Target Runtime: $sys_py_ver"

    local aur_helper=""
    aur_helper=$(command -v paru 2>/dev/null || command -v yay 2>/dev/null || true)

    if [[ -z "$aur_helper" ]]; then
        log_warn "AUR Helper (paru/yay) missing. Orphan rebuild vector disabled."
    else
        local -a dead_runtimes=()
        mapfile -t dead_runtimes < <(
            find /usr/lib -maxdepth 1 -type d -name "python3.*" \
                ! -name "python${sys_py_ver}" 2>/dev/null || true
        )

        local -a orphan_pkgs=()
        for dead_dir in "${dead_runtimes[@]}"; do
            [[ -z "$dead_dir" ]] && continue
            log_info "Harvesting orphans from: $dead_dir"
            mapfile -t -O "${#orphan_pkgs[@]}" orphan_pkgs < <(
                find "$dead_dir" -type f 2>/dev/null \
                | xargs -r pacman -Qo 2>/dev/null \
                | awk '/is owned by/ {print $5}' \
                | sort -u \
                || true
            )
        done

        if [[ ${#orphan_pkgs[@]} -gt 0 ]]; then
            # Deduplicate
            local -a unique_orphans=()
            mapfile -t unique_orphans < <(printf "%s\n" "${orphan_pkgs[@]}" | sort -u)

            log_purge "Re-compiling offensive tools into native stack..."
            "$aur_helper" -S --rebuild --noconfirm --needed "${unique_orphans[@]}"
            log_success "Orphan migration complete."
        else
            log_info "No orphan packages detected."
        fi
    fi

    # 4. Deep Cache Liquidation
    # INTEGRATION: __pycache__ removal also runs in optimize_venv.sh scrub.
    # Kept here for completeness on standalone --force invocations.
    log_info "Liquidating __pycache__ artifacts..."
    find "${XDG_CONFIG_HOME}" "${XDG_DATA_HOME}" \
        -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true

    log_success "System is zeroed. SUPREMACY ACHIEVED."
    log_purge "EXECUTION COMPLETE."
}

# ── ARGUMENT GATING ───────────────────────────────────────────────────────────
if [[ $# -eq 0 ]]; then
    show_usage
    exit 0
fi

case "$1" in
    -h|--help)
        show_usage
        exit 0
        ;;
    --force)
        run_purge
        ;;
    *)
        log_warn "Unknown option: $1"
        show_usage
        exit 1
        ;;
esac
