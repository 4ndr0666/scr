#!/bin/bash

# Function to install jq if not already installed
install_jq() {
  if ! command -v jq &> /dev/null; then
    echo "jq not found. Installing jq..."
    sudo pacman -S jq
  else
    echo "jq is already installed."
  fi
}

# Function to list available profiles
list_profiles() {
  echo "Available profiles:"
  profiles=()
  i=1
  for profile in ~/.config/BraveSoftware/Brave-Browser/*/; do
    profile_name=$(basename "$profile")
    echo "$i. $profile_name"
    profiles+=("$profile_name")
    ((i++))
  done
}

# Function to select profile
select_profile() {
  list_profiles
  read -p "Select a profile number: " profile_number
  if (( profile_number > 0 && profile_number <= ${#profiles[@]} )); then
    selected_profile="${profiles[$((profile_number - 1))]}"
    echo "Selected profile: $selected_profile"
  else
    echo "Invalid selection. Please try again."
    select_profile
  fi
}

# Function to backup original preferences
backup_preferences() {
  echo "Backing up original preferences..."
  mkdir -p ~/.cache/bravesoftware
  cp ~/.config/BraveSoftware/Brave-Browser/$selected_profile/Preferences ~/.cache/bravesoftware/Preferences.backup
  echo "Backup completed: ~/.cache/bravesoftware/Preferences.backup"
}

# Function to restore backup preferences
restore_backup() {
  if [ -f ~/.cache/bravesoftware/Preferences.backup ]; then
    echo "Restoring backup preferences..."
    cp ~/.cache/bravesoftware/Preferences.backup ~/.config/BraveSoftware/Brave-Browser/$selected_profile/Preferences
    echo "Backup restored successfully."
  else
    echo "No backup found. Please ensure a backup exists."
  fi
}

# Function to format preferences file
format_preferences() {
  echo "Formatting preferences file..."
  jq . ~/.config/BraveSoftware/Brave-Browser/$selected_profile/Preferences > ~/.config/BraveSoftware/Brave-Browser/$selected_profile/Preferences.formatted
  echo "Formatting completed: ~/.config/BraveSoftware/Brave-Browser/$selected_profile/Preferences.formatted"
}

# Function to open preferences file in the user's preferred editor
edit_preferences() {
  echo "Opening preferences file in your preferred editor..."
  $EDITOR ~/.config/BraveSoftware/Brave-Browser/$selected_profile/Preferences.formatted
}

# Function to replace original preferences with the formatted and edited file
replace_preferences() {
  echo "Replacing original preferences with the formatted and edited file..."
  mv ~/.config/BraveSoftware/Brave-Browser/$selected_profile/Preferences.formatted ~/.config/BraveSoftware/Brave-Browser/$selected_profile/Preferences
  echo "Preferences file updated successfully."
}

# Main menu function
main_menu() {
  while true; do
    clear
    echo "===== Brave Browser Preferences Editor ====="
    echo "1. Install jq"
    echo "2. Select profile"
    echo "3. Backup original preferences"
    echo "4. Format preferences file"
    echo "5. Edit preferences file"
    echo "6. Replace original preferences with edited file"
    echo "7. Restore backup preferences"
    echo "8. Exit"
    echo "============================================"
    read -p "Choose an option [1-8]: " choice

    case $choice in
      1) install_jq ;;
      2) select_profile ;;
      3) backup_preferences ;;
      4) format_preferences ;;
      5) edit_preferences ;;
      6) replace_preferences ;;
      7) restore_backup ;;
      8) exit 0 ;;
      *) echo "Invalid option. Please try again." ;;
    esac

    read -p "Press Enter to continue..."
  done
}

# Run the main menu
main_menu
