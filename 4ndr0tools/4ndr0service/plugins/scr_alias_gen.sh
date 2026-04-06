#!/usr/bin/env bash
# File: plugins/scr_alias_gen.sh
# Description: The Tool Indexer - Maps SCR executables to high-speed Zsh aliases.
# - Eliminates PATH-bloat by using absolute path aliasing.
# - Scans the SCR repository for mission-critical offensive tools.
# - Generates a dynamic alias manifest for inclusion in .zshrc.

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=../common.sh
source "${PKG_PATH:-.}/common.sh"

plugin_scr_alias_gen() {
    log_info "Initializing Tool Indexer: Indexing SCR Repository..."
    
    local scr_root='/home/git/clone/4ndr0666/scr'
    local alias_file="${XDG_CACHE_HOME:-$HOME/.cache}/4ndr0service/tool_aliases.zsh"
    
    if [[ ! -d "$scr_root" ]]; then
        log_warn "SCR repository not found at $scr_root. Skipping alias generation."
        return 1
    fi

    ensure_dir "$(dirname "$alias_file")"
    
    # 1. Header Generation
    echo "# 4ndr0666OS: Dynamic SCR Tool Manifest" > "$alias_file"
    echo "# Generated on: $(date +'%Y-%m-%d %H:%M:%S')" >> "$alias_file"
    echo "# Sourced by: .zshrc" >> "$alias_file"
    echo "" >> "$alias_file"

    log_info "Scanning binary sectors in $scr_root..."
    
    local count=0
    # 2. Recursive Discovery
    # Finds all executable files (-executable), excluding .git and hidden artifacts
    while IFS= read -r tool_path; do
        local tool_name
        tool_name=$(basename "$tool_path")
        
        # Filter: Skip hidden files and common system noise
        [[ "$tool_name" =~ ^\..* ]] && continue
        
        # 3. Alias Injection
        # We use absolute pathing to guarantee zero-drift execution
        echo "alias $tool_name=\"$tool_path\"" >> "$alias_file"
        ((count++))
    done < <(find "$scr_root" -type f -executable -not -path '*/.git/*' 2>/dev/null)

    log_success "Indexing Complete: $count tools mapped to high-speed aliases."
    log_info "Manifest stored at: $alias_file"
    
    # 4. Trigger Shell Invalidation
    touch "${XDG_CACHE_HOME}/.scr_dirty"
}

# Implementation Hook: Add this to your .zshrc for full automation
# [ -f "${XDG_CACHE_HOME:-$HOME/.cache}/4ndr0service/tool_aliases.zsh" ] && \
#    source "${XDG_CACHE_HOME:-$HOME/.cache}/4ndr0service/tool_aliases.zsh"
