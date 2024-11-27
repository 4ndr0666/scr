#!/bin/bash
# File: optimize_go.sh
# Author: 4ndr0666
# Date: 2024-11-24
# Description: Optimizes Go environment in alignment with XDG Base Directory Specifications.

set -euo pipefail
IFS=$'\n\t'

# Define color codes for enhanced output
CYAN='\033[0;36m'
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
        echo "✅ Directory $dir_path is writable."
        log "Directory '$dir_path' is writable."
    else
        echo -e "${RED}❌ Error: Directory $dir_path is not writable.${NC}"
        log "ERROR: Directory '$dir_path' is not writable."
        exit 1
    fi
}

# Function to install Go
install_go() {
    if command -v pacman &> /dev/null; then
        echo "📦 Installing Go using pacman..."
        if sudo pacman -S --noconfirm go; then
            echo "✅ Go installed successfully using pacman."
            log "Go installed successfully using pacman."
        else
            handle_error "Failed to install Go with pacman."
        fi
    elif command -v apt-get &> /dev/null; then
        echo "📦 Installing Go using apt-get..."
        if sudo apt-get update && sudo apt-get install -y golang; then
            echo "✅ Go installed successfully using apt-get."
            log "Go installed successfully using apt-get."
        else
            handle_error "Failed to install Go with apt-get."
        fi
    elif command -v dnf &> /dev/null; then
        echo "📦 Installing Go using dnf..."
        if sudo dnf install -y golang; then
            echo "✅ Go installed successfully using dnf."
            log "Go installed successfully using dnf."
        else
            handle_error "Failed to install Go with dnf."
        fi
    elif command -v brew &> /dev/null; then
        echo "📦 Installing Go using Homebrew..."
        if brew install go; then
            echo "✅ Go installed successfully using Homebrew."
            log "Go installed successfully using Homebrew."
        else
            handle_error "Failed to install Go with Homebrew."
        fi
    else
        handle_error "Unsupported package manager. Go installation aborted."
    fi
}

# Function to update Go
update_go() {
    if command -v pacman &> /dev/null; then
        echo "🔄 Updating Go using pacman..."
        if sudo pacman -Syu --needed go; then
            echo "✅ Go updated successfully using pacman."
            log "Go updated successfully using pacman."
        else
            echo -e "${RED}⚠️ Error: Failed to update Go with pacman. There may be dependency conflicts.${NC}"
            log "Failed to update Go with pacman. Dependency conflicts may exist."
            echo "Please resolve the package manager dependency conflicts manually."
            exit 1
        fi
    elif command -v apt-get &> /dev/null; then
        echo "🔄 Updating Go using apt-get..."
        if sudo apt-get update && sudo apt-get install --only-upgrade -y golang; then
            echo "✅ Go updated successfully using apt-get."
            log "Go updated successfully using apt-get."
        else
            handle_error "Failed to update Go with apt-get."
        fi
    elif command -v dnf &> /dev/null; then
        echo "🔄 Updating Go using dnf..."
        if sudo dnf upgrade -y golang; then
            echo "✅ Go updated successfully using dnf."
            log "Go updated successfully using dnf."
        else
            handle_error "Failed to update Go with dnf."
        fi
    elif command -v brew &> /dev/null; then
        echo "🔄 Updating Go using Homebrew..."
        if brew upgrade go; then
            echo "✅ Go updated successfully using Homebrew."
            log "Go updated successfully using Homebrew."
        else
            handle_error "Failed to update Go with Homebrew."
        fi
    else
        handle_error "Unsupported package manager. Go update aborted."
    fi
}

# Function to get the latest Go version
get_latest_go_version() {
    if command -v pacman &> /dev/null; then
        latest_go_version=$(pacman -Si go | grep Version | awk '{print $3}')
    elif command -v apt-cache &> /dev/null; then
        latest_go_version=$(apt-cache policy golang | grep Candidate | awk '{print $2}')
    elif command -v dnf &> /dev/null; then
        latest_go_version=$(dnf info golang | grep Version | awk '{print $3}')
    elif command -v brew &> /dev/null; then
        latest_go_version=$(brew info go | grep -Eo 'go: stable [^,]+' | awk '{print $3}')
    else
        handle_error "Unsupported package manager. Cannot determine the latest Go version."
    fi
    echo "$latest_go_version"
}

