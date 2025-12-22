#!/bin/bash
# shellcheck disable=SC2155,SC2034
# Rev: 4
# Author: 4ndr0666, Ψ-Anarch, HIC-7
set -euo pipefail
# ============================== // GUI.SH //
# Description: A strategic command console for Git operations.
#
# -------------------------------------------

# Constants: Colors & Symbols
readonly GREEN='\033[0;32m'; readonly BOLD='\033[1m'; readonly RED='\033[0;31m'
readonly CYAN='\033[0;36m'; readonly NC='\033[0m'
readonly SUCCESS="✔️"; readonly FAILURE="❌"; readonly INFO="➡️"

# UI & HELPER FUNCTIONS:
prominent() { printf "${BOLD}${GREEN}%s${NC}\n" "$1"; }
bug() { printf "${BOLD}${RED}%s${NC}\n" "$1" >&2; }
info() { printf "${CYAN}%s${NC}\n" "$1"; }
pause() { read -n 1 -s -r -p "Press any key to continue..."; echo; }

ask_confirmation() {
    local prompt_message="$1"; local response
    while true; do
        read -rp "$prompt_message (y/n): " response
        case "$response" in [yY]|[yY][eE][sS]) return 0;; [nN]|[nN][oO]) return 1;; *) bug "Invalid input.";; esac
    done
}

