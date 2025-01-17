#!/bin/bash

# Enable strict error handling
set -euo pipefail

# --- // AUTO_ESCALATE:
if [ "$(id -u)" -ne 0 ]; then
    echo "This script requires root privileges. Please enter your password to continue."
    exec sudo "$0" "$@"
fi

sleep 1
echo "💀WARNING💀 - you are now operating as root..."
sleep 1
echo

# -----------------------------------------------------------------------------
# PARAMETRIC BACKUP PATH
# By default, /4ndr0/backups/ is used; override via BACKUP_PATH env variable.
# e.g.: BACKUP_PATH="/some/dir/backups" ./memorymonitor_installer.sh
# -----------------------------------------------------------------------------
BACKUP_PATH="${BACKUP_PATH:-/4ndr0/backups}"

# Paths and files
BASE_DIR="/usr/local/bin"
FREECACHE_SERVICE="/etc/systemd/system/freecache.service"
MEMORY_MONITOR_SERVICE="/etc/systemd/system/memory_monitor.service"
OOMD_SERVICE="/etc/systemd/system/systemd-oomd.service"
EARLYOOM_SERVICE="/etc/systemd/system/earlyoom.service"
OOMD_CONF="/etc/systemd/oomd.conf"

# Initialize EARLYOOM_BIN as empty
EARLYOOM_BIN=""

# -----------------------------------------------------------------------------
# Enhanced package list for dependencies (including pkill, ps, systemd-analyze)
# -----------------------------------------------------------------------------
installDependencies() {
    local packages=("earlyoom" "procps-ng" "preload" "irqbalance" "zswap-utils" "uksd" "systemd-oomd")
    echo "Checking and installing any missing packages..."

    for pkg in "${packages[@]}"; do
        if ! pacman -Qi "$pkg" &> /dev/null; then
            echo "Installing package $pkg..."
            pacman -S --needed --noconfirm "$pkg" || {
                echo "Error: Failed to install $pkg"
                exit 1
            }
        else
            echo "Package $pkg is already installed."
        fi
    done
}

# -----------------------------------------------------------------------------
# Function to dynamically resolve paths (e.g., earlyoom)
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# Broaden command checks: includes pkill, ps, systemd-analyze, journalctl
# -----------------------------------------------------------------------------
checkCommandDependencies() {
    local commands=("systemctl" "mkdir" "chmod" "tee" "sysctl" "free" "awk" "date" "irqbalance" "preload" "pkill" "ps" "systemd-analyze" "journalctl" "systemd-cat")
    for cmd in "${commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "Error: $cmd is not installed or not in PATH."
            echo "Please install it to proceed."
            exit 1
        fi
    done
}

# -----------------------------------------------------------------------------
# Validate Backup Path Exists and is Writable
# -----------------------------------------------------------------------------
validateBackupPath() {
    if [[ ! -d "$BACKUP_PATH" ]]; then
        echo "Backup directory $BACKUP_PATH does not exist. Attempting to create it..."
        mkdir -p "$BACKUP_PATH" || {
            echo "Error: Failed to create backup directory at $BACKUP_PATH."
            exit 1
        }
        echo "Backup directory $BACKUP_PATH created successfully."
    fi

    if [[ ! -w "$BACKUP_PATH" ]]; then
        echo "Error: Backup directory $BACKUP_PATH is not writable."
        exit 1
    fi
    echo "Backup directory $BACKUP_PATH is valid and writable."
}

# -----------------------------------------------------------------------------
# Create needed directories (excluding LOG_DIR as we're using journald)
# -----------------------------------------------------------------------------
createDirectories() {
    # Create BASE_DIR if it doesn't exist
    if [[ ! -d "$BASE_DIR" ]]; then
        mkdir -p "$BASE_DIR" || {
            echo "Error: Failed to create directory $BASE_DIR"
            exit 1
        }
        echo "Created directory: $BASE_DIR"
    elif [[ ! -w "$BASE_DIR" ]]; then
        echo "Error: Directory $BASE_DIR is not writable."
        exit 1
    else
        echo "Directory $BASE_DIR already exists and is writable."
    fi
}

