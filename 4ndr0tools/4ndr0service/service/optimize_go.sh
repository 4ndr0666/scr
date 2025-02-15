#!/usr/bin/env bash
# File: optimize_go.sh
# Author: 4ndr0666
# Date: 2024-11-24
# Description: Optimizes Go environment.

set -euo pipefail
IFS=$'\n\t'

CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

LOG_FILE="${LOG_FILE:-$HOME/.cache/4ndr0service/logs/service_optimization.log}"
mkdir -p "$(dirname "$LOG_FILE")" || { echo "Failed to create log directory."; exit 1; }

log() {
    local message="$1"
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

handle_error() {
    local error_message="$1"
    echo -e "${RED}❌ Error: $error_message${NC}" >&2
    log "ERROR: $error_message"
    exit 1
}

check_directory_writable() {
    local dir_path="$1"
    if [[ -w "$dir_path" ]]; then
        echo "✅ Directory $dir_path is writable."
        log "Directory '$dir_path' is writable."
    else
        handle_error "Directory $dir_path is not writable."
    fi
}

install_go() {
    if command -v go &> /dev/null; then
        echo "✅ Go is already installed: $(go version)."
        log "Go is already installed."
        return 0
    fi

    if command -v pacman &> /dev/null; then
        echo "Installing Go using pacman..."
        sudo pacman -Syu --needed go || handle_error "Failed to install Go with pacman."
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
        handle_error "Unsupported package manager. Go installation aborted."
    fi
    echo "✅ Go installed successfully."
    log "Go installed successfully."
}

update_go() {
    if command -v pacman &> /dev/null; then
        echo "🔄 Updating Go using pacman..."
        sudo pacman -Syu --needed go || handle_error "Failed to update Go with pacman."
        echo "✅ Go updated successfully with pacman."
        log "Go updated with pacman."
    elif command -v apt-get &> /dev/null; then
        echo "🔄 Updating Go using apt-get..."
        sudo apt-get update && sudo apt-get install --only-upgrade -y golang || handle_error "Failed to update Go with apt-get."
        echo "✅ Go updated successfully with apt-get."
        log "Go updated with apt-get."
    elif command -v dnf &> /dev/null; then
        echo "🔄 Updating Go using dnf..."
        sudo dnf upgrade -y golang || handle_error "Failed to update Go with dnf."
        echo "✅ Go updated with dnf."
        log "Go updated with dnf."
    elif command -v brew &> /dev/null; then
        echo "🔄 Updating Go using Homebrew..."
        brew upgrade go || handle_error "Failed to update Go with Homebrew."
        echo "✅ Go updated with Homebrew."
        log "Go updated with Homebrew."
    else
        handle_error "Unsupported package manager. Go update aborted."
    fi
}

get_latest_go_version() {
    if command -v pacman &> /dev/null; then
        pacman -Si go | grep Version | awk '{print $3}'
    elif command -v apt-cache &> /dev/null; then
        apt-cache policy golang | grep Candidate | awk '{print $2}'
    elif command -v dnf &> /dev/null; then
        dnf info golang | grep Version | awk '{print $3}'
    elif command -v brew &> /dev/null; then
        brew info go | grep -Eo 'go: stable [^,]+' | awk '{print $3}'
    else
        handle_error "Unsupported package manager. Cannot determine latest Go version."
    fi
}

setup_go_paths() {
    echo "🛠️ Setting up Go environment paths..."
    temp_goroot=$(go env GOROOT)
    if [[ -z "$temp_goroot" ]]; then
        handle_error "GOROOT is not set correctly after Go installation."
    fi

    export GOPATH="${XDG_DATA_HOME:-$HOME/.local/share}/go"
    export GOMODCACHE="${XDG_CACHE_HOME:-$HOME/.cache}/go/mod"
    export GOROOT="$temp_goroot"

    echo -e "${CYAN}GOPATH:${NC} $GOPATH"
    echo -e "${CYAN}GOMODCACHE:${NC} $GOMODCACHE"
    echo -e "${CYAN}GOROOT:${NC} $GOROOT"

    log "GOPATH set to '$GOPATH', GOMODCACHE set to '$GOMODCACHE', GOROOT set to '$GOROOT'."
    mkdir -p "$GOPATH" "$GOMODCACHE" || handle_error "Failed to create GOPATH or GOMODCACHE directories."
    check_directory_writable "$GOPATH"
    check_directory_writable "$GOMODCACHE"
}

install_go_tools() {
    echo "🔧 Installing Go tools (goimports, golangci-lint, gopls)..."
    export PATH="$GOPATH/bin:$PATH"

    # goimports
    if ! go install golang.org/x/tools/cmd/goimports@latest; then
        echo "⚠️ Warning: Failed to install goimports."
        log "Warning: Failed to install goimports."
    else
        echo "✅ goimports installed."
        log "goimports installed."
    fi

    # golangci-lint
    if ! go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest; then
        echo "⚠️ Warning: Failed to install golangci-lint."
        log "Warning: Failed to install golangci-lint."
    else
        echo "✅ golangci-lint installed."
        log "golangci-lint installed."
    fi

    # gopls
    if ! go install golang.org/x/tools/gopls@latest; then
        echo "⚠️ Warning: Failed to install gopls."
        log "Warning: Failed to install gopls."
    else
        echo "✅ gopls installed."
        log "gopls installed."
    fi
}

manage_permissions() {
    echo "🔐 Managing permissions for Go directories..."
    check_directory_writable "$GOPATH"
    check_directory_writable "$GOMODCACHE"
    log "Permissions for Go directories are verified."
}

manage_go_versions() {
    echo "🔄 Managing multi-version Go support..."
    if ! command -v goenv &> /dev/null; then
        echo "📦 Installing goenv..."
        if [[ -d "${XDG_DATA_HOME:-$HOME/.local/share}/goenv" ]]; then
            echo "goenv directory already exists. Skipping."
            log "goenv directory found, skipping clone."
        else
            git clone https://github.com/syndbg/goenv.git "${XDG_DATA_HOME:-$HOME/.local/share}/goenv" || log "Warning: Failed to clone goenv."
        fi
        export GOENV_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/goenv"
        export PATH="$GOENV_ROOT/bin:$PATH"
        if ! eval "$(goenv init -)" &>/dev/null; then
            echo "⚠️ Warning: Failed to initialize goenv."
            log "Warning: Failed to initialize goenv."
        else
            echo "✅ goenv initialized."
            log "goenv initialized."
        fi
    else
        echo "✅ goenv is already installed."
        log "goenv is already installed."
    fi
}

validate_go_installation() {
    echo "✅ Validating Go installation..."
    if ! go version &> /dev/null; then
        handle_error "Go not found. Use --fix to install."
    fi
    if [[ ! -d "$GOPATH" ]]; then
        handle_error "GOPATH directory '$GOPATH' does not exist."
    fi
    if [[ ! -d "$GOMODCACHE" ]]; then
        handle_error "GOMODCACHE directory '$GOMODCACHE' does not exist."
    fi
    echo "✅ Go is installed and configured correctly."
    log "Go installation validated successfully."
}

perform_go_cleanup() {
    echo "🧼 Performing final cleanup..."
    if [[ -d "$GOPATH/tmp" ]]; then
        echo "🗑️ Cleaning up $GOPATH/tmp..."
        rm -rf "${GOPATH:?}/tmp" || log "Warning: Failed to remove tmp in $GOPATH."
        log "Cleaned up $GOPATH/tmp."
    fi
    if [[ -d "$GOMODCACHE/tmp" ]]; then
        echo "🗑️ Cleaning up $GOMODCACHE/tmp..."
        rm -rf "${GOMODCACHE:?}/tmp" || log "Warning: Failed to remove tmp in $GOMODCACHE."
        log "Cleaned up $GOMODCACHE/tmp."
    fi
    echo "🧼 Final cleanup completed."
    log "Go final cleanup tasks completed."
}

optimize_go_service() {
    echo "🔧 Starting Go environment optimization..."
    echo "🔍 Checking if Go is installed and up to date..."
    install_go

    current_go_version=$(go version | awk '{print $3}')
    latest_go_version=$(get_latest_go_version || echo "")
    if [[ -n "$latest_go_version" && "$current_go_version" != "$latest_go_version" ]]; then
        echo "⏫ Updating Go from $current_go_version to $latest_go_version..."
        update_go
    else
        echo "✅ Go is up to date: $current_go_version."
        log "Go is up to date: $current_go_version."
    fi

    echo "🛠️ Ensuring Go environment variables are correct..."
    setup_go_paths

    echo "🔧 Installing or updating Go tools..."
    install_go_tools

    echo "🔐 Checking and managing permissions..."
    manage_permissions

    echo "🔄 Managing multi-version Go support..."
    manage_go_versions

    echo "✅ Validating Go installation..."
    validate_go_installation

    echo "🧼 Performing final cleanup..."
    perform_go_cleanup

    echo "🎉 Go environment optimization complete."
    echo -e "${CYAN}GOPATH:${NC} $GOPATH"
    echo -e "${CYAN}GOROOT:${NC} $GOROOT"
    echo -e "${CYAN}GOMODCACHE:${NC} $GOMODCACHE"
    echo -e "${CYAN}Go version:${NC} $(go version)"
    log "Go environment optimization completed."
}
