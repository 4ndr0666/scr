#!/bin/bash
# File: optimize_python.sh
# Author: 4ndr0666
# Date: 2024-11-24
# Description: Optimizes Python environment, including virtual environments and package management, in alignment with XDG Base Directory Specifications.

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

# Define Python directories based on XDG specifications
export PYTHON_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/python"
export PYTHON_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/python"
export PYTHON_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/python"
export VENV_HOME="$PYTHON_DATA_HOME/virtualenvs"
export PIPX_HOME="$PYTHON_DATA_HOME/pipx"
export PIPX_BIN_DIR="$PYTHON_DATA_HOME/pipx/bin"

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

# Function to install or update Python
install_or_update_python() {
    echo "📦 Installing or updating Python..."
    if command -v python3 &> /dev/null; then
        echo "✅ Python is already installed: $(python3 --version)"
        log "Python is already installed."
    else
        if command -v pacman &> /dev/null; then
            echo "📦 Installing Python using pacman..."
            if sudo pacman -Syu --needed python; then
                echo "✅ Python installed successfully using pacman."
                log "Python installed successfully using pacman."
            else
                handle_error "Failed to install Python with pacman."
            fi
        elif command -v apt-get &> /dev/null; then
            echo "📦 Installing Python using apt-get..."
            if sudo apt-get update && sudo apt-get install -y python3 python3-pip; then
                echo "✅ Python installed successfully using apt-get."
                log "Python installed successfully using apt-get."
            else
                handle_error "Failed to install Python with apt-get."
            fi
        elif command -v dnf &> /dev/null; then
            echo "📦 Installing Python using dnf..."
            if sudo dnf install -y python3 python3-pip; then
                echo "✅ Python installed successfully using dnf."
                log "Python installed successfully using dnf."
            else
                handle_error "Failed to install Python with dnf."
            fi
        elif command -v brew &> /dev/null; then
            echo "📦 Installing Python using Homebrew..."
            if brew install python; then
                echo "✅ Python installed successfully using Homebrew."
                log "Python installed successfully using Homebrew."
            else
                handle_error "Failed to install Python with Homebrew."
            fi
        else
            handle_error "Unsupported package manager. Python installation aborted."
        fi
    fi
}

# Function to install or update pip
install_or_update_pip() {
    echo "🔄 Installing or updating pip..."
    if command -v pip3 &> /dev/null; then
        if python3 -m pip install --upgrade pip; then
            echo "✅ pip updated successfully."
            log "pip updated successfully."
        else
            echo "⚠️ Warning: Failed to update pip."
            log "Warning: Failed to update pip."
        fi
    else
        echo "📦 Installing pip..."
        if curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && python3 get-pip.py; then
            echo "✅ pip installed successfully."
            log "pip installed successfully."
            rm get-pip.py
        else
            handle_error "Failed to install pip."
        fi
    fi
}

# Function to install or update virtualenv
install_or_update_virtualenv() {
    echo "🔧 Installing or updating virtualenv..."
    if pip3 show virtualenv &> /dev/null; then
        if pip3 install --upgrade virtualenv; then
            echo "✅ virtualenv updated successfully."
            log "virtualenv updated successfully."
        else
            echo "⚠️ Warning: Failed to update virtualenv."
            log "Warning: Failed to update virtualenv."
        fi
    else
        if pip3 install virtualenv; then
            echo "✅ virtualenv installed successfully."
            log "virtualenv installed successfully."
        else
            echo "⚠️ Warning: Failed to install virtualenv."
            log "Warning: Failed to install virtualenv."
        fi
    fi
}

