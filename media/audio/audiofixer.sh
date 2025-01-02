#!/bin/bash

# Comprehensive System Maintenance and Troubleshooting Script with UI and Dynamic Configuration
#LOG_FILE="/var/log/system_maintenance.log"
@RETRY_COUNT=3

# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if the script is run as root and escalate if not
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${YELLOW}Running as root is required. Escalating...${NC}"
    sudo "$0" "$@"
    exit $?
fi

# Banner Display
echo -e "${BLUE}"
cat << "EOF"
#
#     _____            .___.__        _____.__                   .__
#    /  _  \  __ __  __| _/|__| _____/ ____\__|__  ___      _____|  |__
#   /  /_\  \|  |  \/ __ | |  |/  _ \   __\|  \  \/  /     /  ___/  |  \
#  /    |    \  |  / /_/ | |  (  <_> )  |  |  |>    <      \___ \|   Y  \
#  \____|__  /____/\____ | |__|\____/|__|  |__/__/\_ \ /\ /____  >___|  /
#          \/           \/                          \/ \/      \/     \/
EOF
echo -e "${NC}"

# Log Actions
LogActions() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"
}

# Error logging function
log_error() {
    echo "[ERROR] $1" | tee -a "$LOG_FILE"
}

# Function to temporarily bypass a potentially aliased command within the script
#TempBypassAlias() {
#    local cmd="$1"
#    unalias "$cmd" 2>/dev/null
#    eval "$cmd() { /usr/bin/$cmd \"\$@\";\ }"
#}

# Function to remove a specific alias, if necessary, by checking user configuration files
#RemoveAlias() {
#    local alias_name="$1"
#    LogActions "Checking for alias: $alias_name"
#    local config_files=(~/.bashrc ~/.bash_aliases ~/.zshrc ~/.profile)
#    for config_file in "${config_files[@]}"; do
#        if grep -q "alias $alias_name=" "$config_file"; then
#            LogActions "Alias found in: $config_file. Consider removing it to prevent conflicts."
#        else
#            LogActions "No alias found in: $config_file"
#        fi
#    done
#}

# Function to check the status of audio services and start them if not running
CheckAudioServices() {
    local services=("$@")
    for service in "${services[@]}"; do
        if systemctl --user is-active --quiet "$service"; then
            echo -e "${GREEN}$service is running${NC}"
        else
            echo -e "${YELLOW}$service is not running. Starting $service...${NC}"
            systemctl --user start "$service"
            if systemctl --user is-active --quiet "$service"; then
                echo -e "${GREEN}$service started successfully.${NC}"
            else
                log_error "Failed to start $service. Please check logs."
            fi
        fi
    done
}

# Function to verify the user session type and ensure the correct environment
VerifyUserSession() {
    local session_type="$1"
    LogActions "Verifying user session: $session_type"
    if [[ "$XDG_SESSION_TYPE" == "$session_type" ]]; then
        echo "Session type is correct: $XDG_SESSION_TYPE"
    else
        echo "Warning: Session type is incorrect. Expected: $session_type, Found: $XDG_SESSION_TYPE"
    fi
}

# Function to install and configure audio-related packages
ConfigureAudioServices() {
    local packages=("$@")
    LogActions "Configuring audio services..."
    for package in "${packages[@]}"; do
        if ! pacman -Q "$package" &>/dev/null; then
            LogActions "Installing $package..."
            sudo pacman -S --needed "$package" || log_error "Failed to install $package."
        else
            LogActions "$package is already installed."
        fi
    done
}

# Function to restart audio services for changes to take effect
RestartAudioServices() {
    local services=("$@")
    LogActions "Restarting audio services..."
    for service in "${services[@]}"; do
        systemctl --user restart "$service"
        if systemctl --user is-active --quiet "$service"; then
            LogActions "$service restarted successfully."
        else
            log_error "Failed to restart $service. Please check system logs for more details."
        fi
    done
}

# Function to test audio output using ALSA tools
TestAudioOutput() {
    local test_sound="$1"
    LogActions "Testing audio output with: $test_sound"
    if aplay "$test_sound"; then
        LogActions "Audio test completed successfully."
    else
        log_error "Failed to play test audio."
    fi
}

# Function to backup configuration files
BackupConfigFiles() {
    local config_files=("$@")
    LogActions "Backing up configuration files..."
    for config_file in "${config_files[@]}"; do
        if [ -f "$config_file" ]; then
            cp "$config_file" "$config_file.bak"
            LogActions "Backed up $config_file"
        else
            LogActions "No configuration file found at $config_file"
        fi
    done
}

# Function to restore configuration files from backup
RestoreConfigFiles() {
    local config_files=("$@")
    LogActions "Restoring configuration files from backup..."
    for config_file in "${config_files[@]}"; do
        if [ -f "$config_file.bak" ]; then
            mv "$config_file.bak" "$config_file"
            LogActions "Restored $config_file from backup"
        else
            LogActions "No backup found for $config_file"
        fi
    done
}

