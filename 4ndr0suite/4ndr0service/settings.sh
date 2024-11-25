#!/bin/bash
# Author: 4ndr0666
# File: settings.sh

# =============================== // SETTINGS.SH //
################################
##############################
export LOG_FILE_DIR="/home/andro/.cache/4ndr0service/logs"
export LOG_FILE="$LOG_FILE_DIR/service_optimization.log"
export BACKUP_DIR="/home/andro/.local/share/4ndr0service/backups/settings_backups"
export SETTINGS_FILE="$PKG_PATH/settings.sh"
###############################
############################## // USER INTERFACE //
######### --- // DIALOG or CLI
export USER_INTERFACE="cli"
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
