#!/bin/bash

# File: gui.sh
# Author: 4ndr0666
# Edited: 4-11-2024
#
# --- // GUI.SH // ========

# --- // COLORS_AND_SYMBOLS:
GREEN='\033[0;32m'
BOLD='\033[1m'
RED='\033[0;31m'
NC='\033[0m' # No Color
SUCCESS="✔️"
FAILURE="❌"
INFO="➡️"
EXPLOSION="💥"

# Utility functions for prominent and bug messages
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
        read -rp "Enter the name of the remote to remove (leave blank to cancel): " remote_to_remove
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
    remote_name=$(git remote | fzf --height=10 --prompt="Select a remote: ")
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
    new_url="git@github.com:$user_repo.git"

    git remote set-url "$remote_name" "$new_url"
    prominent "Switched '$remote_name' to use SSH: $new_url"
}

# --- // UPDATE_REMOTE_URL:
update_remote_url() {
    local repo_base="https://www.github.com/4ndr0666/"
    local repos repo_name new_url
    repos=$(gh repo list 4ndr0666 -L 100 --json name -q '.[].name')

    echo "Enter the repository name:"
    repo_name=$(echo "$repos" | fzf --height=10 --prompt="Select a repository: ")

    new_url="${repo_base}${repo_name}.git"
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
    read -rp "Enter branch name to switch to: " branch_name

    if git branch --list "$branch_name" > /dev/null; then
        git checkout "$branch_name"
        prominent "Switched to branch '$branch_name'."
    else
        bug "Branch '$branch_name' does not exist."
    fi
}

# --- // CREATE_BRANCH:
create_new_branch() {
    read -rp "Enter new branch name: " new_branch
    git checkout -b "$new_branch"
    prominent "Branch '$new_branch' created and checked out."
}

# --- // DELETE_BRANCH:
delete_branch() {
    read -rp "Enter branch name to delete: " del_branch
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
        URL)
            read -rp "Enter the remote URL: " reconnect_url
            git remote add origin "$reconnect_url"
            ;;
        Name)
            read -rp "Enter the remote name: " reconnect_name
            git remote add origin "git@github.com:$reconnect_name.git"
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
            git stash push -m "$message"
            prominent "Changes stashed. ${SUCCESS}"
            ;;
        2)
            echo "Stash list:"
            git stash list
            ;;
        3)
            git stash apply
            prominent "Stash applied. ${SUCCESS}"
            ;;
        4)
            git stash pop
            prominent "Stash popped and removed. ${SUCCESS}"
            ;;
        5)
            git stash clear
            prominent "All stashes cleared. ${SUCCESS}"
            ;;
        6)
            read -rp "Enter stash @{number} to show contents (e.g., stash@{0}): " stash_number
            git stash show -p "$stash_number"
            ;;
        7)
            read -rp "Enter stash @{number} to apply (e.g., stash@{0}): " stash_number
            git stash apply "$stash_number"
            prominent "Specific stash applied. ${SUCCESS}"
            ;;
        8)
            read -rp "Enter stash @{number} to drop (e.g., stash@{0}): " stash_number
            git stash drop "$stash_number"
            prominent "Specific stash dropped. ${SUCCESS}"
            ;;
        *)
            bug "Invalid choice! ${FAILURE}"
            ;;
    esac
}

# --- // HISTORY:
merge_branches() {
    read -rp "Enter the name of the branch you want to merge into the current branch: " branch_to_merge

    if git branch --list "$branch_to_merge" > /dev/null; then
        git merge "$branch_to_merge"
        prominent "Branch '$branch_to_merge' merged into $(git branch --show-current)."
    else
        bug "Branch '$branch_to_merge' does not exist."
    fi
}

# Function to view Git commit history
view_commit_history() {
    prominent "Showing commit history for the current branch:"
    git log --oneline --graph
}

# --- // REBASE:
rebase_branch() {
    read -rp "Enter the branch you want to rebase onto: " base_branch

    if git branch --list "$base_branch" > /dev/null; then
        git rebase "$base_branch"
        prominent "Current branch rebased onto '$base_branch'."
    else
        bug "Branch '$base_branch' does not exist."
    fi
}

