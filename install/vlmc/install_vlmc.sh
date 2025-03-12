#!/usr/bin/env sh
# VLMC Install Script - Automated installation of VLMC dependencies and build.
# Supports sh, bash, and zsh on Arch Linux with Wayland/Wayfire and XDG specifications.
# This script is idempotent and logs all critical steps.

set -e

# -------------------------------
# Logging Functions
# -------------------------------
log() {
  printf "[INFO] %s\n" "$*"
}

error() {
  printf "[ERROR] %s\n" "$*" >&2
}

# -------------------------------
# SSH Agent Setup
# -------------------------------
# Directly start the ssh-agent and add SSH keys (without relying on an alias).
if [ -z "$SSH_AGENT_PID" ]; then
  log "Starting ssh-agent..."
  eval "$(ssh-agent -s)"
fi
log "Adding SSH keys..."
ssh-add || log "No SSH key added or ssh-add failed. Continuing..."

# -------------------------------
# Dependency Installation Function
# -------------------------------
check_and_install() {
  for pkg in "$@"; do
    if ! pacman -Q "$pkg" >/dev/null 2>&1; then
      log "Installing package: $pkg"
      sudo pacman -S --needed "$pkg"
    else
      log "Package $pkg already installed."
    fi
  done
}

# Install base development dependencies and additional build tools.
check_and_install git base-devel autoconf automake libtool pkg-config meson ninja cmake

# -------------------------------
# Ensure PKG_CONFIG_PATH is Set Correctly
# -------------------------------
# To allow pkg-config to find libraries installed in /usr/local,
# ensure that /usr/local/lib/pkgconfig is included in PKG_CONFIG_PATH.
if [ -z "$PKG_CONFIG_PATH" ]; then
  export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig"
else
  case ":$PKG_CONFIG_PATH:" in
    *":/usr/local/lib/pkgconfig:"*) : ;;
    *) export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH" ;;
  esac
fi
log "PKG_CONFIG_PATH set to: $PKG_CONFIG_PATH"

# -------------------------------
# Git Repository Directory Setup
# -------------------------------
GIT_DIR="/home/git/clone"
if [ ! -d "$GIT_DIR" ]; then
  log "Creating git clone directory: $GIT_DIR"
  sudo mkdir -p "$GIT_DIR"
  sudo chown "$USER":"$USER" "$GIT_DIR"
fi

# -------------------------------
# Repository Management Functions
# -------------------------------
clone_repo() {
  repo_url="$1"
  repo_dir="$2"
  if [ -d "$repo_dir" ]; then
    log "Repository already exists: $repo_dir. Pulling latest changes."
    cd "$repo_dir" || { error "Failed to change directory to $repo_dir"; exit 1; }
    git pull || log "Warning: Failed to pull latest changes in $repo_dir. Continuing."
  else
    log "Cloning repository from $repo_url into $repo_dir"
    git clone "$repo_url" "$repo_dir" || { error "Failed to clone $repo_url"; exit 1; }
  fi
}

