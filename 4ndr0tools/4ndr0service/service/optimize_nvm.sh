#!/usr/bin/env bash
# 4ndr0666OS: Hardened NVM Setup & Conflict Resolution Service
# - Logic: Resolves .npmrc Prefix Schisms
# - Alignment: Unified XDG_DATA_HOME for NVM Runtimes
# - Compliance: SC2155 (Exit Integrity), SC1091 (NVM Sourcing)

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

# ---[ PATH ALIGNMENT ]---
# Runtimes = Data. Unified with Ascension v8.1 Hive architecture.
export NVM_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvm"

remove_npmrc_prefix_conflict() {
    local npmrc="$HOME/.npmrc"
    if [[ -f "$npmrc" ]]; then
        # Ψ-Check: Detect lines that would hijack the NVM environment
        if grep -Eq '^(prefix|globalconfig)=' "$npmrc"; then
            log_warn "Detected prefix/globalconfig conflict in ~/.npmrc. Sanitizing..."
            sed -i '/^\(prefix\|globalconfig\)=/d' "$npmrc"
            log_success ".npmrc sanitized for NVM compatibility."
        fi
    fi

    # D-25 FIX: nvm independently refuses to operate if certain environment
    # variables are set, regardless of ~/.npmrc content — this is a distinct
    # conflict source the original check never covered. nvm itself checks for
    # PREFIX, NPM_CONFIG_PREFIX (and its lowercase npm_config_prefix form),
    # and NPM_CONFIG_GLOBALCONFIG, and its own suggested fix is always a plain
    # unset. None of these are ever set by this suite (confirmed: no exports
    # of these names anywhere in 4ndr0service) — they come from the user's own
    # shell profile (e.g. a static "Zero-Artifact / Static Path Authority"
    # .zprofile export, per this suite's own convention in optimize_python.sh
    # and optimize_ruby.sh). Unsetting them here only affects this process and
    # its children (nvm.sh, npm, node), so it cannot silently break anything
    # that relies on them elsewhere in the user's environment after this
    # script exits.
    local -a conflicting_vars=(PREFIX NPM_CONFIG_PREFIX npm_config_prefix NPM_CONFIG_GLOBALCONFIG)
    local var unset_any=false
    for var in "${conflicting_vars[@]}"; do
        if [[ -n "${!var:-}" ]]; then
            log_warn "Detected $var=\"${!var}\" in the environment — nvm refuses to run with this set. Unsetting for this session..."
            unset "$var"
            unset_any=true
        fi
    done
    if [[ "$unset_any" == "true" ]]; then
        log_success "Environment sanitized for NVM compatibility."
        log_warn "This was re-exported by your shell profile (e.g. ~/.zprofile or ~/.zshrc). Remove that export there to stop it from coming back on your next login."
    fi
}

optimize_nvm_service() {
    log_info "Synchronizing NVM Infrastructure..."
    remove_npmrc_prefix_conflict

    # 1. NVM Deployment / Update
    if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
        log_info "NVM missing from Hive. Fetching latest release..."
        ensure_dir "$NVM_DIR"
        
        # SC2155: Capturing exit code of the API call
        local latest_nvm
        latest_nvm=$(curl -s --max-time 30 https://api.github.com/repos/nvm-sh/nvm/releases/latest | jq -r '.tag_name')
        
        if [[ -z "$latest_nvm" || "$latest_nvm" == "null" ]]; then
            handle_error "$LINENO" "Failed to retrieve latest NVM version from GitHub API."
        fi

        log_info "Deploying NVM version: $latest_nvm"
        curl -o- --max-time 120 "https://raw.githubusercontent.com/nvm-sh/nvm/${latest_nvm}/install.sh" | bash || handle_error "$LINENO" "NVM installation script failed."
    fi

    # 2. Hive Core Activation
    # shellcheck disable=SC1091
    if [[ -s "$NVM_DIR/nvm.sh" ]]; then
        source "$NVM_DIR/nvm.sh"
    else
        handle_error "$LINENO" "NVM core script missing after deployment."
    fi

    # 3. Node Version Synchronization
    local node_ver
    node_ver=$(jq -r '.node_version // "lts/*"' "$CONFIG_FILE")
    
    log_info "Aligning Hive Node to: $node_ver"
    # GUP 4.2: nvm is a shell FUNCTION, not an executable — timeout(1) cannot
    # invoke it directly, so each nvm operation is bounded through a bash -c
    # child that re-sources nvm.sh. Hard ceilings prevent a hung node
    # download/compile from wedging the systemd oneshot or the CLI menu.
    if ! run_bounded 900 "nvm install $node_ver" \
        bash -c 'source "${NVM_DIR}/nvm.sh" && nvm install "$1"' _ "$node_ver"; then
        log_error "nvm install failed for $node_ver."
        return 1
    fi
    if ! run_bounded 60 "nvm alias default $node_ver" \
        bash -c 'source "${NVM_DIR}/nvm.sh" && nvm alias default "$1"' _ "$node_ver"; then
        log_warn "nvm alias default failed for $node_ver — the runtime itself is installed."
    fi

    log_success "NVM Synchronization Complete."
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
    optimize_nvm_service
fi
