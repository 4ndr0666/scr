#!/bin/bash
# File: optimize_go.sh
# Author: 4ndr0666
# Edited: 11-24-24
# Description: Optimizes Go environment in alignment with XDG Base Directory Specifications.

# Function to optimize Go environment
function optimize_go_service() {
    echo "Starting Go environment optimization..."

    # Step 1: Check if Go is installed and up to date
    echo "Checking if Go is installed and up to date..."
    if ! command -v go &> /dev/null; then
        echo "Go is not installed. Installing Go..."
        install_go
    else
        current_go_version=$(go version | awk '{print $3}')
        latest_go_version=$(get_latest_go_version)
        if [[ "$current_go_version" != "$latest_go_version" ]]; then
            echo "Go is outdated. Updating to version $latest_go_version..."
            update_go "$latest_go_version"
        else
            echo "Go is already up to date: $current_go_version."
        fi
    fi

    # Step 2: Ensure GOPATH, GOROOT, and GOMODCACHE are correctly set
    echo "Ensuring Go environment variables (GOPATH, GOROOT, GOMODCACHE) are set correctly..."
    setup_go_paths

    # Step 3: Perform directory consolidation and cleanup
    echo "Performing directory consolidation and cleanup..."
    consolidate_go_directories

    # Step 4: Install or update Go tools
    echo "Ensuring essential Go tools are installed and up to date..."
    install_go_tools

    # Step 5: Check and manage permissions for Go directories
    echo "Checking and managing permissions for Go directories..."
    manage_permissions

    # Step 6: Manage multi-version Go support (if required)
    echo "Managing multi-version Go support (if applicable)..."
    manage_go_versions

    # Step 7: Perform basic validation of Go installation
    echo "Validating Go installation..."
    validate_go_installation

    # Step 8: Final cleanup
    echo "Performing final cleanup..."
    perform_final_cleanup

    # Final summary
    echo "Go environment optimization complete."
    echo "GOPATH: $GOPATH"
    echo "GOROOT: $GOROOT"
    echo "GOMODCACHE: $GOMODCACHE"
    echo "Go version: $(go version)"
}

# Function to install Go
install_go() {
    if command -v pacman &> /dev/null; then
        echo "Installing Go using pacman..."
        sudo pacman -S --noconfirm go || handle_error "Failed to install Go with pacman."
    elif command -v apt-get &> /dev/null; then
        echo "Installing Go using apt-get..."
        sudo apt-get update && sudo apt-get install -y golang || handle_error "Failed to install Go with apt-get."
    elif command -v dnf &> /dev/null; then
        echo "Installing Go using dnf..."
        sudo dnf install -y golang || handle_error "Failed to install Go with dnf."
    elif command -v brew &> /dev/null; then
        echo "Installing Go using Homebrew..."
        brew install go || handle_error "Failed to install Go with Homebrew."
    else
        echo "Error: Unsupported package manager. Please install Go manually."
        exit 1
    fi
    echo "Go installed successfully."
}

# Function to update Go to the latest version
update_go() {
    local version=$1
    if command -v pacman &> /dev/null; then
        echo "Updating Go to version $version using pacman..."
        sudo pacman -Syu go || handle_error "Failed to update Go with pacman."
    elif command -v apt-get &> /dev/null; then
        echo "Updating Go using apt-get..."
        sudo apt-get update && sudo apt-get upgrade -y golang || handle_error "Failed to update Go with apt-get."
    elif command -v dnf &> /dev/null; then
        echo "Updating Go using dnf..."
        sudo dnf upgrade -y golang || handle_error "Failed to update Go with dnf."
    elif command -v brew &> /dev/null; then
        echo "Updating Go using Homebrew..."
        brew upgrade go || handle_error "Failed to update Go with Homebrew."
    else
        echo "Error: Unsupported package manager. Please update Go manually."
        exit 1
    fi
    echo "Go updated successfully to version $version."
}

