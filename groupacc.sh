#!/bin/bash

# ---- // AUTO-ESCALATE:
if [ "$(id -u)" -ne 0 ]; then
  sudo "$0" "$@"
  exit $?
fi

# --- // SANITIZE PATH:
sanitize_path() {
    local path="$1"
    # Remove trailing slashes
    echo "${path%/}"
}

# --- // VALIDATE_DIR:
validate_directory() {
    local directory="$1"
    if [[ ! -d "$directory" && ! -f "$directory" ]]; then
        echo "Error: '$directory' does not exist or is not a valid directory/file."
        exit 1
    fi
}

# --- // MENU:
display_menu() {
  printf "Menu:\n\
  1. Own it\n\
  2. Compaudit\n\
  3. Getfacl\n\
  4. Change Directory/File\n\
  5. Exit\n\
Enter your choice: "
}

# Normalize and validate the input path
if [ "$1" ]; then
    directory=$(sanitize_path "$1")
    validate_directory "$directory"
else
    directory=$PWD
fi

# --- // CHMOD U+RWX:
compaudit() {
  local directory="$1"

  if ! sudo chown andro:root -R "$directory"; then
    echo "Failed to change ownership."
    exit 1
  fi

  if ! sudo chmod og-w -R "$directory"; then
    echo "Failed to change permissions."
    exit 1
  fi

  echo "Directory secured."
}

# --- // GETFACL:
get_directory_acl() {
    local target="$1"
    echo "Getting ACL of $target..."
    sudo getfacl "$target"
    if [ $? -eq 0 ]; then
        echo "ACL of $target displayed above."
    else
        echo "Failed to retrieve ACL for $target."
    fi
}

# --- // CHMOD UG+RWX:
ownit() {
  local directory="$1"

  if ! sudo chown andro:root -R "$directory"; then
    echo "Failed to change ownership."
    exit 1
  fi

  if ! sudo chmod ug+rwx -R "$directory"; then
    echo "Failed to change permissions."
    exit 1
  fi

  echo "You own it!"
}

set -e

# --- // MENU_LOOP:
while true; do
  display_menu
  read -r choice

  case $choice in
    1)
      ownit "$directory"
      ;;
    2)
      compaudit "$directory"
      ;;
    3)
      get_directory_acl "$directory"
      ;;
    4)
      echo "Enter the new directory or file path:"
      read -e new_directory
      directory=$(sanitize_path "$new_directory")
      validate_directory "$directory"
      ;;
    5)
      echo "Exiting..."
      exit 0
      ;;
    *)
      echo "Invalid choice. Please try again."
      ;;
  esac

  echo
done
