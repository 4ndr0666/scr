#!/usr/bin/env bash
# Author: 4ndr0666
set -euo pipefail
# Removed IFS= as it's rarely needed globally and can lead to unexpected behavior.

# =========================== // BKUP.SH //
## Description: Universal backup and pruning tool using tar archives.
#               Supports configurable backup directory, compression, and retention.
## Usage:       sudo install -m755 bkup.sh /usr/local/bin/bkup.sh
# ----------------------------------------------------------------

## Global Constants
# Using XDG_CONFIG_HOME for configuration file location.
# Default values for configuration options.
declare -r BACKUP_DIR_DEFAULT="/Nas/Backups/bkup"
declare -r LOG_FILE_NAME_DEFAULT="bkup.log"
declare -r LOCK_FILE_DEFAULT="/tmp/bkup.lock" # Using /tmp for user-level script simplicity
declare -r KEEP_COPIES_DEFAULT="2"
declare -r TAR_COMPRESS_DEFAULT="zstd"
declare -r TAR_OPTS_DEFAULT=""
declare -r CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/bkup.json"

## Global Variables (will be loaded from config or defaults)
# These variables are declared globally as they define the script's operational parameters.
declare BACKUP_DIR
declare LOG_FILE
declare LOCK_FILE
declare KEEP_COPIES
declare TAR_COMPRESS
declare TAR_OPTS
declare -a SOURCES # Array to hold backup source paths

# Define common compression flags and suffixes for tar using associative arrays.
# This makes the compression logic cleaner and more extensible.
declare -A TAR_COMPRESSION_MAP=(
    [gzip]="-z" [gz]="-z"
    [bzip2]="-j" [bz2]="-j"
    [xz]="-J"
    [zstd]="--zstd" [zst]="--zstd"
    [none]=""
)
declare -A TAR_SUFFIX_MAP=(
    [gzip]=".tar.gz" [gz]=".tar.gz"
    [bzip2]=".tar.bz2" [bz2]=".tar.bz2"
    [xz]=".tar.xz"
    [zstd]=".tar.zst" [zst]=".tar.zst"
    [none]=".tar"
)

## Logging functions
# log: Writes messages to the designated log file.
# Corrected redirection from > /dev/null 2>&1 to >> "$LOG_FILE" to actually write to the log file.
# Added a fallback to stderr if LOG_FILE is not yet set (e.g., during early initialization errors).
log() {
    local level="$1"
    local message="$2"
    if [[ -n "${LOG_FILE:-}" ]]; then # Check if LOG_FILE is set and not empty
        printf '%s [%5s] %s\n' "$(date -u '+%F %T')" "$level" "$message" >> "$LOG_FILE" 2>&1
    else
        # Fallback to stderr if LOG_FILE isn't ready
        printf '%s [%5s] %s\n' "$(date -u '+%F %T')" "$level" "$message" >&2
    fi
}

# err: Prints error messages to stderr and logs them.
err() {
    local message="$1"
    log ERROR "$message"
    echo "ERROR: $message" >&2
}

# info: Prints informational messages to stderr and logs them.
info() {
    local message="$1"
    log INFO "$message"
    echo "INFO: $message" >&2
}

## Dependency check
# check_dependencies: Ensures all required external commands are available in PATH.
check_dependencies() {
    local deps=(tar jq find sort flock basename dirname)
    # zstd is checked conditionally within archive_one if it's the chosen compression.
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            err "Dependency '$cmd' is not installed or not in PATH. Please install it."
            return 1
        fi
    done
    return 0
}

## Directory management
# ensure_dirs: Checks if directories exist and are writable, creating them if necessary.
ensure_dirs() {
    local dir
    for dir in "$@"; do
        if [[ ! -d "$dir" ]]; then
            if ! mkdir -p "$dir"; then
                err "Failed to create directory: '$dir'"
                return 1
            fi
            info "Created directory: '$dir'"
        fi
        if [[ ! -w "$dir" ]]; then
            err "Directory not writable: '$dir'"
            return 1
        fi
    done
    return 0
}

