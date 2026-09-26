#!/usr/bin/env bash
# 4ndr0666OS: Null-Sector Purge Protocol (v1.6 — Suite-Integrated, suite v1.5.1)
# - Logic: Mandatory --force gate for kinetic liquidation.
# - Integration: Aligned to 4ndr0service common.sh (XDG paths, logging).
# - v1.5: source-safe bootstrap guard; hard timeouts on the AUR orphan
#   rebuild and the orphan harvest; sys_py_ver fallback when /usr/bin/python3
#   is unavailable so the purge sequence can never abort without diagnostics.
# - v1.6: canonical suite-root resolver — cwd-independent, sentinel-checked
#   (v1.5.1 remediation of the PKG_PATH cwd-fallback conflict class)

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

log_purge() { echo -e "\033[38;5;196m[Ψ-PURGE]\033[0m $*"; }

show_usage() {
    log_purge "Purge Protocol v1.6 (suite v${SUITE_VERSION:-1.5.1})"
    echo -e "Usage: $(basename "$0") [options]"
    echo -e ""
    echo -e "${C_BLUE}Operational Vectors:${C_RESET}"
    echo -e "  -h, --help    Display this purge manifest."
    echo -e "  --force       Execute kinetic liquidation."
    echo -e ""
    echo -e "${C_GREEN}Required: Use --force to initiate system-wide rebuild.${C_RESET}"
}

run_purge() {
    log_purge "INITIATING RECURSIVE SYSTEM AUTOCLEAN..."

    log_info "Sterilizing virtualenv hive..."
    for garbage in "--site-packages" ".venv"; do
        local target
        target="${VENV_HOME:?VENV_HOME is unset — cannot safely remove hive artifacts}/${garbage}"
        if [[ -d "$target" ]]; then
            rm -rf -- "$target"
            log_success "Liquidated: $target"
        fi
    done

    log_info "Pruning ${BIN_DIR} for dead ghost links..."
    local purge_rc=0
    if find -L "$BIN_DIR" -maxdepth 1 -type l -delete 2>/dev/null; then
        :
    else
        purge_rc=$?
        log_error "Failed to purge broken symlinks from $BIN_DIR."
        return "$purge_rc"
    fi
    log_success "Broken symlinks purged from $BIN_DIR."

    local sys_py_ver
    # GAP-H FIX: bare failure here (no /usr/bin/python3, e.g. a broken base
    # install) aborted the whole purge mid-sequence with zero diagnostics
    # under set -e. Degrade to "unknown" and keep liquidating — the dead-
    # runtime scan simply widens its exclusion net on such hosts.
    sys_py_ver=$(/usr/bin/python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo "unknown")
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
                # GUP 4.2: the harvest walks a full runtime tree and shells out
                # to pacman for every file — bounded so a pathological tree can
                # never wedge the purge.
                run_bounded 600 "orphan harvest ($(basename "$dead_dir"))" \
                    bash -c 'find "$1" -type f 2>/dev/null | xargs -r pacman -Qo 2>/dev/null | awk "/is owned by/ {print \$5}" | sort -u' _ "$dead_dir"
            )
        done

        if [[ ${#orphan_pkgs[@]} -gt 0 ]]; then
            local -a unique_orphans=()
            mapfile -t unique_orphans < <(printf "%s\n" "${orphan_pkgs[@]}" | sort -u)

            log_purge "Re-compiling offensive tools into native stack..."
            # GUP 4.2: AUR rebuilds legitimately take tens of minutes (they
            # compile against the native stack). A one-hour hard ceiling still
            # guarantees the oneshot timer can never hang forever while leaving
            # realistic build headroom. Failure semantics preserved: baseline
            # aborted the purge on rebuild failure; this does the same, loudly.
            if ! run_bounded 3600 "AUR orphan rebuild" \
                "$aur_helper" -S --rebuild --noconfirm --needed "${unique_orphans[@]}"; then
                log_error "AUR orphan rebuild failed (build error or 3600s ceiling exceeded)."
                return 1
            fi
            log_success "Orphan migration complete."
        else
            log_info "No orphan packages detected."
        fi
    fi

    log_info "Liquidating __pycache__ artifacts..."
    if find "${XDG_CONFIG_HOME}" "${XDG_DATA_HOME}" \
        -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null; then
        :
    else
        purge_rc=$?
        log_error "Failed to liquidate __pycache__ artifacts."
        return "$purge_rc"
    fi

    log_success "System is zeroed. SUPREMACY ACHIEVED."
    log_purge "EXECUTION COMPLETE."
}

# ──────────────────────────────────────────────────────────────────────────────
# STANDALONE BOOTSTRAP GUARD (GAP-B FIX)
# view/cli.sh and view/dialog.sh source this file inline (see their ISSUE-06
# comments) to call run_purge() without re-acquiring the common.sh flock mutex
# in a subprocess. The --force gate below MUST only run when this file is
# executed directly — without this guard, sourcing the file from a menu
# session with no positional parameters executed `show_usage; exit 0`,
# terminating the whole CLI/dialog process instead of returning to the menu.
# ──────────────────────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
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
fi
