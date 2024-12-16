# 4ndr0666install.sh - Automated Arch Linux Setup Script

## Overview

`4ndr0666install.sh` is a comprehensive installation and configuration script designed to automate the setup of a personalized Arch Linux environment. It streamlines the installation of essential packages, configuration of the Zsh shell, deployment of dotfiles, and execution of various system management tasks through modular external scripts.

## Features

- **Automated Environment Setup**: Configures essential directories, environment variables, and shell settings.
- **Package Management**: Installs packages from official repositories, AUR, Git repositories, and Python packages based on a structured `progs.csv`.
- **Dotfiles Deployment**: Clones and deploys dotfiles from a specified Git repository.
- **Modular Scripts**: Executes external scripts for GRUB configuration, application hiding, home directory management, system cleanup, backup verification, and system health checks.
- **Centralized Logging**: All operations are logged to centralized log files within `$XDG_DATA_HOME/logs/`.
- **User-Friendly Interface**: Utilizes `whiptail` for interactive dialogs and progress indicators.
- **Security Measures**: Ensures scripts are executed with appropriate permissions and includes safeguards against potential vulnerabilities.

## Prerequisites

- **Arch Linux**: The script is tailored for Arch Linux distributions.
- **Root Privileges**: Must be run as root or with `sudo`.
- **Internet Connection**: Required for package installations and Git operations.

## Dependencies

Ensure the following commands are available before running the script:

- `whiptail`
- `git`
- `pacman`
- `rsync`
- `curl`
- `nvim` (Neovim)
- `bat`
- `meld`

The script will check for these dependencies and prompt errors if any are missing.

## Installation

1. **Clone the Repository**

   ```bash
   git clone https://github.com/4ndr0666/dotfiles.git
   cd dotfiles
   ```

### 1. **Install the Zen Kernel**

The Zen kernel is optimized for desktop performance and responsiveness. You can install it directly from the official repositories.

1. **Install the Zen Kernel:**
   ```bash
   sudo pacman -S linux-zen linux-zen-headers
   ```

2. **Regenerate the initramfs using Dracut:**
   First, ensure Dracut is installed:
   ```bash
   sudo pacman -S dracut
   ```

   Then, regenerate the initramfs:
   ```bash
   sudo dracut --force
   ```

3. **Update the bootloader configuration:**
   If you use GRUB, update the GRUB configuration:
   ```bash
   sudo grub-mkconfig -o /boot/grub/grub.cfg
   ```

4. **Reboot into the Zen kernel:**
   ```bash
   sudo reboot
   ```

### 2. **Kernel Configuration Changes**

Since you cannot directly access the kernel source via a package, you should rely on the prebuilt Zen kernel, which comes with many optimizations. However, to tweak kernel parameters further:

1. **Persistent Kernel Parameter Configuration:**
   You can adjust certain parameters by editing the GRUB configuration:
   ```bash
   sudo nano /etc/default/grub
   ```

   Add or modify the `GRUB_CMDLINE_LINUX_DEFAULT` line to include necessary parameters. For example:
   ```bash
   GRUB_CMDLINE_LINUX_DEFAULT="quiet splash transparent_hugepage=always"
   ```

   Save the file and update GRUB:
   ```bash
   sudo grub-mkconfig -o /boot/grub/grub.cfg
   ```

2. **Modifying Runtime Kernel Parameters:**
   Use `sysctl` to modify kernel parameters dynamically. For example, to reduce swappiness:
   ```bash
   sudo sysctl vm.swappiness=10
   ```

   To make this persistent:
   ```bash
   echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.d/99-sysctl.conf
   ```

### 3. **Install and Configure ZFS (if required)**

1. **Install ZFS for the Zen Kernel:**
   ```bash
   sudo pacman -S zfs-linux-zen zfs-utils
   ```

2. **Load the ZFS kernel module:**
   ```bash
   sudo modprobe zfs
   ```

3. **Enable and start the ZFS service:**
   ```bash
   sudo systemctl enable zfs-import-cache
   sudo systemctl start zfs-import-cache
   sudo systemctl enable zfs-mount
   sudo systemctl start zfs-mount
   ```

### 4. **Performance Tweaks**

1. **Tune CPU Performance:**
   - Install `cpupower` for CPU frequency scaling:
     ```bash
     sudo pacman -S cpupower
     ```
   - Set the performance governor:
     ```bash
     sudo cpupower frequency-set -g performance
     ```
   - To apply this setting on boot:
     ```bash
     sudo systemctl enable cpupower
     ```

2. **Optimize I/O Scheduler:**
   - Set the I/O scheduler to `mq-deadline` for SSDs:
     ```bash
     echo 'mq-deadline' | sudo tee /sys/block/sdX/queue/scheduler
     ```
   - To apply this at boot, create a udev rule:
     ```bash
     echo 'ACTION=="add|change", SUBSYSTEM=="block", KERNEL=="sd[a-z]", ATTR{queue/scheduler}="mq-deadline"' | sudo tee /etc/udev/rules.d/60-io-scheduler.rules
     ```

3. **Enable Huge Pages:**
   - Enable transparent huge pages:
     ```bash
     echo 'always' | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
     ```
   - To apply this on boot:
     ```bash
     sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="/&transparent_hugepage=always /' /etc/default/grub
     sudo grub-mkconfig -o /boot/grub/grub.cfg
     ```

4. **Network Optimizations:**
   - Adjust TCP congestion control:
     ```bash
     echo 'net.ipv4.tcp_congestion_control=bbr' | sudo tee -a /etc/sysctl.d/99-sysctl.conf
     sudo sysctl -p
     ```

### 5. **Security Hardening**

1. **Review and Choose Between SELinux or AppArmor:**
   - If not using SELinux:
     ```bash
     sudo pacman -Rns selinux
     sudo grub-mkconfig -o /boot/grub/grub.cfg
     sudo reboot
     ```

   - If you prefer SELinux over AppArmor:
     ```bash
     sudo pacman -S selinux selinux-policy
     sudo systemctl disable apparmor
     sudo reboot
     ```

2. **Configure Firewall Settings (if not done):**
   - Use `ufw` to configure firewall rules for additional security:
     ```bash
     sudo pacman -S ufw
     sudo systemctl enable ufw
     sudo systemctl start ufw
     sudo ufw default deny incoming
     sudo ufw default allow outgoing
     sudo ufw enable
     ```

### 6. **Final System Update and Cleanup**

1. **Ensure the system is up to date:**
   ```bash
   sudo pacman -Syu
   ```

2. **Remove unnecessary packages:**
   ```bash
   sudo pacman -Rns $(pacman -Qdtq)
   ```
