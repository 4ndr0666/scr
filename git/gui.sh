#!/bin/bash
# shellcheck disable=all
# File: gui.sh
# Author: 4ndr0666
# Edited: 12-16-2024

# ============================== // GUI.SH //
# --- // Colors:
GREEN='\033[0;32m'
BOLD='\033[1m'
RED='\033[0;31m'
NC='\033[0m' # No Color
SUCCESS="✔️"
FAILURE="❌"
INFO="➡️"
EXPLOSION="💥"
prominent() {
    echo -e "${BOLD}${GREEN}$1${NC}"
}

bug() {
    echo -e "${BOLD}${RED}$1${NC}"
}

echo_cyan() { echo -e "\e[36m$1\e[0m"; }

# Function to check and set up SSH key for GitHub
check_and_setup_ssh() {
    local ssh_key="${HOME}/.ssh/id_ed25519"

    if [ -f "$ssh_key" ]; then
        prominent "SSH key exists."
    else
        prominent "SSH key not found. Creating one now..."
        ssh-keygen -t ed25519 -C "01_dolor.loftier@icloud.com" -f "$ssh_key" -N ""
        eval "$(ssh-agent -s)"
        ssh-add "$ssh_key"
        echo "SSH key created and added to the ssh-agent."

        echo_cyan "Please manually upload the SSH key to GitHub."
        gh auth login
        gh ssh-key add "$ssh_key.pub"
    fi
}

# --- // MANAGE_REMOTES:
list_and_manage_remotes() {
    prominent "Current Git remotes:"
    git remote -v
    read -rp "Would you like to remove any remotes? (yes/no): " response
    if [[ "$response" =~ ^[yY] ]]; then
        local remotes
        remotes=$(git remote)
        local remote_to_remove
        remote_to_remove=$(echo "$remotes" | fzf --height=40% --prompt="Select a remote to remove: ")
        if [ -n "$remote_to_remove" ]; then
            if git remote | grep -q "^$remote_to_remove$"; then
                git remote remove "$remote_to_remove"
                prominent "Remote '$remote_to_remove' has been removed."
            else
                bug "Remote '$remote_to_remove' not found."
            fi
        else
            echo "No remotes removed."
        fi
    else
        echo "No changes made to remotes."
    fi
}

