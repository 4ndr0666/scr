#!/bin/bash
# File: optimize_meson.sh
# Author: 4ndr0666
# Date: 2024-11-24
# Description: Optimizes Meson build system environment in alignment with XDG Base Directory Specifications.

set -euo pipefail
IFS=$'\n\t'

# Define color codes for enhanced output
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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
        echo -e "${GREEN}✅ Directory $dir_path is writable.${NC}"
        log "Directory '$dir_path' is writable."
    else
        echo -e "${RED}❌ Error: Directory $dir_path is not writable.${NC}"
        log "ERROR: Directory '$dir_path' is not writable."
        exit 1
    fi
}

# Define Meson directories based on XDG specifications
export MESON_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/meson"
export MESON_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/meson"
export MESON_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/meson"

# Function to optimize Meson build system environment
optimize_meson_service() {
    echo -e "${CYAN}🔧 Starting Meson build system environment optimization...${NC}"

    # Step 1: Check if Meson is installed
    echo "📦 Checking if Meson is installed..."
    if ! command -v meson &> /dev/null; then
        echo "📦 Meson is not installed. Installing Meson..."
        install_meson
    else
        current_meson_version=$(meson --version)
        echo -e "${GREEN}✅ Meson is already installed: $current_meson_version${NC}"
        log "Meson is already installed: $current_meson_version"
    fi

    # Step 2: Ensure Ninja build system is installed (required for Meson)
    check_ninja_installation

    # Step 3: Ensure Python is set up and Meson dependencies are installed
    echo "🐍 Ensuring Python environment and Meson dependencies are installed..."
    setup_python_environment_for_meson

    # Step 4: Set up environment variables for Meson and Ninja
    echo "🛠️ Setting up Meson and Ninja environment variables..."
    setup_meson_environment

    # Step 5: Install optional testing and linting tools (meson test, meson lint)
    echo "🔧 Installing optional tools for Meson testing and linting..."
    pip_install_or_update "meson-test"
    pip_install_or_update "meson-lint"

    # Step 6: Check permissions for Meson directories
    echo "🔐 Checking permissions for Meson directories..."
    check_directory_writable "$MESON_HOME"

    # Step 7: Configure additional backends or options (optional)
    echo "⚙️ Configuring additional Meson backends (optional)..."
    configure_additional_meson_backends

    # Step 8: Clean up and consolidate Meson directories
    echo "🧹 Consolidating Meson directories..."
    consolidate_directories "$HOME/.meson" "$MESON_HOME"
    remove_empty_directories "$HOME/.meson"

    # Step 9: Backup current Meson configuration (optional)
#    echo "🗄️ Backing up Meson configuration..."
#    backup_meson_configuration

    # Step 10: Final cleanup and summary
    echo "🧼 Performing final cleanup..."
    perform_final_cleanup

    echo -e "${GREEN}🎉 Meson and Ninja environment optimization complete.${NC}"
    echo -e "${CYAN}Meson version:${NC} $(meson --version)"
    echo -e "${CYAN}Ninja version:${NC} $(ninja --version)"
    echo -e "${CYAN}MESON_HOME:${NC} $MESON_HOME"
    echo -e "${CYAN}MESON_CONFIG_HOME:${NC} $MESON_CONFIG_HOME"
    echo -e "${CYAN}MESON_CACHE_HOME:${NC} $MESON_CACHE_HOME"
}

