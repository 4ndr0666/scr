#!/usr/bin/env bash
# 4ndr0666OS: Hardened NVM Setup & Conflict Resolution Service
# - Logic: Resolves .npmrc Prefix Schisms
# - Alignment: Unified XDG_DATA_HOME for NVM Runtimes
# - Compliance: SC2155 (Exit Integrity), SC1091 (NVM Sourcing)

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=/dev/null
source "${PKG_PATH:-.}/common.sh"

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
        latest_nvm=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | jq -r '.tag_name')
        
        if [[ -z "$latest_nvm" || "$latest_nvm" == "null" ]]; then
            handle_error "$LINENO" "Failed to retrieve latest NVM version from GitHub API."
        fi

        log_info "Deploying NVM version: $latest_nvm"
        curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${latest_nvm}/install.sh" | bash || handle_error "$LINENO" "NVM installation script failed."
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
    nvm install "$node_ver"
    nvm alias default "$node_ver"
    
    log_success "NVM Synchronization Complete."
}

# ──────────────────────────────────────────────────────────────────────────────
# STANDALONE BOOTSTRAP (SC2155 & SC1091 Compliant)
# ──────────────────────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if [[ -z "${PKG_PATH:-}" ]]; then
        # Capture physical location safely to find common.sh
        _CURRENT_SVC_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"
        readonly _CURRENT_SVC_DIR
        PKG_PATH="$(dirname "$_CURRENT_SVC_DIR")"
        export PKG_PATH
    fi

    # shellcheck source=/dev/null
    source "$PKG_PATH/common.sh"
    optimize_nvm_service
fi
