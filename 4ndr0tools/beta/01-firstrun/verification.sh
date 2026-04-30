#!/bin/bash
# shellcheck disable=all

# --- Backup Verification ---

# Function to verify backup integrity
verify_backup() {
    echo "Verifying backup tarballs in /var/recover..."
    for file in /var/recover/*.tar.gz; do
        if tar -tzf "$file" > /dev/null; then
            echo "$file is valid."
        else
            echo "Error: $file is corrupted!"
        fi
    done
    echo "Backup verification completed."
}

# Main function to execute backup verification
main() {
    verify_backup
}

# Execute the main function
main
