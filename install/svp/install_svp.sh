#!/usr/bin/env bash
# svpinstaller.sh
#Author: 4ndr0666
#Edited: 3-27-24
#
# --- // SVPINSTALLER.SH // ========

set -eu
set -o pipefail

# Global constants
BUILD_DIR="$HOME/build"
SVP_LOGFILE="$HOME/svp_setup.log"

# Helper function: Print status messages in green
echo_status() {
    echo -e "\e[1;32m$1\e[0m"
}

# Helper function: Print errors in red and exit
handle_error() {
    echo -e "\e[1;31mError: $1\e[0m" >&2
    exit 1
}

# Function 1: Ensure the script is run as root (for package installation)
ensure_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo_status "Escalating privileges via sudo..."
        sudo "$0" "$@"
        exit $?
    fi
}

# Function 2: Update system and install base dependencies and an AUR helper (yay)
update_and_install() {
    echo_status "Updating system and installing base packages..."
    sudo pacman -Syu --needed base-devel git || handle_error "System update failed."
    if ! command -v yay &>/dev/null; then
        mkdir -p "$BUILD_DIR"
        cd "$BUILD_DIR" || handle_error "Cannot change to build directory."
        git clone https://aur.archlinux.org/yay.git || handle_error "Failed to clone yay."
        cd yay || handle_error "Cannot enter yay directory."
        makepkg -si || handle_error "Failed to build yay."
    fi
}

# Function 3: Install required packages for SVP4 and transcoding
install_svp_packages() {
    echo_status "Installing required packages..."
    sudo pacman -S --needed qt5-base qt5-declarative qt5-svg libmediainfo lsof vapoursynth \
        mkvtoolnix-cli python cython opencl-headers ocl-icd opencl-driver || handle_error "Pacman install failed."
#    yay -S --needed ffmpeg-git intel-compute-runtime || handle_error "AUR package install failed."
    yay -S --needed ffmpeg-git alsa-lib aom bzip2 fontconfig fribidi gmp gnutls gsm jack lame libass libavc1394 libbluray libbs2b libdav1d libdrm libfreetype libgl libiec61883 libjxl libmodplug libopenmpt libpulse librav1e libraw1394 librsvg-2 libsoxr libssh libtheora libva libva-drm libva-x11 libvdpau libvidstab libvorbisenc libvorbis libvpx libwebp libx11 libx264 libx265 libxcb libxext libxml2 libxv libxvidcore libzimg ocl-icd onevpl opencore-amr openjpeg2 opus sdl2 speex srt svt-av1 v4l-utils vmaf vulkan-icd-loader xz zlib || handle_error "AUR package install failed."

}

# Function 4: Build and install zimg and VapourSynth
build_zimg_and_vapoursynth() {
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR" || handle_error "Cannot change to build directory."

    echo_status "Building zimg..."
    if [ ! -d "zimg" ]; then
        git clone https://github.com/sekrit-twc/zimg.git || handle_error "Failed to clone zimg."
    else
        git -C zimg pull || handle_error "Failed to update zimg."
    fi
    cd zimg || handle_error "Cannot enter zimg directory."
    ./autogen.sh || handle_error "zimg autogen failed."
    ./configure || handle_error "zimg configuration failed."
    make -j"$(nproc)" || handle_error "zimg build failed."
    sudo make install || handle_error "zimg install failed."

    echo_status "Building VapourSynth..."
    cd "$BUILD_DIR" || handle_error "Cannot change to build directory."
    if [ ! -d "vapoursynth" ]; then
        git clone https://github.com/vapoursynth/vapoursynth.git || handle_error "Failed to clone VapourSynth."
    else
        git -C vapoursynth pull || handle_error "Failed to update VapourSynth."
    fi
    cd vapoursynth || handle_error "Cannot enter VapourSynth directory."
    ./autogen.sh || handle_error "VapourSynth autogen failed."
    ./configure || handle_error "VapourSynth configuration failed."
    make -j"$(nproc)" || handle_error "VapourSynth build failed."
    sudo make install || handle_error "VapourSynth install failed."
    sudo ldconfig
    PYTHON_VERSION=$(python3 --version | awk '{print $2}' | cut -d. -f1,2)
    sudo ln -sf /usr/local/lib/python${PYTHON_VERSION}/site-packages/vapoursynth.so /usr/lib/python${PYTHON_VERSION}/site-packages/ || handle_error "Failed to symlink VapourSynth Python module."
}

# Function 5: Build and install MPV with VapourSynth support
build_mpv() {
    echo_status "Building MPV with VapourSynth support..."
    cd "$BUILD_DIR" || handle_error "Cannot change to build directory."
    if [ ! -d "mpv-build" ]; then
        git clone https://github.com/mpv-player/mpv-build.git || handle_error "Failed to clone mpv-build."
    else
        git -C mpv-build pull || handle_error "Failed to update mpv-build."
    fi
    cd mpv-build || handle_error "Cannot enter mpv-build directory."
    ./use-ffmpeg-release || handle_error "Failed to configure ffmpeg options."
    # Append additional options
    echo --enable-libx264 >> ffmpeg_options
    echo --enable-nvdec >> ffmpeg_options
    echo --enable-vaapi >> ffmpeg_options
    echo --enable-vapoursynth >> mpv_options
    echo --enable-libmpv-shared >> mpv_options
    ./rebuild -j"$(nproc)" || handle_error "MPV rebuild failed."
    sudo ./install || handle_error "MPV installation failed."
    sudo ldconfig

}

# Function 6: Main function to run all setup steps
svp_setup_main() {
    ensure_root "$@"
    update_and_install
    install_svp_packages
    build_zimg_and_vapoursynth
    build_mpv
    echo_status "SVP setup completed successfully."
}

# Execute the main function
svp_setup_main "$@"
