#!/bin/bash

# --- // AUTO_ESCALATE:
if [ "$(id -u)" -ne 0 ]; then
    echo "This script requires root privileges. Please enter your password to continue."
    exec sudo "$0" "$@"
fi

sleep 1
echo "💀WARNING💀 - you are now operating as root..."
sleep 1
echo

set -euo pipefail  # Fail fast on errors and undefined variables

# Paths and files
BASE_DIR="/usr/local/bin"
FREECACHE_SERVICE="/etc/systemd/system/freecache.service"
MEMORY_MONITOR_SERVICE="/etc/systemd/system/memory_monitor.service"
OOMD_SERVICE="/etc/systemd/system/systemd-oomd.service"
EARLYOOM_SERVICE="/etc/systemd/system/earlyoom.service"
OOMD_CONF="/etc/systemd/oomd.conf"
LOG_DIR="/home/andro/.local/share/logs/"
LOG_FILE="/home/andro/.local/share/logs/freecache.log"

# Initialize EARLYOOM_BIN as empty
EARLYOOM_BIN=""

# Function to check and install dependencies
installDependencies() {
    local packages=("earlyoom" "procps-ng" "preload" "irqbalance" "zswap-utils" "uksd")
    for pkg in "${packages[@]}"; do
        if ! pacman -Qi "$pkg" &> /dev/null; then
            echo "Installing package $pkg..."
            pacman -S --needed --noconfirm "$pkg" || { echo "Error: Failed to install $pkg"; exit 1; }
        else
            echo "Package $pkg is already installed."
        fi
    done
}

# Function to dynamically resolve paths
resolvePaths() {
    EARLYOOM_BIN=$(command -v earlyoom || true)
    if [[ -z "$EARLYOOM_BIN" ]]; then
        echo "earlyoom binary not found in PATH. Attempting to install..."
        installDependencies
        EARLYOOM_BIN=$(command -v earlyoom || true)
        if [[ -z "$EARLYOOM_BIN" ]]; then
            echo "Error: earlyoom binary still not found after installation."
            exit 1
        fi
    fi
    echo "Found earlyoom binary at: $EARLYOOM_BIN"
}

# Function to check command dependencies
checkCommandDependencies() {
    local commands=("systemctl" "mkdir" "chmod" "tee" "sysctl" "free" "awk" "date" "irqbalance" "preload")
    for cmd in "${commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "Error: $cmd is not installed. Please install it to proceed." >&2
            exit 1
        fi
    done
}

# Function to create necessary directories and check permissions
createDirectories() {
    # Create BASE_DIR if it doesn't exist
    if [[ ! -d "$BASE_DIR" ]]; then
        mkdir -p "$BASE_DIR" || { echo "Error: Failed to create directory $BASE_DIR"; exit 1; }
        echo "Created directory: $BASE_DIR"
    elif [[ ! -w "$BASE_DIR" ]]; then
        echo "Error: Directory $BASE_DIR is not writable."
        exit 1
    else
        echo "Directory $BASE_DIR already exists and is writable."
    fi

    # Create LOG_DIR if it doesn't exist
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR" || { echo "Error: Failed to create log directory $LOG_DIR"; exit 1; }
        echo "Created log directory: $LOG_DIR"
    fi
}

# Function to remove conflicting or old service files dynamically
removeConflictingServices() {
    echo "Checking for conflicting services..."
    # Define a list of known conflicting services
    local conflicting_services=("cgroup2ctl.service")

    # Dynamically detect services related to memory management that are not part of the current setup
    local detected_services
    detected_services=$(systemctl list-unit-files --type=service | awk '{print $1}' | grep -E 'oom|earlyoom|memory_monitor|freecache' | grep -vE 'systemd-oomd.service|earlyoom.service|memory_monitor.service|freecache.service')

    for service in "${conflicting_services[@]}"; do
        if systemctl list-unit-files | grep -q "^${service}"; then
            echo "Removing conflicting service: $service"
            systemctl stop "$service" || echo "Warning: Failed to stop $service"
            systemctl disable "$service" || echo "Warning: Failed to disable $service"
            rm -f "/etc/systemd/system/$service" || echo "Warning: Failed to remove $service file"
        fi
    done

    # Additionally, remove any detected conflicting services
    for service in $detected_services; do
        echo "Removing detected conflicting service: $service"
        systemctl stop "$service" || echo "Warning: Failed to stop $service"
        systemctl disable "$service" || echo "Warning: Failed to disable $service"
        rm -f "/etc/systemd/system/$service" || echo "Warning: Failed to remove $service file"
    done
}

