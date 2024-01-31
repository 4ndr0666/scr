#!/bin/bash

# Uninstall Nix: A script to completely remove Nix from the system.

# Stop Nix daemon if it's running
sudo systemctl stop nix-daemon.socket 2>/dev/null
sudo systemctl stop nix-daemon.service 2>/dev/null

# Disable Nix daemon services
sudo systemctl disable nix-daemon.socket 2>/dev/null
sudo systemctl disable nix-daemon.service 2>/dev/null

# Remove Nix files and directories
sudo rm -rf /nix
rm -rf ~/.nix-profile
rm -rf ~/.nix-defexpr
rm -rf ~/.nix-channels
rm -rf ~/.config/nix

# Remove Nix-related lines from user shell configuration files
sed -i '/nix/d' ~/.bashrc
sed -i '/nix/d' ~/.zshrc
sed -i '/nix/d' ~/.profile

# Reload the shell configuration
source ~/.bashrc 2>/dev/null
source ~/.zshrc 2>/dev/null
source ~/.profile 2>/dev/null

# Remove Nix users and groups
# Check if the user or group exists before attempting to delete
for i in $(seq 1 32); do
  if id "nixbld$i" &>/dev/null; then
    sudo userdel "nixbld$i"
  fi
  if getent group "nixbld$i" &>/dev/null; then
    sudo groupdel "nixbld$i"
  fi
done

# List Nix-related files and directories in the user's home
echo "Listing Nix-related files and directories in the home directory:"
find ~ -name '*nix*' -print

# Optional: Prompt for confirmation before deletion
read -p "Do you want to delete these files? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    find ~ -name '*nix*' -exec rm -rf {} +
fi

# Notify user
echo "Nix has been uninstalled from the system."
