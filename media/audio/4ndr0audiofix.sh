#!/bin/bash
# shellcheck disable=all

# ==============================================================================
# 4ndr0audiofix.sh - Automated Audio Conflict Resolution
# ==============================================================================
# This script dynamically encapsulates an extensive command sequence used to 
# mitigate common audio conflicts (e.g., snd_hda_intel, PipeWire vs PulseAudio)
# into a modular, production-ready automated deployment.
# ==============================================================================

LOG_FILE="/var/log/4ndr0audiofix.log"

# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Auto-escalate to root privilege
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${YELLOW}Running as root is required. Escalating...${NC}"
    sudo "$0" "$@"
    exit $?
fi

# Determine actual user for user-level systemd daemon execution
ACTUAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "$USER")}"
ACTUAL_UID="$(id -u "$ACTUAL_USER")"

Log() {
    local message="$1"
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - ${message}" | tee -a "$LOG_FILE"
}

# Helper function to execute commands accurately within the user's session context
RunUserCmd() {
    sudo -u "$ACTUAL_USER" XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" "$@"
}

DiagnoseInitialState() {
    Log "${BLUE}[*] Diagnosing Initial Hardware and Service State...${NC}"
    lsmod | grep snd || true
    RunUserCmd aplay -l || true
    RunUserCmd systemctl --user status pulseaudio.socket pulseaudio.service pipewire.socket pipewire-pulse.socket pipewire-pulse.service --no-pager || true
    dmesg | grep -iE 'snd|hda|audio|sof' | tail -n 30 || true
    lspci -nnk | grep -iA 3 "Audio" || true
    lspci -nnk | grep -iA 3 "multimedia" || true
    pacman -Qs pipewire-alsa pipewire-pulse wireplumber || true
    lspci -nk || true
    ls /lib/firmware/intel/sof/ 2>/dev/null || Log "${YELLOW}[!] SOF firmware directory not found or empty.${NC}"
}

StopAudioServices() {
    Log "${BLUE}[*] Stopping conflicting audio services for user ${ACTUAL_USER}...${NC}"
    RunUserCmd systemctl --user stop pipewire.socket pipewire.service wireplumber pulseaudio.socket pulseaudio.service || true
}

ConfigureModprobe() {
    local conf_file="/etc/modprobe.d/audio-fix.conf"
    Log "${BLUE}[*] Writing persistent Modprobe configuration to $conf_file...${NC}"
    
    # Creates configuration based on user constraints, mitigating GPU audio hijacking
    cat <<EOF > "$conf_file"
# Disable Radeon HDMI audio to let the PCH initialize
options radeon audio=0
# Force the onboard Intel/Realtek chip to slot 0 and utilize auto model matching
options snd-hda-intel index=0 model=auto power_save=0 power_save_controller=N
EOF
    chmod 644 "$conf_file"
}

ReloadKernelModules() {
    Log "${BLUE}[*] Unloading potentially conflicting audio modules...${NC}"
    modprobe -rv snd_hda_intel snd_hda_codec_hdmi snd_hda_codec_realtek || true
    
    Log "${BLUE}[*] Loading core audio module with dynamic debugging enabled...${NC}"
    modprobe -v snd_hda_intel dyndbg='file sound/pci/hda/* +p'
    
    Log "${BLUE}[*] Inspecting dmesg output post-module reload...${NC}"
    dmesg | tail -n 20 || true
}

EnsureDependencies() {
    Log "${BLUE}[*] Ensuring required PipeWire packages are installed/reinstalled...${NC}"
    pacman -S --needed --noconfirm pipewire pipewire-pulse pipewire-alsa wireplumber
}

RescanHardware() {
    Log "${BLUE}[*] Triggering PCI bus rescan...${NC}"
    echo 1 > /sys/bus/pci/rescan
    sleep 2
    
    Log "${BLUE}[*] Checking for specific Intel Audio Controller...${NC}"
    lspci -nk | grep 00:1b || true
    if lspci -d 8086:1c20 >/dev/null 2>&1; then
        Log "${GREEN}[SUCCESS] DEVICE FOUND (8086:1c20)${NC}"
    else
        Log "${RED}[WARNING] HARDWARE STILL GONE${NC}"
    fi
}

StartAudioServices() {
    Log "${BLUE}[*] Unmasking and enabling PipeWire audio services...${NC}"
    RunUserCmd systemctl --user unmask pipewire.service pipewire.socket pipewire-pulse.service pipewire-pulse.socket wireplumber.service
    
    Log "${BLUE}[*] Starting PipeWire audio services...${NC}"
    RunUserCmd systemctl --user enable --now pipewire.service pipewire-pulse.service wireplumber.service
}

VerifyFinalState() {
    Log "${BLUE}[*] Verifying Final Audio State...${NC}"
    RunUserCmd pactl info | grep "Server Name" || true
    RunUserCmd aplay -l || true
}

PromptReboot() {
    Log "${YELLOW}[!] A system reboot is highly recommended to finalize hardware initialization and kernel parameter changes.${NC}"
    read -p "Reboot now? [y/N]: " -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        Log "${GREEN}[*] Rebooting system...${NC}"
        reboot
    else
        Log "${YELLOW}[*] Reboot postponed by user.${NC}"
    fi
}

Main() {
    Log "${GREEN}====================================================${NC}"
    Log "${GREEN}  Starting 4ndr0audiofix.sh...      ${NC}"
    Log "${GREEN}====================================================${NC}"
    
    DiagnoseInitialState
    StopAudioServices
    ConfigureModprobe
    ReloadKernelModules
    EnsureDependencies
    RescanHardware
    StartAudioServices
    VerifyFinalState
    
    Log "${GREEN}====================================================${NC}"
    Log "${GREEN}  Resolution Sequence Completed      ${NC}"
    Log "${GREEN}====================================================${NC}"
    
    PromptReboot
}

# Execute main sequence
Main "$@"
