#!/bin/bash

# --- Function Definitions ---

# Log a message with a timestamp
log_message() {
    local message="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $message"
}

# Function to run git lfs prune
cleanup_lfs_cache() {
    log_message "Cleaning up Git LFS cache..."
    git lfs prune
}

# Function to check and ensure all LFS objects are properly staged
check_lfs_status() {
    log_message "Checking Git LFS status..."
    git lfs status
}

# Function to force push all LFS objects
force_push_lfs_objects() {
    log_message "Force pushing all Git LFS objects..."
    git lfs push --all origin main
}

# Function to push regular commits
push_commits() {
    log_message "Pushing commits to the remote repository..."
    git push origin main
}

# Function to reinitialize LFS tracking
reinitialize_lfs_tracking() {
    local file_patterns=("*.tar.gz" "*.zip")
    log_message "Reinitializing LFS tracking for patterns: ${file_patterns[*]}"

    for pattern in "${file_patterns[@]}"; do
        git lfs untrack "$pattern"
    done

    git add .gitattributes
    git commit -m "Untrack files from LFS"

    for pattern in "${file_patterns[@]}"; do
        git lfs track "$pattern"
    done

    git add .gitattributes
    for pattern in "${file_patterns[@]}"; do
        git add "$pattern"
    done

    git commit -m "Re-track files with LFS"
}

# Function to handle errors and print them
handle_errors() {
    local error_file="$1"
    local error_message="$2"
    if [[ -e "$error_file" && ! -w "$error_file" ]]; then
        log_message "$error_message $error_file due to lock."
    fi
}

# Function to retry pushing LFS objects
retry_push_lfs_objects() {
    log_message "Retrying push of all Git LFS objects..."
    git lfs push --all origin main
}

# Function to automate the entire process
automate_git_lfs_resolution() {
    cleanup_lfs_cache
    check_lfs_status
    force_push_lfs_objects

    log_message "Checking for unstaged/staged changes..."
    if ! git diff-index --quiet HEAD --; then
        git add .
        git commit -m "Committing local changes"
    fi

    push_commits

    local error_files=(
        "/root/.bashrc"
        "/root/.zshrc"
        "/root/.config/fish/config.fish"
    )
    for error_file in "${error_files[@]}"; do
        handle_errors "$error_file" "Could not modify"
    done

    reinitialize_lfs_tracking
    push_commits

    log_message "Retrying push of all Git LFS objects to ensure no unknown objects remain..."
    retry_push_lfs_objects
}

# --- Main Execution ---

log_message "Starting automated Git LFS resolution script..."
automate_git_lfs_resolution
log_message "Completed Git LFS resolution script."
