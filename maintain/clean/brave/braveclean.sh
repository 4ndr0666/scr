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
#   BRAVE_DEEP_CLEAN=1 ./braveclean.sh   # Also clears GPUCache, Code Cache, Service Worker/CacheStorage
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

# IFS is explicitly set to newline and tab for array processing etc.
# It is explicitly set to ' ' or '' where needed for 'read' to prevent word splitting.
IFS=$'\n\t'

# ============================== // BRAVECLEAN.SH //

# Global variable for deep clean mode
DEEP_CLEAN=0

# usage: Displays help message and exits.
usage() {
  printf "Usage: %s [-d|--deep-clean] [-h|--help]\n" "$(basename "$0")"
  printf "\n"
  printf "  -d, --deep-clean    Perform a deep clean, removing additional caches (GPUCache, Code Cache, Service Worker/CacheStorage, DawnCache).\n"
  printf "  -h, --help          Display this help message and exit.\n"
  printf "\n"
  printf "This script cleans up Brave Browser and other browser profiles by vacuuming SQLite databases and removing specific cache and temporary directories/files.\n"
  exit 0
}

## Color variables (more robust using tput)
# Check if stdout is a tty AND supports colors
if [[ -t 1 && -n "$TERM" && "$TERM" != "dumb" ]]; then
    # Use tput for more robust color code retrieval
    RED=$(tput setaf 1 || true) # Red foreground
    GRN=$(tput setaf 2 || true) # Green foreground
    YLW=$(tput setaf 3 || true) # Yellow foreground
    RST=$(tput sgr0 || true)    # Reset all attributes
else
    RED=; GRN=; YLW=; RST=; # No colors if not a TTY or no color support
fi

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
  local err_red="$RED" err_rst="$RST"
  if ! [[ -t 2 && -n "$TERM" && "$TERM" != "dumb" ]]; then # Check if stderr is a TTY
    err_red=; err_rst=; # Disable colors if stderr is not a TTY
  fi
  printf "%sError:%s %s\n" "$err_red" "$err_rst" "$1" >&2
  log "ERROR: $1"
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

