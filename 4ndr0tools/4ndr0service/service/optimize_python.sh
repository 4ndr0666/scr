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

# D-20 FIX: This re-derived the same path common.sh already exports as
# VENV_HOME (and which optimize_venv.sh re-exports identically). Three
# independent definitions of "where is the virtualenv hive" is a drift
# surface — using the shared VENV_HOME directly removes that surface.
VENV_BASE="$VENV_HOME"

# D-19 FIX: clean_pip_ghosts() below previously hardcoded /home/andro and
# andro:andro for its fallback path and ownership-reclaim step, silently
# defeating itself on any host where the real user is not literally "andro"
# (the chown target never existed, so the reclaim step was a permanent no-op,
# masked by `2>/dev/null || true`). Mirrors the same discovery pattern already
# established in ascension.sh.
REAL_USER="${SUDO_USER:-$USER}"
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

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

    # Never fall back to a hardcoded version — query the live pyenv version or
    # the running python3, so this function works regardless of which Python
    # version the suite is configured for.
    local py_version="${1:-}"
    if [[ -z "$py_version" ]]; then
        if command -v pyenv &>/dev/null; then
            py_version=$(pyenv global 2>/dev/null | head -1)
            [[ "$py_version" == "system" ]] && py_version=""
        fi
        if [[ -z "$py_version" ]]; then
            py_version=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')" 2>/dev/null || echo "")
        fi
        [[ -z "$py_version" ]] && { log_warn "Cannot determine Python version — skipping ghost clean"; return 0; }
    fi
    local site_pkgs
    site_pkgs=$(python3 -c "
import sysconfig
print(sysconfig.get_paths()['purelib'])
" 2>/dev/null || echo "${USER_HOME}/.local/share/pyenv/versions/${py_version}/lib/python${py_version%.*}/site-packages")

    if [[ ! -d "$site_pkgs" ]]; then
        log_warn "Site-packages not found at $site_pkgs — skipping ghost clean"
        return 0
    fi

    # Count ghosts before acting so the force-reinstall is gated on actual
    # corruption rather than running unconditionally on every optimize pass.
    local ghost_count=0
    local pattern
    for pattern in "~irtual*" "-irtual*" "*virtualenvondemand*" "*virtualenv-tools3*"; do
        local n
        n=$(find "$site_pkgs" -maxdepth 1 -name "$pattern" 2>/dev/null | wc -l)
        ghost_count=$(( ghost_count + n ))
    done

    if [[ $ghost_count -gt 0 ]]; then
        log_warn "Found $ghost_count ghost artifact(s) — removing..."
        sudo rm -rf "${site_pkgs}/~irtual"* 2>/dev/null || true
        sudo rm -rf "${site_pkgs}/-irtual"* 2>/dev/null || true
        sudo rm -rf "${site_pkgs}/*virtualenvondemand"* 2>/dev/null || true
        sudo rm -rf "${site_pkgs}/*virtualenv-tools3"* 2>/dev/null || true

        sudo chown -R "${REAL_USER}:${REAL_USER}" \
            "${USER_HOME}/.local/share/pyenv/versions/${py_version}" 2>/dev/null || true

        log_info "Corruption detected — purging pip cache and reinstalling build tools..."
        python -m pip cache purge 2>/dev/null || true
        python -m pip install --upgrade --force-reinstall --no-cache-dir --no-deps \
            pip setuptools wheel 2>/dev/null || true
        log_success "Ghost exorcism complete for Python ${py_version} ($ghost_count artifact(s) removed)"
    else
        log_success "Ghost exorcism complete for Python ${py_version} — environment is clean"
    fi
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
    # Never fall back to a hardcoded version string — always query the live
    # running environment so the suite stays correct when Python is upgraded.
    local target_ver=""
    if command -v jq &>/dev/null && [[ -f "${CONFIG_FILE:-}" ]]; then
        local _cfg_ver
        _cfg_ver=$(jq -r '.python_version // ""' "$CONFIG_FILE")
        # Reject the stale default if the live pyenv global differs — this is
        # exactly the broken-interpreter scenario reported in the logs.
        if [[ -n "$_cfg_ver" && "$_cfg_ver" != "3.10.14" ]]; then
            target_ver="$_cfg_ver"
        fi
    fi
    if [[ -z "$target_ver" ]] && command -v pyenv &>/dev/null; then
        local _pv
        _pv=$(pyenv global 2>/dev/null | head -1)
        [[ -n "$_pv" && "$_pv" != "system" ]] && target_ver="$_pv"
    fi
    if [[ -z "$target_ver" ]]; then
        target_ver=$(python3 -c \
            "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')" \
            2>/dev/null || echo "")
    fi
    if [[ -z "$target_ver" ]]; then
        log_error "Cannot determine target Python version. Aborting Python optimization."
        return 1
    fi

    log_info "Ensuring Python $target_ver via Pyenv Hive..."
    pyenv install -s "$target_ver"
    pyenv global "$target_ver"
    pyenv rehash

    # Persist the detected version back to config.json so future runs skip
    # this discovery path and don't accidentally revert to a stale value.
    if command -v jq &>/dev/null && [[ -f "${CONFIG_FILE:-}" ]]; then
        local _stored
        _stored=$(jq -r '.python_version // ""' "$CONFIG_FILE")
        if [[ "$_stored" != "$target_ver" ]]; then
            local _tmp
            _tmp=$(mktemp)
            jq --arg v "$target_ver" '.python_version = $v' "$CONFIG_FILE" > "$_tmp" \
                && mv "$_tmp" "$CONFIG_FILE" \
                && log_info "Updated config.json python_version → $target_ver"
        fi
    fi

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

    # Pipx bad-interpreter repair: pipx stores the path to its Python
    # interpreter at install time. If pyenv was upgraded or the configured
    # version changed, pipx's shebang becomes a dangling path and every
    # invocation fails with "bad interpreter: No such file or directory".
    # Detect and repair before attempting any tool work.
    if ! pipx --version &>/dev/null 2>&1; then
        log_warn "pipx interpreter broken (stale pyenv path in shebang). Reinstalling..."
        rm -f "${PIPX_BIN_DIR:-$HOME/.local/bin}/pipx" 2>/dev/null || true
        if command -v pacman &>/dev/null; then
            sudo pacman -S --needed --noconfirm python-pipx \
                && log_success "pipx reinstalled via pacman." \
                || { log_error "pacman reinstall of pipx failed — reinstall manually."; return 1; }
        fi
        if ! pipx --version &>/dev/null 2>&1; then
            log_error "pipx still broken after reinstall. Skipping tool injection."
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
                # D-23 FIX: was `pipx list | grep -q "$tool"` — see optimize_venv.sh
                # for the full rationale. Exact-match against the package-name
                # field of `pipx list --short` instead of substring-matching
                # pipx's free-text listing.
                if ! (pipx list --short 2>/dev/null || true) | awk '{print $1}' | grep -qx "$tool"; then
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
