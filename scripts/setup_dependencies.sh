#!/usr/bin/env bash
# shellcheck disable=all
set -euo pipefail

# Script: setup_dependencies.sh
# Description: Automates the installation and configuration of required dependencies.
# Usage: ./setup_dependencies.sh

# Define required tools
REQUIRED_TOOLS=("git-lfs" "shellcheck" "shfmt" "notify-send" "git" "bash")

# Log file
DEPENDENCY_LOG="dependency_setup.log"
echo "Dependency setup started at $(date)" > "$DEPENDENCY_LOG"

# Function to install a tool using pacman
install_tool() {
    local tool="$1"
    if pacman -Qi "$tool" &> /dev/null; then
        echo "$tool is already installed." | tee -a "$DEPENDENCY_LOG"
    else
        echo "Installing $tool..." | tee -a "$DEPENDENCY_LOG"
        sudo pacman -S --noconfirm "$tool" | tee -a "$DEPENDENCY_LOG"
        echo "$tool installed successfully." | tee -a "$DEPENDENCY_LOG"
    fi
}

# Function to install a tool using yay (AUR helper)
install_aur_tool() {
    local tool="$1"
    if yay -Qi "$tool" &> /dev/null; then
        echo "$tool is already installed via AUR." | tee -a "$DEPENDENCY_LOG"
    else
        echo "Installing $tool from AUR..." | tee -a "$DEPENDENCY_LOG"
        yay -S --noconfirm "$tool" | tee -a "$DEPENDENCY_LOG"
        echo "$tool installed successfully from AUR." | tee -a "$DEPENDENCY_LOG"
    fi
}

# Install required tools
for tool in "${REQUIRED_TOOLS[@]}"; do
    install_tool "$tool"
done

# Check and install git-lfs separately if not installed
if ! command -v git-lfs &> /dev/null; then
    echo "git-lfs not found. Installing git-lfs..." | tee -a "$DEPENDENCY_LOG"
    sudo pacman -S --noconfirm git-lfs | tee -a "$DEPENDENCY_LOG"
    echo "git-lfs installed successfully." | tee -a "$DEPENDENCY_LOG"
else
    echo "git-lfs is already installed." | tee -a "$DEPENDENCY_LOG"
fi

# Initialize git-lfs
if git lfs env &> /dev/null; then
    echo "git-lfs is already initialized." | tee -a "$DEPENDENCY_LOG"
else
    echo "Initializing git-lfs..." | tee -a "$DEPENDENCY_LOG"
    git lfs install | tee -a "$DEPENDENCY_LOG"
    echo "git-lfs initialized successfully." | tee -a "$DEPENDENCY_LOG"
fi

# Ensure notify-send is available (part of libnotify)
if ! command -v notify-send &> /dev/null; then
    echo "Installing libnotify..." | tee -a "$DEPENDENCY_LOG"
    sudo pacman -S --noconfirm libnotify | tee -a "$DEPENDENCY_LOG"
    echo "libnotify installed successfully." | tee -a "$DEPENDENCY_LOG"
else
    echo "libnotify is already installed." | tee -a "$DEPENDENCY_LOG"
fi

# Summary
echo "Dependency setup completed at $(date)" | tee -a "$DEPENDENCY_LOG"
echo "All required dependencies are installed and configured." | tee -a "$DEPENDENCY_LOG"

exit 0
