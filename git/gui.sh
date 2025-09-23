#!/bin/bash
# shellcheck disable=SC2155,SC2034
# File: gui.sh
# Author: 4ndr0666
# Revised: Ψ-Anarch
# Date: 12-16-2024

# --- // Script Configuration & Safety
# Exit immediately if a command exits with a non-zero status.
# Treat unset variables as an error when substituting.
# Exit with a non-zero status if any command in a pipeline fails.
set -euo pipefail

# ============================== // GUI.SH // ==============================

# --- // Constants: Colors & Symbols
# Use readonly to prevent accidental modification of these global constants.
readonly GREEN='\033[0;32m'
readonly BOLD='\033[1m'
readonly RED='\033[0;31m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

readonly SUCCESS="✔️"
readonly FAILURE="❌"
readonly INFO="➡️"
readonly EXPLOSION="💥"

# --- // UI & HELPER FUNCTIONS:
# Centralized functions for consistent output and user interaction.

prominent() {
    printf "${BOLD}${GREEN}%s${NC}\n" "$1"
}

bug() {
    printf "${BOLD}${RED}%s${NC}\n" "$1" >&2
}

info() {
    printf "${CYAN}%s${NC}\n" "$1"
}

pause() {
    # Use -n 1 and -s to read a single character without showing it.
    read -n 1 -s -r -p "Press any key to continue..."
    echo
}

# A robust confirmation prompt.
ask_confirmation() {
    local prompt_message="$1"
    local response
    while true; do
        read -rp "$prompt_message (y/n): " response
        case "$response" in
            [yY] | [yY][eE][sS]) return 0 ;;
            [nN] | [nN][oO]) return 1 ;;
            *) bug "Invalid input. Please enter 'y' or 'n'." ;;
        esac
    done
}

# --- // PRE-FLIGHT CHECKS:

check_dependencies() {
    local missing_deps=()
    # notify-send is optional, so not checked here.
    local deps=("git" "fzf" "gh" "shellcheck" "shfmt")
    prominent "Checking for required dependencies..."
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        bug "Error: The following dependencies are missing:"
        for dep in "${missing_deps[@]}"; do
            printf "${RED}- %s${NC}\n" "$dep"
        done
        bug "Please install them and try again."
        exit 1
    else
        prominent "All dependencies are installed. ${SUCCESS}"
    fi
}

# --- // DYNAMIC CONFIGURATION:
# Functions to fetch user-specific data, avoiding hardcoded values.

get_gh_user() {
    # Cache the username to avoid repeated API calls.
    if [ -z "${GH_USER:-}" ]; then
        # Use a temporary variable to handle potential command failure.
        local user_name
        user_name=$(gh api user --jq .login) || { bug "Failed to get GitHub username. Is 'gh' authenticated?"; return 1; }
        export GH_USER="$user_name"
    fi
    echo "$GH_USER"
}

get_git_email() {
    git config user.email
}

# --- // CORE GIT & GITHUB FUNCTIONS:

ensure_gh_repo_exists() {
    local full_repo_name="$1"
    info "Verifying repository '$full_repo_name' on GitHub..."
    if ! gh repo view "$full_repo_name" >/dev/null 2>&1; then
        if ask_confirmation "Repository '$full_repo_name' does not exist. Create it now?"; then
            # Create a private repo by default.
            if gh repo create "$full_repo_name" --private --confirm; then
                prominent "Repository '$full_repo_name' created successfully. ${SUCCESS}"
                return 0
            else
                bug "Failed to create repository '$full_repo_name'. ${FAILURE}"
                return 1
            fi
        else
            bug "Repository creation skipped. Aborting."
            return 1
        fi
    fi
    info "Repository '$full_repo_name' exists."
    return 0
}