# --- // PRE-FLIGHT CHECKS:
check_dependencies() {
    local missing_deps=(); local deps=("git" "fzf" "gh" "shellcheck" "shfmt" "rsync")
    prominent "Checking for required dependencies..."; for cmd in "${deps[@]}"; do if ! command -v "$cmd" &>/dev/null; then missing_deps+=("$cmd"); fi; done
    if [ ${#missing_deps[@]} -gt 0 ]; then
        bug "Error: Missing dependencies:"; for dep in "${missing_deps[@]}"; do printf "${RED}- %s${NC}\n" "$dep"; done
        bug "Please install them and try again."; exit 1
    else prominent "All dependencies are installed. ${SUCCESS}"; fi
}

# --- // DYNAMIC CONFIGURATION:
get_gh_user() { if [ -z "${GH_USER:-}" ]; then local user_name; user_name=$(gh api user --jq .login) || { bug "Failed to get GitHub username."; return 1; }; export GH_USER="$user_name"; fi; echo "$GH_USER"; }
get_git_email() { git config user.email || echo "user@example.com"; }

# --- // GUIDED WORKFLOWS
pristine_contribution_wizard() {
    prominent "Pristine Contribution Wizard"
    local main_branch="main"
    if ! git show-ref --verify --quiet refs/heads/"$main_branch"; then
        main_branch="master"
        if ! git show-ref --verify --quiet refs/heads/"$main_branch"; then
            bug "Could not determine default branch (main/master). Aborting."
            return 1
        fi
    fi
    info "Step 1: Ensuring '$main_branch' is up-to-date."
    git checkout "$main_branch" && git pull origin "$main_branch" --rebase
    read -rp "Step 2: Enter name for your new feature branch: " new_branch
    if [ -z "$new_branch" ]; then bug "Branch name cannot be empty."; return 1; fi
    git checkout -b "$new_branch"
    prominent "Switched to new branch '$new_branch'."
    info "You can now start working on your changes."
    if ask_confirmation "Push this new branch to origin to set up tracking?"; then
        git push --set-upstream origin "$new_branch"
    fi
    prominent "Wizard complete. Happy coding! ${SUCCESS}"
}

pre_flight_cleanup_assistant() {
    prominent "Pre-PR Cleanup Assistant"
    local current_branch=$(git branch --show-current)
    local target_branch="main"
    if ! git show-ref --verify --quiet refs/heads/"$target_branch"; then
        target_branch="master"
    fi
    info "This assistant helps you clean up '$current_branch' before creating a pull request against '$target_branch'."
    if ask_confirmation "Start an interactive rebase against '$target_branch' to squash/reword commits?"; then
        info "Rebasing '$current_branch' onto '$target_branch'..."
        if ! git rebase -i "$target_branch"; then
            bug "Rebase failed. Please resolve conflicts and run 'git rebase --continue' or 'git rebase --abort'."
            return 1
        fi
        info "Rebase complete."
        if ask_confirmation "Force-push the cleaned branch to update the remote? (Required after rebase)"; then
            git push --force-with-lease
            prominent "Force push complete."
        fi
    fi
    prominent "Cleanup complete. Your branch is ready for a pull request. ${SUCCESS}"
}

# --- // EMERGENCY & RECOVERY PROTOCOLS
emergency_recovery_protocol() {
    prominent "EMERGENCY RECOVERY PROTOCOL"
    info "This wizard helps you recover from a bad state (e.g., accidental deletion)."; echo
    if ! ask_confirmation "This involves 'git reset --hard' and 'git push --force'. Proceed with caution?"; then info "Recovery aborted."; return 1; fi
    local current_branch=$(git branch --show-current)
    info "Analyzing the reference log for the current branch: '$current_branch'..."
    local reflog_entry; reflog_entry=$(git reflog --pretty=format:'%h %gs' | fzf --height=50% --prompt="Select the LAST KNOWN GOOD state to restore to: ")
    if [ -z "$reflog_entry" ]; then bug "No state selected. Aborting recovery."; return 1; fi
    local good_hash=$(echo "$reflog_entry" | cut -d' ' -f1)
    local description=$(echo "$reflog_entry" | cut -d' ' -f2-)
    info "You have selected: ${good_hash} - ${description}"
    if ask_confirmation "Do you want to temporarily checkout this commit to inspect it?"; then
        git checkout "$good_hash"
        prominent "You are now in a DETACHED HEAD state at ${good_hash} for inspection."
        info "Check your files. When you are done, return here and press any key."
        pause
        git checkout "$current_branch"
        info "Returned to branch '$current_branch'."
    fi
    bug "FINAL WARNING: The next step is DESTRUCTIVE and will rewrite history."
    printf "${RED}You are about to hard-reset '${current_branch}' to '${good_hash}' and force-push.${NC}\n"
    read -rp "To confirm, type the branch name ('$current_branch'): " confirmation
    if [ "$confirmation" != "$current_branch" ]; then bug "Confirmation failed. Recovery aborted."; return 1; fi
    prominent "Executing recovery..."
    info "Step 1: Resetting local branch..."; git reset --hard "$good_hash"
    info "Step 2: Force-pushing to remote..."; git push origin "$current_branch" --force
    prominent "Recovery protocol complete. Branch '$current_branch' has been restored. ${SUCCESS}"
}

restore_single_file() {
    prominent "Restore Single Deleted File"
    info "Finding commits where files were deleted..."
    local deletion_log
    deletion_log=$(git log --diff-filter=D --summary --pretty=format:'%C(yellow)%h %C(reset)%s' | sed -n '/delete mode/p' | sed 's/ delete mode [0-9]* //')
    if [ -z "$deletion_log" ]; then bug "Could not find any file deletions in the history."; return 1; fi
    local selection
    selection=$(echo "$deletion_log" | fzf --prompt="Select the deletion event to reverse: ")
    if [ -z "$selection" ]; then info "Operation canceled."; return 1; fi
    local commit_hash=$(echo "$selection" | awk '{print $1}')
    local file_path=$(echo "$selection" | awk '{$1=""; print $0}' | xargs)
    local parent_hash="${commit_hash}^"
    info "You are about to restore '${file_path}' from the commit before it was deleted (${parent_hash})."
    if ! ask_confirmation "Proceed?"; then info "Restore canceled."; return 1; fi
    git checkout "$parent_hash" -- "$file_path"
    prominent "File '${file_path}' has been restored to your working directory. ${SUCCESS}"
    info "Please stage and commit this change."; git status --short
}

# --- // DAILY OPERATIONS
fetch_from_remote() { prominent "Fetching updates..."; git fetch --all --prune; prominent "Fetch complete."; }

pull_from_remote() {
    local current_branch=$(git branch --show-current)
    if ! git diff-index --quiet HEAD --; then
        info "Local changes detected."
        if ask_confirmation "Stash changes before pulling?"; then
            git stash push -u -m "autostash-before-pull-$(date +%s)"
            prominent "Changes stashed."
            if ! git pull --rebase; then
                bug "Pull failed. Your changes remain stashed. Please resolve the pull issues manually."
                return 1
            fi
            if ! git stash pop; then
                bug "Could not pop stashed changes. There might be a conflict. Use 'git stash apply' to inspect."
                return 1
            fi
            prominent "Pulled with rebase and restored stashed changes. ${SUCCESS}"
        else
            bug "Pull aborted due to uncommitted changes."; return 1
        fi
    else
        prominent "Pulling updates for branch '$current_branch'..."; git pull --rebase; prominent "Pull complete. ${SUCCESS}"
    fi
}

push_to_remote() {
    local current_branch=$(git branch --show-current)
    local remote_branch=$(git rev-parse --abbrev-ref "$current_branch"@{u} 2>/dev/null)
    if [ -z "$remote_branch" ]; then
        info "No upstream branch is set for '$current_branch'."
        if ask_confirmation "Push and set upstream to 'origin/$current_branch'?"; then
            git push --set-upstream origin "$current_branch"
        else
            info "Push aborted."; return 1
        fi
    else
        prominent "Pushing to '$remote_branch'..."; git push
    fi
    prominent "Push complete. ${SUCCESS}"
}

interactive_add() {
    prominent "Entering Interactive Staging"
    info "Use 's' to see status, 'u' to update, 'p' to patch, 'q' to quit."
    git add -i
    prominent "Exited interactive staging."
    git status -s
}

quick_commit_push() {
    prominent "Quick Commit & Push"
    git status -s
    if ! ask_confirmation "The above changes will be staged. Proceed?"; then
        info "Operation cancelled."
        return 1
    fi
    git add .
    read -rp "Enter commit message: " commit_message
    if [ -z "$commit_message" ]; then
        bug "Commit message cannot be empty. Aborting."
        return 1
    fi
    git commit -m "$commit_message"
    push_to_remote
}

manage_stashes() {
    prominent "Stash Manager"
    local stashes=$(git stash list)
    if [ -z "$stashes" ]; then
        info "No stashes found."; return 0
    fi
    local selection=$(echo "$stashes" | fzf --prompt="Select a stash: " --header="[a]pply, [p]op, [d]rop, [s]how")
    if [ -z "$selection" ]; then info "Operation cancelled."; return 1; fi
    
    local stash_ref=$(echo "$selection" | awk '{print $1}' | sed 's/://')
    read -rp "Action for $stash_ref ([a]pply, [p]op, [d]rop, [s]how): " action

    case "$action" in
        a|A) git stash apply "$stash_ref" ;;
        p|P) git stash pop "$stash_ref" ;;
        d|D) if ask_confirmation "Really drop $stash_ref?"; then git stash drop "$stash_ref"; fi ;;
        s|S) git stash show -p "$stash_ref" | less -R ;;
        *) bug "Invalid action." ;;
    esac
}

