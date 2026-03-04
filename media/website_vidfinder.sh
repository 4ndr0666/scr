#!/usr/bin/env bash
# shellcheck disable=SC2154,SC2034,SC2001
#
# vidfinder.sh
# Ψ-4ndr0666 High-Performance Media Orchestrator (v2.0.0)
#
# COHESION REPORT:
# - Fixed: Added JSON-escape sanitization before regex extraction.
# - Fixed: Stripped query strings from filenames (e.g., ?token=...) to prevent FS errors.
# - Fixed: Injected tactical User-Agents across curl, ffmpeg, and streamlink to bypass WAFs.
# - Fixed: Implemented parallel backgrounding for static MP4 downloads.
# - Maintained: Interactive CLI menu and robust logging protocol.

set -euo pipefail

# -----------------------------
# Global State & Config
# -----------------------------
DOWNLOAD_DIR="${DOWNLOAD_DIR:-$HOME/Downloads/VidFinder}"
LOG_FILE="$DOWNLOAD_DIR/engine_log.txt"
DOWNLOAD_METHOD="streamlink"

# Tactical Headers for WAF Evasion
UA_STEALTH="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36"

# -----------------------------
# Utility Functions
# -----------------------------
setup_environment() {
    mkdir -p "$DOWNLOAD_DIR"
    touch "$LOG_FILE"
}

log_action() {
    local type="$1"
    local msg="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$type] $msg" >> "$LOG_FILE"
}

display() {
    local type="$1"
    local msg="$2"
    case "$type" in
        success) echo -e "\e[32m[+] $msg\e[0m"; log_action "SUCCESS" "$msg" ;;
        error)   echo -e "\e[31m[!] $msg\e[0m"; log_action "ERROR" "$msg" ;;
        warning) echo -e "\e[33m[-] $msg\e[0m"; log_action "WARNING" "$msg" ;;
        info)    echo -e "\e[36m[Ψ] $msg\e[0m"; log_action "INFO" "$msg" ;;
    esac
}

check_dependencies() {
    local deps=("curl" "ffmpeg" "streamlink" "grep" "sed")
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            display error "CRITICAL: Missing dependency -> $cmd"
            exit 1
        fi
    done
}

