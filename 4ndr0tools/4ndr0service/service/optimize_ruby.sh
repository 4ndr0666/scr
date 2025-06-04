#!/usr/bin/env bash
# shellcheck disable=all
# File: optimize_ruby.sh
# Description: Ruby environment optimization (XDG-compliant).

set -euo pipefail
IFS=$'\n\t'

# Colors
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# Logging
LOG_FILE="${LOG_FILE:-$HOME/.cache/4ndr0service/logs/service_optimization.log}"
mkdir -p "$(dirname "$LOG_FILE")" || { echo "Failed to create log directory."; exit 1; }

log() {
    local msg="$1"
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $msg" >> "$LOG_FILE"
}

handle_error() {
    local msg="$1"
    echo -e "${RED}❌ Error: $msg${NC}" >&2
    log "ERROR: $msg"
    exit 1
}

check_directory_writable() {
    local dir="$1"
    [[ -w "$dir" ]] \
        && { echo "✅ Directory $dir writable."; log "Dir '$dir' writable."; } \
        || handle_error "Directory $dir not writable."
}

export GEM_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/gem"
export GEM_PATH="$GEM_HOME"
export PATH="$GEM_HOME/bin:$PATH"

install_ruby() {
    if ! command -v ruby &>/dev/null; then
        echo "📦 Installing Ruby..."
        sudo pacman -S --needed --noconfirm ruby \
            || handle_error "Failed to install Ruby."
        log "Ruby installed."
    else
        echo "✅ Ruby present: $(ruby --version)"
        log "Ruby already installed."
    fi
}

gem_install_or_update() {
    local gem="$1"
    if gem list -i "$gem" &>/dev/null; then
        echo "🔄 Updating gem $gem..."
        gem update "$gem" \
            && log "Gem $gem updated." \
            || log "Warning: update failed for gem $gem."
    else
        echo "📦 Installing gem $gem..."
        gem install --user-install "$gem" \
            && log "Gem $gem installed." \
            || log "Warning: install failed for gem $gem."
    fi
}

optimize_ruby_service() {
    echo "🔧 Optimizing Ruby environment..."

    install_ruby

    ruby_version=$(ruby -e 'print RUBY_VERSION')
    GEM_HOME="$GEM_HOME/gems/$ruby_version"
    GEM_PATH="$GEM_HOME"
    export GEM_HOME GEM_PATH
    export PATH="$GEM_HOME/bin:$PATH"

    mkdir -p "$GEM_HOME" \
             "${XDG_CONFIG_HOME:-$HOME/.config}/ruby" \
             "${XDG_CACHE_HOME:-$HOME/.cache}/ruby" \
        || handle_error "Failed to create Ruby dirs."

    echo "🔐 Checking permissions..."
    check_directory_writable "$GEM_HOME"

    for g in bundler rake rubocop; do
        gem_install_or_update "$g"
    done

    echo -e "${CYAN}Ruby → $(ruby -v)${NC}"
    log "Ruby optimization completed."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    optimize_ruby_service
fi
