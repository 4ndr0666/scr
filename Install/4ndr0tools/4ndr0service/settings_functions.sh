#!/bin/bash
# File: settings_functions.sh
# Author: 4ndr0666
# Date: 10-20-24
# This file contains functions to manage and modify settings for the Service Optimization Suite.

# ==================================== // SETTINGS_FUNCTIONS.SH //
modify_settings() {
    
    log "Modifying settings..."

    if [[ -z "$EDITOR" && -n "$SUDO_USER" ]]; then
        EDITOR="$(sudo -i -u $SUDO_USER env | awk '/^EDITOR=/{ print substr($0, 8) }')"
    fi

    if [[ -n "$EDITOR" ]]; then
        execute_editor "$EDITOR" "\nEDITOR environment variable of $EDITOR is not valid"
    elif [[ "$SETTINGS_EDITOR" =~ (vim|neovim|nano|emacs|micro|lite-xl) && $(command -v "$SETTINGS_EDITOR") ]]; then
        execute_editor "$SETTINGS_EDITOR"
    else
        fallback_editor
    fi

    log "Settings modified successfully."     
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

    if [[ -x "$(command -v "$editor")" ]]; then
        "$editor" "$PKG_PATH/settings.sh"    
        check_optdepends "$editor"
        if [[ $? -eq 0 ]]; then
            echo "Settings successfully modified."
        else
            echo "Error: Failed to modify settings with $editor."
        fi
    else
        echo "Error: $editor is not installed."
        fallback_editor
    fi
}

fallback_editor() {
    printf "\nNo valid editor found. Please select an editor to use\n" 1>&2
    select editor in "vim" "neovim" "nano" "emacs" "micro" "lite-xl" "Exit"; do
        case $REPLY in
            1) vim "$PKG_PATH/settings.sh"; break;;
            2) neovimn "$PKG_PATH/settings.sh"; break;;
            3) nano "$PKG_PATH/settings.sh"; break;;
            4) emacs "$PKG_PATH/settings.sh"; break;;
            5) micro "$PKG_PATH/settings.sh"; break;;
            6) lite-xl "$PKG_PATH/settings.sh"; break;;
            7) echo "Exiting without modifying settings."; exit 0;;
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
