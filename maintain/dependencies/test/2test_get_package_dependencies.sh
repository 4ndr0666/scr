#!/usr/bin/env bash
# File: test_get_package_dependencies.sh
# Purpose: Retrieve and display the "Depends On" field from pacman -Si for a sample package.

sample_pkg="bat"  # Change this to a known installed package if needed

echo "Retrieving dependency information for package: $sample_pkg"
deps=$(pacman -Si "$sample_pkg" 2>/dev/null | grep -i "^Depends On" | cut -d: -f2 | sed 's/^[[:space:]]*//')

if [ -z "$deps" ]; then
    echo "No dependencies found or package '$sample_pkg' not found."
else
    echo "Depends On: $deps"
fi
