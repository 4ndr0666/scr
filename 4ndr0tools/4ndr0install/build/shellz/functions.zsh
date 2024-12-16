# Utility Functions

# Backup Utility
bkup() {
    local operation mode file target_dir=() current_date
    current_date=$(date -u "+%Y%m%dT%H%M%SZ")
    local show_help=false copy=false move=false clean=false all=false verbose=false

    # Parse options using getopts
    while getopts "hcma:rv" opt; do
        case "${opt}" in
            h) show_help=true ;;
            c) copy=true ;;
            m) move=true ;;
            r) clean=true ;;
            a) all=true ;;
            v) verbose=true ;;
            *) show_help=true ;;
        esac
    done
    shift $((OPTIND -1))

    # Show help if -h option is present or if no arguments are provided
    if [ "$show_help" = true ] || [ $# -eq 0 ]; then
        cat <<'EOF'
bk [-hcmrv] FILE [FILE ...]
bk -r [-av] [FILE [FILE ...]]
Backup a file or folder in place and append the timestamp
Remove backups of a file or folder, or all backups in the current directory

Usage:
  -h    Display this help text
  -c    Create a copy backup using cp(1) (default)
  -m    Move the file/folder using mv(1)
  -r    Remove backups
  -a    Remove all (even hidden) backups
  -v    Verbose output

The -c, -r, and -m options are mutually exclusive. If specified simultaneously, the last one is used.

The return code is the sum of all cp/mv/rm return codes.
EOF
        return 0
    fi

    # Determine operation mode
    if [ "$clean" = true ]; then
        mode="clean"
    elif [ "$move" = true ]; then
        mode="move"
    elif [ "$copy" = true ]; then
        mode="copy"
    else
        mode="copy"  # default mode
    fi

    # Determine target directories/files
    if [ "$all" = true ]; then
        target_dir=(*)
    else
        target_dir=("$@")
    fi

    # Check for valid target
    if [ ${#target_dir[@]} -eq 0 ]; then
        echo "Error: No target file or directory specified."
        return 1
    fi

    # Execute based on mode
    case $mode in
        "clean")
            for file in "${target_dir[@]}"; do
                if [[ -e $file ]]; then
                    [ "$verbose" = true ] && echo "Removing backup for '$file'"
                    rm -rf "${file}_${current_date}"
                else
                    echo "Warning: Backup for '$file' not found."
                fi
            done
            ;;
        "move")
            for file in "${target_dir[@]}"; do
                if [[ -e $file ]]; then
                    local backup_file="${file}_${current_date}"
                    [ "$verbose" = true ] && echo "Moving '$file' to '$backup_file'"
                    mv "$file" "$backup_file" || { echo "Error: Failed to move '$file'"; return 1; }
                else
                    echo "Error: File '$file' not found."
                fi
            done
            ;;
        "copy")
            for file in "${target_dir[@]}"; do
                if [[ -e $file ]]; then
                    local backup_file="${file}_${current_date}"
                    if [[ -e $backup_file ]]; then
                        echo "Warning: Backup file '$backup_file' already exists, skipping."
                        continue
                    fi
                    [ "$verbose" = true ] && echo "Copying '$file' to '$backup_file'"
                    cp -a "$file" "$backup_file" || { echo "Error: Failed to copy '$file'"; return 1; }
                else
                    echo "Error: File '$file' not found."
                fi
            done
            ;;
    esac
}

