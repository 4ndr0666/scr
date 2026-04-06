#!/usr/bin/env bash
# 4ndr0666OS: Hardened Ruby/Gem Hive Optimization Service
# - Integration: XDG_DATA_HOME/gem Hive + Major.Minor.0 Pathing
# - Logic: Resolves Version-Path Schisms between Script & .zprofile
# - Compliance: SC2155 (Exit Integrity), SC1091 (Env Sourcing)

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=/dev/null
source "${PKG_PATH:-.}/common.sh"

# ---[ PATH ALIGNMENT ]---
# Gems = Data. Unified with .zprofile static exports.
export GEM_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/gem"

optimize_ruby_service() {
    log_info "Synchronizing Ruby Matrix..."

    # 1. Binary Infrastructure
    if ! command -v ruby &>/dev/null; then
        log_warn "Ruby missing from stack. Initiating deployment..."
        install_sys_pkg "ruby" || handle_error "$LINENO" "Ruby deployment failed."
    fi

    # 2. Version-Path Alignment Protocol
    # Arch Ruby uses X.Y.0 for gem paths regardless of patch version.
    local rb_ver
    rb_ver=$(ruby -e 'print RUBY_VERSION.sub(/\.\d+$/, ".0")')
    
    # Define the specific Hive sector for this Ruby version
    local gem_hive_bin="${GEM_HOME}/ruby/${rb_ver}/bin"
    export GEM_PATH="$GEM_HOME" # Ensures Ruby looks in our XDG Hive
    
    log_info "Detected Ruby Engine: $rb_ver"
    path_prepend "$gem_hive_bin"
    ensure_dir "$gem_hive_bin"

    # 3. Toolchain Synchronization
    local tools_json
    # SC2155 compliance
    tools_json=$(jq -r '(.ruby_gems // [])[]' "$CONFIG_FILE")
    local -a r_gems
    mapfile -t r_gems <<< "$tools_json"

    if [[ ${#r_gems[@]} -gt 0 ]]; then
        log_info "Synchronizing Ruby Gems..."
        for gem in "${r_gems[@]}"; do
            # We omit --user-install to force installation into our exported GEM_HOME
            if ! gem list -i "$gem" &>/dev/null; then
                log_info "Deploying Gem: $gem"
                gem install --no-document "$gem" || log_warn "Gem failed to deploy: $gem"
            else
                log_info "Syncing Gem state: $gem"
                gem update --no-document "$gem" || log_warn "Gem update suppressed: $gem"
            fi
        done
    fi

    # 4. Artifact Liquidation
    log_info "Purging stale Gem artifacts..."
    gem cleanup 2>/dev/null || true

    log_success "Ruby Matrix Calibrated. Active: $(ruby -v | awk '{print $2}')"
}

# ──────────────────────────────────────────────────────────────────────────────
# STANDALONE BOOTSTRAP (SC2155 & SC1091 Compliant)
# ──────────────────────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if [[ -z "${PKG_PATH:-}" ]]; then
        # Capture physical location to find common.sh
        _CURRENT_SVC_DIR="$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd -P)"
        readonly _CURRENT_SVC_DIR
        PKG_PATH="$(dirname "$_CURRENT_SVC_DIR")"
        export PKG_PATH
    fi

    # shellcheck source=/dev/null
    source "$PKG_PATH/common.sh"
    optimize_ruby_service
fi