# --- // SWITCH_GCLONE_TO_SSH:
switch_to_ssh() {
    local remote_name
    remote_name=$(git remote | fzf --height=40% --prompt="Select a remote to switch to SSH: ")

    if [ -z "$remote_name" ]; then
        bug "No remote selected."
        return
    fi

    local old_url new_url
    old_url=$(git remote get-url "$remote_name")

    if [[ "$old_url" == git@github.com:* ]]; then
        prominent "The remote '$remote_name' is already using SSH."
        return
    fi

    local user_repo
    user_repo=${old_url#*github.com/}
    user_repo=${user_repo%.git}
    new_url="git@github.com:4ndr0666/$user_repo.git"

    # Check if the repository exists, if not, prompt to create it
    if ! gh repo view "4ndr0666/$user_repo" >/dev/null 2>&1; then
        read -rp "Repository '4ndr0666/$user_repo' does not exist on GitHub. Would you like to create it? (y/n): " create_repo
        if [[ "$create_repo" =~ ^[yY]$ ]]; then
            if gh repo create "4ndr0666/$user_repo" --private --confirm; then
                prominent "Repository '4ndr0666/$user_repo' created successfully on GitHub."
            else
                bug "Failed to create repository '4ndr0666/$user_repo' on GitHub."
                return 1
            fi
        else
            bug "Repository creation skipped. Aborting SSH switch."
            return 1
        fi
    fi

    git remote set-url "$remote_name" "$new_url"
    prominent "Switched '$remote_name' to use SSH: $new_url"
}

# --- // UPDATE_REMOTE_URL:
update_remote_url() {
    local repo_base="https://github.com/4ndr0666/"
    local repos
    repos=$(gh repo list 4ndr0666 -L 100 --json name -q '.[].name')

    if [ -z "$repos" ]; then
        bug "No repositories found under '4ndr0666'."
        return 1
    fi

    prominent "Select the repository you want to update:"
    local repo_name
    repo_name=$(echo "$repos" | fzf --height=40% --prompt="Select repository: ")

    if [ -z "$repo_name" ]; then
        bug "No repository selected. Aborting update."
        return 1
    fi

    local new_url="${repo_base}${repo_name}.git"

    # Check if the repository exists, if not, prompt to create it
    if ! gh repo view "4ndr0666/$repo_name" >/dev/null 2>&1; then
        read -rp "Repository '4ndr0666/$repo_name' does not exist on GitHub. Would you like to create it? (y/n): " create_repo
        if [[ "$create_repo" =~ ^[yY]$ ]]; then
            if gh repo create "4ndr0666/$repo_name" --private --confirm; then
                prominent "Repository '4ndr0666/$repo_name' created successfully on GitHub."
            else
                bug "Failed to create repository '4ndr0666/$repo_name' on GitHub."
                return 1
            fi
        else
            bug "Repository creation skipped. Aborting remote URL update."
            return 1
        fi
    fi

    git remote set-url origin "$new_url"
    prominent "Remote URL updated to $new_url"
}

# --- // REMOTE_FETCH:
fetch_from_remote() {
    prominent "Fetching updates from remote..."
    git fetch origin
    prominent "Fetch complete."
}

# --- // REMOTE_PULL:
pull_from_remote() {
    local current_branch
    current_branch=$(git branch --show-current)
    prominent "Pulling updates from remote for branch '$current_branch'..."
    git pull origin "$current_branch"
    prominent "Pull complete."
}

# --- // REMOTE_PUSH:
push_to_remote() {
    local current_branch
    current_branch=$(git branch --show-current)
    
    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        prominent "Uncommitted changes detected. Staging and committing them..."
        git add -A
        local auto_message="Auto-commit: Pushing changes on $(date +%Y-%m-%d_%H:%M:%S)"
        git commit -m "$auto_message"
        prominent "Changes committed with message: '$auto_message'"
    fi

    prominent "Pushing local branch '$current_branch' to remote..."
    git push -u origin "$current_branch"
    prominent "Push complete."
}

# --- // LIST_BRANCHES:
list_branches() {
    prominent "Available branches:"
    git branch
}

# --- // SWITCH_BRANCH:
switch_branch() {
    prominent "Select the branch you want to switch to:"
    local branches
    branches=$(git branch | sed 's/* //')
    local branch_name
    branch_name=$(echo "$branches" | fzf --height=40% --prompt="Select branch: ")

    if [ -z "$branch_name" ]; then
        bug "No branch selected. Aborting switch."
        return 1
    fi

    # Confirm selection
    read -rp "Are you sure you want to switch to branch '$branch_name'? (y/n): " confirm
    if [[ "$confirm" != [yY] ]]; then
        prominent "Switch branch action canceled."
        return 0
    fi

    if git checkout "$branch_name"; then
        prominent "Switched to branch '$branch_name'."
    else
        bug "Failed to switch to branch '$branch_name'. Ensure it exists."
    fi
}

# --- // CREATE_BRANCH:
create_new_branch() {
    read -rp "Enter new branch name: " new_branch

    if [ -z "$new_branch" ]; then
        bug "No branch name provided. Aborting creation."
        return 1
    fi

    # Confirm creation
    read -rp "Are you sure you want to create and switch to branch '$new_branch'? (y/n): " confirm
    if [[ "$confirm" != [yY] ]]; then
        prominent "Create branch action canceled."
        return 0
    fi

    if git checkout -b "$new_branch"; then
        prominent "Branch '$new_branch' created and checked out."
    else
        bug "Failed to create branch '$new_branch'. It may already exist."
    fi
}

# --- // DELETE_BRANCH:
delete_branch() {
    prominent "Select the branch you want to delete:"
    local branches
    branches=$(git branch | sed 's/* //')
    local del_branch
    del_branch=$(echo "$branches" | fzf --height=40% --prompt="Select branch to delete: ")

    if [ -z "$del_branch" ]; then
        bug "No branch selected. Aborting deletion."
        return 1
    fi

    # Confirm deletion
    read -rp "Are you sure you want to delete branch '$del_branch'? (y/n): " confirm
    if [[ "$confirm" != [yY] ]]; then
        prominent "Delete branch action canceled."
        return 0
    fi

    if git branch --list "$del_branch" > /dev/null; then
        git branch -d "$del_branch"
        prominent "Branch '$del_branch' deleted."
    else
        bug "Branch '$del_branch' does not exist."
    fi
}

# --- // RECONNECT_OLD_REPO:
reconnect_old_repo() {
    read -rp "Do you know the remote URL or name? (URL/Name): " reconnect_type
    case "$reconnect_type" in
        URL|url)
            read -rp "Enter the remote URL: " reconnect_url
            # Extract repo name from URL
            local repo_name
            repo_name=$(basename "$reconnect_url" .git)
            # Check if repo exists under '4ndr0666'
            if ! gh repo view "4ndr0666/$repo_name" >/dev/null 2>&1; then
                read -rp "Repository '4ndr0666/$repo_name' does not exist on GitHub. Would you like to create it? (y/n): " create_repo
                if [[ "$create_repo" =~ ^[yY]$ ]]; then
                    if gh repo create "4ndr0666/$repo_name" --private --confirm; then
                        prominent "Repository '4ndr0666/$repo_name' created successfully on GitHub."
                    else
                        bug "Failed to create repository '4ndr0666/$repo_name' on GitHub."
                        return 1
                    fi
                else
                    bug "Repository creation skipped. Aborting reconnect."
                    return 1
                fi
            fi
            git remote add origin "$reconnect_url"
            prominent "Remote 'origin' added with URL '$reconnect_url'."
            ;;
        Name|name)
            read -rp "Enter the remote name (e.g., 'repo'): " reconnect_name
            local new_url="git@github.com:4ndr0666/$reconnect_name.git"
            # Check if repo exists under '4ndr0666'
            if ! gh repo view "4ndr0666/$reconnect_name" >/dev/null 2>&1; then
                read -rp "Repository '4ndr0666/$reconnect_name' does not exist on GitHub. Would you like to create it? (y/n): " create_repo
                if [[ "$create_repo" =~ ^[yY]$ ]]; then
                    if gh repo create "4ndr0666/$reconnect_name" --private --confirm; then
                        prominent "Repository '4ndr0666/$reconnect_name' created successfully on GitHub."
                    else
                        bug "Failed to create repository '4ndr0666/$reconnect_name' on GitHub."
                        return 1
                    fi
                else
                    bug "Repository creation skipped. Aborting reconnect."
                    return 1
                fi
            fi
            git remote add origin "$new_url"
            prominent "Remote 'origin' added with SSH URL '$new_url'."
            ;;
        *)
            bug "Invalid option. Exiting..."
            return 1
            ;;
    esac
}