# Function to check for updates and prompt user to update
CheckForUpdates() {
    LogActions "Checking for available package updates..."
    if pacman -Sy; then
        local updates=$(pacman -Qu)
        if [ -n "$updates" ]; then
            echo -e "${YELLOW}Updates are available:${NC}"
            echo "$updates"
            if (whiptail --title "Updates Available" --yesno "Updates are available. Would you like to update now?" 10 60); then
                sudo pacman -Syu || log_error "Failed to update packages."
            fi
        else
            LogActions "No updates available."
        fi
    else
        log_error "Failed to refresh package database."
    fi
}

# Function to reboot the system with user confirmation
RebootSystem() {
    if (whiptail --title "Reboot System" --yesno "A system reboot is recommended. Would you like to reboot now?" 10 60); then
        LogActions "Rebooting system..."
        reboot
    else
        LogActions "Reboot postponed by user."
    fi
}

# Function to prompt user interactively and retrieve input
InteractivePrompt() {
    local prompt_message="$1"
    local user_input
    user_input=$(whiptail --inputbox "$prompt_message" 10 60 3>&1 1>&2 2>&3)
    echo "$user_input"
}

# Function to handle errors gracefully and log messages
HandleErrorsGracefully() {
    local error_message="$1"
    log_error "$error_message"
    whiptail --title "Error" --msgbox "$error_message" 10 60
}

# Function to verify kernel modules are loaded and load them if necessary
VerifyKernelModules() {
    local modules=("$@")
    LogActions "Verifying kernel modules..."
    for module in "${modules[@]}"; do
        if ! lsmod | grep -q "$module"; then
            modprobe "$module"
            if ! lsmod | grep -q "$module"; then
                log_error "Failed to load kernel module: $module"
            else
                LogActions "Loaded kernel module: $module"
            fi
        else
            LogActions "Kernel module already loaded: $module"
        fi
    done
}

# Function to install missing dependencies required for the script
InstallMissingDependencies() {
    local dependencies=("$@")
    LogActions "Checking for missing dependencies..."
    for dependency in "${dependencies[@]}"; do
        if ! pacman -Q "$dependency" &>/dev/null; then
            LogActions "Installing missing dependency: $dependency"
            sudo pacman -S --needed "$dependency" || log_error "Failed to install dependency: $dependency"
        else
            LogActions "Dependency already installed: $dependency"
        fi
    done
}

# Function to monitor system resources
MonitorSystemResources() {
    LogActions "Monitoring system resources..."
    local cpu_usage
    local ram_usage
    local disk_usage

    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}') # CPU Usage in percent
    ram_usage=$(free -m | awk '/Mem:/ {print $3}')                # RAM Usage in MB
    disk_usage=$(df -h / | awk '/\// {print $5}')                 # Disk Usage in percent

    LogActions "CPU Usage: $cpu_usage%"
    LogActions "RAM Usage: $ram_usage MB"
    LogActions "Disk Usage: $disk_usage"

    whiptail --title "System Resources" --msgbox "CPU Usage: $cpu_usage%\nRAM Usage: $ram_usage MB\nDisk Usage: $disk_usage" 12 50
}

# Function to perform dynamic configuration based on system requirements
DynamicConfiguration() {
    LogActions "Detecting system hardware and requirements..."
    local packages=()

    # Detect Bluetooth
    if lsusb | grep -qi 'Bluetooth'; then
        LogActions "Bluetooth hardware detected."
        packages+=("bluez" "bluez-utils")
    fi

    # Detect Intel GPU
    if lspci | grep -qi 'Intel.*Graphics'; then
        LogActions "Intel GPU detected."
        packages+=("xf86-video-intel" "intel-media-driver")
    fi

    # Detect Virtualization
    if lscpu | grep -qi 'Hypervisor'; then
        LogActions "Virtualization detected."
        packages+=("qemu" "libvirt" "virt-manager")
    fi

    # Detect mismatched kernel version and mitigate
    local running_kernel
    running_kernel=$(uname -r)
    local installed_kernel
    installed_kernel=$(pacman -Q linux | awk '{print $2}')
    if [[ "$running_kernel" != "$installed_kernel" ]]; then
        log_error "Kernel version mismatch detected. Running: $running_kernel, Installed: $installed_kernel"
        LogActions "Reinstalling kernel..."
        sudo pacman -S linux || log_error "Failed to reinstall the kernel."
    fi

    # Detect snd_hda_intel
    if lspci | grep -qi 'Audio device.*Intel'; then
        LogActions "snd_hda_intel audio device detected."
        VerifyKernelModules "snd_hda_intel"
    fi

    # Detect Audio System (PipeWire or PulseAudio)
    if systemctl --user is-active --quiet pipewire; then
        LogActions "PipeWire detected as the active audio system."
        packages+=("pipewire" "pipewire-audio" "pipewire-v412" "pipewire-x11-bell" "pipewire-zeroconf" "gst-plugin-pipewire" "qemu-audio-pipewire" "lib32-libpipewire" "libpipewire" "pipewire-pulse" "pipewire-alsa" "pipewire-jack" "wireplumber" "pipewire-autostart pulseaudio-support")
        # Ensure PulseAudio is not running
        if systemctl --user is-active --quiet pulseaudio; then
            LogActions "Stopping PulseAudio to avoid conflicts with PipeWire."
            systemctl --user stop pulseaudio
            systemctl --user disable pulseaudio
        fi
        # Restart PipeWire services
        CheckAudioServices "pipewire" "wireplumber"
    else
        LogActions "PulseAudio detected as the active audio system."
        packages+=("pulseaudio" "pulseaudio-alsa" "pavucontrol")
        # Ensure PipeWire is not running
        if systemctl --user is-active --quiet pipewire; then
            LogActions "Stopping PipeWire to avoid conflicts with PulseAudio."
            systemctl --user stop pipewire
            systemctl --user disable pipewire
        fi
        # Restart PulseAudio services
        CheckAudioServices "pulseaudio"
    fi

    ConfigureAudioServices "${packages[@]}"
}

