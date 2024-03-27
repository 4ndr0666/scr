#!/usr/bin/env bash


# --- // Set up a cron job with sudo crontab -e. Then append this:  0 * * * * /path/to/dbus_daemon_analysis.sh
# --- // Auto escalate:
if [ "$(id -u)" -ne 0 ]; then
      sudo "$0" "$@"
    exit $?
fi

# Ensure script is run as root
if [ "$(id -u)" -ne 0 ]; then
      exec sudo "$0" "$@"
fi

LOG_FILE="/tmp/dbus_daemon_analysis.log"
CPU_THRESHOLD=10.0
MEM_THRESHOLD=10.0

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

analyze_and_terminate() {
    local pid=$1 cpu_usage=$2 mem_usage=$3

    if (( $(echo "$cpu_usage > $CPU_THRESHOLD" | bc -l) || $(echo "$mem_usage > $MEM_THRESHOLD" | bc -l) )); then
        log_message "High resource usage detected for PID $pid. Terminating..."
        kill -9 "$pid"
        log_message "PID $pid terminated due to high resource usage."
    fi
}

# Log file rotation
find /tmp -name 'dbus_daemon_analysis*.log' -mtime +7 -exec rm {} \;

log_message "Starting dbus-daemon investigation"

ps aux | grep [d]bus-daemon | awk '{print $2, $3, $4, $11}' | while read -r pid cpu mem cmd; do
    log_message "PID: $pid, CMD: $cmd, CPU: $cpu%, MEM: $mem%"
    analyze_and_terminate "$pid" "$cpu" "$mem"
done

log_message "Investigation and potential cleanup completed"
echo "Investigation report generated at: $LOG_FILE"



