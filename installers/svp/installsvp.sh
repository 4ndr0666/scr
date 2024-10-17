#!/bin/bash

# Helper functions for status and error handling
echo_status() {
    echo -e "\e[1;32m$1\e[0m"
}

handle_error() {
    echo -e "\e[1;31mError: $1\e[0m" >&2
    exit 1
}

# Constants for the build directory
BUILD_DIR="$HOME/build"
mkdir -p "$BUILD_DIR"

# Ensure the script runs with sudo
if [ "$(id -u)" -ne 0 ]; then
    sudo "$0" "$@"
    exit $?
fi

# Update system and install basic and required packages
update_and_install() {
    echo_status "Updating system and ensuring yay is installed..."
    sudo pacman -Syu --needed base-devel git qt5-base qt5-declarative qt5-svg libmediainfo lsof vapoursynth mkvtoolnix-cli python cython opencl-headers ocl-icd opencl-driver
    if ! command -v yay &> /dev/null; then
        git clone https://aur.archlinux.org/yay.git "$BUILD_DIR/yay"
        cd "$BUILD_DIR/yay" || exit
        makepkg -si
    fi
    echo_status "Installing FFmpeg and other dependencies..."
    yay -S ffmpeg-git intel-compute-runtime --needed
}

# Install AUR packages
install_aur_packages() {
    echo_status "Installing AUR packages..."
    yay -S rsound spirv-cross mpv-full --needed
}

# Enable and start necessary services
configure_services() {
    echo_status "Configuring system services..."
    sudo systemctl enable avahi-daemon.service
    sudo systemctl start avahi-daemon.service
}

# Build and configure Vapoursynth
build_vapoursynth() {
    echo_status "Building Vapoursynth and its dependencies..."
    clone_or_pull "https://github.com/sekrit-twc/zimg.git" "$BUILD_DIR/zimg"
    cd "$BUILD_DIR/zimg" || exit
    ./autogen.sh && ./configure && make -j"$(nproc)" && sudo make install

    clone_or_pull "https://github.com/vapoursynth/vapoursynth.git" "$BUILD_DIR/vapoursynth"
    cd "$BUILD_DIR/vapoursynth" || exit
    ./autogen.sh && ./configure && make -j"$(nproc)" && sudo make install
    sudo ldconfig
    PYTHON_VERSION=$(python3 --version | cut -d ' ' -f 2 | cut -d '.' -f 1,2)
    sudo ln -sf /usr/local/lib/python${PYTHON_VERSION}/site-packages/vapoursynth.so /usr/lib/python${PYTHON_VERSION}/site-packages/
}

# Configure MPV with Vapoursynth support
configure_mpv() {
    echo_status "Configuring MPV with Vapoursynth support..."
    clone_or_pull "https://github.com/mpv-player/mpv-build.git" "$BUILD_DIR/mpv-build"
    cd "$BUILD_DIR/mpv-build" || exit
    ./use-ffmpeg-release
    echo --enable-libx264 >> ffmpeg_options
    echo --enable-nvdec >> ffmpeg_options
    echo --enable-vaapi >> ffmpeg_options
    echo --enable-vapoursynth >> mpv_options
    echo --enable-libmpv-shared >> mpv_options
    ./rebuild -j"$(nproc)" && sudo ./install
    mkdir -p ~/.config/mpv
    echo "--input-ipc-server=/tmp/mpvsocket" >> ~/.config/mpv/mpv.conf
    echo "--hwdec=auto-copy" >> ~/.config/mpv/mpv.conf
}

# Provide help and usage instructions
cli_help() {
    echo_status "Available Commands:"
    echo "1) Update and Install Base Packages"
    echo "2) Install AUR Packages"
    echo "3) Configure System Services"
    echo "4) Install and Configure Vapoursynth"
    echo "5) Configure MPV"
    echo "6) Exit"
}

# Main menu system for interactive execution
main_menu() {
    while true; do
        echo_status "Select an option:"
        read -rp "Enter choice (1-6): " choice
        case "$choice" in
            1) update_and_install ;;
            2) install_aur_packages ;;
            3) configure_services ;;
            4) build_vapoursynth ;;
            5) configure_mpv ;;
            6) cli_help ;;
            7) echo "Exiting script."; break ;;
            *) echo "Invalid option, try again." ;;
        esac
    done
}

# Utility function to clone or update git repositories
clone_or_pull() {
    local repo_url="$1"
    local dest_dir="$2"
    if [ ! -d "$dest_dir/.git" ]; then
        echo_status "Cloning into $dest_dir..."
        git clone "$repo_url" "$dest_dir"
    else
        echo_status "Updating $dest_dir..."
        git -C "$dest_dir" pull
    fi
}

# Start the main menu
main_menu
