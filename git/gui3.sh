#!/bin/bash
# shellcheck disable=SC2155,SC2034
# Rev: 5.3 (Fix Menu Color Rendering)
# Author: 4ndr0666, Ψ-Anarch, HIC-7
set -euo pipefail
# ============================== // GUI.SH //
# Description: A unified strategic command console for Git operations,
# with a refined, user-friendly interface.
#
# -------------------------------------------

# Constants: Colors, Symbols, & Styles
readonly BOLD='\033[1m'; readonly UNDERLINE='\033[4m'
readonly GREEN='\033[0;32m'; readonly RED='\033[0;31m'; readonly CYAN='\033[0;36m'; readonly YELLOW='\033[0;33m'
readonly NC='\033[0m'
readonly SUCCESS="✔️"; readonly FAILURE="❌"; readonly INFO="➡️"; readonly WARN="⚠️"

# --- // UI & HELPER FUNCTIONS
prominent() { printf "${BOLD}${GREEN}%s${NC}\n" "$1"; }
bug() { printf "${BOLD}${RED}%s${NC}\n" "$1" >&2; }
info() { printf "${CYAN}%s${NC}\n" "$1"; }
warning() { printf "${YELLOW}%s${NC}\n" "$1"; }
pause() { read -n 1 -s -r -p "Press any key to return to the menu..."; echo; }

ask_confirmation() {
    local prompt_message="$1"; local response
    while true; do
        read -rp "$prompt_message (y/n): " response
        case "$response" in [yY]|[yY][eE][sS]) return 0;; [nN]|[nN][oO]) return 1;; *) bug "Invalid input.";; esac
    done
}