# -----------------------------------------------------------------------------
# Remove conflicting or old service files dynamically
# -----------------------------------------------------------------------------
removeConflictingServices() {
    echo "Checking for conflicting services..."
    # Example of known conflicting service
    local conflicting_services=("cgroup2ctl.service" "dbus-org.freedesktop.oom1.service")

    # Dynamically detect services related to memory mgmt that aren't in our set
    local detected_services
    detected_services=$(systemctl list-unit-files --type=service \
      | awk '{print $1}' \
      | grep -E 'oom|earlyoom|memory_monitor|freecache' \
      | grep -vE 'systemd-oomd.service|earlyoom.service|memory_monitor.service|freecache.service' || true)

    echo "Detected conflicting services: $detected_services"

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

# -----------------------------------------------------------------------------
# Backup service files to parametric $BACKUP_PATH
# -----------------------------------------------------------------------------
backupServiceFile() {
    local service_file="$1"
    local backup_dir="$BACKUP_PATH/$(basename "$service_file")"

    mkdir -p "$(dirname "$backup_dir")" || {
        echo "Error: Failed to create backup directory for $service_file"
        exit 1
    }

    if [[ -f "$service_file" ]]; then
        local backup_file
        backup_file="${backup_dir}.bak.$(date +'%Y%m%d%H%M%S')"
        cp "$service_file" "$backup_file" || {
            echo "Error: Failed to create backup of $service_file"
            exit 1
        }
        echo "Backup of $service_file created at $backup_file."
    fi
}

# -----------------------------------------------------------------------------
# Restore service files from the newest backup (unchanged from original)
# -----------------------------------------------------------------------------
restoreServiceFile() {
    local service_file="$1"
    local backup_dir="$BACKUP_PATH/$(basename "$service_file")"
    local latest_backup
    latest_backup=$(find "$(dirname "$backup_dir")" -type f -name "$(basename "$backup_dir").bak.*" -printf '%T@ %p\n' | sort -n -r | head -n1 | cut -d' ' -f2)

    if [[ -n "$latest_backup" && -f "$latest_backup" ]]; then
        cp "$latest_backup" "$service_file" || {
            echo "Error: Failed to restore $service_file from $latest_backup"
            exit 1
        }
        echo "Restored $service_file from $latest_backup."
        systemctl daemon-reload
        systemctl restart "$(basename "$service_file")"
    else
        echo "No backup found for $service_file. Cannot restore."
    fi
}

# -----------------------------------------------------------------------------
# Define and write file contents if they differ from existing ones
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# Make scripts executable if not already
# -----------------------------------------------------------------------------
makeExecutable() {
    local script="$1"
    if [[ -x "$script" ]]; then
        echo "Script $script is already executable."
    else
        chmod +x "$script"
        echo "Made $script executable."
    fi
}

# -----------------------------------------------------------------------------
# Reload systemd and enable/start services
# -----------------------------------------------------------------------------
reloadEnableStartServices() {
    systemctl daemon-reload
    local services=("memory_monitor.service" "freecache.service" "systemd-oomd.service" "earlyoom.service")
    for service in "${services[@]}"; do
        if systemctl is-enabled --quiet "$service"; then
            echo "Service $service is already enabled."
        else
            systemctl enable "$service" || {
                echo "Failed to enable $service"
                return 1
            }
            echo "Service $service has been enabled."
        fi

        if systemctl is-active --quiet "$service"; then
            echo "Service $service is already running."
        else
            systemctl start "$service" || {
                echo "Failed to start $service"
                return 1
            }
            echo "Service $service has been started."
        fi
    done
}

# -----------------------------------------------------------------------------
# Enable a service safely
# -----------------------------------------------------------------------------
enableServiceSafely() {
    local service="$1"
    if systemctl is-enabled --quiet "$service"; then
        echo "Service $service is already enabled."
    else
        systemctl enable "$service" || {
            echo "Failed to enable $service"
            return 1
        }
        echo "Service $service has been enabled."
    fi
}

# -----------------------------------------------------------------------------
# Validate systemd service files
# -----------------------------------------------------------------------------
validateServiceFile() {
    local file="$1"
    if systemd-analyze verify "$file"; then
        echo "Service file $file is valid."
    else
        echo "Warning: Service file $file has issues. Please review manually."
    fi
}

# -----------------------------------------------------------------------------
# Logging function - now utilizes journald via systemd-cat
# -----------------------------------------------------------------------------
log_action() {
    local message="$1"
    echo "$message" | systemd-cat -t freecache
}

# -----------------------------------------------------------------------------
# Adjust swappiness based on free memory
# -----------------------------------------------------------------------------
adjust_swappiness() {
    local target_swappiness=10  # Changed from 20 to 10 as per requirement
    local free_ram_mb
    free_ram_mb=$(free -m | awk '/^Mem:/{print $4}')
    free_ram_mb=${free_ram_mb:-0}  # Default to 0 if undefined
    sysctl -w vm.swappiness="$target_swappiness" || {
        echo "Error: Failed to set swappiness."
        exit 1
    }
    log_action "Swappiness adjusted to $target_swappiness. Free memory: ${free_ram_mb}MB"
}

# -----------------------------------------------------------------------------
# Clear RAM cache if free memory is low
# -----------------------------------------------------------------------------
clear_ram_cache() {
    local free_ram_mb
    free_ram_mb=$(free -m | awk '/^Mem:/{print $4}')
    free_ram_mb=${free_ram_mb:-0}  # Default to 0 if undefined

    if [ "$free_ram_mb" -lt 300 ]; then
        echo 3 > /proc/sys/vm/drop_caches || {
            echo "Error: Failed to drop caches."
            exit 1
        }
        log_action "RAM cache cleared due to low free memory (${free_ram_mb}MB)."
    fi
}

# -----------------------------------------------------------------------------
# Clear swap if usage exceeds threshold
# -----------------------------------------------------------------------------
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
        if ! swapoff -a; then
            echo "Error: Failed to swapoff."
            exit 1
        fi
        if ! swapon -a; then
            echo "Error: Failed to swapon."
            exit 1
        fi
        log_action "Swap cleared due to high swap usage (${swap_usage_percent}%)."
    fi
}

