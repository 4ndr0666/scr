# shellcheck disable=all
# ---- // LOG_ACTION FUNCTION:
log_action() {
    local action="$1"
    local log_file="$HOME/permission_changes.log"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $action" >> "$log_file"
}
