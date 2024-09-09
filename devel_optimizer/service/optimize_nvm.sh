#!/bin/bash

# Function to optimize NVM and Node.js environment
function optimize_nvm_service() {
    echo "Optimizing NVM (Node Version Manager) and Node.js environment..."

    # Step 1: Check if NVM is installed
    if command -v nvm &> /dev/null; then
        echo "NVM is already installed."
    else
        echo "NVM is not installed. Installing NVM..."
        install_nvm
    fi

    # Step 2: Manage Node.js versions using NVM
    manage_node_versions_via_nvm

    # Step 3: Ensure essential global npm packages are installed (npm-check-updates, yarn, nodemon)
    echo "Ensuring essential global npm packages are installed..."
    nvm use --lts
    npm_global_install_or_update "npm-check-updates"
    npm_global_install_or_update "yarn"
    npm_global_install_or_update "nodemon"

    # Step 4: Set up environment variables for NVM and Node.js
    echo "Setting up NVM environment variables..."
    export NVM_DIR="$HOME/.config/nvm"
    export PATH="$NVM_DIR/versions/node/$(nvm version default)/bin:$PATH"

    add_to_zenvironment "NVM_DIR" "$NVM_DIR"
    add_to_zenvironment "PATH" "$NVM_DIR/versions/node/$(nvm version default)/bin:$PATH"

    # Step 5: Source NVM and bash completion scripts as defined in zenvironment
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        source "$NVM_DIR/nvm.sh"
    else
        echo "Warning: NVM script not found at $NVM_DIR/nvm.sh"
    fi

    if [ -s "$NVM_DIR/bash_completion" ]; then
        source "$NVM_DIR/bash_completion"
    else
        echo "Warning: NVM bash completion script not found at $NVM_DIR/bash_completion"
    fi

    # Step 6: Check permissions for NVM directory and global npm directory
    check_directory_writable "$NVM_DIR"
    check_directory_writable "$(npm root -g)"

    # Step 7: Clean up and consolidate NVM directories
    echo "Consolidating NVM directories..."
    consolidate_directories "$HOME/.config/nvm" "$NVM_DIR"
    remove_empty_directories "$HOME/.config/nvm"

    # Step 8: Backup current NVM configuration (optional)
    backup_nvm_configuration

    # Step 9: Testing and Verification
    echo "Verifying NVM installation and Node.js versions..."
    verify_nvm_setup

    # Step 10: Final cleanup and summary
    echo "Performing final cleanup..."
    echo "NVM and Node.js environment optimization complete."
    echo "NVM version: $(nvm --version)"
    echo "Node.js version: $(node -v)"
    echo "NVM_DIR: $NVM_DIR"
}

# Helper function to install NVM
install_nvm() {
    echo "Installing NVM via the official NVM script..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
    export NVM_DIR="$HOME/.config/nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
}

# Helper function to manage Node.js versions using NVM
manage_node_versions_via_nvm() {
    echo "Managing Node.js versions via NVM..."

    # Install and use the latest LTS version as default
    nvm install --lts
    nvm alias default lts/*
    nvm use default

    # Optional: Install additional Node.js versions if needed
    echo "Do you need to install any additional Node.js versions? (y/N)"
    read additional_node_versions
    if [[ "$additional_node_versions" == "y" || "$additional_node_versions" == "Y" ]]; then
        echo "Please specify the Node.js version(s) to install (e.g., 12.18.3 or 14.15.0):"
        read node_version
        nvm install "$node_version"
        echo "Switching to Node.js version $node_version..."
        nvm use "$node_version"
    else
        echo "No additional Node.js versions were requested."
    fi
}

# Helper function to globally install or update an npm package
npm_global_install_or_update() {
    local package_name=$1

    if npm list -g "$package_name" &> /dev/null; then
        echo "Updating $package_name..."
        npm update -g "$package_name"
    else
        echo "Installing $package_name globally..."
        npm install -g "$package_name"
    fi
}

# Helper function to backup current NVM configuration
backup_nvm_configuration() {
    echo "Backing up NVM configuration..."

    local backup_dir="$HOME/.nvm_backup_$(date +%Y%m%d)"
    mkdir -p "$backup_dir"
    cp -r "$NVM_DIR" "$backup_dir"
    cp -r "$(npm config get prefix)" "$backup_dir"

    echo "Backup completed: $backup_dir"
}

# Helper function to verify NVM setup and Node.js functionality
verify_nvm_setup() {
    echo "Verifying NVM and Node.js versions..."

    # Check NVM installation
    if command -v nvm &> /dev/null; then
        echo "NVM is installed and functioning correctly."
    else
        echo "Error: NVM is not functioning correctly. Please check your setup."
        exit 1
    fi

    # Check Node.js version
    if command -v node &> /dev/null; then
        echo "Node.js is installed: $(node -v)"
    else
        echo "Error: Node.js is not functioning correctly. Please check your setup."
        exit 1
    fi

    # Verify global npm packages
    if npm list -g npm-check-updates &> /dev/null && npm list -g yarn &> /dev/null && npm list -g nodemon &> /dev/null; then
        echo "Global npm packages are installed and functioning correctly."
    else
        echo "Error: Some global npm packages are missing or not functioning correctly."
        exit 1
    fi
}

# The controller script will call optimize_nvm_service as needed, so there is no need for direct invocation in this file.