# URL Shortener using CleanURI
turl() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: turl <URL> [URL ...]"
        return 1
    fi

    local url response shortUrl

    for url in "$@"; do
        if [[ ! "$url" =~ ^https?:// ]]; then
            echo "Invalid URL: $url"
            continue
        fi

        response=$(curl -sS --header "Content-Type: application/x-www-form-urlencoded" \
                        --request POST \
                        --data-urlencode "url=$url" \
                        "https://cleanuri.com/api/v1/shorten")

        shortUrl=$(echo "$response" | grep -Po '"result_url":"\K[^"]+')

        if [[ -n "$shortUrl" ]]; then
            echo "Original URL: $url"
            echo "Short URL: $shortUrl"
        else
            echo "Error: Failed to shorten URL: $url"
        fi
    done
}

# Clean Package List from Clipboard and Install
cleanlist() {
    local clipboard_cmd packages
    if command -v xclip &>/dev/null; then
        clipboard_cmd="xclip -o -selection clipboard"
    elif command -v wl-paste &>/dev/null; then
        clipboard_cmd="wl-paste"
    else
        echo "No suitable clipboard utility found. Please install xclip or wl-clipboard."
        return 1
    fi

    packages=$(eval "$clipboard_cmd" | tr ',' '\n' | sed -E 's/=.*//;s/^[[:space:]]+//;s/[[:space:]]+$//' | tr -s '\n' ' ')

    if [[ -z "$packages" ]]; then
        echo "No valid package names were found in clipboard."
        return 1
    fi

    echo "Cleaned package list: $packages"

    if command -v xclip &>/dev/null; then
        echo -n "$packages" | xclip -selection clipboard
    elif command -v wl-copy &>/dev/null; then
        echo -n "$packages" | wl-copy
    fi

    local log_file="$HOME/.local/share/cleanlist.log"
    mkdir -p "$(dirname "$log_file")"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $packages" >> "$log_file"
    echo "Cleaned package list logged to $log_file."

    local pkg_manager
    while true; do
        echo "Select the package manager to use:"
        select pkg_manager in paru yay pacman; do
            if [[ -n "$pkg_manager" ]]; then
                break
            else
                echo "Invalid selection. Please choose a valid package manager."
            fi
        done

        case $pkg_manager in
            paru|yay)
                $pkg_manager -S --needed $packages
                break
                ;;
            pacman)
                sudo pacman -S --needed $packages
                break
                ;;
            *)
                echo "Invalid selection. Please choose a valid package manager."
                ;;
        esac
    done
}

# Fix GPG Keyring for Pacman
fixgpgkey() {
    local gpg_conf="$HOME/.gnupg/gpg.conf"
    local keyring_entry="keyring /etc/pacman.d/gnupg/pubring.gpg"
    local backup_file="$gpg_conf.bak.$(date +%Y%m%d%H%M%S)"

    echo "Starting GPG keyring fix process..."

    if [[ -f "$gpg_conf" ]]; then
        cp "$gpg_conf" "$backup_file"
        echo "Backup of gpg.conf created at $backup_file."
    else
        echo "No existing gpg.conf found; creating a new one."
        touch "$gpg_conf"
    fi

    if ! grep -qF "$keyring_entry" "$gpg_conf"; then
        echo "$keyring_entry" >> "$gpg_conf"
        echo "Keyring entry added to $gpg_conf."
    else
        echo "Keyring entry already exists in $gpg_conf."
    fi

    echo "Populating the pacman keyring..."
    if sudo pacman-key --populate archlinux; then
        echo "Pacman keyring populated successfully."
    else
        echo "Error: Failed to populate pacman keyring." >&2
        return 1
    fi

    echo "GPG keyring fix process completed."
}

# List Most Recently Modified Files
whatsnew() {
    local num_files=${1:-10}
    echo "Listing the $num_files most recently modified files across the entire system:"

    if ! sudo -v &>/dev/null; then
        echo "Error: You do not have sudo privileges." >&2
        return 1
    fi

    local files
    files=$(sudo find / -type f -printf '%T@ %p\n' 2>/dev/null | sort -n -r | head -n "$num_files" | cut -d' ' -f2-)

    if [[ -z "$files" ]]; then
        echo "No recently modified files found."
    else
        echo "$files"
    fi
}

