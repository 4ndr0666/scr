#!/bin/bash
set -euo pipefail

# ======================= // INSTALL_MEMORY_MONITOR.SH //

## Privileges

if [ "$(id -u)" -ne 0 ]; then
    echo "This script requires root privileges. Please enter your password to continue."
    exec sudo "$0" "$@"
fi
echo "💀WARNING💀 - you are now operating as root..."
sleep 2

## Cyan highlight variables (for visual appeal)
CYAN='\033[0;36m'
RESET='\033[0m'

## Constants

BASE_DIR="/usr/local/bin"
FREECACHE_SERVICE="/etc/systemd/system/freecache.service"
MEMORY_MONITOR_SERVICE="/etc/systemd/system/memory_monitor.service"
OOMD_SERVICE="/etc/systemd/system/systemd-oomd.service"
EARLYOOM_SERVICE="/etc/systemd/system/earlyoom.service"
OOMD_CONF="/etc/systemd/oomd.conf"
EARLYOOM_BIN=""

## Deps

installDependencies() {
    local packages=("earlyoom" "procps-ng" "preload" "irqbalance" "zramswap" \
                    "uksmd" "systemd-oomd-defaults" "fzf")
    echo -e "${CYAN}Checking and installing any missing packages...${RESET}"
    for pkg in "${packages[@]}"; do
        if ! pacman -Qi "$pkg" &> /dev/null; then
            echo -e "${CYAN}Installing package $pkg...${RESET}"
            pacman -S --needed --noconfirm "$pkg" || {
                echo "Error: Failed to install $pkg"
                exit 1
            }
        else
            echo "Package $pkg is already installed."
        fi
    done
}

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

## Dirs and Paths

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
    echo -e "${CYAN}Found earlyoom binary at: ${EARLYOOM_BIN}${RESET}"
}

createDirectories() {
    if [[ ! -d "$BASE_DIR" ]]; then
        mkdir -p "$BASE_DIR" || {
            echo "Error: Failed to create $BASE_DIR"
            exit 1
        }
        echo -e "${CYAN}Created directory: $BASE_DIR${RESET}"
    elif [[ ! -w "$BASE_DIR" ]]; then
        echo "Error: Directory $BASE_DIR is not writable."
        exit 1
    else
        echo "Directory $BASE_DIR already exists."
    fi
}

## Clean Env

removeOldFreecacheUnits() {
    echo "Checking for leftover freecache services/units..."
    local leftover_services
    leftover_services=$(systemctl list-unit-files | grep -i freecache | awk '{print $1}' | grep -v '^freecache.service$' || true)
    local leftover_symlinks
    leftover_symlinks=$(find /etc/systemd/system/ -type l -lname '*freecache.service' 2>/dev/null | grep -v '/etc/systemd/system/freecache.service' || true)
    if [[ -z "$leftover_services" && -z "$leftover_symlinks" ]]; then
        echo "No leftover freecache services detected."
        return
    fi
    echo "Detected leftover freecache references:"
    echo "$leftover_services"
    echo "$leftover_symlinks"
    for svc in $leftover_services; do
        echo -e "${CYAN}Removing leftover freecache unit: $svc${RESET}"
        if systemctl is-active "$svc" &> /dev/null; then
            systemctl stop "$svc"
        fi
        systemctl disable "$svc" 2>/dev/null || true
        rm -f "/etc/systemd/system/$svc"
    done
    for link in $leftover_symlinks; do
        echo -e "${CYAN}Removing leftover symlink: $link${RESET}"
        rm -f "$link"
    done
    systemctl daemon-reload
}

## Remove stray service files for all deprecated units

