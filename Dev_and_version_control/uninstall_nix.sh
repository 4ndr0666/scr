#!/bin/bash

# Uninstall Nix: A script to completely remove Nix from the system.

# Stop Nix daemon if it's running
sudo systemctl stop nix-daemon.socket
sudo systemctl stop nix-daemon.service

# Disable Nix daemon services
sudo systemctl disable nix-daemon.socket
sudo systemctl disable nix-daemon.service

# Remove Nix files and directories
sudo rm -rf /nix
rm -rf ~/.nix-profile
rm -rf ~/.nix-defexpr
rm -rf ~/.nix-channels
rm -rf ~/.config/nix

# Remove Nix-related lines from shell configuration files
# This step might need to be adjusted based on the shell and its configuration file
sed -i '/nix/d' ~/.bashrc
sed -i '/nix/d' ~/.zshrc
sed -i '/nix/d' ~/.profile

# Reload the shell configuration
source ~/.bashrc
source ~/.zshrc
source ~/.profile

# Remove Nix users and groups
sudo userdel nixbld
sudo groupdel nixbld

# Remove any additional Nix build users (nixbld1, nixbld2, ...)
for i in {1..32}; do
  sudo userdel nixbld$i
  sudo groupdel nixbld$i
done

# Optional: Remove entries from /etc/passwd and /etc/group if they still exist
# Caution: Only do this if you are sure about what you're doing
# sudo sed -i '/nix/d' /etc/passwd
# sudo sed -i '/nix/d' /etc/group

# Clean up systemd units if they were installed
sudo find /etc/systemd -name '*nix*' -delete

# Clean up any remaining Nix-related files and directories
sudo find /etc -name '*nix*' -delete
find ~ -name '*nix*' -delete

# Notify user
echo "Nix has been uninstalled from the system."
