#!/usr/bin/env zsh

# Source necessary function scripts
source "$(dirname "$0")/log_functions.sh"
source "$(dirname "$0")/backup_functions.sh"
source "$(dirname "$0")/factory_functions.sh"

# List of available factory functions and their descriptions
factory_functions=("factory_user" "factory_gpg" "factory_ssh" "factory_boot" "factory_python")
factory_descriptions=(
    "User Permissions"
    "GPG Permissions"
    "SSH Permissions"
    "/boot Permissions"
    "Python Permissions"
)

# ---- // MAIN MENU FUNCTION:
main_menu() {
    echo -e "\033[1;34m💥 4ndr0permission 💥\033[0m"
    echo ""

    while true; do
        echo "# --- // Menu:"
        echo "0) All"
        for i in {1..${#factory_functions[@]}}; do
            echo "$i) ${factory_functions[$i-1]} - ${factory_descriptions[$i-1]}"
        done
        echo "q) Quit"
        echo ""

        read "user_choice?By your command: "
        echo ""

        if [[ "$user_choice" == "q" ]]; then
            echo -e "\033[1;33mExiting 4ndr0permission.\033[0m"
            break
        elif [[ "$user_choice" == "0" ]]; then
            factory_all
            break
        elif [[ "$user_choice" -ge 1 && "$user_choice" -le ${#factory_functions[@]} ]]; then
            selected_function="${factory_functions[$user_choice-1]}"
            echo -e "\033[1;36m➡️ Executing $selected_function...\033[0m"
            log_action "main_menu: Executing $selected_function."

            # Execute the selected function
            if declare -f "$selected_function" > /dev/null; then
                # Optional confirmation prompt for the function
                read -q "func_confirm?Are you sure you want to run $selected_function? (y/N): "
                echo ""
                if [[ "$func_confirm" == [Yy] ]]; then
                    "$selected_function"
                    local func_status=$?

                    # Provide status feedback
                    if [[ $func_status -eq 0 ]]; then
                        echo -e "\033[1;32m✅ $selected_function completed successfully.\033[0m"
                        log_action "main_menu: $selected_function completed successfully."
                    else
                        echo -e "\033[1;31m❌ $selected_function encountered errors.\033[0m"
                        log_action "main_menu: $selected_function encountered errors."
                    fi
                else
                    echo -e "\033[1;33m⚠️ $selected_function aborted by user.\033[0m"
                    log_action "main_menu: $selected_function aborted by user."
                fi
            else
                echo -e "\033[1;31m❌ Error: Function '$selected_function' is not defined.\033[0m"
                log_action "main_menu: Error - Function '$selected_function' is not defined."
            fi

        else
            echo -e "\033[1;31mInvalid choice. Please try again.\033[0m"
        fi

        echo ""
    done
}

# ---- // FACTORY_ALL FUNCTION:
factory_all() {
    echo -e "\033[1;34m➡️ Resetting Default Factory Permissions...\033[0m"
    echo ""

    # Confirmation prompt
    read -q "user_confirm?Are you sure you want to reset all permissions? This may affect system stability and security. (y/N): "
    echo ""  # Move to a new line after user input
    if [[ "$user_confirm" != [Yy] ]]; then
        echo -e "\033[1;33m⚠️ Permission reset aborted by user.\033[0m"
        log_action "factory_all: Permission reset aborted by user."
        return 0
    fi

    echo ""

    # Backup permissions before making changes
    backup_permissions
    if [[ $? -ne 0 ]]; then
        echo -e "\033[1;31m❌ Error: Backup failed. Aborting permission reset.\033[0m"
        log_action "factory_all: Backup failed. Aborting permission reset."
        return 1
    fi

    echo ""

    # Iterate over each factory function
    for func in "${factory_functions[@]}"; do
        if declare -f "$func" > /dev/null; then
            echo -e "\033[1;36m➡️ Running $func...\033[0m"
            log_action "factory_all: Running $func."

            # Execute the function
            "$func"
            local func_status=$?

            # Provide status feedback
            if [[ $func_status -eq 0 ]]; then
                echo -e "\033[1;32m✅ $func completed successfully.\033[0m"
                log_action "factory_all: $func completed successfully."
            else
                echo -e "\033[1;31m❌ $func encountered errors.\033[0m"
                log_action "factory_all: $func encountered errors."
            fi

            echo ""
        else
            echo -e "\033[1;31m❌ Error: Function '$func' is not defined.\033[0m"
            log_action "factory_all: Error - Function '$func' is not defined."
        fi
    done

    echo -e "\033[1;34m🔚 Default factory permissions applied!\033[0m"
    log_action "factory_all: Default factory permissions applied!"
}

# Start the script by calling the main menu
main_menu
