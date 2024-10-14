#!/bin/bash

# ================================== // INSTALL_CUSTOM_FFMPEG-MPV-VSP.SH //
# File: install_custom_ffmpeg-mpv-vsp.sh
# Author: 4ndr0666
# Date: 10-02-24
# Description: Builds x264, x265, FFmpeg, MPV and VSP plugins from source with error handling, logging,
# and installs them into user directories. Ensures that the custom-built FFmpeg and MPV are
# the ones used by updating environment variables. Also includes cleanup functionality with `--clean`.

# --- // Constants:
export FFMPEG_SOURCES="$HOME/ffmpeg_sources"
export FFMPEG_BUILD="$HOME/ffmpeg_build"
export FFMPEG_BIN="$HOME/bin"
export MPV_BUILD_DIR="$HOME/mpv_build"
export VSP_PLUGIN_DIR="$HOME/vapoursynth_plugins"
export LOG_DIR="$HOME/ffmpeg_mpv_build/logs"
export BUILD_LOG="$LOG_DIR/build.log"
export INSTALL_LOG="$LOG_DIR/install.log"

export PATH="$FFMPEG_BIN:$PATH"
export PKG_CONFIG_PATH="$FFMPEG_BUILD/lib/pkgconfig:$PKG_CONFIG_PATH"
export LD_LIBRARY_PATH="$FFMPEG_BUILD/lib:$LD_LIBRARY_PATH"

# --- // Create necessary directories:
mkdir -p "$LOG_DIR" "$FFMPEG_SOURCES" "$FFMPEG_BIN" "$FFMPEG_BUILD" "$MPV_BUILD_DIR" "$VSP_PLUGIN_DIR"

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
    sudo pacman -Sy --needed --noconfirm "${MISSING_TOOLS[@]}"
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
    base-devel git autoconf automake cmake extra-cmake-modules \
    yasm nasm pkgconf \
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
    libpulse alsa-lib \
    meson ninja

  check_status

  echo "Installing AUR packages..." | tee -a "$BUILD_LOG"
  yay -Sy --needed --noconfirm fdk-aac vmaf vapoursynth-plugin-mvtools vapoursynth-plugin-vivtc vapoursynth-plugin-f3kdb vapoursynth-plugin-ffms2 vapoursynth-plugin-svpflow
  check_status
}

# --- // Clone and Build Function:
clone_and_build() {
  local repo_url=$1
  local dir_name=$2
  local configure_cmd=$3
  local make_install_cmd=$4

  cd "$FFMPEG_SOURCES" || exit
  if [ ! -d "$dir_name" ]; then
    git clone "$repo_url" "$dir_name" 2>&1 | tee -a "$BUILD_LOG"
    check_status
  fi
  cd "$dir_name" || exit
  if [ -f "config.h" ] || [ -d "build" ]; then
    make distclean 2>&1 | tee -a "$BUILD_LOG" || true
    rm -rf build 2>&1 | tee -a "$BUILD_LOG" || true
  fi
  eval "$configure_cmd" 2>&1 | tee -a "$BUILD_LOG"
  check_status
  make -j"$(nproc)" 2>&1 | tee -a "$BUILD_LOG"
  check_status
  eval "$make_install_cmd" 2>&1 | tee -a "$INSTALL_LOG"
  check_status
}

# --- // Build x264:
echo "Building x264..." | tee -a "$BUILD_LOG"
clone_and_build \
  "https://code.videolan.org/videolan/x264.git" \
  "x264" \
  "PKG_CONFIG_PATH=\"$FFMPEG_BUILD/lib/pkgconfig\" ./configure --prefix=\"$FFMPEG_BUILD\" --bindir=\"$FFMPEG_BIN\" --enable-static --disable-opencl" \
  "make install"

# --- // Build x265:
echo "Building x265..." | tee -a "$BUILD_LOG"
cd "$FFMPEG_SOURCES" || exit
if [ ! -d "x265" ]; then
  git clone https://bitbucket.org/multicoreware/x265_git.git x265 2>&1 | tee -a "$BUILD_LOG"
  check_status
fi
cd x265/build/linux || exit
cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$FFMPEG_BUILD" -DENABLE_SHARED=off ../../source 2>&1 | tee -a "$BUILD_LOG"
check_status
make -j"$(nproc)" 2>&1 | tee -a "$BUILD_LOG"
check_status
make install 2>&1 | tee -a "$INSTALL_LOG"
check_status

# --- // Build fdk-aac:
echo "Building fdk-aac..." | tee -a "$BUILD_LOG"
clone_and_build \
  "https://github.com/mstorsjo/fdk-aac.git" \
  "fdk-aac" \
  "autoreconf -fiv && ./configure --prefix=\"$FFMPEG_BUILD\" --disable-shared" \
  "make install"

# --- // Build libvmaf:
echo "Building libvmaf..." | tee -a "$BUILD_LOG"
cd "$FFMPEG_SOURCES" || exit
if [ ! -d "vmaf" ]; then
  git clone https://github.com/Netflix/vmaf.git 2>&1 | tee -a "$BUILD_LOG"
  check_status
fi
cd vmaf/libvmaf || exit
meson setup build --prefix="$FFMPEG_BUILD" --buildtype release -Denable_float=true 2>&1 | tee -a "$BUILD_LOG"
check_status
meson compile -C build -j"$(nproc)" 2>&1 | tee -a "$BUILD_LOG"
check_status
meson install -C build 2>&1 | tee -a "$INSTALL_LOG"
check_status

