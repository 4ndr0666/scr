#!/bin/bash
set -e

# File: install_ffmpegbeta.sh
# Author: 4ndr0666
# Date: 10-14-24
# Description: Builds x264, x265, FFmpeg, and MPV from source with error handling, logging,
# and installs them into user directories. Ensures that the custom-built FFmpeg and MPV are
# the ones used by updating environment variables. Also includes cleanup functionality.

# ================================== // INSTALL_FFMPEGBETA.SH //

# --- // Constants:
export FFMPEG_SOURCES="$HOME/ffmpeg_sources"
export FFMPEG_BUILD="$HOME/ffmpeg_build"
export FFMPEG_BIN="$HOME/bin"
export MPV_BUILD_DIR="$HOME/mpv_build"
export LOG_DIR="$HOME/ffmpeg_mpv_build/logs"
export BUILD_LOG="$LOG_DIR/build.log"
export INSTALL_LOG="$LOG_DIR/install.log"

# --- // Ensure necessary directories exist:
mkdir -p "$LOG_DIR" "$FFMPEG_SOURCES" "$FFMPEG_BIN" "$FFMPEG_BUILD" "$MPV_BUILD_DIR"

# --- // Prevent duplicate entries in environment variables:
if [[ ":$PATH:" != *":$FFMPEG_BIN:"* ]]; then
  export PATH="$FFMPEG_BIN:$PATH"
fi

if [[ ":$PKG_CONFIG_PATH:" != *":$FFMPEG_BUILD/lib/pkgconfig:"* ]]; then
  export PKG_CONFIG_PATH="$FFMPEG_BUILD/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
fi

if [[ ":$LD_LIBRARY_PATH:" != *":$FFMPEG_BUILD/lib:"* ]]; then
  export LD_LIBRARY_PATH="$FFMPEG_BUILD/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

# --- // Function to check if previous commands succeeded:
check_status() {
  if [ $? -ne 0 ]; then
    echo "Error encountered in the previous step. Exiting." | tee -a "$BUILD_LOG"
    echo "Check the build log at $BUILD_LOG and install log at $INSTALL_LOG for details."
    exit 1
  fi
}

# --- // Verify Required Tools:
verify_dependencies() {
  echo "Verifying required tools..." | tee -a "$BUILD_LOG"
  REQUIRED_TOOLS=(git cmake make gcc g++ yasm pkg-config python3 meson ninja)
  MISSING_TOOLS=()
  for TOOL in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$TOOL" &> /dev/null; then
      MISSING_TOOLS+=("$TOOL")
    fi
  done
  if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
    echo "The following required tools are missing: ${MISSING_TOOLS[*]}" | tee -a "$BUILD_LOG"
    echo "Installing missing tools..." | tee -a "$BUILD_LOG"
    sudo pacman -Sy --needed --noconfirm base-devel git
    check_status
  fi

  if ! command -v yay &> /dev/null; then
    echo "Installing yay AUR helper..." | tee -a "$BUILD_LOG"
    git clone https://aur.archlinux.org/yay.git "$HOME/yay" && cd "$HOME/yay" && makepkg -si --noconfirm
    cd "$HOME"
    check_status
  fi
}

# --- // Install Build Dependencies:
install_build_dependencies() {
  echo "Installing build dependencies..." | tee -a "$BUILD_LOG"
  sudo pacman -Sy --needed --noconfirm \
    autoconf automake cmake extra-cmake-modules git gtk3 \
    libtool nasm yasm pkgconf \
    bzip2 fontconfig freetype2 fribidi gmp gnutls \
    gsm jack lame libass libavc1394 libbluray libdrm \
    libvpx libwebp libx11 libxcb libxext ffms2 \
    libxml2 libxv libxrender mesa openssl opus \
    sdl2 \
    wayland wayland-protocols xorg-server xorg-xinit \
    python python-pip python-setuptools python-docutils \
    python-jinja \
    libarchive luajit libcdio libcdio-paranoia \
    wavpack librsvg \
    zimg libplacebo vulkan-icd-loader openjpeg2 \
    rubberband uchardet shaderc spirv-tools libnfs \
    numactl \
    dav1d \
    xvidcore \
    srt \
    harfbuzz libxrandr libxinerama libxi libxcursor \
    libpulse alsa-lib

  check_status

  echo "Installing AUR packages..." | tee -a "$BUILD_LOG"
  yay -Sy --needed --noconfirm fdk-aac vmaf
  check_status
}

