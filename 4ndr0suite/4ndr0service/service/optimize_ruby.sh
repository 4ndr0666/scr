#!/bin/bash
# File: optimize_ruby.sh
# Author: 4ndr0666
# Date: 2024-11-24
# Description: Optimizes Ruby environment in alignment with XDG Base Directory Specifications.

set -euo pipefail
IFS=$'\n\t'

# Define color codes for enhanced output
CYAN='\033[0;36m'
GREEN='\033[0;32m'
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

# Define Ruby directories based on XDG specifications
export RUBY_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/ruby"
export RUBY_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/ruby"
export RUBY_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/ruby"

# Function to optimize Ruby environment
optimize_ruby_service() {
    echo "🔧 Starting Ruby environment optimization..."

    # Step 1: Check if Ruby is installed
    echo "📦 Checking if Ruby is installed..."
    if ! command -v ruby &> /dev/null; then
        echo "📦 Ruby is not installed. Installing the latest version..."
        install_ruby
    else
        current_ruby_version=$(ruby -v)
        echo "✅ Ruby is already installed: $current_ruby_version"
    fi

    # Step 2: Manage Ruby Versioning (System, RVM, or rbenv)
    manage_ruby_versions

    # Step 3: Set up environment variables for Ruby and Gems
    echo "🛠️ Setting up Ruby environment variables..."
    ruby_version=$(ruby -e 'puts RUBY_VERSION')
    export GEM_HOME="$RUBY_DATA_HOME/gems/$ruby_version"
    export GEM_PATH="$GEM_HOME"
    export PATH="$GEM_HOME/bin:$PATH"

    echo "GEM_HOME: $GEM_HOME"
    echo "GEM_PATH: $GEM_PATH"

    # Ensure directories exist
    mkdir -p "$GEM_HOME" "$RUBY_CONFIG_HOME" "$RUBY_CACHE_HOME" || handle_error "Failed to create Ruby directories."

    # Step 4: Check permissions for Ruby and gem directories
    echo "🔐 Checking permissions for Ruby and gem directories..."
    check_directory_writable "$GEM_HOME"
    check_directory_writable "$RUBY_CONFIG_HOME"
    check_directory_writable "$RUBY_CACHE_HOME"

    # Step 5: Ensure common Ruby gems (bundler, rake) are installed and up to date
    echo "🔧 Ensuring common Ruby gems (bundler, rake) are installed and up to date..."
    gem_install_or_update "bundler"
    gem_install_or_update "rake"

    # Step 6: Optionally install and configure `rubocop` for linting and `prettier` for formatting
    echo "🔧 Installing Ruby linter (rubocop) and formatter (prettier)..."
    gem_install_or_update "rubocop"

    if command -v npm &> /dev/null; then
        npm_install_or_update "prettier"
    else
        echo "⚠️ Warning: npm is not installed. Skipping installation of prettier."
        log "npm is not installed. Skipping installation of prettier."
    fi

    # Step 7: Ensure Bundler and RubyGems are configured correctly
    echo "🛠️ Ensuring Bundler and RubyGems are configured correctly..."
    ensure_bundler_config
    ensure_rubygems_config

    # Step 8: Consolidate Ruby directories and clean up
    echo "🧹 Consolidating and cleaning up Ruby directories..."
    consolidate_directories "$RUBY_DATA_HOME/gems" "$GEM_HOME"
    remove_empty_directories "$RUBY_DATA_HOME/gems"

    # Step 9: Final cleanup and summary
    echo "🧼 Performing final cleanup..."
    perform_final_cleanup

    echo "🎉 Ruby environment optimization complete."
    echo -e "${CYAN}Ruby version:${NC} $(ruby -v)"
    echo -e "${CYAN}GEM_HOME:${NC} $GEM_HOME"
    echo -e "${CYAN}GEM_PATH:${NC} $GEM_PATH"
}

# Helper function to install Ruby using multiple package managers
install_ruby() {
    if command -v pacman &> /dev/null; then
        echo "Installing Ruby using pacman..."
        sudo pacman -Syu --needed ruby || handle_error "Failed to install Ruby with pacman."
    elif command -v apt-get &> /dev/null; then
        echo "Installing Ruby using apt-get..."
        sudo apt-get update && sudo apt-get install -y ruby-full || handle_error "Failed to install Ruby with apt-get."
    elif command -v dnf &> /dev/null; then
        echo "Installing Ruby using dnf..."
        sudo dnf install -y ruby || handle_error "Failed to install Ruby with dnf."
    elif command -v brew &> /dev/null; then
        echo "Installing Ruby using Homebrew..."
        brew install ruby || handle_error "Failed to install Ruby with Homebrew."
    else
        handle_error "Unsupported package manager. Please install Ruby manually."
    fi
    echo "✅ Ruby installed successfully."
    log "Ruby installed successfully."
}

# Helper function to install or update a Ruby gem
gem_install_or_update() {
    local gem_name=$1
    if gem list "$gem_name" -i &> /dev/null; then
        echo "🔄 Updating $gem_name gem..."
        if gem update "$gem_name"; then
            echo "✅ $gem_name gem updated successfully."
            log "$gem_name gem updated successfully."
        else
            echo "⚠️ Warning: Failed to update $gem_name."
            log "Warning: Failed to update $gem_name."
        fi
    else
        echo "📦 Installing $gem_name gem..."
        if gem install "$gem_name"; then
            echo "✅ $gem_name gem installed successfully."
            log "$gem_name gem installed successfully."
        else
            echo "⚠️ Warning: Failed to install $gem_name."
            log "Warning: Failed to install $gem_name."
        fi
    fi
}

