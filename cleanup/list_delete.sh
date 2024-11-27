#!/bin/bash

# Print ASCII art in green
#echo -e "${GREEN}"
#cat << "EOF"
#  .____     .__           __           .___       .__            __                       .__     
#  |    |    |__|  _______/  |_       __| _/ ____  |  |    ____ _/  |_   ____        ______|  |__  
#  |    |    |  |/  ___/\   __\     / __ |_/ __ \ |  |  _/ __ \\   __\_/ __ \      /  ___/|  |  \ 
#  |    |___ |  |\___ \  |  |      / /_/ |\  ___/ |  |__\  ___/ |  |  \  ___/      \___ \ |   Y  \
#  |_______ \|__|/____  > |__|______\____ | \___  >|____/ \___  >|__|   \___  > /\ /____  >|___|  /
#          \/         \/     /_____/     \/     \/            \/            \/  \/      \/      \/ 
#EOF
#echo -e "${NC}"

GREEN='\033[0;32m'
NC='\033[0m' # No Color


# Prompt the user for the path to the list in green
echo -e "${GREEN}Enter the path to the list of files you want to delete:${NC}"
read -r _input

# Check if the file exists
if [ ! -f "$_input" ]; then
    echo "File $(_input) not found."
    exit 1
fi

# Ask the user for the mode of operation in green
echo -e "${GREEN}Choose an option:"
echo "1. Delete files in the list that exist."
echo "2. Delete all files except those in the list."
read -rp "Enter your choice (1/2): " choice

# Confirmation before proceeding in green
echo -e "${GREEN}Are you sure you want to proceed with this operation? [y/N]:${NC}"
read confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

# Based on the user's choice, perform the operation
case $choice in
    1)
        # Delete files in the list that exist
        while read -r line
        do 
            if [ -f "$line" ]; then
                echo "Deleting $line..."
                rm -f "$line"
            else
                echo "File $line not found."
            fi
        done < "$_input"
        ;;
    2)
        # Delete all files except those in the list
        for file in *
        do
            # If the file is not in the list, delete it
            if ! grep -qxF "$file" "$_input"; then
                echo "Deleting $file..."
                rm -f "$file"
            else
                echo "Keeping $file..."
            fi
        done
        ;;
    *)
        echo "Invalid choice."
        exit 1
        ;;
esac

echo "Operation completed."

