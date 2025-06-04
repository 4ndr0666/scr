#!/bin/bash
# shellcheck disable=all
# File: rsnapshot.sh
# An interactive script to manage and restore rsnapshot backups on Arch Linux
# Author: 4ndr0666
# Date: 2024-12-11
set -e
# set -x

# ============================ // RSNAPSHOT.SH //
# Constants
CONFIG_FILE="/etc/rsnapshot.conf"
EXCLUDE_FILE="/usr/local/bin/excluded_dir.txt"
LOGFILE="/var/log/rsnapshot/rsnapshot.log"
LOCKFILE="/var/run/rsnapshot.pid"
SNAPSHOT_ROOT="/Nas/Backups/rsnapshot/"
CRON_FILE="/var/spool/cron/crontabs/root"

# Colors for UI
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
BOLD=$(tput bold)
RESET=$(tput sgr0)

# Function: Display Main Menu
display_menu() {
    clear
    echo "${BOLD}==============================================${RESET}"
    echo "${BOLD}            rsnapshot Manager                 ${RESET}"
    echo "${BOLD}==============================================${RESET}"
    echo ""
    echo "Please choose an option:"
    echo "1. Verify and Set Permissions for Snapshot Root"
    echo "2. Verify External Program Paths"
    echo "3. Ensure Logfile Setup and Permissions"
    echo "4. Configure Lockfile Setup and Permissions"
    echo "5. Enable and Configure rsync Arguments"
    echo "6. Enable link_dest Option"
    echo "7. Enable sync_first Option and Adjust Crontab"
    echo "8. Enable stop_on_stale_lockfile Option"
    echo "9. Manage Exclusion Patterns"
    echo "10. Manage Cron Jobs"
    echo "11. Perform Configuration Test and Manual Backup Run"
    echo "12. Monitor Logfiles and Disk Usage"
    echo "13. Restore from Snapshot"
    echo "14. Exit"
    echo ""
    echo -n "Enter your choice [1-14]: "
}

# Function: Verify and Set Permissions for Snapshot Root
verify_set_permissions_snapshot_root() {
    echo "${BLUE}Verifying and setting permissions for snapshot root directory...${RESET}"
    if [ -d "$SNAPSHOT_ROOT" ]; then
        echo "Snapshot root directory exists."
    else
        echo "Snapshot root directory does not exist. Creating..."
        sudo mkdir -p "$SNAPSHOT_ROOT"
        echo "Created snapshot root directory at $SNAPSHOT_ROOT."
    fi
    sudo chown root:andro "$SNAPSHOT_ROOT"
    sudo chmod 700 "$SNAPSHOT_ROOT"
    echo "${GREEN}Permissions set to 700 and ownership set to root:andro.${RESET}"
    read -n1 -r -p "Press any key to return to the menu..."
}

