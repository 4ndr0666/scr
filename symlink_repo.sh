#!/bin/bash

# --- // AUTO_ESCALATE:
if [ "$(id -u)" -ne 0 ]; then
    echo "This script requires root privileges. Please enter your password to continue."
    sudo "$0" "${@:-}"
    exit $?
fi

# Function to print messages with visual feedback
print_info() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

print_success() {
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

print_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
}

# Set up paths
SCRIPT_REPO="/Nas/Build/git/syncing/scr"
TARGET_DIR="/usr/local/bin/scr"
BASHRC="$HOME/.bashrc"
ZSHRC="$HOME/.zshrc"

# Confirm user input
echo "This script will:"
echo "1. Symlink your script directory $SCRIPT_REPO to $TARGET_DIR."
echo "2. Add $TARGET_DIR to your system's PATH."
read -p "Do you want to continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_error "Operation aborted."
    exit 1
fi

# Check if the source directory exists
if [ ! -d "$SCRIPT_REPO" ]; then
    print_error "Source directory $SCRIPT_REPO does not exist. Please check the path."
    exit 1
fi

# Remove existing symlink if it exists
if [ -L "$TARGET_DIR" ]; then
    print_info "Removing existing symlink at $TARGET_DIR..."
    sudo rm "$TARGET_DIR"
elif [ -d "$TARGET_DIR" ]; then
    print_error "Target directory $TARGET_DIR exists as a directory, not a symlink. Cannot proceed."
    exit 1
fi

# Create a new symlink
print_info "Creating symlink from $SCRIPT_REPO to $TARGET_DIR..."
sudo ln -s "$SCRIPT_REPO" "$TARGET_DIR"
if [ $? -eq 0 ]; then
    print_success "Symlink created successfully."
else
    print_error "Failed to create symlink."
    exit 1
fi

# Function to add the directory to the PATH in the shell configuration file
add_to_path() {
    local shellrc="$1"
    if grep -Fxq "export PATH=\$PATH:$TARGET_DIR" "$shellrc"; then
        print_info "Path already added to $shellrc."
    else
        echo "export PATH=\$PATH:$TARGET_DIR" >> "$shellrc"
        print_success "Path added to $shellrc."
    fi
}

# Add to PATH in .bashrc or .zshrc if not already added
if [ -f "$BASHRC" ]; then
    add_to_path "$BASHRC"
fi

if [ -f "$ZSHRC" ]; then
    add_to_path "$ZSHRC"
fi

# Reload the shell configuration
if [ "$SHELL" == "/bin/zsh" ]; then
    print_info "Reloading .zshrc..."
    source "$ZSHRC"
elif [ "$SHELL" == "/bin/bash" ]; then
    print_info "Reloading .bashrc..."
    source "$BASHRC"
else
    print_error "Unrecognized shell. Please reload your shell manually."
fi

print_success "Setup completed successfully. The $TARGET_DIR is now in your PATH."
