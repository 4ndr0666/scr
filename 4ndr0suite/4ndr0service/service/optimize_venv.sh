#!/bin/bash

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
        python3 -m venv .venv
    else
        echo "Virtual environment already exists."
    fi

    # Step 3: Activate the virtual environment
    echo "Activating the virtual environment..."
    source .venv/bin/activate --prompt '💀 '

    # Step 4: Install project dependencies if requirements.txt exists
    if [ -f "requirements.txt" ]; then
        echo "Installing project dependencies from requirements.txt..."
        pip install -r requirements.txt
    else
        echo "No requirements.txt found. Skipping dependency installation."
    fi

    # Step 5: Install development dependencies if requirements-dev.txt exists
    if [ -f "requirements-dev.txt" ]; then
        echo "Installing development dependencies from requirements-dev.txt..."
        pip install -r requirements-dev.txt
    else
        echo "No requirements-dev.txt found. Skipping development dependency installation."
    fi

    # Step 6: Ensure pipx is installed and install global Python tools
    echo "Ensuring pipx is installed..."
    if command -v pipx &> /dev/null; then
        echo "pipx is already installed."
    else
        echo "pipx is not installed. Installing pipx..."
        python3 -m pip install --user pipx
        python3 -m pipx ensurepath
    fi

    # Step 7: Install or update global Python tools via pipx
    echo "Installing/updating global Python tools using pipx..."
    pipx_install_or_update "black"
    pipx_install_or_update "flake8"
    pipx_install_or_update "mypy"
    pipx_install_or_update "pytest"

    # Step 8: Set up environment variables
    echo "Setting up environment variables for venv and pipx..."
    export VENV_HOME="$(pwd)/.venv"
    export PIPX_HOME="$HOME/.local/pipx"
    export PATH="$VENV_HOME/bin:$PIPX_HOME/bin:$PATH"

    add_to_zenvironment "VENV_HOME" "$VENV_HOME"
    add_to_zenvironment "PIPX_HOME" "$PIPX_HOME"
    add_to_zenvironment "PATH" "$VENV_HOME/bin:$PIPX_HOME/bin:$PATH"

    # Step 9: Check permissions for directories
    check_directory_writable "$VENV_HOME"
    check_directory_writable "$PIPX_HOME"

    # Step 10: Final cleanup and summary
    echo "Performing final cleanup..."
    echo "Python environment optimization complete."
    echo "Virtual environment located at: $VENV_HOME"
    echo "Global tools managed by pipx are installed in: $PIPX_HOME"
}

# Helper function to install or update pipx packages
pipx_install_or_update() {
    local tool_name=$1

    if pipx list | grep "$tool_name" &> /dev/null; then
        echo "Updating $tool_name..."
        pipx upgrade "$tool_name"
    else
        echo "Installing $tool_name via pipx..."
        pipx install "$tool_name"
    fi
}

# The controller script will call optimize_venv_service as needed, so there is no need for direct invocation in this file.