# Function to create a backup of existing service files
backupServiceFile() {
    local service_file="$1"
    local backup_dir="/Nas/Backups/$(basename "$service_file")"
    mkdir -p "$(dirname "$backup_dir")" || { echo "Error: Failed to create backup directory for $service_file"; exit 1; }
    if [[ -f "$service_file" ]]; then
        local backup_file="${backup_dir}.bak.$(date +'%Y%m%d%H%M%S')"
        cp "$service_file" "$backup_file" || { echo "Error: Failed to create backup of $service_file"; exit 1; }
        echo "Backup of $service_file created at $backup_file."
    fi
}

# Function to restore service files from backups
restoreServiceFile() {
    local service_file="$1"
    local backup_dir="/Nas/Backups/$(basename "$service_file")"
    local latest_backup
    latest_backup=$(ls -t "${backup_dir}.bak."* 2>/dev/null | head -n1)

    if [[ -n "$latest_backup" && -f "$latest_backup" ]]; then
        cp "$latest_backup" "$service_file" || { echo "Error: Failed to restore $service_file from $latest_backup"; exit 1; }
        echo "Restored $service_file from $latest_backup."
        systemctl daemon-reload
        systemctl restart "$(basename "$service_file")"
    else
        echo "No backup found for $service_file. Cannot restore."
    fi
}

# Function to define and write file contents if they differ from existing ones
defineWriteFiles() {
    local content="$1"
    local path="$2"
    local temp_file="${path}.tmp"

    if [[ -f "$path" ]]; then
        local existing_content
        existing_content=$(<"$path")
        if [[ "$existing_content" == "$content" ]]; then
            echo "File $path is already up to date."
            return
        else
            echo "Updating file $path."
            backupServiceFile "$path"
        fi
    else
        echo "Creating file $path."
    fi

    echo "$content" > "$temp_file"
    mv "$temp_file" "$path"
    echo "File $path has been written successfully."
}

# Function to make scripts executable if not already
makeExecutable() {
    local script="$1"
    if [[ -x "$script" ]]; then
        echo "Script $script is already executable."
    else
        chmod +x "$script"
        echo "Made $script executable."
    fi
}

# Function to reload systemd and enable/start services
reloadEnableStartServices() {
    systemctl daemon-reload
    local services=("memory_monitor.service" "freecache.service" "systemd-oomd.service" "earlyoom.service")
    for service in "${services[@]}"; do
        if systemctl is-enabled --quiet "$service"; then
            echo "Service $service is already enabled."
        else
            systemctl enable "$service" || { echo "Failed to enable $service"; return 1; }
            echo "Service $service has been enabled."
        fi

        if systemctl is-active --quiet "$service"; then
            echo "Service $service is already running."
        else
            systemctl start "$service" || { echo "Failed to start $service"; return 1; }
            echo "Service $service has been started."
        fi
    done
}

# Function to enable a service safely
enableServiceSafely() {
    local service="$1"
    if systemctl is-enabled --quiet "$service"; then
        echo "Service $service is already enabled."
    else
        systemctl enable "$service" || { echo "Failed to enable $service"; return 1; }
        echo "Service $service has been enabled."
    fi
}

# Function to validate systemd service files
validateServiceFile() {
    local file="$1"
    if systemd-analyze verify "$file"; then
        echo "Service file $file is valid."
    else
        echo "Warning: Service file $file has issues. Please review manually."
    fi
}

