#!/bin/bash

# Automatically escalate privileges if not running as root
if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$0" "$@"
fi

trap "echo 'Script interrupted by user'; exit 1" INT

echo "Starting Intel Graphics GPU driver installation for Arch Linux..."

# Ensure the presence of yay
if ! command -v yay >/dev/null 2>&1; then
    echo "yay is not installed. Installing yay..."
    pacman -S --needed git base-devel --noconfirm
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay && makepkg -si --noconfirm
fi

# Update the system
echo "Updating system..."
pacman -Syu --noconfirm || {
    echo "Error updating the system. Exiting..."
    exit 1
}

# Install necessary packages using yay for both AUR and official repositories
yay -S --needed mesa lib32-mesa libva libva-intel-driver libva-mesa-driver libva-vdpau-driver libva-utils lib32-libva lib32-libva-intel-driver lib32-libva-mesa-driver lib32-libva-vdpau-driver intel-ucode iucode-tool vulkan-intel lib32-vulkan-intel intel-gmmlib intel-graphics-compiler intel-media-driver intel-media-sdk intel-opencl-clang libmfx clinfo mesa vulkan-intel intel-compute-runtime intel-gpu-tools --noconfirm

# Performing enhanced error checks with clinfo
echo "Performing enhanced error checks with clinfo..."
if ! command -v clinfo >/dev/null 2>&1; then
    echo "clinfo command not found after installation. Exiting..."
    exit 1
fi

# Check for OpenCL compatibility
if ! OPENCL_VERSION=$(clinfo | grep "OpenCL API version:" | head -n 1); then
    echo "OpenCL compatibility check failed. Please ensure your hardware supports OpenCL."
    exit 1
else
    echo "OpenCL compatibility: $OPENCL_VERSION"
fi

# Check for error correction support
ERROR_CORRECTION=$(clinfo | grep -i "Error correction support" | head -n 1)
if [[ "$ERROR_CORRECTION" == *"No"* ]]; then
    echo "Warning: Error correction not supported. This may not be critical for most tasks."
fi

# Verify installation with glxinfo, installing it first if necessary
if ! command -v glxinfo >/dev/null 2>&1; then
    echo "'glxinfo' is not installed. Installing mesa-demos for glxinfo..."
    pacman -S mesa-demos --noconfirm
fi

echo "Verifying installation..."
if GLXINFO_OUTPUT=$(glxinfo | grep "OpenGL renderer"); then
    echo "Verification successful! OpenGL renderer info:"
    echo "$GLXINFO_OUTPUT"
else
    echo "Verification failed. There might be an issue with the GPU setup."
fi

echo "Installation complete!"