# Function to get the latest Go version
get_latest_go_version() {
    if command -v pacman &> /dev/null; then
        latest_go_version=$(pacman -Si go | grep Version | awk '{print $3}')
    elif command -v apt-get &> /dev/null; then
        latest_go_version=$(apt-cache policy golang | grep Candidate | awk '{print $2}')
    elif command -v dnf &> /dev/null; then
        latest_go_version=$(dnf info golang | grep Version | awk '{print $3}')
    elif command -v brew &> /dev/null; then
        latest_go_version=$(brew info go | grep stable | awk '{print $3}')
    else
        echo "Error: Unsupported package manager."
        exit 1
    fi
    echo "$latest_go_version"
}

# Function to set up Go paths (GOPATH, GOROOT, GOMODCACHE)
setup_go_paths() {
    echo "Setting up Go environment paths..."
    export GOPATH="$XDG_DATA_HOME/go"
    export GOMODCACHE="$XDG_CACHE_HOME/go/mod"
    export GOROOT=$(go env GOROOT)  # Dynamically determine GOROOT

    # Environment variables are already set in .zprofile, so no need to modify them here.
    echo "GOPATH: $GOPATH"
    echo "GOMODCACHE: $GOMODCACHE"
    echo "GOROOT: $GOROOT"
}

# Function to consolidate Go directories
consolidate_go_directories() {
    echo "Consolidating Go directories..."
    mkdir -p "$GOPATH" "$GOMODCACHE"
    check_directory_writable "$GOPATH"
    check_directory_writable "$GOMODCACHE"
}

# Function to install essential Go tools
install_go_tools() {
    echo "Installing Go tools (goimports, golangci-lint, gopls)..."
    go install golang.org/x/tools/cmd/goimports@latest
    go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
    go install golang.org/x/tools/gopls@latest  # Go Language Server
}

# Function to manage permissions for Go directories
manage_permissions() {
    echo "Managing permissions for Go directories..."
    check_directory_writable "$GOPATH"
    check_directory_writable "$GOMODCACHE"
}

# Function to update environment variables
update_environment_variables() {
    echo "Environment variables are managed in .zprofile. No action needed here."
}

# Function to manage multi-version Go support
manage_go_versions() {
    echo "Managing multi-version Go support..."
    if ! command -v goenv &> /dev/null; then
        echo "Go Version Manager (goenv) is not installed. Installing goenv..."
        git clone https://github.com/syndbg/goenv.git "$XDG_DATA_HOME/goenv" || handle_error "Failed to clone goenv repository."
        export GOENV_ROOT="$XDG_DATA_HOME/goenv"
        export PATH="$GOENV_ROOT/bin:$PATH"
        # Assuming 'add_to_shell_config' has been removed from service scripts
        echo "export GOENV_ROOT=\"$GOENV_ROOT\"" >> "$ZDOTDIR/.zprofile"
        echo "export PATH=\"$GOENV_ROOT/bin:\$PATH\"" >> "$ZDOTDIR/.zprofile"
        # Source goenv
        # shellcheck source=/dev/null
        [ -s "$GOENV_ROOT/bin/goenv" ] && eval "$(goenv init -)" || handle_error "Failed to initialize goenv."
    else
        echo "goenv is already installed."
    fi
}

# Function to validate Go installation
validate_go_installation() {
    echo "Validating Go installation..."
    if ! go version &> /dev/null; then
        echo "Error: Go is not installed correctly."
        exit 1
    fi

    if [[ ! -d "$GOPATH" ]]; then
        echo "Error: GOPATH is not set correctly."
        exit 1
    fi

    if [[ ! -d "$GOMODCACHE" ]]; then
        echo "Error: GOMODCACHE is not set correctly."
        exit 1
    fi

    echo "Go is installed and configured correctly."
}

# Function to perform final cleanup tasks
perform_final_cleanup() {
    echo "Performing final cleanup tasks..."
    # Remove unused files, cache, or temporary directories
    if [[ -d "$GOPATH/tmp" ]]; then
        echo "Cleaning up temporary files in $GOPATH/tmp..."
        rm -rf "$GOPATH/tmp"
    fi
    if [[ -d "$GOMODCACHE/tmp" ]]; then
        echo "Cleaning up temporary files in $GOMODCACHE/tmp..."
        rm -rf "$GOMODCACHE/tmp"
    fi
    echo "Final cleanup completed."
}

# Helper function: Handle errors
handle_error() {
    echo "Error: $1" >&2
    exit 1
}
