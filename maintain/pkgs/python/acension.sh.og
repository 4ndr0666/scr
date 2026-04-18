#!/usr/bin/env bash
# 4ndr0666OS: Arch Universal Ascension Protocol v8.2 (Standalone/Hardened)
# - Host: theworkpc | User: andro (Dynamic Discovery)
# - Logic: Mandatory flag architecture + Tool Injection Vector
# - Fix: Localized ensure_dir and enforced echo -e for ANSI Hud.

set -euo pipefail
trap 'echo -e "\033[38;5;196m[CRITICAL FAILURE] Protocol Severed at line $LINENO\033[0m" >&2' ERR

# ---[ NEURAL CONFIG & VISUALS ]---
PSI_COLOR="\033[38;5;196m"; WARN_COLOR="\033[38;5;208m"
SUCCESS_COLOR="\033[38;5;46m"; INFO_COLOR="\033[38;5;45m"
RESET="\033[0m"

log_psi() { echo -e "${PSI_COLOR}[Ψ-CORE] $1${RESET}"; }
log_info() { echo -e "${INFO_COLOR}[RECON] $1${RESET}"; }
log_warn() { echo -e "${WARN_COLOR}[THREAT] $1${RESET}"; }
log_success() { echo -e "${SUCCESS_COLOR}[VEC_COMPLETE] $1${RESET}"; }

# ---[ INTERNAL UTILITIES ]---
ensure_dir() {
    if [[ ! -d "$1" ]]; then
        mkdir -p "$1" || { log_warn "Failed to create directory: $1"; return 1; }
    fi
}

show_usage() {
    echo -e "${PSI_COLOR}4ndr0666OS | Ascension Protocol v8.2${RESET}"
    echo -e "Usage: $(basename "$0") [options]"
    echo -e ""
    echo -e "${INFO_COLOR}Operational Vectors:${RESET}"
    echo -e "  -h, --help       Display this tactical manifest."
    echo -e "  --sync           Execute global synchronization and Ghost Link audit."
    echo -e "  --inject <tool>  Deploy a specific tool into the Hive (e.g., stig, ImgCodeCheck)."
    echo -e ""
    echo -e "${WARN_COLOR}Note: Passing no arguments will populate this help menu.${RESET}"
}

# ---[ PHASE 0: DYNAMIC SYNC ]---
REAL_USER="${SUDO_USER:-$USER}"
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
XDG_DATA_HOME="${XDG_DATA_HOME:-$USER_HOME/.local/share}"
PYENV_ROOT="${XDG_DATA_HOME}/pyenv"
VENV_BASE="${XDG_DATA_HOME}/virtualenv"
BIN_TARGET="${USER_HOME}/.local/bin"

# Export paths for sub-processes
export PATH="$BIN_TARGET:${PYENV_ROOT}/bin:${PYENV_ROOT}/shims:$PATH"

install_resilient_tool() {
    local PKG_NAME="$1"
    local TARGET_VENV="${VENV_BASE}/${PKG_NAME}"
    
    log_info "Injecting $PKG_NAME into the Hive..."
    
    # Use Pyenv baseline if available, else native
    local PY_EXEC="${PYENV_ROOT}/versions/3.10.14/bin/python"
    if [[ ! -f "$PY_EXEC" ]]; then
        log_warn "Pyenv 3.10.14 not found. Falling back to native python3."
        PY_EXEC="/usr/bin/python3"
    fi

    ensure_dir "$VENV_BASE"
    ensure_dir "$TARGET_VENV"

    "$PY_EXEC" -m venv "$TARGET_VENV"
    
    log_info "Updating sector pip and installing $PKG_NAME..."
    "$TARGET_VENV/bin/pip" install --upgrade pip >/dev/null 2>&1
    "$TARGET_VENV/bin/pip" install "$PKG_NAME" >/dev/null 2>&1
    
    # Ghost Link creation for the specific tool
    ln -sf "$TARGET_VENV/bin/$PKG_NAME" "$BIN_TARGET/$PKG_NAME"
    log_success "$PKG_NAME successfully bridged to $BIN_TARGET"
}

run_sync() {
    log_psi "INITIALIZING OMNISCIENT SYNCHRONIZATION..."
    
    # Hive Sanitization
    for garbage in "--site-packages" ".venv"; do
        if [[ -d "$VENV_BASE/$garbage" ]]; then
            log_warn "Liquidating anomaly: $garbage"
            rm -rf "$VENV_BASE/$garbage"
        fi
    done

    # Runtime Discovery
    local SYS_PY_VER
    SYS_PY_VER=$(/usr/bin/python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    log_info "Native OS Python: $SYS_PY_VER | Pyenv Baseline: 3.10.14"

    # Ghost Link Idempotency (Global Hive)
    log_info "Enforcing Ghost Link: pyenv/env -> virtualenv/venv"
    ensure_dir "$VENV_BASE/venv"
    ensure_dir "$PYENV_ROOT"
    ln -sf "${VENV_BASE}/venv" "${PYENV_ROOT}/env"
    
    # Integrity Audit
    log_info "Architecture Audit:"
    if command -v eza >/dev/null 2>&1; then
        eza -al --icons "$VENV_BASE"
    else
        ls -alh "$VENV_BASE"
    fi
    log_psi "ASCENSION COMPLETE. SYSTEM ZEROED."
}

# ---[ ARGUMENT GATING ]---
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