# Function: Verify External Program Paths
verify_external_program_paths() {
    echo "${BLUE}Verifying external program paths...${RESET}"
    PROGRAMS=("cp" "rm" "rsync" "du" "rsnapshot-diff")
    declare -A program_paths

    for prog in "${PROGRAMS[@]}"; do
        path=$(which "$prog" 2>/dev/null || echo "Not found")
        program_paths["$prog"]="$path"
        echo "$prog: ${path}"
    done

    # Check if any program is not found
    missing=()
    for prog in "${PROGRAMS[@]}"; do
        if [ "${program_paths[$prog]}" == "Not found" ]; then
            missing+=("$prog")
        fi
    done

    if [ ${#missing[@]} -ne 0 ]; then
        echo "${RED}The following programs are missing:${RESET} ${missing[*]}"
        echo "Please install them before proceeding."
    else
        echo "${GREEN}All external programs are correctly installed.${RESET}"
    fi

    read -n1 -r -p "Press any key to return to the menu..."
}

# Function: Ensure Logfile Setup and Permissions
ensure_logfile_setup() {
    echo "${BLUE}Ensuring logfile setup and permissions...${RESET}"
    if [ ! -d "$(dirname "$LOGFILE")" ]; then
        sudo mkdir -p "$(dirname "$LOGFILE")"
        echo "Created log directory at $(dirname "$LOGFILE")."
    fi

    if [ ! -f "$LOGFILE" ]; then
        sudo touch "$LOGFILE"
        echo "Created logfile at $LOGFILE."
    fi

    sudo chown root:root "$LOGFILE"
    sudo chmod 600 "$LOGFILE"
    echo "${GREEN}Logfile ownership set to root:root and permissions set to 600.${RESET}"
    read -n1 -r -p "Press any key to return to the menu..."
}

# Function: Configure Lockfile Setup and Permissions
configure_lockfile() {
    echo "${BLUE}Configuring lockfile setup and permissions...${RESET}"
    if [ ! -f "$LOCKFILE" ]; then
        sudo touch "$LOCKFILE"
        echo "Created lockfile at $LOCKFILE."
    fi

    sudo chown root:root "$LOCKFILE"
    sudo chmod 600 "$LOCKFILE"
    echo "${GREEN}Lockfile ownership set to root:root and permissions set to 600.${RESET}"
    read -n1 -r -p "Press any key to return to the menu..."
}

# Function: Enable and Configure rsync Arguments
configure_rsync_arguments() {
    echo "${BLUE}Configuring rsync arguments in rsnapshot.conf...${RESET}"
    # Backup the original config
    sudo cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"

    # Update rsync_short_args
    sudo sed -i 's/^rsync_short_args\s\+.*$/rsync_short_args\t-aH/' "$CONFIG_FILE"

    # Update rsync_long_args
    sudo sed -i 's/^rsync_long_args\s\+.*$/rsync_long_args\t--delete --numeric-ids --relative --delete-excluded/' "$CONFIG_FILE"

    echo "${GREEN}rsync_short_args set to -aH and rsync_long_args set to --delete --numeric-ids --relative --delete-excluded.${RESET}"
    read -n1 -r -p "Press any key to return to the menu..."
}

# Function: Enable link_dest Option
enable_link_dest() {
    echo "${BLUE}Enabling link_dest option in rsnapshot.conf...${RESET}"
    sudo sed -i 's/^link_dest\s\+0/link_dest\t1/' "$CONFIG_FILE"
    echo "${GREEN}link_dest option enabled.${RESET}"
    read -n1 -r -p "Press any key to return to the menu..."
}

# Function: Enable sync_first Option and Adjust Crontab
enable_sync_first() {
    echo "${BLUE}Enabling sync_first option in rsnapshot.conf and adjusting crontab...${RESET}"
    sudo sed -i 's/^sync_first\s\+0/sync_first\t1/' "$CONFIG_FILE"
    echo "${GREEN}sync_first option enabled in rsnapshot.conf.${RESET}"

    # Update crontab
    echo "${YELLOW}Updating crontab to include sync operation before alpha backup...${RESET}"
    sudo crontab -l | grep -v "rsnapshot sync && rsnapshot alpha" > /tmp/crontab.tmp || true
    echo "0 */4 * * *    /usr/bin/rsnapshot sync && /usr/bin/rsnapshot alpha" | sudo tee -a /tmp/crontab.tmp > /dev/null
    echo "50 23 * * *    /usr/bin/rsnapshot beta" | sudo tee -a /tmp/crontab.tmp > /dev/null
    echo "40 23 * * 6    /usr/bin/rsnapshot gamma" | sudo tee -a /tmp/crontab.tmp > /dev/null
    echo "30 23 1 * *    /usr/bin/rsnapshot delta" | sudo tee -a /tmp/crontab.tmp > /dev/null
    sudo crontab /tmp/crontab.tmp
    rm /tmp/crontab.tmp
    echo "${GREEN}Crontab updated successfully.${RESET}"
    read -n1 -r -p "Press any key to return to the menu..."
}

# Function: Enable stop_on_stale_lockfile Option
enable_stop_on_stale_lockfile() {
    echo "${BLUE}Enabling stop_on_stale_lockfile option in rsnapshot.conf...${RESET}"
    sudo sed -i 's/^stop_on_stale_lockfile\s\+0/stop_on_stale_lockfile\t1/' "$CONFIG_FILE"
    echo "${GREEN}stop_on_stale_lockfile option enabled.${RESET}"
    read -n1 -r -p "Press any key to return to the menu..."
}

# Function: Manage Exclusion Patterns
manage_exclusions() {
    while true; do
        clear
        echo "${BOLD}==============================================${RESET}"
        echo "${BOLD}           Manage Exclusion Patterns           ${RESET}"
        echo "${BOLD}==============================================${RESET}"
        echo ""
        echo "1. View Current Exclusions"
        echo "2. Add an Exclusion Pattern"
        echo "3. Remove an Exclusion Pattern"
        echo "4. Search and Add Exclusion with fzf"
        echo "5. Return to Main Menu"
        echo ""
        echo -n "Enter your choice [1-5]: "
        read -r choice
        case $choice in
            1)
                echo "${BLUE}Current Exclusion Patterns:${RESET}"
                sudo cat "$EXCLUDE_FILE" || echo "No exclusion patterns found."
                echo ""
                read -n1 -r -p "Press any key to continue..."
                ;;
            2)
                echo "${BLUE}Add a New Exclusion Pattern:${RESET}"
                echo -n "Enter the exclusion pattern: "
                read -r pattern
                echo "$pattern" | sudo tee -a "$EXCLUDE_FILE" > /dev/null
                echo "${GREEN}Pattern '$pattern' added to exclusions.${RESET}"
                read -n1 -r -p "Press any key to continue..."
                ;;
            3)
                echo "${BLUE}Remove an Exclusion Pattern:${RESET}"
                echo "${YELLOW}Select the pattern to remove:${RESET}"
                patterns=$(sudo grep -v '^#' "$EXCLUDE_FILE")
                if [ -z "$patterns" ]; then
                    echo "No exclusion patterns to remove."
                else
                    selected=$(echo "$patterns" | fzf --prompt="Select pattern to remove: ")
                    if [ -n "$selected" ]; then
                        sudo sed -i "/$(echo "$selected" | sed 's/[^^]/[&]/g; s/\^/\\^/g')/d" "$EXCLUDE_FILE"
                        echo "${GREEN}Pattern '$selected' removed from exclusions.${RESET}"
                    else
                        echo "No pattern selected."
                    fi
                fi
                echo ""
                read -n1 -r -p "Press any key to continue..."
                ;;
            4)
                echo "${BLUE}Search and Add Exclusion with fzf:${RESET}"
                echo "Select files or directories to exclude:"
                selections=$(find /home/andro -type d -o -type f | fzf -m)
                if [ -n "$selections" ]; then
                    echo "$selections" | sudo tee -a "$EXCLUDE_FILE" > /dev/null
                    echo "${GREEN}Selected patterns added to exclusions.${RESET}"
                else
                    echo "No selections made."
                fi
                echo ""
                read -n1 -r -p "Press any key to continue..."
                ;;
            5)
                break
                ;;
            *)
                echo "${RED}Invalid choice. Please select a valid option.${RESET}"
                read -n1 -r -p "Press any key to continue..."
                ;;
        esac
    done
}

