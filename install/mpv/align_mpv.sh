#!/usr/bin/env bash

# ==============================================================================
# AUTHOR: 4ndr0666
# NAME: MPV-ALIGN-OS (Fortified Final Revision)
# VERSION: 3.0.0
# MANDATE: Idempotent | Modular | Production-Ready
# ==============================================================================

set -e

# --- [ INITIALIZATION & INVENTORY ] ---
CONF_PATH="${XDG_CONFIG_HOME:-$HOME/.config}/mpv/mpv.conf"
BACKUP_PATH="${CONF_PATH}.bak"

declare -A GPU_MAP=(
    ["INTEL"]="vaapi"
    ["AMD"]="vaapi"
    ["NVIDIA"]="nvdec"
    ["GENERIC"]="auto-safe"
)

# --- [ UI & NOTIFICATION SYSTEM ] ---
banner() {
    clear
    echo -e "\e[1;35m⊰•-•💀Ψ•-•-⦑4NDR0666-Ψ-OS⦒-•-•Ψ💀•-•⊱\e[0m"
    echo -e "\e[1;34m[ SYSTEM ALIGNMENT & COHESION SUITE v3.0 ]\e[0m\n"
}

info()    { echo -e "\e[34m[AUDIT]\e[0m $1"; }
success() { echo -e "\e[32m[DONE]\e[0m $1"; }
warn()    { echo -e "\e[33m[WARN]\e[0m $1"; }
error()   { echo -e "\e[31m[FAIL]\e[0m $1"; exit 1; }

# --- [ CORE LOGIC MODULES ] ---

check_dependencies() {
    local deps=("lspci" "sed" "grep" "bc")
    for tool in "${deps[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error "Required dependency '$tool' is missing. Please install it via pacman."
        fi
    done
}

update_param() {
    local key="$1"
    local val="$2"
    # Idempotent logic: handles commented and active lines
    if grep -q "^#\?${key}=" "$CONF_PATH" 2>/dev/null; then
        sed -i "s|^#\?${key}=.*|${key}=${val}|" "$CONF_PATH"
        info "Aligned: $key -> $val"
    else
        echo "${key}=${val}" >> "$CONF_PATH"
        info "Injected: $key=$val"
    fi
}

audit_hardware() {
    info "Initiating Hardware Recon..."
    GPU_RAW=$(lspci | grep -iE 'vga|3d' | head -n1)
    
    if echo "$GPU_RAW" | grep -iq "Intel"; then VENDOR="INTEL";
    elif echo "$GPU_RAW" | grep -iq "NVIDIA"; then VENDOR="NVIDIA";
    elif echo "$GPU_RAW" | grep -iq "AMD\|ATI"; then VENDOR="AMD";
    else VENDOR="GENERIC"; fi

    # Fetch VA-API codecs with fallback
    if command -v vainfo &> /dev/null; then
        CODEC_LIST=$(vainfo 2>/dev/null | grep VAProfile | awk '{print $1}' | sed 's/VAProfile//g' | xargs | tr ' ' ',')
    fi
    [[ -z "$CODEC_LIST" ]] && CODEC_LIST="auto"
    success "Hardware Profile: $VENDOR | Target: ${GPU_MAP[$VENDOR]}"
}

calibrate_display() {
    info "Auditing Display Swapchain Latency..."
    local hz_raw
    if command -v wlr-randr &> /dev/null; then
        hz_raw=$(wlr-randr | grep -oP '\d+\.\d+ Hz' | sort -rn | head -n1 | cut -d. -f1)
    elif command -v xrandr &> /dev/null; then
        hz_raw=$(xrandr | grep '*' | awk '{print $2}' | cut -d. -f1 | head -n1)
    fi
    MAX_HZ=${hz_raw:-60}
    
    if (( MAX_HZ <= 60 )); then
        SWAP_DEPTH="2"; SYNC_MODE="display-resample"
    else
        SWAP_DEPTH="3"; SYNC_MODE="display-vdrop"
    fi
    success "Display calibrated for ${MAX_HZ}Hz."
}

optimize_shaders() {
    info "Analyzing GPU Compute Unit (CU) headroom..."
    # Ensure spline36 is used if GCN 1.0 (Pitcairn) is detected to prevent CU overload
    if [[ "$GPU_RAW" == *"PITCAIRN"* ]] || grep -q "ArtCNN" "$CONF_PATH" 2>/dev/null; then
        warn "Pitcairn Architecture/High-load shaders found. Balancing for stability."
        sed -i 's|^glsl-shader=.*ArtCNN.*|# & # Disabled for stability|' "$CONF_PATH" 2>/dev/null
        update_param "scale" "spline36"
    fi
}

tune_network_cache() {
    info "Calculating RAM-to-Cache ratio..."
    local total_mem=$(free -m | awk '/^Mem:/{print $2}')
    local target_cache=$(( total_mem / 10 ))
    [[ "$target_cache" -gt 2048 ]] && target_cache=2048
    
    update_param "demuxer-max-bytes" "${target_cache}MiB"
    update_param "demuxer-readahead-secs" "30"
}

align_system() {
    mkdir -p "$(dirname "$CONF_PATH")"
    [[ ! -f "$CONF_PATH" ]] && touch "$CONF_PATH"
    
    echo -ne "\e[1;33m[CONFIRM]\e[0m Apply alignment to $CONF_PATH? (y/N): "
    read -r response
    [[ ! "$response" =~ ^[Yy]$ ]] && error "Alignment aborted."

    cp "$CONF_PATH" "$BACKUP_PATH"
    
    update_param "hwdec" "${GPU_MAP[$VENDOR]}"
    update_param "hwdec-codecs" "$CODEC_LIST"
    update_param "video-sync" "$SYNC_MODE"
    update_param "swapchain-depth" "$SWAP_DEPTH"
    
    if [[ "$GPU_RAW" == *"PITCAIRN"* ]]; then
        update_param "vo" "gpu-next"
        update_param "gpu-api" "vulkan"
    fi
    success "Alignment Complete. Forward progress secured."
}

# --- [ MAIN EXECUTION ] ---
main() {
    case "$1" in
        -s|--sync)
            banner
            check_dependencies
            audit_hardware
            calibrate_display
            optimize_shaders
            tune_network_cache
            align_system
            ;;
        *)
            echo "Usage: $0 --sync"
            ;;
    esac
}

main "$@"
