#!/bin/bash

# Function to optimize Poetry and Python environment
function optimize_poetry_service() {
    echo "Optimizing Poetry and Python environment..."

    # Step 1: Check if Poetry is installed
    if command -v poetry &> /dev/null; then
        echo "Poetry is already installed."
    else
        echo "Poetry is not installed. Installing Poetry..."
        install_poetry
    fi

    # Step 2: Ensure Poetry is up to date
    update_poetry

    # Step 3: Set up Poetry virtual environments and dependencies for the current project
    echo "Setting up Poetry virtual environments and project dependencies..."
    poetry_setup_virtualenv_and_dependencies

    # Step 4: Set up environment variables for Poetry
    echo "Setting up Poetry environment variables..."
    export POETRY_HOME="$XDG_CONFIG_HOME/poetry"
    export POETRY_CACHE_DIR="$XDG_CACHE_HOME/poetry"
    export POETRY_VIRTUALENVS_PATH="$XDG_DATA_HOME/poetry/virtualenvs"
    export PATH="$POETRY_HOME/bin:$PATH"

    add_to_zenvironment "POETRY_HOME" "$POETRY_HOME"
    add_to_zenvironment "POETRY_CACHE_DIR" "$POETRY_CACHE_DIR"
    add_to_zenvironment "POETRY_VIRTUALENVS_PATH" "$POETRY_VIRTUALENVS_PATH"
    add_to_zenvironment "PATH" "$POETRY_HOME/bin:$PATH"

    # Step 5: Check permissions for Poetry-related directories
    check_directory_writable "$POETRY_HOME"
    check_directory_writable "$POETRY_CACHE_DIR"
    check_directory_writable "$POETRY_VIRTUALENVS_PATH"

    # Step 6: Install optional testing and linting tools (pytest, flake8)
    echo "Installing optional testing and linting tools (pytest, flake8)..."
    poetry_add_dev_dependencies

    # Step 7: Clean up and consolidate Poetry directories
    echo "Consolidating Poetry directories..."
    consolidate_directories "$HOME/.poetry" "$POETRY_HOME"
    remove_empty_directories "$HOME/.poetry"

    # Step 8: Backup current Poetry configuration (optional)
    backup_poetry_configuration

    # Step 9: Testing and Verification
    echo "Verifying Poetry setup and project dependencies..."
    verify_poetry_setup

    # Step 10: Final cleanup and summary
    echo "Performing final cleanup..."
    echo "Poetry and Python environment optimization complete."
    echo "Poetry version: $(poetry --version)"
    echo "POETRY_HOME: $POETRY_HOME"
    echo "POETRY_CACHE_DIR: $POETRY_CACHE_DIR"
}

# Helper function to install Poetry
install_poetry() {
    echo "Installing Poetry via the official installer..."
    curl -sSL https://install.python-poetry.org | python3 -
    export POETRY_HOME="$XDG_CONFIG_HOME/poetry"
    [ -s "$POETRY_HOME/bin/poetry" ] && \. "$POETRY_HOME/env"
}

# Helper function to update Poetry to the latest version
update_poetry() {
    echo "Ensuring Poetry is up to date..."
    poetry self update
}

# Helper function to set up virtual environments and dependencies for a project
poetry_setup_virtualenv_and_dependencies() {
    if [ -f "pyproject.toml" ]; then
        echo "pyproject.toml found. Installing project dependencies..."
        poetry install
    else
        echo "Error: No pyproject.toml found in the current directory."
        exit 1
    fi

    # Optionally, create a new virtual environment if not already present
    if [ -z "$(poetry env info --path 2>/dev/null)" ]; then
        echo "No virtual environment found. Creating a new one..."
        poetry env use python3
    fi
}

# Helper function to add development dependencies (pytest, flake8)
poetry_add_dev_dependencies() {
    poetry add --dev pytest
    poetry add --dev flake8
}

# Helper function to backup current Poetry configuration
backup_poetry_configuration() {
    echo "Backing up Poetry configuration..."

    local backup_dir="$HOME/.poetry_backup_$(date +%Y%m%d)"
    mkdir -p "$backup_dir"
    cp -r "$POETRY_HOME" "$backup_dir"
    cp -r "$POETRY_CACHE_DIR" "$backup_dir"
    cp -r "$POETRY_VIRTUALENVS_PATH" "$backup_dir"

    echo "Backup completed: $backup_dir"
}

# Helper function to verify Poetry setup and project dependencies
verify_poetry_setup() {
    echo "Verifying Poetry and Python environment setup..."

    # Check Poetry installation
    if command -v poetry &> /dev/null; then
        echo "Poetry is installed and functioning correctly."
    else
        echo "Error: Poetry is not functioning correctly. Please check your setup."
        exit 1
    fi

    # Verify project dependencies
    if [ -f "pyproject.toml" ]; then
        echo "Verifying project dependencies..."
        poetry check
    else
        echo "No pyproject.toml found. Skipping dependency verification."
    fi

    # Check if virtual environment is active
    if [ -z "$(poetry env info --path 2>/dev/null)" ]; then
        echo "Error: Virtual environment is not active. Please check your Poetry setup."
        exit 1
    else
        echo "Virtual environment is active and configured correctly."
    fi
}

# The controller script will call optimize_poetry_service as needed, so there is no need for direct invocation in this file.