# Function: Manage Cron Jobs
manage_cron_jobs() {
    while true; do
        clear
        echo "${BOLD}==============================================${RESET}"
        echo "${BOLD}              Manage Cron Jobs                ${RESET}"
        echo "${BOLD}==============================================${RESET}"
        echo ""
        echo "1. View Current Cron Jobs"
        echo "2. Add a New Cron Job"
        echo "3. Remove a Cron Job"
        echo "4. Edit a Cron Job"
        echo "5. Return to Main Menu"
        echo ""
        echo -n "Enter your choice [1-5]: "
        read -r choice
        case $choice in
            1)
                echo "${BLUE}Current Cron Jobs:${RESET}"
                sudo crontab -l || echo "No cron jobs found."
                echo ""
                read -n1 -r -p "Press any key to continue..."
                ;;
            2)
                echo "${BLUE}Add a New Cron Job:${RESET}"
                echo "Enter the cron schedule (e.g., '0 */4 * * *'):"
                read -r schedule
                echo "Enter the rsnapshot command (e.g., '/usr/bin/rsnapshot alpha'):"
                read -r command
                # Validate schedule format (basic check)
                if [[ $schedule =~ ^([0-5]|\*)\ ([0-9]|\*)\ ([0-9]|\*)\ ([0-9]|\*)\ ([0-7]|\*)$ ]]; then
                    (sudo crontab -l 2>/dev/null; echo "$schedule    $command") | sudo crontab -
                    echo "${GREEN}Cron job added successfully.${RESET}"
                else
                    echo "${RED}Invalid cron schedule format.${RESET}"
                fi
                echo ""
                read -n1 -r -p "Press any key to continue..."
                ;;
            3)
                echo "${BLUE}Remove a Cron Job:${RESET}"
                jobs=$(sudo crontab -l 2>/dev/null | grep rsnapshot)
                if [ -z "$jobs" ]; then
                    echo "No rsnapshot cron jobs found."
                else
                    selected=$(echo "$jobs" | fzf --prompt="Select cron job to remove: ")
                    if [ -n "$selected" ]; then
                        sudo crontab -l | grep -vF "$selected" | sudo crontab -
                        echo "${GREEN}Selected cron job removed.${RESET}"
                    else
                        echo "No cron job selected."
                    fi
                fi
                echo ""
                read -n1 -r -p "Press any key to continue..."
                ;;
            4)
                echo "${BLUE}Edit a Cron Job:${RESET}"
                jobs=$(sudo crontab -l 2>/dev/null | grep rsnapshot)
                if [ -z "$jobs" ]; then
                    echo "No rsnapshot cron jobs found."
                else
                    selected=$(echo "$jobs" | fzf --prompt="Select cron job to edit: ")
                    if [ -n "$selected" ]; then
                        echo "Selected Cron Job: $selected"
                        echo "Enter the new schedule (leave blank to keep unchanged):"
                        read -r new_schedule
                        echo "Enter the new command (leave blank to keep unchanged):"
                        read -r new_command
                        updated_job="$selected"
                        if [ -n "$new_schedule" ]; then
                            updated_job=$(echo "$updated_job" | sed "s/^[^ ]\+ [^ ]\+ [^ ]\+ [^ ]\+ [^ ]\+/$(echo "$new_schedule" | sed 's/\*/\\*/g')/")
                        fi
                        if [ -n "$new_command" ]; then
                            updated_job=$(echo "$updated_job" | sed "s|/usr/bin/rsnapshot.*|$new_command|")
                        fi
                        # Remove old job and add updated job
                        sudo crontab -l | grep -vF "$selected" | sudo crontab -
                        (sudo crontab -l 2>/dev/null; echo "$updated_job") | sudo crontab -
                        echo "${GREEN}Cron job updated successfully.${RESET}"
                    else
                        echo "No cron job selected."
                    fi
                fi
                echo ""
                read -n1 -r -p "Press any key to continue..."
                ;;
            5)
                break
                ;;
            *)
                echo "${RED}Invalid choice. Please select a valid option.${RESET}"
                read -n1 -r -p "Press any key to continue..."
                ;;
        esac
    done
}

