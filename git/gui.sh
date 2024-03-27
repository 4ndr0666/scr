#!/bin/bash

# --- // GUI.SH // ========
#File: gui.sh
#Author: 4ndr0666
#Edited: 3-20-2024

# Helper Functions
check_and_setup_ssh() {
  local ssh_key="${HOME}/.ssh/id_ed25519"

  if [ -f "$ssh_key" ]; then
    echo "SSH key exists."
  else
    echo "SSH key not found. Creating one now..."
    ssh-keygen -t ed25519 -C "your_email@example.com" -f "$ssh_key"
    eval "$(ssh-agent -s)"
    ssh-add "$ssh_key"

    echo "Uploading the SSH key to GitHub..."
    # Assuming GitHub CLI is installed and configured
    gh auth login
    gh ssh-key add "$ssh_key.pub"
  fi
}

list_and_manage_remotes() {
  echo "Current Git remotes:"
  git remote -v

  # List remotes and ask the user if they want to remove any
  echo "Would you like to remove any remotes? (yes/no):"
  read -r response

  if [[ "$response" =~ ^[Yy](es)?$ ]]; then
    echo "Enter the name of the remote to remove (leave blank to cancel):"
    read -r remote_to_remove

    if [[ -n "$remote_to_remove" ]]; then
      if git remote | grep -q "^$remote_to_remove$"; then
        git remote remove "$remote_to_remove"
        echo "Remote '$remote_to_remove' has been removed."
      else
        echo "Remote '$remote_to_remove' not found."
      fi
    else
      echo "No remotes removed."
    fi
  else
    echo "No changes made to remotes."
  fi
}

switch_to_ssh() {
  local old_url new_url

  # Get a list of all remotes and use fzf to select one
  local remote_name=$(git remote | fzf --height=10 --prompt="Select a remote: ")

  # Check if a remote was selected
  if [[ -z "$remote_name" ]]; then
    echo "No remote selected."
    return
  fi

  old_url=$(git remote get-url "$remote_name")

  # Check if the current URL is already using SSH
  if [[ "$old_url" == git@github.com:* ]]; then
    echo "The remote '$remote_name' is already using SSH."
    return
  fi

  # Extract the username and repository from the old URL
  local user_repo=${old_url#*github.com/}

  # Remove any trailing ".git"
  user_repo=${user_repo%.git}

  new_url="git@github.com:$user_repo.git"

  git remote set-url "$remote_name" "$new_url"

  echo "Switched '$remote_name' to use SSH: $new_url"
}

update_remote_url() {
  local repo_base="https://www.github.com/4ndr0666/"
  local repos=$(gh repo list 4ndr0666 -L 100 --json name -q '.[].name')

  echo "Enter the repository name:"
  local repo_name
  repo_name=$(echo "$repos" | fzf --height=10 --prompt="Select a repository: ")

  local new_url="${repo_base}${repo_name}.git"
  git remote set-url origin "$new_url"
  echo "Remote URL updated to $new_url"
}

fetch_from_remote() {
  echo "Fetching updates from remote..."
  git fetch origin
  echo "Fetch complete."
}

pull_from_remote() {
  local current_branch=$(git branch --show-current)
  echo "Pulling updates from remote for branch '$current_branch'..."
  git pull origin "$current_branch"
  echo "Pull complete."
}

push_to_remote() {
  local current_branch=$(git branch --show-current)
  echo "Pushing local branch '$current_branch' to remote..."
  git push -u origin "$current_branch"
  echo "Push complete."
}

list_branches() {
  echo "Available branches:"
  git branch
}

switch_branch() {
  echo "Enter branch name to switch to:"
  read -r branch_name

  if git branch --list "$branch_name" > /dev/null; then
    git checkout "$branch_name"
    echo "Switched to branch '$branch_name'."
  else
    echo "Branch '$branch_name' does not exist."
  fi
}

create_new_branch() {
  echo "Enter new branch name:"
  read -r new_branch
  git checkout -b "$new_branch"
  echo "Branch '$new_branch' created and checked out."
}

delete_branch() {
  echo "Enter branch name to delete:"
  read -r del_branch

  if git branch --list "$del_branch" > /dev/null; then
    git branch -d "$del_branch"
    echo "Branch '$del_branch' deleted."
  else
    echo "Branch '$del_branch' does not exist."
  fi
}

reconnect_old_repo() {
  echo "Do you know the remote URL or name? (URL/Name):"
  read -r reconnect_type
  if [ "$reconnect_type" == "URL" ]; then
    echo "Enter the remote URL:"
    read -r reconnect_url
    git remote add origin "$reconnect_url"
  elif [ "$reconnect_type" == "Name" ]; then
    echo "Enter the remote name:"
    read -r reconnect_name
    git remote add origin "git@github.com:$reconnect_name.git"
  else
    echo "Invalid option. Exiting..."
    return 1
  fi
}
manage_stashes() {
  echo "1. Stash Changes"
  echo "2. List Stashes"
  echo "3. Apply Latest Stash"
  echo "4. Pop Latest Stash"
  echo "5. Clear All Stashes"
  echo "6. Show Stash Contents"
  echo "7. Apply Specific Stash"
  echo "8. Drop Specific Stash"
  echo "Enter your choice (1-8):"
  read -r stash_choice

  # Reusing your color and echo functions
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

  case "$stash_choice" in
    1)
      echo "Enter a message for the stash (optional):"
      read -r message
      git stash push -m "$message"
      prominent "Changes stashed. ${SUCCESS}"
      ;;
    2)
      git stash list | while IFS= read -r line; do prominent "$line"; done
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
      echo "Enter stash @{number} to show contents (e.g., stash@{0}):"
      read -r stash_number
      git stash show -p "$stash_number" | while IFS= read -r line; do prominent "$line"; done
      ;;
    7)
      echo "Enter stash @{number} to apply (e.g., stash@{0}):"
      read -r stash_number
      git stash apply "$stash_number"
      prominent "Specific stash applied. ${SUCCESS}"
      ;;
    8)
      echo "Enter stash @{number} to drop (e.g., stash@{0}):"
      read -r stash_number
      git stash drop "$stash_number"
      prominent "Specific stash dropped. ${SUCCESS}"
      ;;
    *)
      bug "Invalid choice! ${FAILURE}"
      ;;
  esac
}

