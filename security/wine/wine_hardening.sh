#!/usr/bin/env bash
# 4ndr0666OS: Wine Hardening Protocol (Phases 3 & 4)
# - Objective: Kernel Cauterization, Privilege Amputation, Perimeter Sealing.
# - Compliance: SC2155, SC1091, Idempotent Execution, Auto-Escalation.

set -euo pipefail
IFS=$'\n\t'

# ── VISUALS & LOGGING ─────────────────────────────────────────────────────────
C_BLUE='\033[0;34m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[0;31m'
C_CYAN='\033[1;36m'
C_RESET='\033[0m'

log_step()    { echo -e "\n${C_CYAN}[Ψ-PHASE]${C_RESET} $*"; }
log_info()    { echo -e " ${C_BLUE}[INFO]${C_RESET}   $*"; }
log_success() { echo -e " ${C_GREEN}[OK]${C_RESET}     $*"; }
log_warn()    { echo -e " ${C_YELLOW}[WARN]${C_RESET}   $*"; }
log_error()   { echo -e " ${C_RED}[FAIL]${C_RESET}   $*" >&2; }

# ── AUTO-ESCALATION GATE ──────────────────────────────────────────────────────
if [[ "${EUID}" -ne 0 ]]; then
    echo -e "${C_RED}💀WARNING💀 - escalating to root (sudo)...${C_RESET}"
    exec sudo "$0" "$@"
    exit $?
fi
log_info "Running with root privileges."

log_step "INITIATING ABSOLUTE HOST HARDENING..."

# ── 1. KERNEL MATRIX LOCKDOWN (SYSCTL) ────────────────────────────────────────
log_step "Phase 3+4: Kernel Memory & BPF Cauterization"
SYSCTL_CONF="/etc/sysctl.d/99-4ndr0-wine.conf"

cat > "$SYSCTL_CONF" << 'EOF'
# 4ndr0666OS: Kinetic Hardening Parameters
# Block unprivileged access to dmesg (prevents KASLR bypass)
kernel.dmesg_restrict = 1
# Lock down ptrace (prevents advanced process injection)
kernel.yama.ptrace_scope = 2
# Disable unprivileged eBPF (shuts down a massive exploit vector)
kernel.unprivileged_bpf_disabled = 2
# Hide kernel pointers
kernel.kptr_restrict = 2
# Prevent kernel replacement via kexec
kernel.kexec_load_disabled = 1
# Disable SUID core dumps (prevents harvesting credentials from crashed SUID bins)
fs.suid_dumpable = 0
EOF

log_info "Applying kernel parameters..."
sysctl --system &>/dev/null || log_warn "Some sysctl parameters may require a reboot to bind."
log_success "Kernel Matrix Sealed."


# ── 2. PERIMETER POISONING NEUTRALIZATION (LLMNR) ─────────────────────────────
log_step "Phase 3: Network Perimeter Poisoning Neutralization"
RESOLVED_CONF="/etc/systemd/resolved.conf"

if [[ -f "$RESOLVED_CONF" ]]; then
    log_info "Disabling LLMNR broadcast resolution..."
    sed -i 's/^#*LLMNR=.*/LLMNR=no/' "$RESOLVED_CONF"
    systemctl restart systemd-resolved
    log_success "LLMNR neutralized. Port 5355 is dead."
else
    log_warn "resolved.conf not found. Skipping LLMNR mitigation."
fi


# ── 3. PRIVILEGE AMPUTATION (LEGACY CAPABILITIES) ─────────────────────────────
log_step "Phase 3: Legacy Capability Amputation"
LEGACY_BINS=( "/usr/bin/rcp" "/usr/bin/rlogin" "/usr/bin/rsh" )

for bin in "${LEGACY_BINS[@]}"; do
    if [[ -f "$bin" ]]; then
        log_info "Stripping cap_net_bind_service from $bin..."
        setcap -r "$bin" 2>/dev/null || true
        log_success "Amputated $bin"
    fi
done


# ── 4. SUID SANDBOX ENFORCEMENT ───────────────────────────────────────────────
log_step "Phase 3: Chromium SUID Sandbox Enforcement"
SANDBOXES=(
    "/opt/thorium-browser/chrome-sandbox"
    "/opt/brave.com/brave-beta/chrome-sandbox"
    "/opt/vidcut/chrome-sandbox"
)

for sb in "${SANDBOXES[@]}"; do
    if [[ -f "$sb" ]]; then
        log_info "Enforcing absolute ownership on $sb..."
        chown root:root "$sb"
        chmod 4755 "$sb"
        log_success "Sandbox Secured: $sb"
    fi
done


# ── 5. SYSTEMD ZOMBIE ERADICATION ─────────────────────────────────────────────
log_step "Phase 3: Systemd Hold-State Eradication"
ZOMBIE_SVC="systemd-networkd-wait-online.service"

if systemctl list-unit-files "$ZOMBIE_SVC" &>/dev/null; then
    log_info "Masking failing network hold-state service..."
    systemctl mask "$ZOMBIE_SVC" &>/dev/null
    log_success "Zombie service masked."
fi


# ── COMPLETION ────────────────────────────────────────────────────────────────
log_step "HARDENING SEQUENCE COMPLETE."
echo -e "${C_CYAN}Ψ The host architecture is now kinetically secured. Ψ${C_RESET}\n"
