#!/bin/bash

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
    rustup component add cargo clippy rustfmt

    # Step 3: Install or update additional Rust tooling (cargo-audit, wasm32 target)
    echo "Ensuring additional Rust tooling is installed..."
    cargo_install_or_update "cargo-audit"
    rustup target add wasm32-unknown-unknown

    # Step 4: Set up environment variables for Rust and Cargo
    echo "Setting up environment variables for Rust and Cargo..."
    export CARGO_HOME="$XDG_DATA_HOME/cargo"
    export RUSTUP_HOME="$XDG_DATA_HOME/rustup"
    export PATH="$CARGO_HOME/bin:$PATH"

    add_to_zenvironment "CARGO_HOME" "$CARGO_HOME"
    add_to_zenvironment "RUSTUP_HOME" "$RUSTUP_HOME"
    add_to_zenvironment "PATH" "$CARGO_HOME/bin:$PATH"

    # Step 5: Check permissions for Cargo and Rust directories
    check_directory_writable "$CARGO_HOME"
    check_directory_writable "$RUSTUP_HOME"

    # Step 6: Clean up and consolidate Rust directories
    echo "Consolidating Rust directories..."
    consolidate_directories "$HOME/.cargo" "$CARGO_HOME"
    consolidate_directories "$HOME/.rustup" "$RUSTUP_HOME"
    remove_empty_directories "$HOME/.cargo" "$HOME/.rustup"

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
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    export CARGO_HOME="$XDG_DATA_HOME/cargo"
    export RUSTUP_HOME="$XDG_DATA_HOME/rustup"
    [ -s "$CARGO_HOME/bin/cargo" ] && \. "$CARGO_HOME/env"
}

# Helper function to install or update Cargo tools
cargo_install_or_update() {
    local tool_name=$1
    if cargo install --list | grep "$tool_name" &> /dev/null; then
        echo "Updating $tool_name..."
        cargo install "$tool_name" --force
    else
        echo "Installing $tool_name..."
        cargo install "$tool_name"
    fi
}

# Helper function to backup current Rust configuration
backup_rust_configuration() {
    echo "Backing up Rust configuration..."

    local backup_dir="$HOME/.rust_backup_$(date +%Y%m%d)"
    mkdir -p "$backup_dir"
    cp -r "$CARGO_HOME" "$backup_dir"
    cp -r "$RUSTUP_HOME" "$backup_dir"

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
}

# The controller script will call optimize_rust_tooling_service as needed, so there is no need for direct invocation in this file.