# Function to set up Go paths (GOPATH, GOROOT, GOMODCACHE)
setup_go_paths() {
    echo "🛠️ Setting up Go environment paths..."

    # Ensure GOROOT is correctly set
    temp_goroot=$(go env GOROOT)
    if [[ -z "$temp_goroot" ]]; then
        handle_error "GOROOT is not set correctly."
    fi

    # Export environment variables as per XDG specifications
    export GOPATH="${XDG_DATA_HOME:-$HOME/.local/share}/go"
    export GOMODCACHE="${XDG_CACHE_HOME:-$HOME/.cache}/go/mod"
    export GOROOT="$temp_goroot"

    echo -e "${CYAN}GOPATH:${NC} $GOPATH"
    echo -e "${CYAN}GOMODCACHE:${NC} $GOMODCACHE"
    echo -e "${CYAN}GOROOT:${NC} $GOROOT"

    log "GOPATH set to '$GOPATH'."
    log "GOMODCACHE set to '$GOMODCACHE'."
    log "GOROOT set to '$GOROOT'."
}

# Function to consolidate Go directories
consolidate_go_directories() {
    echo "🧹 Consolidating Go directories..."

    # Ensure directories exist
    mkdir -p "$GOPATH" "$GOMODCACHE" || handle_error "Failed to create GOPATH or GOMODCACHE directories."

    # Check if directories are writable
    check_directory_writable "$GOPATH"
    check_directory_writable "$GOMODCACHE"

    log "Go directories consolidated and verified as writable."
}

# Function to install essential Go tools
install_go_tools() {
    echo "🔧 Installing Go tools (goimports, golangci-lint, gopls)..."

    # Ensure GOPATH/bin is in PATH
    export PATH="$GOPATH/bin:$PATH"

    # goimports
    if go install golang.org/x/tools/cmd/goimports@latest; then
        echo "✅ goimports installed successfully."
        log "goimports installed successfully."
    else
        echo "⚠️ Warning: Failed to install goimports."
        log "Warning: Failed to install goimports."
    fi

    # golangci-lint
    if go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest; then
        echo "✅ golangci-lint installed successfully."
        log "golangci-lint installed successfully."
    else
        echo "⚠️ Warning: Failed to install golangci-lint."
        log "Warning: Failed to install golangci-lint."
    fi

    # gopls
    if go install golang.org/x/tools/gopls@latest; then
        echo "✅ gopls (Go Language Server) installed successfully."
        log "gopls (Go Language Server) installed successfully."
    else
        echo "⚠️ Warning: Failed to install gopls."
        log "Warning: Failed to install gopls."
    fi
}

# Function to manage permissions for Go directories
manage_permissions() {
    echo "🔐 Managing permissions for Go directories..."

    check_directory_writable "$GOPATH"
    check_directory_writable "$GOMODCACHE"

    log "Permissions for Go directories are verified."
}

# Function to manage multi-version Go support
manage_go_versions() {
    echo "🔄 Managing multi-version Go support..."

    if ! command -v goenv &> /dev/null; then
        echo "🚀 goenv is not installed. Installing goenv..."
        install_goenv || handle_error "Failed to install goenv."
    else
        echo "✅ goenv is already installed."
        log "goenv is already installed."
    fi
}

# Function to install goenv
install_goenv() {
    echo "📦 Installing goenv..."
    git clone https://github.com/syndbg/goenv.git "${XDG_DATA_HOME:-$HOME/.local/share}/goenv" || handle_error "Failed to clone goenv repository."

    export GOENV_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/goenv"
    export PATH="$GOENV_ROOT/bin:$PATH"

    # Initialize goenv
    if eval "$(goenv init -)"; then
        echo "✅ goenv initialized successfully."
        log "goenv initialized successfully."
    else
        handle_error "Failed to initialize goenv."
    fi
}

