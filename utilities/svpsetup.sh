#!/bin/bash

# TROUBLESHOOT
echo "Troubleshooting..."
export LD_LIBRARY_PATH=/home//build/mpv-build/build_libs/lib:$LD_LIBRARY_PATH

# ENSURE DEPENDENCIES
echo "Installing dependencies..."
yay -S --needed libx264 xorg libxpresent libva libdrm libplacebo qt5-base qt5-declarative qt5-svg libmediainfo lsof vapoursynth mkvtoolnix-cli mediainfo zimg opencl cython make autoconf automake libtool pkg-config nasm git

# BUILD VapourSynth
echo "Building VapourSynth..."
if ! [ -x "$(command -v vapoursynth)" ]; then
    git clone --branch R59 https://github.com/vapoursynth/vapoursynth.git
    cd vapoursynth || exit
    ./autogen.sh
    ./configure
    make -j"$(nproc)"
    sudo make install
    cd ..
    sudo ldconfig
    PYTHON_VERSION=$(python3 --version | awk '{print $2}' | awk -F. '{print $1"."$2}')
    sudo ln -sf /usr/local/lib/python${PYTHON_VERSION}/site-packages/vapoursynth.so /usr/lib/python${PYTHON_VERSION}/site-packages/
fi

# BUILD MPV with VapourSynth support
echo "Building MPV with VapourSynth support..."
if ! [ -x "$(command -v mpv)" ]; then
    git clone https://github.com/mpv-player/mpv-build.git
    cd mpv-build || exit
    ./use-ffmpeg-release
    echo --enable-libx264 >> ffmpeg_options
    echo --enable-nvdec >> ffmpeg_options
    echo --enable-vaapi >> ffmpeg_options
    echo --enable-vapoursynth >> mpv_options
    echo --enable-libmpv-shared >> mpv_options
    ./rebuild -j"$(nproc)"
    sudo ./install
    cd ..
fi

# MPV CONFIG
echo "Configuring MPV..."
mkdir -p ~/.config/mpv
{
    echo "--input-ipc-server=/tmp/mpvsocket"
    echo "--hwdec=auto-copy"
} >> ~/.config/mpv/mpv.conf

# VLC CONFIG
echo "Configuring VLC..."
sudo chmod 777 /usr/lib/vlc/plugins/video_filter

echo "Setup completed successfully."
