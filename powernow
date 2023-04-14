#!/usr/bin/env bash

# powerdown - print energy usage

if [[ $EUID != 0 ]]; then
  echo "[powerdown] must be run as root"
  exit 1
fi

# module loaded
loaded() {
  lsmod | cut -f 1 -d " " | grep -q "^$1$"
}

display_opt () {
  [[ -r $1 ]] && echo " - $1: $(cat $1)"
}

display_module() {
  modinfo $1 &>/dev/null || return
  echo " - $1 $(loaded $1 && echo loaded || echo not loaded)"
}

display_power() {
  for bat in /sys/class/power_supply/BAT*; do
    if [[ -f $bat/power_now ]]; then
      watt=$(perl -e "print sprintf('%.3f', $(cat $bat/power_now) / 1000000)")
    else	
      watt=$(perl -e "print sprintf('%.3f', $(cat $bat/current_now) * $(cat $bat/voltage_now) / 1000000)")
    fi
    echo "[powerdown] $bat using $watt watts"
  done
}

display_readahead() {
  echo " - $1 readahead: $(blockdev --getra $1)"
}

display_wireless() {
  echo " - $1: $(iw dev $1 get power_save)"
}

display_power
echo " Detail:"

# aspm
display_opt /sys/module/pcie_aspm/parameters/policy

# cpu
for i in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do display_opt $i; done

# kernel write mode
for opt in laptop_mode dirty_ratio dirty_background_ratio dirty_expire_centisecs dirty_writeback_centisecs; do
  display_opt "/proc/sys/vm/$opt"
done

# Disk powersave
for dev in /dev/sd[a-z]; do display_readahead $dev; done
for i in /sys/class/scsi_host/host*/link_power_management_policy; do display_opt $i; done

# Sound card powersave
display_opt /sys/module/snd_hda_intel/parameters/power_save
display_opt /sys/module/snd_hda_intel/parameters/power_save_controller

# wifi powersave
display_wireless wlo1

# Screen powersave
for i in /sys/class/backlight/acpi_video*/brightness; do display_opt $i; done

# webcam
display_module uvcvideo

# bluetooth
display_module btusb
display_module bluetooth

# radeon power profile
if [[ -f /sys/class/drm/card0/device/power_method ]] && [[ $(cat /sys/class/drm/card0/device/power_method) == "profile" ]]; then
  display_opt /sys/class/drm/card0/device/power_profile
fi

# nmi_watchdog
display_opt /proc/sys/kernel/nmi_watchdog
