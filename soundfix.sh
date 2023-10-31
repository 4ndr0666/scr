#!/bin/bash

# Ensure script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script requires root privileges. Please run with sudo."
  exit 1
fi

# Function to install necessary packages
install_packages() {
  echo "Installing necessary packages..."
  pacman -S --needed pulseaudio pulseaudio-alsa alsa-utils
}

# Function to address permission discrepancies
fix_permissions() {
  echo "Fixing permissions..."
  chmod 755 /etc/pulse /etc/xdg /etc/xdg/Xwayland-session.d /etc/xdg/autostart
}

# Function to check audio hardware
check_audio_hardware() {
  echo "Checking audio hardware..."
  aplay -l
  arecord -l
}

# Function to check and add user to audio group if necessary
check_audio_group() {
  echo "Checking audio group membership..."
  if ! id -nG "$USER" | grep -qw "audio"; then
    usermod -aG audio $USER
    echo "User added to audio group. A reboot is required for changes to take effect."
  else
    echo "User is already part of the audio group."
  fi
}

# Function to check and fix ALSA mixer settings
check_alsa_mixer() {
  echo "Checking ALSA mixer settings..."
  amixer scontrols | while read control; do
    amixer set "$control" unmute cap
  done
}

# Function to reload ALSA and PulseAudio
reload_audio_services() {
  echo "Reloading ALSA and PulseAudio..."
  alsa force-reload
  pulseaudio -k && pulseaudio --start
}

# Function to test audio
test_audio() {
  echo "Testing audio..."
  speaker-test -c 2 -l 1
  read -p "Did you hear the sound? (y/n): " sound_works
  if [ "$sound_works" == "y" ]; then
    echo "Sound is working. Exiting..."
    exit 0
  fi
}

# Function to gather system audio information
gather_audio_info() {
  echo "Gathering system audio information..."
  alsa-info.sh --upload
  echo "Audio information uploaded. Please review the generated alsa-info.txt for potential issues."
}

# Main Execution Flow
install_packages
fix_permissions
check_audio_hardware
check_audio_group
check_alsa_mixer
reload_audio_services
test_audio
gather_audio_info

# Reminder for additional manual steps
echo "Reminder for additional manual steps:"
echo "1. Reboot your system to apply any changes: sudo reboot"
echo "2. After rebooting, run 'speaker-test -c 2' to test the sound."
echo "3. Visit Arch Wiki or relevant community forums for further assistance if needed."
