#!/bin/bash

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
    sudo "$0" "$@"
    exit $?
fi

# Function to install Monaco Nerd Font
install_monaco() {
    # Create a directory for the Monaco Nerd Font
    mkdir -p /usr/share/fonts/monaco-nerd-fonts || { echo "Failed to create directory"; exit 1; }

    # Clone the Monaco Nerd Font repository from GitHub
    git clone https://github.com/Karmenzind/monaco-nerd-fonts.git || { echo "Failed to clone repository"; exit 1; }

    # Copy the fonts to the target directory
    cp -r monaco-nerd-fonts/fonts/* /usr/share/fonts/monaco-nerd-fonts/ || { echo "Failed to copy fonts"; exit 1; }
  
    # Remove the cloned repository to clean up
    rm -rf monaco-nerd-fonts || { echo "Failed to remove cloned repository"; exit 1; }

    # Update the font cache
    fc-cache -fv || { echo "Failed to update font cache"; exit 1; }
}

# Execute the installation function
install_monaco
