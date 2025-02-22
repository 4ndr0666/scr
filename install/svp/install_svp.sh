#!/usr/bin/env bash
# svpinstaller.sh
# Author: 4ndr0666
# Edited: 3-27-24
#
# --- // SVPINSTALLER.SH // ========
set -eu
set -o pipefail

###############################################################################
# Global Constants
###############################################################################
declare -r BUILD_DIR="$HOME/build"
declare -r SVP_LOGFILE="$HOME/svp_setup.log"

# Official repository packages
declare -r PACMAN_PACKAGES=(
    "mesa"
    "vulkan-radeon"
    "vulkan-mesa-layers"
    "wayfire"
    "waybar"
    "pipewire"
    "pipewire-pulse"
    "wireplumber"
    "vulkan-tools"
    "linux-firmware"
    "wl-clipboard"
    "swaybg"
    "wlr-randr"
    "kanshi"
    "nwg-displays"
)

# Dependencies for system and AUR helper
declare -r DEPENDENCIES=("yay" "git" "base-devel")

# Additional constants (may be used if needed)
declare -r GRUB_PARAMETERS="amdgpu.si_support=1 radeon.si_support=0"
declare -r BLACKLIST_FILE="/etc/modprobe.d/blacklist-radeon.conf"
declare -r LOGFILE="/var/log/setup_amdgpu.log"

# Redirect all output to log file (with timestamps) and console
exec > >(tee -a "$LOGFILE") 2>&1

###############################################################################
# Helper Functions
###############################################################################

# Print status messages in green
echo_status() {
    echo -e "\e[1;32m$1\e[0m"
}

# Print errors in red and exit
handle_error() {
    echo -e "\e[1;31mError: $1\e[0m" 1>&2
    exit 1
}

###############################################################################
# 1) Ensure the script is run as root (for pacman commands)
###############################################################################
ensure_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo_status "Please run this script as root (e.g., via sudo)."
        exit 1
    fi
}

###############################################################################
# 2) Clone or update a git repository
###############################################################################
clone_or_pull() {
    local repo_url="$1"
    local dest_dir="$2"

    if [ ! -d "$dest_dir/.git" ]; then
        echo_status "Cloning repository from $repo_url into $dest_dir..."
        git clone "$repo_url" "$dest_dir" || handle_error "Failed to clone repository $repo_url."
    else
        echo_status "Updating repository in $dest_dir..."
        git -C "$dest_dir" pull || handle_error "Failed to update repository in $dest_dir."
    fi
}

###############################################################################
# 3) Update system and install base dependencies and AUR helper (yay)
###############################################################################
update_and_install() {
    echo_status "Updating system and installing base packages..."
    pacman -Syu --needed base-devel git || handle_error "System update failed."

    if [ -z "${SUDO_USER:-}" ]; then
        handle_error "This script must be run via sudo so that yay commands run as the non-root user."
    fi

    # If yay is not installed, build it from AUR
    if ! sudo -u "$SUDO_USER" bash -c 'command -v yay' > /dev/null 2>&1; then
        mkdir -p "$BUILD_DIR"
        cd "$BUILD_DIR" || handle_error "Cannot change to build directory."
        echo_status "Cloning yay repository..."
        sudo -u "$SUDO_USER" git clone https://aur.archlinux.org/yay.git || handle_error "Failed to clone yay."
        cd yay || handle_error "Cannot enter yay directory."
        echo_status "Building and installing yay..."
        sudo -u "$SUDO_USER" makepkg -si --noconfirm || handle_error "Failed to build yay."
    fi
}

###############################################################################
# 4) Fix yay safe.directory configuration for AUR caches
###############################################################################
fix_yay_safe_directory() {
    local user_home
    user_home="$(eval echo "~${SUDO_USER}")"

    if [ -d "$user_home/.cache/yay/ffmpeg-git" ]; then
        sudo -u "$SUDO_USER" git config --global --add safe.directory "$user_home/.cache/yay/ffmpeg-git" || true
    fi
    if [ -d "$user_home/.cache/yay/amf-headers-git" ]; then
        sudo -u "$SUDO_USER" git config --global --add safe.directory "$user_home/.cache/yay/amf-headers-git" || true
    fi
}

###############################################################################
# 5) Fix permissions for yay cache directory to avoid permission errors
###############################################################################
fix_yay_permissions() {
    local yay_cache_dir="$HOME/.cache/yay"

    if [ -d "$yay_cache_dir" ]; then
        echo_status "Fixing permissions for yay cache directory..."
        sudo chown -R "$SUDO_USER":"$SUDO_USER" "$yay_cache_dir" || handle_error "Failed to fix permissions for yay cache directory."
    fi
}

