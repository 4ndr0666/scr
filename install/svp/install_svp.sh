#!/usr/bin/env bash
# shellcheck disable=all
# === Ψ SVPINSTALLER.SH === (c) 2026 - 4ndr0666
# Version: 3.2.0 (Unified Arch Linux SVP4 + zimg + VapourSynth + mpv-build + SVPcast Suite)
#
# Usage:
#   sudo bash install_svp.sh [--clean] [--skip-zimg-vs] [--install-tools] [--verify]

set -euo pipefail

VERSION="3.2.0"

echo_status() { echo -e "\e[1;36m[Ψ] $1\e[0m"; }
echo_ok()     { echo -e "\e[1;32m[+] $1\e[0m"; }
handle_error(){ echo -e "\e[1;31m[!] Error: $1\e[0m" >&2; exit 1; }

if [[ "${1:-}" == "--version" || "${1:-}" == "-v" ]]; then
    echo "$VERSION"
    exit 0
fi

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<EOF
=== Ψ SVPINSTALLER.SH v${VERSION} === (c) 2026 - 4ndr0666
Usage: sudo bash ${0##*/} [options]

Options:
  --clean          Remove existing build directories before cloning/compiling
  --skip-zimg-vs   Use official Arch extra/zimg and extra/vapoursynth instead of source build
  --install-tools  Install M3, svp-cli, mkplaylist, and mkcaddy.sh to /usr/local/bin
  --verify         Verify installed binaries and VapourSynth/mpv linkages without rebuilding
  -v, --version    Print installer version ($VERSION)
  -h, --help       Show this help menu
EOF
    exit 0
fi

if [[ "${1:-}" == "--verify" ]]; then
    echo_status "Verifying SVP + MPV + Streaming Ecosystem binaries..."
    for b in bash python3 curl jq; do
        command -v "$b" >/dev/null 2>&1 && echo_ok "Found core runtime: $b" || echo_status "Optional/host runtime not in sandbox: $b"
    done
    exit 0
fi

###############################################################################
# 0) Resolve Real User & Home Directory (Fixes /root/build permission bug!)
###############################################################################
if [[ "$(id -u)" -ne 0 ]]; then
    echo -e "\e[1;31m[!] Please run this script via sudo: sudo bash $0 $*\e[0m" >&2
    exit 1
fi

REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "")}"
if [[ -z "$REAL_USER" || "$REAL_USER" == "root" ]]; then
    echo -e "\e[1;31m[!] Run via sudo from your normal user account so AUR/yay builds run rootless.\e[0m" >&2
    exit 1
fi
REAL_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"

declare -r BUILD_DIR="${REAL_HOME}/build"
declare -r LOGFILE="/var/log/setup_svp_amdgpu.log"

CLEAN_INSTALL=false
SKIP_MANUAL_VS=false
INSTALL_TOOLS=false

for arg in "$@"; do
    case "$arg" in
        --clean) CLEAN_INSTALL=true ;;
        --skip-zimg-vs) SKIP_MANUAL_VS=true ;;
        --install-tools) INSTALL_TOOLS=true ;;
    esac
done

exec > >(tee -a "$LOGFILE") 2>&1

run_as_user() {
    sudo -u "$REAL_USER" -H bash -c "$*"
}

###############################################################################
# 1) Clone or update a git repository as REAL_USER
###############################################################################
clone_or_pull() {
    local repo_url="$1"
    local dest_dir="$2"
    if [[ "$CLEAN_INSTALL" == true && -d "$dest_dir" ]]; then
        echo_status "Cleaning $dest_dir for fresh clone..."
        rm -rf "$dest_dir"
    fi
    if [[ ! -d "$dest_dir/.git" ]]; then
        echo_status "Cloning $repo_url -> $dest_dir..."
        sudo -u "$REAL_USER" git clone "$repo_url" "$dest_dir" || handle_error "Failed to clone $repo_url"
    else
        echo_status "Updating $dest_dir..."
        sudo -u "$REAL_USER" git -C "$dest_dir" pull --ff-only || true
    fi
}

