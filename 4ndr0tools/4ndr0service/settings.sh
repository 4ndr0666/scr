#!/bin/bash
# Author: 4ndr0666
################################
##############################
export LOG_FILE_DIR="/home/andro/.local/logs/4ndr0service/logs"
export LOG_FILE="$LOG_FILE_DIR/service_optimization.log"
export BACKUP_DIR="/Nas/Backups/4ndr0service"
export SETTINGS_FILE="$PKG_PATH/settings.sh"
###############################
############################## // USER INTERFACE //
######### --- // DIALOG or CLI
export USER_INTERFACE="dialog"
###############################
############################## // TEXT EDITOR //
#############################
export SETTINGS_EDITOR="nvim"
###############################
#############################
############################
create_directory_if_not_exists "$LOG_FILE_DIR"
create_directory_if_not_exists "$BACKUP_DIR"
#######################################################
