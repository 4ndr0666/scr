#!/usr/bin/env bash
# shellcheck disable=all

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



# Function to restore system
restore_system() {
	echo "➡️ Starting system restore..."
	if execute_restore; then
		printf "✔️ System restored successfully."
	else
		printf "Error: System restore failed."
		exit 1
	fi
	printf "\n"
}

# Function to update system settings
update_settings() {
	printf "➡️ Updating settings..."
	modify_settings
	source_settings
	printf "✔️ Settings updated successfully."
	printf "\n"
}
