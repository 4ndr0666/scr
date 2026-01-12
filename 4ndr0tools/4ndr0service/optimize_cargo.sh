#!/usr/bin/env bash
# File: service/optimize_cargo.sh
# Optimized — uses common retry, safe_jq_array, dry-run

set -euo pipefail
IFS=$'\n\t'

source "$PKG_PATH/common.sh"

optimize_cargo_service() {
    log_info "Optimizing Cargo / Rust environment..."

    [[ "$DRY_RUN" == "true" ]] && { log_info "[DRY-RUN] Skipping actual changes."; return 0; }

    export CARGO_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/cargo"
    export RUSTUP_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/rustup"

    ensure_dir "$CARGO_HOME" "$RUSTUP_HOME"
    check_directory_writable "$CARGO_HOME" "$RUSTUP_HOME"

    if ! command -v rustup >/dev/null 2>&1; then
        log_info "Installing rustup..."
        retry curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
        source "$CARGO_HOME/env" || handle_error "Failed to source rustup env"
    fi

    log_info "Updating rustup + stable toolchain..."
    retry rustup self update
    retry rustup update stable
    retry rustup default stable

    mapfile -t TOOLS < <(safe_jq_array "cargo_tools" "$CONFIG_FILE")

    for tool in "${TOOLS[@]}"; do
        [[ -z "$tool" ]] && continue
        if cargo install --list | grep -q "^$tool "; then
            log_info "Updating $tool..."
            retry cargo install "$tool" --force
        else
            log_info "Installing $tool..."
            retry cargo install "$tool"
        fi
    done

    log_info "Cargo optimization complete."
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && optimize_cargo_service