# Adjust swappiness based on free memory
adjust_swappiness() {
    local target_swappiness=20
    local free_ram_mb
    free_ram_mb=$(free -m | awk '/^Mem:/{print $4}')
    free_ram_mb=${free_ram_mb:-0}  # Default to 0 if undefined
    sysctl -w vm.swappiness="$target_swappiness" || { echo "Error: Failed to set swappiness."; exit 1; }
    log_action "Swappiness adjusted to $target_swappiness. Free memory: ${free_ram_mb}MB"
}

# Clear RAM cache if free memory is low
clear_ram_cache() {
    local free_ram_mb
    free_ram_mb=$(free -m | awk '/^Mem:/{print $4}')
    free_ram_mb=${free_ram_mb:-0}  # Default to 0 if undefined

    if [ "$free_ram_mb" -lt 300 ]; then
        echo 3 > /proc/sys/vm/drop_caches || { echo "Error: Failed to drop caches."; exit 1; }
        log_action "RAM cache cleared due to low free memory (${free_ram_mb}MB)."
    fi
}

# Clear swap if usage exceeds threshold
clear_swap() {
    local swap_total swap_used swap_usage_percent

    swap_total=$(free | awk '/^Swap:/{print $2}')
    swap_used=$(free | awk '/^Swap:/{print $3}')

    if [[ -z "$swap_total" || -z "$swap_used" || "$swap_total" -eq 0 ]]; then
        swap_usage_percent=0  # Set to 0 if swap values can't be determined
    else
        swap_usage_percent=$(awk "BEGIN {printf \"%.0f\", ($swap_used/$swap_total) * 100}")
    fi

    if [ "$swap_usage_percent" -gt 80 ]; then
        swapoff -a && swapon -a || { echo "Error: Failed to clear swap."; exit 1; }
        log_action "Swap cleared due to high swap usage (${swap_usage_percent}%)."
    fi
}

# Kill processes that consume excessive memory
kill_memory_hogs() {
    local mem_threshold=80
    local current_mem_usage
    current_mem_usage=$(free | awk '/^Mem:/{printf("%.0f", $3/$2 * 100)}')

    if [ "$current_mem_usage" -gt "$mem_threshold" ]; then
        log_action "Memory usage over $mem_threshold%. Initiating process termination..."
        # Prioritize terminating Brave and Chromium first
        for process in brave chromium; do
            pkill -f "$process" && log_action "Terminated $process to free up memory."
        done
        # If memory usage still high, terminate other high-memory processes
        ps aux --sort=-%mem | awk 'NR>1{print $2, $4, $11}' | while read -r pid mem cmd; do
            mem_int=$(echo "$mem" | cut -d. -f1)
            if [ "$mem_int" -gt 10 ]; then
                kill "$pid" && log_action "Sent SIGTERM to process $cmd (PID $pid) using $mem% memory."
                sleep 5
                if ps -p "$pid" > /dev/null 2>&1; then
                    kill -9 "$pid" && log_action "Sent SIGKILL to process $cmd (PID $pid) using $mem% memory."
                fi
            fi
        done
    fi
}

# Logging function
log_action() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
}

# Define service and script contents

# Define freecache.service content
FREECACHE_SERVICE_CONTENT=$(cat <<EOF
[Unit]
Description=Free Cache when Memory is Low
After=memory_monitor.service systemd-oomd.service

[Service]
Type=oneshot
ExecStart=$BASE_DIR/freecache.sh

[Install]
WantedBy=multi-user.target
EOF
)

# Define memory_monitor.service content
MEMORY_MONITOR_SERVICE_CONTENT=$(cat <<EOF
[Unit]
Description=Monitor Memory Usage
After=network.target

[Service]
Type=simple
ExecStart=$BASE_DIR/memory_monitor.sh
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
)

