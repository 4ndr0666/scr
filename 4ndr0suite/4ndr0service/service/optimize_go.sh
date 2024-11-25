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
        if sudo pacman -S --noconfirm go; then
            echo "Go installed successfully using pacman."
        else
            handle_error "Failed to install Go with pacman."
        fi
    elif command -v apt-get &> /dev/null; then
        echo "Installing Go using apt-get..."
        if sudo apt-get update && sudo apt-get install -y golang; then
            echo "Go installed successfully using apt-get."
        else
            handle_error "Failed to install Go with apt-get."
        fi
    elif command -v dnf &> /dev/null; then
        echo "Installing Go using dnf..."
        if sudo dnf install -y golang; then
            echo "Go installed successfully using dnf."
        else
            handle_error "Failed to install Go with dnf."
        fi
    elif command -v brew &> /dev/null; then
        echo "Installing Go using Homebrew..."
        if brew install go; then
            echo "Go installed successfully using Homebrew."
        else
            handle_error "Failed to install Go with Homebrew."
        fi
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
        if sudo pacman -Syu go; then
            echo "Go updated successfully to version $version using pacman."
        else
            handle_error "Failed to update Go with pacman."
        fi
    elif command -v apt-get &> /dev/null; then
        echo "Updating Go using apt-get..."
        if sudo apt-get update && sudo apt-get upgrade -y golang; then
            echo "Go updated successfully to version $version using apt-get."
        else
            handle_error "Failed to update Go with apt-get."
        fi
    elif command -v dnf &> /dev/null; then
        echo "Updating Go using dnf..."
        if sudo dnf upgrade -y golang; then
            echo "Go updated successfully to version $version using dnf."
        else
            handle_error "Failed to update Go with dnf."
        fi
    elif command -v brew &> /dev/null; then
        echo "Updating Go using Homebrew..."
        if brew upgrade go; then
            echo "Go updated successfully to version $version using Homebrew."
        else
            handle_error "Failed to update Go with Homebrew."
        fi
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
    local temp_goroot
    temp_goroot=$(go env GOROOT)
    if [[ -z "$temp_goroot" ]]; then
        handle_error "GOROOT is not set correctly."
    fi

    export GOPATH="$XDG_DATA_HOME/go"
    export GOMODCACHE="$XDG_CACHE_HOME/go/mod"
    export GOROOT="$temp_goroot"

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
    if go install golang.org/x/tools/cmd/goimports@latest; then
        echo "goimports installed successfully."
    else
        echo "Warning: Failed to install goimports."
    fi

    if go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest; then
        echo "golangci-lint installed successfully."
    else
        echo "Warning: Failed to install golangci-lint."
    fi

    if go install golang.org/x/tools/gopls@latest; then
        echo "gopls (Go Language Server) installed successfully."
    else
        echo "Warning: Failed to install gopls."
    fi
}

# Function to manage permissions for Go directories
manage_permissions() {
    echo "Managing permissions for Go directories..."
    check_directory_writable "$GOPATH"
    check_directory_writable "$GOMODCACHE"
}

# Function to manage multi-version Go support
manage_go_versions() {
    echo "Managing multi-version Go support..."

    if ! command -v goenv &> /dev/null; then
        echo "Go Version Manager (goenv) is not installed. Installing goenv..."
        git clone https://github.com/syndbg/goenv.git "$XDG_DATA_HOME/goenv" || handle_error "Failed to clone goenv repository."
        export GOENV_ROOT="$XDG_DATA_HOME/goenv"
        export PATH="$GOENV_ROOT/bin:$PATH"

        # Add goenv environment variables to .zprofile
        echo "export GOENV_ROOT=\"$GOENV_ROOT\"" >> "$ZDOTDIR/.zprofile"
        echo "export PATH=\"$GOENV_ROOT/bin:\$PATH\"" >> "$ZDOTDIR/.zprofile"

        # Source goenv
        if [ -s "$GOENV_ROOT/bin/goenv" ]; then
            if ! eval "$(goenv init -)"; then
                handle_error "Failed to initialize goenv."
            fi
        else
            handle_error "goenv script not found."
        fi
    else
        echo "goenv is already installed."
        # Ensure goenv is initialized
        if [ -s "$GOENV_ROOT/bin/goenv" ]; then
            if ! eval "$(goenv init -)"; then
                handle_error "Failed to initialize goenv."
            fi
        else
            handle_error "goenv script not found."
        fi
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
        rm -rf "${GOPATH:?}/tmp"
    fi
    if [[ -d "$GOMODCACHE/tmp" ]]; then
        echo "Cleaning up temporary files in $GOMODCACHE/tmp..."
        rm -rf "${GOMODCACHE:?}/tmp"
    fi
    echo "Final cleanup completed."
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
    local dir_path=$1

    find "$dir_path" -type d -empty -delete
    echo "Removed empty directories in $dir_path."
}