# Helper function to install Meson via pip or package managers
install_meson() {
    if command -v pip &> /dev/null; then
        echo "📦 Installing Meson via pip..."
        pip install --user meson || handle_error "Failed to install Meson with pip."
    elif command -v pacman &> /dev/null; then
        echo "📦 Installing Meson via pacman..."
        sudo pacman -S --noconfirm meson || handle_error "Failed to install Meson with pacman."
    elif command -v apt-get &> /dev/null; then
        echo "📦 Installing Meson via apt-get..."
        sudo apt-get install -y meson || handle_error "Failed to install Meson with apt-get."
    elif command -v dnf &> /dev/null; then
        echo "📦 Installing Meson via dnf..."
        sudo dnf install -y meson || handle_error "Failed to install Meson with dnf."
    elif command -v brew &> /dev/null; then
        echo "📦 Installing Meson via Homebrew..."
        brew install meson || handle_error "Failed to install Meson with Homebrew."
    elif command -v zypper &> /dev/null; then
        echo "📦 Installing Meson via zypper..."
        sudo zypper install -y meson || handle_error "Failed to install Meson with zypper."
    else
        handle_error "Unsupported package manager. Please install Meson manually."
    fi
    echo -e "${GREEN}✅ Meson installed successfully.${NC}"
    log "Meson installed successfully."
}

# Helper function to check if Ninja build system is installed
check_ninja_installation() {
    echo "📦 Checking if Ninja build system is installed..."
    if command -v ninja &> /dev/null; then
        current_ninja_version=$(ninja --version)
        echo -e "${GREEN}✅ Ninja build system is already installed: $current_ninja_version${NC}"
        log "Ninja build system is already installed: $current_ninja_version"
    else
        echo "📦 Ninja build system is not installed. Installing Ninja..."
        install_ninja
    fi
}

# Helper function to install Ninja build system
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

# Helper function to set up Python environment and ensure Meson dependencies are installed
setup_python_environment_for_meson() {
    if command -v python3 &> /dev/null; then
        echo -e "${GREEN}✅ Python3 is already installed.${NC}"
    else
        echo "🐍 Python3 is not installed. Installing Python3..."
        install_python3
    fi

    pip_install_or_update "meson"

    # Optionally, create a virtual environment for Meson
    if [[ -d "$MESON_HOME/venv" ]]; then
        echo "🐍 Virtual environment already exists for Meson. Activating..."
        source "$MESON_HOME/venv/bin/activate"
    elif [[ -z "${VIRTUAL_ENV:-}" ]]; then
        echo "🐍 Creating a new virtual environment for Meson..."
        python3 -m venv "$MESON_HOME/venv" || handle_error "Failed to create virtual environment."
        source "$MESON_HOME/venv/bin/activate"
        pip install --upgrade pip
    else
        echo "🐍 A virtual environment is already active."
    fi
}

# Helper function to install Python via package managers
install_python3() {
    if command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm python || handle_error "Failed to install Python with pacman."
    elif command -v apt-get &> /dev/null; then
        sudo apt-get install -y python3 || handle_error "Failed to install Python with apt-get."
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y python3 || handle_error "Failed to install Python with dnf."
    elif command -v brew &> /dev/null; then
        brew install python || handle_error "Failed to install Python with Homebrew."
    elif command -v zypper &> /dev/null; then
        sudo zypper install -y python3 || handle_error "Failed to install Python with zypper."
    else
        handle_error "Unsupported package manager. Please install Python manually."
    fi
    echo -e "${GREEN}✅ Python3 installed successfully.${NC}"
    log "Python3 installed successfully."
}

# Helper function to install or update Python packages
pip_install_or_update() {
    local package_name="$1"

    if pip show "$package_name" &> /dev/null; then
        echo "🔄 Updating $package_name..."
        if pip install --user --upgrade "$package_name"; then
            echo -e "${GREEN}✅ $package_name updated successfully.${NC}"
            log "$package_name updated successfully."
        else
            echo -e "${YELLOW}⚠️ Warning: Failed to update $package_name.${NC}"
            log "Warning: Failed to update $package_name."
        fi
    else
        echo "📦 Installing $package_name via pip..."
        if pip install --user "$package_name"; then
            echo -e "${GREEN}✅ $package_name installed successfully.${NC}"
            log "$package_name installed successfully."
        else
            echo -e "${YELLOW}⚠️ Warning: Failed to install $package_name.${NC}"
            log "Warning: Failed to install $package_name."
        fi
    fi
}