# --- // QUICK_FIX:
resolve_merge_conflicts() {
    echo "Attempting to start a merge..."
    git merge

    if git ls-files -u | grep -q "^"; then
        prominent "There are merge conflicts. Manually resolve them and then run 'git merge --continue'."
    else
        prominent "No merge conflicts detected."
    fi
}

# -- // CHERRY_PICK:
cherry_pick_commits() {
    read -rp "Enter the commit hash you want to cherry-pick: " commit_hash

    git cherry-pick "$commit_hash"
    prominent "Commit '$commit_hash' cherry-picked onto $(git branch --show-current)."
}

# --- // RESTORE_BRANCH:
restore_branch() {
    echo "Retrieving commit history..."
    git log --oneline | nl -w3 -s': '
    read -rp "Enter the commit number to restore: " commit_number
    commit_hash=$(git log --oneline | sed "${commit_number}q;d" | awk '{print $1}')

    if [ -z "$commit_hash" ]; then
        bug "Invalid commit number."
        return
    fi

    branch_name="restore-$(date +%Y%m%d%H%M%S)"
    git checkout -b "$branch_name" "$commit_hash"
    prominent "New branch '$branch_name' created at commit $commit_hash."

    read -rp "Do you want to merge changes into your main branch and push to remote? (y/n): " merge_choice

    if [[ $merge_choice =~ ^[Yy]$ ]]; then
        read -rp "Enter the name of your main branch (e.g., 'main' or 'master'): " main_branch

        git checkout "$main_branch"
        git merge "$branch_name"
        git push origin "$main_branch"

        prominent "Changes merged into $main_branch and pushed to remote repository."
    else
        echo "Skipping merge and push to remote repository."
    fi
}

# --- // REVERT:
revert_version() {
    echo "Recent actions in the repository:"
    git reflog -10

    read -rp "Enter the reflog entry number you want to revert to (e.g., HEAD@{2}): " reflog_entry

    read -rp "Do you want to revert to this point? This action is irreversible. (yes/no): " confirmation

    if [[ "$confirmation" == "yes" ]]; then
        if git reset --hard "$reflog_entry"; then
            prominent "Reverted to $reflog_entry."
        else
            bug "Failed to revert. Make sure the reflog entry number is correct."
            return 1
        fi
    else
        prominent "Revert action canceled."
        return 0
    fi
}

# --- // MAIN_LOGIC_LOOP:
gui() {
  while true; do
    clear
    echo -e "==================================================================="
    echo -e "    ================= ${GREEN}// Git Management Menu //${NC} ================="
    echo -e "==================================================================="
    echo -e "${GREEN}1${NC}) Check and generate SSH key\t\t${GREEN}11${NC}) Delete branch"
    echo -e "${GREEN}2${NC}) List current remotes\t\t\t${GREEN}12${NC}) Reconnect old repo"
    echo -e "${GREEN}3${NC}) Update remote URL\t\t\t${GREEN}13${NC}) Manage stashes"
    echo -e "${GREEN}4${NC}) Switch from HTTPS to SSH\t\t${GREEN}14${NC}) Cherry-pick commits"
    echo -e "${GREEN}5${NC}) Fetch from remote\t\t\t${GREEN}15${NC}) Restore Branch from Commit History"
    echo -e "${GREEN}6${NC}) Pull from remote\t\t\t${GREEN}16${NC}) Revert to previous version"
    echo -e "${GREEN}7${NC}) Push to remote\t\t\t${GREEN}17${NC}) View Commit History"
    echo -e "${GREEN}8${NC}) List branches\t\t\t${GREEN}18${NC}) Rebase Branch"
    echo -e "${GREEN}9${NC}) Switch branch\t\t\t${GREEN}19${NC}) Resolve Merge Conflicts"
    echo -e "${GREEN}10${NC}) Create new branch\t\t\t${GREEN}20${NC}) Exit"
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
      20) echo "Exiting..."; return ;;  # Corrected exit to return
      *) bug "Invalid choice!";;
    esac
  done
}

gui
