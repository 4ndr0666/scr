#!/usr/bin/env bash

# --- // PCUTS.SH // ========
# File: /usr/local/bin/pcuts
# Author: 4ndr0666
# Edited: 3-21-24

# --- // CONSTANTS_AND_COLORS:
BASEPATH=$(dirname "$0")

# Load colors if available
if [ -f "${BASEPATH}/colors.sh" ]; then
    . "${BASEPATH}/colors.sh"
else
    # Basic heading function if colors.sh is not found
    heading() {
        echo "----------------------------------------------------------------------"
        echo "  $1"
        echo "----------------------------------------------------------------------"
        echo
    }
    # Basic color definitions if colors.sh is not found
    grn='\033[0;32m'
    yel='\033[0;33m'
    red='\033[0;31m'
    r='\033[0m'
fi

# Initialize flags
_sync=false
_search=false
_query=false
_files=false

# Store all arguments
args=$@

# --- // FUNCTION_DEFINITIONS ========

# --- // HELP_MENU:
help(){
    heading "HELP"
    echo -e "${grn}pcuts${r}         # Show all pacman commands"
    echo -e "${grn}pcuts${r}${yel} -s${r}    # Sync commands"
    echo -e "${grn}pcuts${r}${yel} -r${r}    # Remote search commands"
    echo -e "${grn}pcuts${r}${yel} -q${r}    # Query commands"
    echo -e "${grn}pcuts${r}${yel} -f${r}    # File management commands"
    echo -e "${grn}pcuts${r}${yel} -h${r}    # Display help menu"
}

# Function to display all pacman commands
show_all_commands(){
    heading "All Pacman Commands"
    sync_commands
    remote_search
    query_commands
    file_operations
}

# Function to display sync commands
sync_commands(){
    heading "Sync Commands"
    echo -e "${grn}pacman -Syu${r}        # Update and upgrade the system"
    echo -e "${grn}pacman -S package${r}  # Install a specific package"
    echo -e "${grn}pacman -R package${r}  # Remove a specific package"
    echo -e "${grn}pacman -Rns package${r}# Remove a package and its dependencies"
    echo -e "${grn}pacman -Syyu${r}       # Force refresh all package databases"
    echo -e "${grn}pacman -Sy package${r} # Sync package database and install a package"
}

# Function for remote search commands
remote_search(){
    heading "Remote Search Commands"
    echo -e "${grn}pacman -Ss query${r}   # Search for a package in the remote repositories"
    echo -e "${grn}pacman -Sl repo${r}    # List all packages in a repository"
}

# Function for query commands
query_commands(){
    heading "Query Commands"
    echo -e "${grn}pacman -Qs query${r}   # Search for a package in the installed packages"
    echo -e "${grn}pacman -Qi package${r} # Display information about an installed package"
    echo -e "${grn}pacman -Ql package${r} # List files installed by a package"
    echo -e "${grn}pacman -Qm${r}         # List foreign (AUR) packages"
    echo -e "${grn}pacman -Qdt${r}        # List orphaned packages"
}

# Function for file management commands
file_operations(){
    heading "File Management Commands"
    echo -e "${grn}pacman -Qo file${r}    # Find which package owns a specific file"
    echo -e "${grn}pacman -F file${r}     # Find a package that provides a specific file"
    echo -e "${grn}pacman -Sc${r}         # Clean the package cache"
    echo -e "${grn}pacman -Scc${r}        # Clean the package cache thoroughly"
    echo -e "${grn}pacman -D --asdeps${r} # Mark packages as dependencies"
    echo -e "${grn}pacman -D --asexplicit${r} # Mark packages as explicitly installed"
}

# Parse command-line arguments
for arg in "$@"; do
    case $arg in
        -s|--sync)
            _sync=true
            ;;
        -r|--remote)
            _search=true
            ;;
        -q|--query)
            _query=true
            ;;
        -f|--files)
            _files=true
            ;;
        -h|--help)
            help
            exit 0
            ;;
        *)
            echo -e "${red}Unknown option: $arg${r}"
            help
            exit 1
            ;;
    esac
done

# Execute based on flags
if [ "$_sync" = true ]; then
    sync_commands
fi

if [ "$_search" = true ]; then
    remote_search
fi

if [ "$_query" = true ]; then
    query_commands
fi

if [ "$_files" = true ]; then
    file_operations
fi

# Default behavior: show all commands if no options are provided
if [ "$_sync" = false ] && [ "$_search" = false ] && [ "$_query" = false ] && [ "$_files" = false ]; then
    show_all_commands
fi