# Helper function to set up Meson and Ninja environment variables
setup_meson_environment() {
    export PATH="$MESON_HOME/bin:$PATH"
    echo -e "${GREEN}✅ Environment variables set.${NC}"
    log "Environment variables for Meson and Ninja set."
}

# Helper function to configure additional Meson backends or options (optional)
configure_additional_meson_backends() {
    echo "⚙️ Configuring additional Meson backends (optional)..."
    # For example, setting up a custom build directory
    if [[ -d "build" ]]; then
        echo "📁 Build directory already exists. Using existing build directory."
    else
        echo "📁 Creating a new build directory for Meson..."
        meson setup build --backend=ninja || echo -e "${YELLOW}⚠️ Warning: Failed to set up Meson build directory.${NC}"
    fi
}

# Helper function to backup current Meson configuration
backup_meson_configuration() {
    if [[ -d "$MESON_CONFIG_HOME" ]]; then
        echo "🗄️ Backing up Meson configuration..."

        local backup_dir
        backup_dir="${XDG_STATE_HOME:-$HOME/.local/state}/backups/meson_backup_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$backup_dir"
        tar --exclude-vcs -czf "$backup_dir/meson_config_backup.tar.gz" -C "$MESON_CONFIG_HOME" . || log "⚠️ Warning: Could not backup Meson configuration."

        echo -e "${GREEN}✅ Backup completed at '$backup_dir'.${NC}"
        log "Backup completed at '$backup_dir'."
    else
        echo -e "${YELLOW}⚠️ Meson configuration directory does not exist. Skipping backup.${NC}"
    fi
}

# Helper function to perform final cleanup tasks
perform_final_cleanup() {
    echo "🧼 Performing final cleanup tasks..."

    # Remove temporary files if they exist
    if [[ -d "$MESON_CACHE_HOME/tmp" ]]; then
        echo "🗑️ Cleaning up temporary files in $MESON_CACHE_HOME/tmp..."
        rm -rf "${MESON_CACHE_HOME:?}/tmp" || log "⚠️ Warning: Failed to remove temporary files in '$MESON_CACHE_HOME/tmp'."
        log "Temporary files in '$MESON_CACHE_HOME/tmp' removed."
    fi

    echo -e "${GREEN}✅ Final cleanup completed.${NC}"
    log "Final cleanup tasks completed."
}

# Helper function: Consolidate contents from source to target directory
consolidate_directories() {
    local source_dir="$1"
    local target_dir="$2"

    if [[ -d "$source_dir" ]]; then
        echo "🧹 Consolidating $source_dir to $target_dir..."
        rsync -av "$source_dir/" "$target_dir/" || echo -e "${YELLOW}⚠️ Warning: Failed to consolidate $source_dir to $target_dir.${NC}"
        rm -rf "$source_dir"
        echo -e "${GREEN}✅ Consolidated directories from $source_dir to $target_dir.${NC}"
        log "Consolidated directories from $source_dir to $target_dir."
    else
        echo -e "${YELLOW}⚠️ Source directory $source_dir does not exist. Skipping consolidation.${NC}"
    fi
}

# Helper function: Remove empty directories
remove_empty_directories() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        find "$dir" -type d -empty -delete
        echo "🗑️ Removed empty directories in $dir."
        log "Removed empty directories in $dir."
    else
        echo -e "${YELLOW}⚠️ Directory $dir does not exist. Skipping removal of empty directories.${NC}"
    fi
}

# Export necessary functions for use by the controller
export -f log
export -f handle_error
export -f check_directory_writable
export -f install_meson
export -f check_ninja_installation
export -f install_ninja
export -f setup_python_environment_for_meson
export -f install_python3
export -f pip_install_or_update
export -f setup_meson_environment
export -f configure_additional_meson_backends
export -f backup_meson_configuration
export -f perform_final_cleanup
export -f consolidate_directories
export -f remove_empty_directories
export -f optimize_meson_service

# The controller script will call optimize_meson_service as needed, so there is no need for direct invocation here.
