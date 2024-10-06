#!/bin/bash

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

    # Step 6: Add environment variables to the shell configuration
    echo "Adding environment variables to configuration..."
    update_environment_variables

    # Step 7: Handle multi-version Go support (if required)
    echo "Managing multi-version Go support (if applicable)..."
    manage_go_versions

    # Step 8: Perform basic validation of Go installation
    echo "Validating Go installation..."
    validate_go_installation

    # Step 9: Final cleanup
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
        sudo pacman -Syu go
    elif command -v apt-get &> /dev/null; then
        echo "Installing Go using apt-get..."
        sudo apt-get update && sudo apt-get install -y golang
    elif command -v dnf &> /dev/null; then
        echo "Installing Go using dnf..."
        sudo dnf install -y golang
    elif command -v brew &> /dev/null; then
        echo "Installing Go using Homebrew..."
        brew install go
    else
        echo "Error: Unsupported package manager. Please install Go manually."
        exit 1
    fi
}

# Function to update Go to the latest version
update_go() {
    local version=$1
    if command -v pacman &> /dev/null; then
        echo "Updating Go to version $version using pacman..."
        sudo pacman -Syu go
    elif command -v apt-get &> /dev/null; then
        echo "Updating Go using apt-get..."
        sudo apt-get update && sudo apt-get upgrade -y golang
    elif command -v dnf &> /dev/null; then
        echo "Updating Go using dnf..."
        sudo dnf upgrade -y golang
    elif command -v brew &> /dev/null; then
        echo "Updating Go using Homebrew..."
        brew upgrade go
    else
        echo "Error: Unsupported package manager. Please update Go manually."
        exit 1
    fi
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
    export GOPATH="${XDG_DATA_HOME:-$HOME}/go"
    export GOMODCACHE="${XDG_CACHE_HOME:-$HOME/.cache}/go/mod"
    export GOROOT=$(go env GOROOT)  # Dynamically determine GOROOT

    add_to_zenvironment "GOPATH" "$GOPATH"
    add_to_zenvironment "GOMODCACHE" "$GOMODCACHE"
    add_to_zenvironment "GOROOT" "$GOROOT"
    add_to_zenvironment "PATH" "$GOPATH/bin:$GOROOT/bin:$PATH"

    echo "GOPATH: $GOPATH"
    echo "GOMODCACHE: $GOMODCACHE"
    echo "GOROOT: $GOROOT"
}

# Function to consolidate Go directories
consolidate_go_directories() {
    echo "Consolidating Go directories..."
    create_directory_if_not_exists "$GOPATH"
    create_directory_if_not_exists "$GOMODCACHE"
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
    echo "Adding environment variables to the shell configuration..."
    add_to_zenvironment "GOPATH" "$GOPATH"
    add_to_zenvironment "GOMODCACHE" "$GOMODCACHE"
    add_to_zenvironment "GOROOT" "$GOROOT"
    add_to_zenvironment "PATH" "$GOPATH/bin:$GOROOT/bin:$PATH"
}

# Function to manage multi-version Go support
manage_go_versions() {
    echo "Managing multi-version Go support..."
    if ! command -v goenv &> /dev/null; then
        echo "Go Version Manager (goenv) is not installed. Installing goenv..."
        git clone https://github.com/syndbg/goenv.git ~/.goenv
        export GOENV_ROOT="$HOME/.goenv"
        export PATH="$GOENV_ROOT/bin:$PATH"
        add_to_zenvironment "GOENV_ROOT" "$GOENV_ROOT"
        add_to_zenvironment "PATH" "$GOENV_ROOT/bin:$PATH"
    else
        echo "Goenv is already installed. To manage versions, use 'goenv install <version>'"
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

# The controller script will call optimize_go_service as needed, so there is no need for direct invocation in this file.
