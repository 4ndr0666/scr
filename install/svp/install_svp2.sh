#!/usr/bin/env bash
# svpinstaller.sh
# Author: 4ndr0666 (Original), Refined by ChatGPT
# Edited: 2025-01-21 (Version 2.1.2)
#
# This script installs the Smooth Video Project (SVP4) along with required dependencies,
# builds and installs zimg, VapourSynth, and MPV with VapourSynth support, tailored for Arch Linux.
#
# Pre-requirements:
#   - Ensure that Qt (>=5.9), VapourSynth (>=R31), MediaInfo, lsof, and Python 3.8 are installed.
#   - Proprietary video drivers (with OpenCL ICD) are recommended.
#   - mpv (>=0.28) with VapourSynth support is required.
#
# Usage:
#   sudo bash svpinstaller.sh [--clean]
#
# The --clean flag forces a fresh installation (removing existing build directories).
#
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
    "mkvtoolnix-cli"
    "avahi"
)

# Dependencies for system and AUR helper
declare -r DEPENDENCIES=("yay" "git" "base-devel")

declare -r GRUB_PARAMETERS="amdgpu.si_support=1 radeon.si_support=0"
declare -r BLACKLIST_FILE="/etc/modprobe.d/blacklist-radeon.conf"
declare -r LOGFILE="/var/log/setup_amdgpu.log"

# Global flag for clean installation (default false)
CLEAN_INSTALL=false

# Parse command-line arguments
for arg in "$@"; do
    case $arg in
        --clean)
            CLEAN_INSTALL=true
            shift ;;
        *)
            ;;
    esac
done

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
    if [ "$CLEAN_INSTALL" = true ] && [ -d "$dest_dir" ]; then
        echo_status "Cleaning existing directory $dest_dir for a fresh clone..."
        rm -rf "$dest_dir" || handle_error "Failed to remove $dest_dir."
    fi
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
# 5) Fix permissions for yay cache directory
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
        return 0
    else
        echo_status "Normal removal of $pkg failed; attempting forced removal with -Rddns..."
        if pacman -Rddns --noconfirm "$pkg"; then
            echo_status "Forcibly removed $pkg."
            return 0
        else
            echo_status "Failed to forcibly remove $pkg."
            return 1
        fi
    fi
}

###############################################################################
# 7) Remove conflicting packages (ffmpeg or ffmpeg-git) individually
###############################################################################
remove_conflicting_packages() {
    echo_status "Checking for conflicting ffmpeg packages..."
    local ffmpeg_path
    if ffmpeg_path="$(which ffmpeg 2>/dev/null)"; then
        if pacman -Qo "$ffmpeg_path" > /dev/null 2>&1; then
            local owner
            owner=$(pacman -Qo "$ffmpeg_path" 2>/dev/null | awk '{print $2}')
            if [ "$owner" = "ffmpeg" ]; then
                echo_status "ffmpeg is installed (owned by $owner), attempting removal..."
                if ! remove_pkg_force "ffmpeg"; then
                    echo_status "Warning: Unable to remove ffmpeg; dependencies exist. Using existing ffmpeg."
                fi
            else
                echo_status "ffmpeg binary is provided by $owner; skipping removal."
            fi
        else
            echo_status "ffmpeg binary found but not owned by any package; skipping removal."
        fi
    else
        echo_status "ffmpeg not found; no conflict."
    fi

    if pacman -Qs '^ffmpeg-git$' > /dev/null 2>&1; then
        echo_status "ffmpeg-git is installed, attempting removal..."
        if ! remove_pkg_force "ffmpeg-git"; then
            echo_status "Warning: Unable to remove ffmpeg-git due to dependency conflicts. Skipping removal."
        fi
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
    fix_yay_safe_directory
    fix_yay_permissions
    remove_conflicting_packages
    # Install ffmpeg-git only if not already installed
    if pacman -Qs '^ffmpeg-git$' > /dev/null 2>&1; then
        echo_status "ffmpeg-git is already installed; skipping installation."
    else
        if ! yes | sudo -u "$SUDO_USER" yay -S --needed ffmpeg-git; then
            echo_status "Warning: Failed to install ffmpeg-git from AUR. Continuing with existing dependencies."
        fi
    fi
    # Install remaining AUR packages
    yes | sudo -u "$SUDO_USER" yay -S --needed \
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
    if [ "$CLEAN_INSTALL" = true ]; then
        rm -rf "$BUILD_DIR/zimg" "$BUILD_DIR/vapoursynth"
    fi
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
    local PYTHON_VERSION
    PYTHON_VERSION="$(python3 --version | awk '{print $2}' | cut -d. -f1,2)"
    sudo ln -sf "/usr/local/lib/python${PYTHON_VERSION}/site-packages/vapoursynth.so" \
        "/usr/lib/python${PYTHON_VERSION}/site-packages/" || handle_error "Failed to symlink VapourSynth Python module."
}

