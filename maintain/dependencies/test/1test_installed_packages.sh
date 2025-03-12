#!/usr/bin/env bash
# File: test_installed_packages.sh
# Purpose: Retrieve the list of installed packages using pacman -Qqe and display the count.

# Get installed packages and store in a temporary file
tmp_installed=$(mktemp)
pacman -Qqe > "$tmp_installed" 2>&1

# Count the number of installed packages
count=$(wc -l < "$tmp_installed")
echo "Number of installed packages: $count"

# Optionally, display first 10 packages for inspection
echo "First 10 installed packages:"
head -n 10 "$tmp_installed"

rm -f "$tmp_installed"
