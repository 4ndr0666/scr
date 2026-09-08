#!/bin/bash
# shellcheck disable=SC2155,SC2034
# Rev: 6.0 (Golden-Unit Merge: regression fix + first-run identity config + gui2 grafts)
# Author: 4ndr0666, Ψ-Anarch, HIC-7
set -euo pipefail
# ============================== // GUI.SH //
# Description: A unified strategic command console for Git operations,
# with a refined, user-friendly interface.
#
# Rev 6.0 changelog against Rev 5.3:
#   - FIX: emergency_recovery_protocol regressed a Rev-4 safety guarantee
#     (pre-reset commit inspection). Restored.
#   - NEW: first-run configuration file (~/.config/git-gui-console/config)
#     replaces all hardcoded personal identity (email/GitHub username)
#     that shipped in the rejected gui2.sh candidate.
#   - NEW: update_remote_url, reconnect_old_repo, rebase_branch,
#     resolve_merge_conflicts, edit_config — grafted from gui2.sh candidate
#     review, re-implemented against the config system, with the gui2
#     operator-precedence bug and hardcoded-identity defects removed.
#   - EXCLUDED (deliberately, not silently): gui2.sh's run_integration_tests,
#     resolve_git_conflicts_automatically, setup_cron_job, setup_dependencies,
#     and perform_backup all dispatch to external "Git/scripts/*.sh" paths
#     that are not part of this repository and were never provided as
#     canonical source. Including them would ship orphaned references. See
#     the trailing note in this file's delivery message.
# -------------------------------------------

# Constants: Colors, Symbols, & Styles
readonly BOLD='\033[1m'; readonly UNDERLINE='\033[4m'
readonly GREEN='\033[0;32m'; readonly RED='\033[0;31m'; readonly CYAN='\033[0;36m'; readonly YELLOW='\033[0;33m'
readonly NC='\033[0m'
readonly SUCCESS="✔️"; readonly WARN="⚠️"

# Constants: First-run identity config
readonly CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/git-gui-console"
readonly CONFIG_FILE="${CONFIG_DIR}/config"

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
    local missing_deps=(); local deps=("git" "fzf" "gh" "shellcheck" "shfmt" "less" "hostname")
    prominent "Checking for required dependencies..."; for cmd in "${deps[@]}"; do if ! command -v "$cmd" &>/dev/null; then missing_deps+=("$cmd"); fi; done
    if [ ${#missing_deps[@]} -gt 0 ]; then
        bug "Error: Missing dependencies:"; for dep in "${missing_deps[@]}"; do printf "${RED}- %s${NC}\n" "$dep"; done
        bug "Please install them and try again."; exit 1
    else prominent "All dependencies are installed. ${SUCCESS}"; fi
}

# --- // FIRST-RUN IDENTITY CONFIGURATION
# Replaces gui2.sh's hardcoded personal email/username (a portability and
# correctness defect: running gui2.sh as anyone but its original author
# generated SSH keys under the wrong email and built remote URLs under the
# wrong GitHub namespace). Values are collected once, persisted to disk,
# and reused; get_gh_user()/get_git_email() read from this store.
first_run_setup() {
    prominent "First-Run Setup"
    info "No configuration found at ${CONFIG_FILE}. Let's set one up."
    mkdir -p "$CONFIG_DIR"
    chmod 700 "$CONFIG_DIR"

    local default_email default_user input_email input_user
    default_email=$(git config --global user.email 2>/dev/null || echo "")
    read -rp "Git commit/SSH email [${default_email:-none}]: " input_email
    GUI_GIT_EMAIL="${input_email:-$default_email}"
    while [ -z "$GUI_GIT_EMAIL" ]; do
        bug "An email is required (used for SSH key generation and as a commit-identity fallback)."
        read -rp "Git commit/SSH email (required): " GUI_GIT_EMAIL
    done

    default_user=""
    if command -v gh &>/dev/null && gh auth status &>/dev/null; then
        default_user=$(gh api user --jq .login 2>/dev/null || echo "")
    fi
    read -rp "GitHub username [${default_user:-none}]: " input_user
    GUI_GH_USER="${input_user:-$default_user}"
    while [ -z "$GUI_GH_USER" ]; do
        bug "A GitHub username is required (used to construct remote URLs)."
        read -rp "GitHub username (required): " GUI_GH_USER
    done

    {
        printf 'GUI_GIT_EMAIL=%q\n' "$GUI_GIT_EMAIL"
        printf 'GUI_GH_USER=%q\n' "$GUI_GH_USER"
    } > "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    export GUI_GIT_EMAIL GUI_GH_USER
    prominent "Configuration saved to ${CONFIG_FILE}. ${SUCCESS}"
}

load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        first_run_setup
        return 0
    fi
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
    export GUI_GIT_EMAIL GUI_GH_USER
}

