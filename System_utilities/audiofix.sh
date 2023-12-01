#!/bin/bash
set -e


# --- // AUTO_ESCALATE:
if [ "$(id -u)" -ne 0 ]; then
      sudo "$0" "$@"
    exit $?
fi


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

Play_Test_Audio() {
    echo "Playing test audio..."
    paplay /usr/share/sounds/freedesktop/stereo/front-left-right.wav || log_error "Failed to play test audio."
}

Install_Pavucontrol() {
    echo "Installing pavucontrol..."
    yay -Syu pavucontrol --noconfirm || log_error "Failed to install pavucontrol."
}

choose_functions() {
    local choices=(
        "Install_Pulseaudio" "Remove_Pipewire" "Check_Permissions"
        "Force_Reset_Pulseaudio" "Configure_MPV_Pulseaudio" "Configure_Mplayer_Pulseaudio"
        "Restart_System_Service" "Set_Default_Sink_and_Card" "Troubleshooting_Checks"
        "Play_Test_Audio" "Install_Pavucontrol" "Exit"
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
Install_Pulseaudio() {
    echo "Installing necessary packages..."
    pacman -S --needed pulseaudio pulseaudio-alsa alsa-utils || log_error "Failed to install necessary packages."
}

Remove_Pipewire() {
    echo "Removing conflicting packages..."
    pacman -Rns pipewire || log_error "Failed to remove conflicting packages."
}

Check_Permissions() {
    echo "Setting permissions..."
    chmod 755 /etc/pulse /etc/xdg /etc/xdg/Xwayland-session.d /etc/xdg/autostart || log_error "Failed to set permissions."
}

Force_Reset_Pulseaudio() {
    mv ~/.config/pulse/default.pa ~/default.pa.bak || log_error "Failed to reset PulseAudio configuration."
    pulseaudio -vvvvv || log_error "Failed to start PulseAudio."
}

Configure_MPV_Pulseaudio() {
    echo "Configuring MPV audio..."
    sed -i '/^ao=/d' ~/.config/mpv/mpv.conf || echo "ao=pulse" >> ~/.config/mpv/mpv.conf
}

Configure_Mplayer_Audio() {
    echo "Configuring MPlayer audio..."
    sed -i '/^ao=/d' ~/.mplayer/config || echo "ao=pulse" >> ~/.mplayer/config
}

Restart_System_Service() {
    echo "Managing audio services..."
    systemctl --user restart pulseaudio || log_error "Failed to restart PulseAudio service."
}

Set_Default_Sink_and_Card() {
    echo "Setting default audio configuration..."
    pacmd set-card-profile 0 output:analog-stereo
    pacmd set-default-sink 1
}

Troubleshooting_Checks() {
    echo "Running troubleshooting checks..."
    aplay -l
    arecord -l
    pacmd list-sinks
    pacmd list-sources
}

Exit() {
    local exit_code=$1
    echo "Exiting AudioFixer with status code $exit_code"
    echo "Check $LOG_FILE for detailed logs."
    exit $exit_code
}


# Main Script Logic
main() {
    echo "Starting AudioFixer..."

    # Backup existing configurations
    backup_configuration ~/.config/pulse/default.pa
    backup_configuration ~/.config/mpv/mpv.conf
    backup_configuration ~/.mplayer/config

    # Check if user wants to choose specific functions or run all
    read -p " Execute all actions at once or select individually? (all/select): " choice
    if [ "$choice" == "select" ]; then
        choose_functions
    else
        for function in Install_Pulseaudio Remove_Pipewire Check_Permissions Force_Reset_Pulseaudio Configure_MPV_Audio Configure_Mplayer_Audio Restart_System_Service Set_Default_Sink_and_Card Troubleshooting_Checks Play_Test_Audio Install_Pavucontrol Exit; do
            for i in $(seq 1 "$RETRY_COUNT"); do
                if $function; then break; else log_error "Retry $i/$RETRY_COUNT for $function"; fi
            done
        done
    fi
    
    # If the script reaches this point, exit successfully
    exit_script 0
    
    echo "AudioFixer completed. Check $LOG_FILE for detailed logs."
}

main