# --- // BRANCHING & HISTORY
view_commit_history() { git log --oneline --graph --decorate --all | less -R; }

list_branches() { prominent "Branches:"; git branch -a --color=always | less -R; }

switch_branch() {
    local branch
    branch=$(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes/origin | sed 's/origin\///' | sort -u | fzf --prompt="Select branch to switch to: ")
    if [ -n "$branch" ]; then git checkout "$branch"; fi
}

create_new_branch() { read -rp "Enter new branch name: " name; if [ -n "$name" ]; then git checkout -b "$name"; fi; }

delete_branch() {
    local branch
    branch=$(git branch --format='%(refname:short)' | fzf --prompt="Select LOCAL branch to delete: ")
    if [ -n "$branch" ]; then
        if ask_confirmation "Delete local branch '$branch'?"; then git branch -d "$branch"; fi
        if ask_confirmation "Also delete remote branch 'origin/$branch'?"; then git push origin --delete "$branch"; fi
    fi
}

# --- // ADVANCED DIAGNOSTICS
search_repository() { read -rp "Enter search query (grep): " q; if [ -n "$q" ]; then git grep -i "$q"; fi; }

find_large_files() {
    prominent "Scanning repository for large files (>50MB)..."
    git rev-list --objects --all | \
      git cat-file --batch-check='%(objectname) %(objecttype) %(objectsize) %(rest)' | \
      awk '$3 > 50000000 {printf "%.2f MB\t%s\n", $3/1048576, $4}' | \
      sort -hr | less
}