validate_url() {
    if [[ ! "$1" =~ ^https?:// ]]; then
        display error "Invalid Target URL: $1"
        return 1
    fi
    return 0
}

ensure_unique_filename() {
    local base="$1"
    local ext="$2"
    local target="$DOWNLOAD_DIR/$base.$ext"
    local counter=1

    while [[ -e "$target" ]]; do
        target="$DOWNLOAD_DIR/${base}_${counter}.${ext}"
        ((counter++))
    done
    echo "$target"
}

# -----------------------------
# Extraction & Download Engine
# -----------------------------
fetch_and_download() {
    local target_url="$1"
    display info "Initiating DOM extraction on: $target_url"

    # Fetch with stealth headers and timeout
    local page_content
    page_content=$(curl -s -m 15 -A "$UA_STEALTH" "$target_url") || {
        display error "Target unreachable or blocked."
        return 1
    }

    # Sanitize JSON-escaped slashes (e.g., https:\/\/domain.com)
    local clean_dom
    clean_dom=$(echo "$page_content" | sed 's/\\\//\//g')

    # Aggressive Regex: Matches http/https, ignores quotes/spaces, grabs up to .mp4 or .m3u8, includes optional query strings
    mapfile -t mp4_targets < <(echo "$clean_dom" | grep -Eo 'https?://[^"'\''[:space:]<>]+DASH[^"'\''[:space:]<>]*\.mp4(\?[^"'\''[:space:]<>]*)?' || true)
    mapfile -t m3u8_targets < <(echo "$clean_dom" | grep -Eo 'https?://[^"'\''[:space:]<>]+\.m3u8(\?[^"'\''[:space:]<>]*)?' || true)

    if [[ ${#mp4_targets[@]} -eq 0 && ${#m3u8_targets[@]} -eq 0 ]]; then
        display warning "Zero actionable media links identified in DOM."
        return 1
    fi

    # Phase 1: Parallel MP4 Extraction
    if [[ ${#mp4_targets[@]} -gt 0 ]]; then
        display success "Identified ${#mp4_targets[@]} static MP4 targets."
        
        for vid in "${mp4_targets[@]}"; do
            # Strip query strings for clean filesystem naming
            local raw_name
            raw_name=$(basename "$vid" | cut -d? -f1)
            local clean_target
            clean_target=$(ensure_unique_filename "${raw_name%.*}" "mp4")
            
            display info "Spawning async download: $clean_target"
            # Background the curl process for concurrency
            curl -s -A "$UA_STEALTH" -o "$clean_target" "$vid" && log_action "SUCCESS" "Downloaded $vid" &
        done
        
        display info "Waiting for async MP4 downloads to resolve..."
        wait
        display success "Static MP4 Matrix complete."
    fi

    # Phase 2: Sequential HLS/M3U8 Stream Ripping
    if [[ ${#m3u8_targets[@]} -gt 0 ]]; then
        display success "Identified ${#m3u8_targets[@]} HLS/m3u8 stream targets."

        for stream in "${m3u8_targets[@]}"; do
            local raw_name
            raw_name=$(basename "$stream" | cut -d? -f1)
            local clean_target
            clean_target=$(ensure_unique_filename "${raw_name%.*}" "mp4")

            display info "Ripping Stream -> $clean_target via $DOWNLOAD_METHOD"

            if [[ "$DOWNLOAD_METHOD" == "ffmpeg" ]]; then
                ffmpeg -hide_banner -loglevel error -user_agent "$UA_STEALTH" -i "$stream" -c copy "$clean_target" && \
                display success "Stream secured: $clean_target" || \
                display error "FFmpeg stream failure: $stream"
                
            elif [[ "$DOWNLOAD_METHOD" == "streamlink" ]]; then
                streamlink --http-header "User-Agent=$UA_STEALTH" "$stream" best -o "$clean_target" >/dev/null 2>&1 && \
                display success "Stream secured: $clean_target" || \
                display error "Streamlink failure: $stream"
            fi
        done
    fi
}

# -----------------------------
# Interface & Menu
# -----------------------------
main_menu() {
    while true; do
        echo -e "\n\e[1;35m==== Ψ-4NDR0666 VIDFINDER MATRIX ====\e[0m"
        echo -e "\e[36mCurrent Output Dir: $DOWNLOAD_DIR\e[0m"
        echo -e "\e[36mStream Method:      $DOWNLOAD_METHOD\e[0m\n"
        echo "1) Acquire Target (Enter URL)"
        echo "2) Reconfigure Output Directory"
        echo "3) Toggle Stream Ripping Engine (ffmpeg/streamlink)"
        echo "4) Sever Connection (Exit)"
        echo -n "> "
        read -r choice

        case "$choice" in
            1)
                echo -n "[?] Target URL: "
                read -r target_url
                if validate_url "$target_url"; then
                    fetch_and_download "$target_url"
                fi
                ;;
            2)
                echo -n "[?] New Absolute Path: "
                read -r new_dir
                if mkdir -p "$new_dir" 2>/dev/null; then
                    DOWNLOAD_DIR="$new_dir"
                    LOG_FILE="$DOWNLOAD_DIR/engine_log.txt"
                    display success "Output matrix shifted to: $DOWNLOAD_DIR"
                else
                    display error "Insufficient permissions for path."
                fi
                ;;
            3)
                if [[ "$DOWNLOAD_METHOD" == "streamlink" ]]; then
                    DOWNLOAD_METHOD="ffmpeg"
                else
                    DOWNLOAD_METHOD="streamlink"
                fi
                display success "Engine toggled to: $DOWNLOAD_METHOD"
                ;;
            4)
                display info "Terminating script."
                exit 0
                ;;
            *)
                display warning "Invalid protocol."
                ;;
        esac
    done
}

# -----------------------------
# Boot Sequence
# -----------------------------
setup_environment
check_dependencies

# If arguments were passed directly, bypass menu
if [[ $# -gt 0 ]]; then
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            -u|--url) target_url="$2"; shift 2 ;;
            -d|--download-dir) DOWNLOAD_DIR="$2"; shift 2 ;;
            -m|--method) DOWNLOAD_METHOD="$2"; shift 2 ;;
            *) display error "Unknown flag: $1"; exit 1 ;;
        esac
    done
    setup_environment
    if validate_url "${target_url:-}"; then
        fetch_and_download "$target_url"
    fi
    exit 0
fi

# Otherwise, trigger the interactive matrix
main_menu