check_and_setup_ssh() {
    local ssh_key="${HOME}/.ssh/id_ed25519"

    if [ -f "$ssh_key" ]; then
        prominent "SSH key already exists at '$ssh_key'. ${SUCCESS}"
    else
        prominent "SSH key not found. Creating one now..."
        # Dynamically get email from git config.
        local email=$(get_git_email)
        if [ -z "$email" ]; then
            bug "Git user email is not set. Please configure it first:"
            info "git config --global user.email \"your_email@example.com\""
            return 1
        fi
        ssh-keygen -t ed25519 -C "$email" -f "$ssh_key" -N ""
        eval "$(ssh-agent -s)"
        ssh-add "$ssh_key"
        info "SSH key created and added to the ssh-agent."

        info "Attempting to automatically upload the SSH key to GitHub..."
        # Use a more descriptive title for the key on GitHub.
        local title="GitUI-$(hostname)"
        if gh ssh-key add "$ssh_key.pub" --title "$title"; then
            prominent "SSH key successfully uploaded to GitHub. ${SUCCESS}"
        else
            bug "Failed to upload SSH key to GitHub. Please do it manually. ${FAILURE}"
        fi
    fi
}

list_and_manage_remotes() {
    prominent "Current Git remotes:"
    git remote -v
    if ! ask_confirmation "Would you like to remove any remotes?"; then
        info "No changes made to remotes."
        return 0
    fi

    local remotes=$(git remote)
    if [ -z "$remotes" ]; then
        info "No remotes to remove."
        return
    fi
    local remote_to_remove
    remote_to_remove=$(echo "$remotes" | fzf --height=40% --prompt="Select a remote to remove: ")
    if [ -n "$remote_to_remove" ]; then
        git remote remove "$remote_to_remove"
        prominent "Remote '$remote_to_remove' has been removed. ${SUCCESS}"
    else
        info "No remotes removed."
    fi
}

switch_to_ssh() {
    local remote_name
    remote_name=$(git remote | fzf --height=40% --prompt="Select a remote to switch to SSH: ")

    if [ -z "$remote_name" ]; then
        bug "No remote selected."
        return 1
    fi

    local old_url
    old_url=$(git remote get-url "$remote_name")

    if [[ "$old_url" == git@* ]]; then
        info "The remote '$remote_name' is already using SSH."
        return
    fi

    # Extract repo path from HTTPS URL.
    local repo_path
    repo_path=$(echo "$old_url" | sed -E 's#^https://github.com/([^/]+/[^/]+).*#\1#')
    local new_url="git@github.com:${repo_path}.git"

    if ! ensure_gh_repo_exists "$repo_path"; then
        return 1
    fi

    git remote set-url "$remote_name" "$new_url"
    prominent "Switched '$remote_name' to use SSH: $new_url ${SUCCESS}"
}

update_remote_url() {
    local user_name=$(get_gh_user)
    local repos
    repos=$(gh repo list "$user_name" --limit 100 --json name --jq '.[].name')

    if [ -z "$repos" ]; then
        bug "No repositories found for user '$user_name'."
        return 1
    fi

    prominent "Select the repository you want to set as origin:"
    local repo_name
    repo_name=$(echo "$repos" | fzf --height=40% --prompt="Select repository: ")

    if [ -z "$repo_name" ]; then
        bug "No repository selected. Aborting update."
        return 1
    fi

    local full_repo_name="${user_name}/${repo_name}"
    if ! ensure_gh_repo_exists "$full_repo_name"; then
        return 1
    fi

    local new_url="https://github.com/${full_repo_name}.git"
    git remote set-url origin "$new_url"
    prominent "Remote 'origin' URL updated to $new_url ${SUCCESS}"
}

fetch_from_remote() {
    prominent "Fetching updates from all remotes..."
    git fetch --all --prune
    prominent "Fetch complete. ${SUCCESS}"
}

pull_from_remote() {
    local current_branch
    current_branch=$(git branch --show-current)
    prominent "Pulling updates from remote for branch '$current_branch'..."
    git pull origin "$current_branch"
    prominent "Pull complete. ${SUCCESS}"
}

push_to_remote() {
    local current_branch
    current_branch=$(git branch --show-current)

    # Check for uncommitted changes.
    if ! git diff-index --quiet HEAD --; then
        info "Uncommitted changes detected."
        git status --short
        read -rp "Enter commit message to stage and commit all changes (or leave blank to cancel): " commit_message
        if [ -n "$commit_message" ]; then
            git add -A
            git commit -m "$commit_message"
            prominent "Changes committed with message: '$commit_message'"
        else
            bug "Push canceled due to uncommitted changes."
            return 1
        fi
    fi

    prominent "Pushing local branch '$current_branch' to remote..."
    git push -u origin "$current_branch"
    prominent "Push complete. ${SUCCESS}"
}

