#!/bin/bash

# Create log directory if it doesn't exist
log_dir="$HOME/.local/share/dependencies"
mkdir -p $log_dir || { echo "Failed to create log directory"; exit 1; }

# Log file to store installed dependencies
log_file="$log_dir/dependency_log_$(date +%Y%m%d%H%M%S).log"

# Function to display a progressively expanding progress bar in cyan
display_progress_bar() {
  echo -ne "\033[36mProcessing: "
  for i in $(seq 1 50); do # Adjust 50 to the desired length of the progress bar
    echo -ne "="
    sleep 0.1
  done
  echo -e "\033[38;5;114m Done\033[0m! ✨ 🌟 ✨"
}

# Function to check if a package is installed
is_installed() {
  paru -Q $1 &> /dev/null || { echo "Error: Failed to query package $1"; return 1; }
}

# Function to get the repository of a package
get_repo() {
  repo=$(paru -Si $1 | grep "Repository" | awk '{print $3}') || { echo "Error: Failed to get repository for $1"; return 1; }
  echo $repo
}

# Function to recursively find and install missing dependencies using pactree
install_missing_deps() {
  local pkg=$1
  deps=$(pactree -l $pkg) || { echo "Error: Failed to get dependencies for $pkg"; return 1; }
  for dep in $deps; do
    if ! is_installed $dep; then
      echo "Missing dependency found: $dep"
      read -p "Do you want to install it? (y/n): " choice
      if [ "$choice" == "y" ]; then
        repo=$(get_repo $dep)
        paru -S $dep || { echo "Error: Failed to install $dep"; return 1; }
        echo "Successfully installed $dep from $repo"
        echo "$repo: $dep installed on $(date)" >> $log_file
        install_missing_deps $dep
      else
        echo "$dep skipped"
        echo "$dep skipped" >> $log_file
      fi
    fi
  done
}

# Function to rollback installed packages
rollback() {
  tac $log_file | while read -r line; do
    pkg=$(echo $line | awk '{print $2}')
    read -p "Do you want to uninstall $pkg? (y/n): " choice
    if [ "$choice" == "y" ]; then
      paru -Rns $pkg || { echo "Error: Failed to uninstall $pkg"; return 1; }
      echo "Successfully uninstalled $pkg"
    fi
  done
}

# Main function
main() {
  display_progress_bar
  if [ "$1" == "rollback" ]; then
    rollback
  else
    pkg_name=$1
    if ! is_installed $pkg_name; then
      echo "The package $pkg_name is not installed. Exiting."
      exit 1
    fi
    install_missing_deps $pkg_name
    echo "Process complete. Check $log_file for a log of changes."
  fi
}

main $1
