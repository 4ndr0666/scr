#!/bin/bash

# TROUBLESHOOT
echo "Troubleshooting..."
export LD_LIBRARY_PATH=/usr/lib:$LD_LIBRARY_PATH

# ENSURE DEPENDENCIES
echo "Installing dependencies..."
paru -S libx264 xorg libxpresent libva libdrm libplacebo qt5-base qt5-declarative qt5-svg libmediainfo lsof vapoursynth mkvtoolnix-cli mediainfo zimg opencl zimg vapoursynth cython make autoconf automake libtool pkg-config nasm git

# BUILD VapourSynth
echo "Building VapourSynth..."
git clone --branch R59 https://github.com/vapoursynth/vapoursynth.git
cd vapoursynth || exit
./autogen.sh
./configure
make -j4
sudo make install
cd ..
sudo ldconfig
sudo ln -s /usr/local/lib/python3.11/site-packages/vapoursynth.so /usr/lib/python3.11/lib-dynload/vapoursynth.so

# BUILD MPV with VapourSynth support
echo "Building MPV with VapourSynth support..."
git clone https://github.com/mpv-player/mpv-build.git
cd mpv-build || exit
./use-ffmpeg-release
echo --enable-libx264 >> ffmpeg_options
echo --enable-nvdec >> ffmpeg_options
echo --enable-vaapi >> ffmpeg_options
echo --enable-vapoursynth >> mpv_options
echo --enable-libmpv-shared >> mpv_options
./rebuild -j4
sudo ./install
cd ..

# MPV CONFIG
echo "Configuring MPV..."
echo "--input-ipc-server=/tmp/mpvsocket" >> ~/.config/mpv/mpv.conf
echo "--hwdec=auto-copy" >> ~/.config/mpv/mpv.conf

# VLC CONFIG
echo "Configuring VLC..."
sudo chmod 777 /usr/lib/vlc/plugins/video_filter

echo "Setup completed successfully."
