#!/bin/bash
# File: optimize_node.sh
# Author: 4ndr0666
# Date: 2024-11-24
# Description: Optimizes Node.js and npm environment in alignment with XDG Base Directory Specifications.

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

# Define Node.js directories based on XDG specifications
export NODE_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/node"
export NODE_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/node"
export NODE_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/node"

# Function to optimize Node.js environment
optimize_node_service() {
    echo "🔧 Starting Node.js and npm environment optimization..."

    # Step 1: Check if Node.js is installed
    echo "📦 Checking if Node.js is installed..."
    if ! command -v node &> /dev/null; then
        echo "📦 Node.js is not installed. Installing Node.js..."
        install_node
    else
        current_node_version=$(node -v)
        echo "✅ Node.js is already installed: $current_node_version"
        log "Node.js is already installed: $current_node_version"
    fi

    # Step 2: Check if NVM (Node Version Manager) is installed and manage Node.js versions
    manage_nvm_and_node_versions

    # Step 3: Set up environment variables for Node.js and NVM
    echo "🛠️ Setting up environment variables for Node.js and NVM..."
    export NVM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvm"
    export PATH="$NODE_DATA_HOME/npm-global/bin:$PATH"

    # Ensure directories exist
    mkdir -p "$NODE_DATA_HOME" "$NODE_CONFIG_HOME" "$NODE_CACHE_HOME" "$NVM_DIR" || handle_error "Failed to create Node.js directories."

    # Step 4: Configure npm cache and global directory
    echo "🛠️ Configuring npm cache and global directory..."
    configure_npm_cache_and_global_directory

    # Step 5: Ensure essential global npm packages are installed
    echo "🔧 Ensuring essential global npm packages are installed..."
    install_npm_packages

    # Step 6: Check permissions for global npm directory
    echo "🔐 Checking permissions for global npm directory..."
    local npm_global_root
    npm_global_root=$(npm root -g) || handle_error "Failed to retrieve npm global root."
    check_directory_writable "$npm_global_root"

    # Step 7: Clean up and consolidate Node.js directories
    echo "🧹 Consolidating Node.js and npm directories..."
    consolidate_node_directories

    # Step 8: Backup current Node.js and npm configuration
#    echo "🗄️ Backing up Node.js and npm configuration..."
#    backup_node_configuration

    # Step 9: Validate Node.js installation
    echo "✅ Validating Node.js installation..."
    validate_node_installation

    # Step 10: Final cleanup and summary
    echo "🧼 Performing final cleanup..."
    perform_final_cleanup

    echo "🎉 Node.js and npm environment optimization complete."
    echo -e "${CYAN}Node.js version:${NC} $(node -v)"
    echo -e "${CYAN}npm version:${NC} $(npm -v)"
    echo -e "${CYAN}NVM_DIR:${NC} $NVM_DIR"
    echo -e "${CYAN}NODE_DATA_HOME:${NC} $NODE_DATA_HOME"
    echo -e "${CYAN}NODE_CONFIG_HOME:${NC} $NODE_CONFIG_HOME"
    echo -e "${CYAN}NODE_CACHE_HOME:${NC} $NODE_CACHE_HOME"
}

# Helper function to install Node.js using multiple package managers
install_node() {
    if command -v pacman &> /dev/null; then
        echo "Installing Node.js using pacman..."
        sudo pacman -Syu --needed nodejs npm || handle_error "Failed to install Node.js with pacman."
    elif command -v apt-get &> /dev/null; then
        echo "Installing Node.js using apt-get..."
        sudo apt-get update && sudo apt-get install -y nodejs npm || handle_error "Failed to install Node.js with apt-get."
    elif command -v dnf &> /dev/null; then
        echo "Installing Node.js using dnf..."
        sudo dnf install -y nodejs npm || handle_error "Failed to install Node.js with dnf."
    elif command -v brew &> /dev/null; then
        echo "Installing Node.js using Homebrew..."
        brew install node || handle_error "Failed to install Node.js with Homebrew."
    else
        handle_error "Unsupported package manager. Please install Node.js manually."
    fi
    echo "✅ Node.js installed successfully."
    log "Node.js installed successfully."
}

# Function to manage NVM and Node.js versions
manage_nvm_and_node_versions() {
    if command -v nvm &> /dev/null; then
        echo "🔄 Managing Node.js versions via NVM..."
    else
        echo "📦 NVM is not installed. Installing NVM..."
        install_nvm
    fi

    # Temporarily disable 'set -u' before sourcing nvm.sh
    set +u
    # Ensure NVM is loaded
    export NVM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvm"
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" || handle_error "Failed to source NVM script."
    # Re-enable 'set -u'
    set -u

    # Install and use the latest LTS version
    echo "🔄 Installing the latest LTS version of Node.js..."
    set +u
    if nvm install --lts; then
        echo "✅ Latest LTS version of Node.js installed successfully."
        log "Latest LTS version of Node.js installed successfully."
    else
        echo "⚠️ Warning: Failed to install the latest LTS Node.js version."
        log "Warning: Failed to install the latest LTS Node.js version."
    fi
    set -u

    echo "🔄 Using the latest LTS version of Node.js..."
    set +u
    if nvm use --lts; then
        echo "✅ Using the latest LTS version of Node.js."
        log "Using the latest LTS version of Node.js."
    else
        echo "⚠️ Warning: Failed to switch to the latest LTS Node.js version."
        log "Warning: Failed to switch to the latest LTS Node.js version."
    fi
    set -u

    echo "🔄 Setting the latest LTS version as the default..."
    set +u
    if nvm alias default 'lts/*'; then
        echo "✅ Latest LTS version set as default."
        log "Latest LTS version set as default."
    else
        echo "⚠️ Warning: Failed to set default Node.js version."
        log "Warning: Failed to set default Node.js version."
    fi
    set -u
}

