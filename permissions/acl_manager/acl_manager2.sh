#!/bin/bash

# Function to display a menu
display_menu() {
    echo "Choose an option:"
    echo "1) Create Backup"
    echo "2) Restore Backup"
    echo "3) Exit"
}

# Function to check for root privileges
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "This script requires root privileges. Please run as root or use sudo."
        exit 1
    fi
}

# Function to create an ACL backup
create_backup() {
    read -p "Enter the directory to backup ACLs from (default: $PWD): " target_dir
    target_dir=${target_dir:-$PWD}
    read -p "Enter the output file path for ACL backup: " output_file

    if [ -z "$target_dir" ] || [ -z "$output_file" ]; then
        echo "Target directory and output file path cannot be empty."
        exit 1
    fi

    echo "Creating ACL backup from $target_dir to $output_file"
    getfacl -R "$target_dir" > "$output_file"
    if [ $? -eq 0 ]; then
        echo "ACLs successfully backed up to $output_file"
    else
        echo "Failed to backup ACLs"
        exit 1
    fi
}

# Function to restore ACLs with user replacement
restore_acls() {
    read -p "Enter the ACL backup file path (default: $PWD/$(ls $PWD | fzf --prompt='Select ACL file: ')): " input_file
    input_file=${input_file:-$PWD/$(ls $PWD | fzf --prompt='Select ACL file: ')}
    read -p "Enter the old user name: " old_user
    read -p "Enter the target user name: " target_user

    if [ -z "$input_file" ] || [ -z "$old_user" ] || [ -z "$target_user" ]; then
        echo "ACL backup file path, old user name, and target user name cannot be empty."
        exit 1
    fi

    if [ ! -f "$input_file" ]; then
        echo "ACL backup file not found: $input_file"
        exit 1
    fi

    echo "Restoring ACLs from $input_file"
    echo "Replacing user $old_user with $target_user in the ACL file"

    # Replace old user with new user in the ACL file
    sed -i "s/${old_user}/${target_user}/g" "$input_file"

    # Visual feedback using a spinner
    spinner() {
        local pid=$1
        local delay=0.1
        local spinstr='|/-\'
        while ps -p $pid > /dev/null; do
            local temp=${spinstr#?}
            printf " [%c]  " "$spinstr"
            local spinstr=$temp${spinstr%"$temp"}
            sleep $delay
            printf "\b\b\b\b\b\b"
        done
        printf "    \b\b\b\b"
    }

    # Start the restoration process and capture the result
    setfacl --restore="$input_file" >/dev/null 2>&1 &
    pid=$!
    spinner $pid
    wait $pid
    result=$?

    if [ $result -eq 0 ]; then
        echo "ACLs successfully restored from $input_file"
    else
        echo "Failed to restore ACLs"
        exit 1
    fi

    # Summary of restored ACLs
    echo "Summary of restored ACLs:"
    grep "^# file:" "$input_file" | awk '{print $3}' | while read -r file; do
        echo "  - $file"
    done
    exit 0
}

# Function for auto privilege escalation
auto_escalate() {
    if [ "$EUID" -ne 0 ]; then
        echo "This script requires root privileges. Attempting to escalate privileges..."
        exec sudo "$0" "$@"
        exit 1
    fi
}

# Main script logic
auto_escalate "$@"

while true; do
    display_menu
    read -p "Select an option (1-3): " option

    case $option in
        1)
            create_backup
            ;;
        2)
            restore_acls
            ;;
        3)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid option. Please try again."
            ;;
    esac
done