# --- // STASHES:
manage_stashes() {
    echo "1. Stash Changes"
    echo "2. List Stashes"
    echo "3. Apply Latest Stash"
    echo "4. Pop Latest Stash"
    echo "5. Clear All Stashes"
    echo "6. Show Stash Contents"
    echo "7. Apply Specific Stash"
    echo "8. Drop Specific Stash"
    read -rp "Enter your choice (1-8): " stash_choice

    case "$stash_choice" in
        1)
            read -rp "Enter a message for the stash (optional): " message
            if git stash push -m "$message"; then
                prominent "Changes stashed. ${SUCCESS}"
            else
                bug "Failed to stash changes. ${FAILURE}"
            fi
            ;;
        2)
            echo "Stash list:"
            git stash list
            ;;
        3)
            if git stash apply; then
                prominent "Latest stash applied. ${SUCCESS}"
            else
                bug "Failed to apply latest stash. ${FAILURE}"
            fi
            ;;
        4)
            if git stash pop; then
                prominent "Latest stash popped and removed. ${SUCCESS}"
            else
                bug "Failed to pop latest stash. ${FAILURE}"
            fi
            ;;
        5)
            read -rp "Are you sure you want to clear all stashes? (y/n): " confirm_clear
            if [[ "$confirm_clear" =~ ^[yY]$ ]]; then
                if git stash clear; then
                    prominent "All stashes cleared. ${SUCCESS}"
                else
                    bug "Failed to clear stashes. ${FAILURE}"
                fi
            else
                prominent "Clear stashes action canceled."
            fi
            ;;
        6)
            read -rp "Enter stash @{number} to show contents (e.g., stash@{0}): " stash_number
            if git stash show -p "$stash_number"; then
                prominent "Displayed contents of $stash_number."
            else
                bug "Failed to show contents of $stash_number. Ensure it exists."
            fi
            ;;
        7)
            read -rp "Enter stash @{number} to apply (e.g., stash@{0}): " stash_number
            if git stash apply "$stash_number"; then
                prominent "Specific stash '$stash_number' applied. ${SUCCESS}"
            else
                bug "Failed to apply stash '$stash_number'. ${FAILURE}"
            fi
            ;;
        8)
            read -rp "Enter stash @{number} to drop (e.g., stash@{0}): " stash_number
            if git stash drop "$stash_number"; then
                prominent "Specific stash '$stash_number' dropped. ${SUCCESS}"
            else
                bug "Failed to drop stash '$stash_number'. ${FAILURE}"
            fi
            ;;
        *)
            bug "Invalid choice! ${FAILURE}"
            ;;
    esac
}

