#!/bin/bash

# Function to optimize Node.js environment
function optimize_node_service() {
    echo "Optimizing Node.js and npm environment..."

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

    # Step 3: Ensure essential global npm packages are installed (npm-check-updates, yarn, nodemon, eslint)
    echo "Ensuring essential global npm packages are installed..."
    npm_global_install_or_update "npm-check-updates"
    npm_global_install_or_update "yarn"
    npm_global_install_or_update "nodemon"
    npm_global_install_or_update "eslint"

    # Step 4: Install performance tools (pm2, npx)
    echo "Ensuring performance tools (pm2, npx) are installed..."
    npm_global_install_or_update "pm2"
    npm_global_install_or_update "npx"

    # Step 5: Set up environment variables for Node.js, NPM, and NVM
    echo "Setting up environment variables for Node.js and NVM..."
    export NVM_DIR="$HOME/.nvm"
    export PATH="$NVM_DIR/versions/node/$(node -v)/bin:$PATH"

    add_to_zenvironment "NVM_DIR" "$NVM_DIR"
    add_to_zenvironment "PATH" "$NVM_DIR/versions/node/$(node -v)/bin:$PATH"

    # Step 6: Configure npm cache and global directory for improved performance
    configure_npm_cache_and_global_directory

    # Step 7: Check permissions for global npm directory
    check_directory_writable "$(npm root -g)"

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

# Helper function to install Node.js using system package managers or NVM
install_node() {
    if command -v pacman &> /dev/null; then
        sudo pacman -S nodejs npm
    elif command -v apt-get &> /dev/null; then
        sudo apt-get install -y nodejs npm
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y nodejs
    elif command -v zypper &> /dev/null; then
        sudo zypper install -y nodejs
    else
        echo "Unsupported package manager. Please install Node.js manually."
        exit 1
    fi
}

# Helper function to manage Node.js versions using NVM
manage_nvm_and_node_versions() {
    if command -v nvm &> /dev/null; then
        echo "Managing Node.js versions via NVM..."
        nvm install --lts
        nvm use --lts
        nvm alias default lts/*
    else
        echo "NVM is not installed. Installing NVM..."
        install_nvm
        nvm install --lts
        nvm use --lts
        nvm alias default lts/*
    fi
}

# Helper function to install NVM (Node Version Manager)
install_nvm() {
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    # Ensure the NVM configuration persists across sessions
    if [[ "$SHELL" == *"zsh"* ]]; then
        echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.zshrc
        echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.zshrc
    elif [[ "$SHELL" == *"bash"* ]]; then
        echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.bashrc
        echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.bashrc
    fi
}

# Helper function to globally install or update an npm package
npm_global_install_or_update() {
    local package_name=$1

    if npm ls -g "$package_name" --depth=0 &> /dev/null; then
        echo "Updating $package_name..."
        npm update -g "$package_name"
    else
        echo "Installing $package_name globally..."
        npm install -g "$package_name"
    fi
}

# Helper function to configure npm cache and global directory
configure_npm_cache_and_global_directory() {
    echo "Configuring npm cache for improved performance..."
    npm config set cache "$HOME/.npm-cache"
    
    # Aligning npm global prefix with the zenvironment configuration
    npm config set prefix "$HOME/.npm-global"

    add_to_zenvironment "NPM_CONFIG_CACHE" "$HOME/.npm-cache"
    add_to_zenvironment "NPM_CONFIG_PREFIX" "$HOME/.npm-global"
    export PATH="$HOME/.npm-global/bin:$PATH"
    add_to_zenvironment "PATH" "$HOME/.npm-global/bin:$PATH"
}

# Helper function to backup current Node.js and npm configuration
backup_node_configuration() {
    echo "Backing up Node.js and npm configuration..."

    local backup_dir="$HOME/.node_backup_$(date +%Y%m%d)"
    mkdir -p "$backup_dir"

    if [[ -d "$NVM_DIR" ]]; then
        cp -r "$NVM_DIR" "$backup_dir"
    fi

    if [[ -d "$(npm config get prefix)" ]]; then
        cp -r "$(npm config get prefix)" "$backup_dir"
    fi

    if [[ -d "$HOME/.npm-cache" ]]; then
        cp -r "$HOME/.npm-cache" "$backup_dir"
    fi

    echo "Backup completed: $backup_dir"
}

# The controller script will call optimize_node_service as needed, so there is no need for direct invocation in this file.