list_branches() {
    prominent "Available branches (local and remote):"
    git branch -a | less -R
}

switch_branch() {
    prominent "Select the branch you want to switch to:"
    local branches
    branches=$(git branch --format='%(refname:short)')
    local branch_name
    branch_name=$(echo "$branches" | fzf --height=40% --prompt="Select branch: ")

    if [ -z "$branch_name" ]; then
        bug "No branch selected. Aborting switch."
        return 1
    fi

    if git checkout "$branch_name"; then
        prominent "Switched to branch '$branch_name'. ${SUCCESS}"
    else
        bug "Failed to switch to branch '$branch_name'. ${FAILURE}"
    fi
}

create_new_branch() {
    read -rp "Enter new branch name: " new_branch

    if [ -z "$new_branch" ]; then
        bug "No branch name provided. Aborting creation."
        return 1
    fi

    if git checkout -b "$new_branch"; then
        prominent "Branch '$new_branch' created and checked out. ${SUCCESS}"
    else
        bug "Failed to create branch '$new_branch'. It may already exist. ${FAILURE}"
    fi
}

delete_branch() {
    prominent "Select the branch you want to delete:"
    local branches
    branches=$(git branch --format='%(refname:short)')
    local del_branch
    del_branch=$(echo "$branches" | fzf --height=40% --prompt="Select branch to delete: ")

    if [ -z "$del_branch" ]; then
        bug "No branch selected. Aborting deletion."
        return 1
    fi

    if ask_confirmation "Are you sure you want to delete branch '$del_branch'?"; then
        if git branch -d "$del_branch"; then
            prominent "Branch '$del_branch' deleted. ${SUCCESS}"
        else
            bug "Failed to delete branch '$del_branch'. It might have unmerged changes. Use -D to force. ${FAILURE}"
        fi
    else
        info "Delete branch action canceled."
    fi
}

reconnect_old_repo() {
    read -rp "Do you know the remote URL or just the repository Name? (URL/Name): " reconnect_type
    local user_name=$(get_gh_user)
    case "$reconnect_type" in
        [uU][rR][lL])
            read -rp "Enter the remote URL: " reconnect_url
            local repo_name
            repo_name=$(basename "$reconnect_url" .git)
            local full_repo_name="${user_name}/${repo_name}"
            
            if ! ensure_gh_repo_exists "$full_repo_name"; then
                return 1
            fi
            git remote add origin "$reconnect_url"
            prominent "Remote 'origin' added with URL '$reconnect_url'. ${SUCCESS}"
            ;;
        [nN][aA][mM][eE])
            read -rp "Enter the repository name (e.g., 'my-repo'): " reconnect_name
            local full_repo_name="${user_name}/${reconnect_name}"
            local new_url="git@github.com:${full_repo_name}.git"

            if ! ensure_gh_repo_exists "$full_repo_name"; then
                return 1
            fi
            git remote add origin "$new_url"
            prominent "Remote 'origin' added with SSH URL '$new_url'. ${SUCCESS}"
            ;;
        *)
            bug "Invalid option. Exiting..."
            return 1
            ;;
    esac
}

manage_stashes() {
    local options="1. Stash Changes\n2. List Stashes\n3. Apply Latest Stash\n4. Pop Latest Stash\n5. Clear All Stashes\n6. Show Stash Contents\n7. Apply Specific Stash\n8. Drop Specific Stash"
    local choice
    choice=$(printf "%b" "$options" | fzf --height=40% --prompt="Manage Stashes: " | cut -d'.' -f1)

    case "$choice" in
        1)
            read -rp "Enter a message for the stash (optional): " message
            if git stash push -m "$message"; then prominent "Changes stashed. ${SUCCESS}"; else bug "Failed to stash changes. ${FAILURE}"; fi
            ;;
        2)
            prominent "Stash list:"
            git stash list
            ;;
        3)
            if git stash apply; then prominent "Latest stash applied. ${SUCCESS}"; else bug "Failed to apply latest stash. ${FAILURE}"; fi
            ;;
        4)
            if git stash pop; then prominent "Latest stash popped. ${SUCCESS}"; else bug "Failed to pop latest stash. ${FAILURE}"; fi
            ;;
        5)
            if ask_confirmation "Are you sure you want to clear all stashes?"; then
                if git stash clear; then prominent "All stashes cleared. ${SUCCESS}"; else bug "Failed to clear stashes. ${FAILURE}"; fi
            else info "Clear stashes action canceled."; fi
            ;;
        6 | 7 | 8)
            local action_verb
            case "$choice" in
                6) action_verb="show" ;;
                7) action_verb="apply" ;;
                8) action_verb="drop" ;;
            esac
            local stash_ref
            stash_ref=$(git stash list | fzf --prompt="Select stash to $action_verb: " | awk -F: '{print $1}')
            if [ -n "$stash_ref" ]; then
                if [ "$action_verb" = "show" ]; then
                    git stash show -p "$stash_ref" | less -R
                elif git stash "$action_verb" "$stash_ref"; then
                    prominent "Stash '$stash_ref' ${action_verb}ed. ${SUCCESS}"
                else
                    bug "Failed to $action_verb stash '$stash_ref'. ${FAILURE}"
                fi
            else bug "No stash selected."; fi
            ;;
        *)
            bug "Invalid choice! ${FAILURE}"
            ;;
    esac
}

