#!/bin/bash
# File: optimize_ruby.sh
# Author: 4ndr0666
# Edited: 11-24-24
# Description: Optimizes Ruby environment in alignment with XDG Base Directory Specifications.

# Function to optimize Ruby environment
function optimize_ruby_service() {
    echo "Optimizing Ruby environment..."

    # Step 1: Check if Ruby is installed
    current_ruby_version=$(ruby -v 2>/dev/null)
    latest_ruby_version=$(get_latest_ruby_version)

    if [[ $? -ne 0 ]]; then
        echo "Ruby is not installed. Installing the latest version..."
        install_ruby
    elif [[ "$current_ruby_version" != *"$latest_ruby_version"* ]]; then
        echo "Ruby is outdated. Updating to the latest version ($latest_ruby_version)..."
        sudo pacman -Syu ruby || handle_error "Failed to update Ruby with pacman."
    else
        echo "Ruby is already installed and up to date: $current_ruby_version"
    fi

    # Step 2: Manage Ruby Versioning (System, RVM, or rbenv)
    manage_ruby_versions

    # Step 3: Ensure common Ruby gems (bundler, rake, etc.) are installed and up to date
    echo "Ensuring common Ruby gems (bundler, rake) are installed and up to date..."
    gem_install_or_update "bundler"
    gem_install_or_update "rake"

    # Step 4: Optionally install and configure `rubocop` for linting and `prettier` for formatting
    echo "Installing Ruby linter (rubocop) and formatter (prettier)..."
    gem_install_or_update "rubocop"
    npm_install_or_update "prettier"

    # Step 5: Check permissions for Ruby and gem directories
    echo "Checking permissions for Ruby and gem directories..."
    check_permissions "$GEM_HOME"
    check_permissions "$RBENV_ROOT"
    check_permissions "$HOME/.rvm"

    # Step 6: Set up environment variables for Ruby and Gems (aligning with .zprofile)
    echo "Setting up Ruby environment variables..."
    ruby_version=$(ruby -e 'puts RUBY_VERSION')  # Dynamically fetch the Ruby version
    export GEM_HOME="$XDG_DATA_HOME/gem/ruby/$ruby_version"
    export GEM_PATH="$GEM_HOME"
    export PATH="$GEM_HOME/bin:$PATH"

    # Environment variables are already set in .zprofile, so no need to modify them here.
    echo "GEM_HOME: $GEM_HOME"
    echo "GEM_PATH: $GEM_PATH"

    # Step 7: Ensure Bundler and RubyGems are configured correctly
    echo "Ensuring Bundler and RubyGems are configured correctly..."
    ensure_bundler_config
    ensure_rubygems_config

    # Step 8: Consolidate Ruby directories and clean up
    echo "Consolidating and cleaning up Ruby directories..."
    consolidate_directories "$XDG_DATA_HOME/gem/ruby" "$GEM_HOME"
    remove_empty_directories "$XDG_DATA_HOME/gem/ruby"

    # Step 9: Final cleanup and summary
    echo "Performing final cleanup..."
    echo "Ruby environment optimization complete."
    echo "Ruby version: $(ruby -v)"
    echo "GEM_HOME: $GEM_HOME"
    echo "GEM_PATH: $GEM_PATH"
}

# Helper function to install Ruby using multiple package managers
install_ruby() {
    if command -v pacman &> /dev/null; then
        echo "Installing Ruby using pacman..."
        sudo pacman -S --noconfirm ruby || handle_error "Failed to install Ruby with pacman."
    elif command -v apt-get &> /dev/null; then
        echo "Installing Ruby using apt-get..."
        sudo apt-get update && sudo apt-get install -y ruby-full || handle_error "Failed to install Ruby with apt-get."
    elif command -v dnf &> /dev/null; then
        echo "Installing Ruby using dnf..."
        sudo dnf install -y ruby || handle_error "Failed to install Ruby with dnf."
    elif command -v zypper &> /dev/null; then
        echo "Installing Ruby using zypper..."
        sudo zypper install -y ruby || handle_error "Failed to install Ruby with zypper."
    else
        echo "Unsupported package manager. Please install Ruby manually."
        exit 1
    fi
    echo "Ruby installed successfully."
}

# Helper function to get the latest Ruby version
get_latest_ruby_version() {
    if command -v pacman &> /dev/null; then
        pacman -Si ruby | grep Version | awk '{print $3}'
    elif command -v apt-cache &> /dev/null; then
        apt-cache show ruby | grep Version | awk '{print $2}' | head -n 1
    else
        echo "Error: Unsupported package manager."
        exit 1
    fi
}

# Helper function to install or update a Ruby gem
gem_install_or_update() {
    local gem_name=$1
    if gem list "$gem_name" -i &> /dev/null; then
        echo "Updating $gem_name gem..."
        gem update "$gem_name" || handle_error "Failed to update $gem_name."
    else
        echo "Installing $gem_name gem..."
        gem install "$gem_name" || handle_error "Failed to install $gem_name."
    fi
}

# Helper function to install or update an npm package (for Prettier)
npm_install_or_update() {
    local package_name=$1
    if npm list -g "$package_name" &> /dev/null; then
        echo "Updating $package_name..."
        npm update -g "$package_name" || echo "Warning: Failed to update $package_name."
    else
        echo "Installing $package_name globally..."
        npm install -g "$package_name" || echo "Warning: Failed to install $package_name."
    fi
}

# Function to manage Ruby versions with RVM or rbenv
manage_ruby_versions() {
    if command -v rvm &> /dev/null; then
        echo "Managing Ruby versions with RVM..."
        rvm use default --install --quiet-curl || handle_error "Failed to manage Ruby versions with RVM."
    elif command -v rbenv &> /dev/null; then
        echo "Managing Ruby versions with rbenv..."
        rbenv install --skip-existing || handle_error "Failed to install Ruby versions with rbenv."
        rbenv global "$(rbenv versions --bare | tail -1)" || handle_error "Failed to set global Ruby version with rbenv."
    else
        echo "Neither RVM nor rbenv is installed. Consider using one for managing Ruby versions."
    fi
}

# Helper function to ensure Bundler configuration is set up correctly
ensure_bundler_config() {
    bundle config --global path "$GEM_HOME"
    echo "Ensuring Bundler is configured to use GEM_HOME: $GEM_HOME"
}

# Helper function to ensure RubyGems configuration is correct
ensure_rubygems_config() {
    gem sources --add https://rubygems.org/ --remove https://rubygems.org/ 2>/dev/null
    echo "Ensuring RubyGems source is set correctly."
}

# Helper function: Handle errors
handle_error() {
    echo "Error: $1" >&2
    exit 1
}

# Helper function: Check directory permissions and ownership
check_permissions() {
    local dir=$1
    if [[ ! -w "$dir" ]]; then
        echo "Error: $dir is not writable. Adjusting permissions..."
        chmod -R u+w "$dir" || handle_error "Failed to set write permissions for $dir."
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

# The controller script will call optimize_ruby_service as needed, so there is no need for direct invocation in this file.