###############################################################################
# 10) Build and install MPV with VapourSynth support (custom options)
###############################################################################
build_mpv() {
    if [ "$CLEAN_INSTALL" = true ]; then
        rm -rf "$BUILD_DIR/mpv-build"
    fi
    echo_status "Building MPV with VapourSynth support..."
    cd "$BUILD_DIR" || handle_error "Cannot change to build directory."
    clone_or_pull "https://github.com/mpv-player/mpv-build.git" "$BUILD_DIR/mpv-build"
    cd "$BUILD_DIR/mpv-build" || handle_error "Cannot enter mpv-build directory."
    ./use-ffmpeg-release || handle_error "Failed to configure ffmpeg options."

    # Define FFMPEG build options exactly as specified
    FFMPEG_OPTS=(
        "--disable-libopencv"
        "--disable-libtls"
        "--disable-mbedtls"
        "--disable-programs"
        "--disable-amf"
        "--disable-liblensfun"
        "--disable-libtensorflow"
        "--enable-alsa"
        "--enable-bzlib"
        "--enable-chromaprint"
        "--enable-fontconfig"
        "--enable-frei0r"
        "--enable-gcrypt"
        "--enable-gmp"
        "--enable-gnutls"
        "--enable-gpl"
        "--enable-gray"
        "--enable-iconv"
        "--enable-ladspa"
        "--enable-lcms2"
        "--enable-libaom"
        "--enable-libaribb24"
        "--enable-libass"
        "--enable-libbluray"
        "--enable-libbs2b"
        "--enable-libcaca"
        "--enable-libcdio"
        "--enable-libcodec2"
        "--enable-libdav1d"
        "--enable-libdc1394"
        "--enable-libdrm"
        "--enable-libfdk-aac"
        "--enable-libfreetype"
        "--enable-libfribidi"
        "--enable-libglslang"
        "--enable-libgme"
        "--enable-libgsm"
        "--enable-libiec61883"
        "--enable-libilbc"
        "--enable-libjack"
        "--enable-libjxl"
        "--enable-libkvazaar"
        "--enable-libmodplug"
        "--enable-libmp3lame"
        "--enable-libmysofa"
        "--enable-libopencore-amrnb"
        "--enable-libopencore-amrwb"
        "--enable-libopenh264"
        "--enable-libopenjpeg"
        "--enable-libopenmpt"
        "--enable-libopus"
        "--enable-libpulse"
        "--enable-librabbitmq"
        "--enable-librav1e"
        "--enable-librsvg"
        "--enable-librtmp"
        "--enable-librubberband"
        "--enable-libsnappy"
        "--enable-libsoxr"
        "--enable-libspeex"
        "--enable-libsrt"
        "--enable-libssh"
        "--enable-libsvtav1"
        "--enable-libtesseract"
        "--enable-libtheora"
        "--enable-libtwolame"
        "--enable-libv4l2"
        "--enable-libvidstab"
        "--enable-libvmaf"
        "--enable-libvorbis"
        "--enable-libvpx"
        "--enable-libwebp"
        "--enable-libx264"
        "--enable-libx265"
        "--enable-libxcb"
        "--enable-libxcb-shape"
        "--enable-libxcb-shm"
        "--enable-libxcb-xfixes"
        "--enable-libxml2"
        "--enable-libxvid"
        "--enable-libzimg"
        "--enable-libzmq"
        "--enable-libzvbi"
        "--enable-libvpl"
        "--enable-lto"
        "--enable-lv2"
        "--enable-lzma"
        "--enable-nonfree"
        "--enable-omx"
        "--enable-openal"
        "--enable-opencl"
        "--enable-opengl"
        "--enable-pic"
        "--enable-sdl2"
        "--enable-sndio"
        "--enable-v4l2-m2m"
        "--enable-vaapi"
        "--enable-vapoursynth"
        "--enable-vdpau"
        "--enable-version3"
        "--enable-vulkan"
        "--enable-xlib"
        "--enable-zlib"
    )

    # Define MPV build options exactly as specified
    MPV_OPTS=(
        "-Db_lto=true"
        "-Db_staticpic=true"
        "-Ddefault_library=shared"
        "-Dc_link_args=-lstdc++ -lglslang -Wl,-Bsymbolic"
        "-Dcplayer=true"
        "-Dlibmpv=true"
        "-Dbuild-date=true"
        "-Dcdda=enabled"
        "-Dcplugins=enabled"
        "-Ddvbin=enabled"
        "-Ddvdnav=enabled"
        "-Diconv=enabled"
        "-Djavascript=enabled"
        "-Dlcms2=enabled"
        "-Dlibarchive=enabled"
        "-Dlibavdevice=enabled"
        "-Dlibbluray=enabled"
        "-Dlua=luajit"
        "-Drubberband=enabled"
        "-Dsdl2=enabled"
        "-Dsdl2-gamepad=enabled"
        "-Duchardet=enabled"
        "-Duwp=disabled"
        "-Dvapoursynth=enabled"
        "-Dvector=auto"
        "-Dwin32-threads=disabled"
        "-Dzimg=enabled"
        "-Dzlib=enabled"
        "-Dalsa=enabled"
        "-Daudiounit=disabled"
        "-Davfoundation=disabled"
        "-Dcoreaudio=disabled"
        "-Djack=enabled"
        "-Dopenal=enabled"
        "-Dopensles=disabled"
        "-Doss-audio=disabled"
        "-Dpipewire=enabled"
        "-Dpulse=enabled"
        "-Dsdl2-audio=enabled"
        "-Dsndio=enabled"
        "-Dwasapi=disabled"
        "-Dcaca=enabled"
        "-Dcocoa=disabled"
        "-Dd3d11=disabled"
        "-Ddirect3d=disabled"
        "-Ddmabuf-wayland=enabled"
        "-Ddrm=enabled"
        "-Degl=enabled"
        "-Degl-android=disabled"
        "-Degl-angle=disabled"
        "-Degl-angle-lib=disabled"
        "-Degl-angle-win32=disabled"
        "-Degl-drm=enabled"
        "-Degl-wayland=enabled"
        "-Degl-x11=enabled"
        "-Dgbm=enabled"
        "-Dgl=enabled"
        "-Dgl-cocoa=disabled"
        "-Dgl-dxinterop=disabled"
        "-Dgl-win32=disabled"
        "-Dgl-x11=enabled"
        "-Djpeg=enabled"
        "-Dsdl2-video=enabled"
        "-Dshaderc=disabled"
        "-Dsixel=enabled"
        "-Dspirv-cross=disabled"
        "-Dplain-gl=enabled"
        "-Dvdpau=enabled"
        "-Dvdpau-gl-x11=enabled"
        "-Dvaapi=enabled"
        "-Dvaapi-drm=enabled"
        "-Dvaapi-wayland=enabled"
        "-Dvaapi-x11=enabled"
        "-Dvaapi-win32=disabled"
        "-Dvulkan=enabled"
        "-Dwayland=enabled"
        "-Dx11=enabled"
        "-Dxv=enabled"
    )

    # Write FFMPEG options to file (overwrite existing file)
    local ffmpeg_file="ffmpeg_options"
    : > "$ffmpeg_file" || handle_error "Failed to clear $ffmpeg_file."
    for opt in "${FFMPEG_OPTS[@]}"; do
        echo "$opt" >> "$ffmpeg_file" || handle_error "Failed to write to $ffmpeg_file."
    done

    # Write MPV options to file (overwrite existing file)
    local mpv_file="mpv_options"
    : > "$mpv_file" || handle_error "Failed to clear $mpv_file."
    for opt in "${MPV_OPTS[@]}"; do
        echo "$opt" >> "$mpv_file" || handle_error "Failed to write to $mpv_file."
    done

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