# Accessed Files in Last N Days
accessed() {
    local time_range=${1:-1}

    if [[ ! $time_range =~ ^[0-9]+$ ]]; then
        echo "Usage: accessed [time_range_in_days]"
        return 1
    fi

    echo "Listing files accessed in the last $time_range day(s):"
    sudo find / -type f -atime -"$time_range" -print0 2>/dev/null | xargs -0 ls -lah --time=atime
}

# Changed Files in Last N Days
changed() {
    local time_range=${1:-1}

    if [[ ! $time_range =~ ^[0-9]+$ ]]; then
        echo "Usage: changed [time_range_in_days]"
        return 1
    fi

    echo "Listing files changed in the last $time_range day(s):"
    sudo find / -type f -ctime -"$time_range" -print0 2>/dev/null | xargs -0 ls -lah --time=ctime
}

# Modified Files in Last N Days
modified() {
    local time_range=${1:-1}

    if [[ ! $time_range =~ ^[0-9]+$ ]]; then
        echo "Usage: modified [time_range_in_days]"
        return 1
    fi

    echo "Listing files modified in the last $time_range day(s):"
    sudo find / -type f -mtime -"$time_range" -print0 2>/dev/null | xargs -0 ls -lah --time=mtime
}

# Run Command in Background Forever
4ever() {
    if [[ -z "$1" ]]; then
        echo "Usage: 4ever <command> [arguments] [log_file]"
        return 1
    fi

    local command="$1"
    shift

    if ! command -v "$command" &>/dev/null; then
        echo "Error: Command '$command' not found. Not executed."
        return 1
    fi

    local log_file
    if [[ -f "${@: -1}" || "${@: -1}" == *.log ]]; then
        log_file="${@: -1}"
        set -- "${@:1:$(($#-1))}"
    else
        log_file="/dev/null"
    fi

    if [[ "$log_file" == "/dev/null" ]]; then
        log_file="/tmp/${command}_$(date +'%Y%m%d%H%M%S').log"
    fi

    nohup "$command" "$@" &> "$log_file" &
    local pid=$!
    echo "Command '$command $*' started in the background with PID $pid."
    echo "Output is being logged to $log_file."

    echo "$pid" > "/tmp/forever_${command}_${pid}.pid"
}

# Make Directory and Change into It
mkcd() {
    if (( $# != 1 )); then
        echo 'Usage: mkcd <new-directory>'
        return 1
    fi

    local dir="$1"

    if [[ -z "$dir" ]]; then
        echo "Error: Directory name cannot be empty."
        return 1
    fi

    if [[ ! -d "$dir" ]]; then
        if mkdir -p "$dir"; then
            echo "Directory '$dir' created."
        else
            echo "Error: Failed to create directory '$dir'."
            return 1
        fi
    else
        echo "Directory '$dir' already exists."
    fi

    if cd "$dir"; then
        echo "Switched to directory '$dir'."
    else
        echo "Error: Failed to switch to directory '$dir'."
        return 1
    fi
}

# Change to Temporary Directory
cdt() {
    local tmp_dir

    if tmp_dir=$(mktemp -d 2>/dev/null); then
        echo "Created and switching to temporary directory: $tmp_dir"
        cd "$tmp_dir" || { echo "Error: Failed to change to temporary directory."; return 1; }
    else
        echo "Error: Failed to create a temporary directory."
        return 1
    fi

    pwd
}

# Simple Notepad Function
notepad() {
    local file="$HOME/Documents/notes/.notes"
    mkdir -p "$(dirname "$file")"  # Ensure the directory exists
    [[ -f $file ]] || touch "$file"

    show_help() {
        cat <<'EOF'
Usage: notepad [option] [arguments]
Options:
  (no option)       Display all notes
  -c                Clear all notes
  -r [number]       Display the last 'number' notes (default 10)
  -f <YYYY-MM-DD>   Filter notes by specific date
  -h                Show this help message
  <note>            Add a new note with a timestamp
EOF
    }

    if (( $# )); then
        case "$1" in
            -c)
                > "$file"
                echo "All notes cleared."
                ;;
            -r)
                local recent_count=10
                if [[ -n "$2" && "$2" =~ ^[0-9]+$ ]]; then
                    recent_count="$2"
                else
                    echo "Invalid or missing argument for -r option. Defaulting to 10."
                fi
                tail -n "$recent_count" "$file"
                ;;
            -f)
                if [[ -z "$2" || ! "$2" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
                    echo "Usage: notepad -f <YYYY-MM-DD>"
                    return 1
                fi
                grep "\[$2" "$file" || echo "No notes found for $2."
                ;;
            -h)
                show_help
                ;;
            -*)
                echo "Invalid option: $1"
                show_help
                return 1
                ;;
            *)
                local timestamp
                timestamp=$(date "+%Y-%m-%d %H:%M:%S")
                printf "[%s] %s\n" "$timestamp" "$*" >> "$file"
                echo "Note added."
                ;;
        esac
    else
        cat "$file"
    fi
}

