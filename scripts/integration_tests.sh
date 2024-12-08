#!/usr/bin/env bash
set -euo pipefail

echo "Running integration tests..."

# Example test: Check if all scripts are executable
if find . -type f -name "*.sh" ! -executable | grep -q .; then
    echo "Error: Some scripts are not executable."
    exit 1
fi

# Add additional integration tests as needed
echo "All integration tests passed."
exit 0
