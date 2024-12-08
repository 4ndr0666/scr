#!/bin/bash
# File: optimize_nvm.sh
# Author: 4ndr0666
# Date: 2024-11-24
# Description: Optimizes NVM (Node Version Manager) and Node.js environment in alignment with XDG Base Directory Specifications.

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

# Define Node.js directories based on XDG specifications at the beginning
export NODE_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/node"
export NODE_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/node"

# Function to install NVM
install_nvm() {
    echo "📦 Installing NVM..."
    if command -v curl &> /dev/null; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | bash || handle_error "Failed to install NVM using curl."
    elif command -v wget &> /dev/null; then
        wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | bash || handle_error "Failed to install NVM using wget."
    else
        handle_error "Neither curl nor wget is installed. Please install one to proceed."
    fi

    # Set NVM_DIR according to XDG specifications
    export NVM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvm"
    mkdir -p "$NVM_DIR"

    # Move default NVM directory to XDG_CONFIG_HOME
    if [[ -d "$HOME/.nvm" && "$HOME/.nvm" != "$NVM_DIR" ]]; then
        mv "$HOME/.nvm" "$NVM_DIR" || handle_error "Failed to move .nvm to $NVM_DIR."
    fi

    # Temporarily disable 'set -u' before sourcing nvm.sh
    set +u
    # Load NVM
    export NVM_DIR
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" || handle_error "Failed to source NVM script."
    # Re-enable 'set -u'
    set -u

    # Verify NVM installation
    if command -v nvm &> /dev/null; then
        echo "✅ NVM installed successfully."
        log "NVM installed successfully."
    else
        handle_error "NVM installation failed."
    fi
}

# Function to install or update Node.js using NVM
install_or_update_node() {
    echo "📦 Installing or updating Node.js using NVM..."
    # Temporarily disable 'set -u' before sourcing nvm.sh
    set +u
    # Load NVM
    export NVM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvm"
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" || handle_error "Failed to source NVM script."
    # Re-enable 'set -u'
    set -u

    # Install latest LTS version of Node.js
    echo "🔄 Installing latest LTS version of Node.js..."
    if nvm install --lts; then
        echo "✅ Latest LTS version of Node.js installed successfully."
        log "Latest LTS version of Node.js installed successfully."
    else
        echo "⚠️ Warning: Failed to install latest LTS version of Node.js."
        log "Warning: Failed to install latest LTS version of Node.js."
    fi

    # Use the latest LTS version
    echo "🔧 Setting latest LTS version as default..."
    if nvm alias default 'lts/*' && nvm use default; then
        echo "✅ Latest LTS version of Node.js set as default."
        log "Latest LTS version of Node.js set as default."
    else
        echo "⚠️ Warning: Failed to set latest LTS version of Node.js as default."
        log "Warning: Failed to set latest LTS version of Node.js as default."
    fi
}

# Function to install or update npm
install_or_update_npm() {
    echo "🔄 Updating npm to the latest version..."
    if npm install -g npm@latest; then
        echo "✅ npm updated successfully."
        log "npm updated successfully."
    else
        echo "⚠️ Warning: Failed to update npm."
        log "Warning: Failed to update npm."
    fi
}

# Function to install or update essential npm packages
install_npm_packages() {
    echo "🔧 Installing essential global npm packages (npm-check-updates, yarn, nodemon, eslint, pm2, npx)..."

    local packages=("npm-check-updates" "yarn" "nodemon" "eslint" "pm2" "npx")

    for package in "${packages[@]}"; do
        if npm list -g --depth=0 "$package" &> /dev/null; then
            echo "🔄 Updating $package..."
            if npm update -g "$package"; then
                echo "✅ $package updated successfully."
                log "$package updated successfully."
            else
                echo "⚠️ Warning: Failed to update $package."
                log "Warning: Failed to update $package."
            fi
        else
            echo "📦 Installing $package globally..."
            if npm install -g "$package"; then
                echo "✅ $package installed successfully."
                log "$package installed successfully."
            else
                echo "⚠️ Warning: Failed to install $package."
                log "Warning: Failed to install $package."
            fi
        fi
    done
}

# Function to perform directory consolidation and cleanup
consolidate_node_directories() {
    echo "🧹 Consolidating Node.js directories..."

    # Ensure directories exist
    mkdir -p "$NODE_DATA_HOME" "$NODE_CONFIG_HOME" || handle_error "Failed to create Node.js directories."

    # Check if directories are writable
    check_directory_writable "$NODE_DATA_HOME"
    check_directory_writable "$NODE_CONFIG_HOME"

    log "Node.js directories consolidated and verified as writable."
}

# Function to manage permissions for Node.js directories
manage_permissions() {
    echo "🔐 Managing permissions for Node.js directories..."

    check_directory_writable "$NODE_DATA_HOME"
    check_directory_writable "$NODE_CONFIG_HOME"

    log "Permissions for Node.js directories are verified."
}

# Function to validate Node.js installation
validate_node_installation() {
    echo "✅ Validating Node.js installation..."

    # Check Node.js version
    if ! node --version &> /dev/null; then
        handle_error "Node.js is not installed correctly."
    fi

    # Check npm version
    if ! npm --version &> /dev/null; then
        handle_error "npm is not installed correctly."
    fi

    echo "✅ Node.js and npm are installed and configured correctly."
    log "Node.js installation validated successfully."
}

