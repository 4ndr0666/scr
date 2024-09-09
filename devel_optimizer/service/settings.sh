#!/bin/bash

modify_settings() {
    # Attempt to determine the editor if not already set and if there is a SUDO_USER
    if [[ -z "$EDITOR" && -n "$SUDO_USER" ]]; then
        EDITOR="$(sudo -i -u $SUDO_USER env | awk '/^EDITOR=/{ print substr($0, 8) }')"
    fi
    # Use the determined or pre-set editor, or fallback if not valid
    if [[ -n "$EDITOR" ]]; then
        execute_editor "$EDITOR" "\nEDITOR environment variable of $EDITOR is not valid"
    elif [[ "$SETTINGS_EDITOR" =~ (vim|micro|nano) ]]; then
        execute_editor "$SETTINGS_EDITOR"
    else
        fallback_editor
    fi
}
# Function to execute the chosen editor on the settings file
execute_editor() {
    check_optdepends "$1"
    if [[ "$?" == 0 ]]; then
        $1 $(pkg_path)/settings.sh
    else
        printf "${2:-\n$1 is not installed}"
        fallback_editor
    fi
}
# Function to fallback to the default editor if the chosen editor is not available
fallback_editor() {
    printf "\nIncorrect SETTINGS_EDITOR setting -- falling back to default\n" 1>&2
    read
    vim $(pkg_path)/settings.sh
}