merge_branches() {
  # Merging is useful when you want to combine the changes from one branch into another.
  echo "Enter the name of the branch you want to merge into the current branch:"
  read -r branch_to_merge

  # Check if the specified branch exists
  if git branch --list "$branch_to_merge" > /dev/null; then
    # Merge the specified branch into the current branch
    git merge "$branch_to_merge"
    echo "Branch '$branch_to_merge' merged into $(git branch --show-current)."
  else
    echo "Branch '$branch_to_merge' does not exist."
  fi
}

view_commit_history() {
  # Viewing the commit history can help you understand the changes made over time.
  echo "Showing commit history for the current branch:"
  # --oneline condenses each commit to a single line, --graph shows a text-based graph of the commits
  git log --oneline --graph
}

rebase_branch() {
  # Rebasing is a way to move or combine a sequence of commits to a new base commit.
  echo "Enter the branch you want to rebase onto:"
  read -r base_branch

  # Check if the base branch exists
  if git branch --list "$base_branch" > /dev/null; then
    # Rebase the current branch onto the specified base branch
    git rebase "$base_branch"
    echo "Current branch rebased onto '$base_branch'."
  else
    echo "Branch '$base_branch' does not exist."
  fi
}

resolve_merge_conflicts() {
  # Merge conflicts happen when Git can't automatically resolve differences in code between two commits.
  # Git will mark the conflicts in the problematic files.
  echo "Attempting to start a merge..."
  git merge

  # Check if there are merge conflicts
  if git ls-files -u | grep -q "^"; then
    echo "There are merge conflicts. Manually resolve them and then run 'git merge --continue'"
  else
    echo "No merge conflicts detected."
  fi
}

cherry_pick_commits() {
  # Cherry-picking allows you to pick a specific commit from one branch and apply it onto another.
  echo "Enter the commit hash you want to cherry-pick:"
  read -r commit_hash

  # Apply the specified commit to the current branch
  git cherry-pick "$commit_hash"
  echo "Commit '$commit_hash' cherry-picked onto $(git branch --show-current)."

  echo "Available options:"
  echo "1. Merge Branches - Combine changes from one branch into another."
  echo "2. View Commit History - Show the commit history of the current branch."
  echo "3. Rebase Branch - Move or combine commits to a new base commit."
  echo "4. Resolve Merge Conflicts - Handle conflicts when Git can't automatically merge."
  echo "5. Cherry-Pick Commits - Apply specific commits from one branch to another."
  # ... other options ...
  echo "Enter your choice:"
  read -r choice

  case "$choice" in
    1)
      merge_branches
      ;;
    2)
      view_commit_history
      ;;
    3)
      rebase_branch
      ;;
    4)
      resolve_merge_conflicts
      ;;
    5)
      cherry_pick_commits
      ;;
    # ... other cases ...
  esac
}

# --- // RESTORE_BRANCH:
restore_branch() {
  # Assuming the Python script is named 'restore_branch.py' and is in the same directory
  python3  ~/.config/shell/functions/restore_branch.py
}

revert_to_previous_version() {
    # Display recent actions from the reflog
    echo "Recent actions in the repository:"
    git reflog -10

    # Ask the user to input the reflog entry number
    echo "Enter the reflog entry number you want to revert to (e.g., HEAD@{2}):"
    read -r reflog_entry

    # Confirm the choice
    echo "Do you want to revert to this point? This action is irreversible. (yes/no):"
    read -r confirmation

    if [[ "$confirmation" == "yes" ]]; then
        # Revert to the chosen reflog entry
        if git reset --hard "$reflog_entry"; then
            echo "Reverted to $reflog_entry."
        else
            echo "Failed to revert. Make sure the reflog entry number is correct."
            return 1
        fi
    else
        echo "Revert action canceled."
        return 0
    fi
}

# Main Function
gui() {
  local choice=""
  while true; do
    echo "1. Check and generate SSH key"
    echo "2. List current remotes"
    echo "3. Update remote URL"
    echo "4. Switch from HTTPS to SSH"
    echo "5. Fetch from remote"
    echo "6. Pull from remote"
    echo "7. Push to remote"
    echo "8. List branches"
    echo "9. Switch branch"
    echo "10. Create new branch"
    echo "11. Delete branch"
    echo "12. Reconnect old repo"
    echo "13. Manage stashes"
    echo "14. Restore Branch from Commit History"
    echo "15. Exit"
    echo "Enter your choice (1-15):"
    read -r choice

    case "$choice" in
      1)  check_and_setup_ssh ;;
      2)  
          list_and_manage_remotes
          ;;
      3)  update_remote_url ;;
      4)  switch_to_ssh ;;
      5)  fetch_from_remote ;;
      6)  pull_from_remote ;;
      7)  push_to_remote ;;
      8)  list_branches ;;
      9)  switch_branch ;;
      10) create_new_branch ;;
      11) delete_branch ;;
      12) reconnect_old_repo ;;
      13) manage_stashes ;;
      14) restore_branch ;;
      15) echo "Exiting..."
          break
          ;;
      *)  echo "Invalid choice!" ;;
    esac
  done
}



