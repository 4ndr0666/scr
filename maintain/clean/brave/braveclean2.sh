#!/usr/bin/env bash
#
# BraveClean.sh - A script to clean up Brave Browser and other browser profiles.
# Author: 4ndr0666
#
# This script performs the following cleanup tasks:
# 1. Vacuums SQLite databases in browser profiles (Firefox, Chromium, Brave, etc.).
# 2. Removes specific cache and temporary directories/files for Brave Browser.
# 3. Provides a user prompt to kill running browser processes before cleanup.
# 4. Performs additional cleanup actions, including Chromium cache.
#
# Usage: ./braveclean.sh
#
# Requirements:
# - sqlite3: For vacuuming SQLite databases.
# - notify-send (optional): For desktop notifications.

# Set strict shell options for robustness:
# -e: Exit immediately if a command exits with a non-zero status.
# -u: Treat unset variables as an error.
# -o pipefail: The return value of a pipeline is the status of the last command
#              to exit with a non-zero status, or zero if all commands exit successfully.
set -euo pipefail

# IFS is left at its default value for most operations.
# It is explicitly set to ' ' or '' where needed for 'read' to prevent word splitting.

# ============================== // BRAVECLEAN.SH //

## Color variables
# Using ANSI escape codes for colors. These are widely supported in modern terminals.
RED="\e[01;31m"
GRN="\e[01;32m"
YLW="\e[01;33m"
RST="\e[00m" # Reset to default color and style

## Logging
LOG_FILE="/tmp/BraveClean.log" # Using /tmp for temporary logs, generally acceptable for cleanup scripts.

# log: Writes messages to the log file with a timestamp.
# Arguments:
#   $1 - The message to log.
log() {
  local msg="$1" # Declare msg as local to the function.
  printf "%s %s\n" "$(date +%Y-%m-%dT%H:%M:%S%z)" "$msg" >> "$LOG_FILE"
}

## Error Handling
# error_exit: Prints an error message to stderr, logs it, and exits with status 1.
# Arguments:
#   $1 - The error message.
error_exit() {
  local msg="$1" # Declare msg as local to the function.
  printf "${RED}Error:${RST} %s\n" "$msg" >&2
  log "ERROR: $msg"
  exit 1
}

## Dependency Checks
# dep_check_sqlite3: Checks if the 'sqlite3' command is available.
dep_check_sqlite3() {
  # command -v is robust for checking command existence.
  if ! command -v sqlite3 >/dev/null 2>&1; then
    error_exit "sqlite3 not found. Please install it to enable database vacuuming."
  fi
}

# dep_check_notify_send: Checks if the 'notify-send' command is available.
# Returns 0 if found, 1 otherwise.
dep_check_notify_send() {
  command -v notify-send >/dev/null 2>&1
}

## Spinner for User Experience
# spinner: Displays a spinning cursor while a background process runs.
# Arguments:
#   $1 - PID of the process to monitor.
spinner() {
  local pid="$1"
  local delay=0.1
  local spin='|/-\\' # Escaping the backslash for SC1003
  local i=0
  while kill -0 "$pid" 2>/dev/null; do # kill -0 checks if PID exists without sending a signal.
    printf "%s\b" "${spin:$i:1}" # Print character and backspace to overwrite
    sleep "$delay"
    i=$(( (i + 1) % 4 )) # Cycle through spinner characters
  done
  printf " \b" # Clear the spinner character after the process finishes
}

