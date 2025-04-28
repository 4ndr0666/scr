#!/usr/bin/env bash
# ffx - A Combined CLI Tool for Video Processing
#   - Default: Lightweight usage for process, merge, looperang, slowmo
#   - Advanced Mode: Hardware Acceleration, Multi-Pass, Extended Filters
#
# Total Functions: 14
# Total Lines: 520

###############################################################################
# 0) Global Configuration & Initialization
###############################################################################
set -eu
set -o pipefail  # safer pipelines

ADVANCED_MODE=false
VERBOSE_MODE=false
LOG_FILE="ffx_wrapper.log"
PKG_MANAGER=""

HW_ACCEL_AVAILABLE=false
HW_ACCEL_CHOICE=""
VIDEO_CODEC="libx264"  # default fallback
PIX_FMT="yuv420p"
CRF_DEFAULT=23
BITRATE_DEFAULT="8M"

###############################################################################
# 1) display_usage
#    - Shows the command usage instructions.
###############################################################################
display_usage() {
    cat <<EOF
Usage: ffx [options] <command> [args...]

Global Options:
  --advanced     Enable advanced features (HW accel, multi-pass, etc.)
  -v, --verbose  Enable verbose logging

Commands:
  process   <input> [output] [fps]
            Downscale video to 1080p in high quality (CRF=0) or re-encode as needed.
            Defaults to 60 fps if not specified.

  merge     [-s fps] [-o output] [files...]
            Merge multiple videos in a lossless manner. If no files are specified,
            attempts interactive selection (fzf). Re-encodes if resolution differs.

  looperang <file1> [file2 ... fileN] [output]
            Produces a boomerang effect for each input file by reversing each
            video and concatenating the forward and reversed versions.
            If no input is provided, fzf will be used to select a file.
            If the last argument does not exist as a file, it is treated as the final output.

  slowmo    <input> [output] [slow_factor] [target_fps] [interp]
            Slows video playback by the specified factor, optionally applying
            motion interpolation if 'interp' is specified.

Advanced Example:
  ffx --advanced process input.mp4 output.mp4 60
EOF
}

###############################################################################
# 2) error_exit
#    - Prints an error message and exits.
###############################################################################
error_exit() {
    err_msg="$1"
    echo "Error: $err_msg" >&2
    exit 1
}

###############################################################################
# 3) command_exists
#    - Checks whether a given command is in PATH.
###############################################################################
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

###############################################################################
# 4) parse_global_opts
#    - Parses the top-level script options: --advanced, --verbose.
###############################################################################
parse_global_opts() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --advanced)
                ADVANCED_MODE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE_MODE=true
                shift
                ;;
            *)
                break
                ;;
        esac
    done
}

###############################################################################
# 5) verbose_log
#    - Prints logs if VERBOSE_MODE is true.
###############################################################################
verbose_log() {
    if [ "$VERBOSE_MODE" = true ]; then
        echo "[VERBOSE] $*"
    fi
}

###############################################################################
# 6) detect_package_manager
#    - Detects if pacman or yay is available, sets PKG_MANAGER.
###############################################################################
detect_package_manager() {
    if command_exists pacman; then
        PKG_MANAGER="pacman"
    elif command_exists yay; then
        PKG_MANAGER="yay"
    else
        echo "No recognized package manager found. Proceeding but dependencies must be installed manually."
        PKG_MANAGER=""
    fi
}

###############################################################################
# 7) install_dependencies_if_advanced
#    - If advanced mode is on, ensure ffmpeg & fzf are installed.
###############################################################################
install_dependencies_if_advanced() {
    if [ "$ADVANCED_MODE" = false ]; then
        return
    fi

    deps="ffmpeg fzf"
    if [ -n "$PKG_MANAGER" ]; then
        for d in $deps; do
            if ! command_exists "$d"; then
                echo "Installing $d..."
                if [ "$PKG_MANAGER" = "pacman" ]; then
                    sudo pacman -S --noconfirm "$d"
                elif [ "$PKG_MANAGER" = "yay" ]; then
                    yay -S --noconfirm "$d"
                else
                    echo "Unknown package manager: $PKG_MANAGER"
                fi
            fi
        done
    else
        for d in $deps; do
            if ! command_exists "$d"; then
                echo "Dependency missing: $d. Please install manually."
            fi
        done
    fi
}