cherry_pick_commits() {
    prominent "Fetching latest commits..."
    git fetch --all

    local commit_hash
    commit_hash=$(git log --all --graph --pretty=format:'%C(yellow)%h%C(reset) -%C(red)%d%C(reset) %s %C(green)(%cr) %C(bold blue)<%an>%C(reset)' |
        fzf --ansi --no-sort --reverse --tiebreak=index --bind=ctrl-d:half-page-down,ctrl-u:half-page-up --height=50% --prompt="Select a commit to cherry-pick: " |
        cut -d' ' -f1)

    if [ -z "$commit_hash" ]; then
        bug "No commit selected. Aborting cherry-pick."
        return 1
    fi

    if git cherry-pick "$commit_hash"; then
        prominent "Commit $commit_hash cherry-picked successfully. ${SUCCESS}"
    else
        bug "Cherry-pick failed. Please resolve conflicts manually. ${FAILURE}"
    fi
}

restore_branch() {
    prominent "Retrieving commit history..."
    local commit_hash
    commit_hash=$(git log --all --graph --pretty=format:'%C(yellow)%h%C(reset) -%C(red)%d%C(reset) %s %C(green)(%cr) %C(bold blue)<%an>%C(reset)' |
        fzf --ansi --no-sort --reverse --tiebreak=index --height=50% --prompt="Select a commit to restore: " |
        cut -d' ' -f1)

    if [ -z "$commit_hash" ]; then
        bug "No commit selected. Aborting restore."
        return 1
    fi

    local branch_name="restore-$(date +%Y%m%d%H%M%S)"
    if git checkout -b "$branch_name" "$commit_hash"; then
        prominent "New branch '$branch_name' created from commit $commit_hash. ${SUCCESS}"
    else
        bug "Failed to create branch from commit. ${FAILURE}"
    fi
}

revert_version() {
    prominent "Recent actions in the repository (reflog):"
    git reflog -10

    local reflog_entry
    reflog_entry=$(git reflog --pretty=format:'%h %gs' | fzf --height=40% --prompt="Select a reflog entry to revert to: " | cut -d' ' -f1)

    if [ -z "$reflog_entry" ]; then
        bug "No reflog entry selected. Aborting revert."
        return 1
    fi

    if ask_confirmation "HARD RESET to $reflog_entry? This is destructive and can lose work."; then
        if git reset --hard "$reflog_entry"; then
            prominent "Hard reset to $reflog_entry successful. ${SUCCESS}"
        else
            bug "Failed to revert. ${FAILURE}"
        fi
    else
        info "Revert action canceled."
    fi
}

view_commit_history() {
    prominent "Showing commit history for all branches:"
    git log --oneline --graph --decorate --all | less -R
}

rebase_branch() {
    prominent "Select the base branch to rebase onto:"
    local base_branch
    base_branch=$(git branch --format='%(refname:short)' | fzf --height=40% --prompt="Select base branch: ")

    if [ -z "$base_branch" ]; then
        bug "No base branch selected. Aborting rebase."
        return 1
    fi
    
    if git rebase "$base_branch"; then
        prominent "Current branch rebased onto '$base_branch' successfully. ${SUCCESS}"
    else
        bug "Rebase failed. Please resolve conflicts manually. You can abort with 'git rebase --abort'. ${FAILURE}"
    fi
}

