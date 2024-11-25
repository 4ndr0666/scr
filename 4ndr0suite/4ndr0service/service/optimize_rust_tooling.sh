#!/bin/bash

# File: optimize_rust_tooling.sh
# Author: 4ndr0666
# Edited: 10-20-24
# Description: Optimizes Rust tooling environment in alignment with XDG Base Directory Specifications.

# Function to optimize Rust tooling environment
function optimize_rust_tooling_service() {
    echo "Optimizing Rust tooling environment..."

    # Step 1: Ensure Rust is installed via rustup
    if command -v rustup &> /dev/null; then
        echo "Rustup is already installed."
    else
        echo "Rustup is not installed. Installing Rustup..."
        install_rustup
    fi

    # Step 2: Ensure essential Rust components are installed (cargo, clippy, rustfmt)
    echo "Ensuring essential Rust components are installed..."
    rustup component add cargo clippy rustfmt || handle_error "Failed to add Rust components."

    # Step 3: Install or update additional Rust tooling (cargo-audit, wasm32 target)
    echo "Ensuring additional Rust tooling is installed..."
    cargo_install_or_update "cargo-audit"
    rustup target add wasm32-unknown-unknown || handle_error "Failed to add wasm32 target."

    # Step 4: Set up environment variables for Rust and Cargo
    echo "Setting up environment variables for Rust and Cargo..."
    export CARGO_HOME="$XDG_DATA_HOME/cargo"
    export RUSTUP_HOME="$XDG_DATA_HOME/rustup"
    export PATH="$CARGO_HOME/bin:$PATH"

    # Environment variables are already set in .zprofile, so no need to modify them here.

    # Step 5: Check permissions for Cargo and Rust directories
    check_directory_writable "$CARGO_HOME"
    check_directory_writable "$RUSTUP_HOME"

    # Step 6: Clean up and consolidate Rust directories
    echo "Consolidating Rust directories..."
    consolidate_directories "$XDG_DATA_HOME/cargo" "$CARGO_HOME"
    consolidate_directories "$XDG_DATA_HOME/rustup" "$RUSTUP_HOME"
    remove_empty_directories "$XDG_DATA_HOME/cargo" "$XDG_DATA_HOME/rustup"

    # Step 7: Backup current Rust configuration (optional)
    backup_rust_configuration

    # Step 8: Testing and Verification
    echo "Verifying Rust setup and tooling..."
    verify_rust_tooling_setup

    # Step 9: Final cleanup and summary
    echo "Performing final cleanup..."
    echo "Rust tooling optimization complete."
    echo "Cargo version: $(cargo --version)"
    echo "Rustup version: $(rustup --version)"
    echo "CARGO_HOME: $CARGO_HOME"
    echo "RUSTUP_HOME: $RUSTUP_HOME"
}

# Helper function to install Rustup
install_rustup() {
    echo "Installing Rustup via the official installer..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y || handle_error "Failed to install Rustup."

    export CARGO_HOME="$XDG_DATA_HOME/cargo"
    export RUSTUP_HOME="$XDG_DATA_HOME/rustup"
    [ -s "$CARGO_HOME/env" ] && source "$CARGO_HOME/env" || handle_error "Failed to source Rustup environment."
}

# Helper function to install or update Cargo tools
cargo_install_or_update() {
    local tool_name=$1
    if cargo install --list | grep "$tool_name" &> /dev/null; then
        echo "Updating $tool_name..."
        cargo install "$tool_name" --force || echo "Warning: Failed to update $tool_name."
    else
        echo "Installing $tool_name..."
        cargo install "$tool_name" || echo "Warning: Failed to install $tool_name."
    fi
}

# Helper function to backup current Rust configuration
backup_rust_configuration() {
    echo "Backing up Rust configuration..."

    local backup_dir="$XDG_STATE_HOME/backups/rust_backup_$(date +%Y%m%d)"
    mkdir -p "$backup_dir"
    cp -r "$CARGO_HOME" "$backup_dir/cargo/" || echo "Warning: Could not copy $CARGO_HOME"
    cp -r "$RUSTUP_HOME" "$backup_dir/rustup/" || echo "Warning: Could not copy $RUSTUP_HOME"

    echo "Backup completed: $backup_dir"
}

# Helper function to verify Rust tooling setup
verify_rust_tooling_setup() {
    echo "Verifying Rust and Cargo setup..."

    # Check Rustup installation
    if command -v rustup &> /dev/null; then
        echo "Rustup is installed and functioning correctly."
    else
        echo "Error: Rustup is not functioning correctly. Please check your setup."
        exit 1
    fi

    # Check Cargo installation
    if command -v cargo &> /dev/null; then
        echo "Cargo is installed: $(cargo --version)"
    else
        echo "Error: Cargo is not functioning correctly. Please check your setup."
        exit 1
    fi

    # Check cargo-audit installation
    if cargo audit --version &> /dev/null; then
        echo "cargo-audit is installed: $(cargo audit --version)"
    else
        echo "Error: cargo-audit is not functioning correctly."
        exit 1
    fi
}

# Helper function: Handle errors
handle_error() {
    echo "Error: $1" >&2
    exit 1
}

# Helper function: Check if a directory is writable
check_directory_writable() {
    local dir_path=$1

    if [ -w "$dir_path" ]; then
        echo "Directory $dir_path is writable."
    else
        echo "Error: Directory $dir_path is not writable."
        exit 1
    fi
}

# Helper function: Consolidate contents from source to target directory
consolidate_directories() {
    local source_dir=$1
    local target_dir=$2

    if [ -d "$source_dir" ]; then
        rsync -av "$source_dir/" "$target_dir/" || echo "Warning: Failed to consolidate $source_dir to $target_dir."
        echo "Consolidated directories from $source_dir to $target_dir."
    else
        echo "Source directory $source_dir does not exist. Skipping consolidation."
    fi
}

# Helper function: Remove empty directories
remove_empty_directories() {
    local dirs=("$@")
    for dir in "${dirs[@]}"; do
        find "$dir" -type d -empty -delete
        echo "Removed empty directories in $dir."
    done
}
