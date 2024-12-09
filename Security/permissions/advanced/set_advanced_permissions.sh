#!/bin/bash

# Directory to check (default to /etc if no argument is given)
TARGET_DIR="${1:-/etc}"

# Directories to exclude from permission checks
EXCLUDED_DIRS=(
    "/etc/skel"
    # Add more directories to exclude as needed
)

# Function to check if a directory should be excluded
is_excluded() {
    local dir_to_check=$1
    for excluded_dir in "${EXCLUDED_DIRS[@]}"; do
        if [[ "$dir_to_check" == "$excluded_dir"* ]]; then
            return 0 # True: The directory is excluded
        fi
    done
    return 1 # False: The directory is not excluded
}

# Function to set standard permissions using chmod
set_standard_permissions() {
    local file=$1
    local permission=$2
    echo "Setting standard permissions $permission on $file"
    sudo chmod "$permission" "$file"
}

# Function to set setuid bit if not set
set_setuid() {
    local file=$1
    if [ ! -u "$file" ]; then
        echo "Setting setuid on $file"
        sudo chmod u+s "$file"
    else
        echo "$file already has setuid set."
    fi
}

# Function to set setgid bit if not set
set_setgid() {
    local file=$1
    if [ ! -g "$file" ]; then
        echo "Setting setgid on $file"
        sudo chmod g+s "$file"
    else
        echo "$file already has setgid set."
    fi
}

# Function to set sticky bit if not set
set_sticky_bit() {
    local file=$1
    if [ ! -k "$file" ]; then
        echo "Setting sticky bit on $file"
        sudo chmod +t "$file"
    else
        echo "$file already has sticky bit set."
    fi
}

# Function to apply ACLs for finer-grained control
set_acl() {
    local file=$1
    local acl_entry=$2
    echo "Setting ACL on $file: $acl_entry"
    sudo setfacl -m "$acl_entry" "$file"
}

# Main function to process all files and directories in the target directory
main() {
    echo "Checking permissions in $TARGET_DIR..."

    # Find all files and directories, excluding specified paths
    find "$TARGET_DIR" -type f -o -type d | while read -r file; do
        # Skip excluded directories
        if is_excluded "$file"; then
            echo "Skipping excluded directory: $file"
            continue
        fi

        # Apply default permissions based on file type
        if [ -f "$file" ]; then
            # Set standard permissions for files (e.g., 755)
            set_standard_permissions "$file" "755"
        elif [ -d "$file" ]; then
            # Set standard permissions for directories (e.g., 775)
            set_standard_permissions "$file" "775"
            # Also set sticky bit for directories
            set_sticky_bit "$file"
        fi

        # Apply special permission bits
        set_setuid "$file"
        set_setgid "$file"

        # Apply example ACL (customize as needed)
        set_acl "$file" "u::rw-,g::r--,o::r--"
    done

    echo "Permission setting process complete."
}

# Execute the main function
main