## Log File setup
# setup_logfile: Prepares the log file, ensuring its parent directory exists and it's writable.
setup_logfile() {
    # Ensure the parent directory of the log file exists and is writable.
    if ! ensure_dirs "$(dirname "$LOG_FILE")"; then
        err "Failed to prepare log directory for '$LOG_FILE'."
        return 1
    fi
    # Touch the log file to create it if it doesn't exist.
    if ! touch "$LOG_FILE"; then
        err "Cannot create or write to log file: '$LOG_FILE'"
        return 1
    fi
    # Ensure the log file is writable (redundant after touch if dir is writable, but safe).
    if [[ ! -w "$LOG_FILE" ]]; then
        err "Log file not writable: '$LOG_FILE'"
        return 1
    fi
    return 0
}

## Configuration management
# write_config: Creates a default configuration file if one doesn't exist.
write_config() {
    local out_file="$CONFIG_FILE"
    local default_source="$HOME/.config/BraveSoftware" # Example default source

    if ! ensure_dirs "$(dirname "$out_file")"; then
        err "Failed to prepare config directory for '$out_file'."
        return 1
    fi

    # Use printf for robust JSON generation, ensuring correct quoting and formatting.
    {
        echo '{'
        printf '  "backup_directory": "%s",\n' "${BACKUP_DIR_DEFAULT}"
        printf '  "keep_copies": %s,\n' "${KEEP_COPIES_DEFAULT}"
        printf '  "compression": "%s",\n' "${TAR_COMPRESS_DEFAULT}"
        printf '  "tar_opts": "%s",\n' "${TAR_OPTS_DEFAULT}"
        echo '  "sources": ['
        printf '    "%s"\n' "${default_source}" # Only one default source for initial config
        echo '  ]'
        echo '}'
    } >"$out_file" || { err "Failed to write config file: '$out_file'"; return 1; }

    chmod 600 "$out_file" || { err "Failed to set permissions on '$out_file'."; return 1; }
    info "Created default config: '$out_file'"
    return 0
}

