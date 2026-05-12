#!/usr/bin/env bash
# 4ndr0666OS: Hardened Python/Pyenv/Pipx Optimization Service
# - Integration: pyenv + virtualenv Hive + Ghost Link Enforcement
# - Compliance: SC2155 (Exit Integrity), SC1091 (Runtime Sourcing)
# - Policy: Zero-Artifact / Static Path Authority (.zprofile)
#
# D-06 FIX: Global Hive venv initialization moved to BEFORE Dynamic Tool
# Injection (was duplicate step 5 after injection). The Ghost Link
# ${PYENV_ROOT}/env -> ${VENV_BASE}/venv must point to an existing directory
# before pipx installs tools that resolve the python executable via it.

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=/dev/null
source "${PKG_PATH:-.}/common.sh"

VENV_BASE="${XDG_DATA_HOME:-$HOME/.local/share}/virtualenv"

load_pyenv() {
    if [[ -d "$PYENV_ROOT" ]]; then
        path_prepend "$PYENV_ROOT/bin"
        eval "$(pyenv init -)"
        [[ ":$PATH:" != *":$PYENV_ROOT/shims:"* ]] && path_prepend "$PYENV_ROOT/shims"
        return 0
    fi
    return 1
}

install_pyenv() {
    log_warn "Pyenv missing from $PYENV_ROOT. Initiating deployment..."
    if ! command -v curl &>/dev/null; then
        log_error "Dependency missing: curl. Pyenv deployment aborted."
        return 1
    fi
    curl https://pyenv.run | bash || handle_error "$LINENO" "Pyenv deployment failed."
    load_pyenv
}

# ── GHOST EXORCISM (Integrated Pip Cleanup) ──────────────────────────────────
clean_pip_ghosts() {
    log_info "Initiating Ghost Exorcism Protocol..."

    local py_version="${1:-3.10.14}"
    local site_pkgs="/home/andro/.local/share/pyenv/versions/${py_version}/lib/python${py_version#*.}/site-packages"

    if [[ ! -d "$site_pkgs" ]]; then
        log_warn "Site-packages not found at $site_pkgs — skipping ghost clean"
        return 0
    fi

    # Kill known ghost patterns
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

optimize_python_service() {
    log_info "Synchronizing Python Matrix..."

    # 0. Dependency Pre-Flight
    if ! command -v jq &>/dev/null; then
        log_warn "Dependency missing: jq. Dynamic JSON parsing will be degraded."
    fi

    # 1. Pyenv Bootstrap & Initial Shimming
    if ! load_pyenv; then
        install_pyenv || exit 1
    fi

    # 2. Ghost Link Idempotency (Phase 3 Sync)
    local ghost_link="${PYENV_ROOT}/env"
    local hive_main="${VENV_BASE}/venv"

    if [[ ! -L "$ghost_link" ]]; then
        log_warn "Ghost Link anomaly detected. Restoring bridge..."
        ensure_dir "$VENV_BASE"
        ln -sfn "$hive_main" "$ghost_link"
        log_success "Ghost Link established: $ghost_link -> $hive_main"
    else
        log_info "Ghost Link stable."
    fi

    # 3. Version Enforcement & Baseline Alignment
    local target_ver="3.10.14"
    if command -v jq &>/dev/null && [[ -f "${CONFIG_FILE:-}" ]]; then
        target_ver=$(jq -r '.python_version // "3.10.14"' "$CONFIG_FILE")
    fi

    log_info "Ensuring Python $target_ver via Pyenv Hive..."
    pyenv install -s "$target_ver"
    pyenv global "$target_ver"
    pyenv rehash

    # Integrated Ghost Exorcism (after pyenv baseline is ready)
    clean_pip_ghosts "$target_ver"

    # 4. Global Hive Initialization — MUST precede tool injection (D-06 FIX).
    #    pipx resolves its python executable through the Ghost Link path;
    #    that path must exist as a real directory before any pipx install.
    if [[ ! -d "$hive_main" ]]; then
        log_info "Initializing Main Hive Venv at $hive_main..."
        ensure_dir "$VENV_BASE"
        python3 -m venv "$hive_main"
        log_success "Main Hive online."
    else
        log_info "Main Hive venv present: $hive_main"
    fi

    # 5. Pipx Isolation & Tool Sync
    if ! command -v pipx &>/dev/null; then
        log_warn "Pipx absent. Executing PEP-668 compliant bootstrap..."
        if command -v pacman &>/dev/null; then
            sudo pacman -S --needed --noconfirm python-pipx
        else
            log_error "Install pipx via pacman (python-pipx) before running this service."
            return 1
        fi
    fi

    # 6. Dynamic Tool Injection Matrix
    if command -v jq &>/dev/null && [[ -f "${CONFIG_FILE:-}" ]]; then
        local -a py_tools
        mapfile -t py_tools < <(jq -r '(.python_tools // [])[]' "$CONFIG_FILE" 2>/dev/null || true)

        if [[ ${#py_tools[@]} -gt 0 ]]; then
            for tool in "${py_tools[@]}"; do
                [[ -z "$tool" ]] && continue
                if ! pipx list 2>/dev/null | grep -q "$tool"; then
                    log_info "Deploying tool to Hive sector: $tool"
                    pipx install "$tool" || log_warn "Pipx failed to deploy: $tool"
                else
                    log_info "Verifying tool integrity: $tool"
                    pipx upgrade "$tool" >/dev/null 2>&1 || log_warn "Pipx upgrade failed for: $tool"
                fi
            done
        else
            log_info "No Python tools specified in matrix config."
        fi
    else
        log_warn "Matrix config unavailable or jq missing. Skipping dynamic tool injection."
    fi

    log_success "Python Optimization Complete. Active: $(python3 --version | awk '{print $2}')"
}

# ──────────────────────────────────────────────────────────────────────────────
# STANDALONE BOOTSTRAP (SC2155 & SC1091 Compliant)
# ──────────────────────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if [[ -z "${PKG_PATH:-}" ]]; then
        _CURRENT_SVC_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"
        readonly _CURRENT_SVC_DIR
        PKG_PATH="$(dirname "$_CURRENT_SVC_DIR")"
        export PKG_PATH
    fi
    # shellcheck source=/dev/null
    source "$PKG_PATH/common.sh"
    optimize_python_service
fi
