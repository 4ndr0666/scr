#!/bin/bash

# Create log directory if it doesn't exist
log_dir="$HOME/.local/share/dependencies"
mkdir -p "$log_dir" || exit_with_error "Failed to create log directory"

# Log file to store installed dependencies
log_file="$log_dir/dependency_log_$(date +%Y%m%d%H%M%S).log"

# Unified error handling
exit_with_error() {
  echo "$1" | tee -a "$log_file"
  exit 1
}

# Function to display a progressively expanding progress bar in cyan
display_progress_bar() {
  printf "\033[36mProcessing: "
  for i in $(seq 1 50); do
    printf "="
    sleep 0.1
  done
  printf "\033[38;5;114m Done\033[0m! ✨ 🌟 ✨\n"
}

# Function to check if a package is installed
is_installed() {
  local pkg="$1"
  paru -Q "$pkg" &> /dev/null || exit_with_error "Error: Failed to query package $pkg"
}

# Function to get the repository of a package
get_repo() {
  local pkg="$1"
  paru -Si "$pkg" | grep "Repository" | awk '{print $3}' || exit_with_error "Error: Failed to get repository for $pkg"
}

# Function to recursively find and install missing dependencies using pactree
install_missing_deps() {
  local pkg="$1"
  local deps=$(pactree -l "$pkg") || exit_with_error "Error: Failed to get dependencies for $pkg"
  
  for dep in $deps; do
    if ! is_installed "$dep"; then
      echo "Missing dependency found: $dep" | tee -a "$log_file"
      local repo=$(get_repo "$dep")
      paru -S "$dep" || exit_with_error "Error: Failed to install $dep"
      echo "Successfully installed $dep from $repo" | tee -a "$log_file"
      install_missing_deps "$dep"
    fi
  done
}

# Main function
main() {
  display_progress_bar
  local pkg_name="$1"
  
  if [ "$pkg_name" == "rollback" ]; then
    rollback
  elif ! is_installed "$pkg_name"; then
    exit_with_error "The package $pkg_name is not installed. Exiting."
  else
    install_missing_deps "$pkg_name"
    echo "Process complete. Check $log_file for a log of changes."
  fi
}

main "$1"