# --- // Build FFmpeg:
echo "Building FFmpeg..." | tee -a "$BUILD_LOG"
cd "$FFMPEG_SOURCES" || exit
if [ ! -d "ffmpeg" ]; then
  git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg 2>&1 | tee -a "$BUILD_LOG"
  check_status
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
  --enable-gnutls \
  --disable-debug \
  --disable-doc 2>&1 | tee -a "$BUILD_LOG"
check_status

echo "Compiling FFmpeg..." | tee -a "$BUILD_LOG"
make -j"$(nproc)" 2>&1 | tee -a "$BUILD_LOG"
check_status
make install 2>&1 | tee -a "$INSTALL_LOG"
check_status

# --- // Build MPV:
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
PKG_CONFIG_PATH="$PKG_CONFIG_PATH" \
meson setup build --prefix="$FFMPEG_BUILD" \
  --bindir="$FFMPEG_BIN" \
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

# --- // Install VapourSynth Plugins:
install_vapoursynth_plugins() {
  echo "Installing VapourSynth plugins..." | tee -a "$BUILD_LOG"
  PLUGIN_LIST=(
    "https://github.com/darealshinji/vapoursynth-svpflow.git"
    "https://github.com/HomeOfAviSynthPlusEvolution/VapourSynth-DFTTest.git"
    "https://github.com/HomeOfVapourSynthEvolution/VapourSynth-BM3D.git"
  )

  for REPO_URL in "${PLUGIN_LIST[@]}"; do
    PLUGIN_NAME=$(basename "$REPO_URL" .git)
    cd "$VSP_PLUGIN_DIR" || exit
    if [ ! -d "$PLUGIN_NAME" ]; then
      git clone "$REPO_URL" "$PLUGIN_NAME" 2>&1 | tee -a "$BUILD_LOG"
      check_status
    fi
    cd "$PLUGIN_NAME" || exit
    if [ -f "Makefile" ] || [ -d "build" ]; then
      make distclean 2>&1 | tee -a "$BUILD_LOG" || true
      rm -rf build 2>&1 | tee -a "$BUILD_LOG" || true
    fi
    # Assume plugins use Meson or Autotools
    if [ -f "meson.build" ]; then
      meson setup build --prefix="$FFMPEG_BUILD" 2>&1 | tee -a "$BUILD_LOG"
      check_status
      meson compile -C build -j"$(nproc)" 2>&1 | tee -a "$BUILD_LOG"
      check_status
      meson install -C build 2>&1 | tee -a "$INSTALL_LOG"
      check_status
    elif [ -f "configure" ]; then
      ./configure --prefix="$FFMPEG_BUILD" 2>&1 | tee -a "$BUILD_LOG"
      check_status
      make -j"$(nproc)" 2>&1 | tee -a "$BUILD_LOG"
      check_status
      make install 2>&1 | tee -a "$INSTALL_LOG"
      check_status
    else
      echo "Unknown build system for $PLUGIN_NAME" | tee -a "$BUILD_LOG"
    fi
  done
}

install_vapoursynth_plugins

# --- // Update Library Cache:
echo "Updating library cache..." | tee -a "$BUILD_LOG"
ldconfig 2>&1 | tee -a "$BUILD_LOG"

# --- // Verify Installation:
echo "Verifying FFmpeg installation..." | tee -a "$BUILD_LOG"
which ffmpeg | tee -a "$BUILD_LOG"
ffmpeg -version | tee -a "$BUILD_LOG"
ffmpeg -encoders | grep libx264 | tee -a "$BUILD_LOG"
if ffmpeg -encoders | grep -q libx264; then
  echo "Custom FFmpeg with libx264 support is now in your PATH." | tee -a "$BUILD_LOG"
else
  echo "Error: libx264 encoder not found in FFmpeg. Check the build and installation steps." | tee -a "$BUILD_LOG"
  exit 1
fi

echo "Verifying MPV installation..." | tee -a "$BUILD_LOG"
which mpv | tee -a "$BUILD_LOG"
mpv --version | tee -a "$BUILD_LOG"
if mpv --version &>/dev/null; then
  echo "MPV is installed successfully in your user directory." | tee -a "$BUILD_LOG"
else
  echo "Error: MPV failed to run. Check for missing libraries or other issues." | tee -a "$BUILD_LOG"
  exit 1
fi

# --- // Clean Up:
echo "Cleaning up temporary files..." | tee -a "$BUILD_LOG"
rm -rf "$FFMPEG_SOURCES"
rm -rf "$MPV_BUILD_DIR"
rm -rf "$VSP_PLUGIN_DIR"

# --- // Cleanup Function:
cleanup_previous_installation() {
  echo "Cleaning up previous installations..." | tee -a "$BUILD_LOG"
  rm -rf "$FFMPEG_SOURCES"
  rm -rf "$FFMPEG_BUILD"
  rm -rf "$MPV_BUILD_DIR"
  rm -rf "$VSP_PLUGIN_DIR"
  rm -rf "$LOG_DIR"
  rm -rf "$HOME/yay"
  rm -f "$FFMPEG_BIN/ffmpeg" "$FFMPEG_BIN/ffprobe" "$FFMPEG_BIN/mpv"
  sed -i '/^export PATH=.*ffmpeg_build.*$/d' "$HOME/.bashrc"
  sed -i '/^export LD_LIBRARY_PATH=.*ffmpeg_build.*$/d' "$HOME/.bashrc"
  source "$HOME/.bashrc"
}

if [ "$1" == "--clean" ]; then
  cleanup_previous_installation
  echo "Previous installations have been cleaned up." | tee -a "$BUILD_LOG"
  exit 0
fi

# --- // Completion Message:
echo "Custom FFmpeg and MPV build and installation completed successfully." | tee -a "$BUILD_LOG"
echo "Logs can be found in $LOG_DIR"
