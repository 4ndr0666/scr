#!/bin/bash

# Automatically escalate privileges if not running as root
if [ "$(id -u)" -ne 0 ]; then
    sudo "$0" "$@"
    exit $?
fi

trap "echo 'Script interrupted by user'; exit 1" INT

echo "Starting Intel Graphics GPU driver installation for Arch Linux..."

# Check for root permissions
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or use sudo."
    exit 1
fi

# Check for yay
command -v yay >/dev/null 2>&1 || {
    echo "yay is not installed. Installing yay..."
    pacman -S yay --noconfirm --needed || {
        echo "Error installing yay. Exiting..."
        exit 1
    }
}

# Update the system
echo "Updating system..."
pacman -Syu --noconfirm || {
    echo "Error updating the system. Exiting..."
    exit 1
}

# Install mesa if not installed
if ! pacman -Qq | grep -qw mesa; then
    echo "Installing mesa..."
    pacman -S mesa --noconfirm || {
        echo "Error installing mesa. Exiting..."
        exit 1
    }
else
    echo "mesa is already installed. Skipping..."
fi

# Install vulkan-intel if not installed
if ! pacman -Qq | grep -qw vulkan-intel; then
    echo "Installing vulkan-intel..."
    pacman -S vulkan-intel --noconfirm || {
        echo "Error installing vulkan-intel. Exiting..."
        exit 1
    }
else
    echo "vulkan-intel is already installed. Skipping..."
fi

# Install intel-compute-runtime from AUR if not installed
if ! pacman -Qq | grep -qw intel-compute-runtime; then
    echo "Installing intel-compute-runtime from AUR..."
    yay -S intel-compute-runtime --noconfirm || {
        echo "Error installing intel-compute-runtime. Exiting..."
        exit 1
    }
else
    echo "intel-compute-runtime is already installed. Skipping..."
fi

# Verify installation
echo "Verifying installation..."
GLXINFO_OUTPUT=$(glxinfo 2>/dev/null | grep "OpenGL renderer")
if [ $? -eq 0 ]; then
    echo "Verification successful!"
    echo "$GLXINFO_OUTPUT"
else
    echo "Verification failed. 'glxinfo' might not be installed or there's an issue with the GPU setup."
fi

echo "Installation complete!"