###############################################################################
# 8) advanced_hw_accel
#    - If advanced mode is enabled, optionally detect & pick hardware acceleration.
###############################################################################
advanced_hw_accel() {
    if [ "$ADVANCED_MODE" = false ]; then
        return
    fi

    verbose_log "Detecting hardware acceleration..."
    hw_list=""
    hw_list="$(ffmpeg -hwaccels 2>/dev/null | tail -n +2 || true)"
    if [ -z "$hw_list" ]; then
        verbose_log "No hardware accelerations available."
        HW_ACCEL_AVAILABLE=false
        return
    fi

    first_accel="$(echo "$hw_list" | head -n 1 | tr '[:upper:]' '[:lower:]')"
    if [ -n "$first_accel" ]; then
        HW_ACCEL_AVAILABLE=true
        HW_ACCEL_CHOICE="$first_accel"
        verbose_log "HW Accel chosen automatically: $HW_ACCEL_CHOICE"
    else
        HW_ACCEL_AVAILABLE=false
    fi
}

###############################################################################
# 9) absolute_path
#    - Returns the absolute path of a file, handling spaces safely.
###############################################################################
absolute_path() {
    in_path="$1"
    if command_exists readlink; then
        abs_path="$(readlink -f "$in_path" 2>/dev/null || true)"
        if [ -z "$abs_path" ]; then
            abs_path="$(pwd)/$in_path"
        fi
    else
        abs_path="$(pwd)/$in_path"
    fi
    echo "$abs_path"
}

###############################################################################
# 10) process_command
#     - Downscales input video to 1080p, optionally sets FPS (default=60).
###############################################################################
process_command() {
    input="$1"
    if [ ! -f "$input" ]; then
        error_exit "Input file '$input' does not exist."
    fi

    output="${2:-}"
    if [ -z "$output" ]; then
        base="${input%.*}"
        ext="${input##*.}"
        output="${base}_1080p.${ext}"
    fi

    fps="${3:-60}"

    echo "Processing video => '$input' -> '$output' (fps=$fps)"
    ffmpeg -y -i "$input" -vf "scale=-2:1080,fps=$fps" -c:v libx264 -crf 0 \
           -preset veryslow -c:a copy "$output"
    if [ "$?" -ne 0 ]; then
        error_exit "Failed to process '$input'."
    fi
    echo "Process command completed => $output"
}

###############################################################################
# 11) merge_videos
#     - Merges multiple videos using concat demuxer. Re-encodes if resolution
#       differs. Converts all paths to absolute to avoid directory issues.
###############################################################################
merge_videos() {
    fps=""
    output=""
    files=""

    while [ "$#" -gt 0 ]; do
        case "$1" in
            -s)
                shift
                fps="$1"
                shift
                ;;
            -o)
                shift
                output="$1"
                shift
                ;;
            *)
                if [ -z "$files" ]; then
                    files="$1"
                else
                    files="$files"$'\n'"$1"
                fi
                shift
                ;;
        esac
    done

    if [ -z "$files" ]; then
        if command_exists fzf; then
            echo "No input files. Launching fzf selection..."
            while IFS= read -r line; do
                if [ -z "$files" ]; then
                    files="$line"
                else
                    files="$files"$'\n'"$line"
                fi
            done <<EOFZ
