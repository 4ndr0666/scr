#!/bin/bash

# --- Central Control Script for Initial System Setup ---

# Set up log directory and file
LOG_DIR="$XDG_DATA_HOME/logs/firstrun_logs"
LOG_FILE="$LOG_DIR/firstrun.log"
mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

# Menu options for the main screen
function main_menu() {
    local choice
    choice=$(whiptail --title "System Setup Control Center" --menu "Choose an option:" 20 78 10 \
    "1" "Run MakePoetry Setup" \
    "2" "Run MakeGrub Setup" \
    "3" "Run MakeRecovery Setup" \
    "4" "Run Home Manager" \
    "5" "Hide Applications" \
    "6" "System Health Check" \
    "7" "Backup Verification" \
    "8" "System Cleanup" \
    "9" "View Logs" \
    "10" "Exit" 3>&1 1>&2 2>&3)

    case $choice in
        1) run_makepoetry ;;
        2) run_makegrub ;;
        3) run_makerecovery ;;
        4) run_homemanager ;;
        5) run_hideapps ;;
        6) system_health_check ;;
        7) backup_verification ;;
        8) system_cleanup ;;
        9) view_logs ;;
        10) exit 0 ;;
        *) whiptail --msgbox "Invalid option. Please try again." 8 45 ;;
    esac
}

# Function to run the MakePoetry script
function run_makepoetry() {
    if ./makepoetry.sh; then
        whiptail --msgbox "MakePoetry setup completed successfully." 8 45
    else
        whiptail --msgbox "MakePoetry setup encountered an error." 8 45
    fi
}

# Function to run the MakeGrub script
function run_makegrub() {
    if ./makegrub.sh; then
        whiptail --msgbox "MakeGrub setup completed successfully." 8 45
    else
        whiptail --msgbox "MakeGrub setup encountered an error." 8 45
    fi
}

# Function to run the MakeRecovery script
function run_makerecovery() {
    if ./makerecover2-etc.sh; then
        whiptail --msgbox "MakeRecovery setup completed successfully." 8 45
    else
        whiptail --msgbox "MakeRecovery setup encountered an error." 8 45
    fi
}

# Function to run the Home Manager script
function run_homemanager() {
    if ./home_manager.sh; then
        whiptail --msgbox "Home Manager operations completed successfully." 8 45
    else
        whiptail --msgbox "Home Manager encountered an error." 8 45
    fi
}

# Function to run the HideApps script
function run_hideapps() {
    if ./hideapps.sh; then
        whiptail --msgbox "Applications were successfully hidden." 8 45
    else
        whiptail --msgbox "Hiding applications encountered an error." 8 45
    fi
}

# Function for system health check
function system_health_check() {
    if ./system_health_check.sh; then
        whiptail --msgbox "System health check completed successfully." 8 45
    else
        whiptail --msgbox "System health check encountered an error." 8 45
    fi
}

# Function for backup verification
function backup_verification() {
    if ./backup_verification.sh; then
        whiptail --msgbox "Backup verification completed successfully." 8 45
    else
        whiptail --msgbox "Backup verification encountered an error." 8 45
    fi
}

# Function for system cleanup
function system_cleanup() {
    if ./system_cleanup.sh; then
        whiptail --msgbox "System cleanup completed successfully." 8 45
    else
        whiptail --msgbox "System cleanup encountered an error." 8 45
    fi
}

# Function to view logs
function view_logs() {
    whiptail --title "View Logs" --textbox "$LOG_FILE" 20 60
}

# Run the main menu in a loop
while true; do
    main_menu
done
