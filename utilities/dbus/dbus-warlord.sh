#!/usr/bin/env bash
# 4NDR0-DBUS-WARLORD v1.1
# Author: Ψ-4ndr0666
# Purpose: Total D-Bus hegemony. Split-Brain Auto-Correction.
# Usage: dbus-warlord [check|clean|benchmark|monitor|env-sync]

set -euo pipefail
IFS=$'\n\t'

# Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${CYAN}[*]${NC} $1"; }
log_success() { echo -e "${GREEN}[+]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_crit() { echo -e "${RED}[-]${NC} $1"; }

require_user() {
    if [[ $EUID -eq 0 ]]; then
        log_crit "Run as USER, not ROOT. Root has no session."
        exit 1
    fi
}

# --- 4NDR0: THE SOVEREIGNTY CHECK ---
# Forces the script to use the Systemd bus if available, ignoring polluted env vars.
ensure_sovereign_bus() {
    local SOVEREIGN_SOCKET="unix:path=/run/user/${UID}/bus"
    
    # If the standard socket exists, we trust it over the environment.
    if [[ -S "/run/user/${UID}/bus" ]]; then
        if [[ "${DBUS_SESSION_BUS_ADDRESS:-}" != "${SOVEREIGN_SOCKET}" ]]; then
            log_warn "Split-Brain detected. Env says: '${DBUS_SESSION_BUS_ADDRESS:-(unset)}'."
            log_warn "Systemd says: '${SOVEREIGN_SOCKET}'."
            log_info "Forcing usage of the Systemd Sovereign Bus..."
            export DBUS_SESSION_BUS_ADDRESS="${SOVEREIGN_SOCKET}"
        fi
    fi
}

module_check() {
    log_info "Verifying Session Bus..."
    ensure_sovereign_bus

    # Verify implementation
    if systemctl --user is-active dbus-broker.service >/dev/null 2>&1; then
        log_success "Bus Implementation: dbus-broker (High Performance)"
    elif systemctl --user is-active dbus.service >/dev/null 2>&1; then
        log_info "Bus Implementation: dbus-daemon (Legacy)"
    else
        log_warn "Unknown bus provider or systemd-managed dbus failed."
    fi

    # Ping Test
    if dbus-send --session --dest=org.freedesktop.DBus \
        --type=method_call --print-reply \
        /org/freedesktop/DBus org.freedesktop.DBus.Peer.Ping >/dev/null 2>&1; then
        log_success "Bus Connectivity: ESTABLISHED (Sovereign)."
    else
        log_crit "Bus is unresponsive to PING (Connectivity LOST)."
        exit 1
    fi
}

module_clean() {
    log_info "Initiating purge..."
    # Warning: Root logic removed to force user-space compliance.
    
    # Check for Ghost Sockets
    if [[ -d "/run/user/${UID}/dbus-1" ]]; then
        log_warn "Detected legacy dbus-1 garbage directory."
    fi

    if [[ -S "${XDG_RUNTIME_DIR}/bus" ]]; then
         if ! fuser "${XDG_RUNTIME_DIR}/bus" >/dev/null 2>&1; then
             log_warn "Primary socket ${XDG_RUNTIME_DIR}/bus appears dead (no listeners)."
             rm -f "${XDG_RUNTIME_DIR}/bus" 2>/dev/null || log_warn "Could not purge (permission denied?)."
             log_success "Socket purged."
         else
             log_success "Primary session bus is active (listeners found)."
         fi
    else
        log_warn "No socket at ${XDG_RUNTIME_DIR}/bus."
    fi
}

module_benchmark() {
    ensure_sovereign_bus
    log_info "Benchmarking Bus Latency..."
    
    if ! command -v dbus-test-tool >/dev/null; then
        log_crit "dbus-test-tool (dbus-tests package) not found."
        exit 1
    fi

    log_info "Running 'echo' throughput test (1000 messages)..."
    dbus-test-tool echo --session --count=1000 --name=org.4ndr0.Benchmark
}

module_monitor() {
    ensure_sovereign_bus
    log_info "Entering Monitor Mode. Press Ctrl+C to stop."
    log_info "Filtering for error signals and critical failures..."
    dbus-monitor --session "type='error'" "type='signal',interface='org.freedesktop.DBus.Local'"
}

module_env_sync() {
    ensure_sovereign_bus
    log_info "Forcing Environment Synchronization (Sovereign Mode)..."
    
    local vars=("WAYLAND_DISPLAY" "DISPLAY" "XDG_CURRENT_DESKTOP" "XDG_RUNTIME_DIR" "DBUS_SESSION_BUS_ADDRESS")
    
    # 1. Sync to systemd user session (Private Socket)
    log_info "Pushing environment to systemd --user..."
    systemctl --user import-environment "${vars[@]}"
    
    # 2. Sync to D-Bus activation environment (Session Bus)
    if command -v dbus-update-activation-environment >/dev/null; then
        log_info "Pushing environment to D-Bus Activation..."
        # This will now succeed because we are on the Sovereign Bus
        if dbus-update-activation-environment --systemd --all; then
             log_success "D-Bus Activation Sync: SUCCESS."
        else
             log_crit "D-Bus Activation Sync: FAILED (Check systemd-user logs)."
             exit 1
        fi
    fi
    
    log_success "Environment propagated to all subsystems."
}

usage() {
    echo "Usage: $0 {check|clean|benchmark|monitor|env-sync}"
    exit 1
}

if [[ $# -eq 0 ]]; then usage; fi

case "$1" in
    check) require_user; module_check ;;
    clean) require_user; module_clean ;;
    benchmark) require_user; module_benchmark ;;
    monitor) require_user; module_monitor ;;
    env-sync) require_user; module_env_sync ;;
    *) usage ;;
esac
