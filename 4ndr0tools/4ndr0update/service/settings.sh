#!/bin/bash

modify_settings() {
    # Check if EDITOR is set and valid
    if [[ -z "$EDITOR" && -n "$SUDO_USER" ]]; then
            EDITOR="$(sudo -i -u "$SUDO_USER" env | awk '/^EDITOR=/{ print substr($0, 8) }')"
    fi
    
    if [[ -n "$EDITOR" ]]; then
            execute_editor "$EDITOR" "\nEDITOR environment variable of $EDITOR is not valid"
    elif [[ "$SETTINGS_EDITOR" =~ (vim|neovim|nano|emacs|micro|lite-xl) && $(command -v "$SETTINGS_EDITOR") ]]; then
        execute_editor "$SETTINGS_EDITOR"
    else
        fallback_editor
    fi
}

# Function to execute the chosen editor on the settings file
execute_editor() {
    local editor="$1"
    if [[ -x "$(command -v "$editor")" ]]; then
        if "$editor" "$(pkg_path)/settings.sh"; then
            echo "Settings successfully modified."
        else
            echo "Error: Failed to modify settings with $editor."
        fi
    else
        echo "Error: $editor is not installed."
        fallback_editor
    fi
}

# Function to prompt user for available editors if both EDITOR and SETTINGS_EDITOR fail
fallback_editor() {
    printf "\nNo valid editor found. Please select an editor to use\n" 1>&2
    select editor in "vim" "neovim" "nano" "emacs" "micro" "lite-xl" "Exit"; do
        case $REPLY in
            1) vim "$(pkg_path)/settings.sh"; break;;
            2) neovimn "$(pkg_path)/settings.sh"; break;;
            3) nano "$(pkg_path)/settings.sh"; break;;
	    4) emacs "$(pkg_path)/settings.sh"; break;;
            5) micro "$(pkg_path)/settings.sh"; break;;
            6) lite-xl "$(pkg_path)/settings.sh"; break;;
            7) echo "Exiting without modifying settings."; exit 0;;
            *) echo "Invalid selection. Please choose again.";;
        esac
    done
}

# Function to determine the package path dynamically
#pkg_path() {
#    if [[ -L "$0" ]]; then
#        dirname "$(readlink -f "$0")"
#    else
#        dirname "$0"
#    fi
#}
