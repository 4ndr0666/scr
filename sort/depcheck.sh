#!/bin/bash

# Update the system and sync the package database
echo "Updating system and syncing package database..."
sudo pacman -Syu

# List all explicitly installed packages
packages=$(pacman -Qe | awk '{print $1}')

# Reinstall all explicitly installed packages and their dependencies
echo "Reinstalling all packages and their dependencies..."
for package in $packages; do
    echo "Reinstalling $package..."
    sudo pacman -S --needed $package
done

# Check for and remove orphan packages (packages that were installed as dependencies but are not needed anymore)
echo "Removing orphan packages..."
orphans=$(pacman -Qdtq)
if [ -n "$orphans" ]; then
    sudo pacman -Rns $orphans
fi

# The package you're interested in
read -p "Enter the name of the package you're interested in: " package

# Get a list of all dependencies for the package
dependencies=$(pactree -l $package)

# Check if the dependencies are installed
missing_dependencies=$(pacman -T $dependencies)

if [ -n "$missing_dependencies" ]; then
    # If there are missing dependencies, install them
    echo "The following dependencies are missing and will be installed: $missing_dependencies"
    sudo pacman -S $missing_dependencies
else
    echo "All dependencies for $package are installed."
fi

echo "Done!"