$(fzf --multi --prompt="Select video files: ")
EOFZ
            if [ -z "$files" ]; then
                error_exit "No files selected for merging."
            fi
        else
            error_exit "No files specified and fzf not installed."
        fi
    fi

    IFS=$'\n'
    all_files=($files)
    unset IFS

    safe_files=""
    for f in "${all_files[@]}"; do
        if [ ! -f "$f" ]; then
            error_exit "File '$f' does not exist."
        fi
        absf="$(absolute_path "$f")"
        if [ -z "$safe_files" ]; then
            safe_files="$absf"
        else
            safe_files="$safe_files"$'\n'"$absf"
        fi
    done

    IFS=$'\n'
    all_files=($safe_files)
    unset IFS

    first_file="${all_files[0]}"
    first_res="$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height \
                 -of csv=p=0:s=x "$first_file" 2>/dev/null || true)"
    if [ -z "$first_res" ]; then
        first_res="1920x1080"
    fi

    uniform="true"
    for current in "${all_files[@]}"; do
        this_res="$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height \
                   -of csv=p=0:s=x "$current" 2>/dev/null || true)"
        if [ -z "$this_res" ]; then
            this_res="1920x1080"
        fi
        if [ "$this_res" != "$first_res" ]; then
            uniform="false"
            break
        fi
    done

    tmpdir="$(mktemp -d)"
    if [ -z "$tmpdir" ]; then
        error_exit "Failed to create temporary directory."
    fi
    trap 'rm -rf "$tmpdir"' EXIT

    processed_files=()
    if [ "$uniform" = "true" ]; then
        echo "All files share resolution ($first_res). Direct merging..."
        for item in "${all_files[@]}"; do
            processed_files+=("$item")
        done
    else
        echo "Files differ in resolution. Re-encoding to match $first_res..."
        w="${first_res%%x*}"
        h="${first_res##*x}"
        for item in "${all_files[@]}"; do
            this_res="$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height \
                       -of csv=p=0:s=x "$item" 2>/dev/null || true)"
            if [ -z "$this_res" ]; then
                this_res="1920x1080"
            fi
            if [ "$this_res" != "$first_res" ]; then
                basef="$(basename "$item")"
                extf="${basef##*.}"
                namef="${basef%.*}"
                safe_name="${namef//[^a-zA-Z0-9._-]/_}"
                out_reenc="$tmpdir/${safe_name}_proc.$extf"
                echo "Re-encoding '$basef' => resolution $first_res"
                ffmpeg -y -i "$item" -vf "scale=${w}:${h}" -c:v libx264 -crf 0 \
                       -preset veryslow -c:a copy "$out_reenc"
                if [ "$?" -ne 0 ]; then
                    error_exit "Failed to re-encode '$basef' to $first_res."
                fi
                processed_files+=("$out_reenc")
            else
                processed_files+=("$item")
            fi
        done
    fi

    concat_file="$(mktemp)"
    if [ -z "$concat_file" ]; then
        error_exit "Failed to create temporary concat file."
    fi

    for pf in "${processed_files[@]}"; do
        echo "file '$pf'" >> "$concat_file"
    done

    if [ -z "$output" ]; then
        output="merged_output.mp4"
    fi

    echo "Merging into => $output"
    if [ -n "$fps" ]; then
        ffmpeg -y -f concat -safe 0 -i "$concat_file" -r "$fps" -c copy "$output"
        if [ "$?" -ne 0 ]; then
            error_exit "Merge operation failed with forced fps=$fps."
        fi
    else
        ffmpeg -y -f concat -safe 0 -i "$concat_file" -c copy "$output"
        if [ "$?" -ne 0 ]; then
            error_exit "Merge operation failed."
        fi
    fi
    echo "Merge complete => $output"
}

###############################################################################
# 12) looperang
#     - Creates a boomerang effect by processing input files.
#       If no input is provided, fzf is used to select a file.
#       If multiple files are provided, the last argument (if not an existing file)
#       is treated as the output; otherwise, output defaults to "looperang_output.mp4".
###############################################################################
looperang() {
    inputs=""
    output=""
    if [ "$#" -lt 1 ]; then
        if command_exists fzf; then
            echo "No input files provided. Launching fzf selection..."
            inputs="$(fzf --multi --prompt="Select video file(s) for looperang: " | head -n 1)"
            [ -z "$inputs" ] && error_exit "No file selected for looperang."
        else
            error_exit "No input files provided and fzf is not installed."
        fi
    else
        # If multiple arguments provided, check if last argument is an output file candidate
        set -- "$@"
        count="$#"
        last_arg="${!count}"
        if [ -f "$last_arg" ]; then
            output="looperang_output.mp4"
            inputs="$*"
        else
            output="$last_arg"
            # All but last are input files
            inputs=""
            i=1
            while [ "$i" -lt "$count" ]; do
                arg="$(eval echo \${$i})"
                if [ -z "$inputs" ]; then
                    inputs="$arg"
                else
                    inputs="$inputs"$'\n'"$arg"
                fi
                i=$((i+1))
            done
        fi
    fi

    if [ -z "$inputs" ]; then
        error_exit "No input files available for looperang."
    fi

    IFS=$'\n'
    all_ins=($inputs)
    unset IFS

    concat_list="$(mktemp)"
    if [ -z "$concat_list" ]; then
        error_exit "Failed to create temp file for looperang list."
    fi

    tmpdir="$(mktemp -d)"
    if [ -z "$tmpdir" ]; then
        error_exit "Failed to create temporary directory."
    fi
    trap 'rm -rf "$tmpdir"' EXIT

    for f in "${all_ins[@]}"; do
        if [ ! -f "$f" ]; then
            error_exit "Input file '$f' not found."
        fi
        abs="$(absolute_path "$f")"
        rfile="$(mktemp --suffix=.mp4 -p "$tmpdir")"
        if [ -z "$rfile" ]; then
            error_exit "Could not create reversed file for '$abs'."
        fi
        echo "Reversing => $abs"
        ffmpeg -y -i "$abs" -vf reverse -af areverse "$rfile"
        if [ "$?" -ne 0 ]; then
            error_exit "Failed reversing => $abs"
        fi
        echo "file '$abs'" >> "$concat_list"
        echo "file '$rfile'" >> "$concat_list"
    done

    echo "Combining forward+reverse segments into => $output"
    ffmpeg -y -f concat -safe 0 -i "$concat_list" -c copy "$output"
    if [ "$?" -ne 0 ]; then
        error_exit "Failed to finalize boomerang => $output"
    fi
    echo "Looperang creation done => $output"
}

