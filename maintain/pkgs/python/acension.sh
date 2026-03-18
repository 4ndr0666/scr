#!/usr/bin/env bash
# 4ndr0666OS: Arch Universal Ascension Protocol v8.1 (Omniscient/Clean)
# - Host: theworkpc | User: andro (Dynamic Discovery)
# - Integration: pyenv + virtualenv + Ghost Link Enforcement
# - Logic: Automatic system Python discovery + Artifact Purge

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

# ---[ PHASE 0: DYNAMIC SYNC ]---
log_psi "INITIALIZING OMNISCIENT SYNCHRONIZATION..."

REAL_USER="${SUDO_USER:-$USER}"
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
XDG_DATA_HOME="${XDG_DATA_HOME:-$USER_HOME/.local/share}"
PYENV_ROOT="${XDG_DATA_HOME}/pyenv"
VENV_BASE="${XDG_DATA_HOME}/virtualenv"
BIN_TARGET="${USER_HOME}/.local/bin"

export PATH="$BIN_TARGET:${PYENV_ROOT}/bin:${PYENV_ROOT}/shims:$PATH"

# ---[ PHASE 1: ARTIFACT LIQUIDATION ]---
log_info "Executing targeted artifact purge..."
for garbage in ".venv" "--site-packages"; do
    if [[ -d "$VENV_BASE/$garbage" ]]; then
        log_warn "Liquidating anomaly: $garbage"
        rm -rf "$VENV_BASE/$garbage"
    fi
done

# ---[ PHASE 2: SYSTEM RUNTIME DISCOVERY ]---
# Dynamically find the Arch native Python (e.g., 3.14) to avoid false flags
SYS_PY_VER=$(/usr/bin/python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
log_info "Native OS Python: $SYS_PY_VER | Pyenv Baseline: 3.10.14"

log_info "Scanning for runtime entropy..."
mapfile -t DEAD_RUNTIMES < <(find /usr/lib -maxdepth 1 -type d -name "python3.*" ! -name "python$SYS_PY_VER" 2>/dev/null || true)

for dead_dir in "${DEAD_RUNTIMES[@]}"; do
    FOUND_PKGS=$(find "$dead_dir" -type f 2>/dev/null | xargs -r pacman -Qo 2>/dev/null | awk '/is owned by/ {print $5}' | sort -u || true)
    if [[ -n "$FOUND_PKGS" ]]; then
        log_warn "Orphans in $dead_dir: $(echo "$FOUND_PKGS" | xargs)"
    fi
done

# ---[ PHASE 3: GHOST LINK IDEMPOTENCY ]---
log_info "Enforcing Ghost Link: pyenv/env -> virtualenv/venv"
if [[ ! -L "${PYENV_ROOT}/env" ]]; then
    ln -sf "${VENV_BASE}/venv" "${PYENV_ROOT}/env"
    log_success "Ghost link restored."
else
    log_success "Ghost link stable."
fi

# ---[ PHASE 4: HIVE-AWARE INSTALLER ]---
install_resilient_tool() {
    local PKG_NAME="$1"
    local TARGET_VENV="${VENV_BASE}/${PKG_NAME}"
    
    if command -v "$PKG_NAME" >/dev/null 2>&1; then
        log_success "$PKG_NAME operational."
        return 0
    fi

    log_warn "$PKG_NAME missing. Deploying into Hive..."
    
    # Use Pyenv baseline if available, else native
    local PY_EXEC="${PYENV_ROOT}/versions/3.10.14/bin/python"
    [[ ! -f "$PY_EXEC" ]] && PY_EXEC="/usr/bin/python3"

    mkdir -pv "$TARGET_VENV"
    "$PY_EXEC" -m venv "$TARGET_VENV"
    "$TARGET_VENV/bin/pip" install --upgrade pip "$PKG_NAME" >/dev/null
    
    ln -sf "$TARGET_VENV/bin/$PKG_NAME" "$BIN_TARGET/$PKG_NAME"
    pyenv rehash 2>/dev/null || true
    log_success "$PKG_NAME injected."
}

# ---[ PHASE 5: AUDIT ]---
log_info "Final Architecture Audit:"
if command -v eza >/dev/null 2>&1; then
    eza -alXMoZ --icons=always "$VENV_BASE"
else
    ls -alh "$VENV_BASE"
fi

log_psi "ASCENSION COMPLETE. SYSTEM ZEROED."
