#!/bin/bash

# Function to display user's current groups
view_groups() {
    id -nG "$1"
}

# Function to add user to selected group(s)
add_to_group() {
    for group in "${@:2}"; do
        usermod -aG "$group" "$1"
    done
    echo "$1 added to groups: ${@:2}"
}

# Function to remove user from selected group(s)
remove_from_group() {
    for group in "${@:2}"; do
        gpasswd -d "$1" "$group"
    done
    echo "$1 removed from groups: ${@:2}"
}

# Function to apply a standard preset of groups to the user
apply_standard_preset() {
    local standard_groups=("wheel" "audio" "video" "optical" "storage" "scanner" "lp" "network" "power")
    echo "Applying standard preset groups to $1..."
    for group in "${standard_groups[@]}"; do
        if grep -q "^${group}:" /etc/group; then
            usermod -aG "$group" "$1"
            echo "$1 added to $group."
        else
            echo "Group $group does not exist. Skipping..."
        fi
    done
}

# Main menu function
main_menu() {
    echo "Select operation:"
    options=("View User's Groups" "Add User to Group" "Remove User from Group" "Apply Standard Group Preset")
    select opt in "${options[@]}"; do
        case $REPLY in
            1)
                echo "Enter username:"
                read -r username
                echo "Groups for $username:"
                view_groups "$username"
                break
                ;;
            2)
                echo "Enter username:"
                read -r username
                echo "Select group(s) to add user to:"
                mapfile -t selected < <(cut -d: -f1 /etc/group | fzf -m)
                add_to_group "$username" "${selected[@]}"
                break
                ;;
            3)
                echo "Enter username:"
                read -r username
                echo "Select group(s) to remove user from:"
                mapfile -t selected < <(cut -d: -f1 /etc/group | fzf -m)
                remove_from_group "$username" "${selected[@]}"
                break
                ;;
            4)
                echo "Enter username:"
                read -r username
                apply_standard_preset "$username"
                break
                ;;
            *)
                echo "Invalid option. Please enter a number from 1 to 4."
                ;;
        esac
    done
}

# Ensure script is run with root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root."
    exit 1
fi

# Ensure fzf is installed
if ! command -v fzf &> /dev/null; then
    echo "fzf is not installed. Please install it first."
    exit 1
fi

main_menu








