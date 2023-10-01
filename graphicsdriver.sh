#!/bin/bash

# --- Privilege escalation
if [ "$(id -u)" -ne 0 ]; then
    sudo "$0" "$@"
    exit $?
fi

# --- Error handling with trap
trap "echo 'Script interrupted by user'; exit 1" INT

# Check if a command exists
command_exists() {
  command -v "$1" &> /dev/null
}

# Install a package using pacman
install_pacman_pkg() {
  pacman -S --noconfirm --needed "$1" || {
    echo "Error installing $1. Exiting..."
    exit 1
  }
}

# Install a package using yay
install_yay_pkg() {
  yay -S --noconfirm "$1" || {
    echo "Error installing $1. Exiting..."
    exit 1
  }
}

# --- Check if lspci is available
check_lspci() {
    if ! command -v lspci &> /dev/null; then
        echo "lspci could not be found, please install pciutils package."
        exit 1
    fi
}

# --- Update package lists
update_packages() {
    echo "Updating packages list..."
    pacman -Sy --noconfirm || {
        echo "Error updating package list. Exiting..."
        exit 1
    }
}

# --- Check for yay
check_yay() {
    if ! command -v yay &>/dev/null; then
        echo "yay package manager is not installed. Installing now..."
        pacman -S yay --noconfirm || {
            echo "Error installing yay. Exiting..."
            exit 1
        }
    fi
}


# --- Install GPU drivers
install_gpu_drivers() {
    gpu_type=$(lspci)

    # Install appropriate GPU driver
    install_gpu_driver() {
      if grep -E -w "NVIDIA|GeForce" <<< ${gpu_type}; then
        install_pacman_pkg "nvidia"
        nvidia-xconfig
      elif lspci | grep 'VGA' | grep -E -w "Radeon|AMD"; then
        install_pacman_pkg "xf86-video-amdgpu"
      elif grep -E -w "Integrated Graphics Controller" <<< ${gpu_type}; then
        install_pacman_pkg "libva-intel-driver"
        # ... (rest of your code)
      fi
    }

    # Call the function to install GPU driver
    install_gpu_driver
}  # <-- Ensure this closing brace is present


# Call the function to install GPU driver
install_gpu_driver

echo "Basic GPU drivers installed successfully."
echo "Checking to ensure proper dependencies are installed..."

# --- Mesa
if ! pacman -Qq | grep -qw mesa; then
    echo "Installing mesa..."
    pacman -S mesa --noconfirm || {
        echo "Error installing mesa. Exiting..."
        exit 1
    }
else
    echo "mesa is already installed. Skipping..."
fi

# --- Vulkan-intel
if ! pacman -Qq | grep -qw vulkan-intel; then
    echo "Installing vulkan-intel..."
    pacman -S vulkan-intel --noconfirm || {
        echo "Error installing vulkan-intel. Exiting..."
        exit 1
    }
else
    echo "vulkan-intel is already installed. Skipping..."
fi

# --- Intel-compute-runtime
if ! pacman -Qq | grep -qw intel-compute-runtime; then
    echo "Installing intel-compute-runtime from AUR..."
    yay -S intel-compute-runtime --noconfirm || {
        echo "Error installing intel-compute-runtime. Exiting..."
        exit 1
    }
else
    echo "intel-compute-runtime is already installed. Skipping..."
fi

# Install additional packages
install_additional_pkgs() {
  declare -a packages=("qt5-base" "qt5-declarative" "qt5-svg" "libmediainfo" "lsof" "vapoursynth" "zimg" "cython")
  for pkg in "${packages[@]}"; do
    if ! pacman -Qq | grep -qw "$pkg"; then
      install_yay_pkg "$pkg"
    else
      echo "$pkg is already installed. Skipping..."
    fi
  done
}

# Call the function to install additional packages
install_additional_pkgs

# Verify installation
verify_installation() {
  GLXINFO_OUTPUT=$(glxinfo 2>/dev/null | grep "OpenGL renderer")
  if [ $? -eq 0 ]; then
    echo "Verification successful!"
    echo "$GLXINFO_OUTPUT"
  else
    echo "Verification failed. 'glxinfo' might not be installed or there's an issue with the GPU setup."
  fi
}

# Call the function to verify installation
verify_installation

# Final message
echo "All drivers installed!"


# Verify VapourSynth installation
verify_vapoursynth() {
  VSPY_INFO=$(vspipe --version 2>&1)
  if [ $? -eq 0 ]; then
    echo "Verification successful!"
    echo "$VSPY_INFO"
  else
    echo "Verification failed. There might be an issue with the VapourSynth setup."
  fi
}

# Install additional packages for SVP4 and dependencies for ffmpeg and mpv
install_additional_dependencies() {
  paru -S mkvtoolnix-cli libssl-dev libfribidi-dev libharfbuzz-dev libluajit-5.1-dev libx264-dev xorg-dev libxpresent-dev libegl1-mesa-dev libfreetype-dev libfontconfig-dev libffmpeg-nvenc-dev libva-dev libdrm-dev libplacebo-dev libasound2-dev libpulse-dev --noconfirm || {
    echo "Error installing additional dependencies. Exiting..."
    exit 1
  }
}

# Build mpv with Vapoursynth support
build_mpv() {
  git clone https://github.com/mpv-player/mpv-build.git
  cd mpv-build
  ./use-ffmpeg-release
  echo --enable-libx264 >> ffmpeg_options
  echo --enable-nvdec >> ffmpeg_options
  echo --enable-vaapi >> ffmpeg_options
  echo --enable-vapoursynth >> mpv_options
  echo --enable-libmpv-shared >> mpv_options
  ./rebuild -j4
  sudo ./install
  cd ..
}

# Call the functions
verify_vapoursynth
install_additional_dependencies
build_mpv

# Final message
echo "Process complete!"
