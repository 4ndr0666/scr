#!/usr/bin/env bash
# File: ascension.sh
# 4ndr0666OS: Arch Universal Ascension Protocol v8.2
# - Host: theworkpc | User: andro (Dynamic Discovery)
# - Logic: Mandatory flag architecture + Tool Injection Vector
# - Integration: Aligned to 4ndr0service common.sh (XDG paths, logging, ensure_dir)

set -euo pipefail
IFS=$'\n\t'

# ── SELF-LOCATE & SOURCE SUITE CORE ──────────────────────────────────────────
# Ascension lives alongside the suite (same repo root or sibling).
# Resolve PKG_PATH from BASH_SOURCE[0] — never trust the environment value
# because this script may be invoked from any working directory.
_ASC_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"

# Search for common.sh: first sibling, then parent, then grandparent (covers
# both installed layout /opt/4ndr0service/ and source-tree layouts).
_found_pkg=""
for _candidate in "$_ASC_DIR" "$(dirname "$_ASC_DIR")" "$(dirname "$(dirname "$_ASC_DIR")")"; do
    if [[ -f "$_candidate/common.sh" ]]; then
        _found_pkg="$_candidate"
        break
    fi
done

if [[ -z "$_found_pkg" ]]; then
    echo -e "\033[38;5;196m[FATAL] Cannot locate common.sh from $_ASC_DIR\033[0m" >&2
    exit 1
fi

export PKG_PATH="$_found_pkg"
# shellcheck source=./common.sh
source "$PKG_PATH/common.sh"

# ── VISUALS ───────────────────────────────────────────────────────────────────
# INTEGRATION NOTE: common.sh owns log_info, log_warn, log_success, ensure_dir.
# Ascension-specific log levels that do not conflict are added here.
# The original local redefinitions of log_info/log_warn/log_success/ensure_dir
# are REMOVED — they shadowed common.sh's implementations with incompatible
# prefixes ([RECON] vs [INFO]), causing split log formatting when sourced
# alongside the suite.
PSI_COLOR="\033[38;5;196m"
RESET_ASC="\033[0m"

log_psi() { echo -e "${PSI_COLOR}[Ψ-CORE] $1${RESET_ASC}"; }

# ── DYNAMIC USER DISCOVERY ────────────────────────────────────────────────────
# INTEGRATION: XDG_DATA_HOME, PYENV_ROOT, VENV_HOME, BIN_DIR are all already
# exported by common.sh.  Derive REAL_USER for sudo-context awareness only;
# do not re-export XDG vars (they would overwrite common.sh's values).
REAL_USER="${SUDO_USER:-$USER}"
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

# ALIGNMENT: common.sh exports VENV_HOME="${XDG_DATA_HOME}/virtualenv"
# Ascension originally used VENV_BASE for the same path.  Unified to VENV_HOME.
# BIN_TARGET aligned to common.sh's BIN_DIR.
BIN_TARGET="${USER_HOME}/.local/bin"
path_prepend "$BIN_TARGET"
path_prepend "${PYENV_ROOT}/shims"
path_prepend "${PYENV_ROOT}/bin"

# ── USAGE ─────────────────────────────────────────────────────────────────────
show_usage() {
    echo -e "${PSI_COLOR}4ndr0666OS | Ascension Protocol v8.2${RESET_ASC}"
    echo -e "Usage: $(basename "$0") [options]"
    echo -e ""
    echo -e "${C_BLUE}Operational Vectors:${C_RESET}"
    echo -e "  -h, --help       Display this tactical manifest."
    echo -e "  --sync           Execute global synchronization and Ghost Link audit."
    echo -e "  --inject <tool>  Deploy a specific tool into the Hive (e.g., stig, ImgCodeCheck)."
    echo -e ""
    echo -e "${C_YELLOW}Note: Passing no arguments will populate this help menu.${C_RESET}"
}

