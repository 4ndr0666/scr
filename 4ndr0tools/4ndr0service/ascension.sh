#!/usr/bin/env bash
# File: ascension.sh
# 4ndr0666OS: Arch Universal Ascension Protocol v8.3
# - Host: theworkpc | User: andro (Dynamic Discovery)
# - Logic: Mandatory flag architecture + Tool Injection Vector + Ghost Exorcism
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
PSI_COLOR="\033[38;5;196m"
RESET_ASC="\033[0m"

log_psi() { echo -e "${PSI_COLOR}[Ψ-CORE] $1${RESET_ASC}"; }

# ── DYNAMIC USER DISCOVERY ────────────────────────────────────────────────────
REAL_USER="${SUDO_USER:-$USER}"
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

BIN_TARGET="${USER_HOME}/.local/bin"
path_prepend "$BIN_TARGET"
path_prepend "${PYENV_ROOT}/shims"
path_prepend "${PYENV_ROOT}/bin"

# ── GHOST EXORCISM (Idempotent Pip Cleanup) ──────────────────────────────────
clean_pip_ghosts() {
    log_psi "Initiating Ghost Exorcism Protocol on Python ${1:-3.10.14}"

    local py_version="${1:-3.10.14}"
    local site_pkgs="/home/andro/.local/share/pyenv/versions/${py_version}/lib/python${py_version#*.}/site-packages"

    if [[ ! -d "$site_pkgs" ]]; then
        log_warn "Site-packages not found at $site_pkgs — skipping ghost clean"
        return 0
    fi

    # Kill known ghost patterns (tilde + dash variants)
    sudo rm -rf "${site_pkgs}/~irtual"* 2>/dev/null || true
    sudo rm -rf "${site_pkgs}/-irtual"* 2>/dev/null || true
    sudo rm -rf "${site_pkgs}/*virtualenvondemand"* 2>/dev/null || true
    sudo rm -rf "${site_pkgs}/*virtualenv-tools3"* 2>/dev/null || true

    # Reclaim ownership
    sudo chown -R andro:andro "/home/andro/.local/share/pyenv/versions/${py_version}" 2>/dev/null || true

    # Pip cache + force reinstall
    python -m pip cache purge 2>/dev/null || true
    python -m pip install --upgrade --force-reinstall --no-cache-dir --no-deps pip setuptools wheel 2>/dev/null || true

    log_success "Ghost exorcism complete for Python ${py_version}"
}

# ── USAGE ─────────────────────────────────────────────────────────────────────
show_usage() {
    echo -e "${PSI_COLOR}4ndr0666OS | Ascension Protocol v8.3${RESET_ASC}"
    echo -e "Usage: $(basename "$0") [options]"
    echo -e ""
    echo -e "${C_BLUE}Operational Vectors:${C_RESET}"
    echo -e "  -h, --help          Display this tactical manifest."
    echo -e "  --sync              Execute global synchronization and Ghost Link audit."
    echo -e "  --inject <tool>     Deploy a specific tool into the Hive."
    echo -e "  --clean-ghosts      Run standalone pip ghost exorcism."
    echo -e ""
    echo -e "${C_YELLOW}Note: Passing no arguments will populate this help menu.${C_RESET}"
}

# ── TOOL INJECTION ────────────────────────────────────────────────────────────
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
    "$py_exec" -m venv "$target_venv"

    log_info "Updating sector pip and installing $pkg_name..."
    "$target_venv/bin/pip" install --upgrade pip      >/dev/null 2>&1
    "$target_venv/bin/pip" install "$pkg_name"        >/dev/null 2>&1

    if [[ -f "$target_venv/bin/$pkg_name" ]]; then
        ln -sf "$target_venv/bin/$pkg_name" "$BIN_TARGET/$pkg_name"
        log_success "$pkg_name successfully bridged to $BIN_TARGET"
    else
        log_warn "Binary $pkg_name not found in $target_venv/bin after install."
    fi
}

# ── SYNC ──────────────────────────────────────────────────────────────────────
run_sync() {
    log_psi "INITIALIZING OMNISCIENT SYNCHRONIZATION..."

    # Hive Sanitization
    for garbage in "--site-packages" ".venv"; do
        if [[ -d "${VENV_HOME}/${garbage}" ]]; then
            log_warn "Liquidating anomaly: ${garbage}"
            rm -rf "${VENV_HOME:?}/${garbage}"
        fi
    done

    # Runtime Discovery — Fixed quoting to prevent bad substitution
    local sys_py_ver
    sys_py_ver=$(/usr/bin/python3 -c "
import sys
print(f'{sys.version_info.major}.{sys.version_info.minor}')
" 2>/dev/null || echo "unknown")

    local target_py_ver
    target_py_ver=$(jq -r '.python_version // "3.10.14"' "$CONFIG_FILE" 2>/dev/null || echo "3.10.14")

    log_info "Native OS Python: $sys_py_ver | Suite Target: $target_py_ver"

    # Ghost Link Idempotency
    log_info "Enforcing Ghost Link: pyenv/env -> virtualenv/venv"
    ensure_dir "${VENV_HOME}/venv"
    ensure_dir "$PYENV_ROOT"
    ln -sf "${VENV_HOME}/venv" "${PYENV_ROOT}/env"

    # Integrated Ghost Exorcism
    clean_pip_ghosts "$target_py_ver"

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
        --clean-ghosts)
            clean_pip_ghosts
            shift
            ;;
        *)
            log_warn "Unknown vector: $1"
            show_usage
            exit 1
            ;;
    esac
done