# --- // CHERRY_PICK_COMMITS:
cherry_pick_commits() {
    prominent "Fetching latest commits..."
    git fetch --all

    local commits
    commits=$(git log --oneline --graph --all)

    local selected_commit
    selected_commit=$(echo "$commits" | fzf --height=40% --prompt="Select a commit to cherry-pick: " | awk '{print $NF}')

    if [ -z "$selected_commit" ]; then
        bug "No commit selected. Aborting cherry-pick."
        return 1
    fi

    # Confirm selection
    read -rp "Are you sure you want to cherry-pick commit $selected_commit? (y/n): " confirm
    if [[ "$confirm" != [yY] ]]; then
        prominent "Cherry-pick canceled."
        return 0
    fi

    # Attempt to cherry-pick
    if git cherry-pick "$selected_commit"; then
        prominent "Commit $selected_commit cherry-picked successfully."
    else
        bug "Cherry-pick failed. Please resolve conflicts manually."
    fi
}

# --- // RESTORE_BRANCH:
restore_branch() {
    prominent "Retrieving commit history..."
    local commits
    commits=$(git log --oneline --all)

    local selected_commit
    selected_commit=$(echo "$commits" | fzf --height=40% --prompt="Select a commit to restore: " | awk '{print $NF}')

    if [ -z "$selected_commit" ]; then
        bug "No commit selected. Aborting restore."
        return 1
    fi

    # Confirm selection
    read -rp "Are you sure you want to restore commit $selected_commit? This will create a new branch. (y/n): " confirm
    if [[ "$confirm" != [yY] ]]; then
        prominent "Restore process canceled."
        return 0
    fi

    # Create new branch from selected commit
    local branch_name="restore-$(date +%Y%m%d%H%M%S)"
    if git checkout -b "$branch_name" "$selected_commit"; then
        prominent "New branch '$branch_name' created at commit $selected_commit."
    else
        bug "Failed to create and switch to branch '$branch_name'."
        return 1
    fi

    # Optionally merge into main branch
    read -rp "Do you want to merge changes into your main branch and push to remote? (y/n): " merge_choice

    if [[ $merge_choice =~ ^[Yy]$ ]]; then
        # Hardcoded main branch name
        local main_branch="main"

        # Check if main branch exists
        if git show-ref --verify --quiet "refs/heads/$main_branch"; then
            git checkout "$main_branch"
        else
            bug "Main branch '$main_branch' does not exist."
            return 1
        fi

        # Merge the restored branch
        if git merge "$branch_name"; then
            prominent "Branch '$branch_name' merged into '$main_branch' successfully."
        else
            bug "Merge failed. Please resolve conflicts manually."
            return 1
        fi

        # Push to remote
        if git push origin "$main_branch"; then
            prominent "Changes pushed to remote repository."
        else
            bug "Failed to push changes to remote."
        fi
    else
        prominent "Skipping merge and push to remote repository."
    fi
}

# --- // REVERT_VERSION:
revert_version() {
    prominent "Recent actions in the repository:"
    git reflog -10

    local reflog_entry
    reflog_entry=$(git reflog | awk '{print $1}' | fzf --height=40% --prompt="Select a reflog entry to revert to: ")

    if [ -z "$reflog_entry" ]; then
        bug "No reflog entry selected. Aborting revert."
        return 1
    fi

    # Confirm selection
    read -rp "Are you sure you want to revert to $reflog_entry? This action is irreversible. (yes/no): " confirmation

    if [[ "$confirmation" == "yes" ]]; then
        if git reset --hard "$reflog_entry"; then
            prominent "Reverted to $reflog_entry successfully."
        else
            bug "Failed to revert. Ensure the reflog entry is correct."
            return 1
        fi
    else
        prominent "Revert action canceled."
        return 0
    fi
}

# --- // VIEW_COMMIT_HISTORY:
view_commit_history() {
    prominent "Showing commit history for the current branch:"
    git log --oneline --graph --decorate | less
}

