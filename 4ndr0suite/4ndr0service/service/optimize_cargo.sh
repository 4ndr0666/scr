#!/bin/bash
# File: optimize_cargo.sh
# Author: 4ndr0666
# Date: 2024-11-24
# Description: Optimizes Cargo environment in alignment with XDG Base Directory Specifications.

set -euo pipefail
IFS=$'\n\t'

# Define color codes for enhanced output
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Define LOG_FILE if not already defined
LOG_FILE="${LOG_FILE:-$HOME/.cache/4ndr0service/logs/service_optimization.log}"
mkdir -p "$(dirname "$LOG_FILE")"

# Function to log messages with timestamp
log() {
    local message="$1"
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

# Function to handle errors and exit
handle_error() {
    local error_message="$1"
    echo -e "${RED}❌ Error: $error_message${NC}" >&2
    log "ERROR: $error_message"
    exit 1
}

# Function to check if a directory is writable
check_directory_writable() {
    local dir_path="$1"

    if [[ -w "$dir_path" ]]; then
        echo "✅ Directory $dir_path is writable."
        log "Directory '$dir_path' is writable."
    else
        echo -e "${RED}❌ Error: Directory $dir_path is not writable.${NC}"
        log "ERROR: Directory '$dir_path' is not writable."
        exit 1
    fi
}

# Define Cargo directories based on XDG specifications
export CARGO_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/cargo"
export RUSTUP_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/rustup"

# Function to optimize Cargo environment
optimize_cargo_service() {
    echo "🔧 Starting Cargo environment optimization..."

    # Step 1: Check if rustup is installed
    if ! command -v rustup &> /dev/null; then
        echo "📦 rustup is not installed. Installing rustup and Cargo..."
        install_rustup
    else
        echo "✅ rustup is already installed."
        log "rustup is already installed."
    fi

    # Step 2: Update rustup and Cargo
    echo "🔄 Updating rustup and Cargo..."
    update_rustup_and_cargo

    # Step 3: Set up environment variables
    echo "🛠️ Setting up environment variables for Cargo and rustup..."
    export PATH="$CARGO_HOME/bin:$PATH"

    # Step 4: Consolidate Cargo directories
    echo "🧹 Consolidating Cargo directories..."
    consolidate_cargo_directories

    # Step 5: Install or update essential Cargo tools
    echo "🔧 Installing or updating essential Cargo tools..."
    install_cargo_tools

    # Step 6: Manage permissions for Cargo directories
    echo "🔐 Managing permissions for Cargo directories..."
    manage_permissions

    # Step 7: Validate Cargo installation
    echo "✅ Validating Cargo installation..."
    validate_cargo_installation

    # Step 8: Final cleanup
    echo "🧼 Performing final cleanup..."
    perform_final_cleanup

    # Final summary
    echo "🎉 Cargo environment optimization complete."
    echo -e "${CYAN}CARGO_HOME:${NC} $CARGO_HOME"
    echo -e "${CYAN}RUSTUP_HOME:${NC} $RUSTUP_HOME"
    echo -e "${CYAN}Cargo version:${NC} $(cargo --version)"
    echo -e "${CYAN}rustup version:${NC} $(rustup --version)"
}

# Function to install rustup and Cargo
install_rustup() {
    echo "📦 Installing rustup..."
    if curl https://sh.rustup.rs -sSf | sh -s -- -y --no-modify-path; then
        echo "✅ rustup installed successfully."
        log "rustup installed successfully."
    else
        handle_error "Failed to install rustup."
    fi
}

# Function to update rustup and Cargo
update_rustup_and_cargo() {
    # Check if rustup self-update is allowed
    if rustup self update &> /dev/null; then
        if rustup update; then
            echo "✅ rustup and Cargo updated successfully."
            log "rustup and Cargo updated successfully."
        else
            echo "⚠️ Warning: Failed to update Cargo."
            log "Warning: Failed to update Cargo."
        fi
    else
        echo "⚠️ rustup self-update is disabled for this build."
        echo "⚠️ Please use your system package manager to update rustup."
        log "rustup self-update is disabled. Instructed user to use system package manager."
    fi
}

# Function to install or update a Cargo package
cargo_install_or_update() {
    local package_name="$1"

    if cargo install --list | grep -q "^$package_name v"; then
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

# Function to perform directory consolidation and cleanup
consolidate_cargo_directories() {
    echo "🧹 Ensuring Cargo directories exist and are correct..."

    # Ensure directories exist
    mkdir -p "$CARGO_HOME" "$RUSTUP_HOME" || handle_error "Failed to create Cargo directories."

    # Move any existing .cargo or .rustup directories to XDG locations
    if [[ -d "$HOME/.cargo" && "$HOME/.cargo" != "$CARGO_HOME" ]]; then
        echo "🧹 Moving existing .cargo directory to $CARGO_HOME..."
        mv "$HOME/.cargo" "$CARGO_HOME" || handle_error "Failed to move .cargo to $CARGO_HOME."
    fi

    if [[ -d "$HOME/.rustup" && "$HOME/.rustup" != "$RUSTUP_HOME" ]]; then
        echo "🧹 Moving existing .rustup directory to $RUSTUP_HOME..."
        mv "$HOME/.rustup" "$RUSTUP_HOME" || handle_error "Failed to move .rustup to $RUSTUP_HOME."
    fi

    log "Cargo directories consolidated and verified as writable."
}

# Function to install essential Cargo tools
install_cargo_tools() {
    echo "🔧 Installing essential Cargo tools (cargo-update, cargo-audit)..."

    # cargo-install-update
    cargo_install_or_update "cargo-update"

    # cargo-audit
    cargo_install_or_update "cargo-audit"
}

# Function to manage permissions for Cargo directories
manage_permissions() {
    echo "🔐 Verifying permissions for Cargo directories..."

    check_directory_writable "$CARGO_HOME"
    check_directory_writable "$RUSTUP_HOME"

    log "Permissions for Cargo directories are verified."
}

# Function to validate Cargo installation
validate_cargo_installation() {
    echo "✅ Validating Cargo installation..."

    # Check Cargo version
    if ! cargo --version &> /dev/null; then
        handle_error "Cargo is not installed correctly."
    fi

    # Check rustup version
    if ! rustup --version &> /dev/null; then
        handle_error "rustup is not installed correctly."
    fi

    echo "✅ Cargo and rustup are installed and configured correctly."
    log "Cargo installation validated successfully."
}

# Function to perform final cleanup tasks
perform_final_cleanup() {
    echo "🧼 Performing final cleanup tasks..."

    # Remove temporary files if they exist
    if [[ -d "$CARGO_HOME/tmp" ]]; then
        echo "🗑️ Cleaning up temporary files in $CARGO_HOME/tmp..."
        rm -rf "${CARGO_HOME:?}/tmp" || log "⚠️ Warning: Failed to remove temporary files in '$CARGO_HOME/tmp'."
        log "Temporary files in '$CARGO_HOME/tmp' removed."
    fi

    if [[ -d "$RUSTUP_HOME/tmp" ]]; then
        echo "🗑️ Cleaning up temporary files in $RUSTUP_HOME/tmp..."
        rm -rf "${RUSTUP_HOME:?}/tmp" || log "⚠️ Warning: Failed to remove temporary files in '$RUSTUP_HOME/tmp'."
        log "Temporary files in '$RUSTUP_HOME/tmp' removed."
    fi

    echo "🧼 Final cleanup completed."
    log "Final cleanup tasks completed."
}

# Export necessary functions for use by the controller
export -f log
export -f handle_error
export -f check_directory_writable
export -f install_rustup
export -f update_rustup_and_cargo
export -f cargo_install_or_update
export -f consolidate_cargo_directories
export -f install_cargo_tools
export -f manage_permissions
export -f validate_cargo_installation
export -f perform_final_cleanup
export -f optimize_cargo_service

# The controller script will call optimize_cargo_service as needed, so there is no need for direct invocation here.
