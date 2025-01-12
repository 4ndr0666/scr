#!/bin/bash
# -------------------------------------------------------------------
# File: optimize_cargo.sh
# Date: 2024-11-24
# Description: Optimizes Cargo environment in alignment with XDG Base Directory Specs.
# -------------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

LOG_FILE="${LOG_FILE:-$HOME/.cache/4ndr0service/logs/service_optimization.log}"
mkdir -p "$(dirname "$LOG_FILE")" || { echo "Failed to create log directory."; exit 1; }

log() {
    local message="$1"
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

handle_error() {
    local error_message="$1"
    echo -e "${RED}❌ Error: $error_message${NC}" >&2
    log "ERROR: $error_message"
    exit 1
}

check_directory_writable() {
    local dir_path="$1"
    if [[ ! -w "$dir_path" ]]; then
        handle_error "Directory $dir_path is not writable."
    else
        echo "✅ Directory $dir_path is writable."
        log "Directory '$dir_path' is writable."
    fi
}

export CARGO_HOME="${CARGO_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/cargo}"
export RUSTUP_HOME="${RUSTUP_HOME:-${XDG_DATA_HOME:-$HOME/.local/share}/rustup}"

install_rustup() {
    echo "📦 Installing rustup..."
    if curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path; then
        echo "✅ rustup installed successfully."
        log "rustup installed successfully."
    else
        handle_error "Failed to install rustup."
    fi
    [ -s "$CARGO_HOME/env" ] && source "$CARGO_HOME/env" || handle_error "Failed to source Rustup environment."
}

update_rustup_and_cargo() {
    if rustup self update &> /dev/null; then
        if rustup update; then
            echo "✅ rustup and Cargo updated successfully."
            log "rustup and Cargo updated successfully."
        else
            echo "⚠️ Warning: Failed to update Cargo."
            log "Warning: Failed to update Cargo."
        fi
    else
        echo "⚠️ rustup self-update disabled for this system. Use system package manager to update rustup."
        log "rustup self-update not available."
    fi
}

cargo_install_or_update() {
    local package_name="$1"
    if cargo install --list | grep -q "^$package_name "; then
        echo "🔄 Updating Cargo package: $package_name..."
        if cargo install "$package_name" --force; then
            echo "✅ $package_name updated successfully."
            log "$package_name updated successfully."
        else
            echo "⚠️ Warning: Failed to update $package_name."
            log "Warning: Failed to update $package_name."
        fi
    else
        echo "📦 Installing Cargo package: $package_name..."
        if cargo install "$package_name"; then
            echo "✅ $package_name installed successfully."
            log "$package_name installed successfully."
        else
            echo "⚠️ Warning: Failed to install $package_name."
            log "Warning: Failed to install $package_name."
        fi
    fi
}

consolidate_cargo_directories() {
    echo "🧹 Ensuring Cargo directories exist..."
    mkdir -p "$CARGO_HOME" "$RUSTUP_HOME" || handle_error "Failed creating Cargo dirs."

    if [[ -d "$HOME/.cargo" && "$HOME/.cargo" != "$CARGO_HOME" ]]; then
        echo "🧹 Moving existing .cargo => $CARGO_HOME..."
        mv "$HOME/.cargo" "$CARGO_HOME" || handle_error "Failed to move .cargo => $CARGO_HOME."
    fi
    if [[ -d "$HOME/.rustup" && "$HOME/.rustup" != "$RUSTUP_HOME" ]]; then
        echo "🧹 Moving existing .rustup => $RUSTUP_HOME..."
        mv "$HOME/.rustup" "$RUSTUP_HOME" || handle_error "Failed to move .rustup => $RUSTUP_HOME."
    fi
    log "Cargo directories consolidated."
}

install_cargo_tools() {
    echo "🔧 Installing essential Cargo tools (cargo-update, cargo-audit)..."
    cargo_install_or_update "cargo-update"
    cargo_install_or_update "cargo-audit"
}

manage_permissions() {
    echo "🔐 Verifying permissions for Cargo directories..."
    check_directory_writable "$CARGO_HOME"
    check_directory_writable "$RUSTUP_HOME"
    log "Permissions verified for Cargo directories."
}

validate_cargo_installation() {
    echo "✅ Validating Cargo installation..."
    if ! cargo --version &> /dev/null; then
        handle_error "Cargo missing. Use --fix to attempt installation."
    fi
    if ! rustup --version &> /dev/null; then
        handle_error "rustup not installed correctly."
    fi
    echo "✅ Cargo and rustup are installed + configured."
    log "Cargo validated."
}

perform_final_cleanup() {
    echo "🧼 Performing final cleanup tasks..."
    if [[ -d "$CARGO_HOME/tmp" ]]; then
        echo "🗑️ Cleaning $CARGO_HOME/tmp..."
        rm -rf "${CARGO_HOME:?}/tmp" || log "Warning: Failed removing $CARGO_HOME/tmp."
        log "Removed $CARGO_HOME/tmp."
    fi
    if [[ -d "$RUSTUP_HOME/tmp" ]]; then
        echo "🗑️ Cleaning $RUSTUP_HOME/tmp..."
        rm -rf "${RUSTUP_HOME:?}/tmp" || log "Warning: Failed removing $RUSTUP_HOME/tmp."
        log "Removed $RUSTUP_HOME/tmp."
    fi
    echo "🧼 Final cleanup completed."
    log "Cargo final cleanup done."
}

optimize_cargo_service() {
    echo "🔧 Starting Cargo environment optimization..."

    if ! command -v rustup &> /dev/null; then
        echo "📦 rustup not installed. Installing..."
        install_rustup
    else
        echo "✅ rustup already installed."
        log "rustup installed."
    fi

    echo "🔄 Updating rustup + Cargo..."
    update_rustup_and_cargo

    echo "🛠️ Setting PATH for Cargo..."
    export PATH="$CARGO_HOME/bin:$PATH"

    echo "🧹 Consolidating Cargo directories..."
    consolidate_cargo_directories

    echo "🔧 Installing essential Cargo tools..."
    install_cargo_tools

    echo "🔐 Managing permissions..."
    manage_permissions

    echo "✅ Validating Cargo installation..."
    validate_cargo_installation

    echo "🧼 Final cleanup..."
    perform_final_cleanup

    echo "🎉 Cargo environment optimization complete."
    echo -e "${CYAN}CARGO_HOME:${NC} $CARGO_HOME"
    echo -e "${CYAN}RUSTUP_HOME:${NC} $RUSTUP_HOME"
    echo -e "${CYAN}Cargo version:${NC} $(cargo --version)"
    echo -e "${CYAN}rustup version:${NC} $(rustup --version)"
    log "Cargo environment optimization completed."
}