# --- // REBASE_BRANCH:
rebase_branch() {
    prominent "Select the base branch to rebase onto:"
    local base_branch
    base_branch=$(git branch --all | grep -v HEAD | sed 's/remotes\///' | sort | uniq | fzf --height=40% --prompt="Select base branch: ")

    if [ -z "$base_branch" ]; then
        bug "No base branch selected. Aborting rebase."
        return 1
    fi

    # Confirm selection
    read -rp "Are you sure you want to rebase the current branch onto '$base_branch'? (y/n): " confirm
    if [[ "$confirm" != [yY] ]]; then
        prominent "Rebase action canceled."
        return 0
    fi

    # Attempt to rebase
    if git rebase "$base_branch"; then
        prominent "Current branch rebased onto '$base_branch' successfully."
    else
        bug "Rebase failed. Please resolve conflicts manually."
    fi
}

# --- // RESOLVE_MERGE_CONFLICTS:
resolve_merge_conflicts() {
    prominent "Select the branch you want to merge into the current branch:"
    local target_branch
    target_branch=$(git branch --all | grep -v HEAD | sed 's/remotes\///' | sort | uniq | fzf --height=40% --prompt="Select target branch: ")

    if [ -z "$target_branch" ]; then
        bug "No target branch selected. Aborting merge."
        return 1
    fi

    # Confirm selection
    read -rp "Are you sure you want to merge '$target_branch' into the current branch? (y/n): " confirm
    if [[ "$confirm" != [yY] ]]; then
        prominent "Merge action canceled."
        return 0
    fi

    # Attempt to merge
    if git merge "$target_branch"; then
        prominent "Branch '$target_branch' merged successfully."
    else
        bug "Merge resulted in conflicts."
        # Prompt to resolve conflicts automatically
        read -rp "Would you like to attempt automatic conflict resolution? (y/n): " resolve_confirm
        if [[ "$resolve_confirm" == [yY] ]]; then
            resolve_git_conflicts_automatically
            # After attempting to resolve, check if merge was successful
            if git merge --continue 2>/dev/null; then
                prominent "Merge completed after automatic conflict resolution."
            else
                bug "Automatic conflict resolution failed. Please resolve conflicts manually."
            fi
        else
            prominent "Please resolve conflicts manually."
        fi
    fi
}