# --- // Prompt for FFmpeg Source:
select_ffmpeg_source_method() {
  echo "Select FFmpeg source method:"
  echo "1) Clone via HTTPS (default)"
  echo "2) Clone via SSH"
  echo "3) Download tarball"
  read -p "Enter your choice [1-3]: " ffmpeg_source_choice
  ffmpeg_source_choice=${ffmpeg_source_choice:-1}

  case $ffmpeg_source_choice in
    1)
      FFmpeg_repo_url="https://git.ffmpeg.org/ffmpeg.git"
      ;;
    2)
      echo "Ensure your SSH agent is running and keys are loaded."
      FFmpeg_repo_url="git@github.com:FFmpeg/FFmpeg.git"
      ;;
    3)
      FFmpeg_tarball_url="https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2"
      ;;
    *)
      echo "Invalid choice. Defaulting to HTTPS."
      FFmpeg_repo_url="https://git.ffmpeg.org/ffmpeg.git"
      ;;
  esac
}

# --- // Build x264:
build_x264() {
  echo "Building x264..." | tee -a "$BUILD_LOG"
  cd "$FFMPEG_SOURCES" || exit
  if [ ! -d "x264" ]; then
    git clone --depth 1 https://code.videolan.org/videolan/x264.git 2>&1 | tee -a "$BUILD_LOG"
    check_status
  fi
  cd x264 || exit
  if [ -f "config.h" ]; then
    make distclean 2>&1 | tee -a "$BUILD_LOG"
  fi
  PKG_CONFIG_PATH="$FFMPEG_BUILD/lib/pkgconfig" ./configure \
    --prefix="$FFMPEG_BUILD" \
    --bindir="$FFMPEG_BIN" \
    --enable-shared \
    --disable-static \
    --enable-pic \
    --disable-opencl 2>&1 | tee -a "$BUILD_LOG"
  check_status
  make -j"$(nproc)" 2>&1 | tee -a "$BUILD_LOG"
  check_status
  make install 2>&1 | tee -a "$INSTALL_LOG"
  check_status
}

# --- // Build x265:
build_x265() {
  echo "Building x265..." | tee -a "$BUILD_LOG"
  cd "$FFMPEG_SOURCES" || exit
  if [ ! -d "x265" ]; then
    git clone https://bitbucket.org/multicoreware/x265_git.git x265 2>&1 | tee -a "$BUILD_LOG"
    check_status
  fi
  cd x265/build/linux || exit
  cmake -G "Unix Makefiles" \
    -DCMAKE_INSTALL_PREFIX="$FFMPEG_BUILD" \
    -DENABLE_SHARED=ON \
    -DENABLE_STATIC=OFF \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    ../../source 2>&1 | tee -a "$BUILD_LOG"
  check_status
  make -j"$(nproc)" 2>&1 | tee -a "$BUILD_LOG"
  check_status
  make install 2>&1 | tee -a "$INSTALL_LOG"
  check_status
}

# --- // Build fdk-aac:
build_fdk_aac() {
  echo "Building fdk-aac..." | tee -a "$BUILD_LOG"
  cd "$FFMPEG_SOURCES" || exit
  if [ ! -d "fdk-aac" ]; then
    git clone --depth 1 https://github.com/mstorsjo/fdk-aac.git 2>&1 | tee -a "$BUILD_LOG"
    check_status
  fi
  cd fdk-aac || exit
  autoreconf -fiv 2>&1 | tee -a "$BUILD_LOG"
  CFLAGS="-fPIC" ./configure --prefix="$FFMPEG_BUILD" --enable-shared --disable-static 2>&1 | tee -a "$BUILD_LOG"
  check_status
  make -j"$(nproc)" 2>&1 | tee -a "$BUILD_LOG"
  check_status
  make install 2>&1 | tee -a "$INSTALL_LOG"
  check_status
}

# --- // Build libvmaf:
build_libvmaf() {
  echo "Building libvmaf..." | tee -a "$BUILD_LOG"
  cd "$FFMPEG_SOURCES" || exit
  if [ ! -d "vmaf" ]; then
    git clone https://github.com/Netflix/vmaf.git 2>&1 | tee -a "$BUILD_LOG"
    check_status
  fi
  cd vmaf/libvmaf || exit
  if [ -d "build" ]; then
    rm -rf build 2>&1 | tee -a "$BUILD_LOG"
  fi
  meson setup build --prefix="$FFMPEG_BUILD" --buildtype release -Denable_float=true 2>&1 | tee -a "$BUILD_LOG"
  check_status
  meson compile -C build -j"$(nproc)" 2>&1 | tee -a "$BUILD_LOG"
  check_status
  meson install -C build 2>&1 | tee -a "$INSTALL_LOG"
  check_status
}