# Function to validate Go installation
validate_go_installation() {
    echo "✅ Validating Go installation..."

    # Check go version
    if ! go version &> /dev/null; then
        handle_error "Go is not installed correctly."
    fi

    # Check directories
    if [[ ! -d "$GOPATH" ]]; then
        handle_error "GOPATH directory '$GOPATH' does not exist."
    fi

    if [[ ! -d "$GOMODCACHE" ]]; then
        handle_error "GOMODCACHE directory '$GOMODCACHE' does not exist."
    fi

    echo "✅ Go is installed and configured correctly."
    log "Go installation validated successfully."
}

# Function to perform final cleanup tasks
perform_final_cleanup() {
    echo "🧼 Performing final cleanup tasks..."

    # Remove temporary files in GOPATH and GOMODCACHE if they exist
    if [[ -d "$GOPATH/tmp" ]]; then
        echo "🗑️ Cleaning up temporary files in $GOPATH/tmp..."
        rm -rf "${GOPATH:?}/tmp" || log "⚠️ Warning: Failed to remove temporary files in '$GOPATH/tmp'."
        log "Temporary files in '$GOPATH/tmp' removed."
    fi

    if [[ -d "$GOMODCACHE/tmp" ]]; then
        echo "🗑️ Cleaning up temporary files in $GOMODCACHE/tmp..."
        rm -rf "${GOMODCACHE:?}/tmp" || log "⚠️ Warning: Failed to remove temporary files in '$GOMODCACHE/tmp'."
        log "Temporary files in '$GOMODCACHE/tmp' removed."
    fi

    echo "🧼 Final cleanup completed."
    log "Final cleanup tasks completed."
}

# Function to optimize Go environment
optimize_go_service() {
    echo "🔧 Starting Go environment optimization..."

    # Step 1: Check if Go is installed and up to date
    echo "🔍 Checking if Go is installed and up to date..."
    if ! command -v go &> /dev/null; then
        echo "📦 Go is not installed. Installing Go..."
        install_go || handle_error "Failed to install Go."
    else
        current_go_version=$(go version | awk '{print $3}')
        latest_go_version=$(get_latest_go_version) || handle_error "Failed to retrieve latest Go version."
        if [[ "$current_go_version" != "$latest_go_version" ]]; then
            echo "⏫ Go is outdated (current: $current_go_version, latest: $latest_go_version). Updating to version $latest_go_version..."
            update_go || handle_error "Failed to update Go to version $latest_go_version."
        else
            echo "✅ Go is already up to date: $current_go_version."
            log "Go is already up to date: $current_go_version."
        fi
    fi

    # Step 2: Ensure GOPATH, GOROOT, and GOMODCACHE are correctly set
    echo "🛠️ Ensuring Go environment variables (GOPATH, GOROOT, GOMODCACHE) are set correctly..."
    setup_go_paths

    # Step 3: Perform directory consolidation and cleanup
    echo "🧹 Performing directory consolidation and cleanup..."
    consolidate_go_directories

    # Step 4: Install or update Go tools
    echo "🔧 Ensuring essential Go tools are installed and up to date..."
    install_go_tools

    # Step 5: Check and manage permissions for Go directories
    echo "🔐 Checking and managing permissions for Go directories..."
    manage_permissions

    # Step 6: Manage multi-version Go support (if required)
    echo "🔄 Managing multi-version Go support (if applicable)..."
    manage_go_versions

    # Step 7: Perform basic validation of Go installation
    echo "✅ Validating Go installation..."
    validate_go_installation

    # Step 8: Final cleanup
    echo "🧼 Performing final cleanup..."
    perform_final_cleanup

    # Final summary
    echo "🎉 Go environment optimization complete."
    echo -e "${CYAN}GOPATH:${NC} $GOPATH"
    echo -e "${CYAN}GOROOT:${NC} $GOROOT"
    echo -e "${CYAN}GOMODCACHE:${NC} $GOMODCACHE"
    echo -e "${CYAN}Go version:${NC} $(go version)"
}

# Export necessary functions for use by the controller
export -f log
export -f handle_error
export -f check_directory_writable
export -f install_go
export -f update_go
export -f get_latest_go_version
export -f setup_go_paths
export -f consolidate_go_directories
export -f install_go_tools
export -f manage_permissions
export -f manage_go_versions
export -f install_goenv
export -f validate_go_installation
export -f perform_final_cleanup
export -f optimize_go_service

# The controller script will call optimize_go_service as needed, so there is no need for direct invocation here.