# URL Decoder
urldecode() {
    if [[ -z "$1" ]]; then
        echo "Usage: urldecode <encoded_string>"
        return 1
    fi

    echo "$1" | awk '{gsub(/%([0-9A-Fa-f]{2})/, "\\x\\1"); print}' | xargs -0 echo -e
}

# Upload File to Termbin
termbin() {
    if [[ -z "$1" ]]; then
        echo "Usage: termbin <file>"
        return 1
    fi

    if [[ ! -f "$1" ]]; then
        echo "Error: File not found: $1"
        return 1
    fi

    if ! command -v nc &>/dev/null; then
        echo "Error: 'nc' (netcat) is required but not installed."
        return 1
    fi

    local url
    url=$(nc termbin.com 9999 < "$1")

    if [[ $? -eq 0 && -n "$url" ]]; then
        echo "File uploaded successfully."
        echo "URL: $url"
    else
        echo "Error: Failed to upload file."
        return 1
    fi
}

# Extract Archives
xt() {
    if [[ -f "$1" ]]; then
        case "$1" in
            *.tar.lrz)
                local base_dir
                base_dir=$(basename "$1" .tar.lrz)
                lrztar -d "$1" && [[ -d "$base_dir" ]] && cd "$base_dir" || return 0
                ;;
            *.lrz)
                local base_dir
                base_dir=$(basename "$1" .lrz)
                lrunzip "$1" && [[ -d "$base_dir" ]] && cd "$base_dir" || return 0
                ;;
            *.tar.bz2)
                local base_dir
                base_dir=$(basename "$1" .tar.bz2)
                bsdtar xjf "$1" && [[ -d "$base_dir" ]] && cd "$base_dir" || return 0
                ;;
            *.bz2)
                local base_dir
                base_dir=$(basename "$1" .bz2)
                bunzip2 "$1" && [[ -d "$base_dir" ]] && cd "$base_dir" || return 0
                ;;
            *.tar.gz)
                local base_dir
                base_dir=$(basename "$1" .tar.gz)
                bsdtar xzf "$1" && [[ -d "$base_dir" ]] && cd "$base_dir" || return 0
                ;;
            *.gz)
                local base_dir
                base_dir=$(basename "$1" .gz)
                gunzip "$1" && [[ -d "$base_dir" ]] && cd "$base_dir" || return 0
                ;;
            *.ipk)
                local base_dir
                base_dir=$(basename "$1" .ipk)
                gunzip "$1" && [[ -d "$base_dir" ]] && cd "$base_dir" || return 0
                ;;
            *.tar.xz)
                local base_dir
                base_dir=$(basename "$1" .tar.xz)
                bsdtar Jxf "$1" && [[ -d "$base_dir" ]] && cd "$base_dir" || return 0
                ;;
            *.xz)
                local base_dir
                base_dir=$(basename "$1" .xz)
                xz -d "$1" && [[ -d "$base_dir" ]] && cd "$base_dir" || return 0
                ;;
            *.rar)
                local base_dir
                base_dir=$(basename "$1" .rar)
                unrar e "$1" && [[ -d "$base_dir" ]] && cd "$base_dir" || return 0
                ;;
            *.tar)
                local base_dir
                base_dir=$(basename "$1" .tar)
                bsdtar xf "$1" && [[ -d "$base_dir" ]] && cd "$base_dir" || return 0
                ;;
            *.tbz2)
                local base_dir
                base_dir=$(basename "$1" .tbz2)
                bsdtar xjf "$1" && [[ -d "$base_dir" ]] && cd "$base_dir" || return 0
                ;;
            *.tgz)
                local base_dir
                base_dir=$(basename "$1" .tgz)
                bsdtar xzf "$1" && [[ -d "$base_dir" ]] && cd "$base_dir" || return 0
                ;;
            *.zip)
                local base_dir
                base_dir=$(basename "$1" .zip)
                unzip -qq "$1" && [[ -d "$base_dir" ]] && cd "$base_dir" || return 0
                ;;
            *.Z)
                local base_dir
                base_dir=$(basename "$1" .Z)
                uncompress "$1" && [[ -d "$base_dir" ]] && cd "$base_dir" || return 0
                ;;
            *.7z)
                local base_dir
                base_dir=$(basename "$1" .7z)
                7z x "$1" && [[ -d "$base_dir" ]] && cd "$base_dir" || return 0
                ;;
            *.zst)
                local base_dir
                base_dir=$(basename "$1" .zst)
                zstd -d "$1" && return 0
                ;;
            *.deb)
                ar x "$1" && return 0
                ;;
            *.rpm)
                rpmextract.sh "$1" && return 0
                ;;
            *)
                echo "Error: Failed to extract '$1'..."
                return 1
                ;;
        esac
        return 0
    else
        echo "Error: '$1' is not a valid file!"
        return 1
    fi
}

