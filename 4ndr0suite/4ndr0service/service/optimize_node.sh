#!/bin/bash

# --- Node.js Environment Optimization Script ---

# Ensure common_functions.sh is sourced
source "$(dirname "$(readlink -f "$0")")/../common_functions.sh" || handle_error "Failed to source 'common_functions.sh'."

# --- Function: optimize_node_service ---
# Purpose: Optimize Node.js and npm environment by installing necessary tools, managing versions, and configuring settings.
optimize_node_service() {
    log "Starting Node.js and npm environment optimization..."

    # Step 1: Check if Node.js is installed
    if ! command -v node &> /dev/null; then
        log "Node.js is not installed. Installing Node.js..."
        install_node
    else
        current_node_version=$(node -v)
        log "Node.js is already installed: $current_node_version"
    fi

    # Step 2: Check if NVM (Node Version Manager) is installed and manage Node.js versions
    manage_nvm_and_node_versions

    # Step 3 & 4: Ensure essential global npm packages and performance tools are installed
    ensure_global_npm_packages_installed

    # Step 5: Set up environment variables for Node.js, NPM, and NVM
    log "Setting up environment variables for Node.js and NVM..."
    export NVM_DIR="$HOME/.nvm"
    export PATH="$NVM_DIR/versions/node/$(node -v)/bin:$PATH"

    add_to_shell_config "NVM_DIR" "$NVM_DIR"
    add_to_shell_config "PATH" "$NVM_DIR/versions/node/$(node -v)/bin:$PATH"

    # Step 6: Configure npm cache and global directory for improved performance
    log "Configuring npm cache and global directory..."
    configure_npm_cache_and_global_directory

    # Step 7: Check permissions for global npm directory
    local npm_global_root
    npm_global_root=$(npm root -g) || handle_error "Failed to retrieve npm global root."
    check_directory_writable "$npm_global_root" || handle_error "Global npm directory is not writable."

    # Step 8: Clean up and consolidate Node.js directories
    log "Consolidating Node.js and npm directories..."
    consolidate_directories "$HOME/.npm" "$HOME/.local/npm"
    remove_empty_directories "$HOME/.npm"

    # Step 9: Backup current Node.js and npm configuration
    backup_node_configuration

    # Step 10: Final cleanup and summary
    log "Performing final cleanup..."
    log "Node.js and npm environment optimization complete."
    log "Node.js version: $(node -v)"
    log "npm version: $(npm -v)"
    log "NVM_DIR: $NVM_DIR"
}

# --- Helper Function: install_node ---
# Purpose: Install Node.js using the system's package manager.
install_node() {
    if command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm nodejs npm || handle_error "Failed to install Node.js with pacman."
    elif command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y nodejs npm || handle_error "Failed to install Node.js with apt-get."
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y nodejs || handle_error "Failed to install Node.js with dnf."
    elif command -v zypper &> /dev/null; then
        sudo zypper install -y nodejs || handle_error "Failed to install Node.js with zypper."
    else
        handle_error "Unsupported package manager. Please install Node.js manually."
    fi
    log "Node.js installed successfully."
}

# --- Helper Function: manage_nvm_and_node_versions ---
# Purpose: Install NVM if not present and manage Node.js versions using NVM.
manage_nvm_and_node_versions() {
    if command -v nvm &> /dev/null; then
        log "Managing Node.js versions via NVM..."
    else
        log "NVM is not installed. Installing NVM..."
        install_nvm
    fi

    # Ensure NVM is loaded
    export NVM_DIR="$HOME/.nvm"
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" || handle_error "Failed to source NVM script."

    # Install and use the latest LTS version
    log "Installing the latest LTS version of Node.js..."
    nvm install --lts || handle_error "Failed to install the latest LTS Node.js version."

    log "Using the latest LTS version of Node.js..."
    nvm use --lts || handle_error "Failed to switch to the latest LTS Node.js version."

    log "Setting the latest LTS version as the default..."
    nvm alias default 'lts/*' || handle_error "Failed to set default Node.js version."

    log "Node.js version managed via NVM."
}

