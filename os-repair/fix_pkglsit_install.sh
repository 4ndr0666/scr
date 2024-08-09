#!/bin/bash

# Exit on error, undefined variable usage, or pipeline failure
set -euo pipefail

# Function to handle graceful exit
cleanup() {
    echo "Script terminated. Cleaning up..."
    exit 1
}

# Trap signals for graceful exit
trap cleanup SIGINT SIGTERM

# Function to prompt user for confirmation
confirm() {
    while true; do
        read -r -p "Do you want to proceed with this step? (y/n): " choice
        case "$choice" in 
            y|Y ) return 0;;
            n|N ) return 1;;
            * ) echo "Invalid choice, please enter 'y' or 'n'.";;
        esac
    done
}

# Function to handle package removal
remove_package() {
    local package=$1
    if yay -Qi "$package" > /dev/null 2>&1; then
        echo "Removing $package..."
        if yay -Rdd "$package"; then
            echo "Successfully removed $package."
        else
            echo "Failed to remove $package. Please check for errors and try again."
            exit 1
        fi
    else
        echo "$package is not installed."
    fi
}

# Function to remove corrupted package entry
remove_corrupted_entry() {
    local package=$1
    echo "Removing corrupted entry for $package..."
    sudo rm -rf /var/lib/pacman/local/"${package}"-*
}

# Function to install or reinstall a package
install_package() {
    local package=$1
    echo "Installing $package..."
    if yay -S --overwrite "*" "$package"; then
        echo "Successfully installed $package."
    else
        echo "Failed to install $package. Please check for errors and try again."
        exit 1
    fi
}

# Function to update the package database and upgrade all packages
update_system() {
    echo "Updating package database and upgrading all packages..."
    if yay -Syu; then
        echo "System successfully updated."
    else
        echo "Failed to update the system. Please check for errors and try again."
        exit 1
    fi
}

echo "Starting the automated package conflict resolution script..."

# Step 1: Update system before making changes
if confirm; then
    update_system
else
    echo "Skipping system update."
fi

# Step 2: Remove conflicting package bemenu-git
if confirm; then
    echo "Step 2: Removing conflicting package bemenu-git and its dependencies..."
    # Remove the conflicting package and dependencies that require it
    if yay -Rdd bemenu-git bemenu-wayland-git pinentry-bemenu; then
        echo "Successfully removed bemenu-git and its dependencies."
    else
        echo "Failed to remove bemenu-git. Please check for errors and try again."
        exit 1
    fi
else
    echo "Skipping Step 2."
fi

# Step 3: Fix missing desc file by reinstalling the package
if confirm; then
    echo "Step 3: Fixing missing desc file by removing corrupted entry and reinstalling projectm..."
    remove_corrupted_entry "projectm"
    install_package "projectm"
else
    echo "Skipping Step 3."
fi

# Step 4: Custom step - Add any additional package management operations here
if confirm; then
    echo "Step 4: Installing additional package example-package..."
    install_package "example-package"
else
    echo "Skipping Step 4."
fi

echo "Script completed successfully."
