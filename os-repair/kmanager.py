#!/usr/bin/env python3

import subprocess
import sys
import os

def run_command(command):
    """Run a shell command and return its output."""
    result = subprocess.run(command, shell=True, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error running command: {command}\n{result.stderr}")
        sys.exit(1)
    return result.stdout.strip()

def check_pacman_lock():
    """Check if the pacman database lock file exists and remove it if necessary."""
    db_lock_path = "/var/lib/pacman/db.lck"
    if os.path.exists(db_lock_path):
        print('Warning: removing pacman db.lck!')
        os.remove(db_lock_path)

def list_kernels():
    """List installed kernels."""
    kernels = run_command("pacman -Qqe | grep -E '^linux[0-9]{0,1}(-lts|-zen|-hardened)?$'")
    if kernels:
        print("Installed Kernels:")
        print(kernels)
    else:
        print("No installed kernels found.")

def list_available_kernels():
    """List available kernels."""
    kernels = run_command("pacman -Ssq linux | grep -E '^linux[0-9]{0,1}(-lts|-zen|-hardened)?$'")
    if kernels:
        print("Available Kernels:")
        print(kernels)
    else:
        print("No available kernels found.")

def install_kernel(kernel_name):
    """Install a specified kernel."""
    print(f"Installing kernel: {kernel_name}")
    check_pacman_lock()
    run_command(f"sudo pacman -Syu {kernel_name}")
    rebuild_initramfs(kernel_name)
    update_grub()

def remove_kernel(kernel_name):
    """Remove a specified kernel."""
    print(f"Removing kernel: {kernel_name}")
    check_pacman_lock()
    run_command(f"sudo pacman -Rns {kernel_name}")
    update_grub()

def rebuild_initramfs(kernel_name=None):
    """Rebuild initramfs for the specified kernel."""
    kernel_version = run_command("uname -r")
    modules_dir = f"/lib/modules/{kernel_version}"
    if os.path.isdir(modules_dir):
        print(f"Rebuilding initramfs for kernel version: {kernel_version}")
        result = subprocess.run("sudo mkinitcpio -P", shell=True, capture_output=True, text=True)
        if result.returncode != 0:
            print(f"Error running mkinitcpio: {result.stderr}")
            if '6.6.10-arch1-1' in result.stderr:
                print("Detected reference to incorrect kernel version. Reinstalling the correct kernel.")
                reinstall_kernel()
                rebuild_initramfs()
            else:
                print("Failed to rebuild initramfs. Please check the mkinitcpio configuration.")
    else:
        print(f"Error: Kernel modules directory '{modules_dir}' does not exist.")

def reinstall_kernel():
    """Reinstall the correct kernel and headers."""
    print("Reinstalling the correct kernel and headers.")
    check_pacman_lock()
    run_command("sudo pacman -S --noconfirm linux linux-headers")

def update_grub():
    """Update GRUB configuration."""
    print("Updating GRUB configuration")
    run_command("sudo grub-mkconfig -o /boot/grub/grub.cfg")

def main():
    if len(sys.argv) < 2:
        print("Usage: kernel_manager.py <list|list-available|install|remove|rebuild|update> [kernel_name]")
        sys.exit(1)

    command = sys.argv[1]

    if command == "list":
        list_kernels()
    elif command == "list-available":
        list_available_kernels()
    elif command == "install":
        if len(sys.argv) != 3:
            print("Usage: kernel_manager.py install <kernel_name>")
            sys.exit(1)
        install_kernel(sys.argv[2])
    elif command == "remove":
        if len(sys.argv) != 3:
            print("Usage: kernel_manager.py remove <kernel_name>")
            sys.exit(1)
        remove_kernel(sys.argv[2])
    elif command == "rebuild":
        rebuild_initramfs()
    elif command == "update":
        update_grub()
    else:
        print("Unknown command")
        sys.exit(1)

if __name__ == "__main__":
    main()