# Helper function to install or update an npm package (for Prettier)
npm_install_or_update() {
    local package_name=$1
    if npm list -g "$package_name" &> /dev/null; then
        echo "🔄 Updating $package_name..."
        if npm update -g "$package_name"; then
            echo "✅ $package_name updated successfully."
            log "$package_name updated successfully."
        else
            echo "⚠️ Warning: Failed to update $package_name."
            log "Warning: Failed to update $package_name."
        fi
    else
        echo "📦 Installing $package_name globally..."
        if npm install -g "$package_name"; then
            echo "✅ $package_name installed successfully."
            log "$package_name installed successfully."
        else
            echo "⚠️ Warning: Failed to install $package_name."
            log "Warning: Failed to install $package_name."
        fi
    fi
}

# Function to manage Ruby versions with RVM or rbenv
manage_ruby_versions() {
    if command -v rbenv &> /dev/null; then
        echo "🔄 Managing Ruby versions with rbenv..."
        if rbenv install -s "$(rbenv install -l | grep -v - | tail -1)"; then
            rbenv global "$(rbenv versions --bare | tail -1)" || handle_error "Failed to set global Ruby version with rbenv."
            echo "✅ Ruby version managed with rbenv."
            log "Ruby version managed with rbenv."
        else
            echo "⚠️ Warning: Failed to install Ruby versions with rbenv."
            log "Warning: Failed to install Ruby versions with rbenv."
        fi
    elif command -v rvm &> /dev/null; then
        echo "🔄 Managing Ruby versions with RVM..."
        if rvm install ruby --latest; then
            rvm use ruby --default || handle_error "Failed to set default Ruby version with RVM."
            echo "✅ Ruby version managed with RVM."
            log "Ruby version managed with RVM."
        else
            echo "⚠️ Warning: Failed to install Ruby versions with RVM."
            log "Warning: Failed to install Ruby versions with RVM."
        fi
    else
        echo "⚠️ Neither RVM nor rbenv is installed. Consider installing one for managing Ruby versions."
        log "Neither RVM nor rbenv is installed."
    fi
}

# Helper function to ensure Bundler configuration is set up correctly
ensure_bundler_config() {
    if bundle config set --global path "$GEM_HOME"; then
        echo "✅ Bundler configured to use GEM_HOME: $GEM_HOME"
        log "Bundler configured to use GEM_HOME: $GEM_HOME"
    else
        echo "⚠️ Warning: Failed to configure Bundler."
        log "Warning: Failed to configure Bundler."
    fi
}

# Helper function to ensure RubyGems configuration is correct
ensure_rubygems_config() {
    if gem sources --add https://rubygems.org/ --remove https://rubygems.org/ 2>/dev/null; then
        echo "✅ RubyGems source set correctly."
        log "RubyGems source set correctly."
    else
        echo "⚠️ Warning: Failed to configure RubyGems source."
        log "Warning: Failed to configure RubyGems source."
    fi
}

# Helper function: Check directory permissions and ownership
check_permissions() {
    local dir=$1
    if [[ -d "$dir" ]]; then
        if [[ ! -w "$dir" ]]; then
            echo "🔐 Directory $dir is not writable. Adjusting permissions..."
            chmod -R u+w "$dir" || handle_error "Failed to set write permissions for $dir."
            log "Permissions adjusted for $dir."
        else
            echo "✅ Directory $dir is writable."
            log "Directory $dir is writable."
        fi
    else
        echo "⚠️ Warning: Directory $dir does not exist."
        log "Warning: Directory $dir does not exist."
    fi
}

# Helper function: Consolidate contents from source to target directory
consolidate_directories() {
    local source_dir=$1
    local target_dir=$2

    if [[ -d "$source_dir" ]]; then
        rsync -av "$source_dir/" "$target_dir/" || echo "⚠️ Warning: Failed to consolidate $source_dir to $target_dir."
        echo "✅ Consolidated directories from $source_dir to $target_dir."
        log "Consolidated directories from $source_dir to $target_dir."
    else
        echo "⚠️ Warning: Source directory $source_dir does not exist. Skipping consolidation."
        log "Source directory $source_dir does not exist. Skipping consolidation."
    fi
}

# Helper function: Remove empty directories
remove_empty_directories() {
    local dir=$1
    find "$dir" -type d -empty -delete
    echo "✅ Removed empty directories in $dir."
    log "Removed empty directories in $dir."
}

# Function to perform final cleanup tasks
perform_final_cleanup() {
    echo "🧼 Performing final cleanup tasks..."

    # Remove temporary files if they exist
    if [[ -d "$RUBY_CACHE_HOME/tmp" ]]; then
        echo "🗑️ Cleaning up temporary files in $RUBY_CACHE_HOME/tmp..."
        rm -rf "${RUBY_CACHE_HOME:?}/tmp" || log "⚠️ Warning: Failed to remove temporary files in '$RUBY_CACHE_HOME/tmp'."
        log "Temporary files in '$RUBY_CACHE_HOME/tmp' removed."
    fi

    echo "🧼 Final cleanup completed."
    log "Final cleanup tasks completed."
}

# Export necessary functions for use by the controller
export -f log
export -f handle_error
export -f check_directory_writable
export -f install_ruby
export -f gem_install_or_update
export -f npm_install_or_update
export -f manage_ruby_versions
export -f ensure_bundler_config
export -f ensure_rubygems_config
export -f check_permissions
export -f consolidate_directories
export -f remove_empty_directories
export -f perform_final_cleanup
export -f optimize_ruby_service

# The controller script will call optimize_ruby_service as needed, so there is no need for direct invocation here.
