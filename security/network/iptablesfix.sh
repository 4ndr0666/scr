#!/bin/bash
# shellcheck disable=all

# Function to flush iptables rules
flush_iptables() {
    echo "Flushing all iptables rules..."

    # Flush all rules, delete all chains, and reset all counters
    sudo iptables -F
    sudo iptables -X
    sudo iptables -t nat -F
    sudo iptables -t nat -X
    sudo iptables -t mangle -F
    sudo iptables -t mangle -X
    sudo iptables -t raw -F
    sudo iptables -t raw -X

    # Set default policies to ACCEPT (you can change this as needed)
    sudo iptables -P INPUT ACCEPT
    sudo iptables -P FORWARD ACCEPT
    sudo iptables -P OUTPUT ACCEPT

    echo "Flushed all iptables rules."
}

# Function to reset UFW to default settings
reset_ufw() {
    echo "Resetting UFW to default settings..."

    # Reset UFW and disable it
    sudo ufw --force reset

    # Enable UFW with default settings
    sudo ufw default deny incoming
    sudo ufw default allow outgoing

    # Enable UFW
    sudo ufw enable

    echo "UFW has been reset and enabled with default settings."
}

# Function to load kernel modules
load_kernel_modules() {
    echo "Loading necessary kernel modules..."
    sudo modprobe ip_tables
    sudo modprobe iptable_filter
    sudo modprobe nf_conntrack
    sudo modprobe nf_conntrack_ipv4
    sudo modprobe nf_conntrack_ipv6

    # Verify that modules are loaded
    lsmod | grep -E 'ip_tables|iptable_filter|nf_conntrack' >/dev/null
    if [ $? -ne 0 ]; then
        echo "Error: Failed to load necessary kernel modules."
        exit 1
    fi
    echo "Kernel modules loaded successfully."
}

# Function to switch to iptables-legacy backend
switch_to_legacy() {
    echo "Switching to iptables-legacy backend..."
    sudo update-alternatives --set iptables /usr/bin/iptables-legacy
    sudo update-alternatives --set ip6tables /usr/bin/ip6tables-legacy

    # Verify the switch
    iptables --version | grep 'legacy' >/dev/null
    if [ $? -ne 0 ]; then
        echo "Error: Failed to switch to iptables-legacy backend."
        exit 1
    fi
    echo "Switched to iptables-legacy backend successfully."
}

# Function to reinstall iptables and ufw
reinstall_packages() {
    echo "Reinstalling iptables and ufw..."
    sudo pacman -Rns --noconfirm iptables ufw
    sudo pacman -S --noconfirm iptables ufw

    # Verify installation
    pacman -Q iptables ufw >/dev/null
    if [ $? -ne 0 ]; then
        echo "Error: Failed to reinstall iptables and/or ufw."
        exit 1
    fi
    echo "Reinstalled iptables and ufw successfully."
}

# Function to update the system
update_system() {
    echo "Updating the system..."
    sudo pacman -Syu --noconfirm

    # Verify update
    if [ $? -ne 0 ]; then
        echo "Error: Failed to update the system."
        exit 1
    fi
    echo "System updated successfully."
}

# Main script execution
echo "Starting automated troubleshooting for iptables and ufw issues on Arch Linux..."

# Step 1: Load necessary kernel modules
load_kernel_modules

# Step 2: Switch to iptables-legacy backend
switch_to_legacy

# Step 3: Reinstall iptables and ufw
reinstall_packages

# Step 4: Update the system
update_system

# Step 5: Flush all iptables rules
flush_iptables

# Step 6: Reset UFW to default settings
reset_ufw

echo "All steps completed successfully. Your iptables and ufw setup should now be functioning correctly with default settings."
