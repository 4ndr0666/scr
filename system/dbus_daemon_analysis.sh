#!/bin/bash
##
# --- // Set up a cron job with sudo crontab -e. Then append this:  0 * * * * /path/to/dbus_daemon_analysis.sh
#

# --- // DBUS_DAEMON_ANALYSIS.SH // ========
# --- // Auto escalate:
if [ "$(id -u)" -ne 0 ]; then
      sudo "$0" "$@"
    exit $?
fi

LOG_FILE="/tmp/dbus_daemon_analysis.log"
CPU_THRESHOLD=10.0  # CPU usage percentage threshold for action
MEM_THRESHOLD=10.0  # Memory usage percentage threshold for action

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

analyze_and_terminate() {
    pid=$1
    cpu_usage=$2
    mem_usage=$3

    if (( $(echo "$cpu_usage > $CPU_THRESHOLD" | bc -l) || $(echo "$mem_usage > $MEM_THRESHOLD" | bc -l) )); then
        log_message "High resource usage detected for PID $pid. Terminating..."
        kill -9 $pid
        log_message "PID $pid terminated due to high resource usage."
    fi
}

find /tmp -name 'dbus_daemon_analysis*.log' -mtime +7 -exec rm {} \;

log_message "Starting dbus-daemon investigation"

log_message "Analyzing dbus-daemon processes:"
ps aux | grep dbus-daemon | grep -v grep | awk '{print $2, $3, $11}' | while read pid ppid cmd; do
    cpu_usage=$(ps -p $pid -o %cpu=)
    mem_usage=$(ps -p $pid -o %mem=)
    log_message "PID: $pid, PPID: $ppid, CMD: $cmd, CPU: $cpu_usage%, MEM: $mem_usage%"
    analyze_and_terminate $pid $cpu_usage $mem_usage
done

log_message "Investigation and potential cleanup completed"

echo "Investigation report generated at: $LOG_FILE"
