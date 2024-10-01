#!/bin/bash

# ================================== // CUSTOM_FFMPEG_BUILD.SH //
# File: Custom_ffmpeg_build.sh
# Author: 4ndr0666
# Date: 10-01-24
# Description: Builds ffmpeg from source with error-handling, logging, and common troubleshooting steps. Also 
# builds a static version of the x264 codec locally and links it to the custom ffmpeg build.

# --- // Constants:
export PATH="$HOME/bin:$PATH"
export PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig"
LOG_DIR="$HOME/ffmpeg_build/logs"
BUILD_LOG="$LOG_DIR/build.log"
INSTALL_LOG="$LOG_DIR/install.log"

# --- // Create log directory:
mkdir -p "$LOG_DIR"

# --- // Function to check if previous commands succeeded:
check_status() {
  if [ $? -ne 0 ]; then
    echo "Error encountered. Check logs for details."
    echo "Check the build log at $BUILD_LOG and install log at $INSTALL_LOG"
    exit 1
  fi
}

# --- // Clean up previous builds:
clean_build() {
  echo "Cleaning up previous builds..."
  make clean 2>&1 | tee -a "$BUILD_LOG"
  check_status
}

# --- // Verify Dependencies:
verify_dependencies() {
  echo "Verifying required libraries..."
  if ! pkg-config --libs libx264 &> /dev/null || ! pkg-config --libs libx265 &> /dev/null; then
    echo "Missing dependencies. Ensure libx264 and libx265 are installed."
    exit 1
  fi
}

# --- // Pull ffmpeg snapshot:
echo "Pulling the latest FFmpeg snapshot..."
cd ~/ffmpeg_sources || exit
wget -O ffmpeg-snapshot.tar.bz2 https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2 2>&1 | tee -a "$BUILD_LOG"
check_status
tar xjvf ffmpeg-snapshot.tar.bz2 2>&1 | tee -a "$BUILD_LOG"
check_status
cd ffmpeg || exit

# --- // Build ffmpeg with options:
echo "Starting FFmpeg build process..."
clean_build

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
  --enable-nonfree 2>&1 | tee -a "$BUILD_LOG"
check_status

# --- // Compile and install FFmpeg:
echo "Compiling and installing FFmpeg..."
PATH="$HOME/bin:$PATH" make 2>&1 | tee -a "$BUILD_LOG"
check_status
make install 2>&1 | tee -a "$INSTALL_LOG"
check_status

# --- // Refresh shell environment:
echo "Refreshing shell environment..."
hash -r

# --- // Verify libx264 codec:
echo "Verifying libx264 codec installation..."
if ffmpeg -codecs | grep -q libx264; then
  echo "libx264 codec is available."
else
  echo "Error: libx264 codec is not available."
  exit 1
fi

# --- // Test video encoding with libx264:
echo "Testing video encoding with libx264..."
ffmpeg -i input.mp4 -c:v libx264 -preset slow -crf 23 output.mp4 2>&1 | tee -a "$BUILD_LOG"
if [ $? -eq 0 ]; then
  echo "Test encoding successful."
else
  echo "Test encoding failed. Check $BUILD_LOG for details."
  exit 1
fi

# --- // Verify successful completion:
echo "FFmpeg build and installation completed successfully. Logs can be found in $LOG_DIR."
