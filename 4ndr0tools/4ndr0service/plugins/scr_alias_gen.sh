#!/usr/bin/env bash
# File: plugins/scr_alias_gen.sh
# Description: The Tool Indexer — Maps SCR executables to high-speed Zsh aliases.
# - Eliminates PATH-bloat by using absolute path aliasing.
# - Scans the SCR repository for mission-critical offensive tools.
# - Generates a dynamic alias manifest for inclusion in .zshrc.
#
# Plugin Convention:
#   load_plugins() sources every plugins/*.sh file, then calls the function
#   named in PLUGIN_REGISTER (if set) so plugins self-register without
#   requiring load_plugins() to know their internal function names.

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
        return 0
    fi

    ensure_dir "$(dirname "$alias_file")"

    # Header
    {
        echo "# 4ndr0666OS: Dynamic SCR Tool Manifest"
        echo "# Generated on: $(date +'%Y-%m-%d %H:%M:%S')"
        echo "# Sourced by: .zshrc"
        echo ""
    } > "$alias_file"

    log_info "Scanning binary sectors in $scr_root..."

    local count=0
    while IFS= read -r tool_path; do
        local tool_name
        tool_name=$(basename "$tool_path")

        # Skip hidden files
        [[ "$tool_name" =~ ^\..* ]] && continue

        echo "alias ${tool_name}=\"${tool_path}\"" >> "$alias_file"
        ((count++))
    done < <(find "$scr_root" -type f -executable -not -path '*/.git/*' 2>/dev/null)

    log_success "Indexing Complete: $count tools mapped to high-speed aliases."
    log_info "Manifest stored at: $alias_file"

    # Signal shell to re-source the alias manifest
    touch "${XDG_CACHE_HOME}/.scr_dirty"
}

# FIX: Plugins were sourced by load_plugins() but never invoked — the function
#      definition was dead code.  Convention: each plugin exports PLUGIN_REGISTER
#      pointing to its entry-point function name.  load_plugins() in controller.sh
#      calls `"${PLUGIN_REGISTER}"` immediately after sourcing if the variable is
#      set, giving every plugin a guaranteed execution path with zero changes
#      required to controller.sh's plugin discovery loop.
PLUGIN_REGISTER="plugin_scr_alias_gen"
export PLUGIN_REGISTER

# .zshrc hook comment (not executed here):
# [ -f "${XDG_CACHE_HOME:-$HOME/.cache}/4ndr0service/tool_aliases.zsh" ] && \
#    source "${XDG_CACHE_HOME:-$HOME/.cache}/4ndr0service/tool_aliases.zsh"
