#!/bin/bash
# File: optimize_rust_tooling.sh
# Author: 4ndr0666
# Date: 2024-11-24
# Description: Optimizes Rust tooling environment in alignment with XDG Base Directory Specifications.

set -euo pipefail
IFS=$'\n\t'

# Define color codes for enhanced output
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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
        echo -e "${GREEN}✅ Directory $dir_path is writable.${NC}"
        log "Directory '$dir_path' is writable."
    else
        echo -e "${RED}❌ Error: Directory $dir_path is not writable.${NC}"
        log "ERROR: Directory '$dir_path' is not writable."
        exit 1
    fi
}

# Ensure XDG Base Directories are defined
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# Define Cargo directories based on XDG specifications
export CARGO_HOME="${XDG_DATA_HOME}/cargo"
export RUSTUP_HOME="${XDG_DATA_HOME}/rustup"

# Set default backup directory
BACKUP_DIR="/Nas/Backups"

# Function to optimize Rust tooling environment
optimize_rust_tooling_service() {
    echo -e "${CYAN}🔧 Starting Rust tooling environment optimization...${NC}"

    # Step 1: Ensure Rust is installed via rustup
    if command -v rustup &> /dev/null; then
        echo -e "${GREEN}✅ Rustup is already installed.${NC}"
        log "Rustup is already installed."
    else
        echo "📦 Rustup is not installed. Installing Rustup..."
        install_rustup
    fi

    # Step 2: Ensure essential Rust components are installed (cargo, clippy, rustfmt)
    echo "🔧 Ensuring essential Rust components are installed..."
    if rustup component add cargo clippy rustfmt; then
        echo -e "${GREEN}✅ Essential Rust components installed successfully.${NC}"
        log "Essential Rust components installed successfully."
    else
        handle_error "Failed to add Rust components."
    fi

    # Step 3: Install or update additional Rust tooling (cargo-audit, wasm32 target)
    echo "🔧 Ensuring additional Rust tooling is installed..."
    cargo_install_or_update "cargo-audit"
    if rustup target add wasm32-unknown-unknown; then
        echo -e "${GREEN}✅ wasm32-unknown-unknown target added successfully.${NC}"
        log "wasm32-unknown-unknown target added successfully."
    else
        handle_error "Failed to add wasm32 target."
    fi

    # Step 4: Set up environment variables for Rust and Cargo
    echo "🛠️ Setting up environment variables for Rust and Cargo..."
    export PATH="$CARGO_HOME/bin:$PATH"
    echo -e "${GREEN}✅ Environment variables set.${NC}"
    log "Environment variables for Rust and Cargo set."

    # Step 5: Check permissions for Cargo and Rust directories
    echo "🔐 Checking permissions for Cargo and Rust directories..."
    check_directory_writable "$CARGO_HOME"
    check_directory_writable "$RUSTUP_HOME"

    # Step 6: Clean up and consolidate Rust directories
    echo "🧹 Consolidating Rust directories..."
    consolidate_directories "$HOME/.cargo" "$CARGO_HOME"
    consolidate_directories "$HOME/.rustup" "$RUSTUP_HOME"
    remove_empty_directories "$HOME/.cargo" "$HOME/.rustup"

    # Step 7: Backup current Rust configuration (optional)
    echo "🗄️ Backing up Rust configuration..."
    backup_rust_configuration

    # Step 8: Testing and Verification
    echo "✅ Verifying Rust setup and tooling..."
    verify_rust_tooling_setup

    # Step 9: Final cleanup and summary
    echo "🧼 Performing final cleanup..."
    perform_final_cleanup

    echo -e "${GREEN}🎉 Rust tooling optimization complete.${NC}"
    echo -e "${CYAN}Cargo version:${NC} $(cargo --version)"
    echo -e "${CYAN}Rustup version:${NC} $(rustup --version)"
    echo -e "${CYAN}CARGO_HOME:${NC} $CARGO_HOME"
    echo -e "${CYAN}RUSTUP_HOME:${NC} $RUSTUP_HOME"
}

# Helper function to install Rustup
install_rustup() {
    echo "📦 Installing Rustup via the official installer..."
    if curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path; then
        echo -e "${GREEN}✅ Rustup installed successfully.${NC}"
        log "Rustup installed successfully."
    else
        handle_error "Failed to install Rustup."
    fi

    # Ensure environment variables are set
    export CARGO_HOME="${XDG_DATA_HOME}/cargo"
    export RUSTUP_HOME="${XDG_DATA_HOME}/rustup"

    # Source Rustup environment
    # shellcheck source=/dev/null
    if [ -s "$CARGO_HOME/env" ]; then
        source "$CARGO_HOME/env"
        echo -e "${GREEN}✅ Rustup environment sourced.${NC}"
        log "Rustup environment sourced."
    else
        handle_error "Failed to source Rustup environment."
    fi
}