## Core Cleaning Logic
# run_cleaner: Finds and vacuums SQLite databases in the current directory.
# This function expects to be run from within a browser profile directory.
run_cleaner() {
  local total_cleaned_kb=0
  local db_file s_old s_new diff_kb diff_str

  # Find SQLite files in the current directory (maxdepth 1) and process them.
  # Using -print0 and read -d '' for robustness against unusual filenames (e.g., spaces, newlines).
  while IFS= read -r -d '' db_file; do
    # Skip if db_file is empty (e.g., if find returns nothing, though unlikely with -print0)
    [[ -z "$db_file" ]] && continue

    # Print the cleaning message, filename only
    printf "${GRN} Cleaning${RST}  %s" "${db_file##*/}"

    # Get initial file size. If stat fails (e.g., file disappears), default to 0.
    s_old=$(stat -c%s "$db_file" 2>/dev/null || echo 0)

    # Perform vacuum and reindex in a subshell, running spinner concurrently.
    (
      # Remove WAL (Write-Ahead Log) and SHM (Shared Memory) files first.
      # These are temporary files used by SQLite and can be safely removed.
      # '|| true' prevents script from exiting if files don't exist.
      rm -f -- "${db_file}-wal" "${db_file}-shm" 2>/dev/null || true
      # Vacuum: Rebuilds the database, reclaiming unused space.
      sqlite3 "$db_file" "VACUUM;" >/dev/null 2>&1
      # Reindex: Rebuilds all indexes in the database.
      sqlite3 "$db_file" "REINDEX;" >/dev/null 2>&1
    ) & spinner $!; wait # Run subshell in background, start spinner, then wait for subshell

    # Get new file size. If stat fails, default to 0.
    s_new=$(stat -c%s "$db_file" 2>/dev/null || echo 0)

    # Calculate difference in KB.
    diff_kb=$(( (s_old - s_new) / 1024 ))
    total_cleaned_kb=$(( total_cleaned_kb + diff_kb ))

    # Format difference string for output.
    if (( diff_kb > 0 )); then
      diff_str="${YLW}- ${diff_kb} KB${RST}" # Space reclaimed (yellow)
    elif (( diff_kb < 0 )); then
      diff_str="${RED}+ $(( -diff_kb )) KB${RST}" # File grew (red)
    else
      diff_str="${RST}∘${RST}" # No change (default color)
    fi

    # Print completion message, using carriage return to overwrite the previous line.
    # The %-45s pads the string to 45 characters, ensuring alignment.
    printf "\r%-45s %s %s\n" "${GRN} Cleaning${RST}  ${db_file##*/}" "${GRN}done${RST}" "${diff_str}"

  done < <(find . -maxdepth 1 -type f -name "*.sqlite" -print0) # Find files ending with .sqlite

  # Summary message for the current profile.
  if (( total_cleaned_kb > 0 )); then
    printf "Total space reclaimed in this profile: ${YLW}%s${RST} KB\n" "$total_cleaned_kb"
  else
    printf "No space reclaimed in this profile.\n"
  fi
}

## Process Management
# if_running: Checks if a process is running and prompts the user to kill it.
# Arguments:
#   $1 - The process name to check (e.g., "firefox", "brave").
if_running() {
  local process_name="$1"
  local user="$USER" # Using $USER is generally fine here for user-specific processes.
  local max_wait_attempts=5 # Number of 2-second waits before prompting to kill
  local current_wait_attempts=0
  local ans

  if pgrep -u "$user" "$process_name" >/dev/null 2>&1; then
    printf "Waiting for %s to exit" "$process_name"
    while pgrep -u "$user" "$process_name" >/dev/null 2>&1; do
      if (( current_wait_attempts >= max_wait_attempts )); then
        printf "\n" # Newline after dots
        printf " %s is still running. Kill %s now? [y/N]: " "$process_name" "$process_name"
        read -r ans # -r prevents backslash escapes from being interpreted.
        if [[ "$ans" =~ ^[Yy]$ ]]; then # Case-insensitive check for 'y' or 'Y'.
          printf "Attempting to terminate %s...\n" "$process_name"
          pkill -TERM -u "$user" "$process_name" || true # Send graceful termination signal
          sleep 4 # Give it some time to shut down
          if pgrep -u "$user" "$process_name" >/dev/null 2>&1; then
            printf "Force killing %s...\n" "$process_name"
            pkill -KILL -u "$user" "$process_name" || true # Force kill if still running
          fi
        else
          printf "Please close %s manually and re-run the script.\n" "$process_name"
          exit 1
        fi
        current_wait_attempts=0 # Reset attempts after prompt
      fi
      printf "."
      sleep 2
      current_wait_attempts=$(( current_wait_attempts + 1 ))
    done
    printf "\n" # Newline after dots or wait message
  fi
}

