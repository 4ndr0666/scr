#!/usr/bin/env bash
# File: optimize_meson.sh
# Author: 4ndr0666
# Description: Meson environment optimization for Arch-based systems,
# handling externally-managed environment constraints gracefully.

set -euo pipefail
IFS=$'\n\t'

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

LOG_FILE="${LOG_FILE:-$HOME/.cache/4ndr0service/logs/service_optimization.log}"
mkdir -p "$(dirname "$LOG_FILE")" || {
    echo "Failed to create log directory for Meson optimization."
    exit 1
}

log() {
    local msg="$1"
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $msg" >> "$LOG_FILE"
}

handle_error() {
    local e="$1"
    echo -e "${RED}❌ Error: $e${NC}" >&2
    log "ERROR: $e"
    exit 1
}

attempt_pacman_install() {
    local pkg="$1"
    if ! command -v pacman &>/dev/null; then
        echo -e "${YELLOW}⚠ No pacman found. Cannot fallback to install $pkg.${NC}"
        log "No pacman fallback for $pkg."
        return 1
    fi
    echo "Attempting sudo pacman -S --needed --noconfirm $pkg..."
    if sudo pacman -S --needed --noconfirm "$pkg"; then
        echo -e "${GREEN}✅ $pkg installed via pacman fallback.${NC}"
        log "$pkg installed via pacman fallback."
        return 0
    else
        echo -e "${YELLOW}⚠ pacman fallback failed for $pkg.${NC}"
        log "pacman fallback failed for $pkg."
        return 1
    fi
}

export MESON_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/meson"
export MESON_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/meson"
export MESON_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/meson"

install_meson() {
    if command -v meson &>/dev/null; then
        echo -e "${GREEN}✅ Meson is already installed: $(meson --version)${NC}"
        log "Meson is already installed."
        return
    fi
    attempt_pacman_install "meson" || true
    if ! command -v meson &>/dev/null; then
        handle_error "Meson not found even after pacman attempt."
    fi
}

setup_meson_environment() {
    export PATH="$MESON_HOME/bin:$PATH"
    echo -e "${GREEN}✅ Meson environment variables set.${NC}"
    log "Extended PATH with $MESON_HOME/bin."
}

check_directory_writable() {
    local d="$1"
    if [[ ! -w "$d" ]]; then
        handle_error "Directory $d is not writable."
    else
        echo -e "${GREEN}✅ Directory $d is writable.${NC}"
        log "Directory '$d' is writable."
    fi
}

configure_additional_backends() {
    echo "⚙️ Configuring additional Meson backends (optional)..."
    local build_dir="$MESON_HOME/build"
    if [[ -d "$build_dir" ]]; then
        echo "📁 Build dir already exists => $build_dir"
        log "Meson build dir $build_dir already exists."
    else
        echo "📁 Creating Meson build dir => $build_dir"
        mkdir -p "$build_dir" || handle_error "Failed to create build dir $build_dir."
        if ! meson setup "$build_dir" --backend=ninja; then
            echo -e "${YELLOW}⚠ Warning: meson setup $build_dir failed.${NC}"
            log "meson setup failed for $build_dir."
        else
            echo "✅ Meson build directory created at $build_dir."
            log "Meson build directory created at $build_dir."
        fi
    fi
}

consolidate_directories() {
    local source_dir="$1"
    local target_dir="$2"
    if [[ -d "$source_dir" ]]; then
        rsync -av "$source_dir/" "$target_dir/" || echo -e "${YELLOW}⚠ rsync from $source_dir to $target_dir failed.${NC}"
        rm -rf "$source_dir"
        echo "✅ Consolidated $source_dir => $target_dir."
        log "Consolidated $source_dir => $target_dir."
    else
        echo -e "${YELLOW}⚠ No $source_dir => skipping consolidation.${NC}"
        log "Skipping consolidation => no $source_dir."
    fi
}

perform_final_cleanup() {
    echo "🧼 Final cleanup..."
    if [[ -d "$MESON_CACHE_HOME/tmp" ]]; then
        echo "🗑 Removing $MESON_CACHE_HOME/tmp..."
        rm -rf "${MESON_CACHE_HOME:?}/tmp" || log "Cannot remove $MESON_CACHE_HOME/tmp."
        log "Removed $MESON_CACHE_HOME/tmp."
    fi
    echo -e "${GREEN}🧼 Cleanup done.${NC}"
    log "Meson final cleanup done."
}

validate_meson_installation() {
    echo "✅ Validating Meson installation..."
    if ! command -v meson &>/dev/null; then
        handle_error "Meson missing after installation."
    fi
    if ! command -v ninja &>/dev/null; then
        handle_error "Ninja missing after installation."
    fi
    echo "✅ Meson and Ninja are installed correctly."
    log "Meson and Ninja validated."
}

optimize_meson_service() {
    echo -e "${CYAN}🔧 Starting Meson build system environment optimization...${NC}"
    install_meson
    mkdir -p "$MESON_HOME" || handle_error "Cannot create $MESON_HOME."
    setup_meson_environment
    check_directory_writable "$MESON_HOME"
    echo "⚙️ Configuring additional Meson backends..."
    configure_additional_backends
    echo "🧹 Consolidating Meson directories..."
    consolidate_directories "$HOME/.meson" "$MESON_HOME"
    perform_final_cleanup
    validate_meson_installation

    echo -e "${GREEN}🎉 Meson environment optimization complete.${NC}"
    echo -e "${CYAN}Meson version:${NC} $(meson --version 2>/dev/null || echo 'N/A')"
    echo -e "${CYAN}Ninja version:${NC} $(ninja --version 2>/dev/null || echo 'N/A')"
    echo -e "${CYAN}MESON_HOME:${NC} $MESON_HOME"
    echo -e "${CYAN}MESON_CONFIG_HOME:${NC} $MESON_CONFIG_HOME"
    echo -e "${CYAN}MESON_CACHE_HOME:${NC} $MESON_CACHE_HOME"
    log "Meson environment optimization completed."
}