build_install() {
  repo_dir="$1"
  bootstrap_required="$2"  # "yes" if bootstrap is expected
  configure_options="$3"     # additional options for configure (if any)
  make_install="$4"          # "yes" if 'sudo make install' is required

  cd "$repo_dir" || { error "Failed to change directory to $repo_dir"; exit 1; }

  # Check for Meson build system.
  if [ -f "meson.build" ]; then
    log "Meson build system detected in $repo_dir"
    if [ ! -d "build" ]; then
      log "Setting up Meson build directory in $repo_dir/build"
      meson setup build || { error "Meson setup failed in $repo_dir"; exit 1; }
    else
      log "Meson build directory already exists in $repo_dir/build, reconfiguring..."
      meson configure build || { error "Meson configure failed in $repo_dir/build"; exit 1; }
    fi
    log "Building using Meson/Ninja in $repo_dir/build"
    ninja -C build || { error "Ninja build failed in $repo_dir/build"; exit 1; }
    if [ "$make_install" = "yes" ]; then
      log "Installing built binaries using Meson/Ninja from $repo_dir/build"
      sudo ninja -C build install || { error "Ninja install failed in $repo_dir/build"; exit 1; }
    fi
    return 0
  fi

  # Check for CMake build system.
  if [ -f "CMakeLists.txt" ]; then
    log "CMake build system detected in $repo_dir"
    if [ ! -d "build" ]; then
      log "Setting up CMake build directory in $repo_dir/build"
      mkdir -p build || { error "Failed to create build directory in $repo_dir"; exit 1; }
      cd build || { error "Failed to change directory to build in $repo_dir"; exit 1; }
      cmake .. || { error "CMake configuration failed in $repo_dir/build"; exit 1; }
    else
      cd build || { error "Failed to change directory to build in $repo_dir"; exit 1; }
      log "CMake build directory already exists in $repo_dir/build, reconfiguring..."
      cmake .. || { error "CMake configuration failed in $repo_dir/build"; exit 1; }
    fi
    log "Building using CMake in $repo_dir/build"
    make || { error "Make build failed in $repo_dir/build"; exit 1; }
    if [ "$make_install" = "yes" ]; then
      log "Installing built binaries using CMake from $repo_dir/build"
      sudo make install || { error "CMake install failed in $repo_dir/build"; exit 1; }
    fi
    return 0
  fi

  # Autotools build path:
  if [ "$bootstrap_required" = "yes" ]; then
    if [ -f "./bootstrap" ]; then
      log "Running bootstrap in $repo_dir"
      ./bootstrap || { error "Bootstrap failed in $repo_dir"; exit 1; }
    else
      log "Bootstrap script not found in $repo_dir; attempting autoreconf..."
      autoreconf -fis || { error "autoreconf failed in $repo_dir"; exit 1; }
    fi
  fi

  if [ -f "./configure" ]; then
    log "Running configure in $repo_dir"
    ./configure "$configure_options" || { error "Configure failed in $repo_dir"; exit 1; }
  else
    log "Configure script not found in $repo_dir; skipping configure step."
  fi

  log "Building in $repo_dir"
  make || { error "Build failed in $repo_dir"; exit 1; }

  if [ "$make_install" = "yes" ]; then
    log "Installing built binaries from $repo_dir"
    sudo make install || { error "Installation failed in $repo_dir"; exit 1; }
  fi
}

# -------------------------------
# Build Process for VLMC Components
# -------------------------------

# Install libvlcpp (Autotools)
LIBVLCPP_DIR="$GIT_DIR/libvlcpp"
clone_repo "https://code.videolan.org/videolan/libvlcpp.git" "$LIBVLCPP_DIR"
build_install "$LIBVLCPP_DIR" "yes" "" "yes"

# Install medialibrary (Meson)
MEDIALIB_DIR="$GIT_DIR/medialibrary"
clone_repo "https://code.videolan.org/videolan/medialibrary.git" "$MEDIALIB_DIR"
build_install "$MEDIALIB_DIR" "yes" "" "yes"

# Install MLT (CMake)
MLT_DIR="$GIT_DIR/mlt"
clone_repo "https://github.com/mltframework/mlt.git" "$MLT_DIR"
# For MLT, using CMake; set bootstrap_required to "no".
build_install "$MLT_DIR" "no" "" "yes"

# Build VLMC (Autotools)
VLMC_DIR="$GIT_DIR/vlmc"
clone_repo "https://code.videolan.org/videolan/vlmc.git" "$VLMC_DIR"
build_install "$VLMC_DIR" "yes" "" "no"

# -------------------------------
# Running VLMC
# -------------------------------
log "Running VLMC..."
cd "$VLMC_DIR" || { error "Failed to change directory to $VLMC_DIR"; exit 1; }
./vlmc || { error "Failed to run VLMC"; exit 1; }

log "VLMC installation and execution completed successfully."
