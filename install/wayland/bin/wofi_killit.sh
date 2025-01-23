#!/bin/bash

# --- // Killit: Standalone Script with Wofi Integration

# Function to display error messages
error() {
    notify-send "killit - Error" "$1"
}

# Function to fetch processes matching the pattern
fetch_processes() {
    local pattern="$1"
    # List processes with PID and command, excluding the killit script itself
    pgrep -fl "$pattern" | grep -v "$0"
}

# Function to display processes in wofi and allow selection
select_processes_wofi() {
    local processes="$1"
    echo "$processes" | wofi --dmenu \
        --prompt "Select processes to kill:" \
        --multi-select \
        --height 50 \
        --width 400 \
        | awk '{print $1}'
}

# Function to prompt for manual PID entry using wofi
manual_pid_entry_wofi() {
    wofi --dmenu \
        --prompt "Enter PIDs to kill (separated by spaces):" \
        --height 50 \
        --width 400 \
        | tr ',' ' ' | tr '\n' ' '
}

# Function to confirm killing selected PIDs using wofi
confirm_kill_wofi() {
    local pids="$1"
    # Fetch process names for confirmation
    local confirmation=""
    for pid in $pids; do
        if ps -p "$pid" &>/dev/null; then
            proc_name=$(ps -p "$pid" -o comm=)
            confirmation+="PID: $pid - $proc_name\n"
        else
            confirmation+="PID: $pid - [Process not found]\n"
        fi
    done
    echo -e "$confirmation" | wofi --dmenu \
        --prompt "Confirm killing the following processes? (y/N)" \
        --height 200 \
        --width 400 \
        | grep -iq "^y"
}

# Main loop
while true; do
    # Prompt for process pattern using wofi
    pattern=$(echo "" | wofi --dmenu \
        --prompt "Enter process name or pattern:" \
        --height 50 \
        --width 400)

    # Exit if no input
    if [[ -z "$pattern" ]]; then
        exit 0
    fi

    # Fetch matching processes
    pids_with_names=$(fetch_processes "$pattern")

    if [[ -z "$pids_with_names" ]]; then
        error "No processes found matching '$pattern'."
        # Ask if the user wants to search again
        search_again=$(echo -e "Yes\nNo" | wofi --dmenu \
            --prompt "No matches found. Search again?" \
            --height 50 \
            --width 400)
        if [[ "$search_again" != "Yes" && "$search_again" != "y" && "$search_again" != "Y" ]]; then
            exit 0
        else
            continue
        fi
    fi

    # Display processes and allow selection
    selected_pids=$(select_processes_wofi "$pids_with_names")

    # Allow manual PID entry
    manual_pids=$(manual_pid_entry_wofi)

    # Combine selected and manual PIDs
    all_pids="$selected_pids $manual_pids"

    # Remove duplicates and invalid entries
    all_pids=$(echo "$all_pids" | tr ' ' '\n' | sort -u | grep -E '^[0-9]+$' | tr '\n' ' ')

    if [[ -z "$all_pids" ]]; then
        error "No valid PIDs selected."
        # Ask if the user wants to search again
        search_again=$(echo -e "Yes\nNo" | wofi --dmenu \
            --prompt "No PIDs selected. Search again?" \
            --height 50 \
            --width 400)
        if [[ "$search_again" != "Yes" && "$search_again" != "y" && "$search_again" != "Y" ]]; then
            exit 0
        else
            continue
        fi
    fi

    # Confirm before killing
    if confirm_kill_wofi "$all_pids"; then
        for pid in $all_pids; do
            if ps -p "$pid" &>/dev/null; then
                if sudo kill -9 "$pid" &>/dev/null; then
                    notify-send "killit" "Process $pid killed successfully."
                else
                    notify-send "killit" "Failed to kill process $pid."
                fi
            else
                notify-send "killit" "PID $pid does not exist. Skipping."
            fi
        done
    else
        notify-send "killit" "Kill operation canceled."
    fi

    # Ask if the user wants to perform another kill operation
    again=$(echo -e "Yes\nNo" | wofi --dmenu \
        --prompt "Do you want to kill more processes?" \
        --height 50 \
        --width 400)
    if [[ "$again" != "Yes" && "$again" != "y" && "$again" != "Y" ]]; then
        exit 0
    fi
done
