#!/usr/bin/env bash
#File: svpsetup.sh
#Author: 4ndr0666
#Edited: 3-27-24
#
# --- // SVPSETUP.SH // ========

# --- // AUTO_ESCALATE:
if [ "$(id -u)" -ne 0 ]; then
      sudo "$0" "$@"
    exit $?
fi

# --- CONSTANTS: 
BUILD_DIR="$HOME/build"
mkdir -p "$BUILD_DIR"

# Update system and install yay if not installed
echo "Updating system and ensuring yay is installed..."
sudo pacman -Syu --needed base-devel git
if ! command -v yay &> /dev/null; then
    git clone https://aur.archlinux.org/yay.git "$BUILD_DIR/yay"
    cd "$BUILD_DIR/yay" || exit
    makepkg -si
fi

echo "Installing FFmpeg-git and its dependencies..."
yay -S ffmpeg-git alsa-lib aom bzip2 fontconfig fribidi gmp gnutls gsm jack lame libass libavc1394 libbluray libbs2b libdav1d libdrm libfreetype libgl libiec61883 libjxl libmodplug libopenmpt libpulse librav1e libraw1394 librsvg-2 libsoxr libssh libtheora libva libva-drm libva-x11 libvdpau libvidstab libvorbisenc libvorbis libvpx libwebp libx11 libx264 libx265 libxcb libxext libxml2 libxv libxvidcore libzimg ocl-icd onevpl opencore-amr openjpeg2 opus sdl2 speex srt svt-av1 v4l-utils vmaf vulkan-icd-loader xz zlib --needed

echo "Installing required packages for SVP setup..."
sudo pacman -S --needed qt5-base qt5-declarative qt5-svg libmediainfo lsof vapoursynth mkvtoolnix-cli python cython opencl-headers ocl-icd opencl-driver
yay -S --needed intel-compute-runtime

# Function to clone or pull latest from a git repository
clone_or_pull() {
    local repo_url="$1"
    local dest_dir="$2"
    local repo_name=$(basename "$repo_url" .git)
    local full_path="$dest_dir/$repo_name"

    if [ ! -d "$full_path/.git" ]; then
        echo "Cloning $repo_name..."
        git clone "$repo_url" "$full_path"
    else
        echo "Updating $repo_name..."
        git -C "$full_path" pull
    fi
}

# Build zimg
echo "Building zimg..."
clone_or_pull "https://github.com/sekrit-twc/zimg.git" "$BUILD_DIR"
cd "$BUILD_DIR/zimg" || exit
./autogen.sh
./configure
make -j"$(nproc)"
sudo make install

# Build VapourSynth
echo "Building VapourSynth..."
clone_or_pull "https://github.com/vapoursynth/vapoursynth.git" "$BUILD_DIR"
cd "$BUILD_DIR/vapoursynth" || exit
./autogen.sh
./configure
make -j"$(nproc)"
sudo make install
sudo ldconfig
PYTHON_VERSION=$(python3 --version | awk '{print $2}' | awk -F. '{print $1"."$2}')
sudo ln -sf /usr/local/lib/python${PYTHON_VERSION}/site-packages/vapoursynth.so /usr/lib/python${PYTHON_VERSION}/site-packages/

# Build MPV with VapourSynth support
echo "Building MPV with VapourSynth support..."
clone_or_pull "https://github.com/mpv-player/mpv-build.git" "$BUILD_DIR"
cd "$BUILD_DIR/mpv-build" || exit
./use-ffmpeg-release
echo --enable-libx264 >> ffmpeg_options
echo --enable-nvdec >> ffmpeg_options
echo --enable-vaapi >> ffmpeg_options
echo --enable-vapoursynth >> mpv_options
echo --enable-libmpv-shared >> mpv_options
./rebuild -j"$(nproc)"
sudo ./install

# Update LD_LIBRARY_PATH
export LD_LIBRARY_PATH="$BUILD_DIR/mpv-build/build_libs/lib:$LD_LIBRARY_PATH"
sudo ldconfig

# Configure MPV
echo "Configuring MPV..."
mkdir -p ~/.config/mpv
{
    echo "--input-ipc-server=/tmp/mpvsocket"
    echo "--hwdec=auto-copy"
} >> ~/.config/mpv/mpv.conf

# VLC Configuration
echo "Configuring VLC..."
sudo chmod 777 /usr/lib/vlc/plugins/video_filter

echo "SVP setup completed successfully."





