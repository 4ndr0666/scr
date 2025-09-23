#!/bin/bash
# shellcheck disable=SC2155,SC2034
# Rev: 3
# Author: 4ndr0666, Ψ-Anarch
set -euo pipefail
# ============================== // GUI.SH //
# Description: 
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
get_git_email() { git config user.email; }

# --- // NEW: EMERGENCY & RECOVERY PROTOCOLS
emergency_recovery_protocol() {
    prominent "EMERGENCY RECOVERY PROTOCOL"
    info "This wizard helps you recover from a bad state (e.g., accidental deletion)."; echo
    
    if ! ask_confirmation "This involves 'git reset --hard' and 'git push --force'. Proceed with caution?"; then
        info "Recovery aborted."; return 1
    fi

    local current_branch=$(git branch --show-current)
    info "Analyzing the reference log for the current branch: '$current_branch'..."
    
    local reflog_entry; reflog_entry=$(git reflog --pretty=format:'%h %gs' | fzf --height=50% --prompt="Select the LAST KNOWN GOOD state to restore to: ")
    if [ -z "$reflog_entry" ]; then bug "No state selected. Aborting recovery."; return 1; fi
    
    local good_hash=$(echo "$reflog_entry" | cut -d' ' -f1)
    local description=$(echo "$reflog_entry" | cut -d' ' -f2-)
    
    info "You have selected: ${good_hash} - ${description}"
    if ! ask_confirmation "Do you want to temporarily checkout this commit to inspect it?"; then
        info "Skipping inspection."
    else
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
    
    if [ "$confirmation" != "$current_branch" ]; then
        bug "Confirmation failed. Recovery aborted."; return 1
    fi
    
    prominent "Executing recovery..."
    info "Step 1: Resetting local branch..."
    git reset --hard "$good_hash"
    info "Step 2: Force-pushing to remote..."
    git push origin "$current_branch" --force
    
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
    local file_path=$(echo "$selection" | awk '{$1=""; print $0}' | xargs) # trim leading space
    
    local parent_hash="${commit_hash}^"
    
    info "You are about to restore '${file_path}' from the commit before it was deleted (${parent_hash})."
    if ! ask_confirmation "Proceed?"; then info "Restore canceled."; return 1; fi
    
    git checkout "$parent_hash" -- "$file_path"
    prominent "File '${file_path}' has been restored to your working directory. ${SUCCESS}"
    info "Please stage and commit this change."
    git status --short
}

# --- // CORE GIT FUNCTIONS (EXISTING)
# These are kept for direct access, many are now part of larger workflows.
pull_from_remote() {
    local current_branch=$(git branch --show-current)
    if ! git diff-index --quiet HEAD --; then
        info "Local changes detected."
        if ask_confirmation "Stash changes before pulling?"; then
            git stash push -u -m "autostash-before-pull-$(date +%s)"
            prominent "Changes stashed."
            git pull --rebase
            git stash pop
            prominent "Pulled with rebase and restored stashed changes. ${SUCCESS}"
        else
            bug "Pull aborted due to uncommitted changes."; return 1
        fi
    else
        prominent "Pulling updates for branch '$current_branch'..."; git pull --rebase; prominent "Pull complete. ${SUCCESS}"
    fi
}

# (Other existing functions like push_to_remote, interactive_add, etc., would be here)
# ... for brevity, many existing functions are omitted but assumed to exist.

# --- // PLACEHOLDER WORKFLOWS & UTILITIES (TO BE IMPLEMENTED)
pristine_contribution_wizard() { bug "Workflow not yet implemented."; }
pre_flight_cleanup_assistant() { bug "Workflow not yet implemented."; }
find_large_files() {
    prominent "Scanning repository for large files (>50MB)..."
    git rev-list --objects --all | \
      git cat-file --batch-check='%(objectname) %(objecttype) %(objectsize) %(rest)' | \
      awk '$3 > 50000000 {printf "%.2f MB\t%s\n", $3/1048576, $4}' | \
      sort -hr | less
}
list_and_manage_remotes() { info "Function 'list_and_manage_remotes' called."; }
switch_to_ssh() { info "Function 'switch_to_ssh' called."; }
fetch_from_remote() { prominent "Fetching updates..."; git fetch --all --prune; prominent "Fetch complete."; }
list_branches() { prominent "Branches:"; git branch -a | less -R; }
switch_branch() { local branch; branch=$(git branch -a | sed 's/.*remotes\///' | sed 's/origin\///' | fzf); if [ -n "$branch" ]; then git checkout "$branch"; fi; }
create_new_branch() { read -rp "Enter new branch name: " name; if [ -n "$name" ]; then git checkout -b "$name"; fi; }
delete_branch() { local branch; branch=$(git branch --format='%(refname:short)' | fzf); if [ -n "$branch" ]; then if ask_confirmation "Delete $branch?"; then git branch -d "$branch"; fi; fi; }
manage_stashes() { info "Function 'manage_stashes' called."; }
view_commit_history() { git log --oneline --graph --decorate --all | less -R; }
add_to_gitignore() { read -rp "Enter pattern: " p; if [ -n "$p" ]; then echo "$p" >> .gitignore; fi; }
search_repository() { read -rp "Enter query: " q; if [ -n "$q" ]; then git grep -i "$q"; fi; }
intelligent_clone() { bug "Not implemented."; }
initialize_repository() { bug "Not implemented."; }
interactive_add() { bug "Not implemented."; }
quick_commit_push() { bug "Not implemented."; }
auto_commit_sync() { bug "Not implemented."; }
push_to_remote() { bug "Not implemented."; }

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
    printf "$menu_format" "24" "Manage Stashes" "34" "Manage Remotes"

    printf "$heading_format" "ADVANCED DIAGNOSTICS" "CONFIGURATION"
    printf "$menu_format" "40" "Search Repository Content" "50" "Add to .gitignore"
    printf "$menu_format" "41" "Find Large Files in History" "51" "Check & Setup SSH Key"
    printf "$menu_format" "42" "Initialize Repository" "52" "Advanced Clone"
    printf "$menu_format" "" "" "53" "Auto-Commit & Sync"


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
      24) manage_stashes ;;

      30) view_commit_history ;;
      31) switch_branch ;;
      32) create_new_branch ;;
      33) delete_branch ;;
      34) list_and_manage_remotes ;;

      40) search_repository ;;
      41) find_large_files ;;
      42) initialize_repository ;;

      50) add_to_gitignore ;;
      51) check_and_setup_ssh ;;
      52) intelligent_clone ;;
      53) auto_commit_sync ;;

      e|q) info "Exiting..."; exit 0 ;;
      *) bug "Invalid choice!" ;;
    esac || true
    pause
  done
}

# --- // SCRIPT ENTRYPOINT
main() {
    check_dependencies
    gui
}

main