# --- // Build FFmpeg:
build_ffmpeg() {
  echo "Building FFmpeg..." | tee -a "$BUILD_LOG"
  cd "$FFMPEG_SOURCES" || exit

  # Clone or download FFmpeg source
  if [ -n "$FFmpeg_repo_url" ]; then
    if [ ! -d "ffmpeg" ]; then
      git clone "$FFmpeg_repo_url" ffmpeg 2>&1 | tee -a "$BUILD_LOG"
      check_status
    fi
  elif [ -n "$FFmpeg_tarball_url" ]; then
    if [ ! -d "ffmpeg" ]; then
      wget "$FFmpeg_tarball_url" -O ffmpeg.tar.bz2 2>&1 | tee -a "$BUILD_LOG"
      tar xjf ffmpeg.tar.bz2 2>&1 | tee -a "$BUILD_LOG"
      mv ffmpeg-*-git ffmpeg
      check_status
    fi
  else
    echo "Error: FFmpeg source not specified." | tee -a "$BUILD_LOG"
    exit 1
  fi

  cd ffmpeg || exit
  if [ -f "config.h" ]; then
    make distclean 2>&1 | tee -a "$BUILD_LOG"
  fi

  echo "Configuring FFmpeg build..." | tee -a "$BUILD_LOG"
  PKG_CONFIG_PATH="$FFMPEG_BUILD/lib/pkgconfig:$PKG_CONFIG_PATH" ./configure \
    --prefix="$FFMPEG_BUILD" \
    --pkg-config-flags="--static" \
    --extra-cflags="-I$FFMPEG_BUILD/include" \
    --extra-ldflags="-L$FFMPEG_BUILD/lib" \
    --extra-libs="-lpthread -lm" \
    --bindir="$FFMPEG_BIN" \
    --enable-gpl \
    --enable-nonfree \
    --enable-libfdk-aac \
    --enable-libx264 \
    --enable-libx265 \
    --enable-libvpx \
    --enable-libmp3lame \
    --enable-libopus \
    --enable-libvorbis \
    --enable-libass \
    --enable-libfreetype \
    --enable-libfribidi \
    --enable-libaom \
    --enable-libdav1d \
    --enable-libdrm \
    --enable-libxcb \
    --enable-libxvid \
    --enable-libsoxr \
    --enable-libwebp \
    --enable-libbluray \
    --enable-libtheora \
    --disable-libopenjpeg \
    --enable-librsvg \
    --enable-libshine \
    --enable-libspeex \
    --enable-libzimg \
    --enable-libvidstab \
    --enable-libsrt \
    --enable-version3 \
    --enable-libvmaf \
    --enable-vaapi \
    --enable-libmfx \
    --enable-opencl \
    --enable-opengl \
    --enable-libshaderc \
    --enable-libsvtav1 \
    --enable-libuavs3d \
    --enable-libxavs \
    --enable-libxavs2 \
    --enable-librubberband \
    --enable-libsnappy \
    --enable-libzmq \
    --enable-libzvbi \
    --enable-libopenmpt \
    --enable-frei0r \
    --enable-libplacebo \
    --enable-shared \
    --disable-static \
    --enable-pic \
    --enable-postproc \
    --enable-swscale \
    --enable-avfilter \
    --enable-pthreads \
    --enable-zlib \
    --enable-libxml2 \
    --enable-libfontconfig \
    --enable-gnutls 2>&1 | tee -a "$BUILD_LOG"
  check_status

  echo "Compiling FFmpeg..." | tee -a "$BUILD_LOG"
  make -j"$(nproc)" 2>&1 | tee -a "$BUILD_LOG"
  check_status
  make install 2>&1 | tee -a "$INSTALL_LOG"
  check_status
}

# --- // Build MPV:
build_mpv() {
  echo "Building MPV..." | tee -a "$BUILD_LOG"
  cd "$MPV_BUILD_DIR" || exit
  if [ ! -d "mpv" ]; then
    git clone https://github.com/mpv-player/mpv.git 2>&1 | tee -a "$BUILD_LOG"
    check_status
  fi
  cd mpv || exit
  git reset --hard HEAD 2>&1 | tee -a "$BUILD_LOG"
  git pull 2>&1 | tee -a "$BUILD_LOG"
  check_status

  if [ -d "build" ]; then
    rm -rf build 2>&1 | tee -a "$BUILD_LOG"
  fi

  echo "Configuring MPV build with Meson..." | tee -a "$BUILD_LOG"
  PKG_CONFIG_PATH="$FFMPEG_BUILD/lib/pkgconfig:$PKG_CONFIG_PATH" \
  meson setup build --prefix="$FFMPEG_BUILD" \
    --buildtype=release \
    -Dlibmpv=true \
    -Dlua=enabled \
    -Dsdl2=enabled \
    -Dlibarchive=enabled \
    -Dmanpage-build=enabled \
    -Djavascript=enabled \
    -Ddrm=enabled \
    -Ddvbin=enabled \
    -Dlibbluray=enabled \
    -Dpulse=enabled \
    -Djack=enabled \
    -Dpipewire=enabled \
    -Dwayland=enabled \
    -Dx11=enabled \
    -Dopenal=enabled \
    -Dvulkan=enabled \
    -Dvaapi=enabled 2>&1 | tee -a "$BUILD_LOG"
  check_status

  echo "Compiling MPV..." | tee -a "$BUILD_LOG"
  meson compile -C build -j"$(nproc)" 2>&1 | tee -a "$BUILD_LOG"
  check_status

  echo "Installing MPV..." | tee -a "$BUILD_LOG"
  meson install -C build 2>&1 | tee -a "$INSTALL_LOG"
  check_status
}

