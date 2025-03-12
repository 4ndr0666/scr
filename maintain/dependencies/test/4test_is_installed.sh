#!/usr/bin/env bash
# File: test_is_installed.sh
# Purpose: Test the function that checks if a dependency is installed.

# Define the is_installed function
is_installed() {
    local dep="$1"
    pacman -Qq "$dep" > /dev/null 2>&1
}

# Test with a known installed package (change if needed)
known_dep="glibc"
# Test with a fake dependency that should not be installed
fake_dep="nonexistent-dep-12345"

echo "Testing if '$known_dep' is installed:"
if is_installed "$known_dep"; then
    echo "SUCCESS: '$known_dep' is installed."
else
    echo "FAIL: '$known_dep' is NOT installed."
fi

echo ""
echo "Testing if '$fake_dep' is installed:"
if is_installed "$fake_dep"; then
    echo "FAIL: '$fake_dep' is reported as installed."
else
    echo "SUCCESS: '$fake_dep' is not installed."
fi
