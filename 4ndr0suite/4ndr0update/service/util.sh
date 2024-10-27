#!/bin/bash

# Maximum retries for system commands
MAX_RETRIES=3
RETRY_DELAY=2  # seconds

# Function to retry a command with a delay if it fails
retry_command() {
    local retries="$MAX_RETRIES"
    local delay="$RETRY_DELAY"
    local cmd="$*"

    until $cmd; do
        ((retries--)) || { echo "Error: Command failed after $MAX_RETRIES attempts: $cmd"; return 1; }
        echo "Retrying... ($retries attempts left)"
        sleep "$delay"
    done
}