## Brave-specific and Additional Cleanup
# perform_additional_cleanup: Performs Brave-specific and other requested cleanup steps.
perform_additional_cleanup() {
  local brave_dir="$HOME/.config/BraveSoftware/Brave-Browser" # Default Brave stable path
  local dirs_to_remove
  local dd
  local brave_subdirs_to_clear
  local subdir

  # Check for Brave Beta if stable not found
  if [[ ! -d "$brave_dir" ]]; then
    brave_dir="$HOME/.config/BraveSoftware/Brave-Browser-Beta"
  fi

  if [[ ! -d "$brave_dir" ]]; then
    printf "Brave directory not found (%s). Skipping Brave-specific cleanup.\n" "$brave_dir"
  else
    printf "Performing Brave-specific cleanup steps in %s...\n" "$brave_dir"

    # Use pushd/popd to manage directory changes safely and handle errors.
    pushd "$brave_dir" >/dev/null || { log "ERROR: Could not change to Brave directory: $brave_dir"; return; }

    # List of directories within the Brave profile to be completely removed.
    dirs_to_remove=(
      component_crx_cache
      extensions_crx_cache
      "Crash Reports"
      Greaselion
      GrShaderCache
      ShaderCache
      GraphiteDawnCache
      "Local Traces"
    )
    for dd in "${dirs_to_remove[@]}"; do
      if [[ -d "$dd" ]]; then
        printf "Removing directory: %s\n" "$dd"
        rm -rf -- "$dd" # Using '--' to protect against paths starting with '-'
      fi
    done

    # List of directories whose *contents* should be cleared, but the directory itself kept.
    brave_subdirs_to_clear=(
      "Guest Profile"
    )
    for subdir in "${brave_subdirs_to_clear[@]}"; do
      if [[ -d "$subdir" ]]; then
        printf "Clearing contents of directory: %s\n" "$subdir"
        # Using find -mindepth 1 -delete is the most robust way to clear directory contents,
        # including hidden files, without removing the parent directory itself.
        find "$subdir" -mindepth 1 -delete
      fi
    done

    popd >/dev/null || { log "ERROR: Could not return from Brave directory."; return; }
  fi

  # --- Additional Cleanup Steps ---

  # Clear Chromium's cache.
  # Note: This clears the cache for Chromium, not Brave, but is included here
  # as a general browser-related cleanup step.
  printf "Removing Chromium cache: %s\n" "$HOME/.cache/chromium"
  # Using '--' to protect against paths starting with '-' and '|| true' to prevent script exit
  # if the path does not exist (e.g., Chromium not installed).
  rm -rf -- "$HOME/.cache/chromium" || true
}

