#!/bin/bash
# File: optimize_meson.sh
# Author: 4ndr0666
# Edited: 11-24-24
# Description: Optimizes Meson build system environment in alignment with XDG Base Directory Specifications.

# Function to optimize Meson build system environment
function optimize_meson_service() {
    echo "Optimizing Meson build system environment..."

    # Step 1: Check if Meson is installed
    current_meson_version=$(meson --version 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        echo "Meson is not installed. Installing Meson..."
        install_meson
    else
        echo "Meson is already installed: $current_meson_version"
    fi

    # Step 2: Ensure Ninja build system is installed (required for Meson)
    check_ninja_installation

    # Step 3: Ensure Python is set up and Meson dependencies are installed
    echo "Ensuring Python environment and Meson dependencies are installed..."
    setup_python_environment_for_meson

    # Step 4: Set up environment variables for Meson and Ninja
    echo "Setting up Meson and Ninja environment variables..."
    setup_meson_environment

    # Step 5: Install optional testing and linting tools (meson test, meson lint)
    echo "Installing optional tools for Meson testing and linting..."
    pip_install_or_update "meson-lint"
    pip_install_or_update "meson-test"

    # Step 6: Check permissions for Meson and Ninja directories
    check_directory_writable "$MESON_HOME"

    # Step 7: Configure additional backends or options (optional)
    echo "Configuring additional Meson backends (optional)..."
    configure_additional_meson_backends

    # Step 8: Clean up and consolidate Meson directories
    echo "Consolidating Meson directories..."
    consolidate_directories "$HOME/.meson" "$MESON_HOME"
    remove_empty_directories "$HOME/.meson"

    # Step 9: Backup current Meson configuration (optional)
    backup_meson_configuration

    # Step 10: Final cleanup and summary
    echo "Performing final cleanup..."
    echo "Meson and Ninja environment optimization complete."
    echo "Meson version: $(meson --version)"
    echo "Ninja version: $(ninja --version)"
    echo "MESON_HOME: $MESON_HOME"
}

# Helper function to install Meson via pip or package managers
install_meson() {
    if command -v pip &> /dev/null; then
        echo "Installing Meson via pip..."
        pip install --user meson || handle_error "Failed to install Meson with pip."
    elif command -v pacman &> /dev/null; then
        echo "Installing Meson via pacman..."
        sudo pacman -S --noconfirm meson || handle_error "Failed to install Meson with pacman."
    elif command -v apt-get &> /dev/null; then
        echo "Installing Meson via apt-get..."
        sudo apt-get install -y meson || handle_error "Failed to install Meson with apt-get."
    elif command -v dnf &> /dev/null; then
        echo "Installing Meson via dnf..."
        sudo dnf install -y meson || handle_error "Failed to install Meson with dnf."
    elif command -v brew &> /dev/null; then
        echo "Installing Meson via Homebrew..."
        brew install meson || handle_error "Failed to install Meson with Homebrew."
    elif command -v zypper &> /dev/null; then
        echo "Installing Meson via zypper..."
        sudo zypper install -y meson || handle_error "Failed to install Meson with zypper."
    else
        echo "Unsupported package manager. Please install Meson manually."
        exit 1
    fi
    echo "Meson installed successfully."
}

# Helper function to check if Ninja build system is installed
check_ninja_installation() {
    if command -v ninja &> /dev/null; then
        echo "Ninja build system is already installed."
    else
        echo "Ninja build system is not installed. Installing Ninja..."
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
        echo "Unsupported package manager. Please install Ninja manually."
        exit 1
    fi
    echo "Ninja installed successfully."
}

# Helper function to set up Python environment and ensure Meson dependencies are installed
setup_python_environment_for_meson() {
    if command -v python3 &> /dev/null; then
        echo "Python3 is already installed."
    else
        echo "Python3 is not installed. Installing Python3..."
        install_python3
    fi

    pip_install_or_update "meson"

    # Optionally, create a virtual environment for Meson
    if [[ -d "$MESON_HOME/venv" ]]; then
        echo "Virtual environment already exists for Meson. Activating..."
        source "$MESON_HOME/venv/bin/activate"
    elif [[ -z "$VIRTUAL_ENV" ]]; then
        echo "Creating a new virtual environment for Meson..."
        python3 -m venv "$MESON_HOME/venv" || handle_error "Failed to create virtual environment."
        source "$MESON_HOME/venv/bin/activate"
        pip install --upgrade pip
    else
        echo "A virtual environment is already active."
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
        echo "Unsupported package manager. Please install Python manually."
        exit 1
    fi
    echo "Python3 installed successfully."
}

# Helper function to install or update Python packages
pip_install_or_update() {
    local package_name=$1

    if pip show "$package_name" &> /dev/null; then
        echo "Updating $package_name..."
        pip install --user --upgrade "$package_name" || handle_error "Failed to update $package_name."
    else
        echo "Installing $package_name via pip..."
        pip install --user "$package_name" || handle_error "Failed to install $package_name."
    fi
}

# Helper function to set up Meson and Ninja environment variables
setup_meson_environment() {
    # Check if environment variables are already set
    if [[ -z "$MESON_HOME" ]]; then
        export MESON_HOME="$XDG_CONFIG_HOME/meson"
    fi
    export PATH="$MESON_HOME/bin:$PATH"

    # Environment variables are already set in .zprofile, so no need to modify them here.
    echo "MESON_HOME: $MESON_HOME"
    echo "Updated PATH with MESON_HOME/bin."
}

# Helper function to configure additional Meson backends or options (optional)
configure_additional_meson_backends() {
    echo "Configuring additional Meson backends (optional)..."
    # For example, setting up a custom build directory
    if [[ -d "build" ]]; then
        echo "Build directory already exists. Using existing build directory."
    else
        echo "Creating a new build directory for Meson..."
        meson setup build --backend=ninja || handle_error "Failed to set up Meson build directory."
    fi
}

# Helper function to backup current Meson configuration
backup_meson_configuration() {
    if [[ -d "$MESON_HOME" ]]; then
        echo "Backing up Meson configuration..."

        local backup_dir
        backup_dir="$XDG_STATE_HOME/backups/meson_backup_$(date +%Y%m%d)"
        mkdir -p "$backup_dir"
        cp -r "$MESON_HOME" "$backup_dir" 2>/dev/null || echo "Warning: Could not copy $MESON_HOME"

        echo "Backup completed: $backup_dir"
    else
        echo "Meson configuration directory does not exist. Skipping backup."
    fi
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
