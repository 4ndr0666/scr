#!/bin/bash

# Check if running with escalated privileges
if [[ $EUID -ne 0 ]]; then
    echo "This script requires escalated privileges. Please run it as root or using sudo."
    exit 1
fi

set -e  # Exit immediately if any command fails

# Update all installed packages
python3 -m pip install --use-pep517 --exists-action w --break-system-packages -U $(python3 -m pip list outdated 2> /dev/null | grep -v 'Version' | grep -v '\-\-\-\-\-\-' | awk '{printf $1 " " }' && echo)

# List all globally installed packages
global_packages=$(pip list --format=freeze)

# Create a temporary requirements.txt file
requirements_file="requirements.txt"
echo "# Packages not available in pipx" > "$requirements_file"

# Loop through the packages and check if they are installed by pipx
for package in $global_packages; do
    package_name=$(echo "$package" | cut -d'=' -f1)
    if pipx list | grep -q "$package_name"; then
        echo "Package $package_name is installed by pipx"
    else
        echo "Package $package_name is not installed by pipx"
        echo "$package" >> "$requirements_file"
        pip uninstall -y "$package_name"
        pipx install "$package_name"
    fi
done

echo "Packages not available in pipx are listed in $requirements_file"
