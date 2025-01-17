#!/bin/bash
# File: optimize_ruby.sh
# Author: 4ndr0666
# Date: 2024-11-24
# Description: Optimizes Ruby environment.

set -euo pipefail
IFS=$'\n\t'

CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

LOG_FILE="${LOG_FILE:-$HOME/.cache/4ndr0service/logs/service_optimization.log}"
mkdir -p "$(dirname "$LOG_FILE")" || { echo "Failed to create log directory."; exit 1; }

log() {
    local message="$1"
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

handle_error() {
    local err_msg="$1"
    echo -e "${RED}❌ Error: $err_msg${NC}" >&2
    log "ERROR: $err_msg"
    exit 1
}

check_directory_writable() {
    local dir="$1"
    if [[ -w "$dir" ]]; then
        echo "✅ Directory $dir is writable."
        log "Directory '$dir' is writable."
    else
        handle_error "Directory $dir not writable."
    fi
}

export RUBY_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/ruby"
export RUBY_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/ruby"
export RUBY_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/ruby"

install_ruby() {
    if command -v ruby &> /dev/null; then
        echo "✅ Ruby already installed: $(ruby -v)"
        log "Ruby already installed."
    else
        echo "Installing Ruby..."
        if command -v pacman &> /dev/null; then
            sudo pacman -Syu --needed ruby || handle_error "Failed to install Ruby with pacman."
        else
            handle_error "Ruby missing. Use --fix to install."
        fi
        echo "✅ Ruby installed."
        log "Ruby installed."
    fi
}

gem_install_or_update() {
    local gem_name="$1"
    if gem list "$gem_name" -i &> /dev/null; then
        echo "🔄 Updating $gem_name gem..."
        if gem update "$gem_name"; then
            echo "✅ $gem_name gem updated."
            log "$gem_name gem updated."
        else
            echo "⚠️ Warning: Failed to update $gem_name."
            log "Warning: Failed to update $gem_name."
        fi
    else
        echo "📦 Installing $gem_name gem..."
        if gem install "$gem_name"; then
            echo "✅ $gem_name gem installed."
            log "$gem_name gem installed."
        else
            echo "⚠️ Warning: Failed to install $gem_name."
            log "Warning: Failed to install $gem_name."
        fi
    fi
}

npm_install_or_update() {
    local pkg_name="$1"
    if command -v npm &> /dev/null; then
        if npm ls -g "$pkg_name" --depth=0 &> /dev/null; then
            echo "🔄 Updating $pkg_name..."
            if npm update -g "$pkg_name"; then
                echo "✅ $pkg_name updated."
                log "$pkg_name updated."
            else
                echo "⚠️ Warning: Failed to update $pkg_name."
                log "Warning: Failed to update $pkg_name."
            fi
        else
            echo "📦 Installing $pkg_name globally..."
            if npm install -g "$pkg_name"; then
                echo "✅ $pkg_name installed."
                log "$pkg_name installed."
            else
                echo "⚠️ Warning: Failed to install $pkg_name."
                log "Warning: Failed to install $pkg_name."
            fi
        fi
    else
        echo "⚠️ npm not available, skipping $pkg_name."
        log "npm not available, skipping $pkg_name."
    fi
}

manage_ruby_versions() {
    if command -v rbenv &> /dev/null; then
        echo "🔄 Managing Ruby versions with rbenv..."
        if rbenv install -s "$(rbenv install -l | grep -v - | tail -1)"; then
            rbenv global "$(rbenv versions --bare | tail -1)" || log "Warning: Failed to set global Ruby with rbenv."
            echo "✅ Ruby managed with rbenv."
            log "Ruby managed with rbenv."
        else
            echo "⚠️ Warning: Failed to install Ruby version with rbenv."
            log "Warning: Failed rbenv Ruby install."
        fi
    elif command -v rvm &> /dev/null; then
        echo "🔄 Managing Ruby versions with RVM..."
        if rvm install ruby --latest; then
            rvm use ruby --default || log "Warning: Failed to set default Ruby with RVM."
            echo "✅ Ruby managed with RVM."
            log "Ruby managed with RVM."
        else
            echo "⚠️ Warning: Failed to install Ruby with RVM."
            log "Warning: Failed RVM Ruby install."
        fi
    else
        echo "⚠️ Neither RVM nor rbenv installed. Skipping Ruby version management."
        log "Neither RVM nor rbenv installed."
    fi
}

optimize_ruby_service() {
    echo "🔧 Starting Ruby environment optimization..."
    echo "📦 Checking if Ruby is installed..."
    install_ruby

    echo "🛠️ Setting up Ruby environment variables..."
    ruby_version=$(ruby -e 'puts RUBY_VERSION')
    GEM_HOME="$RUBY_DATA_HOME/gems/$ruby_version"
    GEM_PATH="$GEM_HOME"
    export GEM_HOME GEM_PATH
    export PATH="$GEM_HOME/bin:$PATH"
    mkdir -p "$GEM_HOME" "$RUBY_CONFIG_HOME" "$RUBY_CACHE_HOME" || handle_error "Failed to create Ruby directories."

    echo "🔐 Checking permissions..."
    check_directory_writable "$GEM_HOME"
    check_directory_writable "$RUBY_CONFIG_HOME"
    check_directory_writable "$RUBY_CACHE_HOME"

    echo "🔧 Ensuring common gems (bundler, rake) updated..."
    gem_install_or_update "bundler"
    gem_install_or_update "rake"

    echo "🔧 Installing Ruby linter (rubocop) and (optionally prettier)..."
    gem_install_or_update "rubocop"
    npm_install_or_update "prettier"

    echo "🛠️ Ensuring Bundler and RubyGems config..."
    if bundle config set --global path "$GEM_HOME"; then
        echo "✅ Bundler configured to use GEM_HOME."
        log "Bundler configured to GEM_HOME."
    else
        echo "⚠️ Warning: Failed to configure Bundler."
        log "Warning: Failed to configure Bundler."
    fi

    if gem sources --add https://rubygems.org/ --remove https://rubygems.org/ 2>/dev/null; then
        echo "✅ RubyGems source set."
        log "RubyGems source set."
    else
        echo "⚠️ Warning: Failed to configure RubyGems source."
        log "Warning: Failed to configure RubyGems source."
    fi

    echo "🔧 Managing Ruby versions (optional)..."
    manage_ruby_versions

    echo "🧼 Final cleanup..."
    if [[ -d "$RUBY_CACHE_HOME/tmp" ]]; then
        rm -rf "${RUBY_CACHE_HOME:?}/tmp" || log "Warning: Failed to remove $RUBY_CACHE_HOME/tmp."
        log "Cleaned $RUBY_CACHE_HOME/tmp."
    fi

    echo "🎉 Ruby environment optimization complete."
    echo -e "${CYAN}Ruby version:${NC} $(ruby -v)"
    echo -e "${CYAN}GEM_HOME:${NC} $GEM_HOME"
    echo -e "${CYAN}GEM_PATH:${NC} $GEM_PATH"
    log "Ruby environment optimization completed."
}