# Function: Perform Configuration Test and Manual Backup Run
configuration_test_manual_backup() {
    while true; do
        clear
        echo "${BOLD}==============================================${RESET}"
        echo "${BOLD}   Configuration Test & Manual Backup Run      ${RESET}"
        echo "${BOLD}==============================================${RESET}"
        echo ""
        echo "1. Perform Configuration Test"
        echo "2. Perform Manual Backup Run"
        echo "3. Return to Main Menu"
        echo ""
        echo -n "Enter your choice [1-3]: "
        read -r choice
        case $choice in
            1)
                echo "${BLUE}Performing Configuration Test...${RESET}"
                if sudo rsnapshot configtest; then
                    echo "${GREEN}Configuration test passed successfully.${RESET}"
                else
                    echo "${RED}Configuration test failed. Please check the config file.${RESET}"
                fi
                echo ""
                read -n1 -r -p "Press any key to continue..."
                ;;
            2)
                echo "${BLUE}Select Backup Level to Run Manually:${RESET}"
                backup_levels=("alpha" "beta" "gamma" "delta")
                selected=$(printf '%s\n' "${backup_levels[@]}" | fzf --prompt="Select backup level: ")
                if [ -n "$selected" ]; then
                    echo "${YELLOW}Running rsnapshot $selected backup...${RESET}"
                    sudo rsnapshot -v "$selected"
                    echo "${GREEN}rsnapshot $selected backup completed.${RESET}"
                else
                    echo "${RED}No backup level selected.${RESET}"
                fi
                echo ""
                read -n1 -r -p "Press any key to continue..."
                ;;
            3)
                break
                ;;
            *)
                echo "${RED}Invalid choice. Please select a valid option.${RESET}"
                read -n1 -r -p "Press any key to continue..."
                ;;
        esac
    done
}

# Function: Monitor Logfiles and Disk Usage
monitor_logs_disk_usage() {
    while true; do
        clear
        echo "${BOLD}==============================================${RESET}"
        echo "${BOLD}      Monitor Logfiles and Disk Usage         ${RESET}"
        echo "${BOLD}==============================================${RESET}"
        echo ""
        echo "1. View rsnapshot Logfile"
        echo "2. Check Disk Usage of Snapshots"
        echo "3. Return to Main Menu"
        echo ""
        echo -n "Enter your choice [1-3]: "
        read -r choice
        case $choice in
            1)
                echo "${BLUE}Displaying rsnapshot Logfile:${RESET}"
                sudo less "$LOGFILE"
                ;;
            2)
                echo "${BLUE}Checking Disk Usage of Snapshots...${RESET}"
                sudo rsnapshot du
                echo ""
                read -n1 -r -p "Press any key to continue..."
                ;;
            3)
                break
                ;;
            *)
                echo "${RED}Invalid choice. Please select a valid option.${RESET}"
                read -n1 -r -p "Press any key to continue..."
                ;;
        esac
    done
}

