#!/bin/bash

# File: optimize_venv.sh
# Author: 4ndr0666
# Edited: 10-20-24
# Description: Optimizes Python environment using venv and pipx in alignment with XDG Base Directory Specifications.

# Function to optimize Python environment using venv and pipx
function optimize_venv_service() {
    echo "Optimizing Python environment using venv and pipx..."

    # Step 1: Check if Python3 is installed
    if command -v python3 &> /dev/null; then
        echo "Python3 is already installed: $(python3 --version)"
    else
        echo "Python3 is not installed. Please install Python3 manually."
        exit 1
    fi

    # Step 2: Set up a new virtual environment if not already present
    echo "Setting up virtual environment..."
    if [ ! -d ".venv" ]; then
        echo "Creating new virtual environment..."
        python3 -m venv "$VENV_HOME/.venv" || handle_error "Failed to create virtual environment."
    else
        echo "Virtual environment already exists."
    fi

    # Step 3: Activate the virtual environment
    echo "Activating the virtual environment..."
    source "$VENV_HOME/.venv/bin/activate" --prompt '💀 '

    # Step 4: Install project dependencies if requirements.txt exists
    if [ -f "requirements.txt" ]; then
        echo "Installing project dependencies from requirements.txt..."
        pip install -r requirements.txt || handle_error "Failed to install project dependencies."
    else
        echo "No requirements.txt found. Skipping dependency installation."
    fi

    # Step 5: Install development dependencies if requirements-dev.txt exists
    if [ -f "requirements-dev.txt" ]; then
        echo "Installing development dependencies from requirements-dev.txt..."
        pip install -r requirements-dev.txt || handle_error "Failed to install development dependencies."
    else
        echo "No requirements-dev.txt found. Skipping development dependency installation."
    fi

    # Step 6: Ensure pipx is installed and install global Python tools
    echo "Ensuring pipx is installed..."
    if command -v pipx &> /dev/null; then
        echo "pipx is already installed."
    else
        echo "pipx is not installed. Installing pipx..."
        python3 -m pip install --user pipx || handle_error "Failed to install pipx."
        python3 -m pipx ensurepath || handle_error "Failed to ensure pipx path."
        export PATH="$PIPX_HOME/bin:$PATH"
    fi

    # Step 7: Install or update global Python tools via pipx
    echo "Installing/updating global Python tools using pipx..."
    pipx_install_or_update "black"
    pipx_install_or_update "flake8"
    pipx_install_or_update "mypy"
    pipx_install_or_update "pytest"

    # Step 8: Set up environment variables
    echo "Setting up environment variables for venv and pipx..."
    export VENV_HOME="$XDG_DATA_HOME/virtualenv"
    export PIPX_HOME="$XDG_DATA_HOME/pipx"
    export PATH="$VENV_HOME/.venv/bin:$PIPX_HOME/bin:$PATH"

    # Environment variables are already set in .zprofile, so no need to modify them here.
    echo "VENV_HOME: $VENV_HOME"
    echo "PIPX_HOME: $PIPX_HOME"

    # Step 9: Check permissions for directories
    check_directory_writable "$VENV_HOME/.venv"
    check_directory_writable "$PIPX_HOME"

    # Step 10: Final cleanup and summary
    echo "Performing final cleanup..."
    echo "Python environment optimization complete."
    echo "Virtual environment located at: $VENV_HOME/.venv"
    echo "Global tools managed by pipx are installed in: $PIPX_HOME/bin"
}

# Helper function to install or update pipx packages
pipx_install_or_update() {
    local tool_name=$1

    if pipx list | grep "$tool_name" &> /dev/null; then
        echo "Updating $tool_name..."
        pipx upgrade "$tool_name" || echo "Warning: Failed to update $tool_name."
    else
        echo "Installing $tool_name via pipx..."
        pipx install "$tool_name" || echo "Warning: Failed to install $tool_name."
    fi
}

# Helper function to backup current Python configuration
backup_python_configuration() {
    echo "Backing up Python virtual environments and pipx configurations..."

    local backup_dir="$XDG_STATE_HOME/backups/python_backup_$(date +%Y%m%d)"
    mkdir -p "$backup_dir"

    if [[ -d "$VENV_HOME/.venv" ]]; then
        cp -r "$VENV_HOME/.venv" "$backup_dir/venv/" || echo "Warning: Could not copy virtual environment."
    fi

    if [[ -d "$PIPX_HOME" ]]; then
        cp -r "$PIPX_HOME" "$backup_dir/pipx/" || echo "Warning: Could not copy pipx directory."
    fi

    echo "Backup completed: $backup_dir"
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
