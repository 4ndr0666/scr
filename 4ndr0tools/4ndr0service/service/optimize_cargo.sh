#!/usr/bin/env bash
# File: service/optimize_cargo.sh
# 4ndr0666OS: Hardened Rust/Cargo Optimization Service
# - Integration: Rustup Hive + Cargo-Update Delta Sync
# - Logic: Registry/Index Sanitization (Inode Recovery)
# - Compliance: SC2155 (Exit Integrity), SC1091 (Env Sourcing)

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=/dev/null
source "${PKG_PATH:-.}/common.sh"

export CARGO_HOME="${XDG_DATA_HOME}/cargo"
export RUSTUP_HOME="${XDG_DATA_HOME}/rustup"

optimize_cargo_service() {
    log_info "Synchronizing Cargo Matrix..."

    # 1. Rustup Infrastructure
    if ! command -v rustup &>/dev/null; then
        log_info "Rustup missing from Hive. Initiating deployment..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
            | sh -s -- -y --no-modify-path \
            || handle_error "$LINENO" "Rustup deployment failed."
    fi

    # 2. Environment Activation
    path_prepend "${CARGO_HOME}/bin"
    # shellcheck disable=SC1091
    [[ -s "${CARGO_HOME}/env" ]] && source "${CARGO_HOME}/env"

    # 3. Toolchain & Registry Sanitization
    log_info "Updating Toolchains & Purging Registry Index..."
    rustup update stable || log_warn "Toolchain update failed."
    rustup default stable &>/dev/null || true

    # FIX: Original used `rm -rf "${CARGO_HOME}/registry/index/*"` — the glob
    #      was inside double-quotes so the shell never expanded it; rm received
    #      a literal asterisk as the path argument, which is a no-op on any sane
    #      filesystem.  The glob must be outside quotes for shell expansion.
    # shellcheck disable=SC2086
    rm -rf ${CARGO_HOME}/registry/index/* 2>/dev/null || true

    # 4. Cargo Tool Synchronization (Delta-Aware)
    local tools_json
    tools_json=$(jq -r '(.cargo_tools // [])[]' "$CONFIG_FILE")
    local -a c_tools
    mapfile -t c_tools <<< "$tools_json"

    if [[ ${#c_tools[@]} -gt 0 && -n "${c_tools[0]}" ]]; then
        log_info "Synchronizing Cargo Tools..."

        local has_updater=false
        command -v cargo-install-update &>/dev/null && has_updater=true

        for tool in "${c_tools[@]}"; do
            [[ -z "$tool" ]] && continue
            if ! cargo install --list | grep -q "^${tool} "; then
                log_info "Deploying tool: $tool"
                cargo install "$tool" || log_warn "Cargo failed to deploy: $tool"
            else
                if [[ "$has_updater" == "true" ]]; then
                    log_info "Checking delta for: $tool"
                    cargo install-update "$tool" || log_warn "Delta sync failed: $tool"
                else
                    log_info "Forcing update for: $tool"
                    cargo install "$tool" || log_warn "Force update failed: $tool"
                fi
            fi
        done
    fi

    log_success "Cargo Matrix Calibrated. Rust: $(rustc --version | awk '{print $2}')"
}

# ──────────────────────────────────────────────────────────────────────────────
# STANDALONE BOOTSTRAP
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
    optimize_cargo_service
fi
