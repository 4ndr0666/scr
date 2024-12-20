#!/bin/bash
# File: optimize_meson.sh
# Author: 4ndr0666
# Date: 2024-11-24
# Description: Optimizes Meson build system environment.

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
        echo -e "${GREEN}✅ Directory $dir_path is writable.${NC}"
        log "Directory '$dir_path' is writable."
    else
        handle_error "Directory $dir_path is not writable."
    fi
}

export MESON_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/meson"
export MESON_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/meson"
export MESON_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/meson"

install_meson() {
    if command -v meson &> /dev/null; then
        echo -e "${GREEN}✅ Meson is already installed: $(meson --version)${NC}"
        log "Meson is already installed."
        return 0
    fi

    if command -v pip &> /dev/null; then
        echo "Installing Meson via pip..."
        pip install --user meson || handle_error "Failed to install Meson with pip."
    elif command -v pacman &> /dev/null; then
        echo "Installing Meson via pacman..."
        sudo pacman -S --noconfirm meson || handle_error "Failed to install Meson with pacman."
    else
        handle_error "Meson missing. Use --fix to install."
    fi
    echo -e "${GREEN}✅ Meson installed successfully.${NC}"
    log "Meson installed successfully."
}

check_ninja_installation() {
    echo "📦 Checking if Ninja build system is installed..."
    if command -v ninja &> /dev/null; then
        echo -e "${GREEN}✅ Ninja build system is already installed: $(ninja --version)${NC}"
        log "Ninja build system is installed."
    else
        echo "Ninja build system is not installed. Installing..."
        install_ninja
    fi
}

install_ninja() {
    if command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm ninja || handle_error "Failed to install Ninja with pacman."
    elif command -v apt-get &> /dev/null; then
        sudo apt-get install -y ninja-build || handle_error "Failed to install Ninja with apt-get."
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y ninja-build || handle_error "Failed to install Ninja with dnf."
    elif command -v brew &> /dev/null; then
        brew install ninja || handle_error "Failed to install Ninja with Homebrew."
    elif command -v zypper &> /dev/null; then
        sudo zypper install -y ninja || handle_error "Failed to install Ninja with zypper."
    else
        handle_error "Unsupported package manager. Please install Ninja manually."
    fi
    echo -e "${GREEN}✅ Ninja installed successfully.${NC}"
    log "Ninja installed successfully."
}

setup_python_environment_for_meson() {
    if ! command -v python3 &> /dev/null; then
        echo "Python3 is not installed. Installing..."
        install_python3
    else
        echo -e "${GREEN}✅ Python3 is already installed.${NC}"
    fi

    # Attempt to upgrade meson if pip is available
    if command -v pip &> /dev/null; then
        echo "🔄 Updating meson..."
        if ! pip install --user --upgrade meson; then
            echo -e "${YELLOW}⚠️ Warning: Failed to update meson.${NC}"
            log "Warning: Failed to update meson."
        fi
    else
        echo "pip not available. Skipping meson update."
        log "pip not available, skipping meson update."
    fi

    # Create a virtual environment if not exist and if no active VENV
    if [[ -d "$MESON_HOME/venv" ]]; then
        echo "🐍 Virtual environment already exists. Activating..."
        source "$MESON_HOME/venv/bin/activate"
    elif [[ -z "${VIRTUAL_ENV:-}" ]]; then
        echo "🐍 Creating a new virtual environment for Meson..."
        python3 -m venv "$MESON_HOME/venv" || handle_error "Failed to create virtual environment."
        source "$MESON_HOME/venv/bin/activate"
        pip install --upgrade pip
    else
        echo "🐍 A virtual environment is already active."
        log "Virtual environment already active."
    fi
}

install_python3() {
    if command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm python || handle_error "Failed to install Python with pacman."
    elif command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y python3 || handle_error "Failed to install Python with apt-get."
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y python3 || handle_error "Failed to install Python with dnf."
    elif command -v brew &> /dev/null; then
        brew install python || handle_error "Failed to install Python with Homebrew."
    elif command -v zypper &> /dev/null; then
        sudo zypper install -y python3 || handle_error "Failed to install Python with zypper."
    else
        handle_error "Unsupported package manager for Python installation."
    fi
    echo -e "${GREEN}✅ Python3 installed successfully.${NC}"
    log "Python3 installed successfully."
}

