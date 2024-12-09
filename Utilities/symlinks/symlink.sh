#!/bin/bash

# Text styling
BOLD=$(tput bold)
NORMAL=$(tput sgr0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)

# Function to create symbolic links
create_links() {
    SOURCE_FILE=$1
    shift
    TARGET_FILES=$@
    echo "${BOLD}${GREEN}Creating symbolic links...${NORMAL}"
    for TARGET in $TARGET_FILES; do
        echo "Creating symbolic link: ${TARGET} -> ${SOURCE_FILE}"
        ln -s $SOURCE_FILE $TARGET
    done
    echo "${BOLD}${GREEN}Done.${NORMAL}"
}

# Function to remove symbolic links
remove_links() {
    LINKS=$@
    echo "${BOLD}${RED}Removing symbolic links...${NORMAL}"
    for LINK in $LINKS; do
        if [ -L $LINK ]; then
            echo "Removing symbolic link: ${LINK}"
            unlink $LINK
        else
            echo "${LINK} is not a symbolic link. Skipping."
        fi
    done
    echo "${BOLD}${GREEN}Done.${NORMAL}"
}

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 create|remove source_file target_files"
    exit 1
fi

# Main logic
# --- // AUTO_ESCALATE:
if [ "$(id -u)" -ne 0 ]; then
      sudo "$0" "$@"
    exit $?
fi
ACTION=$1
shift

case $ACTION in
    "create")
        create_links $@
        ;;
    "remove")
        remove_links $@
        ;;
    *)
        echo "Invalid action. Use 'create' or 'remove'."
        exit 1
        ;;
esac
