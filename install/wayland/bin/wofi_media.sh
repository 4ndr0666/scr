#!/bin/bash
# shellcheck disable=all

# --- // PlayMedia: Standalone Script with Wofi Integration

# Configuration
CONFIG_FILE="$HOME/.playmedia.conf"
PLAYLIST_DIR="$HOME/.config/mpv/playlists"
LOG_FILE="$HOME/.playmedia.log"

# Default media directories (overridden by config file if present)
MEDIA_DIRS=("$HOME/Videos" "$HOME/Downloads" "/4ndr0" "/sto2" "/tardis" "/s3" "/storage")

# Dependency check
check_dependencies() {
    local missing=()
    for dep in wofi mpv notify-send socat; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done

    if [ ${#missing[@]} -ne 0 ]; then
        echo "Error: Missing dependencies: ${missing[*]}" >> "$LOG_FILE"
        notify-send "PlayMedia - Error" "Missing dependencies: ${missing[*]}"
        exit 1
    fi
}

# Centralized error handling
handle_error() {
    local message="$1"
    echo "Error: $message" >> "$LOG_FILE"
    notify-send "PlayMedia - Error" "$message"
}

# Sanitize input
sanitize_input() {
    local input="$1"
    if [[ "$input" =~ [\"\'\`] ]]; then
        handle_error "Input contains invalid characters: $input"
        return 1
    fi
    echo "$input"
}

# Load configuration
load_configuration() {
    if [ -f "$CONFIG_FILE" ]; then
        mapfile -t MEDIA_DIRS < "$CONFIG_FILE"
    else
        echo "Warning: Config file not found. Using default directories." >> "$LOG_FILE"
    fi
}

# Initialize or edit the configuration file
initialize_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        printf "%s\n" "$HOME/Videos" "$HOME/Downloads" > "$CONFIG_FILE"
        notify-send "PlayMedia" "Configuration file created at $CONFIG_FILE"
    fi

    if command -v micro &>/dev/null; then
        if ! micro "$CONFIG_FILE"; then
            handle_error "Failed to edit the config file with micro."
            return 1
        fi
    elif command -v nano &>/dev/null; then
        if ! nano "$CONFIG_FILE"; then
            handle_error "Failed to edit the config file with nano."
            return 1
        fi
    else
        handle_error "Neither nano nor micro editor is available. Edit the file manually: $CONFIG_FILE"
        return 1
    fi

    notify-send "PlayMedia" "Configuration file edited successfully. Changes will take effect."
    return 0
}

# Ensure the playlist directory exists
mkdir -p "$PLAYLIST_DIR"

# Display a wofi prompt
wofi_prompt() {
    local prompt_text="$1"
    local input=$(cat - | wofi --dmenu --prompt "$prompt_text" --width 500 --height 400 --lines 15 --columns 1)
    echo "$input"
}

# Validate directory existence
validate_directory() {
    local dir="$1"
    if [ -d "$dir" ]; then
        echo "$dir"
    else
        handle_error "Invalid directory: $dir"
        return 1
    fi
}

# Play selected media
play_media() {
    local media="$1"
    mpv "$media" &
    notify-send "PlayMedia" "Playing: $media"
}

# Queue media in mpv
queue_media() {
    local media="$1"
    local sockets_dir="/tmp/mpvSockets"

    if [ ! -d "$sockets_dir" ]; then
        handle_error "No active mpv instances found."
        return 1
    fi

    local mpv_sockets
    mpv_sockets=$(ls "$sockets_dir")

    if [ -z "$mpv_sockets" ]; then
        handle_error "No active mpv instances found."
        return 1
    fi

    local selected_socket
    selected_socket=$(echo "$mpv_sockets" | wofi_prompt "Select mpv instance to queue media:")

    if [ -n "$selected_socket" ]; then
        local socket_path="$sockets_dir/$selected_socket"
        echo "{\"command\": [\"loadfile\", \"$media\", \"append-play\"]}" | socat - "$socket_path"
        notify-send "PlayMedia" "Queued media in mpv instance: $selected_socket"
    else
        notify-send "PlayMedia" "No mpv instance selected."
    fi
}

# Generate or cache a playlist
generate_and_cache_playlist() {
    local dir="$1"
    local cache_file="$PLAYLIST_DIR/$(basename "$dir")_playlist.m3u"

    if [ ! -f "$cache_file" ] || [ "$dir" -nt "$cache_file" ]; then
        find "$dir" -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.m4v" -o -iname "*.webm" -o -iname "*.gif" \) >"$cache_file"
    fi

    if [ -s "$cache_file" ]; then
        play_playlist "$cache_file"
    else
        handle_error "No media files found in $dir."
        rm -f "$cache_file"
    fi
}

# Play a playlist
play_playlist() {
    local playlist="$1"
    if [ -f "$playlist" ] && [ -s "$playlist" ]; then
        local media_count=$(wc -l < "$playlist")
        notify-send "PlayMedia" "Playing playlist: $playlist ($media_count items)"
        mpv --shuffle --playlist="$playlist" --loop-playlist=inf --no-border --player-operation-mode=pseudo-gui --no-osc &
    else
        handle_error "The playlist file is empty or does not exist."
    fi
}

# Browse media
browse_media() {
    local dir="$1"
    while true; do
        local subdirs=$(find "$dir" -mindepth 1 -maxdepth 1 -type d | sort)
        if [ -n "$subdirs" ]; then
            local dir_choice=$(echo -e "$subdirs\nBack" | wofi_prompt "Select a subdirectory or go back:")

            if [ "$dir_choice" = "Back" ]; then
                return
            elif [ -d "$dir_choice" ]; then
                dir="$dir_choice"
            else
                handle_error "Invalid selection: $dir_choice"
            fi
        else
            local media_files=$(find "$dir" -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.m4v" -o -iname "*.webm" -o -iname "*.gif" \) | sort)

            if [ -z "$media_files" ]; then
                notify-send "PlayMedia - Info" "No media files found in $dir."
                return
            fi

            local selected_media=$(echo "$media_files" | wofi_prompt "Select a media file to play or queue:")
            if [ -n "$selected_media" ]; then
                local action=$(echo -e "Play Now\nQueue in mpv\nBack" | wofi_prompt "Choose an action:")

                case "$action" in
                "Play Now") play_media "$selected_media" ;;
                "Queue in mpv") queue_media "$selected_media" ;;
                "Back") ;;
                *) handle_error "Invalid action selected." ;;
                esac
            else
                notify-send "PlayMedia - Info" "No media file selected."
            fi
            break
        fi
    done
}

# Main menu loop
load_configuration
check_dependencies

while true; do
    main_menu_options=$(printf "%s\n" "${MEDIA_DIRS[@]}" "Type a directory..." "Edit Config" "Exit")
    
    dir_choice=$(echo "$main_menu_options" | wofi --dmenu --prompt "Select a media directory or option:" --width 500 --height 400 --lines 15 --columns 1)

    case "$dir_choice" in
    "Exit")
        exit 0
        ;;
    "Edit Config")
        initialize_config
        if [ $? -eq 0 ]; then
            load_configuration  # Reload the updated config
        fi
        continue
        ;;
    "Type a directory...")
        typed_dir=$(wofi --dmenu --prompt "Enter a directory path:" --width 500 --height 400 --lines 15 --columns 1)
        dir_choice=$(validate_directory "$typed_dir") || continue
        ;;
    *)
        dir_choice=$(validate_directory "$dir_choice") || continue
        ;;
    esac

    mode_choice=$(echo -e "Playlist Mode\nBrowse Mode\nExit" | wofi_prompt "Select a mode:")
    case "$mode_choice" in
    "Playlist Mode")
        generate_and_cache_playlist "$dir_choice"
        ;;
    "Browse Mode")
        browse_media "$dir_choice"
        ;;
    "Exit")
        exit 0
        ;;
    *)
        handle_error "Invalid mode selected."
        ;;
    esac
done
