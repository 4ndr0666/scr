#!/bin/bash

# Helper function to expand user path
expand_user_path() {
    return os.path.expanduser(os.path.expandvars(path))
}

check_and_setup_ssh() {
  local ssh_key="${HOME}/.ssh/id_ed25519"

  if [ -f "$ssh_key" ]; then
    echo "SSH key exists at ${ssh_key}."
  else
    echo "SSH key not found at ${ssh_key}."
    echo -n "Enter your email for the SSH key: "
    read -r user_email
    ssh-keygen -t ed25519 -C "$user_email" -f "$ssh_key" -N ""
    echo "SSH key has been created."

    # Start the ssh-agent in the background.
    eval "$(ssh-agent -s)"
    ssh-add "$ssh_key"

    # Check if GitHub CLI is installed before attempting to upload the SSH key.
    if command -v gh > /dev/null; then
      echo "Uploading the SSH key to GitHub..."
      gh ssh-key add "$ssh_key.pub" -t "$user_email"
    else
      echo "GitHub CLI not found. Please manually upload the SSH key to GitHub."
    fi
  fi
}

list_and_manage_remotes() {
  # Ensure we are in a Git repository
  if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "This command must be run inside a Git repository."
    return 1
  fi

  echo "Current Git remotes:"
  git remote -v

  echo "Would you like to remove any remotes? (yes/no):"
  read -r response

  if [[ "$response" =~ ^[Yy](es)?$ ]]; then
    echo "Enter the name of the remote to remove (leave blank to cancel):"
    read -r remote_to_remove

    if [[ -z "$remote_to_remove" ]]; then
      echo "No remotes removed."
      return
    fi

    if git remote | grep -qw "^$remote_to_remove$"; then
      git remote remove "$remote_to_remove"
      echo "Remote '$remote_to_remove' has been removed."
    else
      echo "Remote '$remote_to_remove' not found."
    fi
  else
    echo "No changes made to remotes."
  fi
}
