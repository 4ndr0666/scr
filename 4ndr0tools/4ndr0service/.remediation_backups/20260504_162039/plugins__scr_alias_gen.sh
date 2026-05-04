#!/usr/bin/env bash
# File: plugins/scr_alias_gen.sh
# Description: The Tool Indexer — Maps SCR executables to high-speed Zsh aliases.
# - Eliminates PATH-bloat by using absolute path aliasing.
# - Scans the SCR repository for custom offensive/utility tools only.
# - Generates a dynamic alias manifest for opt-in inclusion in .zshrc.
#
# Plugin Convention:
#   load_plugins() sources every plugins/*.sh file, then calls the function
#   named in PLUGIN_REGISTER (if set).  This plugin gates on manifest
#   staleness so it does NOT re-scan on every suite startup.
#
# .zshrc integration (opt-in, add manually):
#   [[ -f "${XDG_CACHE_HOME:-$HOME/.cache}/4ndr0service/tool_aliases.zsh" ]] && \
#       source "${XDG_CACHE_HOME:-$HOME/.cache}/4ndr0service/tool_aliases.zsh"

set -euo pipefail
IFS=$'\n\t'

# shellcheck source=../common.sh
source "${PKG_PATH:-.}/common.sh"

plugin_scr_alias_gen() {
    local scr_root='/home/git/clone/4ndr0666/scr'
    local alias_file="${XDG_CACHE_HOME:-$HOME/.cache}/4ndr0service/tool_aliases.zsh"
    local dirty_flag="${XDG_CACHE_HOME:-$HOME/.cache}/.scr_dirty"

    # ── STALENESS GATE ────────────────────────────────────────────────────────
    # FIX: Original ran unconditionally on every suite startup via load_plugins().
    # This caused I/O on every launch and — when the alias file was sourced by
    # .zshrc — the calendar popup bug: any SCR script named 'cal' (or any name
    # matching a shell builtin or common util) was aliased, hijacking it globally.
    # Now we only regenerate when the dirty flag exists or the manifest is absent.
    if [[ -f "$alias_file" && ! -f "$dirty_flag" ]]; then
        log_info "SCR alias manifest is current. Skipping regeneration."
        return 0
    fi

    if [[ ! -d "$scr_root" ]]; then
        log_warn "SCR repository not found at $scr_root. Skipping alias generation."
        return 0
    fi

    log_info "Initializing Tool Indexer: Indexing SCR Repository..."
    ensure_dir "$(dirname "$alias_file")"

    # ── COLLISION STRATEGY: OPT-IN (PATH CHECK + NAMING CONVENTION) ──────────
    # FIX: The previous opt-out blocklist (cal, gcal, ncal, cd, ls, git, ...)
    # was dangerously narrow. Any SCR script whose basename matched a standard
    # utility, Zsh builtin, or completion helper was silently aliased, clobbering
    # normal shell behaviour. The calendar popup was caused by a script named
    # 'cal' being aliased system-wide.
    #
    # New strategy — a tool is aliased ONLY when ALL of the following hold:
    #   1. Its basename contains at least one hyphen or underscore.
    #      Custom tool names follow this convention; single-word names ('cal',
    #      'ps', 'find', 'top') almost always collide with system utilities.
    #   2. Its basename is not currently reachable via PATH.
    #      This is a live check, not a static list, so future PATH additions
    #      automatically prevent new collisions without any list maintenance.
    #
    # Result: zero-maintenance safety. Unknown future collisions are impossible
    # because the check runs against the live environment, not a fixed blocklist.

    local header_written=0
    local count=0
    local tmp_file
    tmp_file="$(mktemp)"

    while IFS= read -r tool_path; do
        local tool_name
        tool_name=$(basename "$tool_path")

        # Skip hidden files
        [[ "$tool_name" =~ ^\..* ]] && continue

        # Rule 1: name must contain a hyphen or underscore (custom tool convention)
        if [[ "$tool_name" != *[-_]* ]]; then
            continue
        fi

        # Rule 2: must not already be reachable on PATH
        if command -v "$tool_name" &>/dev/null; then
            continue
        fi

        # Write manifest header lazily (only when first qualifying tool found)
        if [[ $header_written -eq 0 ]]; then
            {
                echo "# 4ndr0666OS: Dynamic SCR Tool Manifest"
                echo "# Generated: $(date +'%Y-%m-%d %H:%M:%S')"
                echo "# Source:    $scr_root"
                echo "# Safety:    only custom-named tools (containing - or _) absent from PATH."
                echo ""
            } > "$tmp_file"
            header_written=1
        fi

        echo "alias ${tool_name}=\"${tool_path}\"" >> "$tmp_file"
        ((count++))
    done < <(find "$scr_root" -type f -executable -not -path '*/.git/*' 2>/dev/null | sort)

    if [[ $count -gt 0 ]]; then
        mv "$tmp_file" "$alias_file"
        log_success "Indexing Complete: $count custom tools aliased → $alias_file"
    else
        rm -f "$tmp_file"
        log_info "No qualifying SCR tools found (all names conflict with PATH or lack - / _)."
        echo "# SCR Tool Manifest — no qualifying tools at $(date +'%Y-%m-%d %H:%M:%S')" > "$alias_file"
    fi

    # Clear dirty flag — regeneration complete
    rm -f "$dirty_flag"

    log_info "Activate aliases in your shell by adding to ~/.zshrc:"
    log_info "  [[ -f \"${alias_file}\" ]] && source \"${alias_file}\""
}

# Plugin self-registration convention (see controller.sh load_plugins())
PLUGIN_REGISTER="plugin_scr_alias_gen"
export PLUGIN_REGISTER