## Spinner for User Experience (reintegrated from first script's pattern)
_spid=""
spin_start(){ ( local g='|/-\' i=0; while :; do printf '%s\b' "${g:i++%4:1}"; sleep 0.1; done ) & _spid=$!; }
spin_stop(){ [[ -n "${_spid}" ]] && { kill "${_spid}" 2>/dev/null || true; wait "${_spid}" 2>/dev/null || true; _spid=""; printf ' \b'; }; }
trap 'spin_stop' EXIT INT TERM

## Process Management (reintegrated from first script's pattern, modified)
# kill_browser: Checks if a process is running and prompts the user to kill it.
# Arguments:
#   $1 - The process name to check (e.g., "firefox", "brave").
kill_browser() {
  local proc="$1" user="${USER}" tries=0
  pgrep -u "$user" "$proc" >/dev/null 2>&1 || return 0
  printf "Waiting for %s to exit" "$proc"
  while pgrep -u "$user" "$proc" >/dev/null 2>&1; do
    ((tries++))
    if (( tries >= 5 )); then # Wait 5 * 2 = 10 seconds before prompting
      printf "\nKill %s now? [y/N]: " "$proc"
      local a; read -r a
      if [[ "$a" =~ ^[Yy]$ ]]; then
        pkill -TERM -u "$user" "$proc" || true; sleep 4
        pgrep -u "$user" "$proc" >/dev/null 2>&1 && pkill -KILL -u "$user" "$proc" || true
      else
        printf "Please close %s manually and re-run the script.\n" "$proc"; exit 1
      fi
      break # Exit the loop after user interaction
    fi
    printf "."; sleep 2
  done
  printf "\n" # Ensure a newline after dots
}

## Core Cleaning Logic
# vacuum_db: Performs SQLite vacuum, reindex, and optimization.
# Arguments:
#   $1 - Path to the SQLite database file.
vacuum_db(){
  local db="$1"
  rm -f -- "${db}-wal" "${db}-shm" 2>/dev/null || true
  # Combined VACUUM, REINDEX, PRAGMA optimize for efficiency and thoroughness.
  sqlite3 "$db" "PRAGMA journal_mode=DELETE; VACUUM; REINDEX; PRAGMA optimize;" >/dev/null 2>&1 || true
}

# run_cleaner: Finds and vacuums SQLite databases in the current directory.
# This function expects to be run from within a browser profile directory.
run_cleaner() {
  local total_cleaned_kb=0
  local db_file s_old s_new diff_kb diff_str

  # Find SQLite files in the current directory (maxdepth 1) and process them.
  # Using -print0 and read -d '' for robustness against unusual filenames (e.g., spaces, newlines).
  while IFS= read -r -d '' db_file; do
    [[ -z "$db_file" ]] && continue # Skip if db_file is empty

    # Print the cleaning message, filename only
    printf "${GRN} Cleaning${RST}  %s" "${db_file##*/}"

    # Get initial file size. If stat fails (e.g., file disappears), default to 0.
    s_old=$(stat -c%s "$db_file" 2>/dev/null || echo 0)

    spin_start # Start spinner
    vacuum_db "$db_file" # Perform vacuum
    spin_stop # Stop spinner

    # Get new file size. If stat fails, default to 0.
    s_new=$(stat -c%s "$db_file" 2>/dev/null || echo 0)

    # Calculate difference in KB.
    diff_kb=$(( (s_old - s_new) / 1024 ))
    total_cleaned_kb=$(( total_cleaned_kb + diff_kb ))

    # Format difference string for output.
    if (( diff_kb > 0 )); then
      diff_str="${YLW}- ${diff_kb} KB${RST}" # Space reclaimed (yellow)
    elif (( diff_kb < 0 )); then
      diff_str="${RED}+ $(( -diff_kb )) KB (grew)${RST}" # File grew (red)
    else
      diff_str="${RST}∘${RST}" # No change (default color)
    fi

    # Print completion message, using carriage return to overwrite the previous line.
    # The %-45s pads the string to 45 characters, ensuring alignment.
    printf "\r%-45s %s %s\n" "${GRN} Cleaning${RST}  ${db_file##*/}" "${GRN}done${RST}" "${diff_str}"

  done < <(find . -maxdepth 1 -type f -name "*.sqlite" -print0)

  # Summary message for the current profile.
  if (( total_cleaned_kb > 0 )); then
    printf "Total space reclaimed in this profile: ${YLW}%s${RST} KB\n" "$total_cleaned_kb"
  else
    printf "No space reclaimed in this profile.\n"
  fi
}

# ----- Brave-specific cache cleanup (consolidated from first script) -----
clean_brave_specific_caches(){
  local dir="$1"
  printf "Performing Brave-specific cache cleanup in %s...\n" "$dir"
  pushd "$dir" >/dev/null || { log "pushd failed: $dir"; return; }

  # Always-safe removals
  local -a rm_dirs=(
    component_crx_cache extensions_crx_cache "Crash Reports"
    Greaselion GrShaderCache ShaderCache GraphiteDawnCache "Local Traces"
  )
  for d in "${rm_dirs[@]}"; do
    if [[ -d "$d" ]]; then
      printf "Removing directory: %s\n" "$d"
      rm -rf -- "$d"
    fi
  done

  # Deep cache (opt-in via --deep-clean flag)
  if (( DEEP_CLEAN == 1 )); then
    local -a deep=(
      "GPUCache" "Code Cache" "Service Worker/CacheStorage" "DawnCache"
    )
    for d in "${deep[@]}"; do
      if [[ -e "$d" ]]; then
        printf "DEEP: Removing: %s\n" "$d"
        rm -rf -- "$d"
      fi
    done
  fi

  # Keep folder, clear contents
  if [[ -d "Guest Profile" ]]; then
    printf "Clearing contents of directory: %s\n" "Guest Profile"
    find "Guest Profile" -mindepth 1 -delete
  fi

  popd >/dev/null || true
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
    [Brave-Browser-Stable]=".config/BraveSoftware/Brave-Browser"
    [Brave-Browser-Beta]=".config/BraveSoftware/Brave-Browser-Beta"
    [Brave-Browser-Development]=".config/BraveSoftware/Brave-Browser-Development"
  )

  # Map browser display names to actual process names for pgrep.
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
    [Brave-Browser-Stable]="brave" # Common process name for Brave variants
    [Brave-Browser-Beta]="brave"
    [Brave-Browser-Development]="brave"
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
      printf "\r[%s] Scanning for %s [${GRN}found${RST}]\n" "${YLW}$USER${RST}" "${GRN}$b_name${RST}"
      # Check if the browser process is running and prompt to kill if necessary.
      kill_browser "$p_name"

      profile_dirs=() # Reset array for each browser to store its profile paths.

      # Handle Firefox-like profiles, which use a profiles.ini file.
      if [[ "$b_name" =~ ^(Firefox|Icecat|Seamonkey|Aurora)$ ]]; then
        ini_file="$full_config_path/profiles.ini"
        if [[ -f "$ini_file" ]]; then
          while IFS= read -r line; do
            if [[ "$line" =~ ^Path=(.*)$ ]]; then
              profile_dirs+=("$full_config_path/${BASH_REMATCH[1]}")
            fi
          done < "$ini_file"
        fi
      else # Handle Chromium-like profile directories (e.g., "Default", "Profile 1").
        while IFS= read -r -d '' profiledir_found; do
          profile_dirs+=("$profiledir_found")
        done < <(find "$full_config_path" -maxdepth 1 -type d \( -iname "Default" -o -iname "Profile*" \) -print0)
      fi

      # Process each found profile directory (SQLite vacuum).
      if (( ${#profile_dirs[@]} > 0 )); then
        for profiledir in "${profile_dirs[@]}"; do
          if [[ -d "$profiledir" ]]; then
            printf "[%s]\n" "${YLW}${profiledir##*/}${RST}" # Print profile name (e.g., "Default", "Profile 1")
            pushd "$profiledir" >/dev/null || { log "ERROR: Could not change to profile directory: $profiledir"; continue; }
            run_cleaner # Call the core SQLite cleaning function.
            popd >/dev/null || { log "ERROR: Could not return from profile directory: $profiledir"; }
          fi
        done
      else
        printf "No profiles found for %s in %s.\n" "$b_name" "$full_config_path"
      fi

      # After SQLite vacuum, perform Brave-specific cache cleanup for Brave directories.
      if [[ "$b_name" =~ ^Brave-Browser.*$ ]]; then
        clean_brave_specific_caches "$full_config_path"
      fi

    else
      # Overwrite the "Scanning for..." line with "none" status if directory not found.
      printf "\r[%s] Scanning for %s [${RED}none${RST}]\n" "${YLW}$USER${RST}" "${GRN}$b_name${RST}"
      sleep 0.1 # Small delay for better visual flow.
    fi
  done

  printf "Browser vacuuming complete.\n"
}

# --- Additional Cleanup for other browsers ---
clean_other_caches() {
  printf "Removing other common browser caches...\n"
  # Clear Chromium's cache.
  # This clears the cache for Chromium (if installed), separate from Brave.
  if [[ -d "$HOME/.cache/chromium" ]]; then
    printf "Removing Chromium cache: %s\n" "$HOME/.cache/chromium"
    rm -rf -- "$HOME/.cache/chromium" || true
  else
    printf "Chromium cache directory not found: %s\n" "$HOME/.cache/chromium"
  fi
}


## Main Execution Block
main() {
  local ans # Declare local variable for user input.

  # Parse command-line arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d|--deep-clean)
        DEEP_CLEAN=1
        shift # past argument
        ;;
      -h|--help)
        usage
        ;;
      *)
        printf "Unknown option: %s\n" "$1" >&2
        usage
        ;;
    esac
  done

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
  # Perform other general cache cleanup.
  clean_other_caches

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