resolve_merge_conflicts() {
    prominent "Select the branch to merge into the current branch:"
    local target_branch
    target_branch=$(git branch --format='%(refname:short)' | fzf --height=40% --prompt="Select branch to merge: ")

    if [ -z "$target_branch" ]; then
        bug "No target branch selected. Aborting merge."
        return 1
    fi

    if git merge "$target_branch"; then
        prominent "Branch '$target_branch' merged successfully. ${SUCCESS}"
    else
        bug "Merge resulted in conflicts. ${FAILURE}"
        info "Please resolve conflicts manually, then 'git add <files>' and 'git merge --continue'."
        if ask_confirmation "Would you like to run the automated conflict resolver script?"; then
            resolve_git_conflicts_automatically
        fi
    fi
}

fix_git_repository() {
    prominent "Starting Git Repository Fix Process..."

    if ! ask_confirmation "This process can be destructive. It is highly recommended to have a remote backup. Continue?"; then
        info "Fix process aborted by user."
        return
    fi

    local backup_dir="../git_repo_backup_$(date +%Y%m%d_%H%M%S)"
    info "Backing up current repository to $backup_dir"
    if cp -r . "$backup_dir"; then
        prominent "Local backup completed successfully."
    else
        bug "Local backup failed. Aborting."
        return 1
    fi

    info "Running 'git fsck --full' to identify issues..."
    git fsck --full

    info "Expiring reflog entries..."
    git reflog expire --expire=now --all

    info "Running garbage collection 'git gc --prune=now --aggressive'..."
    if git gc --prune=now --aggressive; then
        prominent "'git gc' executed successfully."
    else
        bug "Error: 'git gc' failed."
    fi

    info "Verifying repository integrity again with 'git fsck --full'..."
    if git fsck --full; then
        prominent "Repository integrity verified successfully. ${SUCCESS}"
    else
        bug "Error: Repository integrity check failed. Consider restoring from backup. ${FAILURE}"
    fi
    prominent "Git repository fix process completed."
}

