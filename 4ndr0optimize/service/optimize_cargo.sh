#!/bin/bash

# Function to optimize Cargo and Rust environment
function optimize_cargo_service() {
    echo "Optimizing Cargo and Rust environment..."

    # Step 1: Check if Cargo is installed
    if ! command -v cargo &> /dev/null; then
        echo "Cargo is not installed. Installing Cargo via rustup..."
        install_cargo
    else
        current_cargo_version=$(cargo --version)
        echo "Cargo is already installed: $current_cargo_version"
    fi

    # Step 2: Manage Rust toolchains (stable, nightly, and custom)
    manage_rust_toolchains

    # Step 3: Ensure common Rust tools (clippy, rustfmt) are installed and up to date
    echo "Ensuring common Rust tools (clippy, rustfmt) are installed and up to date..."
    rustup component add clippy rustfmt

    # Step 4: Install or update additional Cargo tools (cargo-audit, cargo-outdated, cargo-bloat, cargo-flamegraph)
    echo "Ensuring additional Cargo tools are installed..."
    cargo_install_or_update "cargo-audit"
    cargo_install_or_update "cargo-outdated"
    cargo_install_or_update "cargo-bloat"
    cargo_install_or_update "cargo-flamegraph"

    # Step 5: Set up environment variables for Cargo and Rust (aligning with zenvironment file)
    echo "Setting up Cargo and Rust environment variables..."
    export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
    export CARGO_HOME="$XDG_DATA_HOME/cargo"
    export RUSTUP_HOME="$XDG_DATA_HOME/rustup"
    export PATH="$CARGO_HOME/bin:$PATH"

    add_to_zenvironment "CARGO_HOME" "$CARGO_HOME"
    add_to_zenvironment "RUSTUP_HOME" "$RUSTUP_HOME"
    add_to_zenvironment "PATH" "$CARGO_HOME/bin:$PATH"

    # Step 6: Check permissions for Cargo and Rust directories
    check_directory_writable "$CARGO_HOME"
    check_directory_writable "$RUSTUP_HOME"

    # Step 7: Set up cross-compilation targets and architectures (WASM, ARM, etc.)
    setup_cross_compilation

    # Step 8: Configure Cargo to use a pre-built binary cache (optional)
    configure_cargo_binary_cache

    # Step 9: Backup current Cargo and Rust configuration (optional)
    backup_cargo_configuration

    # Step 10: Clean up and consolidate Cargo directories
    echo "Consolidating Cargo directories..."
    consolidate_directories "$HOME/.cargo" "$CARGO_HOME"
    remove_empty_directories "$CARGO_HOME"

    # Step 11: Final cleanup and summary
    echo "Performing final cleanup..."
    echo "Cargo and Rust environment optimization complete."
    echo "Cargo version: $(cargo --version)"
    echo "Rustup version: $(rustup --version)"
    echo "CARGO_HOME: $CARGO_HOME"
    echo "RUSTUP_HOME: $RUSTUP_HOME"
}

# Helper function to install Cargo and Rust using rustup
install_cargo() {
    if command -v rustup &> /dev/null; then
        echo "rustup is already installed."
    else
        echo "Installing rustup (which includes Cargo and Rust)..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    fi
}

# Helper function to manage Rust toolchains (stable, nightly, custom)
manage_rust_toolchains() {
    if command -v rustup &> /dev/null; then
        echo "Managing Rust toolchains via rustup..."
        rustup update stable
        rustup default stable
        
        # Optionally install nightly or other toolchains
        echo "Installing nightly toolchain (optional)..."
        rustup install nightly
        rustup target add wasm32-unknown-unknown --toolchain nightly
    else
        echo "rustup is not installed. Installing now..."
        install_cargo
    fi
}

# Helper function to install or update Cargo tools
cargo_install_or_update() {
    local tool_name=$1
    echo "Installing or updating $tool_name..."
    cargo install "$tool_name" --force
}

# Helper function to set up cross-compilation targets (WASM, ARM, etc.)
setup_cross_compilation() {
    echo "Setting up cross-compilation targets..."
    
    # WASM target
    rustup target add wasm32-unknown-unknown

    # ARM target for cross-compilation (e.g., Raspberry Pi)
    rustup target add armv7-unknown-linux-gnueabihf
}

# Helper function to configure Cargo binary caching (optional)
configure_cargo_binary_cache() {
    echo "Configuring Cargo to use a binary cache..."
    
    # Example: Configure S3 or local cache for pre-built binaries
    # cargo install sccache
    # export CARGO_TARGET_DIR="$HOME/.cargo-cache"
}

# Helper function to backup current Cargo configuration
backup_cargo_configuration() {
    echo "Backing up Cargo and Rust configuration..."

    local backup_dir="$HOME/.cargo_backup_$(date +%Y%m%d)"
    mkdir -p "$backup_dir"
    cp -r "$CARGO_HOME" "$backup_dir"
    cp -r "$RUSTUP_HOME" "$backup_dir"

    echo "Backup completed: $backup_dir"
}

# The controller script will call optimize_cargo_service as needed, so there is no need for direct invocation in this file.
