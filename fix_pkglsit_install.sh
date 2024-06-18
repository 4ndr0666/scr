#!/bin/bash

# Function to handle graceful exit
cleanup() {
    echo "Script terminated. Cleaning up..."
    exit 1
}

# Trap signals for graceful exit
trap cleanup SIGINT SIGTERM

# Function to prompt user for confirmation
confirm() {
    read -p "Do you want to proceed with this step? (y/n): " choice
    case "$choice" in 
        y|Y ) return 0;;
        n|N ) return 1;;
        * ) echo "Invalid choice"; confirm;;
    esac
}

# Function to handle package removal
remove_package() {
    local package=$1
    if yay -Qi $package > /dev/null 2>&1; then
        echo "Removing $package..."
        if yay -Rdd $package; then
            echo "Successfully removed $package."
        else
            echo "Failed to remove $package. Please check for errors and try again."
            exit 1
        fi
    else
        echo "$package is not installed."
    fi
}

# Function to remove corrupted package entry
remove_corrupted_entry() {
    local package=$1
    echo "Removing corrupted entry for $package..."
    sudo rm -rf /var/lib/pacman/local/${package}-*
}

echo "Starting the automated package conflict resolution script..."

# Step 1: Remove conflicting package bemenu-git
if confirm; then
    echo "Step 1: Removing conflicting package bemenu-git and its dependencies..."
    # Remove the conflicting package and dependencies that require it
    if yay -Rdd bemenu-git bemenu-wayland-git pinentry-bemenu; then
        echo "Successfully removed bemenu-git and its dependencies."
    else
        echo "Failed to remove bemenu-git. Please check for errors and try again."
        exit 1
    fi
else
    echo "Skipping Step 1."
fi

# Step 2: Fix missing desc file by reinstalling the package
if confirm; then
    echo "Step 2: Fixing missing desc file by removing corrupted entry and reinstalling projectm..."
    remove_corrupted_entry "projectm"
    if yay -S --overwrite "*" projectm; then
        echo "Successfully reinstalled projectm."
    else
        echo "Failed to reinstall projectm. Please check for errors and try again."
        exit 1
    fi
else
    echo "Skipping Step 2."
fi

# Step 3: Clear package cache and update system
if confirm; then
    echo "Step 3: Clearing package cache..."
    if yay -Scc --noconfirm; then
        echo "Successfully cleared package cache."
    else
        echo "Failed to clear package cache. Please check for errors and try again."
        exit 1
    fi
else
    echo "Skipping package cache clearance."
fi

if confirm; then
    echo "Step 3: Updating package database..."
    if yay -Syyu; then
        echo "Successfully updated package database."
    else
        echo "Failed to update package database. Please check for errors and try again."
        exit 1
    fi
else
    echo "Skipping package database update."
fi

# Step 4: Remove orphaned packages
if confirm; then
    echo "Step 4: Removing orphaned packages..."
    orphaned_packages=$(pacman -Qtdq)
    if [ -n "$orphaned_packages" ]; then
        if yay -Rns $orphaned_packages; then
            echo "Successfully removed orphaned packages."
        else
            echo "Failed to remove orphaned packages. Please check for errors and try again."
            exit 1
        fi
    else
        echo "No orphaned packages found."
    fi
else
    echo "Skipping Step 4."
fi

# Step 5: Manual conflict resolution (optional)
echo "Step 5: Manual conflict resolution (optional)"
echo "If you need to manually resolve conflicts, please edit the file /var/lib/pacman/local/projectm-3.1.12-4/desc using:"
echo "sudo nano /var/lib/pacman/local/projectm-3.1.12-4/desc"
confirm && sudo nano /var/lib/pacman/local/projectm-3.1.12-4/desc

# Step 6: Sync and update package databases
if confirm; then
    echo "Step 6: Syncing and updating package databases..."
    if yay -Syu; then
        echo "Successfully synced and updated package databases."
    else
        echo "Failed to sync and update package databases. Please check for errors and try again."
        exit 1
    fi
else
    echo "Skipping Step 6."
fi

echo "Script completed successfully!"
