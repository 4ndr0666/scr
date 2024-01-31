#!/bin/bash

# Check if the script is run as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# Check if lspci is available
if ! command -v lspci &> /dev/null
then
    echo "lspci could not be found, please install pciutils package."
    exit
fi

gpu_type=$(lspci)

# Update package lists
pacman -Sy

if grep -E -w "NVIDIA|GeForce" <<< ${gpu_type}; then
    pacman -S --noconfirm --needed nvidia && nvidia-xconfig
elif lspci | grep 'VGA' | grep -E -w "Radeon|AMD"; then
    pacman -S --noconfirm --needed xf86-video-amdgpu
elif grep -E -w "Integrated Graphics Controller" <<< ${gpu_type}; then
    pacman -S --noconfirm --needed libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils lib32-mesa
elif grep -E -w "Intel Corporation UHD" <<< ${gpu_type}; then
    pacman -S --needed --noconfirm libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils lib32-mesa
fi

# Check for any errors after the command executions
if [ $? -ne 0 ]; then
   echo "There was a problem installing the package. Exiting."
   exit 1
fi

echo "GPU driver installed successfully."

# You can add specific commands to verify if the driver is correctly installed and is being used.