# --- Helper Function: install_nvm ---
# Purpose: Install NVM (Node Version Manager) using curl or wget.
install_nvm() {
    log "Installing NVM..."
    if command -v curl &> /dev/null; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash || handle_error "Failed to install NVM using curl."
    elif command -v wget &> /dev/null; then
        wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash || handle_error "Failed to install NVM using wget."
    else
        handle_error "Neither curl nor wget is installed. Please install one to proceed."
    fi

    log "NVM installation script executed. It's recommended to review the script for security purposes."

    export NVM_DIR="$HOME/.nvm"
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" || handle_error "Failed to source NVM script."

    # Verify NVM installation
    if command -v nvm &> /dev/null; then
        log "NVM installed successfully."
    else
        handle_error "NVM installation failed."
    fi

    # Ensure the NVM configuration persists across sessions
    add_to_shell_config "NVM_DIR" "$NVM_DIR"
    add_to_shell_config "PATH" "$NVM_DIR/versions/node/$(node -v)/bin:$PATH"

    log "NVM installed and configured successfully."
}

# --- Helper Function: ensure_global_npm_packages_installed ---
# Purpose: Ensure essential global npm packages and performance tools are installed.
ensure_global_npm_packages_installed() {
    log "Ensuring essential global npm packages are installed..."
    ensure_global_npm_packages_installed_service
}

# --- Helper Function: ensure_global_npm_packages_installed_service ---
# Purpose: Install or update global npm packages in parallel.
ensure_global_npm_packages_installed_service() {
    log "Installing or updating global npm packages: npm-check-updates, yarn, nodemon, eslint, pm2, npx..."
    
    # List of essential global npm packages
    local packages=("npm-check-updates" "yarn" "nodemon" "eslint" "pm2" "npx")
    
    for package in "${packages[@]}"; do
        npm_global_install_or_update "$package" &
    done

    wait
    log "Essential global npm packages are installed and up to date."
}

# --- Helper Function: configure_npm_cache_and_global_directory ---
# Purpose: Configure npm cache and global directory for improved performance.
configure_npm_cache_and_global_directory() {
    log "Configuring npm cache directory..."
    npm config set cache "$HOME/.npm-cache" || handle_error "Failed to set npm cache directory."

    log "Configuring npm global prefix directory..."
    npm config set prefix "$HOME/.npm-global" || handle_error "Failed to set npm global prefix directory."

    # Update PATH
    export PATH="$HOME/.npm-global/bin:$PATH"
    add_to_shell_config "PATH" "$HOME/.npm-global/bin:$PATH"

    log "npm cache and global directory configured successfully."
}

# --- Helper Function: backup_node_configuration ---
# Purpose: Backup current Node.js and npm configuration directories.
backup_node_configuration() {
    log "Backing up Node.js and npm configuration..."

    local backup_dir="$HOME/.node_backup_$(date +%Y%m%d_%H%M%S)"
    create_directory_if_not_exists "$backup_dir" || handle_error "Failed to create backup directory '$backup_dir'."

    # Use rsync to preserve symbolic links and permissions
    if [[ -d "$NVM_DIR" ]]; then
        rsync -av "$NVM_DIR/" "$backup_dir/nvm/" || handle_error "Failed to backup NVM directory."
    fi

    local npm_prefix
    npm_prefix=$(npm config get prefix) || handle_error "Failed to get npm prefix."

    if [[ -d "$npm_prefix" ]]; then
        rsync -av "$npm_prefix/" "$backup_dir/npm_prefix/" || handle_error "Failed to backup npm prefix directory."
    fi

    if [[ -d "$HOME/.npm-cache" ]]; then
        rsync -av "$HOME/.npm-cache/" "$backup_dir/npm_cache/" || handle_error "Failed to backup npm cache directory."
    fi

    log "Backup completed: '$backup_dir'"
}

# Note: Ensure that this script is sourced by the controller or main script.