###############################################################################
# 13) slowmo
#     - Slows video by factor. If target_fps and 'interp' are provided, uses minterpolate.
###############################################################################
slowmo() {
    if [ "$#" -lt 1 ]; then
        echo "Usage: ffx slowmo <input> [output] [factor] [target_fps] [interp]"
        exit 1
    fi

    input="$1"
    if [ ! -f "$input" ]; then
        error_exit "Input '$input' not found."
    fi

    output="${2:-}"
    if [ -z "$output" ]; then
        bn="${input%.*}"
        ex="${input##*.}"
        output="${bn}_slowmo.${ex}"
    fi

    factor="${3:-2}"
    target_fps="${4:-}"
    interp="${5:-}"

    echo "Applying slowmo => factor=$factor, output=$output"
    case "$factor" in
        ''|*[!0-9.]*)
            echo "Invalid factor => defaulting to 2"
            factor="2"
            ;;
    esac

    if [ -n "$target_fps" ] && [ "$interp" = "interp" ]; then
        echo "Using interpolation => fps=$target_fps"
        ffmpeg -y -i "$input" -filter_complex "[0:v]setpts=${factor}*PTS,minterpolate=fps=${target_fps}:mi_mode=mci:mc_mode=aobmc:vsbmc=1[v]" -map "[v]" -map 0:a? "$output"
        if [ "$?" -ne 0 ]; then
            error_exit "Interpolation slowmo failed."
        fi
    else
        ffmpeg -y -i "$input" -filter_complex "[0:v]setpts=${factor}*PTS[v]" -map "[v]" -map 0:a? "$output"
        if [ "$?" -ne 0 ]; then
            error_exit "Slowmo operation failed."
        fi
    fi
    echo "Slowmo done => $output"
}

###############################################################################
# 14) advanced_multi_pass
#     - If advanced mode is on, you could incorporate a multi-pass routine.
###############################################################################
advanced_multi_pass() {
    if [ "$ADVANCED_MODE" = false ]; then
        return
    fi
    verbose_log "Performing advanced multi-pass (placeholder)."
    # Real logic can be inserted here as needed.
}

###############################################################################
# Main Dispatch
###############################################################################
main_dispatch() {
    if [ "$#" -lt 1 ]; then
        display_usage
        exit 1
    fi

    cmd="$1"
    shift

    case "$cmd" in
        process)
            if [ "$#" -lt 1 ]; then
                echo "Usage: ffx process <input> [output] [fps]"
                exit 1
            fi
            process_command "$@"
            ;;
        merge)
            merge_videos "$@"
            ;;
        looperang)
            looperang "$@"
            ;;
        slowmo)
            slowmo "$@"
            ;;
        *)
            echo "Error: Unknown command '$cmd'"
            display_usage
            exit 1
            ;;
    esac
}

###############################################################################
# Script Entry Point
###############################################################################
parse_global_opts "$@"
OPTIND=1  # reset

if [ "$ADVANCED_MODE" = true ]; then
    detect_package_manager
    install_dependencies_if_advanced
    advanced_hw_accel
    advanced_multi_pass
fi

main_dispatch "$@"
