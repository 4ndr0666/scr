#!/bin/bash
###############################################################################
# memorymonitor_installer.sh (Revised for leftover freecache cleanup)
#
# 1) Checks and removes leftover freecache references
# 2) Installs and configures systemd-oomd, earlyoom, memory_monitor, freecache
# 3) Integrates interactive whitelisting for CPU/memory hog kills (fzf)
# 4) Adds optional zramsetup.sh to handle compressed swap in RAM
# 5) Removes all old backup references and overwrites files unconditionally
# 6) Ensures leftover "freecache.service" references are automatically removed
#
# NOT DECLARED PRODUCTION-READY. Provided for your review.
#
# LINES: 434
# FUNCTIONS: 19
###############################################################################

set -euo pipefail

###############################################################################
# [1] Root check & logging
###############################################################################
if [ "$(id -u)" -ne 0 ]; then
    echo "This script requires root privileges. Please enter your password to continue."
    exec sudo "$0" "$@"
fi

echo "WARNING: Running as root, continuing setup in 2 seconds..."
sleep 2

###############################################################################
# [2] Configurable paths & directories
###############################################################################
BASE_DIR="/usr/local/bin"

FREECACHE_SERVICE="/etc/systemd/system/freecache.service"
MEMORY_MONITOR_SERVICE="/etc/systemd/system/memory_monitor.service"
OOMD_SERVICE="/etc/systemd/system/systemd-oomd.service"
EARLYOOM_SERVICE="/etc/systemd/system/earlyoom.service"
OOMD_CONF="/etc/systemd/oomd.conf"

ZRAM_SETUP_SCRIPT="${BASE_DIR}/zramsetup.sh"

# We'll remove references to backups in code; everything overwrites unconditionally.
EARLYOOM_BIN=""