initialize_repository() {
    if [ -d ".git" ]; then
        bug "This is already a Git repository."; return 1
    fi
    prominent "Initializing new Git repository..."
    git init
    info "Creating initial commit..."
    echo "# New Project" > README.md
    git add README.md
    git commit -m "Initial commit"
    if ask_confirmation "Do you want to add a remote origin now?"; then
        read -rp "Enter remote URL (e.g., git@github.com:user/repo.git): " remote_url
        if [ -n "$remote_url" ]; then
            git remote add origin "$remote_url"
            prominent "Remote 'origin' added. ${SUCCESS}"
        fi
    fi
}

# --- // CONFIGURATION
add_to_gitignore() {
    if [ ! -f ".gitignore" ]; then
        info "Creating .gitignore file."
        touch .gitignore
    fi
    read -rp "Enter pattern to add to .gitignore: " p
    if [ -n "$p" ]; then
        echo "$p" >> .gitignore
        prominent "'$p' added to .gitignore. ${SUCCESS}"
    fi
}

check_and_setup_ssh() {
    prominent "SSH Key Setup Assistant"
    local ssh_key_path="$HOME/.ssh/id_ed25519.pub"
    if [ -f "$ssh_key_path" ]; then
        prominent "Existing SSH key found: $ssh_key_path ${SUCCESS}"
    else
        info "No SSH key found at $ssh_key_path."
        if ! ask_confirmation "Do you want to generate a new SSH key?"; then
            info "SSH setup aborted."; return 1
        fi
        local email=$(get_git_email)
        ssh-keygen -t ed25519 -C "$email"
        prominent "New SSH key generated. ${SUCCESS}"
    fi
    if ask_confirmation "Do you want to add this key to your GitHub account?"; then
        if gh ssh-key add "$ssh_key_path" --title "Git-GUI-$(hostname)"; then
            prominent "SSH key successfully added to GitHub. ${SUCCESS}"
        else
            bug "Failed to add SSH key to GitHub. Please check 'gh' authentication."
        fi
    fi
}

intelligent_clone() {
    prominent "Intelligent Clone Assistant"
    info "Fetching a list of your GitHub repositories..."
    local repo_to_clone
    repo_to_clone=$(gh repo list --limit 100 | fzf --prompt="Select a repository to clone: ")
    if [ -z "$repo_to_clone" ]; then info "Clone operation cancelled."; return 1; fi
    local repo_name=$(echo "$repo_to_clone" | awk '{print $1}')
    info "Cloning $repo_name..."
    gh repo clone "$repo_name"
    prominent "Repository cloned successfully. ${SUCCESS}"
}

list_and_manage_remotes() {
    prominent "Remote Management"
    git remote -v
    read -rp "Action ([a]dd, [r]emove, [q]uit): " action
    case "$action" in
        a|A)
            read -rp "Enter remote name (e.g., upstream): " name
            read -rp "Enter remote URL: " url
            if [ -n "$name" ] && [ -n "$url" ]; then git remote add "$name" "$url"; fi
            ;;
        r|R)
            local remote_to_remove=$(git remote | fzf --prompt="Select remote to remove: ")
            if [ -n "$remote_to_remove" ]; then git remote remove "$remote_to_remove"; fi
            ;;
        *)
            info "No action taken."
            ;;
    esac
}

