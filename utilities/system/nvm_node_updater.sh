#!/bin/bash
# shellcheck disable=all

# NVM_NODE_UPDATER
# v2.0.0

# Check for the shell being used
if [ -n "$ZSH_VERSION" ]; then
    SHELL_TYPE="zsh"
elif [ -n "$BASH_VERSION" ]; then
    SHELL_TYPE="bash"
else
    echo "Unsupported shell. Please use either bash or zsh."
    exit 1
fi

# Source NVM for both zsh and bash
export NVM_DIR="$HOME/.config/nvm"

if [ -s "$NVM_DIR/nvm.sh" ]; then
    if [ "$SHELL_TYPE" = "zsh" ]; then
        source "$NVM_DIR/nvm.sh"
    elif [ "$SHELL_TYPE" = "bash" ]; then
        . "$NVM_DIR/nvm.sh"
    fi
else
    echo "NVM script not found at $NVM_DIR/nvm.sh"
    exit 1
fi

if [ -s "$NVM_DIR/bash_completion" ]; then
    if [ "$SHELL_TYPE" = "zsh" ]; then
        source "$NVM_DIR/bash_completion"
    elif [ "$SHELL_TYPE" = "bash" ]; then
        . "$NVM_DIR/bash_completion"
    fi
else
    echo "NVM bash completion script not found at $NVM_DIR/bash_completion"
fi

# Function to print messages in blue
PRINT_BLUE() { 
    while read; do
        printf '\e[44m%s\e[0m\n' "[STASH NODE-UPDATE] $REPLY";
    done
}

nvm_node_updater() {
    # Check for the current NodeJS version
    NODE_VERSION_INSTALLED=$(nvm current)
    if [ -z "$NODE_VERSION_INSTALLED" ]; then
        echo "Failed to detect the current Node.js version. Is NVM properly installed and initialized?"
        exit 1
    fi

    # Update to the latest NodeJS version
    echo "Updating Node.js to the latest stable release..." | PRINT_BLUE
    nvm install node --reinstall-packages-from=node

    # Set default Node.js version to the latest
    nvm alias default node
    nvm use default

    echo "Node.js is now updated to the latest version." | PRINT_BLUE
    
    # Check for latest NPM package versions
    NPM_GLOBAL_PACKAGES_LIST=($(npm ls -g --depth=0 --parseable | grep -Eo '[^/]+$'))
    NPM_GLOBAL_PACKAGES_COUNT=${#NPM_GLOBAL_PACKAGES_LIST[@]}
    NPM_GLOBAL_PACKAGES_OUTDATED_LIST=($(npm outdated -g --parseable | cut -d: -f2 | grep -Eo '[^/]+$'))
    NPM_GLOBAL_PACKAGES_OUTDATED_COUNT=${#NPM_GLOBAL_PACKAGES_OUTDATED_LIST[@]}
     
    if [ "$NPM_GLOBAL_PACKAGES_OUTDATED_COUNT" -gt 0 ]; then
        # Update to latest NPM package versions
        echo "Number of global packages requiring update: $NPM_GLOBAL_PACKAGES_OUTDATED_COUNT" | PRINT_BLUE
        echo "-> ${NPM_GLOBAL_PACKAGES_OUTDATED_LIST[*]}" | PRINT_BLUE
        
        npm install -g "${NPM_GLOBAL_PACKAGES_OUTDATED_LIST[@]}"
    else
        echo "All $NPM_GLOBAL_PACKAGES_COUNT global packages are up to date." | PRINT_BLUE
        echo "${NPM_GLOBAL_PACKAGES_LIST[*]}" | PRINT_BLUE
    fi
}

# Run the updater
nvm_node_updater
