#!/bin/bash
# shellcheck disable=all

# Update system
sudo pacman -Syu --noconfirm

# Update Intel microcode
sudo pacman -S intel-ucode --noconfirm

# Regenerate GRUB config
sudo grub-mkconfig -o /boot/grub/grub.cfg

# Disable SMT (Optional)
# echo 0 > /sys/devices/system/cpu/smt/control

# Add kernel parameters for additional mitigations
echo 'mitigations=auto' >> /etc/default/grub
sudo grub-mkconfig -o /boot/grub/grub.cfg

# Reboot the system for changes to take effect
sudo reboot