# Function to perform final cleanup tasks
perform_final_cleanup() {
    echo "🧼 Performing final cleanup tasks..."

    # Remove temporary files if they exist
    if [[ -d "$NODE_DATA_HOME/tmp" ]]; then
        echo "🗑️ Cleaning up temporary files in $NODE_DATA_HOME/tmp..."
        rm -rf "${NODE_DATA_HOME:?}/tmp" || log "⚠️ Warning: Failed to remove temporary files in '$NODE_DATA_HOME/tmp'."
        log "Temporary files in '$NODE_DATA_HOME/tmp' removed."
    fi

    if [[ -d "$NODE_CONFIG_HOME/tmp" ]]; then
        echo "🗑️ Cleaning up temporary files in $NODE_CONFIG_HOME/tmp..."
        rm -rf "${NODE_CONFIG_HOME:?}/tmp" || log "⚠️ Warning: Failed to remove temporary files in '$NODE_CONFIG_HOME/tmp'."
        log "Temporary files in '$NODE_CONFIG_HOME/tmp' removed."
    fi

    echo "🧼 Final cleanup completed."
    log "Final cleanup tasks completed."
}

# Function to configure npm cache and global directories
configure_npm_directories() {
    echo "🛠️ Configuring npm cache and global directories..."

    # Set npm cache directory
    if npm config set cache "${XDG_CACHE_HOME:-$HOME/.cache}/npm-cache"; then
        echo "✅ npm cache directory set to '${XDG_CACHE_HOME:-$HOME/.cache}/npm-cache'."
        log "npm cache directory set to '${XDG_CACHE_HOME:-$HOME/.cache}/npm-cache'."
    else
        echo "⚠️ Warning: Failed to set npm cache directory."
        log "Warning: Failed to set npm cache directory."
    fi

    # Set npm global directory
    if npm config set prefix "$NODE_DATA_HOME/npm-global"; then
        echo "✅ npm global directory set to '$NODE_DATA_HOME/npm-global'."
        log "npm global directory set to '$NODE_DATA_HOME/npm-global'."
    else
        echo "⚠️ Warning: Failed to set npm global directory."
        log "Warning: Failed to set npm global directory."
    fi

    # Update PATH
    export PATH="$NODE_DATA_HOME/npm-global/bin:$PATH"
}

# Function to backup Node.js and npm configurations
backup_node_configuration() {
    echo "🗄️ Backing up Node.js and npm configurations..."

    local backup_dir
    backup_dir="${XDG_STATE_HOME:-$HOME/.local/state}/backups/node_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"

    if [[ -d "$NVM_DIR" ]]; then
        # Exclude node_modules and cache directories to prevent core dumps
        echo "⚠️ Skipping backup of NVM directory due to previous errors."
        log "Skipped backup of NVM directory."
    fi

    local npm_prefix
    npm_prefix=$(npm config get prefix) || handle_error "Failed to get npm prefix."

    if [[ -d "$npm_prefix" ]]; then
        echo "⚠️ Skipping backup of npm global directory due to previous errors."
        log "Skipped backup of npm global directory."
    fi

    if [[ -d "${XDG_CACHE_HOME:-$HOME/.cache}/npm-cache" ]]; then
        echo "⚠️ Skipping backup of npm cache directory due to previous errors."
        log "Skipped backup of npm cache directory."
    fi

    echo "✅ Backup step skipped."
    log "Backup step skipped due to previous errors."
}

# Function to optimize NVM and Node.js environment
optimize_nvm_service() {
    echo "🔧 Starting NVM and Node.js environment optimization..."

    # Step 1: Install or update NVM
    echo "📦 Installing or updating NVM..."
    if command -v nvm &> /dev/null; then
        echo "✅ NVM is already installed."
        log "NVM is already installed."
    else
        install_nvm
    fi

    # Step 2: Install or update Node.js using NVM
    echo "📦 Installing or updating Node.js..."
    install_or_update_node

    # Step 3: Install or update npm
    echo "🔄 Updating npm..."
    install_or_update_npm

    # Step 4: Consolidate Node.js directories (ensure NODE_DATA_HOME is set)
    echo "🧹 Performing directory consolidation and cleanup..."
    consolidate_node_directories

    # Step 5: Configure npm cache and global directories
    echo "🛠️ Configuring npm directories..."
    configure_npm_directories

    # Step 6: Install or update essential npm packages
    echo "🔧 Installing or updating essential npm packages..."
    install_npm_packages

    # Step 7: Manage permissions for Node.js directories
    echo "🔐 Managing permissions for Node.js directories..."
    manage_permissions

    # Step 8: Backup Node.js configuration
#    echo "🗄️ Backing up Node.js configuration..."
#    backup_node_configuration

    # Step 9: Validate Node.js installation
    echo "✅ Validating Node.js installation..."
    validate_node_installation

    # Step 10: Final cleanup
    echo "🧼 Performing final cleanup..."
    perform_final_cleanup

    # Final summary
    echo "🎉 NVM and Node.js environment optimization complete."
    echo -e "${CYAN}NODE_DATA_HOME:${NC} $NODE_DATA_HOME"
    echo -e "${CYAN}NODE_CONFIG_HOME:${NC} $NODE_CONFIG_HOME"
    echo -e "${CYAN}NVM_DIR:${NC} $NVM_DIR"
    echo -e "${CYAN}Node.js version:${NC} $(node --version)"
    echo -e "${CYAN}npm version:${NC} $(npm --version)"
}

# Export necessary functions for use by the controller
export -f log
export -f handle_error
export -f check_directory_writable
export -f install_nvm
export -f install_or_update_node
export -f install_or_update_npm
export -f install_npm_packages
export -f consolidate_node_directories
export -f manage_permissions
export -f validate_node_installation
export -f perform_final_cleanup
export -f configure_npm_directories
export -f backup_node_configuration
export -f optimize_nvm_service

# The controller script will call optimize_nvm_service as needed, so there is no need for direct invocation here.
