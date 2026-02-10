#!/usr/bin/env bash
# 4ndr0666OS: Arch Universal Ascension Protocol v6 (Symbiotic/Visual)
# - Integrated: aliasrc aesthetics (eza/bat integration)
# - Behavior: Verbose file ops (mkdir -pv) matching user preference
# - Logic: Dynamic dependency healing for user's UI stack

set -euo pipefail
trap 'echo -e "\033[38;5;196m[ERROR] Protocol severed at line $LINENO\033[0m" >&2' ERR

# ---[ CONFIG & VISUALS ]---
PSI_COLOR="\033[38;5;196m"
WARN_COLOR="\033[38;5;208m"
SUCCESS_COLOR="\033[38;5;46m"
INFO_COLOR="\033[38;5;45m"
SUBTLE_COLOR="\033[38;5;240m"
RESET="\033[0m"

# ---[ CORE FUNCTIONS ]---

# Use bat for logging if available, otherwise standard echo
log_psi() { echo -e "${PSI_COLOR}[Ψ-CORE] $1${RESET}"; }
log_info() { echo -e "${INFO_COLOR}[INFO] $1${RESET}"; }
log_warn() { echo -e "${WARN_COLOR}[WARN] $1${RESET}"; }
log_success() { echo -e "${SUCCESS_COLOR}[SUCCESS] $1${RESET}"; }

# Smart listing function (Mimics your 'la' alias)
list_dir() {
    if command -v eza >/dev/null 2>&1; then
        eza -alXMoZ --no-quotes --time=created --classify=always --colour-scale=all --colour-scale-mode=gradient --icons=always "$@"
    else
        ls -alh "$@"
    fi
}

# Smart view function (Mimics your '00' style aliases)
view_file() {
    if command -v bat >/dev/null 2>&1; then
        bat --style=plain --paging=never --color=always "$1"
    else
        cat "$1"
    fi
}

# ---[ PHASE 0: ENVIRONMENT SYNCHRONIZATION ]---

log_psi "INITIALIZING ENVIRONMENT SYNCHRONIZATION..."

REAL_USER="${SUDO_USER:-$USER}"
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

# Inherit XDG
export XDG_DATA_HOME="${XDG_DATA_HOME:-$USER_HOME/.local/share}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$USER_HOME/.config}"

# Source zprofile for PATHs
if [ -f "$USER_HOME/.zprofile" ]; then
    log_info "Sourcing .zprofile..."
    set +u
    . "$USER_HOME/.zprofile"
    set -u
else
    # Fallback paths
    export PATH="$USER_HOME/.local/bin:$PATH"
fi

# Respect Editor
EDITOR="${EDITOR:-nvim}"

# ---[ PHASE 1: UI STACK HEALTH CHECK ]---

log_info "Verifying User Interface Stack (from aliasrc)..."

# Your aliasrc relies on these. If they are missing, your shell experience is broken.
UI_TOOLS=("eza" "bat" "lazygit" "neovim")
MISSING_UI=()

for tool in "${UI_TOOLS[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        MISSING_UI+=("$tool")
    fi
done

detect_aur_helper() {
    if command -v paru >/dev/null 2>&1; then echo "paru";
    elif command -v yay >/dev/null 2>&1; then echo "yay";
    else echo ""; fi
}

AUR_HELPER=$(detect_aur_helper)
if [ -z "$AUR_HELPER" ]; then
    echo -e "${PSI_COLOR}CRITICAL: No AUR helper found.${RESET}"
    exit 1
fi

