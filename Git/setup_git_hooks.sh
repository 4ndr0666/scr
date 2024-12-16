#!/usr/bin/env bash
set -euo pipefail

# Script: setup_git_hooks.sh
# Description: Automates the installation and enhancement of Git hooks.
# Usage: ./setup_git_hooks.sh

# Define the hooks directory
GIT_HOOKS_DIR=".git/hooks"

# Ensure the hooks directory exists
if [ ! -d "$GIT_HOOKS_DIR" ]; then
    echo "Error: .git/hooks directory not found. Ensure this script is run in the root of a Git repository."
    exit 1
fi

# Log file
HOOKS_LOG="$GIT_HOOKS_DIR/hooks_setup.log"
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
INTEGRATION_TESTS_SCRIPT="scripts/integration_tests.sh"

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
if [ -f "$GIT_HOOKS_DIR/commit-msg" ] && [[ "$GIT_HOOKS_DIR/commit-msg" != *".sample" ]]; then
    echo "commit-msg hook already exists. Skipping installation." | tee -a "$HOOKS_LOG"
else
    install_hook "commit-msg" "$COMMIT_MSG_HOOK"
fi

# Install or update pre-commit hook
install_hook "pre-commit" "$PRE_COMMIT_HOOK"

# Install or update pre-push hook
install_hook "pre-push" "$PRE_PUSH_HOOK"

# Install or update post-commit hook
install_hook "post-commit" "$POST_COMMIT_HOOK"

# Summary
echo "Git hooks setup completed successfully." | tee -a "$HOOKS_LOG"
echo "All Git hooks have been installed and enhanced." | tee -a "$HOOKS_LOG"

exit 0