# YT-DLP Download with Predefined Settings
declare -A YTDLP_COOKIES_MAP=(
    ["youtube.com"]="$HOME/.config/yt-dlp/youtube_cookies.txt"    # YouTube
    ["youtu.be"]="$HOME/.config/yt-dlp/youtube_cookies.txt"       # YouTube Short Links
    ["patreon.com"]="$HOME/.config/yt-dlp/patreon_cookies.txt"    # Patreon
    ["vimeo.com"]="$HOME/.config/yt-dlp/vimeo_cookies.txt"        # Vimeo
    # Add more mappings as needed
)

PREFERRED_FORMATS=("313" "308" "303" "302" "247" "244" "136" "137" "bestaudio" "best")

# Validate URL
validate_url() {
    local url="$1"
    if [[ "$url" =~ ^https?:// ]]; then
        return 0
    else
        return 1
    fi
}

# Get Cookies File Based on URL
get_cookies_file() {
    local url="$1"
    local domain
    domain=$(echo "$url" | awk -F/ '{print $3}' | sed 's/^www\.//; s/^m\.//')

    echo "${YTDLP_COOKIES_MAP[$domain]}"
}

# Select Best Available Format
select_best_format() {
    local url="$1"
    local cookies_file="$2"
    local format_id

    # Fetch JSON output of formats
    local formats_json
    formats_json=$(yt-dlp -j --cookies "$cookies_file" "$url" 2>/dev/null)

    if [[ -z "$formats_json" ]]; then
        echo "best"
        return
    fi

    # Iterate through preferred formats and select the first available one
    for fmt in "${PREFERRED_FORMATS[@]}"; do
        if echo "$formats_json" | jq -e --arg fmt "$fmt" '.formats[] | select(.format_id == $fmt)' > /dev/null; then
            format_id="$fmt"
            echo "$format_id"
            return
        fi
    done

    # If none of the preferred formats are found, fallback to best
    echo "best"
}

# Get Format Details
get_format_details() {
    local url="$1"
    local cookies_file="$2"
    local format_id="$3"

    # Fetch JSON output for the selected format
    local format_json
    format_json=$(yt-dlp -f "$format_id" -j --cookies "$cookies_file" "$url" 2>/dev/null)

    if [[ -z "$format_json" ]]; then
        echo "N/A"
        return
    fi

    # Extract desired format properties using jq
    echo "$format_json" | jq '{format_id, ext, resolution, fps, tbr, vcodec, acodec, filesize}'
}

# yt-dlp Download Function with Predefined Settings
ytdlc() {
    # Check for help flag
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        echo "Usage: ytdlc [options] <URL> [<URL> ...]"
        echo "Downloads videos using yt-dlp with predefined settings and site-specific cookies."
        echo ""
        echo "Options:"
        echo "  --help, -h          Show this help message and exit."
        echo "  --list-formats, -l  List available formats for the provided URL(s) without downloading."
        echo "  --output-dir, -o    Specify a custom output directory. Defaults to ~/Downloads."
        echo ""
        echo "Examples:"
        echo "  ytdlc https://www.youtube.com/watch?v=example_video"
        echo "  ytdlc --list-formats https://www.patreon.com/example_creator"
        echo "  ytdlc --output-dir ~/Videos https://www.vimeo.com/example_video"
        return 0
    fi

    # Initialize variables
    local list_formats=0
    local output_dir="$HOME/Downloads"  # Default output directory

    # Parse options
    while [[ "$1" == -* ]]; do
        case "$1" in
            --list-formats|-l)
                list_formats=1
                shift
                ;;
            --output-dir|-o)
                if [[ -n "$2" && ! "$2" =~ ^- ]]; then
                    output_dir="$2"
                    shift 2
                else
                    echo "Error: --output-dir requires a non-empty option argument."
                    echo "Usage: ytdlc [options] <URL> [<URL> ...]"
                    return 1
                fi
                ;;
            *)
                echo "Unknown option: $1"
                echo "Usage: ytdlc [options] <URL> [<URL> ...]"
                return 1
                ;;
        esac
    done

    # Ensure output directory exists
    if [[ ! -d "$output_dir" ]]; then
        mkdir -p "$output_dir" 2>/dev/null
        if [[ $? -ne 0 ]]; then
            echo "Error: Failed to create output directory '$output_dir'."
            return 1
        fi
    fi

    # Iterate over all provided URLs
    for url in "$@"; do
        echo "----------------------------------------"
        echo "Processing URL: $url"

        # Check if URL is provided
        if [[ -z "$url" ]]; then
            echo "Error: No URL provided."
            echo "Usage: ytdlc [options] <URL> [<URL> ...]"
            continue
        fi

        # Validate URL
        if ! validate_url "$url"; then
            echo "Error: Invalid URL format: $url"
            continue
        fi

        # Retrieve the corresponding cookie file using the helper function
        local cookies_file
        cookies_file=$(get_cookies_file "$url")

        if [[ -z "$cookies_file" ]]; then
            echo "Error: No cookie file configured for the domain in '$url'."
            echo "Please update the YTDLP_COOKIES_MAP associative array with the appropriate cookie file."
            continue
        fi

        # Check if the cookie file exists
        if [[ ! -f "$cookies_file" ]]; then
            echo "Error: Cookie file not found at '$cookies_file'."
            echo "Please ensure the cookie file exists."
            continue
        fi

        # Retrieve the current permissions of the cookie file
        local current_perms
        current_perms=$(stat -c "%a" "$cookies_file" 2>/dev/null)

        if [[ $? -ne 0 ]]; then
            echo "Error: Unable to retrieve permissions for '$cookies_file'."
            continue
        fi

        # Check if permissions are not set to 600
        if [[ "$current_perms" != "600" ]]; then
            echo "Setting permissions of '$cookies_file' to 600 for security."
            chmod 600 "$cookies_file"
            if [[ $? -ne 0 ]]; then
                echo "Error: Failed to set permissions on '$cookies_file'."
                continue
            else
                echo "Permissions set successfully."
            fi
        else
            echo "Permissions for '$cookies_file' are already set to 600."
        fi

        if [[ $list_formats -eq 1 ]]; then
            echo "Listing available formats for '$url':"
            yt-dlp --list-formats --cookies "$cookies_file" "$url"
            echo "----------------------------------------"
            continue
        fi

        # Select the preferred format
        local best_format
        best_format=$(select_best_format "$url" "$cookies_file")

        echo "Selected format ID: $best_format"

        # Fetch and display selected format details
        local format_details
        format_details=$(get_format_details "$url" "$cookies_file" "$best_format")
        echo "Selected format details:"
        echo "$format_details"
        echo ""

        # Execute yt-dlp with the selected format and configurable output directory
        yt-dlp \
            --add-metadata \
            --embed-metadata \
            --external-downloader aria2c \
            --external-downloader-args "-c -j 3 -x 3 -s 3 -k 1M" \
            -f "$best_format+bestaudio/best" \
            --merge-output-format webm \
            --no-playlist \
            --no-mtime \
            --cookies "$cookies_file" \
            --output "$output_dir/%(title)s.%(ext)s" \
            "$url"

        # Check if yt-dlp executed successfully
        if [[ $? -ne 0 ]]; then
            echo "Error: yt-dlp failed to download the video from '$url'."
        else
            echo "Download completed successfully for '$url'."
        fi

        echo "----------------------------------------"
    done
}

