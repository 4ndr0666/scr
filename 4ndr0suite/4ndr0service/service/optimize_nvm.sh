#!/bin/bash

# File: optimize_nvm.sh
# Author: 4ndr0666
# Edited: 10-20-24
# Description: Optimizes NVM (Node Version Manager) and Node.js environment in alignment with XDG Base Directory Specifications.

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

    # Step 3 & 4: Ensure essential global npm packages are installed (npm-check-updates, yarn, nodemon)
    echo "Ensuring essential global npm packages are installed..."
    nvm use --lts
    npm_global_install_or_update "npm-check-updates"
    npm_global_install_or_update "yarn"
    npm_global_install_or_update "nodemon"

    # Step 4: Set up environment variables for NVM and Node.js
    echo "Setting up NVM environment variables..."
    export NVM_DIR="$XDG_CONFIG_HOME/nvm"

    # Check if default Node version exists, otherwise use current version
    if nvm version default &> /dev/null; then
        NODE_VERSION=$(nvm version default)
    else
        NODE_VERSION=$(nvm current)
    fi

    export PATH="$NVM_DIR/versions/node/$NODE_VERSION/bin:$PATH"

    # Environment variables are already set in .zprofile, so no need to modify them here.

    # Step 5: Check permissions for NVM directory and global npm directory
    check_directory_writable "$NVM_DIR"
    check_directory_writable "$(npm root -g)"

    # Step 6: Clean up and consolidate NVM directories
    echo "Consolidating NVM directories..."
    consolidate_directories "$XDG_CONFIG_HOME/nvm" "$NVM_DIR"
    remove_empty_directories "$XDG_CONFIG_HOME/nvm"

    # Step 7: Backup current NVM configuration (optional)
    backup_nvm_configuration

    # Step 8: Testing and Verification
    echo "Verifying NVM installation and Node.js versions..."
    verify_nvm_setup

    # Step 9: Final cleanup and summary
    echo "Performing final cleanup..."
    echo "NVM and Node.js environment optimization complete."
    echo "NVM version: $(nvm --version)"
    echo "Node.js version: $(node -v)"
    echo "NVM_DIR: $NVM_DIR"
}

# --- Helper Function: install_nvm ---
# Purpose: Install NVM (Node Version Manager) using curl or wget.
install_nvm() {
    echo "Installing NVM via the official NVM script..."
    if command -v curl &> /dev/null; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash || handle_error "Failed to install NVM using curl."
    elif command -v wget &> /dev/null; then
        wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash || handle_error "Failed to install NVM using wget."
    else
        handle_error "Neither curl nor wget is installed. Please install one to proceed."
    fi

    echo "NVM installation script executed. It's recommended to review the script for security purposes."

    export NVM_DIR="$XDG_CONFIG_HOME/nvm"
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" || handle_error "Failed to source NVM script."

    # Verify NVM installation
    if command -v nvm &> /dev/null; then
        echo "NVM installed successfully."
    else
        handle_error "NVM installation failed."
    fi

    echo "NVM installed and configured successfully."
}

# --- Helper Function: manage_node_versions_via_nvm ---
# Purpose: Install and manage Node.js versions using NVM.
manage_node_versions_via_nvm() {
    echo "Managing Node.js versions via NVM..."

    # Install and use the latest LTS version as default
    nvm install --lts || handle_error "Failed to install the latest LTS Node.js version."
    nvm alias default 'lts/*' || handle_error "Failed to set default Node.js version."
    nvm use default || handle_error "Failed to switch to the latest LTS Node.js version."

    # Optional: Install additional Node.js versions if needed
    echo "Do you need to install any additional Node.js versions? (y/N)"
    read -r additional_node_versions
    if [[ "$additional_node_versions" == "y" || "$additional_node_versions" == "Y" ]]; then
        echo "Please specify the Node.js version(s) to install (e.g., 12.18.3 or 14.15.0):"
        read -r node_version
        nvm install "$node_version" || handle_error "Failed to install Node.js version $node_version."
        echo "Switching to Node.js version $node_version..."
        nvm use "$node_version" || handle_error "Failed to switch to Node.js version $node_version."
    else
        echo "No additional Node.js versions were requested."
    fi
}

# --- Helper Function: npm_global_install_or_update ---
# Purpose: Install or update a global npm package.
npm_global_install_or_update() {
    local package_name=$1

    if npm ls -g "$package_name" --depth=0 &> /dev/null; then
        echo "Updating $package_name..."
        npm update -g "$package_name" || echo "Warning: Failed to update $package_name."
    else
        echo "Installing $package_name globally..."
        npm install -g "$package_name" || echo "Warning: Failed to install $package_name."
    fi
}

# --- Helper Function: backup_nvm_configuration ---
# Purpose: Backup current NVM and npm configuration.
backup_nvm_configuration() {
    echo "Backing up NVM and npm configuration..."

    local backup_dir="$XDG_STATE_HOME/backups/nvm_backup_$(date +%Y%m%d)"
    mkdir -p "$backup_dir"

    if [[ -d "$NVM_DIR" ]]; then
        cp -r "$NVM_DIR" "$backup_dir/nvm/" || echo "Warning: Could not copy $NVM_DIR"
    fi

    local npm_prefix
    npm_prefix=$(npm config get prefix) || handle_error "Failed to get npm prefix."

    if [[ -d "$npm_prefix" ]]; then
        cp -r "$npm_prefix" "$backup_dir/npm_prefix/" || echo "Warning: Could not copy npm prefix directory."
    fi

    if [[ -d "$XDG_CACHE_HOME/npm-cache" ]]; then
        cp -r "$XDG_CACHE_HOME/npm-cache" "$backup_dir/npm_cache/" || echo "Warning: Could not copy npm cache directory."
    fi

    echo "Backup completed: $backup_dir"
}

# --- Helper Function: verify_nvm_setup ---
# Purpose: Verify that NVM and Node.js are functioning correctly.
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
    if npm ls -g npm-check-updates --depth=0 &> /dev/null && \
       npm ls -g yarn --depth=0 &> /dev/null && \
       npm ls -g nodemon --depth=0 &> /dev/null; then
        echo "Global npm packages are installed and functioning correctly."
    else
        echo "Error: Some global npm packages are missing or not functioning correctly."
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

# The controller script will call optimize_nvm_service as needed, so there is no need for direct invocation in this file.