# Function to configure pip and virtualenv directories
configure_python_directories() {
    echo "🛠️ Configuring Python directories..."

    # Ensure directories exist
    mkdir -p "$PYTHON_DATA_HOME" "$PYTHON_CONFIG_HOME" "$PYTHON_CACHE_HOME" "$VENV_HOME" "$PIPX_HOME" "$PIPX_BIN_DIR" || handle_error "Failed to create Python directories."

    # Set pip cache directory
    if pip3 config set global.cache-dir "$PYTHON_CACHE_HOME/pip"; then
        echo "✅ pip cache directory set to '$PYTHON_CACHE_HOME/pip'."
        log "pip cache directory set to '$PYTHON_CACHE_HOME/pip'."
    else
        echo "⚠️ Warning: Failed to set pip cache directory."
        log "Warning: Failed to set pip cache directory."
    fi

    # Set virtualenv directory
    export WORKON_HOME="$VENV_HOME"
    echo "✅ virtualenvs directory set to '$WORKON_HOME'."
    log "virtualenvs directory set to '$WORKON_HOME'."

    # Set pipx directories
    export PIPX_HOME
    export PIPX_BIN_DIR
    echo "✅ pipx directories set."
    log "pipx directories set."

    # Update PATH for pipx
    export PATH="$PIPX_BIN_DIR:$PATH"

    # Add virtualenvwrapper initialization to shell profile
    local shell_profile="$HOME/.bashrc"
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        shell_profile="$HOME/.zshrc"
    fi

    if ! grep -q "virtualenvwrapper.sh" "$shell_profile"; then
        echo "export WORKON_HOME='$WORKON_HOME'" >> "$shell_profile"
        echo "source $(which virtualenvwrapper.sh)" >> "$shell_profile"
        echo "✅ Added virtualenvwrapper initialization to '$shell_profile'."
        log "Added virtualenvwrapper initialization to '$shell_profile'."
    fi

    # Ensure virtualenvwrapper.sh is installed
    if ! command -v virtualenvwrapper.sh &> /dev/null; then
        if pip3 install virtualenvwrapper; then
            echo "✅ virtualenvwrapper installed successfully."
            log "virtualenvwrapper installed successfully."
        else
            echo "⚠️ Warning: Failed to install virtualenvwrapper."
            log "Warning: Failed to install virtualenvwrapper."
        fi
    fi
}

# Function to install or update essential Python packages
install_python_packages() {
    echo "🔧 Installing essential Python packages (pipx, black, flake8, mypy, pytest)..."

    # Ensure pipx is installed
    if pip3 show pipx &> /dev/null; then
        echo "🔄 Updating pipx..."
        if pip3 install --upgrade pipx; then
            echo "✅ pipx updated successfully."
            log "pipx updated successfully."
        else
            echo "⚠️ Warning: Failed to update pipx."
            log "Warning: Failed to update pipx."
        fi
    else
        echo "📦 Installing pipx..."
        if pip3 install pipx; then
            echo "✅ pipx installed successfully."
            log "pipx installed successfully."
        else
            echo "⚠️ Warning: Failed to install pipx."
            log "Warning: Failed to install pipx."
        fi
    fi

    # Install global Python tools using pipx
    local packages=("black" "flake8" "mypy" "pytest")

    for package in "${packages[@]}"; do
        echo "Installing $package via pipx..."
        if pipx install "$package" --force; then
            echo "✅ $package installed successfully via pipx."
            log "$package installed successfully via pipx."
        else
            echo "⚠️ Warning: Failed to install $package via pipx."
            log "Warning: Failed to install $package via pipx."
        fi
    done
}

# Function to manage permissions for Python directories
manage_permissions() {
    echo "🔐 Managing permissions for Python directories..."

    check_directory_writable "$PYTHON_DATA_HOME"
    check_directory_writable "$PYTHON_CONFIG_HOME"
    check_directory_writable "$PYTHON_CACHE_HOME"
    check_directory_writable "$VENV_HOME"
    check_directory_writable "$PIPX_HOME"
    check_directory_writable "$PIPX_BIN_DIR"

    log "Permissions for Python directories are verified."
}

# Function to validate Python installation
validate_python_installation() {
    echo "✅ Validating Python installation..."

    # Check Python version
    if ! python3 --version &> /dev/null; then
        handle_error "Python is not installed correctly."
    fi

    # Check pip version
    if ! pip3 --version &> /dev/null; then
        handle_error "pip is not installed correctly."
    fi

    echo "✅ Python and pip are installed and configured correctly."
    log "Python installation validated successfully."
}