# Helper function to install or update Cargo tools
cargo_install_or_update() {
    local tool_name="$1"
    if cargo install --list | grep -q "^$tool_name v"; then
        echo "🔄 Updating $tool_name..."
        if cargo install "$tool_name" --force; then
            echo -e "${GREEN}✅ $tool_name updated successfully.${NC}"
            log "$tool_name updated successfully."
        else
            echo -e "${YELLOW}⚠️ Warning: Failed to update $tool_name.${NC}"
            log "Warning: Failed to update $tool_name."
        fi
    else
        echo "📦 Installing $tool_name..."
        if cargo install "$tool_name"; then
            echo -e "${GREEN}✅ $tool_name installed successfully.${NC}"
            log "$tool_name installed successfully."
        else
            echo -e "${YELLOW}⚠️ Warning: Failed to install $tool_name.${NC}"
            log "Warning: Failed to install $tool_name."
        fi
    }
}

# Helper function to backup current Rust configuration
backup_rust_configuration() {
    # Ask the user if they want to perform the backup
    read -rp "Do you want to backup your Rust configuration to '$BACKUP_DIR'? (y/n): " backup_choice
    if [[ "$backup_choice" =~ ^[Yy]$ ]]; then
        echo "🗄️ Backing up Rust configuration to '$BACKUP_DIR'..."

        local timestamp
        timestamp=$(date +%Y%m%d_%H%M%S)
        local backup_path="$BACKUP_DIR/rust_backup_$timestamp"
        mkdir -p "$backup_path"

        if cp -r "$CARGO_HOME" "$backup_path/cargo/"; then
            echo -e "${GREEN}✅ Backed up CARGO_HOME to $backup_path/cargo/.${NC}"
            log "Backed up CARGO_HOME to $backup_path/cargo/."
        else
            echo -e "${YELLOW}⚠️ Warning: Could not copy $CARGO_HOME.${NC}"
            log "Warning: Could not copy $CARGO_HOME."
        fi

        if cp -r "$RUSTUP_HOME" "$backup_path/rustup/"; then
            echo -e "${GREEN}✅ Backed up RUSTUP_HOME to $backup_path/rustup/.${NC}"
            log "Backed up RUSTUP_HOME to $backup_path/rustup/."
        else
            echo -e "${YELLOW}⚠️ Warning: Could not copy $RUSTUP_HOME.${NC}"
            log "Warning: Could not copy $RUSTUP_HOME."
        fi

        echo -e "${GREEN}✅ Backup completed at '$backup_path'.${NC}"
        log "Backup completed at '$backup_path'."
    else
        echo -e "${YELLOW}⚠️ Skipping backup of Rust configuration.${NC}"
        log "User chose to skip backup of Rust configuration."
    fi
}

# Helper function to verify Rust tooling setup
verify_rust_tooling_setup() {
    echo "✅ Verifying Rust and Cargo setup..."

    # Check Rustup installation
    if command -v rustup &> /dev/null; then
        echo -e "${GREEN}✅ Rustup is installed and functioning correctly.${NC}"
        log "Rustup is installed and functioning correctly."
    else
        handle_error "Rustup is not functioning correctly. Please check your setup."
    fi

    # Check Cargo installation
    if command -v cargo &> /dev/null; then
        echo -e "${GREEN}✅ Cargo is installed: $(cargo --version).${NC}"
        log "Cargo is installed: $(cargo --version)."
    else
        handle_error "Cargo is not functioning correctly. Please check your setup."
    fi

    # Check cargo-audit installation
    if command -v cargo-audit &> /dev/null; then
        echo -e "${GREEN}✅ cargo-audit is installed: $(cargo audit --version).${NC}"
        log "cargo-audit is installed: $(cargo audit --version)."
    else
        handle_error "cargo-audit is not functioning correctly."
    fi
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

    echo -e "${GREEN}✅ Final cleanup completed.${NC}"
    log "Final cleanup tasks completed."
}

# Helper function to consolidate directories
consolidate_directories() {
    local source_dir="$1"
    local target_dir="$2"

    if [[ -d "$source_dir" ]]; then
        echo "🧹 Consolidating $source_dir to $target_dir..."
        rsync -av "$source_dir/" "$target_dir/" || echo -e "${YELLOW}⚠️ Warning: Failed to consolidate $source_dir to $target_dir.${NC}"
        rm -rf "$source_dir"
        echo -e "${GREEN}✅ Consolidated directories from $source_dir to $target_dir.${NC}"
        log "Consolidated directories from $source_dir to $target_dir."
    else
        echo -e "${YELLOW}⚠️ Source directory $source_dir does not exist. Skipping consolidation.${NC}"
    fi
}

# Helper function to remove empty directories
remove_empty_directories() {
    local dirs=("$@")
    for dir in "${dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            find "$dir" -type d -empty -delete
            echo "🗑️ Removed empty directories in $dir."
            log "Removed empty directories in $dir."
        else
            echo -e "${YELLOW}⚠️ Directory $dir does not exist. Skipping removal of empty directories.${NC}"
        fi
    done
}

# Export necessary functions for use by the controller
export -f log
export -f handle_error
export -f check_directory_writable
export -f install_rustup
export -f cargo_install_or_update
export -f backup_rust_configuration
export -f verify_rust_tooling_setup
export -f consolidate_directories
export -f remove_empty_directories
export -f perform_final_cleanup
export -f optimize_rust_tooling_service

# The controller script will call optimize_rust_tooling_service as needed, so there is no need for direct invocation here.