setup_git_hooks() {
    prominent "Setting up Git hooks..."
    local GIT_HOOKS_DIR=".git/hooks"
    mkdir -p "$GIT_HOOKS_DIR"

    install_hook() {
        local hook_name="$1"
        local hook_path="$GIT_HOOKS_DIR/$hook_name"

        if [ -f "$hook_path" ] && ! [[ "$hook_path" == *".sample" ]]; then
            info "Backing up existing '$hook_name' hook."
            mv "$hook_path" "${hook_path}.backup.$(date +%s)"
        fi
        # Use a heredoc for readability of the hook content.
        cat > "$hook_path"
        chmod +x "$hook_path"
        prominent "Installed/Updated hook: $hook_name"
    }

    install_hook "commit-msg" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
COMMIT_MSG_FILE="$1"
SUBJECT_LINE=$(head -n 1 "$COMMIT_MSG_FILE")
if [ ${#SUBJECT_LINE} -gt 72 ]; then
    echo "Error: Subject line exceeds 72 characters." >&2
    exit 1
fi
exit 0
EOF

    install_hook "pre-commit" <<'EOF'
#!/bin/bash
set -euo pipefail
# Find staged .sh files to format and lint.
scripts=$(git diff --cached --name-only --diff-filter=ACM | grep -E "\.sh$")
if [ -z "$scripts" ]; then
    exit 0
fi
echo "Running shfmt and shellcheck on staged scripts..."
PASS=true
for script in $scripts; do
    shfmt -w "$script"
    git add "$script" # Re-add the formatted file
    if ! shellcheck "$script"; then
        PASS=false
    fi
done
if ! $PASS; then
    echo "Error: shellcheck found issues. Please fix them before committing." >&2
    exit 1
fi
echo "All staged scripts passed checks."
exit 0
EOF

    install_hook "pre-push" <<'EOF'
#!/bin/sh
set -euo pipefail
INTEGRATION_TESTS_SCRIPT="Git/scripts/integration_tests.sh"
if [ -f "$INTEGRATION_TESTS_SCRIPT" ]; then
    echo "Running integration tests before push..."
    bash "$INTEGRATION_TESTS_SCRIPT" || exit 1
fi
exit 0
EOF

    install_hook "post-commit" <<'EOF'
#!/bin/sh
if command -v notify-send &>/dev/null; then
    COMMIT_MESSAGE=$(git log -1 --pretty=%B | head -n 1)
    notify-send "Git" "Commit successful: $COMMIT_MESSAGE"
fi
exit 0
EOF

    prominent "Git hooks have been set up successfully. ${SUCCESS}"
}

# --- // SCRIPT-BASED ACTIONS (WRAPPERS):
# These functions call external helper scripts.

run_script_if_exists() {
    local script_path="$1"
    local success_msg="$2"
    local failure_msg="$3"
    local not_found_msg="$4"

    if [ -f "$script_path" ]; then
        prominent "Executing $script_path..."
        if bash "$script_path"; then
            prominent "$success_msg ${SUCCESS}"
        else
            bug "$failure_msg ${FAILURE}"
        fi
    else
        bug "$not_found_msg"
    fi
}

run_integration_tests() {
    run_script_if_exists "Git/scripts/integration_tests.sh" "Integration tests passed." "Integration tests failed." "Integration tests script not found."
}

resolve_git_conflicts_automatically() {
    run_script_if_exists "Git/scripts/automated_git_conflict_resolver.sh" "Automated conflict resolution completed." "Automated conflict resolution failed." "Automated conflict resolver script not found."
}

setup_cron_job() {
    run_script_if_exists "Git/scripts/setup_cron_job.sh" "Cron job set up successfully." "Failed to set up cron job." "Cron job setup script not found."
}

setup_dependencies() {
    run_script_if_exists "Git/scripts/setup_dependencies.sh" "Dependencies set up successfully." "Failed to set up dependencies." "Dependencies setup script not found."
}

perform_backup() {
    run_script_if_exists "Git/scripts/backup_new.sh" "Backup completed successfully." "Backup failed." "Backup script not found."
}

# --- // MAIN LOGIC LOOP:
gui() {
  while true; do
    clear
    # Redesigned menu using printf for perfect alignment.
    local menu_format="  ${GREEN}%-2s)${NC} %-30s ${GREEN}%-3s)${NC} %s\n"
    local heading_format="\n  ${BOLD}${GREEN}%-34s %-34s${NC}\n"
    
    prominent "# --- // Git User Interface //"
    
    printf "$heading_format" "REMOTE OPERATIONS" "HISTORY & RECOVERY"
    printf "$menu_format" "1" "Check & Setup SSH key" "14" "Cherry-pick Commits"
    printf "$menu_format" "2" "List & Manage Remotes" "15" "Restore Branch from Commit"
    printf "$menu_format" "3" "Update Remote URL (HTTPS)" "16" "Revert Version (Reflog)"
    printf "$menu_format" "4" "Switch Remote to SSH" "17" "View Commit History"
    printf "$menu_format" "5" "Fetch from Remote" "" ""
    printf "$menu_format" "6" "Pull from Remote" "" ""
    printf "$menu_format" "7" "Push to Remote" "" ""
    printf "$menu_format" "12" "Reconnect Old Repo" "" ""
    
    printf "$heading_format" "BRANCHING & STASHING" "MAINTENANCE & SCRIPTS"
    printf "$menu_format" "8" "List Branches" "20" "Perform Backup"
    printf "$menu_format" "9" "Switch Branch" "21" "Fix Git Repository"
    printf "$menu_format" "10" "Create New Branch" "22" "Setup Git Hooks"
    printf "$menu_format" "11" "Delete Branch" "23" "Run Integration Tests"
    printf "$menu_format" "13" "Manage Stashes" "24" "Resolve Conflicts Automatically"
    printf "$menu_format" "18" "Rebase Branch" "25" "Setup Cron Job"
    printf "$menu_format" "19" "Merge Branch" "26" "Setup Dependencies"

    printf "\n  ${GREEN}e/q)${NC} Exit\n"
    printf "\n${GREEN}By your command:${NC}\n"
    read -rp "❯ " choice

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
      e|q) info "Exiting..."; exit 0 ;;
      *) bug "Invalid choice!" ;;
    esac || true # This prevents 'set -e' from exiting the script if a function fails.
    
    pause
  done
}

# --- // SCRIPT ENTRYPOINT
main() {
    check_dependencies
    gui
}

# Execute the main function.
main
