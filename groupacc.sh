#!/bin/bash

# Function to change ownership and permissions
change_ownership_permissions() {
  local directory="$1"

  # Change ownership to root:wheel recursively
  if ! sudo chown root:wheel -R "$directory"; then
    echo "Failed to change ownership."
    exit 1
  fi

  # Change permissions to user and group read, write, and execute recursively
  if ! sudo chmod ug+rwx -R "$directory"; then
    echo "Failed to change permissions."
    exit 1
  fi

  echo "Ownership and permissions updated successfully."
}

# Function to compare package permissions against current permissions
compare_package_permissions() {
  echo "Checking package permissions against current permissions..."
  sudo pacman -Qlq | while read -r file; do
    if [ -e "$file" ]; then
      if [ "$(stat -c "%a" "$file")" != "$(sudo pacman -Qkk "$file" | awk '{print $2}')" ]; then
        echo "Mismatch: $file"
      fi
    fi
  done
}

# Function to display the menu
display_menu() {
  printf "Menu:
  1. Change ownership and permissions of a directory
  2. Compare package permissions against current permissions
  3. Get ACL of the last updated directory
  4. Exit

Enter your choice: "
}

# Function to get ACL of the last updated directory
get_directory_acl() {
  local directory="$1"

  echo "Getting ACL of the directory..."
  sudo getfacl -R "$directory"
}

# Main script
directory="$1"

if [ "$(id -u)" != "0" ]; then
  echo "This script requires escalated privileges. Please run with sudo."
  exit 1
fi

while true; do
  display_menu
  read -r choice

  case $choice in
    1)
      if [ -z "$directory" ]; then
        echo "Enter the directory path:"
        read -r directory
      fi

      if [ -d "$directory" ]; then
        change_ownership_permissions "$directory"
        display_menu
      else
        echo "Directory does not exist."
      fi
      ;;
    2)
      compare_package_permissions
      ;;
    3)
      if [ -z "$directory" ]; then
        echo "Enter the directory path:"
        read -r directory
      fi

      if [ -d "$directory" ]; then
        get_directory_acl "$directory"
      else
        echo "Directory does not exist."
      fi
      ;;
    4)
      echo "Exiting..."
      exit 0
      ;;
    *)
      echo "Invalid choice. Please try again."
      ;;
  esac

  echo
done