# Define systemd-oomd.service content
OOMD_SERVICE_CONTENT=$(cat <<EOF
[Unit]
Description=Out Of Memory Daemon
ConditionControlGroupController=v2
ConditionControlGroupController=memory
ConditionPathExists=/proc/pressure/cpu
ConditionPathExists=/proc/pressure/io
ConditionPathExists=/proc/pressure/memory
Requires=systemd-oomd.socket
After=systemd-oomd.socket

[Service]
AmbientCapabilities=CAP_KILL CAP_DAC_OVERRIDE
BusName=org.freedesktop.oom1
CapabilityBoundingSet=CAP_KILL CAP_DAC_OVERRIDE
ExecStart=/usr/lib/systemd/systemd-oomd
IPAddressDeny=any
LockPersonality=yes
MemoryDenyWriteExecute=yes
MemoryMin=128M
MemoryLow=128M
NoNewPrivileges=yes
OOMScoreAdjust=-900
PrivateDevices=yes
PrivateTmp=yes
ProtectClock=yes
ProtectHome=yes
ProtectHostname=yes
ProtectKernelLogs=yes
ProtectKernelModules=yes
ProtectKernelTunables=yes
ProtectSystem=strict
Restart=on-failure
RestrictAddressFamilies=AF_UNIX
RestrictNamespaces=yes
RestrictRealtime=yes
RestrictSUIDSGID=yes
SystemCallArchitectures=native
SystemCallErrorNumber=EPERM
SystemCallFilter=@system-service
Type=notify
User=systemd-oom
WatchdogSec=3min

[Install]
WantedBy=multi-user.target
Alias=dbus-org.freedesktop.oom1.service
EOF
)

# Define earlyoom.service content
EARLYOOM_SERVICE_CONTENT=$(cat <<EOF
[Unit]
Description=Early OOM Daemon
After=network.target

[Service]
ExecStart=$EARLYOOM_BIN -m 35 -s 35 -r 60 -p -d -n --sort-by-rss --avoid '(^|/)(init|X|wayland|wayfire|sshd|systemd)$'
Restart=always
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF
)

# Define oomd.conf content
OOMD_CONF_CONTENT=$(cat <<EOF
# /etc/systemd/oomd.conf
# oomd Configuration File

[OOM]
SwapUsedLimit=50%
DefaultMemoryPressureLimit=40%
DefaultMemoryPressureDurationSec=5s
EOF
)

# Define freecache.sh script content
FREECACHE_SCRIPT_CONTENT=$(cat <<'EOF'
#!/bin/bash

set -euo pipefail

LOG_FILE="/home/andro/.local/share/logs/freecache.log"

log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

mkdir -p "$(dirname "$LOG_FILE")" || { echo "Failed to create log directory"; exit 1; }
touch "$LOG_FILE" || { echo "Failed to create log file"; exit 1; }

adjust_swappiness() {
    local target_swappiness=20
    local free_ram_mb
    free_ram_mb=$(free -m | awk '/^Mem:/{print $4}')
    free_ram_mb=${free_ram_mb:-0}  # Default to 0 if undefined
    sysctl -w vm.swappiness="$target_swappiness" || { echo "Error: Failed to set swappiness."; exit 1; }
    log_action "Swappiness adjusted to $target_swappiness. Free memory: ${free_ram_mb}MB"
}

clear_ram_cache() {
    local free_ram_mb
    free_ram_mb=$(free -m | awk '/^Mem:/{print $4}')
    free_ram_mb=${free_ram_mb:-0}  # Default to 0 if undefined

    if [ "$free_ram_mb" -lt 300 ]; then
        echo 3 > /proc/sys/vm/drop_caches || { echo "Error: Failed to drop caches."; exit 1; }
        log_action "RAM cache cleared due to low free memory (${free_ram_mb}MB)."
    fi
}

clear_swap() {
    local swap_total swap_used swap_usage_percent

    swap_total=$(free | awk '/^Swap:/{print $2}')
    swap_used=$(free | awk '/^Swap:/{print $3}')

    if [[ -z "$swap_total" || -z "$swap_used" || "$swap_total" -eq 0 ]]; then
        swap_usage_percent=0  # Set to 0 if swap values can't be determined
    else
        swap_usage_percent=$(awk "BEGIN {printf \"%.0f\", ($swap_used/$swap_total) * 100}")
    fi

    if [ "$swap_usage_percent" -gt 80 ]; then
        swapoff -a && swapon -a || { echo "Error: Failed to clear swap."; exit 1; }
        log_action "Swap cleared due to high swap usage (${swap_usage_percent}%)."
    fi
}

kill_memory_hogs() {
    local mem_threshold=80
    local current_mem_usage
    current_mem_usage=$(free | awk '/^Mem:/{printf("%.0f", $3/$2 * 100)}')

    if [ "$current_mem_usage" -gt "$mem_threshold" ]; then
        log_action "Memory usage over $mem_threshold%. Initiating process termination..."
        # Prioritize terminating Brave and Chromium first
        for process in brave chromium; do
            pkill -f "$process" && log_action "Terminated $process to free up memory."
        done
        # If memory usage still high, terminate other high-memory processes
        ps aux --sort=-%mem | awk 'NR>1{print $2, $4, $11}' | while read -r pid mem cmd; do
            mem_int=$(echo "$mem" | cut -d. -f1)
            if [ "$mem_int" -gt 10 ]; then
                kill "$pid" && log_action "Sent SIGTERM to process $cmd (PID $pid) using $mem% memory."
                sleep 5
                if ps -p "$pid" > /dev/null 2>&1; then
                    kill -9 "$pid" && log_action "Sent SIGKILL to process $cmd (PID $pid) using $mem% memory."
                fi
            fi
        done
    fi
}

adjust_swappiness
clear_ram_cache
clear_swap
kill_memory_hogs

log_action "Memory and Swap Usage After Operations:"
free -h | tee -a "$LOG_FILE"
EOF
)