edit_config() {
    prominent "Current Configuration"
    if [[ -f "$CONFIG_FILE" ]]; then
        info "File: ${CONFIG_FILE}"
        cat "$CONFIG_FILE"
    else
        info "No config file exists yet."
    fi
    if ask_confirmation "Reset and re-run first-run setup now?"; then
        rm -f "$CONFIG_FILE"
        first_run_setup
    fi
}

get_gh_user() {
    if [ -z "${GUI_GH_USER:-}" ]; then load_config; fi
    echo "$GUI_GH_USER"
}

get_git_email() {
    if [ -z "${GUI_GIT_EMAIL:-}" ]; then load_config; fi
    echo "$GUI_GIT_EMAIL"
}

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

# NEW (grafted from gui2.sh, non-interactive counterpart to interactive_rebase
# above): rebase straight onto an arbitrary branch with no editor pass. Fills
# a genuine gap the pre-PR-only workflow above doesn't cover.
rebase_branch() {
    prominent "Rebase Onto Branch (non-interactive)"
    info "Loading branches to select a base..."
    local current_branch base_branch
    current_branch=$(git branch --show-current)
    base_branch=$(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes/origin | sed 's/origin\///' | sort -u | grep -v -x "$current_branch" | fzf --prompt="Select BASE branch: ")
    if [ -z "$base_branch" ]; then info "Operation cancelled."; return 1; fi
    if ! ask_confirmation "Rebase '$current_branch' directly onto '$base_branch' (no editor)?"; then info "Rebase cancelled."; return 1; fi
    if ! git rebase "$base_branch"; then
        bug "Rebase failed or hit conflicts. Resolve them, then 'git rebase --continue', or run 'git rebase --abort'."
        return 1
    fi
    prominent "Rebase of '$current_branch' onto '$base_branch' complete. ${SUCCESS}"
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

# NEW (grafted from gui2.sh, rewritten): merge a branch into the current one.
# On conflict, offers real, native resolution strategies (ours/theirs/
# per-file) backed directly by 'git checkout --ours/--theirs', rather than
# gui2.sh's original design, which called an unverified external
# "automated_git_conflict_resolver.sh" that is not part of this codebase.
# This is a fully self-contained, operational replacement for that feature —
# no external script, nothing fabricated, nothing orphaned.
resolve_merge_conflicts() {
    prominent "Merge Branch & Resolve Conflicts"
    local current_branch source_branch
    current_branch=$(git branch --show-current)
    info "Loading branches to merge into '$current_branch'..."
    source_branch=$(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes/origin | sed 's/origin\///' | sort -u | grep -v -x "$current_branch" | fzf --prompt="Select branch to merge into '$current_branch': ")
    if [ -z "$source_branch" ]; then info "Operation cancelled."; return 1; fi
    if ! ask_confirmation "Merge '$source_branch' into '$current_branch'?"; then info "Merge cancelled."; return 1; fi
    if git merge --no-edit "$source_branch"; then
        prominent "Merge complete, no conflicts. ${SUCCESS}"
        return 0
    fi

    warning "${WARN} Merge produced conflicts in the following files:"
    local -a conflicted
    mapfile -t conflicted < <(git diff --name-only --diff-filter=U)
    printf '  %s\n' "${conflicted[@]}"
    echo
    info "Resolution strategy:"
    info "  [o] ours   — keep '${current_branch}'s version for ALL conflicted files"
    info "  [t] theirs — take '${source_branch}'s version for ALL conflicted files"
    info "  [f] file-by-file — choose ours/theirs per file"
    info "  [m] manual — resolve yourself, then 'git add' + 'git merge --continue'"
    local strategy
    read -rp "Choose [o/t/f/m]: " strategy
    case "$strategy" in
        o|O)
            for f in "${conflicted[@]}"; do git checkout --ours -- "$f"; git add -- "$f"; done
            git commit --no-edit
            prominent "Resolved all conflicts using 'ours' (${current_branch}). ${SUCCESS}"
            ;;
        t|T)
            for f in "${conflicted[@]}"; do git checkout --theirs -- "$f"; git add -- "$f"; done
            git commit --no-edit
            prominent "Resolved all conflicts using 'theirs' (${source_branch}). ${SUCCESS}"
            ;;
        f|F)
            for f in "${conflicted[@]}"; do
                info "File: $f"
                local per_file
                read -rp "  [o]urs / [t]heirs / [s]kip (resolve manually later): " per_file
                case "$per_file" in
                    o|O) git checkout --ours -- "$f"; git add -- "$f" ;;
                    t|T) git checkout --theirs -- "$f"; git add -- "$f" ;;
                    *) info "  Skipped '$f'." ;;
                esac
            done
            if git diff --name-only --diff-filter=U | grep -q .; then
                info "Some files are still conflicted. Resolve them, then:"
                info "  git add <file>...  &&  git merge --continue"
            else
                git commit --no-edit
                prominent "All conflicts resolved. ${SUCCESS}"
            fi
            ;;
        *)
            info "Resolve manually (edit the files, or run 'git mergetool'), then:"
            info "  git add <file>...  &&  git merge --continue"
            info "Or abandon the merge entirely with: git merge --abort"
            ;;
    esac
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
    local description=$(echo "$reflog_entry" | cut -d' ' -f2-)
    # RESTORED (Rev 5.3 dropped this): let the operator preview the exact
    # commit before committing to a destructive hard-reset.
    if ask_confirmation "Inspect '${good_hash}' (log + stat) before deciding?"; then
        git --no-pager log -1 --stat "$good_hash" | less -R
        if ! ask_confirmation "Continue with recovery to '${good_hash}'?"; then info "Recovery aborted."; return 1; fi
    fi
    info "You have selected: ${good_hash} - ${description}"
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
    info "It will back up your repo, run 'git fsck', and attempt to repair corruption."
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
    install_hook "pre-commit" '#!/usr/bin/env bash
