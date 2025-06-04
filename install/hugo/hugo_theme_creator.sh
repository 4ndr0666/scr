#!/bin/bash
# shellcheck disable=all

# Color variables for visual enhancement
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

# Ensure that we are in the root directory of a Hugo project
if [ ! -f "config.yml" ]; then
    echo -e "${RED}Error: This script must be run from the root of a Hugo project.${RESET}"
    exit 1
fi

# Function to display the menu
show_menu() {
    echo -e "${CYAN}${BOLD}"
    echo "----------------------------------------"
    echo "  Welcome to the Hugo Theme Creator     "
    echo "----------------------------------------"
    echo -e "${RESET}"
    echo -e "Please choose an option:"
    echo -e "${CYAN}1. Create a new Hugo theme${RESET}"
    echo -e "${CYAN}2. Copy preset theme files${RESET}"
    echo -e "${CYAN}3. Update config.yml${RESET}"
    echo -e "${CYAN}4. Initialize and update submodule${RESET}"
    echo -e "${CYAN}5. Remove submodule and detach${RESET}"
    echo -e "${CYAN}6. Commit and Push to Git${RESET}"
    echo -e "${CYAN}7. Exit${RESET}"
    echo ""
}

# Function to create a new Hugo theme
create_hugo_theme() {
    echo -e "${YELLOW}Enter the name of the new theme:${RESET} "
    read theme_name

    if [ -d "themes/$theme_name" ]; then
        echo -e "${RED}Error: Theme '$theme_name' already exists.${RESET}"
        return
    fi

    hugo new theme "$theme_name"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Success! Theme '$theme_name' has been created.${RESET}"
    else
        echo -e "${RED}Error creating theme '$theme_name'.${RESET}"
    fi
    echo ""
}

# Function to copy preset theme files (handles submodule)
copy_preset_files() {
    echo -e "${YELLOW}Enter the name of the preset theme to copy:${RESET} "
    read preset_theme
    echo -e "${YELLOW}Enter the name of the new theme to copy to:${RESET} "
    read new_theme

    # Check if the preset theme is a submodule
    submodule_check=$(git submodule status | grep "themes/$preset_theme")
    
    if [ -n "$submodule_check" ]; then
        echo -e "${CYAN}Preset theme '$preset_theme' is a submodule. Initializing and updating...${RESET}"
        git submodule init
        git submodule update
    fi

    # Check if the preset theme exists after initializing the submodule
    if [ ! -d "themes/$preset_theme" ]; then
        echo -e "${RED}Preset theme '$preset_theme' does not exist!${RESET}"
        return
    fi

    # Check if the new theme exists
    if [ ! -d "themes/$new_theme" ]; then
        echo -e "${RED}New theme '$new_theme' does not exist!${RESET}"
        return
    fi

    # Copy the preset theme files
    for folder in layouts static partials; do
        if [ ! -d "themes/$preset_theme/$folder" ]; then
            echo -e "${YELLOW}Notice: Directory 'themes/$preset_theme/$folder' does not exist. Skipping...${RESET}"
        else
            cp -r "themes/$preset_theme/$folder" "themes/$new_theme/"
        fi
    done

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Success! Preset theme files copied to '$new_theme'.${RESET}"
    else
        echo -e "${RED}Error copying files from '$preset_theme' to '$new_theme'.${RESET}"
    fi
    echo ""
}

# Function to update config.yml with the new theme
update_config() {
    echo -e "${YELLOW}Enter the name of the new theme to update in config.yml:${RESET} "
    read new_theme

    # Check if config.yml exists
    if [ ! -f "config.yml" ]; then
        echo -e "${RED}config.yml does not exist in the current directory.${RESET}"
        return
    fi

    # Check if the new theme exists
    if [ ! -d "themes/$new_theme" ]; then
        echo -e "${RED}Theme '$new_theme' does not exist!${RESET}"
        return
    fi

    # Update the config.yml file only if the theme is not already set
    current_theme=$(grep "^theme:" config.yml | cut -d '"' -f2)
    if [ "$current_theme" == "$new_theme" ]; then
        echo -e "${CYAN}The theme is already set to '$new_theme'. No changes needed.${RESET}"
        return
    fi

    sed -i "s/^theme:.*/theme: \"$new_theme\"/" config.yml

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Success! config.yml updated with the new theme '$new_theme'.${RESET}"
    else
        echo -e "${RED}Error updating config.yml.${RESET}"
    fi
    echo ""
}

# Function to initialize and update submodules
initialize_submodule() {
    echo -e "${CYAN}Initializing and updating submodules...${RESET}"
    git submodule init
    git submodule update

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Submodules initialized and updated successfully.${RESET}"
    else
        echo -e "${RED}Error initializing/updating submodules.${RESET}"
    fi
    echo ""
}

# Function to remove submodule and detach the theme
remove_submodule() {
    echo -e "${YELLOW}Enter the name of the theme to detach from submodule:${RESET} "
    read theme_name

    if [ ! -d "themes/$theme_name" ]; then
        echo -e "${RED}Theme '$theme_name' does not exist!${RESET}"
        return
    fi

    # Remove the submodule and its .git data
    echo -e "${CYAN}Detaching '$theme_name' from submodule...${RESET}"
    git submodule deinit -f "themes/$theme_name"
    rm -rf ".git/modules/themes/$theme_name"
    rm -rf "themes/$theme_name/.git"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Success! Theme '$theme_name' is now detached from submodule.${RESET}"
    else
        echo -e "${RED}Error detaching theme '$theme_name' from submodule.${RESET}"
    fi
    echo ""
}

# Function to commit and push changes to Git
commit_and_push() {
    echo -e "${YELLOW}Staging changes...${RESET}"
    git add themes/ config.yml
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Changes staged successfully.${RESET}"
    else
        echo -e "${RED}Error staging changes.${RESET}"
        return
    fi

    echo -e "${YELLOW}Enter the commit message:${RESET} "
    read commit_message

    echo -e "${CYAN}Committing changes...${RESET}"
    git commit -m "$commit_message"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Changes committed successfully.${RESET}"
    else
        echo -e "${RED}Error committing changes.${RESET}"
        return
    fi

    echo -e "${CYAN}Pushing changes to the repository...${RESET}"
    git push origin main
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Changes pushed successfully.${RESET}"
    else
        echo -e "${RED}Error pushing changes.${RESET}"
    fi
    echo ""
}

# Function to handle user input
handle_option() {
    local choice
    read -p "Enter your choice [1-7]: " choice
    case $choice in
        1) create_hugo_theme ;;
        2) copy_preset_files ;;
        3) update_config ;;
        4) initialize_submodule ;;
        5) remove_submodule ;;
        6) commit_and_push ;;
        7) echo -e "${CYAN}Exiting...${RESET}"; exit 0 ;;
        *) echo -e "${RED}Invalid option, please try again.${RESET}" ;;
    esac
}

# Main loop
while true; do
    show_menu
    handle_option
done
