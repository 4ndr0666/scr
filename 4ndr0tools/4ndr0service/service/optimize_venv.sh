#!/usr/bin/env bash
# File: service/optimize_venv.sh
# 4ndr0666OS: Hardened Virtualenv & Pipx Maintenance Service
# - Logic: Nuclear Amputation Protocol for Metadata Deadlocks
# - Sync: Derived Pipx Pathing & XDG Artifact Scrubbing
# - Compliance: SC2155 (Exit Integrity), SC1091 (Venv Sourcing)

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

# ---[ DYNAMIC PATH RESOLUTION ]---
export VENV_HOME="${XDG_DATA_HOME}/virtualenv"
export VENV_PATH="${VENV_HOME}/venv"
export PIPX_VENVS="${PIPX_HOME:-$XDG_DATA_HOME/pipx}/venvs"

optimize_venv_service() {
    log_info "Synchronizing Hive Integrity..."
    # In optimize_venv_service(), before python -m venv:
    local py_ver
    py_ver=$(python3 --version 2>&1 | awk '{print $2}')
    if [[ "$py_ver" =~ ^3\.(1[4-9]|[2-9][0-9])\. ]] && python3 -c "import sys; sys.exit(0 if sys.version_info.releaselevel == 'final' else 1)" 2>/dev/null; then
        : # stable release, proceed
    elif python3 -c "import sys; sys.exit(0 if sys.version_info.releaselevel == 'final' else 1)" 2>/dev/null; then
        : # stable, proceed
    else
        log_warn "Active Python $py_ver is pre-release. Falling back to latest stable pyenv version."
        local stable
        stable=$(pyenv versions --bare | grep -E '^3\.[0-9]+\.[0-9]+$' | sort -V | tail -1)
        [[ -n "$stable" ]] && pyenv shell "$stable" || { log_error "No stable pyenv version found."; return 1; }
    fi

    # 1. Global Hive Maintenance
    if [[ ! -d "$VENV_PATH" ]]; then
        log_info "Initializing Main Hive Venv: $VENV_PATH"
        ensure_dir "$VENV_HOME"
        run_bounded 300 "Main Hive venv init" python3 -m venv "$VENV_PATH"
    fi

    # 2. Hive Core Update
    log_info "Updating Pip in Global Hive..."
    # D-11 FIX: Gate deactivate on successful activation. If the venv at
    # $VENV_PATH was corrupted between the -d check above and this source,
    # 'source activate' fails and 'deactivate' would be undefined — triggering
    # the ERR trap under set -euo pipefail and killing the service run.
    # shellcheck disable=SC1091
    if source "$VENV_PATH/bin/activate" 2>/dev/null; then
        run_bounded 300 "Hive pip upgrade" pip install --upgrade pip || log_warn "Hive Pip upgrade suppressed (Check network/build)."
        deactivate
    else
        log_warn "Could not activate venv at $VENV_PATH — skipping pip upgrade. Venv may be corrupted; run with --fix to recreate."
    fi

    # Rehash runtimes to acknowledge new Hive binaries
    [[ -d "$PYENV_ROOT" ]] && pyenv rehash

    # 3. Nuclear Amputation Protocol (Pipx Metadata Repair)
    if command -v pipx &>/dev/null; then
        local pipx_out
        pipx_out=$(pipx list 2>&1 || true)

        if [[ "$pipx_out" == *"missing internal pipx metadata"* ]]; then
            log_warn "Pipx Registry Corruption: Initiating Amputation..."

            local broken_pkgs
            broken_pkgs=$(echo "$pipx_out" | awk '/package .* has missing internal pipx metadata/ {print $2}' | sort -u)

            for bpkg in $broken_pkgs; do
                log_info "Attempting Sector Repair: $bpkg"
                if ! run_bounded 900 "pipx sector repair ($bpkg)" pipx install --force "$bpkg"; then
                    log_error "Metadata Deadlock: Repair failed for $bpkg"

                    if ! pipx uninstall "$bpkg"; then
                        log_warn "Standard Purge Failed. Executing Nuclear FS Deletion..."
                        local target_dir="$PIPX_VENVS/$bpkg"
                        if [[ -d "$target_dir" ]]; then
                            rm -rf "$target_dir"
                            log_success "Liquidated Sector: $target_dir"
                        fi
                    else
                        log_success "Standard Purge Complete: $bpkg"
                    fi
                else
                    log_success "Metadata Restored: $bpkg"
                fi
            done
        fi
    fi

    # 4. Pipx Package Synchronization
    local -a pkgs
    mapfile -t pkgs < <(jq -r '(.venv_pipx_packages // [])[]' "$CONFIG_FILE")

    if [[ ${#pkgs[@]} -gt 0 ]]; then
        log_info "Ensuring Isolated Tool Sync..."
        for p in "${pkgs[@]}"; do
            # D-23 FIX: was `pipx list | grep -q "$p"` — an unanchored substring
            # match against pipx's human-readable list output, which can false-
            # positive against unrelated package names or version-string noise.
            # `pipx list --short` emits one exact "<package> <version>" line
            # per installed tool; matching the package-name field with -x is
            # an exact lookup, mirroring how optimize_node.sh uses npm directly
            # rather than scraping free text.
            if ! (pipx list --short 2>/dev/null || true) | awk '{print $1}' | grep -qx "$p"; then
                log_info "Deploying: $p"
                run_bounded 900 "pipx install $p" pipx install "$p" || log_warn "Deployment failed: $p"
            fi
        done
    fi

    # 5. Routine Artifact Liquidation
    log_info "Purging System Artifacts (GPUCache / Code Cache)..."
    find "${XDG_CONFIG_HOME:-$HOME/.config}" -maxdepth 3 -type d -name "GPUCache"  -exec rm -rf {} + 2>/dev/null || true
    find "${XDG_CACHE_HOME:-$HOME/.cache}"   -maxdepth 3 -type d -name "Code Cache" -exec rm -rf {} + 2>/dev/null || true
    pip cache purge >/dev/null 2>&1 || true

    log_success "Hive Synchronization Complete."
}

# ──────────────────────────────────────────────────────────────────────────────
# STANDALONE BOOTSTRAP (SC2155 & SC1091 Compliant)
# ──────────────────────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    # shellcheck source=/dev/null
    source "$PKG_PATH/common.sh"
    # GAP-J FIX: standalone runs previously skipped suite initialization —
    # CONFIG_FILE could be absent, so every jq read silently failed and tool
    # sync was silently skipped. initialize_suite guarantees the XDG dirs,
    # the config file and the jq dependency exactly as the main.sh entry
    # point does (idempotent; the flock mutex is already held from the
    # common.sh source above).
    initialize_suite
    optimize_venv_service
fi
