#!/usr/bin/env bash
# File: test_install_decision.sh
# Purpose: Test the decision logic to determine whether to install a dependency via pacman or yay.

# Define the is_in_official_repo function
is_in_official_repo() {
    local dep="$1"
    pacman -Si "$dep" > /dev/null 2>&1
}

# Test dependencies: one that is known to be in the official repo (e.g., glibc) and one fake
official_dep="glibc"
fake_dep="nonexistent-dep-12345"

echo "Testing official repository check:"
if is_in_official_repo "$official_dep"; then
    echo "SUCCESS: '$official_dep' found in official repos. (Install via pacman)"
else
    echo "FAIL: '$official_dep' not found in official repos."
fi

echo ""
echo "Testing AUR fallback check:"
if is_in_official_repo "$fake_dep"; then
    echo "FAIL: '$fake_dep' incorrectly found in official repos."
else
    echo "SUCCESS: '$fake_dep' not found in official repos. (Would install via yay)"
fi
