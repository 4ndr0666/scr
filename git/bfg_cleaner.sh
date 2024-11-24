#!/bin/bash

# Description:
# This script automates the process of removing a specified large file from a Git repository's history using BFG Repo-Cleaner.
# It creates a bare repository, runs BFG, cleans the repository, and force pushes the changes.

# Usage:
# ./clean_git_history.sh /path/to/bare-repo.git filename_to_remove

# Example:
# ./clean_git_history.sh /Nas/Build/git/syncing/scr.git permissions_manifest.acl

# Check for correct number of arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 /path/to/bare-repo.git filename_to_remove"
    exit 1
fi

BARE_REPO="$1"
FILE_TO_REMOVE="$2"

# Check if BFG is installed
if ! command -v java &> /dev/null; then
    echo "Java is not installed. Please install Java to use BFG Repo-Cleaner."
    exit 1
fi

if [ ! -f ~/bin/bfg.jar ]; then
    echo "BFG Repo-Cleaner not found at ~/bin/bfg.jar. Please download it first."
    exit 1
fi

# Check if the bare repository exists
if [ ! -d "$BARE_REPO" ]; then
    echo "Bare repository '$BARE_REPO' does not exist."
    exit 1
fi

# Create a temporary mirror clone
TEMP_DIR=$(mktemp -d)
echo "Cloning the bare repository to temporary directory..."
git clone --mirror "$BARE_REPO" "$TEMP_DIR"

# Run BFG to remove the specified file
echo "Running BFG to delete '$FILE_TO_REMOVE'..."
java -jar ~/bin/bfg.jar --delete-files "$FILE_TO_REMOVE" "$TEMP_DIR"

# Navigate to the temporary clone
cd "$TEMP_DIR" || exit

# Perform garbage collection
echo "Performing garbage collection..."
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# Force push the cleaned history back to the bare repository
echo "Force pushing the cleaned history back to '$BARE_REPO'..."
git push --force --mirror "$BARE_REPO"

# Cleanup
echo "Cleaning up temporary directory..."
rm -rf "$TEMP_DIR"

echo "Cleaning process completed successfully."

exit 0