# --- // Update Library Cache:
update_library_cache() {
  echo "Updating library cache..." | tee -a "$BUILD_LOG"
  # For user-local installations, updating the system library cache is not necessary.
}

# --- // Verify Installation:
verify_installation() {
  echo "Verifying FFmpeg installation..." | tee -a "$BUILD_LOG"
  if command -v ffmpeg >/dev/null 2>&1; then
    which ffmpeg | tee -a "$BUILD_LOG"
    ffmpeg -version | tee -a "$BUILD_LOG"
    if ffmpeg -encoders | grep -q libx264; then
      echo "Custom FFmpeg with libx264 support is now in your PATH." | tee -a "$BUILD_LOG"
    else
      echo "Error: libx264 encoder not found in FFmpeg. Check the build and installation steps." | tee -a "$BUILD_LOG"
      exit 1
    fi
  else
    echo "Error: ffmpeg command not found in PATH. Ensure $FFMPEG_BIN is in your PATH." | tee -a "$BUILD_LOG"
    exit 1
  fi

  echo "Verifying MPV installation..." | tee -a "$BUILD_LOG"
  if command -v mpv >/dev/null 2>&1; then
    which mpv | tee -a "$BUILD_LOG"
    mpv --version | tee -a "$BUILD_LOG"
    echo "MPV is installed successfully." | tee -a "$BUILD_LOG"
  else
    echo "Error: mpv command not found in PATH. Ensure $FFMPEG_BIN is in your PATH." | tee -a "$BUILD_LOG"
    exit 1
  fi
}

# --- // Cleanup Function:
cleanup_previous_installation() {
  # Create logs directory if it doesn't exist
  mkdir -p "$(dirname "$BUILD_LOG")"

  echo "Cleaning up previous installations..." | tee -a "$BUILD_LOG"

  # Remove build directories
  rm -rf "$FFMPEG_SOURCES"
  rm -rf "$FFMPEG_BUILD"
  rm -rf "$MPV_BUILD_DIR"
  rm -rf "$HOME/yay"
  rm -f "$FFMPEG_BIN/ffmpeg" "$FFMPEG_BIN/ffprobe" "$FFMPEG_BIN/mpv"

  # Remove conflicting FFmpeg libraries in user's local directories
  FFmpeg_libs=(libavcodec.so.* libavdevice.so.* libavfilter.so.* libavformat.so.* libavutil.so.* libpostproc.so.* libswresample.so.* libswscale.so.*)
  for lib in "${FFmpeg_libs[@]}"; do
    find "$FFMPEG_BUILD/lib" -name "$lib" -exec rm -f {} \; 2>/dev/null
  done

  # Remove pkgconfig files
  find "$FFMPEG_BUILD/lib/pkgconfig" -name "libav*.pc" -exec rm -f {} \; 2>/dev/null

  echo "Previous installations have been cleaned up." | tee -a "$BUILD_LOG"
}

# --- // Main Execution:

if [ "$1" == "--clean" ]; then
  cleanup_previous_installation
  exit 0
fi

echo "Starting Custom FFmpeg and MPV Build..." | tee -a "$BUILD_LOG"
verify_dependencies
install_build_dependencies
select_ffmpeg_source_method
build_x264
build_x265
build_fdk_aac
build_libvmaf
build_ffmpeg
build_mpv
update_library_cache
verify_installation

# --- // Clean Up:
echo "Cleaning up temporary files..." | tee -a "$BUILD_LOG"
# Optionally, you can remove the source directories
# rm -rf "$FFMPEG_SOURCES"
# rm -rf "$MPV_BUILD_DIR"

echo "Custom FFmpeg and MPV build and installation completed successfully." | tee -a "$BUILD_LOG"
echo "Logs can be found in $LOG_DIR"