# --- // FIX_GIT_REPOSITORY:
fix_git_repository() {
    prominent "Starting Git Repository Fix Process..."

    # Step 1: Backup the repository
    local backup_dir="../git_repo_backup_$(date +%Y%m%d_%H%M%S)"
    prominent "Backing up current repository to $backup_dir"
    cp -r . "$backup_dir"
    if [ $? -eq 0 ]; then
        prominent "Backup completed successfully."
    else
        bug "Backup failed. Aborting."
        return 1
    fi

    # Step 2: Disable Git hooks
    local hooks_dir=".git/hooks"
    if [ -d "$hooks_dir" ]; then
        prominent "Disabling Git hooks by renaming them."
        for hook in "$hooks_dir"/*; do
            [ -e "$hook" ] || continue
            hook_name=$(basename "$hook")
            if [ -x "$hook" ] && [[ "$hook_name" != *.sample ]]; then
                mv "$hook" "${hook}.disabled"
                prominent "Disabled hook: $hook_name"
            fi
        done
    else
        bug "Git hooks directory not found."
    fi

    # Step 3: Run Git Integrity Checks
    prominent "Running 'git fsck --full' to identify bad references."
    local fsck_output
    fsck_output=$(git fsck --full 2>&1) || true
    echo "$fsck_output"

    # Parse bad refs
    local bad_refs=()
    while IFS= read -r line; do
        if [[ "$line" =~ ^(error|warning):\ +([^\ ]+)\ +(.+)$ ]]; then
            # Extract the ref name
            local ref_name="${BASH_REMATCH[2]}"
            bad_refs+=("$ref_name")
        fi
    done <<< "$fsck_output"

    if [ ${#bad_refs[@]} -eq 0 ]; then
        prominent "No bad references found."
    else
        prominent "Found bad references:"
        for ref in "${bad_refs[@]}"; do
            prominent "  - $ref"
            # Remove the bad ref
            git update-ref -d "$ref" || bug "Failed to delete ref: $ref"
        done
    fi

    # Additionally, remove any refs containing '_zsh_highlight_highlighter_cursor_predicate'
    local specific_bad_ref
    specific_bad_ref=$(git show-ref | grep '_zsh_highlight_highlighter_cursor_predicate' || true)
    if [ -n "$specific_bad_ref" ]; then
        local ref_name
        ref_name=$(echo "$specific_bad_ref" | awk '{print $2}')
        prominent "Removing specific bad reference: $ref_name"
        git update-ref -d "$ref_name" || bug "Failed to delete ref: $ref_name"
    else
        prominent "No references found containing '_zsh_highlight_highlighter_cursor_predicate'."
    fi

    # Step 4: Prune Reflog and Run Garbage Collection
    prominent "Expiring reflog entries."
    git reflog expire --expire=now --all

    prominent "Running 'git gc --prune=now --aggressive'."
    if git gc --prune=now --aggressive; then
        prominent "'git gc' executed successfully."
    else
        bug "Error: 'git gc' failed."
        return 1
    fi

    # Step 5: Rebuild Commit Graph
    prominent "Rebuilding commit graph."
    if git commit-graph write --reachable; then
        prominent "Commit graph rebuilt successfully."
    else
        bug "Error: Failed to rebuild commit graph."
        return 1
    fi

    # Step 6: Verify Repository Integrity
    prominent "Verifying repository integrity with 'git fsck --full'."
    if git fsck --full; then
        prominent "Repository integrity verified successfully."
    else
        bug "Error: Repository integrity check failed."
        return 1
    fi

    # Optional Step 7: Re-enable Git Hooks
    # Uncomment the following lines if you wish to re-enable hooks after fixing
    # if [ -d "$hooks_dir" ]; then
    #     prominent "Re-enabling Git hooks."
    #     for hook in "$hooks_dir"/*.disabled; do
    #         [ -e "$hook" ] || continue
    #         mv "$hook" "${hook%.disabled}"
    #         hook_name=$(basename "$hook" .disabled)
    #         prominent "Re-enabled hook: $hook_name"
    #     done
    # fi

    prominent "Git repository fix process completed successfully."
}

# --- // SETUP_GIT_HOOKS:
setup_git_hooks() {
    prominent "Setting up Git hooks..."

    # Define the hooks directory
    local GIT_HOOKS_DIR=".git/hooks"

    # Ensure the hooks directory exists
    if [ ! -d "$GIT_HOOKS_DIR" ]; then
        bug ".git/hooks directory not found. Ensure this script is run in the root of a Git repository."
        return 1
    fi

    # Log file
    local HOOKS_LOG="$GIT_HOOKS_DIR/hooks_setup.log"
    echo "Git hooks setup started at $(date)" > "$HOOKS_LOG"

    # Function to install or update a hook
    install_hook() {
        local hook_name="$1"
        local hook_content="$2"

        local hook_path="$GIT_HOOKS_DIR/$hook_name"

        # Backup existing hook if it exists and is not a sample
        if [ -f "$hook_path" ] && [[ "$hook_path" != *".sample" ]]; then
            cp "$hook_path" "${hook_path}.backup.$(date +%s)"
            echo "Backed up existing hook: $hook_path" | tee -a "$HOOKS_LOG"
        fi

        # Install the new hook
        echo "$hook_content" > "$hook_path"
        chmod +x "$hook_path"
        echo "Installed/Updated hook: $hook_path" | tee -a "$HOOKS_LOG"
    }

    # Enhanced commit-msg hook
    COMMIT_MSG_HOOK='#!/usr/bin/env bash
set -euo pipefail

# Enforce commit message standards
# 1. Subject line <= 72 characters
# 2. No placeholders
# 3. Proper format

COMMIT_MSG_FILE="$1"

if [ ! -f "$COMMIT_MSG_FILE" ]; then
    echo "Error: Commit message file not found: $COMMIT_MSG_FILE"
    exit 1
fi

COMMIT_MSG_CONTENT=$(cat "$COMMIT_MSG_FILE")

# Ensure commit message is not empty
if [ -z "$COMMIT_MSG_CONTENT" ]; then
    echo "Error: Commit message is empty."
    exit 1
fi

# Check subject line length
SUBJECT_LINE=$(head -n 1 "$COMMIT_MSG_FILE")
if [ ${#SUBJECT_LINE} -gt 72 ]; then
    echo "Error: Subject line exceeds 72 characters."
    echo "Subject: $SUBJECT_LINE"
    exit 1
fi

# Forbidden words check (no placeholders)
if echo "$COMMIT_MSG_CONTENT" | grep -qi "placeholder"; then
    echo "Error: Commit message contains forbidden word: 'placeholder'."
    exit 1
fi

echo "Commit message check passed."
exit 0
'

    # Enhanced pre-commit hook
    PRE_COMMIT_HOOK='#!/bin/bash
set -euo pipefail

# Pre-commit hook to enforce:
# 1. No large files (>100MB)
# 2. Run shfmt and shellcheck on staged .sh files

# Maximum allowed file size in KB
MAX_SIZE=100000  # 100 MB

# Check for large files
for file in $(git diff --cached --name-only --diff-filter=ACM | grep -E "\.sh$"); do
    if [ -f "$file" ]; then
        size=$(du -k "$file" | cut -f1)
        if [ "$size" -gt "$MAX_SIZE" ]; then
            echo "Error: Attempting to commit large file '$file' ($size KB)."
            exit 1
        fi
    fi
done

# Get list of staged shell scripts
scripts=$(git diff --cached --name-only --diff-filter=ACM | grep -E "\.sh$")

if [ -z "$scripts" ]; then
    exit 0
fi

PASS=true

# Run shfmt for formatting
for script in $scripts; do
    shfmt -w "$script"
    git add "$script"
    echo "Formatted script: $script"
done

# Run shellcheck for linting
for script in $scripts; do
    shellcheck "$script"
    if [ $? -ne 0 ]; then
        PASS=false
        echo "shellcheck issues found in $script"
    fi
done

if ! $PASS; then
    echo "Error: shellcheck found issues. Please fix them before committing."
    exit 1
fi

echo "Pre-commit checks passed."
exit 0
'

    # Enhanced pre-push hook
    PRE_PUSH_HOOK='#!/bin/sh
set -euo pipefail

# Pre-push hook to run integration tests before pushing

# Define the integration tests script path
INTEGRATION_TESTS_SCRIPT="Git/scripts/integration_tests.sh"

if [ -f "$INTEGRATION_TESTS_SCRIPT" ]; then
    echo "Running integration tests..."
    bash "$INTEGRATION_TESTS_SCRIPT"
    if [ $? -ne 0 ]; then
        echo "Error: Integration tests failed. Push aborted."
        exit 1
    fi
    echo "Integration tests passed."
else
    echo "Warning: Integration tests script not found: $INTEGRATION_TESTS_SCRIPT"
    echo "Skipping integration tests."
fi

exit 0
'

    # Additional Hook: post-commit to notify user
    POST_COMMIT_HOOK='#!/bin/sh
# Notify user of a successful commit
COMMIT_MESSAGE=$(git log -1 --pretty=%B | head -n 1)
notify-send "Git" "Commit successful: $COMMIT_MESSAGE"
exit 0
'

    # Install or update commit-msg hook
    install_hook "commit-msg" "$COMMIT_MSG_HOOK"

    # Install or update pre-commit hook
    install_hook "pre-commit" "$PRE_COMMIT_HOOK"

    # Install or update pre-push hook
    install_hook "pre-push" "$PRE_PUSH_HOOK"

    # Install or update post-commit hook
    install_hook "post-commit" "$POST_COMMIT_HOOK"

    # Summary
    echo "Git hooks setup completed successfully." | tee -a "$HOOKS_LOG"
    echo "All Git hooks have been installed and enhanced." | tee -a "$HOOKS_LOG"

    prominent "Git hooks have been set up successfully."
}

# --- // RUN_INTEGRATION_TESTS:
run_integration_tests() {
    local test_script="Git/scripts/integration_tests.sh"

    if [ -f "$test_script" ]; then
        prominent "Running integration tests..."
        bash "$test_script"
        if [ $? -eq 0 ]; then
            prominent "Integration tests passed successfully. ${SUCCESS}"
        else
            bug "Integration tests failed. ${FAILURE}"
        fi
    else
        bug "Integration tests script not found at $test_script."
    fi
}

# --- // RESOLVE_GIT_CONFLICTS_AUTOMATICALLY:
resolve_git_conflicts_automatically() {
    local resolver_script="Git/scripts/automated_git_conflict_resolver.sh"

    if [ -f "$resolver_script" ]; then
        prominent "Running automated Git conflict resolver..."
        bash "$resolver_script"
        if [ $? -eq 0 ]; then
            prominent "Automated conflict resolution completed successfully. ${SUCCESS}"
        else
            bug "Automated conflict resolution failed. ${FAILURE}"
        fi
    else
        bug "Automated conflict resolver script not found at $resolver_script."
    fi
}

# --- // SETUP_CRON_JOB:
setup_cron_job() {
    local cron_script="Git/scripts/setup_cron_job.sh"

    if [ -f "$cron_script" ]; then
        prominent "Setting up cron job..."
        bash "$cron_script"
        if [ $? -eq 0 ]; then
            prominent "Cron job set up successfully. ${SUCCESS}"
        else
            bug "Failed to set up cron job. ${FAILURE}"
        fi
    else
        bug "Cron job setup script not found at $cron_script."
    fi
}

# --- // SETUP_DEPENDENCIES:
setup_dependencies() {
    local dependencies_script="Git/scripts/setup_dependencies.sh"

    if [ -f "$dependencies_script" ]; then
        prominent "Setting up dependencies..."
        bash "$dependencies_script"
        if [ $? -eq 0 ]; then
            prominent "Dependencies set up successfully. ${SUCCESS}"
        else
            bug "Failed to set up dependencies. ${FAILURE}"
        fi
    else
        bug "Dependencies setup script not found at $dependencies_script."
    fi
}

# --- // PERFORM_BACKUP:
perform_backup() {
    local backup_script="Git/scripts/backup_new.sh"

    if [ -f "$backup_script" ]; then
        prominent "Performing backup..."
        bash "$backup_script"
        if [ $? -eq 0 ]; then
            prominent "Backup completed successfully. ${SUCCESS}"
        else
            bug "Backup failed. ${FAILURE}"
        fi
    else
        bug "Backup script not found at $backup_script."
    fi
}

# --- // MAIN_LOGIC_LOOP:
gui() {
  while true; do
    clear
    echo -e "${GREEN}#${NC} --- ${GREEN}//${NC} Git User Interface ${GREEN}//${NC}"
    echo ""
    echo -e "${GREEN}1${NC}) Check and generate SSH key\t${GREEN}14${NC}) Cherry-pick commits"
    echo -e "${GREEN}2${NC}) List current remotes\t\t${GREEN}15${NC}) Restore Branch from Commit History"
    echo -e "${GREEN}3${NC}) Update remote URL\t\t${GREEN}16${NC}) Revert to previous version"
    echo -e "${GREEN}4${NC}) Switch from HTTPS to SSH\t${GREEN}17${NC}) View Commit History"
    echo -e "${GREEN}5${NC}) Fetch from remote\t\t${GREEN}18${NC}) Rebase Branch"
    echo -e "${GREEN}6${NC}) Pull from remote\t\t${GREEN}19${NC}) Resolve Merge Conflicts"
    echo -e "${GREEN}7${NC}) Push to remote\t\t${GREEN}20${NC}) Perform Backup"
    echo -e "${GREEN}8${NC}) List branches\t\t${GREEN}21${NC}) Fix Git Repository"
    echo -e "${GREEN}9${NC}) Switch branch\t\t${GREEN}22${NC}) Setup Git Hooks"
    echo -e "${GREEN}10${NC}) Create new branch\t\t${GREEN}23${NC}) Run Integration Tests"
    echo -e "${GREEN}11${NC}) Delete branch\t\t${GREEN}24${NC}) Resolve Git Conflicts Automatically"         
    echo -e "${GREEN}12${NC}) Reconnect old repo\t\t${GREEN}25${NC}) Setup Cron Job"
    echo -e "${GREEN}13${NC}) Manage stashes\t\t${GREEN}26${NC}) Setup Dependencies" 
    echo -e "${GREEN}e${NC}) Exit"    
    echo ""
    echo -e "${GREEN}By your command:${NC}"
    read -rp " " choice  # Corrected line to capture the user's choice

    case "$choice" in
      1) check_and_setup_ssh ;;
      2) list_and_manage_remotes ;;
      3) update_remote_url ;;
      4) switch_to_ssh ;;
      5) fetch_from_remote ;;
      6) pull_from_remote ;;
      7) push_to_remote ;;
      8) list_branches ;;
      9) switch_branch ;;
      10) create_new_branch ;;
      11) delete_branch ;;
      12) reconnect_old_repo ;;
      13) manage_stashes ;;
      14) cherry_pick_commits ;;
      15) restore_branch ;;
      16) revert_version ;;
      17) view_commit_history ;;
      18) rebase_branch ;;
      19) resolve_merge_conflicts ;;
      20) perform_backup ;;
      21) fix_git_repository ;;
      22) setup_git_hooks ;;
      23) run_integration_tests ;;
      24) resolve_git_conflicts_automatically ;;
      25) setup_cron_job ;;
      26) setup_dependencies ;;
       e) echo "Exiting..."; exit 0 ;;  # Changed 'return' to 'exit' for script termination
      *) bug "Invalid choice!";;
    esac
  done
}

gui
