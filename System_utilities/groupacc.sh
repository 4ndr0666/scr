#!/bin/bash
set -e

# Auto-escalate to root if not already running as root
if [ "$(id -u)" -ne 0 ]; then
  sudo "$0" "$@"
  exit $?
fi

# Constants
LOG_FILE="/tmp/groupacc.log"
TARGET_USER="andro"
TARGET_GROUP="root"

# Function to sanitize path
sanitize_path() {
    local path="$1"
    echo "${path%/}"
}

# Function to validate if a directory or file exists
validate_directory() {
    local directory="$1"
    if [[ ! -d "$directory" && ! -f "$directory" ]]; then
        echo "Error: '$directory' does not exist or is not a valid directory/file."
        exit 1
    fi
}

# Function to display the menu
display_menu() {
  printf "Menu:\n\
  1. Own it\n\
  2. Compaudit\n\
  3. Getfacl\n\
  4. Change Directory/File\n\
  5. Exit\n\
Enter your choice: "
}

# Check and validate the input path
if [ "$1" ]; then
    directory=$(sanitize_path "$1")
    validate_directory "$directory"
else
    directory=$PWD
fi

# Function to change ownership and permissions to be more restrictive
compaudit() {
  local directory="$1"

  if ! sudo chown "$TARGET_USER:$TARGET_GROUP" -R "$directory"; then
    echo "Failed to change ownership."
    exit 1
  fi

  if ! sudo chmod og-w -R "$directory"; then
    echo "Failed to change permissions."
    exit 1
  fi

  echo "Directory secured."
  echo "Compaudit completed on $directory" | tee -a "$LOG_FILE"
}

# Function to get directory ACL
get_directory_acl() {
    local target="$1"
    echo "Getting ACL of $target..."
    if sudo getfacl "$target"; then
        echo "ACL of $target displayed above."
    else
        echo "Failed to retrieve ACL for $target."
        exit 1
    fi
    echo "Getfacl completed on $target" | tee -a "$LOG_FILE"
}

# Function to change ownership and permissions to be more permissive
ownit() {
  local directory="$1"

  if ! sudo chown "$TARGET_USER:$TARGET_GROUP" -R "$directory"; then
    echo "Failed to change ownership."
    exit 1
  fi

  if ! sudo chmod ug+rwx -R "$directory"; then
    echo "Failed to change permissions."
    exit 1
  fi

  echo "You own it!"
  echo "Ownit completed on $directory" | tee -a "$LOG_FILE"
}

# Main loop for the menu
while true; do
  display_menu
  read -r choice

  case $choice in
    1) ownit "$directory" ;;
    2) compaudit "$directory" ;;
    3) get_directory_acl "$directory" ;;
    4) 
       echo "Enter the new directory or file path:"
       read -e new_directory
       directory=$(sanitize_path "$new_directory")
       validate_directory "$directory"
       ;;
    5) echo "Exiting..."; exit 0 ;;
    *) echo "Invalid choice. Please try again." ;;
  esac
  echo
done