auto_commit_sync() {
    prominent "Auto-Commit & Sync"
    info "This will stage all changes, commit with a timestamped message, and push."
    git status -s
    if ! ask_confirmation "Proceed with auto-commit and push?"; then
        info "Operation cancelled."; return 1
    fi
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    git add .
    git commit -m "Auto-sync: $timestamp"
    push_to_remote
    prominent "Auto-sync complete. ${SUCCESS}"
}

# --- // MAIN LOGIC LOOP:
gui() {
  while true; do
    clear
    local menu_format="  ${GREEN}%-2s)${NC} %-30s ${GREEN}%-3s)${NC} %s\n"
    local heading_format="\n  ${BOLD}${GREEN}%-34s %-34s${NC}\n"
    
    prominent "# --- // Git Strategic Command Console //"
    
    printf "$heading_format" "GUIDED WORKFLOWS" "EMERGENCY & RECOVERY"
    printf "$menu_format" "1" "Pristine Contribution Wizard" "10" "Emergency Recovery Protocol"
    printf "$menu_format" "2" "Pre-PR Cleanup Assistant" "11" "Restore Single Deleted File"
    
    printf "$heading_format" "DAILY OPERATIONS" "BRANCHING & HISTORY"
    printf "$menu_format" "20" "Fetch All Remotes" "30" "View Commit History"
    printf "$menu_format" "21" "Pull (Safe Rebase)" "31" "List & Switch Branches"
    printf "$menu_format" "22" "Push to Upstream" "32" "Create New Branch"
    printf "$menu_format" "23" "Interactive Add" "33" "Delete Branch"
    printf "$menu_format" "24" "Quick Commit & Push" "34" "Manage Stashes"
    printf "$menu_format" "25" "Auto-Commit & Sync" "" ""

    printf "$heading_format" "REPOSITORY & CONFIG" "ADVANCED DIAGNOSTICS"
    printf "$menu_format" "40" "Initialize Repository" "50" "Search Repository Content"
    printf "$menu_format" "41" "Intelligent Clone" "51" "Find Large Files in History"
    printf "$menu_format" "42" "Manage Remotes" "" ""
    printf "$menu_format" "43" "Add to .gitignore" "" ""
    printf "$menu_format" "44" "Check & Setup SSH Key" "" ""

    printf "\n  ${GREEN}e/q)${NC} Exit\n"
    printf "\n${GREEN}By your command:${NC}\n"
    read -rp "❯ " choice

    case "$choice" in
      1) pristine_contribution_wizard ;;
      2) pre_flight_cleanup_assistant ;;
      10) emergency_recovery_protocol ;;
      11) restore_single_file ;;

      20) fetch_from_remote ;;
      21) pull_from_remote ;;
      22) push_to_remote ;;
      23) interactive_add ;;
      24) quick_commit_push ;;
      25) auto_commit_sync ;;

      30) view_commit_history ;;
      31) switch_branch ;;
      32) create_new_branch ;;
      33) delete_branch ;;
      34) manage_stashes ;;

      40) initialize_repository ;;
      41) intelligent_clone ;;
      42) list_and_manage_remotes ;;
      43) add_to_gitignore ;;
      44) check_and_setup_ssh ;;

      50) search_repository ;;
      51) find_large_files ;;

      e|q) info "Exiting..."; exit 0 ;;
      *) bug "Invalid choice!" ;;
    esac || true
    pause
  done
}

# --- // SCRIPT ENTRYPOINT
main() {
    # Check if we are inside a git repository for context-sensitive commands
    if ! git rev-parse --is-inside-work-tree &> /dev/null; then
        info "Not inside a Git repository. Some commands will be unavailable."
        if ask_confirmation "Do you want to initialize a new repository here or clone an existing one?"; then
            read -rp "Choose: [i]nitialize or [c]lone? " init_choice
            case "$init_choice" in
                i|I) initialize_repository ;;
                c|C) intelligent_clone ;;
                *) info "Proceeding with limited functionality." ;;
            esac
        fi
    fi
    check_dependencies
    gui
}

main