###############################################################################
# 6) Attempt to remove a package forcibly if normal removal fails
###############################################################################
remove_pkg_force() {
    local pkg="$1"
    echo_status "Attempting normal removal of $pkg..."
    if pacman -Rns --noconfirm "$pkg"; then
        echo_status "Removed $pkg successfully (normal removal)."
    else
        echo_status "Normal removal of $pkg failed; attempting forced removal with -Rddns..."
        pacman -Rddns --noconfirm "$pkg" || handle_error "Failed to forcibly remove $pkg."
        echo_status "Forcibly removed $pkg."
    fi
}

###############################################################################
# 7) Remove conflicting packages (ffmpeg or ffmpeg-git) individually
###############################################################################
remove_conflicting_packages() {
    echo_status "Checking for conflicting ffmpeg packages..."

    # Check if ffmpeg is installed
    if pacman -Qs '^ffmpeg$' > /dev/null 2>&1; then
        echo_status "ffmpeg is installed, removing..."
        remove_pkg_force "ffmpeg"
    else
        echo_status "ffmpeg is not installed; no conflict."
    fi

    # Check if ffmpeg-git is installed
    if pacman -Qs '^ffmpeg-git$' > /dev/null 2>&1; then
        echo_status "ffmpeg-git is installed, removing..."
        remove_pkg_force "ffmpeg-git"
    else
        echo_status "ffmpeg-git is not installed; no conflict."
    fi
}

###############################################################################
# 8) Install required packages for SVP4 and transcoding
###############################################################################
install_svp_packages() {
    echo_status "Installing required packages..."
    pacman -S --needed qt5-base qt5-declarative qt5-svg libmediainfo lsof vapoursynth \
        mkvtoolnix-cli python cython opencl-headers ocl-icd opencl-driver || handle_error "Pacman install failed."

    # Fix yay configuration and permissions
    fix_yay_safe_directory
    fix_yay_permissions

    # Remove conflicting packages before proceeding
    remove_conflicting_packages

    # Use 'yes |' to auto-answer interactive prompts for AUR commands
    yes | sudo -u "$SUDO_USER" yay -S --needed \
        ffmpeg-git \
        alsa-lib aom bzip2 fontconfig fribidi gmp gnutls gsm jack lame \
        libass libavc1394 libbluray libbs2b libdav1d libdrm libfreetype \
        libgl libiec61883 libjxl libmodplug libopenmpt libpulse librav1e \
        libraw1394 librsvg-2 libsoxr libssh libtheora libva libva-drm \
        libva-x11 libvdpau libvidstab libvorbisenc libvorbis libvpx libwebp \
        libx11 libx264 libx265 libxcb libxext libxml2 libxv libxvidcore \
        libzimg ocl-icd onevpl opencore-amr openjpeg2 opus sdl2 speex srt \
        svt-av1 v4l-utils vmaf vulkan-icd-loader xz zlib || handle_error "AUR package install failed."
}

###############################################################################
# 9) Build and install zimg and VapourSynth
###############################################################################
build_zimg_and_vapoursynth() {
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR" || handle_error "Cannot change to build directory."

    echo_status "Building zimg..."
    clone_or_pull "https://github.com/sekrit-twc/zimg.git" "$BUILD_DIR/zimg"
    cd "$BUILD_DIR/zimg" || handle_error "Cannot enter zimg directory."
    ./autogen.sh || handle_error "zimg autogen failed."
    ./configure || handle_error "zimg configuration failed."
    make -j"$(nproc)" || handle_error "zimg build failed."
    sudo make install || handle_error "zimg install failed."

    echo_status "Building VapourSynth..."
    cd "$BUILD_DIR" || handle_error "Cannot change to build directory."
    clone_or_pull "https://github.com/vapoursynth/vapoursynth.git" "$BUILD_DIR/vapoursynth"
    cd "$BUILD_DIR/vapoursynth" || handle_error "Cannot enter VapourSynth directory."
    ./autogen.sh || handle_error "VapourSynth autogen failed."
    ./configure || handle_error "VapourSynth configuration failed."
    make -j"$(nproc)" || handle_error "VapourSynth build failed."
    sudo make install || handle_error "VapourSynth install failed."
    sudo ldconfig

    # Symlink the VapourSynth Python module
    local PYTHON_VERSION
    PYTHON_VERSION="$(python3 --version | awk '{print $2}' | cut -d. -f1,2)"
    sudo ln -sf "/usr/local/lib/python${PYTHON_VERSION}/site-packages/vapoursynth.so" \
        "/usr/lib/python${PYTHON_VERSION}/site-packages/" || handle_error "Failed to symlink VapourSynth Python module."
}

###############################################################################
# 10) Build and install MPV with VapourSynth support
###############################################################################
build_mpv() {
    echo_status "Building MPV with VapourSynth support..."
    cd "$BUILD_DIR" || handle_error "Cannot change to build directory."
    clone_or_pull "https://github.com/mpv-player/mpv-build.git" "$BUILD_DIR/mpv-build"
    cd "$BUILD_DIR/mpv-build" || handle_error "Cannot enter mpv-build directory."
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

###############################################################################
# 11) Main SVP Setup Execution
###############################################################################
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