removeOldServiceUnits() {
    echo "Checking for stray service units..."
    local services=("freecache.service" "memory_monitor.service" "systemd-oomd.service" "earlyoom.service")
    for svc in "${services[@]}"; do
        local stray_files
        stray_files=$(find /etc/systemd/system/ -type l -name "$svc" ! -path "/etc/systemd/system/$svc" 2>/dev/null || true)
        if [[ -n "$stray_files" ]]; then
            echo -e "${CYAN}Stray instances found for $svc:${RESET}"
            echo "$stray_files"
            for file in $stray_files; do
                echo -e "${CYAN}Removing stray file: $file${RESET}"
                rm -f "$file"
            done
        fi
    done
    systemctl daemon-reload
}

removeConflictingServices() {
    echo "Checking for conflicting services..."
    local conflicting_services=("cgroup2ctl.service" "dbus-org.freedesktop.oom1.service")
    local detected_services
    detected_services=$(systemctl list-unit-files --type=service | awk '{print $1}' | grep -E 'oom|earlyoom|memory_monitor|freecache' | grep -vE 'systemd-oomd.service|earlyoom.service|memory_monitor.service|freecache.service' || true)
    echo -e "${CYAN}Detected conflicting services: $detected_services${RESET}"
    for service in "${conflicting_services[@]}"; do
        if systemctl list-unit-files | grep -q "^${service}"; then
            echo -e "${CYAN}Removing conflicting service: $service${RESET}"
            if systemctl is-active "$service" &> /dev/null; then
                systemctl stop "$service"
            fi
            systemctl disable "$service" 2>/dev/null || true
            rm -f "/etc/systemd/system/$service"
        fi
    done
    for service in $detected_services; do
        echo -e "${CYAN}Removing detected conflicting service: $service${RESET}"
        if systemctl is-active "$service" &> /dev/null; then
            systemctl stop "$service"
        fi
        systemctl disable "$service" 2>/dev/null || true
        rm -f "/etc/systemd/system/$service"
    done
}

## Write scripts

writeFile() {
    local content="$1"
    local path="$2"
    if [[ -f "$path" ]]; then
        local existing_content
        existing_content=$(<"$path")
        if [[ "$existing_content" == "$content" ]]; then
            echo "File $path is already correct."
            return
        else
            echo -e "${CYAN}Overwriting file at $path...${RESET}"
            mkdir -p "$(dirname "$path")"
            echo "$content" > "$path"
        fi
    else
        echo -e "${CYAN}File $path written successfully.${RESET}"
        mkdir -p "$(dirname "$path")" 2>/dev/null
        echo "$content" > "$path"
    fi
}

makeExecutable() {
    local script="$1"
    if [[ -x "$script" ]]; then
        echo "Script $script is already executable."
    else
        chmod +x "$script"
        echo -e "${CYAN}Made $script executable.${RESET}"
    fi
}

## SystemD

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
            echo -e "${CYAN}Service $service has been enabled.${RESET}"
        fi
        if systemctl is-active --quiet "$service"; then
            echo "Service $service is already running."
        else
            systemctl start "$service" || {
                echo "Failed to start $service"
                return 1
            }
            echo -e "${CYAN}Service $service has been started.${RESET}"
        fi
    done
}

enableServiceSafely() {
    local service="$1"
    if systemctl is-enabled --quiet "$service"; then
        echo "Service $service is already enabled."
    else
        systemctl enable "$service" || {
            echo "Failed to enable $service"
            return 1
        }
        echo -e "${CYAN}Service $service has been enabled.${RESET}"
    fi
}

validateServiceFile() {
    local file="$1"
    if systemd-analyze verify "$file"; then
        echo -e "${CYAN}Service file $file is valid.${RESET}"
    else
        echo "Warning: Service file $file has issues. Please review manually."
    fi
}

## Whitelist

configureWhitelist() {
    echo "Gathering list of currently running processes..."
    echo -e "${CYAN}→ Please select the processes you wish to whitelist using fzf. (Press ENTER when done.)${RESET}"
    local proc_list
    proc_list=$(ps aux | awk '$1!="root" && NR>1 {print $11}' | sort -u)
    echo -e "${CYAN}Select processes you want to WHITELIST (fzf multi-select).${RESET}"
    echo -e "${CYAN}Press ENTER when done. If none selected, defaults will be used.${RESET}"
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
    echo -e "${CYAN}Final whitelist: ${FINAL_WHITELIST}${RESET}"
}