###############################################################################
# [3] Install Dependencies
###############################################################################
installDependencies() {
    local packages=("earlyoom" "procps-ng" "preload" "irqbalance" "zramswap" \
                    "uksmd" "systemd-oomd-defaults" "fzf")
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

###############################################################################
# [4] Resolve earlyoom path
###############################################################################
resolvePaths() {
    EARLYOOM_BIN=$(command -v earlyoom || true)
    if [[ -z "$EARLYOOM_BIN" ]]; then
        echo "earlyoom binary not found. Attempting to install..."
        installDependencies
        EARLYOOM_BIN=$(command -v earlyoom || true)
        if [[ -z "$EARLYOOM_BIN" ]]; then
            echo "Error: earlyoom binary still not found after installation."
            exit 1
        fi
    fi
    echo "Found earlyoom binary at: $EARLYOOM_BIN"
}

###############################################################################
# [5] Check for essential commands
###############################################################################
checkCommandDependencies() {
    local commands=("systemctl" "mkdir" "chmod" "tee" "sysctl" "free" "awk" "date" \
                    "irqbalance" "preload" "pkill" "ps" "systemd-analyze" \
                    "journalctl" "systemd-cat" "fzf" "zramctl")
    for cmd in "${commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "Error: $cmd is not installed or not in PATH."
            echo "Please install it to proceed."
            exit 1
        fi
    done
}

###############################################################################
# [6] Create directories if missing
###############################################################################
createDirectories() {
    if [[ ! -d "$BASE_DIR" ]]; then
        mkdir -p "$BASE_DIR" || {
            echo "Error: Failed to create $BASE_DIR"
            exit 1
        }
        echo "Created directory: $BASE_DIR"
    else
        echo "Directory $BASE_DIR already exists."
    fi
}

###############################################################################
# [7] Remove old or conflicting freecache references
###############################################################################
removeOldFreecacheUnits() {
    echo "Checking for leftover freecache services/units..."
    # We'll look for any systemd unit referencing 'freecache' that is NOT
    # the official "/etc/systemd/system/freecache.service"
    local leftover_services
    leftover_services=$(systemctl list-unit-files | grep -i freecache | awk '{print $1}' \
      | grep -v '^freecache.service$' || true)

    # Additionally, check multi-user symlinks or other directories:
    local leftover_symlinks
    leftover_symlinks=$(find /etc/systemd/system/ -type l -lname '*freecache.service' 2>/dev/null \
      | grep -v '/etc/systemd/system/freecache.service' || true)

    if [[ -z "$leftover_services" && -z "$leftover_symlinks" ]]; then
        echo "No leftover freecache services detected."
        return
    fi

    echo "Detected leftover freecache references:"
    echo "$leftover_services"
    echo "$leftover_symlinks"

    # For each leftover service, stop and disable it
    for svc in $leftover_services; do
        echo "Removing leftover freecache unit: $svc"
        systemctl stop "$svc" 2>/dev/null || true
        systemctl disable "$svc" 2>/dev/null || true
        rm -f "/etc/systemd/system/$svc" 2>/dev/null || true
    done

    # For leftover symlinks
    for link in $leftover_symlinks; do
        echo "Removing leftover symlink: $link"
        rm -f "$link" 2>/dev/null || true
    done

    # Reload systemd to forget these old references
    systemctl daemon-reload
}

###############################################################################
# [8] Remove other conflicting services
###############################################################################
removeConflictingServices() {
    echo "Checking for general conflicting services..."
    local conflicting_services=("cgroup2ctl.service" "dbus-org.freedesktop.oom1.service")

    local detected_services
    detected_services=$(systemctl list-unit-files --type=service \
      | awk '{print $1}' \
      | grep -E 'oom|earlyoom|memory_monitor|freecache' \
      | grep -vE 'systemd-oomd.service|earlyoom.service|memory_monitor.service|freecache.service' || true)

    for svc in "${conflicting_services[@]}"; do
        if systemctl list-unit-files | grep -q "^${svc}"; then
            echo "Removing conflicting service: $svc"
            systemctl stop "$svc" 2>/dev/null || true
            systemctl disable "$svc" 2>/dev/null || true
            rm -f "/etc/systemd/system/$svc" 2>/dev/null || true
        fi
    done

    for svc in $detected_services; do
        echo "Removing detected conflicting service: $svc"
        systemctl stop "$svc" 2>/dev/null || true
        systemctl disable "$svc" 2>/dev/null || true
        rm -f "/etc/systemd/system/$svc" 2>/dev/null || true
    done

    # We'll handle leftover freecache specifically in removeOldFreecacheUnits()
}

###############################################################################
# [9] Overwrite files unconditionally (no backup)
###############################################################################
writeFile() {
    local content="$1"
    local path="$2"

    echo "Overwriting file at $path..."
    mkdir -p "$(dirname "$path")"
    echo "$content" > "$path"
    echo "File $path written successfully."
}

###############################################################################
# [10] Make scripts executable
###############################################################################
makeExecutable() {
    local script="$1"
    chmod +x "$script"
    echo "Made $script executable."
}

###############################################################################
# [11] Reload systemd & enable/start services
###############################################################################
reloadEnableStartServices() {
    systemctl daemon-reload

    local services=("memory_monitor.service" "freecache.service" \
                    "systemd-oomd.service" "earlyoom.service")

    for svc in "${services[@]}"; do
        systemctl enable "$svc" || true
        systemctl start "$svc"  || true
    done
}

###############################################################################
# [12] Interactive Whitelist Setup
###############################################################################
configureWhitelist() {
    echo "Gathering list of currently running processes..."
    local proc_list
    proc_list=$(ps aux | awk '$1!="root" && NR>1 {print $11}' | sort -u)

    echo "Select processes you want to WHITELIST (fzf multi-select)."
    echo "Press ENTER when done. If none selected, defaults will be used."
    sleep 2

    local default_whitelist=("wayfire" "Xwayland" "pulseaudio")

    local user_selections
    user_selections=$(echo "${proc_list}" | fzf --multi || true)

    declare -a combined_whitelist
    combined_whitelist=("${default_whitelist[@]}")

    if [[ -n "$user_selections" ]]; then
        echo "You selected additional processes to whitelist:"
        echo "$user_selections"
        while read -r line; do
            combined_whitelist+=("$line")
        done <<< "$user_selections"
    else
        echo "No additional whitelists selected. Using defaults only."
    fi

    export FINAL_WHITELIST="${combined_whitelist[*]}"
    echo "Final whitelist: ${FINAL_WHITELIST}"
}

###############################################################################
# [13] Define service contents
###############################################################################
FREECACHE_SERVICE_CONTENT=$(cat <<'EOF'
[Unit]
Description=Free Cache and Kill Hog Processes
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/freecache.sh

[Install]
WantedBy=multi-user.target
EOF
)

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

EARLYOOM_SERVICE_CONTENT="" # Constructed dynamically next

OOMD_CONF_CONTENT=$(cat <<'EOF'
# /etc/systemd/oomd.conf
[OOM]
SwapUsedLimit=30%
DefaultMemoryPressureLimit=30%
DefaultMemoryPressureDurationSec=5s
EOF
)

###############################################################################
# [14] buildEarlyOOMContent (slightly more aggressive)
###############################################################################
buildEarlyOOMContent() {
    cat <<EOF
[Unit]
Description=Early OOM Daemon
After=network.target

[Service]
ExecStart=$EARLYOOM_BIN -m 40 -s 40 -r 60 -p -d -n --sort-by-rss \
  --avoid '(^|/)(init|X|wayland|wayfire|sshd|systemd)$'
Restart=always
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF
}

###############################################################################
# [15] memory_monitor.sh
###############################################################################
MEMORY_MONITOR_SCRIPT_CONTENT=$(cat <<'EOF'
#!/bin/bash

while true; do
    FREE_RAM=$(free -m | awk '/^Mem:/{print $4}')
    FREE_RAM=${FREE_RAM:-0}
    if [ "$FREE_RAM" -lt 1000 ]; then
        touch /tmp/low_memory
    else
        rm -f /tmp/low_memory
    fi
    sleep 60
done
EOF
)

###############################################################################
# [16] freecache.sh (references $FINAL_WHITELIST)
###############################################################################
FREECACHE_SCRIPT_CONTENT=""
buildFreeCacheScript() {
    cat <<'EOS'
#!/bin/bash

set -euo pipefail

log_action() {
    local msg="$1"
    echo "$msg" | systemd-cat -t freecache
}

adjust_swappiness() {
    local target_swappiness=10
    sysctl -w vm.swappiness="$target_swappiness" || {
        echo "Error: Failed to set swappiness."
        exit 1
    }
    local free_ram_mb
    free_ram_mb=$(free -m | awk '/^Mem:/{print $4}')
    free_ram_mb=${free_ram_mb:-0}
    log_action "Swappiness set to $target_swappiness; free RAM is ${free_ram_mb}MB."
}

clear_ram_cache() {
    local free_ram_mb
    free_ram_mb=$(free -m | awk '/^Mem:/{print $4}')
    free_ram_mb=${free_ram_mb:-0}
    if [ "$free_ram_mb" -lt 300 ]; then
        echo 3 > /proc/sys/vm/drop_caches
        log_action "RAM cache cleared due to low memory (${free_ram_mb}MB)."
    fi
}

clear_swap() {
    local swap_total swap_used usage_pct
    swap_total=$(free | awk '/^Swap:/{print $2}')
    swap_used=$(free | awk '/^Swap:/{print $3}')
    if [[ -z "$swap_total" || -z "$swap_used" || "$swap_total" -eq 0 ]]; then
        usage_pct=0
    else
        usage_pct=$(awk "BEGIN {printf \"%.0f\", ($swap_used/$swap_total)*100}")
    fi
    if [ "$usage_pct" -gt 80 ]; then
        swapoff -a || true
        swapon -a  || true
        log_action "Swap cleared; usage was ${usage_pct}%."
    fi
}

kill_resource_hogs() {
    local WLIST=($FINAL_WHITELIST)
    local mem_threshold=80
    local cpu_threshold=80

    local cur_mem_usage
    cur_mem_usage=$(free | awk '/^Mem:/{printf("%.0f", $3/$2 * 100)}')
    if [ "$cur_mem_usage" -gt "$mem_threshold" ]; then
        log_action "MEM usage ~${cur_mem_usage}%. Checking memory hogs..."
        ps aux --sort=-%mem | awk 'NR>1 {print $2, $4, $11}' | while read -r pid mem cmd; do
            local mem_int=${mem%.*}
            for white_item in "${WLIST[@]}"; do
                if [[ "$cmd" =~ $white_item ]]; then
                    mem_int=0
                    break
                fi
            done
            if [ "$mem_int" -gt 10 ]; then
                if kill "$pid" 2>/dev/null; then
                    log_action "SIGTERM to $cmd (PID=$pid), reason=MEM ${mem}%"
                    sleep 5
                    if ps -p "$pid" &>/dev/null; then
                        kill -9 "$pid" 2>/dev/null || true
                        log_action "SIGKILL to $cmd (PID=$pid), ignoring SIGTERM."
                    fi
                fi
            fi
        done
    fi

    # Approx total CPU usage
    local total_cpu
    total_cpu=$(ps -A -o %cpu | awk '{s+=$1} END {printf "%.0f", s}')
    if [ "$total_cpu" -gt "$cpu_threshold" ]; then
        log_action "CPU usage ~${total_cpu}%. Checking CPU hogs..."
        ps aux --sort=-%cpu | awk 'NR>1 {print $2, $3, $11}' | while read -r pid cpu cmd; do
            local cpu_int=${cpu%.*}
            for white_item in "${WLIST[@]}"; do
                if [[ "$cmd" =~ $white_item ]]; then
                    cpu_int=0
                    break
                fi
            done
            if [ "$cpu_int" -gt 10 ]; then
                if kill "$pid" 2>/dev/null; then
                    log_action "SIGTERM to $cmd (PID=$pid), reason=CPU ${cpu}%"
                    sleep 5
                    if ps -p "$pid" &>/dev/null; then
                        kill -9 "$pid" 2>/dev/null || true
                        log_action "SIGKILL to $cmd (PID=$pid), ignoring SIGTERM."
                    fi
                fi
            fi
        done
    fi
}

main() {
    adjust_swappiness
    clear_ram_cache
    clear_swap
    kill_resource_hogs
}

main
EOS
}

###############################################################################
# [17] zramsetup.sh
###############################################################################
ZRAM_SETUP_SCRIPT_CONTENT=$(cat <<'EOF'
#!/bin/bash
set -euo pipefail

log_and_print() {
    local msg="$1"
    echo "[INFO] $msg"
    echo "$msg" | systemd-cat -t zramsetup
}

mem_total=$(awk '/MemTotal/{print int($2 * 1024 * 0.25)}' /proc/meminfo)
log_and_print "Calculated ZRam size: $mem_total bytes (~25% of total)."

modprobe zram || true
zram_device=$(zramctl --find --size $mem_total 2>/dev/null || true)

if [[ -z "$zram_device" ]]; then
    log_and_print "No zram device found. Attempting to create one..."
    zram_device=$(zramctl --find --size $mem_total)
    log_and_print "Created new zram device: $zram_device"
else
    log_and_print "Re-using existing zram device: $zram_device"
fi

log_and_print "Setting up $zram_device as swap..."
mkswap "$zram_device"
swapon "$zram_device" -p 32767
log_and_print "ZRam device $zram_device set as swap (priority=32767)."
EOF
)

###############################################################################
# [18] main function
###############################################################################
main() {
    checkCommandDependencies
    installDependencies
    resolvePaths
    createDirectories

    # Step 1) remove leftover freecache references
    removeOldFreecacheUnits

    # Step 2) remove other conflicting services
    removeConflictingServices

    # Step 3) Let user pick whitelisted processes (interactive)
    configureWhitelist

    # Step 4) Build dynamic contents
    EARLYOOM_SERVICE_CONTENT="$(buildEarlyOOMContent)"
    FREECACHE_SCRIPT_CONTENT="$(buildFreeCacheScript)"

    # Step 5) Overwrite systemd unit files
    writeFile "$FREECACHE_SERVICE_CONTENT" "$FREECACHE_SERVICE"
    writeFile "$MEMORY_MONITOR_SERVICE_CONTENT" "$MEMORY_MONITOR_SERVICE"
    writeFile "$OOMD_SERVICE_CONTENT" "$OOMD_SERVICE"
    writeFile "$EARLYOOM_SERVICE_CONTENT" "$EARLYOOM_SERVICE"
    writeFile "$OOMD_CONF_CONTENT" "$OOMD_CONF"

    # Step 6) Overwrite scripts
    writeFile "$FREECACHE_SCRIPT_CONTENT"  "$BASE_DIR/freecache.sh"
    writeFile "$MEMORY_MONITOR_SCRIPT_CONTENT" "$BASE_DIR/memory_monitor.sh"
    writeFile "$ZRAM_SETUP_SCRIPT_CONTENT" "$ZRAM_SETUP_SCRIPT"

    # Step 7) Make scripts executable
    makeExecutable "$BASE_DIR/freecache.sh"
    makeExecutable "$BASE_DIR/memory_monitor.sh"
    makeExecutable "$ZRAM_SETUP_SCRIPT"

    # Step 8) Reload systemd and enable services
    reloadEnableStartServices

    # Step 9) Also enable & start earlyoom
    systemctl enable earlyoom.service || true
    systemctl start earlyoom.service  || true

    # Step 10) Also set up zram immediately (if desired)
    echo "Setting up zram..."
    "$ZRAM_SETUP_SCRIPT"

    echo
    echo "===================================================="
    echo " Setup Complete "
    echo "===================================================="
    echo "All leftover freecache references are removed."
    echo "All services have been overwritten with new values."
    echo "ZRAM device is configured for ~25% of total memory."
    echo "Whitelisting is set to: $FINAL_WHITELIST"
    echo "Check journald logs if any service fails to start."
    echo "Done!"
}

main
