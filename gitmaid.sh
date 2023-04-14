#!/bin/bash

# Prompt user for SEARCHPATH
read -p "Enter the search path (default: $PWD): " SEARCHPATH
SEARCHPATH=${SEARCHPATH:-$PWD}

# Prompt user for IGNORE
read -p "Enter directories to ignore (default: 'Third-Party', separate by spaces): " -a IGNORE
IGNORE=${IGNORE:-('Third-Party')}


# Set the search path
if [[ -z "$1" ]]; then
    if [[ -z $SEARCHPATH ]]; then
        SEARCHPATH=$PWD
    fi
else
    if [[ $1 == '-p' ]]; then
        SEARCHPATH=$PWD
    else
        SEARCHPATH="$1"
    fi
fi

if [[ ! -d "$SEARCHPATH" ]]; then
    echo "The supplied path does not resolve to a valid directory"
    echo "Aborting..."
    exit 1
fi

cd "$SEARCHPATH"

# Find all directories that have a .git directory in them
dirty_repos=0
clean_repos=0
for git_dir in $(find . -type d -name .git | sort | sed "s/\/\.git//"); do
    # Save the current working directory before changing directories
    pushd . >/dev/null
    cd "$git_dir"

    # Check if repository is dirty or clean
    git_status=$(git status --porcelain)
    if [[ -n "$git_status" ]]; then
        dirty_repos=$((dirty_repos+1))
        echo -e "${git_dir} \t \033[1;31mDirty\033[0m"
    else
        clean_repos=$((clean_repos+1))
        echo -e "${git_dir} \t \033[1;32mClean\033[0m"
    fi

    # Return to the starting directory
    popd >/dev/null
done

echo "Repositories checked:"
echo "  - Dirty: ${dirty_repos}"
echo "  - Clean: ${clean_repos}"

if [[ $dirty_repos -gt 0 ]]; then
    echo -e "\n\033[1;31mSome repositories are dirty. Please check the above output for details.\033[0m"
else
    echo -e "\n\033[1;32mAll repositories are clean!\033[0m"
fi