# Function to install the Zvuchno volume bar theme
InstallZvuchnoTheme() {
    LogActions "Installing Zvuchno volume bar theme..."
    local zvuchno_repo="https://github.com/thekondor/zvuchno"
    local install_dir="$HOME/.config/zvuchno"

    # Clone the repository if it doesn't exist
    if [ ! -d "$install_dir" ]; then
        git clone "$zvuchno_repo" "$install_dir" || log_error "Failed to clone Zvuchno repository."
    else
        LogActions "Zvuchno repository already cloned."
    fi

    # Install dependencies
    InstallMissingDependencies "dunst" "playerctl"

    # Follow installation instructions from the repository
    (
        cd "$install_dir" || exit
        ./install.sh || log_error "Failed to install Zvuchno theme."
    )

    LogActions "Zvuchno theme installed. To use, follow the instructions in $install_dir."
    whiptail --title "Zvuchno Theme" --msgbox "Zvuchno theme installed successfully.\nFollow the instructions in $install_dir to configure and use it." 12 50
}

# Function to choose specific functions to run
choose_functions() {
    local options=("TempBypassAlias" "RemoveAlias" "CheckAudioServices" "VerifyUserSession"
                   "ConfigureAudioServices" "RestartAudioServices" "TestAudioOutput"
                   "BackupConfigFiles" "RestoreConfigFiles" "CheckForUpdates" "RebootSystem"
                   "InteractivePrompt" "HandleErrorsGracefully" "VerifyKernelModules"
                   "InstallMissingDependencies" "MonitorSystemResources" "DynamicConfiguration"
                   "InstallZvuchnoTheme")

    local choices
    choices=$(whiptail --title "Choose Functions" --checklist "Select functions to run:" 20 80 10 \
        "${options[0]}" "" ON \
        "${options[1]}" "" OFF \
        "${options[2]}" "" OFF \
        "${options[3]}" "" OFF \
        "${options[4]}" "" OFF \
        "${options[5]}" "" OFF \
        "${options[6]}" "" OFF \
        "${options[7]}" "" OFF \
        "${options[8]}" "" OFF \
        "${options[9]}" "" OFF \
        "${options[10]}" "" OFF \
        "${options[11]}" "" OFF \
        "${options[12]}" "" OFF \
        "${options[13]}" "" OFF \
        "${options[14]}" "" OFF \
        "${options[15]}" "" OFF \
        "${options[16]}" "" OFF \
        "${options[17]}" "" OFF 3>&1 1>&2 2>&3)

    for choice in $choices; do
        choice=$(echo "$choice" | tr -d '"')
        for i in $(seq 1 "$RETRY_COUNT"); do
            if $choice; then break; else log_error "Retry $i/$RETRY_COUNT for $choice"; fi
        done
    done
}

# Main Script Logic
main() {
    LogActions "Starting System Maintenance Script..."

    # Install any missing dependencies
    InstallMissingDependencies "whiptail" "alsa-utils"

    # Backup existing configurations
    BackupConfigFiles ~/.config/pulse/default.pa ~/.config/mpv/mpv.conf ~/.mplayer/config

    # User interaction
    if (whiptail --title "Execution Mode" --yesno "Execute all actions at once?" 10 60); then
        # Execute all functions in sequence
        for function in TempBypassAlias RemoveAlias CheckAudioServices VerifyUserSession ConfigureAudioServices RestartAudioServices TestAudioOutput BackupConfigFiles RestoreConfigFiles CheckForUpdates RebootSystem InteractivePrompt HandleErrorsGracefully VerifyKernelModules InstallMissingDependencies MonitorSystemResources DynamicConfiguration InstallZvuchnoTheme; do
            for i in $(seq 1 "$RETRY_COUNT"); do
                if $function; then break; else log_error "Retry $i/$RETRY_COUNT for $function"; fi
            done
        done
    else
        # Select specific functions to run
        choose_functions
    fi

    # If the script reaches this point, exit successfully
    LogActions "System Maintenance Script completed. Check $LOG_FILE for detailed logs."
    exit 0
}

main