# Helper function to install NVM
install_nvm() {
    echo "📦 Installing NVM via the official NVM script..."
    if command -v curl &> /dev/null; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | bash || handle_error "Failed to install NVM using curl."
    elif command -v wget &> /dev/null; then
        wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | bash || handle_error "Failed to install NVM using wget."
    else
        handle_error "Neither curl nor wget is installed. Please install one to proceed."
    fi

    export NVM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvm"
    mkdir -p "$NVM_DIR"

    # Move default NVM directory to XDG_CONFIG_HOME
    if [[ -d "$HOME/.nvm" && "$HOME/.nvm" != "$NVM_DIR" ]]; then
        mv "$HOME/.nvm" "$NVM_DIR" || handle_error "Failed to move .nvm to $NVM_DIR."
    fi

    # Temporarily disable 'set -u' before sourcing nvm.sh
    set +u
    # Ensure NVM is loaded
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

# Function to configure npm cache and global directory
configure_npm_cache_and_global_directory() {
    echo "🛠️ Configuring npm cache directory..."
    if npm config set cache "${XDG_CACHE_HOME:-$HOME/.cache}/npm-cache"; then
        echo "✅ npm cache directory set to '${XDG_CACHE_HOME:-$HOME/.cache}/npm-cache'."
        log "npm cache directory set to '${XDG_CACHE_HOME:-$HOME/.cache}/npm-cache'."
    else
        echo "⚠️ Warning: Failed to set npm cache directory."
        log "Warning: Failed to set npm cache directory."
    fi

    echo "🛠️ Configuring npm global prefix directory..."
    if npm config set prefix "$NODE_DATA_HOME/npm-global"; then
        echo "✅ npm global directory set to '$NODE_DATA_HOME/npm-global'."
        log "npm global directory set to '$NODE_DATA_HOME/npm-global'."
    else
        echo "⚠️ Warning: Failed to set npm global prefix directory."
        log "Warning: Failed to set npm global prefix directory."
    fi

    # Update PATH
    export PATH="$NODE_DATA_HOME/npm-global/bin:$PATH"
}

# Function to consolidate Node.js directories
consolidate_node_directories() {
    # Consolidate .npm directory to NODE_CACHE_HOME
    if [[ -d "$HOME/.npm" ]]; then
        echo "🧹 Consolidating $HOME/.npm to $NODE_CACHE_HOME/npm..."
        rsync -av "$HOME/.npm/" "$NODE_CACHE_HOME/npm/" || echo "⚠️ Warning: Failed to consolidate $HOME/.npm to $NODE_CACHE_HOME/npm."
        rm -rf "$HOME/.npm"
        echo "✅ Consolidated $HOME/.npm to $NODE_CACHE_HOME/npm."
        log "Consolidated $HOME/.npm to $NODE_CACHE_HOME/npm."
    fi
}

# Function to backup Node.js and npm configurations
backup_node_configuration() {
    echo "🗄️ Backing up Node.js and npm configurations..."

    local backup_dir
    backup_dir="${XDG_STATE_HOME:-$HOME/.local/state}/backups/node_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"

    if [[ -d "$NVM_DIR" ]]; then
        tar --exclude='node_modules' --exclude='cache' --exclude-vcs -czf "$backup_dir/nvm_backup.tar.gz" -C "$NVM_DIR" . || log "⚠️ Warning: Could not backup NVM directory."
    fi

    if [[ -d "$NODE_DATA_HOME/npm-global" ]]; then
        tar --exclude='node_modules' --exclude='cache' --exclude-vcs -czf "$backup_dir/npm_global_backup.tar.gz" -C "$NODE_DATA_HOME/npm-global" . || log "⚠️ Warning: Could not backup npm global directory."
    fi

    if [[ -d "${XDG_CACHE_HOME:-$HOME/.cache}/npm-cache" ]]; then
        tar --exclude='node_modules' --exclude='cache' --exclude-vcs -czf "$backup_dir/npm_cache_backup.tar.gz" -C "${XDG_CACHE_HOME:-$HOME/.cache}/npm-cache" . || log "⚠️ Warning: Could not backup npm cache directory."
    fi

    echo "✅ Backup completed at '$backup_dir'."
    log "Backup completed at '$backup_dir'."
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
    if [[ -d "$NODE_CACHE_HOME/tmp" ]]; then
        echo "🗑️ Cleaning up temporary files in $NODE_CACHE_HOME/tmp..."
        rm -rf "${NODE_CACHE_HOME:?}/tmp" || log "⚠️ Warning: Failed to remove temporary files in '$NODE_CACHE_HOME/tmp'."
        log "Temporary files in '$NODE_CACHE_HOME/tmp' removed."
    fi

    echo "🧼 Final cleanup completed."
    log "Final cleanup tasks completed."
}

# Export necessary functions for use by the controller
export -f log
export -f handle_error
export -f check_directory_writable
export -f install_node
export -f manage_nvm_and_node_versions
export -f install_nvm
export -f install_npm_packages
export -f configure_npm_cache_and_global_directory
export -f consolidate_node_directories
export -f backup_node_configuration
export -f validate_node_installation
export -f perform_final_cleanup
export -f optimize_node_service

# The controller script will call optimize_node_service as needed, so there is no need for direct invocation here.
