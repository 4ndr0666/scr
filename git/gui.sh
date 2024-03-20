#!/usr/bin/env bash

# Check and generate SSH key
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
    gh auth login
    gh ssh-key add "$ssh_key.pub"
  fi
}

# List current remotes and manage them
list_and_manage_remotes() {
  echo "Current Git remotes:"
  git remote -v
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

# Update remote URL to a new one
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

# Fetch from remote
fetch_from_remote() {
  echo "Fetching updates from remote..."
  git fetch origin
  echo "Fetch complete."
}

# Pull from remote
pull_from_remote() {
  local current_branch=$(git branch --show-current)
  echo "Pulling updates from remote for branch '$current_branch'..."
  git pull origin "$current_branch"
  echo "Pull complete."
}

# Push to remote
push_to_remote() {
  local current_branch=$(git branch --show-current)
  echo "Pushing local branch '$current_branch' to remote..."
  git push -u origin "$current_branch"
  echo "Push complete."
}

# List branches
list_branches() {
  echo "Available branches:"
  git branch
}

# Switch branch
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

# Create new branch
create_new_branch() {
  echo "Enter new branch name:"
  read -r new_branch
  git checkout -b "$new_branch"
  echo "Branch '$new_branch' created and checked out."
}

# Delete branch
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

# Reconnect old repo
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

# Manage stashes
manage_stashes() {
  echo "1. Stash Changes"
  echo "2. List Stashes"
  echo "3. Apply Latest Stash"
  echo "4. Pop Stash"
  echo "5. Clear Stashes"
  echo "Enter your choice (1-5):"
  read -r stash_choice

  case "$stash_choice" in
    1)
      echo "Enter a message for the stash (optional):"
      read -r message
      git stash push -m "$message"
      echo "Changes stashed."
      ;;
    2)
      git stash list
      ;;
    3)
      git stash apply
      echo "Stash applied."
      ;;
    4)
      git stash pop
      echo "Stash applied and removed."
      ;;
    5)
      git stash clear
      echo "All stashes cleared."
      ;;
    *)
      echo "Invalid choice!"
      ;;
  esac
}

# Restore branch from commit history
restore_branch() {
  # Assuming the Python script is named 'restore_branch.py' and is in the same directory
  python3 ~/.oh-my-zsh/custom/plugins/myfunctions/restore_branch.py
}

# Main Function
gui() {
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
  echo "Enter your choice (1-14):"
  read -r choice

  case "$choice" in
    1)  check_and_setup_ssh ;;
    2)  list_and_manage_remotes ;;
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
    *)  echo "Invalid choice!" ;;
  esac
}



}
