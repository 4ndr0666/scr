#!/usr/bin/env bash
# File: service/optimize_cargo.sh
# Description: Rust/Cargo environment optimization (XDG-compliant).

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=../common.sh
source "${PKG_PATH:-.}/common.sh"

export CARGO_HOME="${XDG_DATA_HOME}/cargo"
export RUSTUP_HOME="${XDG_DATA_HOME}/rustup"

optimize_cargo_service() {
    log_info "Optimizing Cargo environment..."
    
    # 1. Ensure Rustup
    if ! command -v rustup &>/dev/null; then
        log_info "Installing rustup..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path || handle_error "$LINENO" "Rustup installation failed."
    fi

    # 2. Setup Paths
    path_prepend "${CARGO_HOME}/bin"
    # shellcheck disable=SC1091
    [[ -s "${CARGO_HOME}/env" ]] && source "${CARGO_HOME}/env"

    # 3. Update Toolchain
    log_info "Updating Rust toolchains..."
    rustup update stable || log_warn "Toolchain update failed."
    rustup default stable &>/dev/null || true

    # 4. Install Cargo Tools from Config
    local -a tools
    mapfile -t tools < <(jq -r '(.cargo_tools // [])[]' "$CONFIG_FILE")
    
    for tool in "${tools[@]}"; do
        if ! cargo install --list | grep -q "^$tool "; then
            log_info "Installing $tool..."
            cargo install "$tool" || log_warn "Failed to install $tool"
        else
            log_info "Updating $tool..."
            cargo install "$tool" || log_warn "Failed to update $tool"
        fi
    done

    log_success "Cargo optimization complete. Rust: $(rustc --version | awk '{print $2}')"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    optimize_cargo_service
fi