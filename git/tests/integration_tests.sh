#!/usr/bin/env bash
# shellcheck disable=all
set -euo pipefail

echo "Running integration tests..."

# Example Test 1: Check if all .sh scripts are executable
echo "Checking if all .sh scripts are executable..."
if find . -type f -name "*.sh" ! -executable | grep -q .; then
    echo "Error: Some scripts are not executable."
    exit 1
fi

# Example Test 2: Run shellcheck on all .sh scripts
echo "Running shellcheck on all .sh scripts..."
find . -type f -name "*.sh" -exec shellcheck {} \;

echo "All integration tests passed."
exit 0