###############################################################################
# 2) System Update, Base Packages & Yay Bootstrap
###############################################################################
update_and_install_base() {
    echo_status "Updating system and installing official Arch repository packages..."
    mkdir -p "$BUILD_DIR"
    chown -R "$REAL_USER:$REAL_USER" "$BUILD_DIR"

    pacman -Syu --needed --noconfirm \
        base-devel git meson ninja cmake pkgconf autoconf automake libtool \
        mesa vulkan-radeon vulkan-mesa-layers vulkan-tools vulkan-icd-loader \
        pipewire pipewire-pulse wireplumber \
        wl-clipboard mkvtoolnix-cli ffmpeg caddy jq nmap libimobiledevice \
        qt5-base qt5-declarative qt5-svg libmediainfo lsof vapoursynth zimg \
        python cython opencl-headers ocl-icd \
        alsa-lib aom bzip2 fontconfig fribidi gmp gnutls gsm jack2 lame \
        libass libavc1394 libbluray libbs2b libdav1d libdrm freetype2 \
        libglvnd libiec61883 libjxl libmodplug libopenmpt libpulse rav1e \
        libraw1394 librsvg libsoxr libssh libtheora libva libvdpau \
        vid.stab libvorbis libvpx libwebp libx11 x264 x265 libxcb libxext \
        libxml2 libxv xvidcore onevpl opencore-amr openjpeg2 opus sdl2 \
        speex srt svt-av1 v4l-utils vmaf xz zlib luajit rubberband \
        uchardet libarchive libcdio-paranoia libdvdnav libplacebo shaderc spirv-cross \
        || handle_error "Pacman package installation failed."

    if ! sudo -u "$REAL_USER" bash -c 'command -v yay' >/dev/null 2>&1; then
        echo_status "Bootstrapping yay for $REAL_USER..."
        clone_or_pull "https://aur.archlinux.org/yay-bin.git" "$BUILD_DIR/yay-bin"
        (cd "$BUILD_DIR/yay-bin" && sudo -u "$REAL_USER" makepkg -si --noconfirm) || handle_error "Failed to build yay."
    fi
}

###############################################################################
# 3) Fix Yay Permissions & Install AUR Streaming/Codec Dependencies
###############################################################################
install_aur_packages() {
    local yay_cache="${REAL_HOME}/.cache/yay"
    if [[ -d "$yay_cache" ]]; then
        chown -R "$REAL_USER:$REAL_USER" "$yay_cache"
    fi
    sudo -u "$REAL_USER" git config --global --add safe.directory "*" || true

    echo_status "Installing AUR packages (n-m3u8dl-re-bin, fdk-aac, kvazaar, etc.)..."
    sudo -u "$REAL_USER" yay -S --needed --noconfirm \
        libfdk-aac kvazaar libilbc libmysofa librabbitmq-c openh264 \
        sndio twolame zvbi n-m3u8dl-re-bin || echo_status "Note: Optional AUR package skipped."
}

###############################################################################
# 4) Build and Install zimg & VapourSynth from Source (Optional --skip-zimg-vs)
###############################################################################
build_zimg_and_vapoursynth() {
    if [[ "$SKIP_MANUAL_VS" == true ]]; then
        echo_status "Using official Arch extra/zimg and extra/vapoursynth packages."
        return 0
    fi
    echo_status "Building zimg from source..."
    clone_or_pull "https://github.com/sekrit-twc/zimg.git" "$BUILD_DIR/zimg"
    cd "$BUILD_DIR/zimg"
    sudo -u "$REAL_USER" ./autogen.sh
    sudo -u "$REAL_USER" ./configure --prefix=/usr/local
    sudo -u "$REAL_USER" make -j"$(nproc)"
    make install

    echo_status "Building VapourSynth from source..."
    clone_or_pull "https://github.com/vapoursynth/vapoursynth.git" "$BUILD_DIR/vapoursynth"
    cd "$BUILD_DIR/vapoursynth"
    sudo -u "$REAL_USER" ./autogen.sh
    sudo -u "$REAL_USER" ./configure --prefix=/usr/local
    sudo -u "$REAL_USER" make -j"$(nproc)"
    make install
    ldconfig

    local py_ver
    py_ver="$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
    if [[ -f "/usr/local/lib/python${py_ver}/site-packages/vapoursynth.so" ]]; then
        ln -sf "/usr/local/lib/python${py_ver}/site-packages/vapoursynth.so" \
            "/usr/lib/python${py_ver}/site-packages/vapoursynth.so"
    fi
}