# --- // PRE-FLIGHT CHECKS
check_dependencies() {
    local missing_deps=(); local deps=("git" "fzf" "gh" "shellcheck" "shfmt")
    prominent "Checking for required dependencies..."; for cmd in "${deps[@]}"; do if ! command -v "$cmd" &>/dev/null; then missing_deps+=("$cmd"); fi; done
    if [ ${#missing_deps[@]} -gt 0 ]; then
        bug "Error: Missing dependencies:"; for dep in "${missing_deps[@]}"; do printf "${RED}- %s${NC}\n" "$dep"; done
        bug "Please install them and try again."; exit 1
    else prominent "All dependencies are installed. ${SUCCESS}"; fi
}

# --- // DYNAMIC CONFIGURATION
get_gh_user() { if [ -z "${GH_USER:-}" ]; then local user_name; user_name=$(gh api user --jq .login) || { bug "Failed to get GitHub username."; return 1; }; export GH_USER="$user_name"; fi; echo "$GH_USER"; }
get_git_email() { git config user.email || echo "user@example.com"; }

# --- // GUIDED WORKFLOWS
pristine_contribution_wizard() {
    prominent "Pristine Contribution Wizard"
    local main_branch="main"
    if ! git show-ref --verify --quiet refs/heads/"$main_branch"; then
        main_branch="master"
        if ! git show-ref --verify --quiet refs/heads/"$main_branch"; then bug "Could not determine default branch (main/master). Aborting."; return 1; fi
    fi
    info "Step 1: Ensuring '$main_branch' is up-to-date."
    git checkout "$main_branch" && git pull origin "$main_branch" --rebase
    read -rp "Step 2: Enter name for your new feature branch: " new_branch
    if [ -z "$new_branch" ]; then bug "Branch name cannot be empty."; return 1; fi
    git checkout -b "$new_branch"
    prominent "Switched to new branch '$new_branch'."
    info "You can now start working on your changes."
    if ask_confirmation "Push this new branch to origin to set up tracking?"; then git push --set-upstream origin "$new_branch"; fi
    prominent "Wizard complete. Happy coding! ${SUCCESS}"
}

pre_pr_cleanup_assistant() {
    prominent "Pre-PR Cleanup Assistant"
    local current_branch=$(git branch --show-current)
    local target_branch="main"
    if ! git show-ref --verify --quiet refs/heads/"$target_branch"; then target_branch="master"; fi
    info "This assistant helps you clean up '$current_branch' before creating a pull request against '$target_branch'."
    if ask_confirmation "Start an interactive rebase against '$target_branch' to squash/reword commits?"; then
        info "Rebasing '$current_branch' onto '$target_branch'..."
        if ! git rebase -i "$target_branch"; then bug "Rebase failed. Please resolve conflicts and run 'git rebase --continue' or 'git rebase --abort'."; return 1; fi
        info "Rebase complete."
        if ask_confirmation "Force-push the cleaned branch to update the remote? (Required after rebase)"; then git push --force-with-lease; prominent "Force push complete."; fi
    fi
    prominent "Cleanup complete. Your branch is ready for a pull request. ${SUCCESS}"
}

# --- // DAILY OPERATIONS
fetch_from_remote() { prominent "Fetching updates..."; info "Executing 'git fetch --all --prune'..."; git fetch --all --prune; prominent "Fetch complete. ${SUCCESS}"; }

pull_from_remote() {
    local current_branch=$(git branch --show-current)
    if ! git diff-index --quiet HEAD --; then
        info "Local changes detected."
        if ask_confirmation "Stash changes before pulling?"; then
            git stash push -u -m "autostash-before-pull-$(date +%s)"
            prominent "Changes stashed."
            if ! git pull --rebase; then bug "Pull failed. Your changes remain stashed. Please resolve the pull issues manually."; return 1; fi
            if ! git stash pop; then bug "Could not pop stashed changes. There might be a conflict. Use 'git stash apply' to inspect."; return 1; fi
            prominent "Pulled with rebase and restored stashed changes. ${SUCCESS}"
        else bug "Pull aborted due to uncommitted changes."; return 1; fi
    else prominent "Pulling updates for branch '$current_branch'..."; git pull --rebase; prominent "Pull complete. ${SUCCESS}"; fi
}

push_to_remote() {
    local current_branch=$(git branch --show-current)
    local remote_branch=$(git rev-parse --abbrev-ref "$current_branch"@{u} 2>/dev/null)
    if [ -z "$remote_branch" ]; then
        info "No upstream branch is set for '$current_branch'."
        if ask_confirmation "Push and set upstream to 'origin/$current_branch'?"; then git push --set-upstream origin "$current_branch"; else info "Push aborted."; return 1; fi
    else prominent "Pushing to '$remote_branch'..."; git push; fi
    prominent "Push complete. ${SUCCESS}"
}

interactive_add() { prominent "Entering Interactive Staging"; info "Use 's' to see status, 'u' to update, 'p' to patch, 'q' to quit."; git add -i; prominent "Exited interactive staging."; git status -s; }

quick_commit_push() {
    prominent "Quick Commit & Push"
    git status -s
    if ! git diff-index --quiet HEAD -- && ! git ls-files --others --exclude-standard | grep -q .; then info "No changes to commit."; return 0; fi
    if ! ask_confirmation "The above changes will be staged. Proceed?"; then info "Operation cancelled."; return 1; fi
    git add .
    read -rp "Enter commit message: " commit_message
    if [ -z "$commit_message" ]; then bug "Commit message cannot be empty. Aborting."; return 1; fi
    git commit -m "$commit_message"
    push_to_remote
}

auto_commit_sync() {
    prominent "Auto-Commit & Sync"
    info "This will stage all changes, commit with a timestamped message, and push."
    git status -s
    if ! git diff-index --quiet HEAD -- && ! git ls-files --others --exclude-standard | grep -q .; then info "No changes to commit."; return 0; fi
    if ! ask_confirmation "Proceed with auto-commit and push?"; then info "Operation cancelled."; return 1; fi
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    git add .
    git commit -m "Auto-sync: $timestamp"
    push_to_remote
    prominent "Auto-sync complete. ${SUCCESS}"
}

manage_stashes() {
    prominent "Stash Manager"
    local stashes=$(git stash list)
    if [ -z "$stashes" ]; then info "No stashes found."; return 0; fi
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
view_commit_history() { info "Loading commit history..."; git log --oneline --graph --decorate --all | less -R; }

switch_branch() {
    info "Loading branches..."
    local branch
    branch=$(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes/origin | sed 's/origin\///' | sort -u | fzf --prompt="Select branch to switch to: ")
    if [ -n "$branch" ]; then git checkout "$branch"; fi
}

create_new_branch() { read -rp "Enter new branch name: " name; if [ -n "$name" ]; then git checkout -b "$name"; fi; }

delete_branch() {
    info "Loading local branches..."
    local branch
    branch=$(git branch --format='%(refname:short)' | fzf --prompt="Select LOCAL branch to delete: ")
    if [ -n "$branch" ]; then
        if ask_confirmation "Delete local branch '$branch'?"; then git branch -d "$branch"; fi
        if ask_confirmation "Also delete remote branch 'origin/$branch'?"; then git push origin --delete "$branch"; fi
    fi
}

interactive_rebase() {
    prominent "Interactive Rebase"
    info "Loading branches to select a base..."
    local base_branch
    base_branch=$(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes/origin | sed 's/origin\///' | sort -u | fzf --prompt="Select BASE branch to rebase onto: ")
    if [ -z "$base_branch" ]; then info "Operation cancelled."; return 1; fi
    if ask_confirmation "Rebase current branch onto '$base_branch'?"; then
        if ! git rebase -i "$base_branch"; then bug "Rebase failed. Please resolve conflicts manually."; return 1; fi
        prominent "Rebase onto '$base_branch' complete. ${SUCCESS}"
    else info "Rebase cancelled."; fi
}

cherry_pick_commit() {
    prominent "Cherry-Pick a Commit"
    info "Fetching latest changes from all remotes..."
    git fetch --all
    local commit
    commit=$(git log --oneline --graph --all | fzf --height=50% --prompt="Select commit to cherry-pick: " | awk '{print $1}')
    if [ -z "$commit" ]; then info "Operation cancelled."; return 1; fi
    if ask_confirmation "Cherry-pick commit '$commit'?"; then
        if ! git cherry-pick "$commit"; then bug "Cherry-pick failed. Please resolve any conflicts."; return 1; fi
        prominent "Commit '$commit' cherry-picked successfully. ${SUCCESS}"
    else info "Cherry-pick cancelled."; fi
}

# --- // RECOVERY & REPAIR
emergency_recovery_protocol() {
    prominent "EMERGENCY RECOVERY PROTOCOL"
    info "This wizard helps you recover from a bad state using the reflog."; echo
    warning "${WARN} This involves 'git reset --hard' and 'git push --force'. Proceed with extreme caution!"
    if ! ask_confirmation "Are you sure you want to proceed?"; then info "Recovery aborted."; return 1; fi
    local current_branch=$(git branch --show-current)
    info "Analyzing the reference log for the current branch: '$current_branch'..."
    local reflog_entry; reflog_entry=$(git reflog --pretty=format:'%h %gs' | fzf --height=50% --prompt="Select the LAST KNOWN GOOD state to restore to: ")
    if [ -z "$reflog_entry" ]; then bug "No state selected. Aborting recovery."; return 1; fi
    local good_hash=$(echo "$reflog_entry" | cut -d' ' -f1)
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
    local deletion_log; deletion_log=$(git log --diff-filter=D --summary --pretty=format:'%C(yellow)%h %C(reset)%s' | sed -n '/delete mode/p' | sed 's/ delete mode [0-9]* //')
    if [ -z "$deletion_log" ]; then bug "Could not find any file deletions in the history."; return 1; fi
    local selection; selection=$(echo "$deletion_log" | fzf --prompt="Select the deletion event to reverse: ")
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

restore_branch_from_commit() {
    prominent "Restore Branch from Old Commit"
    local commit
    commit=$(git log --oneline --all | fzf --height=50% --prompt="Select commit to create a new branch from: " | awk '{print $1}')
    if [ -z "$commit" ]; then info "Operation cancelled."; return 1; fi
    local branch_name="restore-$(date +%Y%m%d%H%M%S)"
    if ask_confirmation "Create new branch '$branch_name' from commit '$commit'?"; then
        if ! git checkout -b "$branch_name" "$commit"; then bug "Branch creation failed."; return 1; fi
        prominent "Branch '$branch_name' created and checked out successfully. ${SUCCESS}"
    else info "Operation cancelled."; fi
}

fix_git_repository() {
    prominent "Advanced Git Repository Repair"
    warning "${WARN} This is a powerful and potentially destructive tool."
    info "It will back up your repo, disable hooks, run 'git fsck', and attempt to repair corruption."
    if ! ask_confirmation "This is a last resort. Are you sure you want to proceed?"; then info "Repair aborted."; return 1; fi
    local backup_dir="../git_repo_backup_$(date +%Y%m%d_%H%M%S)"
    prominent "Backing up current repository to ${backup_dir}..."
    if ! cp -r . "${backup_dir}"; then bug "Backup failed. Aborting repair."; return 1; fi; info "Backup complete. ${SUCCESS}"
    info "Running repair protocol..."; git fsck --full && git gc --prune=now --aggressive
    prominent "Repair process complete. Verify repository integrity. ${SUCCESS}"
}

# --- // DIAGNOSTICS & AUTOMATION
search_repository() { read -rp "Enter search query (grep): " q; if [ -n "$q" ]; then git grep -i --color=always "$q" | less -R; fi; }

find_large_files() {
    prominent "Scanning repository for large files (>50MB)..."
    git rev-list --objects --all | git cat-file --batch-check='%(objectname) %(objecttype) %(objectsize) %(rest)' | awk '$3 > 50000000 {printf "%.2f MB\t%s\n", $3/1048576, $4}' | sort -hr | less
}

setup_git_hooks() {
    prominent "Git Hooks Setup"
    info "This will install local pre-commit, commit-msg, and pre-push hooks."
    if ! ask_confirmation "This will overwrite existing hooks (after backing them up). Proceed?"; then info "Setup cancelled."; return 1; fi
    local GIT_HOOKS_DIR=".git/hooks"; if [[ ! -d "${GIT_HOOKS_DIR}" ]]; then mkdir -p "${GIT_HOOKS_DIR}"; fi
    install_hook() {
        local hook_name="$1" hook_content="$2" hook_path="${GIT_HOOKS_DIR}/${hook_name}"
        if [[ -f "${hook_path}" && ! "${hook_path}" =~ \.sample$ ]]; then cp "${hook_path}" "${hook_path}.backup.$(date +%s)"; fi
        printf '%s\n' "${hook_content}" >"${hook_path}"; chmod +x "${hook_path}"; info "Installed/updated '${hook_name}' hook."
    }
    install_hook "pre-commit" '#!/bin/bash
set -eu; echo "Running pre-commit hook..."; shfmt -i 2 -w $(git diff --cached --name-only --diff-filter=ACM | grep -E "\.sh$"); shellcheck $(git diff --cached --name-only --diff-filter=ACM | grep -E "\.sh$"); echo "Pre-commit checks passed."'
    install_hook "commit-msg" '#!/bin/bash
set -eu; subject=$(head -n1 "$1"); if (( ${#subject} > 72 )); then echo "ERROR: Subject line > 72 chars." >&2; exit 1; fi'
    prominent "Git hooks installed successfully. ${SUCCESS}"
}

# --- // REPOSITORY & CONFIG
initialize_repository() {
    if [ -d ".git" ]; then bug "This is already a Git repository."; return 1; fi
    prominent "Initializing new Git repository..."; git init; info "Creating initial commit..."; echo "# New Project" > README.md; git add README.md; git commit -m "Initial commit"
    if ask_confirmation "Do you want to add a remote origin now?"; then read -rp "Enter remote URL: " remote_url; if [ -n "$remote_url" ]; then git remote add origin "$remote_url"; prominent "Remote 'origin' added. ${SUCCESS}"; fi; fi
}

intelligent_clone() {
    prominent "Intelligent Clone Assistant"; info "Fetching a list of your GitHub repositories..."
    local repo_to_clone; repo_to_clone=$(gh repo list --limit 100 | fzf --prompt="Select a repository to clone: ")
    if [ -z "$repo_to_clone" ]; then info "Clone operation cancelled."; return 1; fi
    local repo_name=$(echo "$repo_to_clone" | awk '{print $1}')
    info "Cloning $repo_name..."; gh repo clone "$repo_name"; prominent "Repository cloned successfully. ${SUCCESS}"
}

list_and_manage_remotes() {
    prominent "Remote Management"; git remote -v; read -rp "Action ([a]dd, [r]emove, [q]uit): " action
    case "$action" in
        a|A) read -rp "Enter remote name: " name; read -rp "Enter remote URL: " url; if [ -n "$name" ] && [ -n "$url" ]; then git remote add "$name" "$url"; fi ;;
        r|R) local remote_to_remove=$(git remote | fzf --prompt="Select remote to remove: "); if [ -n "$remote_to_remove" ]; then git remote remove "$remote_to_remove"; fi ;;
        *) info "No action taken." ;;
    esac
}

add_to_gitignore() {
    if [ ! -f ".gitignore" ]; then info "Creating .gitignore file."; touch .gitignore; fi
    read -rp "Enter pattern to add to .gitignore: " p; if [ -n "$p" ]; then echo "$p" >> .gitignore; prominent "'$p' added to .gitignore. ${SUCCESS}"; fi
}

check_and_setup_ssh() {
    prominent "SSH Key Setup Assistant"
    local ssh_key_path="$HOME/.ssh/id_ed25519.pub"
    if [ -f "$ssh_key_path" ]; then prominent "Existing SSH key found: $ssh_key_path ${SUCCESS}"; else
        info "No SSH key found at $ssh_key_path."; if ! ask_confirmation "Generate a new SSH key?"; then info "SSH setup aborted."; return 1; fi
        ssh-keygen -t ed25519 -C "$(get_git_email)"; prominent "New SSH key generated. ${SUCCESS}"
    fi
    if ask_confirmation "Add this key to your GitHub account?"; then
        if gh ssh-key add "$ssh_key_path" --title "Git-GUI-$(hostname)"; then prominent "SSH key successfully added to GitHub. ${SUCCESS}"; else bug "Failed to add SSH key. Check 'gh' auth."; fi
    fi
}

switch_to_ssh() {
    prominent "Convert Remote URL to SSH"
    local remote_name; remote_name=$(git remote | fzf --height=20% --prompt="Select remote to convert: ")
    if [[ -z "${remote_name}" ]]; then info "No remote selected."; return 1; fi; local old_url; old_url=$(git remote get-url "${remote_name}")
    if [[ "${old_url}" == git@* ]]; then prominent "Remote '${remote_name}' is already using SSH."; return 0; fi
    if [[ ! "${old_url}" =~ github.com ]]; then bug "This function only supports GitHub HTTPS URLs."; return 1; fi
    local user_repo; user_repo=$(echo "$old_url" | sed -E 's|https://github.com/||; s|\.git$||'); local new_url="git@github.com:${user_repo}.git"
    info "Old URL: $old_url"; info "New URL: $new_url"
    if ask_confirmation "Set remote '${remote_name}' to the new SSH URL?"; then git remote set-url "${remote_name}" "${new_url}"; prominent "Remote '${remote_name}' updated. ${SUCCESS}"; else info "Operation cancelled."; fi
}

# --- // HELP SYSTEM ---
display_help() {
    clear
    printf "${BOLD}${GREEN}Git Strategic Command Console - Help & Usage${NC}\n"
    printf "${CYAN}Enter the number corresponding to the desired command. Use 'h' for help, 'q' or 'e' to exit.${NC}\n\n"
    
    local category_format="${BOLD}${YELLOW}${UNDERLINE}%s${NC}\n"
    local help_format="  ${GREEN}%-3s${NC} %-25s ${CYAN}%s${NC}\n"

    printf "$category_format" "GUIDED WORKFLOWS"
    printf "$help_format" "1" "Pristine Contribution" "Create a new feature branch from an up-to-date main/master."
    printf "$help_format" "2" "Pre-PR Cleanup" "Interactively rebase current branch against main/master."
    
    printf "\n$category_format" "DAILY OPERATIONS"
    printf "$help_format" "3" "Fetch All Remotes" "Download objects/refs from all remotes without merging."
    printf "$help_format" "4" "Pull (Safe Rebase)" "Fetch and integrate changes. Prompts to stash local changes."
    printf "$help_format" "5" "Push to Upstream" "Push commits. Prompts to set upstream if needed."
    printf "$help_format" "6" "Interactive Add" "Choose which changes to stage with 'git add -i'."
    printf "$help_format" "7" "Quick Commit & Push" "Stage all, prompt for message, commit, and push."
    printf "$help_format" "8" "Auto-Commit & Sync" "Stage all, commit with a timestamp, and push."
    printf "$help_format" "9" "Manage Stashes" "Interactive menu to view, apply, pop, or drop stashes."

    printf "\n$category_format" "BRANCHING & HISTORY"
    printf "$help_format" "10" "View Commit History" "Display a graphical log of the entire commit history."
    printf "$help_format" "11" "Switch Branch" "Quickly check out any local or remote branch via fzf."
    printf "$help_format" "12" "Create New Branch" "Prompt for a name and create a new local branch."
    printf "$help_format" "13" "Delete Branch" "Select a local branch to delete; prompts to delete remote."
    printf "$help_format" "14" "Interactive Rebase" "Squash, edit, or reorder commits against a chosen base branch."
    printf "$help_format" "15" "Cherry-Pick a Commit" "Select a single commit from any branch to apply here."

    printf "\n$category_format" "RECOVERY & REPAIR"
    printf "$help_format" "16" "Emergency Recovery" "${BOLD}${RED}DANGEROUS:${NC} Restore a branch to a past state from reflog."
    printf "$help_format" "17" "Restore Single File" "Find and restore a deleted file from Git history."
    printf "$help_format" "18" "Restore Branch" "Create a new branch from any commit in the history."
    printf "$help_format" "19" "Fix Corrupt Repo" "${BOLD}${RED}DANGEROUS:${NC} Attempt to repair a corrupted local repository."
    
    printf "\n$category_format" "REPOSITORY & CONFIG"
    printf "$help_format" "20" "Initialize Repository" "Run 'git init' in the current directory."
    printf "$help_format" "21" "Intelligent Clone" "Clone one of your GitHub repos using fzf."
    printf "$help_format" "22" "Manage Remotes" "View, add, or remove remote repositories."
    printf "$help_format" "23" "Convert to SSH" "Convert a remote's HTTPS URL to its SSH equivalent."
    printf "$help_format" "24" "Add to .gitignore" "Append a pattern to the .gitignore file."
    printf "$help_format" "25" "Check & Setup SSH" "Check/generate an SSH key and add it to GitHub."

    printf "\n$category_format" "DIAGNOSTICS & AUTOMATION"
    printf "$help_format" "26" "Search Repository" "Search for a string in all tracked files ('git grep')."
    printf "$help_format" "27" "Find Large Files" "Scan history for files larger than 50MB."
    printf "$help_format" "28" "Setup Git Hooks" "Install client-side hooks for linting and formatting."
    echo
}

# --- // MAIN MENU & LOOP ---
display_menu() {
    clear
    local ver="5.3"
    local head_color="${BOLD}${CYAN}"
    local border_color="${CYAN}"
    local cat_color="${BOLD}${YELLOW}"
    local num_color="${GREEN}"
    
    # CORRECTED: Use %b to interpret ANSI color codes in the arguments.
    # Each column: Number (2 chars), Text (21 chars), Space (2 chars) = 25 chars wide.
    local menu_line_format="  ${num_color}%-2s)${NC} %-21b${num_color}%-2s)${NC} %-21b${num_color}%-2s)${NC} %-21b\n"

    printf "${border_color}╭──────────────────────────────────────────────────────────────────────────╮${NC}\n"
    printf "${border_color}│${head_color}                Git Strategic Command Console v%-9s                  ${border_color}│${NC}\n" "$ver"
    printf "${border_color}╰──────────────────────────────────────────────────────────────────────────╯${NC}\n"
    
    printf "  ${cat_color}%-25s %-25s %-25s${NC}\n" "WORKFLOWS & DAILY OPS" "BRANCHING & HISTORY" "RECOVERY & REPAIR"
    printf "$menu_line_format" \
        "1" "Pristine Contribution" "10" "View History"        "16" "${RED}Emergency Recovery${NC}" \
        "2" "Pre-PR Cleanup"        "11" "Switch Branch"       "17" "Restore Single File" \
        "3" "Fetch All Remotes"     "12" "Create Branch"       "18" "Restore Branch" \
        "4" "Pull (Safe Rebase)"    "13" "Delete Branch"       "19" "${RED}Fix Corrupt Repo${NC}" \
        "5" "Push to Upstream"      "14" "Interactive Rebase"  "" "" \
        "6" "Interactive Add"       "15" "Cherry-Pick Commit"  "" "" \
        "7" "Quick Commit & Push"   ""   ""                    "" "" \
        "8" "Auto-Commit & Sync"    ""   ""                    "" "" \
        "9" "Manage Stashes"        ""   ""                    "" "" 
    
    printf "\n"
    printf "  ${cat_color}%-25s %-25s %-25s${NC}\n" "REPOSITORY & CONFIG" "DIAGNOSTICS & AUTOMATION" ""
    printf "$menu_line_format" \
        "20" "Initialize Repo"       "26" "Search Repository"   "" "" \
        "21" "Intelligent Clone"     "27" "Find Large Files"    "" "" \
        "22" "Manage Remotes"        "28" "Setup Git Hooks"     "" "" \
        "23" "Convert to SSH"        ""   ""                    "" "" \
        "24" "Add to .gitignore"     ""   ""                    "" "" \
        "25" "Check & Setup SSH"     ""   ""                    "" "" 

    printf "${border_color}──────────────────────────────────────────────────────────────────────────${NC}\n"
    printf "  ${num_color}h)${NC} Help                                                           ${num_color}q/e)${NC} Exit\n"
    printf "${GREEN}By your command:${NC}\n"
}

gui() {
  while true; do
    display_menu
    read -rp "❯ " choice
    clear 
    
    case "$choice" in
      1) pristine_contribution_wizard ;; 2) pre_pr_cleanup_assistant ;;
      3) fetch_from_remote ;; 4) pull_from_remote ;; 5) push_to_remote ;; 6) interactive_add ;;
      7) quick_commit_push ;; 8) auto_commit_sync ;; 9) manage_stashes ;;
      10) view_commit_history ;; 11) switch_branch ;; 12) create_new_branch ;; 13) delete_branch ;;
      14) interactive_rebase ;; 15) cherry_pick_commit ;;
      16) emergency_recovery_protocol ;; 17) restore_single_file ;; 18) restore_branch_from_commit ;;
      19) fix_git_repository ;;
      20) initialize_repository ;; 21) intelligent_clone ;; 22) list_and_manage_remotes ;;
      23) switch_to_ssh ;; 24) add_to_gitignore ;; 25) check_and_setup_ssh ;;
      26) search_repository ;; 27) find_large_files ;; 28) setup_git_hooks ;;
      h|H) display_help ;;
      e|q|E|Q) info "Exiting..."; exit 0 ;;
      *) bug "Invalid choice '$choice'. Displaying help..."; display_help ;;
    esac || true
    echo; pause
  done
}

# --- // SCRIPT ENTRYPOINT
main() {
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        display_help
        exit 0
    fi

    if ! git rev-parse --is-inside-work-tree &> /dev/null; then
        info "Not inside a Git repository. Some commands will be unavailable."
        if ask_confirmation "Initialize a new repository or clone an existing one?"; then
            read -rp "Choose: [i]nitialize or [c]lone? " init_choice
            case "$init_choice" in i|I) initialize_repository ;; c|C) intelligent_clone ;; *) info "Proceeding with limited functionality.";; esac
        fi
    fi
    check_dependencies
    gui
}

main
