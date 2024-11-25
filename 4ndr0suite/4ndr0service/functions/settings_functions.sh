#!/bin/bash
# File: settings_functions.sh
# Author: 4ndr0666
# Date: 10-20-24
# This file contains functions to manage and modify settings for the Service Optimization Suite.

# ==================================== // SETTINGS_FUNCTIONS.SH //
modify_settings() {
    # Check if EDITOR is set and valid
    if [[ -n "$EDITOR" && $(command -v "$EDITOR") ]]; then
        execute_editor "$EDITOR"
    elif [[ "$SETTINGS_EDITOR" =~ (vim|nano|emacs|micro) && $(command -v "$SETTINGS_EDITOR") ]]; then
        execute_editor "$SETTINGS_EDITOR"
    else
        fallback_editor
    fi
}

# Function to execute the chosen editor on the settings file
#execute_editor() {
#    local editor="$1"
#    if [[ -x "$(command -v "$editor")" ]]; then
#        "$editor" "$(pkg_path)/settings.sh"
#        if [[ $? -eq 0 ]]; then
#            echo "Settings successfully modified."
#        else
#            echo "Error: Failed to modify settings with $editor."
#        fi
#    else
#        echo "Error: $editor is not installed."
#        fallback_editor
#    fi
#}

execute_editor() {
    local editor="$1"
    local error_message="$2"

    check_optdepends "$editor"
    if [[ $? -eq 0 ]]; then
        "$editor" "$(pkg_path)/settings_options.sh"
        log "Opened settings file with editor: $editor"
    else
        log "$error_message"
        fallback_editor
    fi
}


# Function to prompt user for available editors if both EDITOR and SETTINGS_EDITOR fail
fallback_editor() {
    echo "No valid editor found. Please select an editor to use:"
    select editor in "vim" "nano" "micro" "emacs" "Exit"; do
        case $REPLY in
            1) vim "$(pkg_path)/settings.sh"; break;;
            2) nano "$(pkg_path)/settings.sh"; break;;
            3) micro "$(pkg_path)/settings.sh"; break;;
            4) emacs "$(pkg_path)/settings.sh"; break;;
            5) echo "Exiting without modifying settings."; exit 0;;
            *) echo "Invalid selection. Please choose again.";;
        esac
    done
}

# Function to determine the package path dynamically
pkg_path() {
    if [[ -L "$0" ]]; then
        dirname "$(readlink -f "$0")"
    else
        dirname "$0"
    fi
}
