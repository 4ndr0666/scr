#!/bin/bash
# File: main.sh
# Author: 4ndr0666

# ================================= // FIRSTRUN.SH //
# --- // Constants:

# --- // Logging:
LOG_DIR="$XDG_DATA_HOME/logs/firstrun_logs"
LOG_FILE="$LOG_DIR/firstrun.log"
mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

# Menu options for the main screen
function main_menu() {
    local choice
    choice=$(whiptail --title "4ndr0tools - First Run Setup" --menu "Choose an option:" 20 78 10 \
    "1" "Setup Recovery" \
    "2" "Setup Grub" \
    "3" "Setup Grub (Btrfs)" \
    "4" "Home Manager" \
    "5" "Clean Menu" \
    "6" "System Health Check" \
    "7" "Backup Verification" \
    "8" "System Cleanup" \
    "9" "View Logs" \
    "10" "Exit" 3>&1 1>&2 2>&3)

    case $choice in
        1) makerecovery ;;
        2) makegrub ;;
        3) makegrubbtrfs ;;
        4) homemanager ;;
        5) hideapps ;;
        6) healthcheck ;;
        7) verification ;;
        8) cleanup ;;
        9) view_logs ;;
        10) exit 0 ;;
        *) whiptail --msgbox "Invalid option. Please try again." 8 45 ;;
    esac
}

# Function to run the MakeRecovery script
function makerecovery() {
    if ./makerecovery.sh; then
        whiptail --msgbox "Recovery Setup Completed!" 8 45
    else
        whiptail --msgbox "Encountered An Error." 8 45
    fi
}

# Function to run the MakeGrub script
function makegrub() {
    if ./makegrub.sh; then
        whiptail --msgbox "Grub Setup Completed!" 8 45
    else
        whiptail --msgbox "Encountered An Error." 8 45
    fi
}

# Function to run the MakeGrubBtrfs script
function makegrubbtrfs() {
    if ./makegrubbtrfs.sh; then
        whiptail --msgbox "Grub Setup Completed!" 8 45
    else
        whiptail --msgbox "Encountered An Error." 8 45
    fi
}

# Function to run the Home Manager script
function homemanager() {
    if ./homemanager.sh; then
        whiptail --msgbox "Home Manager Operations Completed Successfully." 8 45
    else
        whiptail --msgbox "Encountered An Error." 8 45
    fi
}

# Function to run the HideApps script
function hideapps() {
    if ./hideapps.sh; then
        whiptail --msgbox "Menu Successfully Cleaned." 8 45
    else
        whiptail --msgbox "Encountered An Error." 8 45
    fi
}

# Function for system health check
function healthcheck() {
    if ./healthcheck.sh; then
        whiptail --msgbox "System Is Healthy!" 8 45
    else
        whiptail --msgbox "Encountered An Error." 8 45
    fi
}

# Function for backup verification
function verification() {
    if ./verification.sh; then
        whiptail --msgbox "Recovery Backup Verified!" 8 45
    else
        whiptail --msgbox "Recovery Backup Does Not Exist." 8 45
    fi
}

# Function for system cleanup
function cleanup() {
    if ./cleanup.sh; then
        whiptail --msgbox "System Cleanup Complete!" 8 45
    else
        whiptail --msgbox "Encountered An Error." 8 45
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
