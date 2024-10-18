#!/usr/bin/env zsh

# Source necessary function scripts
source "$(dirname "$0")/log_functions.sh"
source "$(dirname "$0")/backup_functions.sh"
source "$(dirname "$0")/factory_functions.sh"

# ---- // FACTORY_ALL FUNCTION:
factory_all() {
    echo -e "\033[1;34m🔄 Starting comprehensive permission reset...\033[0m"
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
    
    # Array of factory functions to execute
    local factory_functions=("factory_user" "factory_gpg" "factory_ssh" "factory_boot" "factory_python")
    
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
    
    echo -e "\033[1;34m🔚 Comprehensive permission reset completed.\033[0m"
    log_action "factory_all: Comprehensive permission reset completed."
}

# Execute the factory_all function when the script is run
factory_all