# Define memory_monitor.sh script content
MEMORY_MONITOR_SCRIPT_CONTENT=$(cat <<'EOF'
#!/bin/bash

while true; do
    FREE_RAM=$(free -m | awk '/^Mem:/{print $4}')
    FREE_RAM=${FREE_RAM:-0}  # Default to 0 if undefined
    if [ "$FREE_RAM" -lt 1000 ]; then
        touch /tmp/low_memory
    else
        rm -f /tmp/low_memory
    fi
    sleep 60
done
EOF
)

# Main function to orchestrate the script logic
main() {
    checkCommandDependencies
    resolvePaths
    createDirectories
    removeConflictingServices

    # Backup service files
    backupServiceFile "$EARLYOOM_SERVICE"
    backupServiceFile "$OOMD_SERVICE"
    backupServiceFile "$MEMORY_MONITOR_SERVICE"
    backupServiceFile "$FREECACHE_SERVICE"

    # Define and write service files
    defineWriteFiles "$FREECACHE_SERVICE_CONTENT" "$FREECACHE_SERVICE"
    defineWriteFiles "$MEMORY_MONITOR_SERVICE_CONTENT" "$MEMORY_MONITOR_SERVICE"
    defineWriteFiles "$OOMD_SERVICE_CONTENT" "$OOMD_SERVICE"
    defineWriteFiles "$EARLYOOM_SERVICE_CONTENT" "$EARLYOOM_SERVICE"
    defineWriteFiles "$OOMD_CONF_CONTENT" "$OOMD_CONF"

    # Define and write script files
    defineWriteFiles "$FREECACHE_SCRIPT_CONTENT" "$BASE_DIR/freecache.sh"
    defineWriteFiles "$MEMORY_MONITOR_SCRIPT_CONTENT" "$BASE_DIR/memory_monitor.sh"

    # Make scripts executable
    makeExecutable "$BASE_DIR/freecache.sh"
    makeExecutable "$BASE_DIR/memory_monitor.sh"

    # Validate service files after scripts are in place
    validateServiceFile "$FREECACHE_SERVICE"
    validateServiceFile "$MEMORY_MONITOR_SERVICE"
    validateServiceFile "$OOMD_SERVICE"
    validateServiceFile "$EARLYOOM_SERVICE"

    # Reload systemd and enable/start services
    reloadEnableStartServices

    # Enable earlyoom.service safely
    enableServiceSafely "earlyoom.service"

    # Adjust swappiness immediately after installation
    adjust_swappiness

    echo "Memory Monitor installation and configuration completed successfully."
}

# Execute the main function
main
