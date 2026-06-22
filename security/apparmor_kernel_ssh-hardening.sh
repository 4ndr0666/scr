#!/usr/bin/env bash
# 4ndr0666OS: AppArmor, Kernel & SSH Hardening Protocol
# - Location: /home/git/clone/4ndr0666/scr/security/apparmor_kernel_ssh-hardening.sh
# - Objective: MAC Enforcement, IPv6/ICMP Black Hole, SSH Cryptographic Lock.
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
log_info "Running with absolute root privileges."

log_step "INITIATING APPARMOR, KERNEL & SSH LOCKDOWN..."

# ── 1. DEPENDENCY GATE: APPARMOR ──────────────────────────────────────────────
log_step "Security Phase: AppArmor Utility Verification"
if ! command -v aa-status &>/dev/null; then
    log_info "AppArmor utilities not found. Installing..."
    pacman -S --noconfirm --needed apparmor
    log_success "AppArmor userspace tools deployed."
else
    log_success "AppArmor userspace tools present."
fi


# ── 2. GRUB INJECTION: WAKING THE PANOPTICON ──────────────────────────────────
log_step "Security Phase: Kernel Bootloader Injection (MAC Enforcement)"
GRUB_FILE="/etc/default/grub"

if [[ -f "$GRUB_FILE" ]]; then
    if ! grep -q "apparmor=1" "$GRUB_FILE"; then
        log_info "Injecting AppArmor parameters into GRUB_CMDLINE_LINUX_DEFAULT..."
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="apparmor=1 security=apparmor /' "$GRUB_FILE"
        
        log_info "Rebuilding GRUB configuration..."
        grub-mkconfig -o /boot/grub/grub.cfg &>/dev/null
        log_success "Bootloader weaponized. AppArmor will enforce on next reboot."
    else
        log_success "AppArmor already injected into bootloader."
    fi
    
    systemctl enable apparmor.service &>/dev/null || true
else
    log_error "GRUB configuration not found at $GRUB_FILE. Manual bootloader injection required."
fi


# ── 3. NETWORK CLOAKING: THE BLACK HOLE ───────────────────────────────────────
log_step "Security Phase: ICMP/IPv6 Vaporization (Kernel Stealth)"
STEALTH_CONF="/etc/sysctl.d/99-4ndr0-stealth.conf"

cat > "$STEALTH_CONF" << 'EOF'
# 4ndr0666OS: Absolute Network Cloaking
# Drop all ICMP echo requests (Ping of Death/Discovery prevention)
net.ipv4.icmp_echo_ignore_all = 1
# Disable IPv6 globally (SLAAC MAC leakage prevention)
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

log_info "Applying stealth network parameters..."
sysctl --system &>/dev/null || log_warn "Some sysctl parameters may require a reboot to bind."
log_success "The host is now a black hole. ICMP and IPv6 are dead."


# ── 4. INGRESS LOCKDOWN: SSHD ─────────────────────────────────────────────────
log_step "Security Phase: SSH Cryptographic Forcing"
SSHD_CONF="/etc/ssh/sshd_config"

if [[ -f "$SSHD_CONF" ]]; then
    log_info "Purging password authentication and root login..."
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONF"
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONF"
    
    log_success "SSH Ingress locked. Only cryptographic keys will be honored."
    
    if systemctl is-active sshd &>/dev/null; then
        systemctl reload sshd
    fi
else
    log_warn "SSH Server not installed. Ingress is natively sealed."
fi

# ── COMPLETION ────────────────────────────────────────────────────────────────
log_step "HARDENING PROTOCOL COMPLETE."
echo -e "${C_CYAN}Ψ The host architecture is secured. Reboot required to bind AppArmor to the kernel. Ψ${C_RESET}\n"
