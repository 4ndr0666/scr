#!/bin/bash
# shellcheck disable=all

# Check TPM status
echo "Checking TPM status..."
sudo tpm2_getcap -c properties-fixed

# Ensure TPM modules are loaded
echo "Verifying TPM modules..."
sudo modprobe tpm
sudo modprobe tpm_crb
sudo modprobe tpm_tis
sudo modprobe tpm_tis_core

# Check if TPM modules are loaded
echo "Checking loaded modules..."
lsmod | grep tpm

# Look for TPM-related errors in logs
echo "Checking system logs for TPM errors..."
dmesg | grep -i tpm

# Ensure necessary TPM packages are installed
echo "Installing TPM tools and libraries..."
sudo pacman -S tpm2-tools tpm2-abrmd

# Update initramfs
echo "Updating initramfs..."
sudo mkinitcpio -P

echo "TPM troubleshooting completed. Please check the outputs for any errors or issues."