# -----------------------------------------------------------------------------
# Kill processes that consume excessive memory
# -----------------------------------------------------------------------------
kill_memory_hogs() {
    local mem_threshold=80
    local current_mem_usage
    current_mem_usage=$(free | awk '/^Mem:/{printf("%.0f", $3/$2 * 100)}')

    if [ "$current_mem_usage" -gt "$mem_threshold" ]; then
        log_action "Memory usage over $mem_threshold%. Initiating process termination..."
        # Prioritize terminating Brave and Chromium first
        for process in brave chromium; do
            if pkill -f "$process"; then
                log_action "Terminated $process to free up memory."
            fi
        done
        # If memory usage still high, terminate other high-memory processes
        ps aux --sort=-%mem | awk 'NR>1{print $2, $4, $11}' | while read -r pid mem cmd; do
            mem_int=$(echo "$mem" | cut -d. -f1)
            if [ "$mem_int" -gt 10 ]; then
                if kill "$pid"; then
                    log_action "Sent SIGTERM to process $cmd (PID $pid) using $mem% memory."
                    sleep 5
                    if ps -p "$pid" > /dev/null 2>&1; then
                        if kill -9 "$pid"; then
                            log_action "Sent SIGKILL to process $cmd (PID $pid) using $mem% memory."
                        fi
                    fi
                fi
            fi
        done
    fi
}

# -----------------------------------------------------------------------------
# Define service and script contents
# -----------------------------------------------------------------------------

# Define freecache.service content
FREECACHE_SERVICE_CONTENT=$(cat <<'EOF'
[Unit]
Description=Free Cache when Memory is Low
After=memory_monitor.service systemd-oomd.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/freecache.sh

[Install]
WantedBy=multi-user.target
EOF
)

# Define memory_monitor.service content
MEMORY_MONITOR_SERVICE_CONTENT=$(cat <<'EOF'
[Unit]
Description=Monitor Memory Usage
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/memory_monitor.sh
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
)

# Define systemd-oomd.service content
OOMD_SERVICE_CONTENT=$(cat <<'EOF'
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

# Define earlyoom.service content with proper variable expansion
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
OOMD_CONF_CONTENT=$(cat <<'EOF'
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

log_action() {
    local message="$1"
    echo "$message" | systemd-cat -t freecache
}

adjust_swappiness() {
    local target_swappiness=10  # Set to 10 as per requirement
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
        if ! swapoff -a; then
            echo "Error: Failed to swapoff."
            exit 1
        fi
        if ! swapon -a; then
            echo "Error: Failed to swapon."
            exit 1
        fi
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
            if pkill -f "$process"; then
                log_action "Terminated $process to free up memory."
            fi
        done
        # If memory usage still high, terminate other high-memory processes
        ps aux --sort=-%mem | awk 'NR>1{print $2, $4, $11}' | while read -r pid mem cmd; do
            mem_int=$(echo "$mem" | cut -d. -f1)
            if [ "$mem_int" -gt 10 ]; then
                if kill "$pid"; then
                    log_action "Sent SIGTERM to process $cmd (PID $pid) using $mem% memory."
                    sleep 5
                    if ps -p "$pid" > /dev/null 2>&1; then
                        if kill -9 "$pid"; then
                            log_action "Sent SIGKILL to process $cmd (PID $pid) using $mem% memory."
                        fi
                    fi
                fi
            fi
        done
    fi
}
EOF
)

# -----------------------------------------------------------------------------
# Define memory_monitor.sh script content
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# Main function to orchestrate the script logic
# -----------------------------------------------------------------------------
main() {
    checkCommandDependencies
    resolvePaths
    validateBackupPath
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