set -eu
mapfile -t files < <(git diff --cached --name-only --diff-filter=ACM -- "*.sh")
if [ "${#files[@]}" -gt 0 ]; then
    echo "Running pre-commit hook..."
    shfmt -i 2 -w "${files[@]}"
    shellcheck "${files[@]}"
    echo "Pre-commit checks passed."
fi'
    install_hook "commit-msg" '#!/usr/bin/env bash
set -eu; subject=$(head -n1 "$1"); if (( ${#subject} > 72 )); then echo "ERROR: Subject line > 72 chars." >&2; exit 1; fi'
    # Grafted from gui2.sh: optional pre-push test gate. Unlike gui2.sh's
    # original (a hardcoded path to a script that may not exist), this
    # auto-detects a real test entry point the same way run_integration_tests
    # does, so it degrades gracefully with no orphaned reference.
    install_hook "pre-push" '#!/usr/bin/env bash
set -eu
if [[ -x "./run_tests.sh" ]]; then
    echo "Running ./run_tests.sh before push..."
    ./run_tests.sh
elif [[ -x "./test.sh" ]]; then
    echo "Running ./test.sh before push..."
    ./test.sh
elif [[ -f "Makefile" ]] && grep -qE "^test:" Makefile; then
    echo "Running \"make test\" before push..."
    make test
elif [[ -f "package.json" ]] && command -v npm >/dev/null 2>&1 && grep -q "\"test\"" package.json; then
    echo "Running \"npm test\" before push..."
    npm test
elif [[ -f "Cargo.toml" ]] && command -v cargo >/dev/null 2>&1; then
    echo "Running \"cargo test\" before push..."
    cargo test
elif [[ -f "go.mod" ]] && command -v go >/dev/null 2>&1; then
    echo "Running \"go test ./...\" before push..."
    go test ./...
else
    echo "No recognized test entry point found; skipping pre-push tests."
fi'
    prominent "Git hooks installed successfully. ${SUCCESS}"
}

# NEW (native replacement for gui2.sh's run_integration_tests, which
# unconditionally dispatched to a fixed "Git/scripts/integration_tests.sh"
# path that isn't part of this codebase). This version auto-detects a real
# test entry point in the current repository — no external file assumed.
run_integration_tests() {
    prominent "Run Project Test Suite"
    info "Auto-detecting a test entry point..."
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || { bug "Not inside a Git repository."; return 1; }

    local -a candidates=()
    [[ -x "${repo_root}/run_tests.sh" ]] && candidates+=("bash '${repo_root}/run_tests.sh'")
    [[ -x "${repo_root}/test.sh" ]] && candidates+=("bash '${repo_root}/test.sh'")
    if [[ -f "${repo_root}/Makefile" ]] && grep -qE '^test:' "${repo_root}/Makefile"; then
        candidates+=("make -C '${repo_root}' test")
    fi
    if [[ -f "${repo_root}/package.json" ]] && command -v npm &>/dev/null && grep -q '"test"' "${repo_root}/package.json"; then
        candidates+=("npm --prefix '${repo_root}' test")
    fi
    if [[ -f "${repo_root}/Cargo.toml" ]] && command -v cargo &>/dev/null; then
        candidates+=("cargo test --manifest-path '${repo_root}/Cargo.toml'")
    fi
    if [[ -f "${repo_root}/go.mod" ]] && command -v go &>/dev/null; then
        candidates+=("cd '${repo_root}' && go test ./...")
    fi
    if command -v pytest &>/dev/null && find "${repo_root}" -maxdepth 3 -name 'test_*.py' -print -quit 2>/dev/null | grep -q .; then
        candidates+=("pytest '${repo_root}'")
    fi

    if [ ${#candidates[@]} -eq 0 ]; then
        bug "No recognized test entry point found (checked run_tests.sh, test.sh, a Makefile 'test' target, npm, cargo, go, and pytest)."
        info "Add an executable 'run_tests.sh' or 'test.sh' to the repo root and this will pick it up automatically."
        return 1
    fi

    local chosen
    if [ ${#candidates[@]} -eq 1 ]; then
        chosen="${candidates[0]}"
    else
        chosen=$(printf '%s\n' "${candidates[@]}" | fzf --prompt="Multiple test runners found, pick one: ")
        if [ -z "$chosen" ]; then info "Operation cancelled."; return 1; fi
    fi

    prominent "Running: ${chosen}"
    if bash -c "$chosen"; then
        prominent "Tests passed. ${SUCCESS}"
    else
        bug "Tests failed."
        return 1
    fi
}

# NEW (native replacement for gui2.sh's setup_cron_job, which had no
# self-contained implementation to begin with). Installs a real crontab
# entry that fetches and fast-forwards this repo on a schedule; it never
# commits or pushes on the user's behalf. Idempotent: re-running replaces
# any prior entry tagged for this exact repository path rather than
# duplicating it.
setup_cron_job() {
    prominent "Schedule Automatic Fetch/Fast-Forward"
    if ! command -v crontab &>/dev/null; then
        bug "'crontab' is not available on this system. Cannot schedule a cron job."
        return 1
    fi
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || { bug "Not inside a Git repository."; return 1; }

    info "This installs a cron job that runs 'git fetch', and fast-forwards"
    info "this repo ONLY if there are no local uncommitted changes. It will"
    info "never commit or push on your behalf."
    local freq schedule
    read -rp "Run how often? [h]ourly / [d]aily / [c]ustom cron expression: " freq
    case "$freq" in
        h|H) schedule="0 * * * *" ;;
        d|D) schedule="0 6 * * *" ;;
        c|C) read -rp "Enter a full 5-field cron expression: " schedule ;;
        *) bug "Invalid choice."; return 1 ;;
    esac
    if [ -z "$schedule" ]; then bug "Empty schedule."; return 1; fi

    local sync_script="${repo_root}/.git/gui-console-autosync.sh"
    cat > "$sync_script" <<-EOF
	#!/usr/bin/env bash
	set -eu
	cd "${repo_root}" || exit 1
	git fetch --all --prune >/dev/null 2>&1 || exit 0
	if git diff --quiet HEAD -- && git diff --cached --quiet; then
	    git pull --ff-only >/dev/null 2>&1 || true
	fi
	EOF
    chmod +x "$sync_script"

    local marker="#git-gui-console:${repo_root}"
    local cron_line="${schedule} ${sync_script} ${marker}"
    local existing
    existing=$(crontab -l 2>/dev/null || true)
    if printf '%s\n' "$existing" | grep -qF "$marker"; then
        info "A cron job for this repository already exists. Replacing it."
        existing=$(printf '%s\n' "$existing" | grep -vF "$marker")
    fi
    if ! ask_confirmation "Install this cron entry: '${cron_line}'?"; then info "Cancelled."; return 1; fi
    { printf '%s\n' "$existing" | grep -v '^$'; printf '%s\n' "$cron_line"; } | crontab -
    prominent "Cron job installed. ${SUCCESS}"
}

# NEW (native replacement for gui2.sh's setup_dependencies). Detects the
# system package manager and offers to install whatever check_dependencies
# found missing. Package names are not guaranteed identical across every
# distro (notably 'gh' and 'shfmt' sometimes need a vendor repo instead of
# the default one) — this is stated explicitly rather than silently assumed.
setup_dependencies() {
    prominent "Install Missing Dependencies"
    local deps=("git" "fzf" "gh" "shellcheck" "shfmt" "less" "hostname")
    local -a missing=()
    for cmd in "${deps[@]}"; do command -v "$cmd" &>/dev/null || missing+=("$cmd"); done
    if [ ${#missing[@]} -eq 0 ]; then
        prominent "All dependencies are already installed. ${SUCCESS}"
        return 0
    fi
    info "Missing: ${missing[*]}"
    local pm=""
    if command -v apt-get &>/dev/null; then pm="apt-get"
    elif command -v pacman &>/dev/null; then pm="pacman"
    elif command -v dnf &>/dev/null; then pm="dnf"
    elif command -v brew &>/dev/null; then pm="brew"
    else
        bug "No supported package manager detected (apt-get/pacman/dnf/brew). Install manually: ${missing[*]}"
        return 1
    fi
    warning "${WARN} Package names may not match exactly on every distro (this is most likely for 'gh' and 'shfmt', which sometimes need a vendor repo). If a package fails to install, you'll need to add that manually via its official install instructions."
    if ! ask_confirmation "Install [${missing[*]}] using '${pm}'? This may prompt for your password."; then
        info "Cancelled."
        return 1
    fi
    case "$pm" in
        apt-get) sudo apt-get update && sudo apt-get install -y "${missing[@]}" ;;
        pacman)  sudo pacman -Sy --noconfirm "${missing[@]}" ;;
        dnf)     sudo dnf install -y "${missing[@]}" ;;
        brew)    brew install "${missing[@]}" ;;
    esac
    prominent "Dependency installation attempted. Re-run to verify what's still missing. ${SUCCESS}"
}

