#!/bin/bash
# File: optimize_node.sh
# Author: 4ndr0666
# Edited: 11-24-24
# Description: Optimizes Node.js and npm environment in alignment with XDG Base Directory Specifications.

# --- Node.js Environment Optimization Script ---

# --- Function: optimize_node_service ---
# Purpose: Optimize Node.js and npm environment by installing necessary tools, managing versions, and configuring settings.
function optimize_node_service() {
    echo "Starting Node.js and npm environment optimization..."

    # Step 1: Check if Node.js is installed
    if ! command -v node &> /dev/null; then
        echo "Node.js is not installed. Installing Node.js..."
        install_node
    else
        current_node_version=$(node -v)
        echo "Node.js is already installed: $current_node_version"
    fi

    # Step 2: Check if NVM (Node Version Manager) is installed and manage Node.js versions
    manage_nvm_and_node_versions

    # Step 3 & 4: Ensure essential global npm packages and performance tools are installed
    ensure_global_npm_packages_installed

    # Step 5: Set up environment variables for Node.js, NPM, and NVM
    echo "Setting up environment variables for Node.js and NVM..."
    export NVM_DIR="$XDG_CONFIG_HOME/nvm"
    export PATH="$NVM_DIR/versions/node/$(node -v)/bin:$PATH"

    # Environment variables are already set in .zprofile, so no need to modify them here.

    # Step 6: Configure npm cache and global directory for improved performance
    echo "Configuring npm cache and global directory..."
    configure_npm_cache_and_global_directory

    # Step 7: Check permissions for global npm directory
    local npm_global_root
    npm_global_root=$(npm root -g) || handle_error "Failed to retrieve npm global root."
    check_directory_writable "$npm_global_root" || handle_error "Global npm directory is not writable."

    # Step 8: Clean up and consolidate Node.js directories
    echo "Consolidating Node.js and npm directories..."
    consolidate_directories "$HOME/.npm" "$HOME/.local/npm"
    remove_empty_directories "$HOME/.npm"

    # Step 9: Backup current Node.js and npm configuration
    backup_node_configuration

    # Step 10: Final cleanup and summary
    echo "Performing final cleanup..."
    echo "Node.js and npm environment optimization complete."
    echo "Node.js version: $(node -v)"
    echo "npm version: $(npm -v)"
    echo "NVM_DIR: $NVM_DIR"
}

# --- Helper Function: install_node ---
# Purpose: Install Node.js using the system's package manager.
install_node() {
    if command -v pacman &> /dev/null; then
        echo "Installing Node.js using pacman..."
        sudo pacman -S --noconfirm nodejs npm || handle_error "Failed to install Node.js with pacman."
    elif command -v apt-get &> /dev/null; then
        echo "Installing Node.js using apt-get..."
        sudo apt-get update && sudo apt-get install -y nodejs npm || handle_error "Failed to install Node.js with apt-get."
    elif command -v dnf &> /dev/null; then
        echo "Installing Node.js using dnf..."
        sudo dnf install -y nodejs npm || handle_error "Failed to install Node.js with dnf."
    elif command -v zypper &> /dev/null; then
        echo "Installing Node.js using zypper..."
        sudo zypper install -y nodejs npm || handle_error "Failed to install Node.js with zypper."
    else
        echo "Error: Unsupported package manager. Please install Node.js manually."
        exit 1
    fi
    echo "Node.js installed successfully."
}

# --- Helper Function: manage_nvm_and_node_versions ---
# Purpose: Install NVM if not present and manage Node.js versions using NVM.
manage_nvm_and_node_versions() {
    if command -v nvm &> /dev/null; then
        echo "Managing Node.js versions via NVM..."
    else
        echo "NVM is not installed. Installing NVM..."
        install_nvm
    fi

    # Ensure NVM is loaded
    export NVM_DIR="$XDG_CONFIG_HOME/nvm"
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" || handle_error "Failed to source NVM script."

    # Install and use the latest LTS version
    echo "Installing the latest LTS version of Node.js..."
    nvm install --lts || handle_error "Failed to install the latest LTS Node.js version."

    echo "Using the latest LTS version of Node.js..."
    nvm use --lts || handle_error "Failed to switch to the latest LTS Node.js version."

    echo "Setting the latest LTS version as the default..."
    nvm alias default 'lts/*' || handle_error "Failed to set default Node.js version."

    echo "Node.js version managed via NVM."
}