# Function to perform final cleanup tasks
perform_final_cleanup() {
    echo "🧼 Performing final cleanup tasks..."

    # Remove temporary files if they exist
    if [[ -d "$PYTHON_CACHE_HOME/tmp" ]]; then
        echo "🗑️ Cleaning up temporary files in $PYTHON_CACHE_HOME/tmp..."
        rm -rf "${PYTHON_CACHE_HOME:?}/tmp" || log "⚠️ Warning: Failed to remove temporary files in '$PYTHON_CACHE_HOME/tmp'."
        log "Temporary files in '$PYTHON_CACHE_HOME/tmp' removed."
    fi

    echo "🧼 Final cleanup completed."
    log "Final cleanup tasks completed."
}

# Function to backup Python configurations
backup_python_configuration() {
    echo "🗄️ Backing up Python configurations..."

    local backup_dir
    backup_dir="${XDG_STATE_HOME:-$HOME/.local/state}/backups/python_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"

    if [[ -d "$PYTHON_CONFIG_HOME" ]]; then
        tar --exclude='__pycache__' --exclude-vcs -czf "$backup_dir/python_config_backup.tar.gz" -C "$PYTHON_CONFIG_HOME" . || log "⚠️ Warning: Could not backup Python config directory."
    fi

    if [[ -d "$PYTHON_DATA_HOME" ]]; then
        tar --exclude='__pycache__' --exclude-vcs -czf "$backup_dir/python_data_backup.tar.gz" -C "$PYTHON_DATA_HOME" . || log "⚠️ Warning: Could not backup Python data directory."
    fi

    if [[ -d "$PYTHON_CACHE_HOME" ]]; then
        tar --exclude='__pycache__' --exclude-vcs -czf "$backup_dir/python_cache_backup.tar.gz" -C "$PYTHON_CACHE_HOME" . || log "⚠️ Warning: Could not backup Python cache directory."
    fi

    echo "✅ Backup completed at '$backup_dir'."
    log "Backup completed at '$backup_dir'."
}

# Function to optimize Python environment
optimize_python_service() {
    echo "🔧 Starting Python environment optimization..."

    # Step 1: Install or update Python
    echo "📦 Installing or updating Python..."
    install_or_update_python

    # Step 2: Install or update pip
    echo "🔄 Installing or updating pip..."
    install_or_update_pip

    # Step 3: Install or update virtualenv
    echo "🔧 Installing or updating virtualenv..."
    install_or_update_virtualenv

    # Step 4: Configure Python directories
    echo "🛠️ Configuring Python directories..."
    configure_python_directories

    # Step 5: Install or update essential Python packages
    echo "🔧 Installing or updating essential Python packages..."
    install_python_packages

    # Step 6: Manage permissions for Python directories
    echo "🔐 Managing permissions for Python directories..."
    manage_permissions

    # Step 7: Backup Python configurations
    echo "🗄️ Backing up Python configurations..."
    backup_python_configuration

    # Step 8: Validate Python installation
    echo "✅ Validating Python installation..."
    validate_python_installation

    # Step 9: Final cleanup
    echo "🧼 Performing final cleanup..."
    perform_final_cleanup

    # Final summary
    echo "🎉 Python environment optimization complete."
    echo -e "${CYAN}PYTHON_DATA_HOME:${NC} $PYTHON_DATA_HOME"
    echo -e "${CYAN}PYTHON_CONFIG_HOME:${NC} $PYTHON_CONFIG_HOME"
    echo -e "${CYAN}PYTHON_CACHE_HOME:${NC} $PYTHON_CACHE_HOME"
    echo -e "${CYAN}VENV_HOME:${NC} $VENV_HOME"
    echo -e "${CYAN}PIPX_HOME:${NC} $PIPX_HOME"
    echo -e "${CYAN}Python version:${NC} $(python3 --version)"
    echo -e "${CYAN}pip version:${NC} $(pip3 --version)"
}

# Export necessary functions for use by the controller
export -f log
export -f handle_error
export -f check_directory_writable
export -f install_or_update_python
export -f install_or_update_pip
export -f install_or_update_virtualenv
export -f configure_python_directories
export -f install_python_packages
export -f manage_permissions
export -f validate_python_installation
export -f perform_final_cleanup
export -f backup_python_configuration
export -f optimize_python_service

# The controller script will call optimize_python_service as needed, so there is no need for direct invocation here.