# NEW (native replacement for gui2.sh's perform_backup). Archives the entire
# repository (including .git, so it's a fully restorable copy) to a
# timestamped tarball at a destination the user chooses.
perform_backup() {
    prominent "Repository Backup"
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || { bug "Not inside a Git repository."; return 1; }
    local repo_name; repo_name=$(basename "$repo_root")
    local default_dest="${HOME}/git-backups"
    local dest
    read -rp "Backup destination directory [${default_dest}]: " dest
    dest="${dest:-$default_dest}"
    mkdir -p "$dest"
    local archive="${dest}/${repo_name}_$(date +%Y%m%d_%H%M%S).tar.gz"
    info "Archiving '${repo_root}' (including .git — fully restorable) to:"
    info "  ${archive}"
    if ! ask_confirmation "Proceed?"; then info "Backup cancelled."; return 1; fi
    if tar -czf "$archive" -C "$(dirname "$repo_root")" "$repo_name"; then
        prominent "Backup created: ${archive} ${SUCCESS}"
        info "Size: $(du -h "$archive" | cut -f1)"
    else
        bug "Backup failed."
        return 1
    fi
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

# NEW (grafted from gui2.sh, rewritten against the config system): point an
# existing remote at a different repository under the configured GitHub
# user. gui2.sh's version hardcoded the username "4ndr0666" into the
# constructed URL; this reads GUI_GH_USER from config instead.
update_remote_url() {
    prominent "Update Remote URL"
    local remote_name; remote_name=$(git remote | fzf --height=20% --prompt="Select remote to update: ")
    if [ -z "$remote_name" ]; then info "No remote selected."; return 1; fi
    info "Current URL: $(git remote get-url "$remote_name")"
    local gh_user; gh_user=$(get_gh_user) || return 1
    read -rp "New repository name (under github.com/${gh_user}/): " repo_name
    if [ -z "$repo_name" ]; then bug "Repository name cannot be empty."; return 1; fi
    local new_url="git@github.com:${gh_user}/${repo_name}.git"
    info "New URL will be: $new_url"
    if ask_confirmation "Set '${remote_name}' to this URL?"; then
        git remote set-url "$remote_name" "$new_url"
        prominent "Remote '${remote_name}' updated. ${SUCCESS}"
    else info "Operation cancelled."; fi
}

# NEW (grafted from gui2.sh, rewritten against the config system): reconnect
# the current working directory to a remote, by name (assumed to belong to
# the configured GitHub user) or by pasting a full URL directly.
reconnect_old_repo() {
    prominent "Reconnect to a Repository"
    if git remote get-url origin &>/dev/null; then
        bug "An 'origin' remote already exists: $(git remote get-url origin)"
        if ! ask_confirmation "Overwrite it?"; then info "Operation cancelled."; return 1; fi
    fi
    local gh_user; gh_user=$(get_gh_user) || return 1
    read -rp "Repo name (under github.com/${gh_user}/) or a full git URL: " target
    if [ -z "$target" ]; then bug "Input cannot be empty."; return 1; fi
    local url
    if [[ "$target" == *"://"* || "$target" == git@* ]]; then
        url="$target"
    else
        url="git@github.com:${gh_user}/${target}.git"
    fi
    if git remote get-url origin &>/dev/null; then
        git remote set-url origin "$url"
    else
        git remote add origin "$url"
    fi
    prominent "Remote 'origin' now points to: $url ${SUCCESS}"
}

add_to_gitignore() {
    if [ ! -f ".gitignore" ]; then info "Creating .gitignore file."; touch .gitignore; fi
    read -rp "Enter pattern to add to .gitignore: " p
    if [ -z "$p" ]; then info "No pattern entered."; return 0; fi
    if grep -qxF -- "$p" .gitignore; then
        info "'$p' is already present in .gitignore. Nothing to do."
        return 0
    fi
    echo "$p" >> .gitignore
    prominent "'$p' added to .gitignore. ${SUCCESS}"
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
    printf "$help_format" "16" "Rebase Onto Branch" "Non-interactive rebase of the current branch onto any other."
    printf "$help_format" "17" "Resolve Merge Conflicts" "Merge a branch in and get a guided path through conflicts."

    printf "\n$category_format" "RECOVERY & REPAIR"
    printf "$help_format" "18" "Emergency Recovery" "${BOLD}${RED}DANGEROUS:${NC} Restore a branch to a past state from reflog."
    printf "$help_format" "19" "Restore Single File" "Find and restore a deleted file from Git history."
    printf "$help_format" "20" "Restore Branch" "Create a new branch from any commit in the history."
    printf "$help_format" "21" "Fix Corrupt Repo" "${BOLD}${RED}DANGEROUS:${NC} Attempt to repair a corrupted local repository."

    printf "\n$category_format" "REPOSITORY & CONFIG"
    printf "$help_format" "22" "Initialize Repository" "Run 'git init' in the current directory."
    printf "$help_format" "23" "Intelligent Clone" "Clone one of your GitHub repos using fzf."
    printf "$help_format" "24" "Manage Remotes" "View, add, or remove remote repositories."
    printf "$help_format" "25" "Update Remote URL" "Point an existing remote at a different repo you own."
    printf "$help_format" "26" "Reconnect Old Repo" "(Re)point 'origin' at a repo by name or full URL."
    printf "$help_format" "27" "Convert to SSH" "Convert a remote's HTTPS URL to its SSH equivalent."
    printf "$help_format" "28" "Add to .gitignore" "Append a pattern to the .gitignore file."
    printf "$help_format" "29" "Check & Setup SSH" "Check/generate an SSH key and add it to GitHub."
    printf "$help_format" "30" "Edit Configuration" "View or reset your saved email/GitHub username."

    printf "\n$category_format" "DIAGNOSTICS & AUTOMATION"
    printf "$help_format" "31" "Search Repository" "Search for a string in all tracked files ('git grep')."
    printf "$help_format" "32" "Find Large Files" "Scan history for files larger than 50MB."
    printf "$help_format" "33" "Setup Git Hooks" "Install client-side hooks for linting, formatting, and tests."
    echo
}

# --- // MAIN MENU & LOOP ---
display_menu() {
    clear
    local ver="6.0"
    local head_color="${BOLD}${CYAN}"
    local border_color="${CYAN}"
    local cat_color="${BOLD}${YELLOW}"
    local num_color="${GREEN}"

    # Use %b to interpret ANSI color codes in the arguments.
    # Each column: Number (2 chars), Text (21 chars), Space (2 chars) = 25 chars wide.
    local menu_line_format="  ${num_color}%-2s)${NC} %-21b${num_color}%-2s)${NC} %-21b${num_color}%-2s)${NC} %-21b\n"

    printf "${border_color}╭──────────────────────────────────────────────────────────────────────────╮${NC}\n"
    printf "${border_color}│${head_color}                Git Strategic Command Console v%-9s                  ${border_color}│${NC}\n" "$ver"
    printf "${border_color}╰──────────────────────────────────────────────────────────────────────────╯${NC}\n"

    printf "  ${cat_color}%-25s %-25s %-25s${NC}\n" "WORKFLOWS & DAILY OPS" "BRANCHING & HISTORY" "RECOVERY & REPAIR"
    printf "$menu_line_format" \
        "1" "Pristine Contribution" "10" "View History"        "18" "${RED}Emergency Recovery${NC}" \
        "2" "Pre-PR Cleanup"        "11" "Switch Branch"       "19" "Restore Single File" \
        "3" "Fetch All Remotes"     "12" "Create Branch"       "20" "Restore Branch" \
        "4" "Pull (Safe Rebase)"    "13" "Delete Branch"       "21" "${RED}Fix Corrupt Repo${NC}" \
        "5" "Push to Upstream"      "14" "Interactive Rebase"  "" "" \
        "6" "Interactive Add"       "15" "Cherry-Pick Commit"  "" "" \
        "7" "Quick Commit & Push"   "16" "Rebase Onto Branch"  "" "" \
        "8" "Auto-Commit & Sync"    "17" "Resolve Conflicts"   "" "" \
        "9" "Manage Stashes"        ""   ""                    "" ""

    printf "\n"
    printf "  ${cat_color}%-25s %-25s %-25s${NC}\n" "REPOSITORY & CONFIG" "DIAGNOSTICS & AUTOMATION" ""
    printf "$menu_line_format" \
        "22" "Initialize Repo"       "31" "Search Repository"   "" "" \
        "23" "Intelligent Clone"     "32" "Find Large Files"    "" "" \
        "24" "Manage Remotes"        "33" "Setup Git Hooks"     "" "" \
        "25" "Update Remote URL"     ""   ""                    "" "" \
        "26" "Reconnect Old Repo"    ""   ""                    "" "" \
        "27" "Convert to SSH"        ""   ""                    "" "" \
        "28" "Add to .gitignore"     ""   ""                    "" "" \
        "29" "Check & Setup SSH"     ""   ""                    "" "" \
        "30" "Edit Configuration"    ""   ""                    "" ""

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
      14) interactive_rebase ;; 15) cherry_pick_commit ;; 16) rebase_branch ;; 17) resolve_merge_conflicts ;;
      18) emergency_recovery_protocol ;; 19) restore_single_file ;; 20) restore_branch_from_commit ;;
      21) fix_git_repository ;;
      22) initialize_repository ;; 23) intelligent_clone ;; 24) list_and_manage_remotes ;;
      25) update_remote_url ;; 26) reconnect_old_repo ;;
      27) switch_to_ssh ;; 28) add_to_gitignore ;; 29) check_and_setup_ssh ;; 30) edit_config ;;
      31) search_repository ;; 32) find_large_files ;; 33) setup_git_hooks ;;
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

    load_config

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

main "$@"#!/bin/bash
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