# --- Helper Function: install_nvm ---
# Purpose: Install NVM (Node Version Manager) using curl or wget.
install_nvm() {
    echo "Installing NVM..."
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

    # Environment variables are already set in .zprofile, so no need to modify them here.
    echo "NVM installed and configured successfully."
}

# --- Helper Function: ensure_global_npm_packages_installed ---
# Purpose: Ensure essential global npm packages and performance tools are installed.
ensure_global_npm_packages_installed() {
    echo "Ensuring essential global npm packages are installed..."
    ensure_global_npm_packages_installed_service
}

# --- Helper Function: ensure_global_npm_packages_installed_service ---
# Purpose: Install or update global npm packages in parallel.
ensure_global_npm_packages_installed_service() {
    echo "Installing or updating global npm packages: npm-check-updates, yarn, nodemon, eslint, pm2, npx..."

    # List of essential global npm packages
    local packages=("npm-check-updates" "yarn" "nodemon" "eslint" "pm2" "npx")

    for package in "${packages[@]}"; do
        npm_global_install_or_update "$package" &
    done

    wait
    echo "Essential global npm packages are installed and up to date."
}

# --- Helper Function: configure_npm_cache_and_global_directory ---
# Purpose: Configure npm cache and global directory for improved performance.
configure_npm_cache_and_global_directory() {
    echo "Configuring npm cache directory..."
    npm config set cache "$XDG_CACHE_HOME/npm-cache" || handle_error "Failed to set npm cache directory."

    echo "Configuring npm global prefix directory..."
    npm config set prefix "$XDG_DATA_HOME/npm-global" || handle_error "Failed to set npm global prefix directory."

    # Update PATH
    export PATH="$XDG_DATA_HOME/npm-global/bin:$PATH"
    # Environment variables are already set in .zprofile, so no need to modify them here.

    echo "npm cache and global directory configured successfully."
}

# --- Helper Function: backup_node_configuration ---
# Purpose: Backup current Node.js and npm configuration directories.
backup_node_configuration() {
    echo "Backing up Node.js and npm configuration..."

    local backup_dir="$XDG_STATE_HOME/backups/node_backup_$(date +%Y%m%d)"
    mkdir -p "$backup_dir"
    rsync -av "$NVM_DIR/" "$backup_dir/nvm/" 2>/dev/null || echo "Warning: Could not copy $NVM_DIR"
    rsync -av "$XDG_DATA_HOME/npm-global/" "$backup_dir/npm-global/" 2>/dev/null || echo "Warning: Could not copy npm-global"
    rsync -av "$XDG_CACHE_HOME/npm-cache/" "$backup_dir/npm-cache/" 2>/dev/null || echo "Warning: Could not copy npm-cache"

    echo "Backup completed: $backup_dir"
}

# --- Helper Function: handle_error ---
# Purpose: Handle errors by displaying a message and exiting.
handle_error() {
    echo "Error: $1" >&2
    exit 1
}

# --- Helper Function: check_directory_writable ---
# Purpose: Check if a directory is writable.
check_directory_writable() {
    local dir_path=$1

    if [ -w "$dir_path" ]; then
        echo "Directory $dir_path is writable."
    else
        echo "Error: Directory $dir_path is not writable."
        exit 1
    fi
}

# --- Helper Function: consolidate_directories ---
# Purpose: Consolidate contents from source directory to target directory.
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

# --- Helper Function: remove_empty_directories ---
# Purpose: Remove empty directories.
remove_empty_directories() {
    local dir_path=$1

    find "$dir_path" -type d -empty -delete
    echo "Removed empty directories in $dir_path."
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