# List Available Formats for a URL
ytf() {
    # Check for help flag
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        echo "Usage: ytf <URL>"
        echo ""
        echo "Description:"
        echo "  Lists all available formats for a given video URL."
        echo ""
        echo "Parameters:"
        echo "  <URL>                    The URL of the video to list formats for."
        echo ""
        echo "Options:"
        echo "  --help                   Display this help message."
        echo ""
        echo "Examples:"
        echo "  ytf \"https://www.youtube.com/watch?v=example_video\""
        return 0
    fi

    local url="$1"

    if [[ -z "$url" ]]; then
        echo "Usage: ytf <URL>"
        return 1
    fi

    # Validate URL
    if ! validate_url "$url"; then
        echo "Error: Invalid URL format: $url"
        return 1
    fi

    # Retrieve the corresponding cookie file using the helper function
    local cookies_file
    cookies_file=$(get_cookies_file "$url")

    if [[ -z "$cookies_file" ]]; then
        echo "Error: No cookie file configured for the domain in '$url'."
        echo "Please update the YTDLP_COOKIES_MAP associative array with the appropriate cookie file."
        return 1
    fi

    # Check if the cookie file exists
    if [[ ! -f "$cookies_file" ]]; then
        echo "Error: Cookie file not found at '$cookies_file'."
        echo "Please ensure the cookie file exists."
        return 1
    fi

    # Retrieve the current permissions of the cookie file
    local current_perms
    current_perms=$(stat -c "%a" "$cookies_file" 2>/dev/null)

    if [[ $? -ne 0 ]]; then
        echo "Error: Unable to retrieve permissions for '$cookies_file'."
        return 1
    fi

    # Check if permissions are not set to 600
    if [[ "$current_perms" != "600" ]]; then
        echo "Setting permissions of '$cookies_file' to 600 for security."
        chmod 600 "$cookies_file"
        if [[ $? -ne 0 ]]; then
            echo "Error: Failed to set permissions on '$cookies_file'."
            return 1
        else
            echo "Permissions set successfully."
        fi
    else
        echo "Permissions for '$cookies_file' are already set to 600."
    fi

    # List available formats
    echo "Listing available formats for '$url':"
    yt-dlp --list-formats --cookies "$cookies_file" "$url"
    echo "----------------------------------------"
}
