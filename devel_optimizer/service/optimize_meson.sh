#!/bin/bash

# Function to optimize Meson environment
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
    export MESON_HOME="$XDG_CONFIG_HOME/meson"
    export PATH="$MESON_HOME/bin:$PATH"

    add_to_zenvironment "MESON_HOME" "$MESON_HOME"
    add_to_zenvironment "PATH" "$MESON_HOME/bin:$PATH"

    # Step 5: Install optional testing and linting tools (meson test, meson lint)
    echo "Installing optional tools for Meson testing and linting..."
    pip_install_or_update "meson-lint"
    pip_install_or_update "meson-test"

    # Step 6: Check permissions for Meson and Ninja directories
    check_directory_writable "$MESON_HOME"

    # Step 7: Configure additional backends or options (optional)
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
        pip install --user meson
    elif command -v pacman &> /dev/null; then
        echo "Installing Meson via pacman..."
        sudo pacman -S meson
    elif command -v apt-get &> /dev/null; then
        sudo apt-get install -y meson
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y meson
    else
        echo "Unsupported package manager. Please install Meson manually."
        exit 1
    fi
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
        sudo pacman -S ninja
    elif command -v apt-get &> /dev/null; then
        sudo apt-get install -y ninja-build
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y ninja-build
    else
        echo "Unsupported package manager. Please install Ninja manually."
        exit 1
    fi
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
    else
        echo "Creating a new virtual environment for Meson..."
        python3 -m venv "$MESON_HOME/venv"
        source "$MESON_HOME/venv/bin/activate"
        pip install --upgrade pip
    fi
}

# Helper function to install Python via package managers
install_python3() {
    if command -v pacman &> /dev/null; then
        sudo pacman -S python
    elif command -v apt-get &> /dev/null; then
        sudo apt-get install -y python3
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y python3
    else
        echo "Unsupported package manager. Please install Python manually."
        exit 1
    fi
}

# Helper function to install or update Python packages
pip_install_or_update() {
    local package_name=$1

    if pip show "$package_name" &> /dev/null; then
        echo "Updating $package_name..."
        pip install --user --upgrade "$package_name"
    else
        echo "Installing $package_name via pip..."
        pip install --user "$package_name"
    fi
}

# Helper function to configure additional Meson backends or options (optional)
configure_additional_meson_backends() {
    echo "Configuring additional Meson backends (optional)..."
    # For example, setting up a custom build directory
    if [[ -d "build" ]]; then
        echo "Build directory already exists. Using existing build directory."
    else
        echo "Creating a new build directory for Meson..."
        meson setup build --backend=ninja
    fi
}

# Helper function to backup current Meson configuration
backup_meson_configuration() {
    echo "Backing up Meson configuration..."

    local backup_dir="$HOME/.meson_backup_$(date +%Y%m%d)"
    mkdir -p "$backup_dir"
    cp -r "$MESON_HOME" "$backup_dir"

    echo "Backup completed: $backup_dir"
}

# The controller script will call optimize_meson_service as needed, so there is no need for direct invocation in this file.