## Heredocs

#### Freecache SystemD
FREECACHE_SERVICE_CONTENT=$(cat <<'EOF'
[Unit]
Description=Free Cache when Memory is Low
After=memory_monitor.service systemd-oomd.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/freecache.sh
AmbientCapabilities=CAP_KILL CAP_IPC_LOCK
CapabilityBoundingSet=CAP_KILL CAP_IPC_LOCK
Nice=-20
OOMScoreAdjust=-100

[Install]
WantedBy=multi-user.target
EOF
)

#### Memory Monitor SystemD
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

#### Memory Monitor Script
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

## Oomd Killer SystemD
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

#### EarlyOOM SystemD
buildEarlyOOMContent() {
    cat <<EOF
[Unit]
Description=Early OOM Daemon
After=network.target

[Service]
ExecStart=$EARLYOOM_BIN -m 40 -s 40 -r 60 -p -d -n --sort-by-rss --avoid '(^|/)(init|X|wayland|wayfire|sshd|systemd)$'
Restart=always
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF
}

#### OOMD Config
OOMD_CONF_CONTENT=$(cat <<'EOF'
# /etc/systemd/oomd.conf
# oomd Configuration File

[OOM]
SwapUsedLimit=30%
DefaultMemoryPressureLimit=30%
DefaultMemoryPressureDurationSec=5s
EOF
)

#### Freecache Script
buildFreeCacheScript() {
    cat <<'EOS'
#!/bin/bash
set -euo pipefail

# Ensure FINAL_WHITELIST is set; if not, set default values.
: "${FINAL_WHITELIST:=wayfire Xwayland }"

log_action() {
    local msg="$1"
    echo "$msg" | systemd-cat -t freecache
}

adjust_swappiness() {
    local target_swappiness=133
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
        echo 3 > /proc/sys/vm/drop_caches || { echo "Error: Failed to drop caches."; exit 1; }
        log_action "RAM cache cleared due to low free memory (${free_ram_mb}MB)."
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
    exit 0
}

main
EOS
}

## Main entry point

main() {
    checkCommandDependencies
    installDependencies
    resolvePaths
    createDirectories
    removeOldFreecacheUnits
    removeConflictingServices
    removeOldServiceUnits
    configureWhitelist
    EARLYOOM_SERVICE_CONTENT="$(buildEarlyOOMContent)"
    FREECACHE_SCRIPT_CONTENT="$(buildFreeCacheScript)"
    writeFile "$FREECACHE_SERVICE_CONTENT" "$FREECACHE_SERVICE"
    writeFile "$MEMORY_MONITOR_SERVICE_CONTENT" "$MEMORY_MONITOR_SERVICE"
    writeFile "$OOMD_SERVICE_CONTENT" "$OOMD_SERVICE"
    writeFile "$EARLYOOM_SERVICE_CONTENT" "$EARLYOOM_SERVICE"
    writeFile "$OOMD_CONF_CONTENT" "$OOMD_CONF"
    writeFile "$FREECACHE_SCRIPT_CONTENT"  "$BASE_DIR/freecache.sh"
    writeFile "$MEMORY_MONITOR_SCRIPT_CONTENT" "$BASE_DIR/memory_monitor.sh"
    makeExecutable "$BASE_DIR/freecache.sh"
    makeExecutable "$BASE_DIR/memory_monitor.sh"
    reloadEnableStartServices
    enableServiceSafely "earlyoom.service"
    echo -e "${CYAN}✔️ Memory Monitor service is installed.${RESET}"
    echo
    echo -e "${CYAN}# === // Whitelisted Items //${RESET}"
    echo "$FINAL_WHITELIST"
}

main
