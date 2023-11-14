#!/bin/bash
set -e

# Constants
RETRY_COUNT=3
LOG_FILE="/tmp/audiofixer.log"

# Banner Display
echo -e "\033[34m"
cat << "EOF"
#
#     _____            .___.__        _____.__                   .__
#    /  _  \  __ __  __| _/|__| _____/ ____\__|__  ___      _____|  |__
#   /  /_\  \|  |  \/ __ | |  |/  _ \   __\|  \  \/  /     /  ___/  |  \
#  /    |    \  |  / /_/ | |  (  <_> )  |  |  |>    <      \___ \|   Y  \
#  \____|__  /____/\____ | |__|\____/|__|  |__/__/\_ \ /\ /____  >___|  /
#          \/           \/                          \/ \/      \/     \/
EOF
echo -e "\033[0m"

# Error logging function
log_error() {
    echo "[ERROR] $1" | tee -a $LOG_FILE
}

backup_configuration() {
    local config_file=$1
    if [ -f "$config_file" ]; then
        cp "$config_file" "$config_file.bak"
    fi
}

play_test_audio() {
    echo "Playing test audio..."
    paplay /usr/share/sounds/freedesktop/stereo/front-left-right.wav || log_error "Failed to play test audio."
}

install_pavucontrol() {
    echo "Installing pavucontrol..."
    yay -Syu pavucontrol --noconfirm || log_error "Failed to install pavucontrol."
}

choose_functions() {
    local choices=(
        "install_packages" "remove_conflicts" "set_permissions"
        "reset_pulseaudio_config" "configure_mpv_audio" "configure_mplayer_audio"
        "manage_audio_services" "audio_configuration" "troubleshooting_checks"
        "play_test_audio" "install_pavucontrol"
    )

    echo "Choose which functions to run (Enter numbers separated by space):"
    for i in "${!choices[@]}"; do
        echo "$i) ${choices[$i]}"
    done

    read -ra selected
    for i in "${selected[@]}"; do
        ${choices[$i]}
    done
}

# Individual Function Definitions
install_packages() {
    echo "Installing necessary packages..."
    sudo pacman -S --needed pulseaudio pulseaudio-alsa alsa-utils || log_error "Failed to install necessary packages."
}

remove_conflicts() {
    echo "Removing conflicting packages..."
    sudo pacman -Rns pipewire || log_error "Failed to remove conflicting packages."
}

set_permissions() {
    echo "Setting permissions..."
    sudo chmod 755 /etc/pulse /etc/xdg /etc/xdg/Xwayland-session.d /etc/xdg/autostart || log_error "Failed to set permissions."
}

reset_pulseaudio_config() {
    mv ~/.config/pulse/default.pa ~/default.pa.bak || log_error "Failed to reset PulseAudio configuration."
    pulseaudio -vvvvv || log_error "Failed to start PulseAudio."
}

configure_mpv_audio() {
    echo "Configuring MPV audio..."
    sed -i '/^ao=/d' ~/.config/mpv/mpv.conf || echo "ao=pulse" >> ~/.config/mpv/mpv.conf
}

configure_mplayer_audio() {
    echo "Configuring MPlayer audio..."
    sed -i '/^ao=/d' ~/.mplayer/config || echo "ao=pulse" >> ~/.mplayer/config
}

manage_audio_services() {
    echo "Managing audio services..."
    sudo systemctl --user restart pulseaudio || log_error "Failed to restart PulseAudio service."
}

audio_configuration() {
    echo "Setting default audio configuration..."
    pacmd set-card-profile 0 output:analog-stereo
    pacmd set-default-sink 1
}

troubleshooting_checks() {
    echo "Running troubleshooting checks..."
    aplay -l
    arecord -l
    pacmd list-sinks
    pacmd list-sources
}

# Main Script Logic
main() {
    echo "Starting AudioFixer..."

    # Backup existing configurations
    backup_configuration ~/.config/pulse/default.pa
    backup_configuration ~/.config/mpv/mpv.conf
    backup_configuration ~/.mplayer/config

    # Check if user wants to choose specific functions or run all
    read -p "Run all functions or choose specific ones? (all/choose): " choice
    if [ "$choice" == "choose" ]; then
        choose_functions
    else
        for function in install_packages remove_conflicts set_permissions reset_pulse audio_config configure_mpv_audio configure_mplayer_audio manage_audio_services audio_configuration troubleshooting_checks play_test_audio install_pavucontrol; do
            for i in $(seq 1 "$RETRY_COUNT"); do
                if $function; then break; else log_error "Retry $i/$RETRY_COUNT for $function"; fi
            done
        done
    fi

    echo "AudioFixer completed. Check $LOG_FILE for detailed logs."
}

main