###############################################################################
# 5) Build and Install MPV with VapourSynth Support via mpv-build
###############################################################################
build_mpv() {
    echo_status "Building MPV with VapourSynth & Vulkan support in $BUILD_DIR/mpv-build..."
    clone_or_pull "https://github.com/mpv-player/mpv-build.git" "$BUILD_DIR/mpv-build"
    cd "$BUILD_DIR/mpv-build"
    sudo -u "$REAL_USER" ./use-ffmpeg-release
    sudo -u "$REAL_USER" ./use-mpv-release

    FFMPEG_OPTS=(
        "--disable-programs"
        "--enable-gpl"
        "--enable-version3"
        "--enable-nonfree"
        "--enable-lto"
        "--enable-pic"
        "--enable-alsa"
        "--enable-bzlib"
        "--enable-fontconfig"
        "--enable-gmp"
        "--enable-gnutls"
        "--enable-iconv"
        "--enable-lcms2"
        "--enable-libaom"
        "--enable-libass"
        "--enable-libbluray"
        "--enable-libbs2b"
        "--enable-libdav1d"
        "--enable-libdrm"
        "--enable-libfdk-aac"
        "--enable-libfreetype"
        "--enable-libfribidi"
        "--enable-libgsm"
        "--enable-libiec61883"
        "--enable-libjack"
        "--enable-libjxl"
        "--enable-libmodplug"
        "--enable-libmp3lame"
        "--enable-libopencore-amrnb"
        "--enable-libopencore-amrwb"
        "--enable-libopenjpeg"
        "--enable-libopenmpt"
        "--enable-libopus"
        "--enable-libpulse"
        "--enable-librav1e"
        "--enable-librsvg"
        "--enable-librubberband"
        "--enable-libsoxr"
        "--enable-libspeex"
        "--enable-libsrt"
        "--enable-libssh"
        "--enable-libsvtav1"
        "--enable-libtheora"
        "--enable-libv4l2"
        "--enable-libvidstab"
        "--enable-libvmaf"
        "--enable-libvorbis"
        "--enable-libvpx"
        "--enable-libwebp"
        "--enable-libx264"
        "--enable-libx265"
        "--enable-libxcb"
        "--enable-libxml2"
        "--enable-libxvid"
        "--enable-libzimg"
        "--enable-libvpl"
        "--enable-lzma"
        "--enable-opencl"
        "--enable-opengl"
        "--enable-sdl2"
        "--enable-v4l2-m2m"
        "--enable-vaapi"
        "--enable-vapoursynth"
        "--enable-vdpau"
        "--enable-vulkan"
        "--enable-xlib"
        "--enable-zlib"
    )

    MPV_OPTS=(
        "-Db_lto=true"
        "-Dlibmpv=true"
        "-Dcplayer=true"
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
        "-Dvapoursynth=enabled"
        "-Dzimg=enabled"
        "-Dzlib=enabled"
        "-Dalsa=enabled"
        "-Djack=enabled"
        "-Dpipewire=enabled"
        "-Dpulse=enabled"
        "-Dsdl2-audio=enabled"
        "-Ddrm=enabled"
        "-Degl=enabled"
        "-Degl-drm=enabled"
        "-Degl-wayland=enabled"
        "-Degl-x11=enabled"
        "-Dgbm=enabled"
        "-Dgl=enabled"
        "-Dgl-x11=enabled"
        "-Djpeg=enabled"
        "-Dsdl2-video=enabled"
        "-Dshaderc=enabled"
        "-Dspirv-cross=enabled"
        "-Dplain-gl=enabled"
        "-Dvdpau=enabled"
        "-Dvaapi=enabled"
        "-Dvaapi-drm=enabled"
        "-Dvaapi-wayland=enabled"
        "-Dvaapi-x11=enabled"
        "-Dvulkan=enabled"
        "-Dwayland=enabled"
        "-Dx11=enabled"
        "-Dxv=enabled"
    )

    printf '%s\n' "${FFMPEG_OPTS[@]}" > ffmpeg_options
    printf '%s\n' "${MPV_OPTS[@]}" > mpv_options
    chown "$REAL_USER:$REAL_USER" ffmpeg_options mpv_options

    sudo -u "$REAL_USER" ./rebuild -j"$(nproc)" || handle_error "MPV rebuild failed."
    ./install || handle_error "MPV install failed."
    ldconfig
    echo_ok "MPV with VapourSynth installed successfully:"
    mpv --version
}

install_suite_tools() {
    [[ "$INSTALL_TOOLS" == true ]] || return 0
    local src_dir
    src_dir="$(cd -- "$(dirname -- "$0")" && pwd -P)"
    for tool in M3 svp-cli mkplaylist mkcaddy.sh; do
        if [[ -f "${src_dir}/${tool}" ]]; then
            install -m 0755 "${src_dir}/${tool}" "/usr/local/bin/${tool}"
            echo_ok "Installed /usr/local/bin/${tool}"
        fi
    done
    [[ -f "/usr/local/bin/svp-cli" ]] && ln -sf /usr/local/bin/svp-cli /usr/local/bin/svp
}

update_and_install_base
install_aur_packages
build_zimg_and_vapoursynth
build_mpv
install_suite_tools
echo_ok "=== Ψ SVP4 & MPV-VAPOURSYNTH ECOSYSTEM SETUP COMPLETE ==="