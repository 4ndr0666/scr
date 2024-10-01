#!/bin/bash

# ================================== // CUSTOM_FFMPEG_BUILD.SH //
# File: Custom_ffmpeg_build.sh
# Author: 4ndr0666
# Date: 10-01-24
# Description: Builds ffmpeg from source with options listed below begining with "--enable". Also 
# builds a static version of the x264 codec locally and links it to the custom ffmpeg build.


# --- // Constants:
export PATH="$HOME/bin:$PATH"
export PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig"

# --- // Pull ffmpeg snapshot:
cd ~/ffmpeg_sources || exit
wget -O ffmpeg-snapshot.tar.bz2 https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2
tar xjvf ffmpeg-snapshot.tar.bz2
cd ffmpeg || exit

# --- // Build ffmpeg w options:
PATH="$HOME/bin:$PATH" PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig" ./configure \
  --prefix="$HOME/ffmpeg_build" \
  --pkg-config-flags="--static" \
  --extra-cflags="-I$HOME/ffmpeg_build/include" \
  --extra-ldflags="-L$HOME/ffmpeg_build/lib" \
  --extra-libs="-lpthread -lm" \
  --ld="g++" \
  --bindir="$HOME/bin" \
  --enable-gpl \
  --enable-libx264 \
  --enable-gnutls \
  --enable-libaom \ 
  --enable-libass \
  --enable-libfdk-aac \
  --enable-libfreetype \
  --enable-libmp3lame \
  --enable-libopus \
  --enable-libsvtav1 \
  --enable-libdav1d \
  --enable-libvorbis \
  --enable-libvpx \
  --enable-libx265 \
  --enable-nvdec \
  --enable-vaapi \
  --enable-nonfree && \

# --- // Compile and install FFmpeg:
PATH="$HOME/bin:$PATH" make
make install

# --- // Refresh shell environment:
hash -r

# --- // Verify libx264 codec:
if ffmpeg -codecs | grep -q libx264; then
  echo "libx264 codec is available."
else
  echo "Error: libx264 codec is not available."
  exit 1
fi

# --- // Test video encoding with libx264:
ffmpeg -i input.mp4 -c:v libx264 -preset slow -crf 23 output.mp4
if [ $? -eq 0 ]; then
  echo "Test encoding successful."
else
  echo "Test encoding failed."
  exit 1
fi