# Function: Restore from Snapshot
restore_from_snapshot() {
    echo "${BLUE}Restoration Process Initiated.${RESET}"
    
    # List available snapshot intervals
    intervals=("alpha" "beta" "gamma" "delta")
    echo "${YELLOW}Select the backup interval to restore from:${RESET}"
    selected_interval=$(printf '%s\n' "${intervals[@]}" | fzf --prompt="Select interval: ")
    
    if [ -z "$selected_interval" ]; then
        echo "${RED}No interval selected. Returning to main menu.${RESET}"
        read -n1 -r -p "Press any key to continue..."
        return
    fi
    
    # List available snapshots within the selected interval
    snapshots=$(ls -d "${SNAPSHOT_ROOT}${selected_interval}."* 2>/dev/null | sort -r)
    if [ -z "$snapshots" ]; then
        echo "${RED}No snapshots found for interval '$selected_interval'.${RESET}"
        read -n1 -r -p "Press any key to continue..."
        return
    fi
    
    echo "${YELLOW}Select the snapshot to restore from:${RESET}"
    selected_snapshot=$(echo "$snapshots" | fzf --prompt="Select snapshot: ")
    
    if [ -z "$selected_snapshot" ]; then
        echo "${RED}No snapshot selected. Returning to main menu.${RESET}"
        read -n1 -r -p "Press any key to continue..."
        return
    fi
    
    # List directories within the snapshot
    backup_points=$(ls -d "${selected_snapshot}/"* 2>/dev/null)
    if [ -z "$backup_points" ]; then
        echo "${RED}No backup points found in snapshot '$selected_snapshot'.${RESET}"
        read -n1 -r -p "Press any key to continue..."
        return
    fi
    
    echo "${YELLOW}Select the backup point to restore from:${RESET}"
    selected_backup_point=$(echo "$backup_points" | fzf --prompt="Select backup point: ")
    
    if [ -z "$selected_backup_point" ]; then
        echo "${RED}No backup point selected. Returning to main menu.${RESET}"
        read -n1 -r -p "Press any key to continue..."
        return
    fi
    
    # Prompt for target directory
    echo "${BLUE}Enter the target directory to restore to:${RESET}"
    read -r target_dir
    if [ -z "$target_dir" ]; then
        echo "${RED}No target directory provided. Aborting restoration.${RESET}"
        read -n1 -r -p "Press any key to continue..."
        return
    fi
    
    # Confirm restoration
    echo ""
    echo "${YELLOW}You are about to restore from:${RESET}"
    echo "Snapshot: $selected_snapshot"
    echo "Backup Point: $selected_backup_point"
    echo "Target Directory: $target_dir"
    echo ""
    echo -n "Are you sure you want to proceed? [y/N]: "
    read -r confirmation
    case "$confirmation" in
        [yY][eE][sS]|[yY])
            echo "${GREEN}Starting restoration...${RESET}"
            sudo rsync -aH --progress "$selected_backup_point/" "$target_dir"
            echo "${GREEN}Restoration completed successfully.${RESET}"
            ;;
        *)
            echo "${RED}Restoration aborted by user.${RESET}"
            ;;
    esac
    echo ""
    read -n1 -r -p "Press any key to return to the menu..."
}

# Function: Exit Script
exit_script() {
    echo "${GREEN}Exiting rsnapshot Backup & Restore Manager. Goodbye!${RESET}"
    exit 0
}

# Function: Handle Invalid Input
invalid_input() {
    echo "${RED}Invalid input. Please try again.${RESET}"
    read -n1 -r -p "Press any key to continue..."
}

# Function: Display Restoration Menu (if needed)
# Not needed since restoration is integrated as option 13

# Main Loop
while true; do
    display_menu
    read -r menu_choice
    case $menu_choice in
        1)
            verify_set_permissions_snapshot_root
            ;;
        2)
            verify_external_program_paths
            ;;
        3)
            ensure_logfile_setup
            ;;
        4)
            configure_lockfile
            ;;
        5)
            configure_rsync_arguments
            ;;
        6)
            enable_link_dest
            ;;
        7)
            enable_sync_first
            ;;
        8)
            enable_stop_on_stale_lockfile
            ;;
        9)
            manage_exclusions
            ;;
        10)
            manage_cron_jobs
            ;;
        11)
            configuration_test_manual_backup
            ;;
        12)
            monitor_logs_disk_usage
            ;;
        13)
            restore_from_snapshot
            ;;
        14)
            exit_script
            ;;
        *)
            invalid_input
            ;;
    esac
done
