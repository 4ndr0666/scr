#!/usr/bin/env python3
"""
4NDR0666OS - Sudo Lazarus
Version: 2.1.0
Description: Resurrects broken sudo binaries by correcting permissions/ownership.
Critical Feature: Uses Fallback Escalation (pkexec/su) if sudo is dead.
"""

import os
import sys
import subprocess
import shutil

# --- CONFIG ---
TARGETS = [
    {"path": "/usr/bin/sudo", "mode": 0o4755, "uid": 0, "gid": 0},
    {"path": "/usr/lib/sudo/sudoers.so", "mode": 0o644, "uid": 0, "gid": 0},
    {"path": "/etc/sudoers", "mode": 0o440, "uid": 0, "gid": 0},
    {"path": "/var/lib/sudo", "mode": 0o711, "uid": 0, "gid": 0}
]

COLORS = {
    "RED": "\033[91m",
    "GREEN": "\033[92m",
    "YELLOW": "\033[93m",
    "RESET": "\033[0m"
}

def log(msg, color="GREEN"):
    print(f"{COLORS.get(color, '')}[*] {msg}{COLORS['RESET']}")

def is_root():
    return os.geteuid() == 0

def escalate():
    """
    The Critical Fallback Chain.
    If sudo is broken, we cannot use sudo to fix it.
    """
    # 1. Try Polkit (pkexec) - often survives fs permission errors
    if shutil.which("pkexec"):
        log("Attempting escalation via PolicyKit (pkexec)...", "YELLOW")
        try:
            subprocess.check_call(["pkexec", sys.executable] + sys.argv)
            sys.exit(0)
        except subprocess.CalledProcessError:
            log("pkexec failed.", "RED")
    
    # 2. Try SU (Direct Root Login)
    if shutil.which("su"):
        log("Attempting escalation via SU (requires root password)...", "YELLOW")
        try:
            # Pass command as a string to su -c
            cmd = f"{sys.executable} {' '.join(sys.argv)}"
            subprocess.check_call(["su", "-c", cmd])
            sys.exit(0)
        except subprocess.CalledProcessError:
            log("su failed.", "RED")

    log("FATAL: All escalation vectors failed. Reboot to single-user mode required.", "RED")
    sys.exit(1)

def repair_target(target):
    path = target["path"]
    if not os.path.exists(path):
        # Some paths might differ by distro, log but don't crash
        log(f"Target not found, skipping: {path}", "YELLOW")
        return

    try:
        # Check current state
        stat = os.stat(path)
        current_mode = stat.st_mode & 0o7777
        
        if current_mode == target["mode"] and stat.st_uid == target["uid"] and stat.st_gid == target["gid"]:
            log(f"Verified: {path}")
            return

        log(f"Repairing: {path}...", "YELLOW")
        
        # 1. Ownership
        os.chown(path, target["uid"], target["gid"])
        
        # 2. Permissions (Setuid bit is critical for sudo binary)
        os.chmod(path, target["mode"])
        
        log(f"Fixed: {path}", "GREEN")

    except PermissionError:
        log(f"Permission Denied on {path}. Root check bypassed?", "RED")
    except Exception as e:
        log(f"Error on {path}: {e}", "RED")

def main():
    if not is_root():
        log("Not running as root. Sudo is likely broken.", "RED")
        escalate()
        return

    log("Initiating Sudo Resurrection Protocol...", "GREEN")
    
    for target in TARGETS:
        repair_target(target)
    
    log("Protocol Complete. Verify with: sudo -v", "GREEN")

if __name__ == "__main__":
    main()