# interactive_setup: Guides the user through creating or updating the configuration file.
interactive_setup() {
    local bd kc cmp opts
    local -a srcs=()
    local p

    echo "=== bkup.sh :: Initial Configuration ==="

    read -rp "Backup output directory [$BACKUP_DIR_DEFAULT]: " bd
    bd="${bd:-$BACKUP_DIR_DEFAULT}"

    read -rp "How many archive copies to keep per source? [$KEEP_COPIES_DEFAULT]: " kc
    kc="${kc:-$KEEP_COPIES_DEFAULT}"

    # Basic validation for keep_copies: must be a non-negative integer.
    if ! [[ "$kc" =~ ^[0-9]+$ ]]; then
        err "Invalid number for keep_copies: '$kc'. Using default: $KEEP_COPIES_DEFAULT"
        kc="$KEEP_COPIES_DEFAULT"
    elif ((kc < 0)); then
        err "keep_copies cannot be negative: '$kc'. Using default: $KEEP_COPIES_DEFAULT"
        kc="$KEEP_COPIES_DEFAULT"
    fi

    read -rp "Compression (gzip|bzip2|xz|zstd|none) [$TAR_COMPRESS_DEFAULT]: " cmp
    cmp="${cmp:-$TAR_COMPRESS_DEFAULT}"
    cmp="${cmp,,}" # Convert to lowercase for case-insensitive comparison

    # Validate chosen compression method against the predefined map.
    if [[ ! -v TAR_COMPRESSION_MAP["$cmp"] ]]; then
        err "Unsupported compression method: '$cmp'. Using default: $TAR_COMPRESS_DEFAULT"
        cmp="$TAR_COMPRESS_DEFAULT"
    fi

    read -rp "Extra tar options (e.g., --exclude=PATTERN, leave blank for default): " opts
    opts="${opts:-$TAR_OPTS_DEFAULT}"

    echo "Enter absolute paths to back up (one per line, blank to finish):"
    while :; do
        read -rp "> " p
        [[ -z "$p" ]] && break # Exit loop if input is empty
        if [[ ! -e "$p" ]]; then
            echo "Warning: Path '$p' does not exist. Add anyway? (y/n)"
            read -rp "[y/n]: " add_anyway
            [[ "${add_anyway,,}" != "y" ]] && continue
        fi
        srcs+=("$p") # Add path to array
    done

    if ((${#srcs[@]} == 0)); then
        info "No sources entered. Adding default source: $HOME/.config/BraveSoftware"
        srcs+=("$HOME/.config/BraveSoftware")
    fi

    if ! ensure_dirs "$(dirname "$CONFIG_FILE")"; then
        err "Failed to prepare config directory for '$CONFIG_FILE'."
        return 1
    fi

    # Generate JSON with proper quoting and array formatting.
    {
        echo '{'
        printf '  "backup_directory": "%s",\n' "${bd}"
        printf '  "keep_copies": %s,\n' "${kc}"
        printf '  "compression": "%s",\n' "${cmp}"
        printf '  "tar_opts": "%s",\n' "${opts}"
        echo '  "sources": ['
        local i
        for ((i = 0; i < ${#srcs[@]}; i++)); do
            printf '    "%s"%s\n' "${srcs[i]}" "$([[ $((i + 1)) -lt ${#srcs[@]} ]] && echo "," || echo "")"
        done
        echo '  ]'
        echo '}'
    } >"$CONFIG_FILE" || { err "Failed to write config file: '$CONFIG_FILE'"; return 1; }

    chmod 600 "$CONFIG_FILE" || { err "Failed to set permissions on '$CONFIG_FILE'."; return 1; }
    info "Wrote configuration to '$CONFIG_FILE'"
    return 0
}

# load_config: Reads configuration from the JSON file into global variables.
# Includes robust error handling for missing file, unreadable file, and jq parsing failures.
load_config() {
    local config_content
    # Check if config file exists and is readable.
    if [[ ! -f "$CONFIG_FILE" ]]; then
        err "Config file not found: '$CONFIG_FILE'. Using default values."
        # Set all global variables to their defaults if config file is missing.
        BACKUP_DIR="$BACKUP_DIR_DEFAULT"
        KEEP_COPIES="$KEEP_COPIES_DEFAULT"
        TAR_COMPRESS="$TAR_COMPRESS_DEFAULT"
        TAR_OPTS="$TAR_OPTS_DEFAULT"
        SOURCES=("$HOME/.config/BraveSoftware")
        return 1 # Indicate that config loading failed
    fi

    # Attempt to read config file content.
    if ! config_content=$(cat "$CONFIG_FILE"); then
        err "Could not read config file: '$CONFIG_FILE'. Using defaults."
        BACKUP_DIR="$BACKUP_DIR_DEFAULT"
        KEEP_COPIES="$KEEP_COPIES_DEFAULT"
        TAR_COMPRESS="$TAR_COMPRESS_DEFAULT"
        TAR_OPTS="$TAR_OPTS_DEFAULT"
        SOURCES=("$HOME/.config/BraveSoftware")
        return 1
    fi

    # Use `jq -e` to ensure non-zero exit if a key is not found, then use `//` for fallback.
    # Each `jq` call is wrapped with `|| echo "..."` to provide a default if `jq` fails or returns empty.
    BACKUP_DIR=$(jq -re '.backup_directory // ""' <<<"$config_content" || echo "$BACKUP_DIR_DEFAULT")
    KEEP_COPIES=$(jq -re '.keep_copies // ""' <<<"$config_content" || echo "$KEEP_COPIES_DEFAULT")
    TAR_COMPRESS=$(jq -re '.compression // ""' <<<"$config_content" || echo "$TAR_COMPRESS_DEFAULT")
    TAR_OPTS=$(jq -re '.tar_opts // ""' <<<"$config_content" || echo "$TAR_OPTS_DEFAULT")

    # Final validation and fallback for loaded values, in case jq returned empty string.
    [[ -z "$BACKUP_DIR" ]] && BACKUP_DIR="$BACKUP_DIR_DEFAULT"
    [[ -z "$KEEP_COPIES" ]] && KEEP_COPIES="$KEEP_COPIES_DEFAULT"
    [[ -z "$TAR_COMPRESS" ]] && TAR_COMPRESS="$TAR_COMPRESS_DEFAULT"
    [[ -z "$TAR_OPTS" ]] && TAR_OPTS="$TAR_OPTS_DEFAULT"

    # Validate `KEEP_COPIES` again after loading from config.
    if ! [[ "$KEEP_COPIES" =~ ^[0-9]+$ ]]; then
        err "Invalid keep_copies value in config: '$KEEP_COPIES'. Using default: $KEEP_COPIES_DEFAULT"
        KEEP_COPIES="$KEEP_COPIES_DEFAULT"
    elif ((KEEP_COPIES < 0)); then
        err "keep_copies cannot be negative in config: '$KEEP_COPIES'. Using default: $KEEP_COPIES_DEFAULT"
        KEEP_COPIES="$KEEP_COPIES_DEFAULT"
    fi

    # Validate `TAR_COMPRESS` again after loading from config.
    TAR_COMPRESS="${TAR_COMPRESS,,}" # Convert to lowercase
    if [[ ! -v TAR_COMPRESSION_MAP["$TAR_COMPRESS"] ]]; then
        err "Unsupported compression method in config: '$TAR_COMPRESS'. Using default: $TAR_COMPRESS_DEFAULT"
        TAR_COMPRESS="$TAR_COMPRESS_DEFAULT"
    fi

    # *** FIX ***
    # Load sources into array using a more robust method.
    # We attempt to read using jq and mapfile, but ignore their exit codes.
    # We then check if the resulting SOURCES array is empty and set a default if it is.
    # This prevents unbound variable errors regardless of jq failures or config contents.
    mapfile -t SOURCES < <(jq -re '.sources[]' <<<"$config_content") &>/dev/null || true
    if ((${#SOURCES[@]} == 0)); then
        err "Could not load sources from config or sources array is empty. Using default source."
        SOURCES=("$HOME/.config/BraveSoftware")
    fi

    info "Configuration loaded from '$CONFIG_FILE'"
    return 0
}

## Archiving function
# archive_one: Creates a tar archive of a single source path.
# Takes compression method and extra tar options as arguments to avoid global side effects.
archive_one() {
    local src="$1"
    local current_tar_compress="$2" # Compression method for this archive
    local current_tar_opts="$3"     # Extra tar options for this archive

    local base stamp archive_path tar_flag tar_suffix
    local -a tar_args=()
    local -a tar_opts_array=()
    local -a tar_flag_array=()

    if [[ ! -e "$src" ]]; then
        err "Missing source: '$src'"
        return 1
    fi

    base=$(basename "$src")
    stamp=$(date -u +%Y%m%dT%H%M%S) # UTC timestamp for consistency

    tar_flag="${TAR_COMPRESSION_MAP["$current_tar_compress"]}"
    tar_suffix="${TAR_SUFFIX_MAP["$current_tar_compress"]}"

    # Special handling for zstd if tar doesn't support --zstd directly (older tar versions).
    if [[ "$current_tar_compress" == "zstd" || "$current_tar_compress" == "zst" ]]; then
        if ! tar --help 2>&1 | grep -q -- '--zstd'; then
            if command -v zstd >/dev/null 2>&1; then
                # This flag has two words and must be handled as such
                tar_flag="-I zstd"
            else
                err "zstd command not found for compression. Falling back to no compression for archive of '$src'."
                tar_flag=""
                tar_suffix=".tar" # Update suffix for this specific archive
                current_tar_compress="none" # For logging purposes
            fi
        fi
    fi

    archive_path="$BACKUP_DIR/${base}-${stamp}${tar_suffix}"

    tar_args+=("-c")
    tar_args+=("-f" "$archive_path")

    # Split the tar_flag string into an array to handle cases like "-I zstd".
    # This prevents the shell from passing "-I zstd" as a single, invalid argument.
    if [[ -n "$tar_flag" ]]; then
        read -ra tar_flag_array <<<"$tar_flag"
        tar_args+=("${tar_flag_array[@]}")
    fi

    if [[ -n "$current_tar_opts" ]]; then
        # Use `read -ra` to split options string into an array, respecting spaces.
        # This allows multiple options like "--exclude=foo --exclude=bar".
        read -ra tar_opts_array <<<"$current_tar_opts"
        tar_args+=("${tar_opts_array[@]}")
    fi

    # Use -C to change directory before adding the item, ensuring correct path in archive.
    tar_args+=("-C" "$(dirname "$src")" "$(basename "$src")")
    log INFO "Archiving '$src' -> '$archive_path' (Compression: $current_tar_compress)"

    # Execute tar command, redirecting its stdout/stderr to the log file.
    if ! tar "${tar_args[@]}" >>"$LOG_FILE" 2>&1; then
        err "tar failed for '$src'. See log for details."
        if [[ -f "$archive_path" ]]; then
            rm -f "$archive_path" || err "Failed to remove incomplete archive: '$archive_path'"
            log INFO "Removed incomplete archive: '$archive_path'"
        fi
        return 1 # Indicate failure
    fi

    log INFO "Archive complete: '$archive_path'"
    return 0 # Indicate success
}

## Pruning function
# prune_archives: Removes oldest archives for a given source, keeping only KEEP_COPIES.
# Corrected the find pattern to match dynamic timestamp and compression suffixes.
prune_archives() {
    local src_path="$1" # Original source path (e.g., /home/user/Documents)
    local src_base=$(basename "$src_path") # Base name of the source (e.g., Documents)
    local -a files=() # Array to hold files found (format: timestamp path)
    local num_to_prune file_entry file_path

    # Use find to get files matching the pattern, print modification time and path, sort by time (oldest first).
    # Pattern: "${src_base}-*.tar*" matches "source-timestamp.tar.gz", "source-timestamp.tar.zst", etc.
    # `2>/dev/null` suppresses errors from find if no files are found.
    # `sort -n` ensures chronological order based on timestamp.
    # `mapfile -t` reads lines into the 'files' array.
    if ! find "$BACKUP_DIR" -maxdepth 1 -type f -name "${src_base}-*.tar*" -printf "%T@ %p\n" 2>/dev/null | sort -n | mapfile -t files; then
        # This block handles potential issues with find/sort/mapfile, though mapfile often returns 0 even if empty.
        # The primary check for "no files" should be on the array length.
        log INFO "No archives found for pruning pattern: '${src_base}-*.tar*' in '$BACKUP_DIR'"
        return 0 # No files to prune is not an error
    fi

    if ((${#files[@]} > KEEP_COPIES)); then
        num_to_prune=$((${#files[@]} - KEEP_COPIES))
        log INFO "Found ${#files[@]} archives for '${src_base}', keeping ${KEEP_COPIES}. Pruning ${num_to_prune} oldest."

        # Iterate through the oldest files to prune.
        for file_entry in "${files[@]:0:num_to_prune}"; do
            file_path="${file_entry#* }" # Extract path after the timestamp (e.g., "1678886400 /path/to/file" -> "/path/to/file")
            if [[ -f "$file_path" ]]; then # Double check it's a regular file before removing
                if rm -f "$file_path"; then
                    log INFO "Pruned old archive: '$file_path'"
                else
                    err "Failed to prune archive: '$file_path'"
                fi
            else
                log WARNING "File to prune not found or not a regular file: '$file_path'"
            fi
        done
    else
        log INFO "Found ${#files[@]} archives for '${src_base}', keeping ${KEEP_COPIES}. No pruning needed."
    fi
    return 0
}

## Help message
usage() {
    cat <<EOF
bkup.sh - Universal backup and pruning tool (single script, config-driven)

USAGE:
  bkup.sh [PATH ...]
    (Backs up all specified paths provided as command-line arguments)

  bkup.sh
    (Backs up all paths listed in the configuration file)

  bkup.sh --setup
    (Interactive configuration wizard, creates or overwrites \$CONFIG_FILE)

  bkup.sh --help
    (Show this message and exit)

  bkup.sh --show-config
    (Show the content of the configuration file, if it exists)

  bkup.sh --dry-run [PATH ...]
    (Process arguments and config but do not perform tar or rm actions)

Cron Example (run hourly):
  0 * * * * /path/to/bkup.sh

Config file: $CONFIG_FILE
Log file: Determined by config or default (${BACKUP_DIR_DEFAULT}/${LOG_FILE_NAME_DEFAULT})
Lock file: Determined by default ($LOCK_FILE_DEFAULT)
EOF
}

## Main execution logic
main() {
    local dryrun=false
    local arg

    # Check for core dependencies first, before any complex operations.
    if ! check_dependencies; then
        exit 1
    fi

    # Parse command-line arguments for special modes.
    case "${1:-}" in # "${1:-}" handles case where no arguments are passed.
        --help)
            usage
            exit 0
            ;;
        --setup | --config)
            if ! interactive_setup; then
                err "Interactive setup failed."
                exit 1
            fi
            exit 0
            ;;
        --show-config)
            if [[ -f "$CONFIG_FILE" ]]; then
                echo "--- Configuration File: $CONFIG_FILE ---"
                cat "$CONFIG_FILE"
                echo "----------------------------------------"
            else
                echo "Configuration file not found: '$CONFIG_FILE'"
                echo "Run 'bkup.sh --setup' to create one."
            fi
            exit 0
            ;;
        -n | --dry-run)
            dryrun=true
            info "Dry run mode enabled. No files will be archived or pruned."
            shift # Remove --dry-run from arguments
            ;;
    esac

    # If config file doesn't exist, create a default one.
    if [[ ! -f "$CONFIG_FILE" ]]; then
        info "Config file not found. Creating default config."
        if ! write_config; then
            err "Failed to create default config. Exiting."
            exit 1
        fi
    fi

    # Load configuration. This will set global variables like BACKUP_DIR, KEEP_COPIES, etc.
    # Errors during load_config will result in defaults being used, and a non-zero return.
    load_config

    # Set LOG_FILE and LOCK_FILE paths using loaded BACKUP_DIR.
    # LOG_FILE needs to be set before `setup_logfile` and before any `log` calls that go to file.
    LOG_FILE="${BACKUP_DIR}/${LOG_FILE_NAME_DEFAULT}"
    LOCK_FILE="${LOCK_FILE_DEFAULT}" # Lock file path is fixed to /tmp

    # Ensure backup directory and lock file directory exist and are writable.
    if ! ensure_dirs "$BACKUP_DIR" "$(dirname "$LOCK_FILE")"; then
        err "Required directories could not be set up. Exiting."
        exit 1
    fi

    # Set up the log file. This must happen after LOG_FILE is defined and its directory exists.
    if ! setup_logfile; then
        err "Log file could not be set up. Exiting."
        exit 1
    fi

    # Acquire lock to prevent concurrent runs.
    # File descriptor 200 is used for the lock.
    exec 200>"$LOCK_FILE"
    if ! flock -n 200; then
        info "Another run in progress (lock file '$LOCK_FILE' exists). Exiting gracefully."
        exit 0 # Exit gracefully if locked
    fi
    log INFO "Lock acquired: '$LOCK_FILE'"

    local -a to_backup=()
    if (($# > 0)); then
        # If command-line arguments are provided, use them as sources.
        to_backup=("$@")
        info "Using command-line arguments as sources: ${to_backup[*]}"
    else
        # Otherwise, use sources from the configuration file.
        to_backup=("${SOURCES[@]}")
        info "Using sources from config file: ${to_backup[*]}"
    fi

    if ((${#to_backup[@]} == 0)); then
        err "No paths to backup specified via command-line or config file."
        usage >&2 # Print usage to stderr
        exit 1
    fi

    log INFO "Backup run started. Targets: ${to_backup[*]}"
    local fails=0
    local src_path

    # Iterate through each source path and perform backup and pruning.
    for src_path in "${to_backup[@]}"; do
        if [[ ! -e "$src_path" ]]; then
            err "Source path does not exist, skipping: '$src_path'"
            ((fails++))
            continue # Skip to the next source
        fi

        if ! $dryrun; then
            # Pass TAR_COMPRESS and TAR_OPTS to archive_one to avoid global side effects.
            if ! archive_one "$src_path" "$TAR_COMPRESS" "$TAR_OPTS"; then
                ((fails++))
                continue # Skip pruning if archiving failed
            fi
        else
            info "Dry run: Would archive '$src_path'"
        fi

        if ! $dryrun; then
            # Pass the original source path to prune_archives for correct pattern matching.
            prune_archives "$src_path"
        else
            info "Dry run: Would prune archives for '$src_path'"
        fi
    done

    # Report final status and exit.
    if ((fails > 0)); then
        err "Backup run completed with $fails error(s)."
        log ERROR "Backup run completed with $fails error(s)."
        exit 1 # Exit with non-zero status on failure
    else
        log INFO "Backup run complete."
        info "Backup run complete."
        exit 0 # Exit with zero status on success
    fi
}

main "$@"