pip_install_or_update() {
    local package_name="$1"
    if pip show "$package_name" &>/dev/null; then
        echo "🔄 Updating $package_name..."
        if pip install --upgrade "$package_name"; then
            echo -e "${GREEN}✅ $package_name updated successfully.${NC}"
            log "$package_name updated successfully."
        else
            echo -e "${YELLOW}⚠️ Warning: Failed to update $package_name.${NC}"
            log "Warning: Failed to update $package_name."
        fi
    else
        echo "📦 Installing $package_name via pip..."
        if pip install "$package_name"; then
            echo -e "${GREEN}✅ $package_name installed successfully.${NC}"
            log "$package_name installed successfully."
        else
            echo -e "${YELLOW}⚠️ Warning: Failed to install $package_name.${NC}"
            log "Warning: Failed to install $package_name."
        fi
    fi
}

setup_meson_environment() {
    export PATH="$MESON_HOME/bin:$PATH"
    echo -e "${GREEN}✅ Environment variables set.${NC}"
    log "Meson and Ninja environment variables set."
}

configure_additional_meson_backends() {
    echo "⚙️ Configuring additional Meson backends (optional)..."
    if [[ -d "build" ]]; then
        echo "📁 Build directory already exists. Skipping creation."
    else
        echo "📁 Creating a new build directory for Meson..."
        if ! meson setup build --backend=ninja; then
            echo -e "${YELLOW}⚠️ Warning: Failed to set up Meson build directory.${NC}"
            log "Warning: Failed to set up Meson build directory."
        else
            echo "✅ Meson build directory set up."
            log "Meson build directory set up."
        fi
    fi
}

consolidate_directories() {
    local source_dir="$1"
    local target_dir="$2"
    if [[ -d "$source_dir" ]]; then
        rsync -av "$source_dir/" "$target_dir/" || echo -e "${YELLOW}⚠️ Warning: Failed to consolidate $source_dir to $target_dir.${NC}"
        rm -rf "$source_dir"
        echo "✅ Consolidated directories from $source_dir to $target_dir."
        log "Consolidated directories from $source_dir to $target_dir."
    else
        echo -e "${YELLOW}⚠️ Source directory $source_dir does not exist. Skipping.${NC}"
        log "Source directory $source_dir does not exist. Skipping consolidation."
    fi
}

remove_empty_directories() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        find "$dir" -type d -empty -delete
        echo "🗑️ Removed empty directories in $dir."
        log "Removed empty directories in $dir."
    else
        echo -e "${YELLOW}⚠️ Directory $dir does not exist. Skipping empty directory removal.${NC}"
    fi
}

perform_final_cleanup() {
    echo "🧼 Performing final cleanup tasks..."
    if [[ -d "$MESON_CACHE_HOME/tmp" ]]; then
        echo "🗑️ Cleaning up $MESON_CACHE_HOME/tmp..."
        rm -rf "${MESON_CACHE_HOME:?}/tmp" || log "Warning: Failed to remove tmp in '$MESON_CACHE_HOME/tmp'."
        log "Removed temporary files in '$MESON_CACHE_HOME/tmp'."
    fi
    echo -e "${GREEN}✅ Final cleanup completed.${NC}"
    log "Meson final cleanup tasks completed."
}

optimize_meson_service() {
    echo -e "${CYAN}🔧 Starting Meson build system environment optimization...${NC}"
    echo "📦 Checking if Meson is installed..."
    install_meson
    check_ninja_installation
    echo "🐍 Ensuring Python environment and Meson dependencies are installed..."
    setup_python_environment_for_meson
    echo "🛠️ Setting up Meson environment..."
    setup_meson_environment
    echo "🔧 Installing optional tools (meson-test, meson-lint)..."
    pip_install_or_update "meson-test"
    pip_install_or_update "meson-lint"
    echo "🔐 Checking permissions for Meson directories..."
    check_directory_writable "$MESON_HOME"
    echo "⚙️ Configuring additional Meson backends..."
    configure_additional_meson_backends
    echo "🧹 Consolidating Meson directories..."
    consolidate_directories "$HOME/.meson" "$MESON_HOME"
    remove_empty_directories "$HOME/.meson"
    echo "🧼 Performing final cleanup..."
    perform_final_cleanup
    echo -e "${GREEN}🎉 Meson environment optimization complete.${NC}"
    echo -e "${CYAN}Meson version:${NC} $(meson --version)"
    echo -e "${CYAN}Ninja version:${NC} $(ninja --version)"
    echo -e "${CYAN}MESON_HOME:${NC} $MESON_HOME"
    echo -e "${CYAN}MESON_CONFIG_HOME:${NC} $MESON_CONFIG_HOME"
    echo -e "${CYAN}MESON_CACHE_HOME:${NC} $MESON_CACHE_HOME"
    log "Meson environment optimization completed."
}