if [ ${#MISSING_UI[@]} -gt 0 ]; then
    log_warn "Missing UI dependencies detected: ${MISSING_UI[*]}"
    echo -e "${SUBTLE_COLOR}Restoring visual stack to match aliasrc specifications...${RESET}"
    "$AUR_HELPER" -S --noconfirm "${MISSING_UI[@]}"
    log_success "UI Stack Restored."
fi

# ---[ PHASE 2: DYNAMIC PYTHON TARGETING ]---

CURRENT_PY_VER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
log_info "Current Python: $CURRENT_PY_VER"

log_info "Scanning for dead runtimes..."
mapfile -t DEAD_RUNTIMES < <(find /usr/lib -maxdepth 1 -type d -name "python3.*" ! -name "python$CURRENT_PY_VER" 2>/dev/null || true)

TARGETS=()

if [ ${#DEAD_RUNTIMES[@]} -eq 0 ]; then
    log_success "No obsolete runtimes found."
else
    for dead_dir in "${DEAD_RUNTIMES[@]}"; do
        log_warn "Analyzing: $dead_dir"
        
        # Identify owners
        FOUND_PKGS=$(find "$dead_dir" -type f 2>/dev/null | \
                     xargs -r pacman -Qo 2>/dev/null | \
                     awk '/is owned by/ {print $5}' | \
                     sort -u)
                     
        if [ -n "$FOUND_PKGS" ]; then
            echo -e "${WARN_COLOR}Orphans found in $dead_dir:${RESET}"
            echo "$FOUND_PKGS"
            TARGETS+=($FOUND_PKGS)
        fi
    done
fi

if [ ${#TARGETS[@]} -gt 0 ]; then
    UNIQUE_TARGETS=($(printf "%s\n" "${TARGETS[@]}" | sort -u))
    log_psi "Migrating ${#UNIQUE_TARGETS[@]} packages..."
    "$AUR_HELPER" -S --rebuild --noconfirm "${UNIQUE_TARGETS[@]}"
    log_success "Migration complete."
fi

# ---[ PHASE 3: IDEMPOTENT CLEANUP ]---

log_info "Cleaning artifacts..."
for dead_dir in "${DEAD_RUNTIMES[@]}"; do
    if [ -d "$dead_dir" ]; then
        # Verbose removal logic matching your style
        if rmdir --ignore-fail-on-non-empty "$dead_dir" 2>/dev/null; then
            echo -e "${SUBTLE_COLOR}Removed empty: $dead_dir${RESET}"
        else
            log_warn "$dead_dir not empty. Purging bytecode..."
            find "$dead_dir" -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
            rmdir --ignore-fail-on-non-empty "$dead_dir" 2>/dev/null || true
        fi
    fi
done

# ---[ PHASE 4: RESILIENT INSTALLER ]---

install_resilient_tool() {
    local PKG_NAME="$1"
    local PIP_ARGS="${2:-}"
    
    if command -v "$PKG_NAME" >/dev/null 2>&1; then
        log_success "$PKG_NAME OK."
        return 0
    fi
    
    log_warn "$PKG_NAME missing. Installing..."
    
    if ! command -v pipx >/dev/null 2>&1; then
        sudo pacman -S --noconfirm python-pipx >/dev/null
        pipx ensurepath
        export PATH="$HOME/.local/bin:$PATH"
    fi
    
    set +e 
    # Strategy A
    if pipx install --force "$PKG_NAME" --pip-args "$PIP_ARGS" >/dev/null 2>&1; then
        log_success "$PKG_NAME installed via pipx."
        set -e
        return 0
    fi
    
    # Strategy B (Legacy Shim)
    log_warn "Pipx failed. Attempting Legacy Shim..."
    
    local FALLBACK_PY="python3.12"
    if ! command -v $FALLBACK_PY >/dev/null 2>&1; then
        "$AUR_HELPER" -S --noconfirm python312 >/dev/null
    fi
    
    if command -v $FALLBACK_PY >/dev/null 2>&1; then
        local VENV_PATH="$XDG_DATA_HOME/${PKG_NAME}-legacy-env"
        # Verbose mkdir matching your alias 'mkdir -pv'
        mkdir -pv "$(dirname "$VENV_PATH")"
        
        rm -rf "$VENV_PATH"
        $FALLBACK_PY -m venv "$VENV_PATH"
        source "$VENV_PATH/bin/activate"
        
        if [ -n "$PIP_ARGS" ]; then pip install "$PKG_NAME" $PIP_ARGS >/dev/null;
        else pip install "$PKG_NAME" >/dev/null; fi
        
        mkdir -pv "$HOME/.local/bin"
        ln -sf "$VENV_PATH/bin/$PKG_NAME" "$HOME/.local/bin/$PKG_NAME"
        
        log_success "$PKG_NAME shimmed via $FALLBACK_PY."
    else
        log_psi "FAIL: Could not install $PKG_NAME."
        return 1
    fi
    set -e
}

# ---[ PHASE 5: VERIFICATION ]---

# install_resilient_tool "cyberdrop-dl" "--no-binary pillow --pre"

log_info "Final Status:"
# Use bat to display the integrity check if possible
if command -v bat >/dev/null 2>&1; then
    pacman -Qkk 2>&1 | grep "python$CURRENT_PY_VER" | bat --language=log --style=plain || echo "Clean."
else
    pacman -Qkk 2>&1 | grep "python$CURRENT_PY_VER" || echo "Clean."
fi

log_psi "SYSTEM OPTIMIZED."s