# ── TOOL INJECTION ────────────────────────────────────────────────────────────
# UNIQUE CAPABILITY: per-tool isolated venv injection with Ghost Link.
# Not duplicated elsewhere in the suite — preserved as-is, path-aligned.
install_resilient_tool() {
    local pkg_name="$1"
    local target_venv="${VENV_HOME}/${pkg_name}"

    log_info "Injecting $pkg_name into the Hive..."

    local py_exec="${PYENV_ROOT}/versions/$(jq -r '.python_version // "3.10.14"' "$CONFIG_FILE")/bin/python"
    if [[ ! -f "$py_exec" ]]; then
        log_warn "Pyenv baseline not found at $py_exec. Falling back to native python3."
        py_exec="/usr/bin/python3"
    fi

    ensure_dir "$VENV_HOME"
    # Use python -m venv directly — do not pre-create the dir, venv does it.
    "$py_exec" -m venv "$target_venv"

    log_info "Updating sector pip and installing $pkg_name..."
    "$target_venv/bin/pip" install --upgrade pip      >/dev/null 2>&1
    "$target_venv/bin/pip" install "$pkg_name"        >/dev/null 2>&1

    # Ghost Link: expose binary at BIN_TARGET for PATH resolution
    if [[ -f "$target_venv/bin/$pkg_name" ]]; then
        ln -sf "$target_venv/bin/$pkg_name" "$BIN_TARGET/$pkg_name"
        log_success "$pkg_name successfully bridged to $BIN_TARGET"
    else
        log_warn "Binary $pkg_name not found in $target_venv/bin after install."
        log_warn "The package may install under a different binary name."
    fi
}

# ── SYNC ──────────────────────────────────────────────────────────────────────
# INTEGRATION: run_sync() previously duplicated Ghost Link logic that also
# exists in optimize_python.sh and main.sh run_core_checks().  The Ghost Link
# enforcement is preserved here for standalone use.  When run via the suite's
# optimize_python_service(), this is already handled — running both is safe
# because ln -sf is idempotent.
#
# Hive artifact sanitization (--site-packages, .venv garbage dirs) was also
# in optimize_venv.sh.  Kept here for standalone --sync invocations.
run_sync() {
    log_psi "INITIALIZING OMNISCIENT SYNCHRONIZATION..."

    # Hive Sanitization (garbage dir liquidation)
    for garbage in "--site-packages" ".venv"; do
        if [[ -d "${VENV_HOME}/${garbage}" ]]; then
            log_warn "Liquidating anomaly: ${garbage}"
            rm -rf "${VENV_HOME:?}/${garbage}"
        fi
    done

    # Runtime Discovery
    local sys_py_ver
    sys_py_ver=$(/usr/bin/python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    local target_py_ver
    target_py_ver=$(jq -r '.python_version // "3.10.14"' "$CONFIG_FILE")
    log_info "Native OS Python: $sys_py_ver | Suite Target: $target_py_ver"

    # Ghost Link Idempotency (Global Hive)
    log_info "Enforcing Ghost Link: pyenv/env -> virtualenv/venv"
    ensure_dir "${VENV_HOME}/venv"
    ensure_dir "$PYENV_ROOT"
    ln -sf "${VENV_HOME}/venv" "${PYENV_ROOT}/env"

    # Integrity Audit
    log_info "Architecture Audit:"
    if command -v eza >/dev/null 2>&1; then
        eza -al --icons "$VENV_HOME"
    else
        ls -alh "$VENV_HOME"
    fi

    log_psi "ASCENSION COMPLETE. SYSTEM ZEROED."
}

# ── ARGUMENT GATING ───────────────────────────────────────────────────────────
if [[ $# -eq 0 ]]; then
    show_usage
    exit 0
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_usage
            exit 0
            ;;
        --sync)
            run_sync
            shift
            ;;
        --inject)
            if [[ -n "${2:-}" ]]; then
                install_resilient_tool "$2"
                shift 2
            else
                log_warn "Error: Tool name missing for --inject"
                exit 1
            fi
            ;;
        *)
            log_warn "Unknown vector: $1"
            show_usage
            exit 1
            ;;
    esac
done