## Main Browser Vacuuming Function
# vacuum_browsers: Iterates through known browser configurations and cleans their profiles.
vacuum_browsers() {
  # Define browser configurations: [display_name]="config_path_relative_to_HOME"
  # This makes the script easily extensible for new browsers/paths.
  declare -A browser_configs=(
    [Firefox]=".mozilla/firefox"
    [Icecat]=".mozilla/icecat"
    [Seamonkey]=".mozilla/seamonkey"
    [Aurora]=".mozilla/aurora"
    [Chromium]=".config/chromium"
    [Chromium-Beta]=".config/chromium-beta"
    [Chromium-Dev]=".config/chromium-dev"
    [Google-Chrome]=".config/google-chrome"
    [Google-Chrome-Beta]=".config/google-chrome-beta"
    [Google-Chrome-Unstable]=".config/google-chrome-unstable"
    [Brave-Browser-Beta]=".config/BraveSoftware/Brave-Browser-Beta"
    [Brave-Browser]=".config/BraveSoftware/Brave-Browser"
  )

  # Map browser display names to actual process names for pgrep.
  # This handles cases where the config directory name differs from the process name.
  declare -A process_names=(
    [Firefox]="firefox"
    [Icecat]="icecat"
    [Seamonkey]="seamonkey"
    [Aurora]="aurora"
    [Chromium]="chromium"
    [Chromium-Beta]="chromium-beta"
    [Chromium-Dev]="chromium-dev"
    [Google-Chrome]="chrome" # Common process name for Chrome variants
    [Google-Chrome-Beta]="chrome"
    [Google-Chrome-Unstable]="chrome"
    [Brave-Browser-Beta]="brave" # Common process name for Brave variants
    [Brave-Browser]="brave"
  )

  local b_name config_path full_config_path p_name
  local ini_file profiledir_found profile_dirs=()
  local line # Declare 'line' as local to this function.

  # Loop through each defined browser.
  for b_name in "${!browser_configs[@]}"; do
    config_path="${browser_configs[$b_name]}"
    full_config_path="$HOME/$config_path"
    # Get the process name, defaulting to the browser display name if not explicitly mapped.
    p_name="${process_names[$b_name]:-$b_name}"

    # Print initial scanning message.
    printf "[%s] Scanning for %s" "${YLW}$USER${RST}" "${GRN}$b_name${RST}"

    if [[ -d "$full_config_path" ]]; then
      # Overwrite the "Scanning for..." line with "found" status.
      printf "\r[%s] Scanning for %s %s\n" "${YLW}$USER${RST}" "${GRN}$b_name${RST}" "[${GRN}found${RST}]"
      # Check if the browser process is running and prompt to kill if necessary.
      if_running "$p_name"

      profile_dirs=() # Reset array for each browser to store its profile paths.

      # Handle Firefox-like profiles, which use a profiles.ini file.
      if [[ "$b_name" =~ ^(Firefox|Icecat|Seamonkey|Aurora)$ ]]; then
        ini_file="$full_config_path/profiles.ini"
        if [[ -f "$ini_file" ]]; then
          # Read profile paths from profiles.ini.
          # IFS= ensures 'read' processes each line as a single field, ignoring spaces.
          while IFS= read -r line; do
            if [[ "$line" =~ ^Path=(.*)$ ]]; then
              # Correctly construct the full profile directory path.
              profile_dirs+=("$full_config_path/${BASH_REMATCH[1]}")
            fi
          done < "$ini_file"
        fi
      else # Handle Chromium-like profile directories (e.g., "Default", "Profile 1").
        # Find "Default" and "Profile*" directories within the browser's config path.
        # Using -print0 and read -d '' for robustness against unusual filenames.
        while IFS= read -r -d '' profiledir_found; do
          profile_dirs+=("$profiledir_found")
        done < <(find "$full_config_path" -maxdepth 1 -type d \( -iname "Default" -o -iname "Profile*" \) -print0)
      fi

      # Process each found profile directory.
      if (( ${#profile_dirs[@]} > 0 )); then
        for profiledir in "${profile_dirs[@]}"; do
          if [[ -d "$profiledir" ]]; then
            printf "[%s]\n" "${YLW}${profiledir##*/}${RST}" # Print profile name (e.g., "Default", "Profile 1")
            # Use pushd/popd to manage directory changes safely for run_cleaner.
            pushd "$profiledir" >/dev/null || { log "ERROR: Could not change to profile directory: $profiledir"; continue; }
            run_cleaner # Call the core cleaning function.
            popd >/dev/null || { log "ERROR: Could not return from profile directory: $profiledir"; }
          fi
        done
      else
        printf "No profiles found for %s in %s.\n" "$b_name" "$full_config_path"
      fi
    else
      # Overwrite the "Scanning for..." line with "none" status if directory not found.
      printf "\r[%s] Scanning for %s %s\n" "${YLW}$USER${RST}" "${GRN}$b_name${RST}" "[${RED}none${RST}]"
      sleep 0.1 # Small delay for better visual flow.
    fi
  done

  printf "Browser vacuuming complete.\n"
}

## Main Execution Block
main() {
  local ans # Declare local variable for user input.

  # Check if running as root and warn the user.
  if [[ $EUID -eq 0 ]]; then
    printf "%sWarning:%s Running as root can cause permission issues with user browser profiles.\n" "$YLW" "$RST"
    printf "Continue? [y/N]: "
    read -r ans
    [[ "$ans" =~ ^[Yy]$ ]] || exit 1
  fi

  # Ensure sqlite3 is available before starting any cleanup operations.
  dep_check_sqlite3

  # Perform browser vacuuming for all configured browsers.
  vacuum_browsers
  # Perform Brave-specific and other additional cleanup steps.
  perform_additional_cleanup

  # Send a desktop notification if notify-send is available, otherwise print to console.
  if dep_check_notify_send; then
    notify-send "BraveClean" "Your browser profiles have been cleaned!"
  else
    printf "\n%sCleanup complete! Your browser profiles are now cleaner.%s\n" "$GRN" "$RST"
  fi
}

# Entry point: ensures main is called only when the script is executed directly.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
