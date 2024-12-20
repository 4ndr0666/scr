#!/bin/bash
# File: optimize_node.sh
# Author: 4ndr0666
# Date: 2024-11-24
# Description: Optimizes Node.js and npm environment.

set -euo pipefail
IFS=$'\n\t'

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

LOG_FILE="${LOG_FILE:-$HOME/.cache/4ndr0service/logs/service_optimization.log}"
mkdir -p "$(dirname "$LOG_FILE")" || { echo "Failed to create log directory."; exit 1; }

log() {
    local message="$1"
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

handle_error() {
    local error_message="$1"
    echo -e "${RED}❌ Error: $error_message${NC}" >&2
    log "ERROR: $error_message"
    exit 1
}

check_directory_writable() {
    local dir_path="$1"
    if [[ -w "$dir_path" ]]; then
        echo "✅ Directory $dir_path is writable."
        log "Directory '$dir_path' is writable."
    else
        handle_error "Directory $dir_path is not writable."
    fi
}

export NODE_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/node"
export NODE_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/node"
export NODE_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/node"

install_node() {
    if command -v node &> /dev/null; then
        echo "✅ Node.js already installed: $(node -v)"
        log "Node.js already installed."
        return 0
    fi

    if command -v pacman &> /dev/null; then
        sudo pacman -Syu --needed nodejs npm || handle_error "Failed to install Node.js with pacman."
    elif command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y nodejs npm || handle_error "Failed to install Node.js with apt-get."
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y nodejs npm || handle_error "Failed to install Node.js with dnf."
    elif command -v brew &> /dev/null; then
        brew install node || handle_error "Failed to install Node.js with Homebrew."
    else
        handle_error "Unsupported package manager for Node.js installation."
    fi
    echo "✅ Node.js installed successfully."
    log "Node.js installed successfully."
}

install_nvm() {
    echo "📦 Installing NVM..."
    if command -v curl &> /dev/null; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | bash || handle_error "Failed to install NVM via curl."
    elif command -v wget &> /dev/null; then
        wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | bash || handle_error "Failed to install NVM via wget."
    else
        handle_error "curl/wget not found. Cannot install NVM."
    fi

    export NVM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvm"
    mkdir -p "$NVM_DIR" || handle_error "Failed to create NVM directory."

    if [[ -d "$HOME/.nvm" && "$HOME/.nvm" != "$NVM_DIR" ]]; then
        mv "$HOME/.nvm" "$NVM_DIR" || handle_error "Failed to move .nvm to $NVM_DIR."
    fi

    set +u
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" || handle_error "Failed to source NVM script."
    set -u

    if command -v nvm &> /dev/null; then
        echo "✅ NVM installed successfully."
        log "NVM installed successfully."
    else
        handle_error "NVM installation failed."
    fi
}

manage_nvm_and_node_versions() {
    if ! command -v nvm &> /dev/null; then
        echo "📦 NVM not installed. Installing NVM..."
        install_nvm
    fi

    set +u
    export NVM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" || handle_error "Failed to source NVM script."
    set -u

    echo "🔄 Installing the latest LTS version of Node.js..."
    set +u
    if nvm install --lts; then
        echo "✅ Latest LTS version of Node.js installed."
        log "Latest LTS version of Node.js installed."
    else
        echo "⚠️ Warning: Failed to install latest LTS Node.js."
        log "Warning: Failed to install latest LTS Node.js."
    fi

    echo "🔄 Using the latest LTS version of Node.js..."
    if nvm use --lts; then
        echo "✅ Using latest LTS Node.js."
        log "Using latest LTS Node.js."
    else
        echo "⚠️ Warning: Failed to switch to latest LTS Node.js."
        log "Warning: Failed to switch to latest LTS Node.js."
    fi

    echo "🔄 Setting latest LTS as default..."
    if nvm alias default 'lts/*'; then
        echo "✅ Latest LTS version set as default."
        log "Latest LTS version set as default."
    else
        echo "⚠️ Warning: Failed to set default Node.js version."
        log "Warning: Failed to set default Node.js version."
    fi
    set -u
}

install_npm_packages() {
    echo "🔧 Ensuring essential global npm packages (npm-check-updates, yarn, nodemon, eslint, pm2, npx) are installed..."
    local packages=("npm-check-updates" "yarn" "nodemon" "eslint" "pm2" "npx")

    for package in "${packages[@]}"; do
        if npm list -g --depth=0 "$package" &> /dev/null; then
            echo "🔄 Updating $package..."
            if npm update -g "$package"; then
                echo "✅ $package updated."
                log "$package updated."
            else
                echo "⚠️ Warning: Failed to update $package."
                log "Warning: Failed to update $package."
            fi
        else
            echo "📦 Installing $package globally..."
            if npm install -g "$package"; then
                echo "✅ $package installed."
                log "$package installed."
            else
                echo "⚠️ Warning: Failed to install $package."
                log "Warning: Failed to install $package."
            fi
        fi
    done
}

configure_npm_cache_and_global_directory() {
    echo "🛠️ Configuring npm cache directory..."
    if npm config set cache "${XDG_CACHE_HOME:-$HOME/.cache}/npm-cache"; then
        echo "✅ npm cache dir set to '${XDG_CACHE_HOME:-$HOME/.cache}/npm-cache'."
        log "npm cache dir set."
    else
        echo "⚠️ Warning: Failed to set npm cache dir."
        log "Warning: Failed to set npm cache dir."
    fi

    echo "🛠️ Configuring npm global prefix directory..."
    if npm config set prefix "$NODE_DATA_HOME/npm-global"; then
        echo "✅ npm global dir set to '$NODE_DATA_HOME/npm-global'."
        log "npm global dir set."
    else
        echo "⚠️ Warning: Failed to set npm global dir."
        log "Warning: Failed to set npm global dir."
    fi

    export PATH="$NODE_DATA_HOME/npm-global/bin:$PATH"
}

consolidate_node_directories() {
    if [[ -d "$HOME/.npm" ]]; then
        echo "🧹 Consolidating $HOME/.npm to $NODE_CACHE_HOME/npm..."
        mkdir -p "$NODE_CACHE_HOME/npm" || handle_error "Failed to create $NODE_CACHE_HOME/npm."
        rsync -av "$HOME/.npm/" "$NODE_CACHE_HOME/npm/" || echo "⚠️ Warning: Failed to consolidate .npm."
        rm -rf "$HOME/.npm"
        echo "✅ Consolidated .npm to $NODE_CACHE_HOME/npm."
        log "Consolidated .npm."
    fi
}

validate_node_installation() {
    echo "✅ Validating Node.js installation..."
    if ! node --version &> /dev/null; then
        handle_error "Node.js missing. Use --fix to install."
    fi
    if ! npm --version &> /dev/null; then
        handle_error "Npm missing. Use --fix to install."
    fi
    echo "✅ Node.js and npm installed correctly."
    log "Node.js installation validated."
}

perform_final_cleanup() {
    echo "🧼 Final cleanup..."
    if [[ -d "$NODE_CACHE_HOME/tmp" ]]; then
        echo "🗑️ Cleaning $NODE_CACHE_HOME/tmp..."
        rm -rf "${NODE_CACHE_HOME:?}/tmp" || log "Warning: Failed to remove $NODE_CACHE_HOME/tmp."
        log "Cleaned $NODE_CACHE_HOME/tmp."
    fi
    echo "🧼 Cleanup done."
    log "Node final cleanup done."
}

optimize_node_service() {
    echo "🔧 Starting Node.js and npm optimization..."
    echo "📦 Checking if Node.js is installed..."
    install_node

    echo "📦 Managing NVM and Node versions..."
    manage_nvm_and_node_versions

    echo "🛠️ Setting environment variables for Node.js and NVM..."
    export NVM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvm"
    export PATH="$NODE_DATA_HOME/npm-global/bin:$PATH"
    mkdir -p "$NODE_DATA_HOME" "$NODE_CONFIG_HOME" "$NODE_CACHE_HOME" "$NVM_DIR" || handle_error "Failed to create Node dirs."

    echo "🛠️ Configuring npm cache and global directory..."
    configure_npm_cache_and_global_directory

    echo "🔧 Ensuring essential npm packages..."
    install_npm_packages

    echo "🔐 Checking global npm directory..."
    npm_global_root=$(npm root -g) || handle_error "Failed to get npm global root."
    check_directory_writable "$npm_global_root"

    echo "🧹 Consolidating Node.js directories..."
    consolidate_node_directories

    echo "✅ Validating Node.js installation..."
    validate_node_installation

    echo "🧼 Performing final cleanup..."
    perform_final_cleanup

    echo "🎉 Node.js environment optimization complete."
    echo -e "${CYAN}Node.js version:${NC} $(node -v)"
    echo -e "${CYAN}npm version:${NC} $(npm -v)"
    echo -e "${CYAN}NVM_DIR:${NC} $NVM_DIR"
    echo -e "${CYAN}NODE_DATA_HOME:${NC} $NODE_DATA_HOME"
    echo -e "${CYAN}NODE_CONFIG_HOME:${NC} $NODE_CONFIG_HOME"
    echo -e "${CYAN}NODE_CACHE_HOME:${NC} $NODE_CACHE_HOME"
    log "Node.js environment optimization completed."
}
