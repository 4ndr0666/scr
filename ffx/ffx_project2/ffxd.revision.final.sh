#!/usr/bin/env bash
#shellcheck disable=SC2207,SC2034,SC2046,SC2004,SC1009,SC1073,SC1078,SC1079,SC1036,SC1050,SC2317
# Author: 4ndr0666 — Production Revision: ffx4.compare vFinal
set -euo pipefail
IFS=$'\n\t'

# ========================== // XDG Compliant Globals // ==========================
: "${XDG_CONFIG_HOME:="$HOME/.config"}"
: "${XDG_CACHE_HOME:="$HOME/.cache"}"
: "${XDG_RUNTIME_DIR:="${TMPDIR:-/tmp}"}"

export FFX4_CONFIG_DIR="$XDG_CONFIG_HOME/ffx4"
export FFX4_CACHE_DIR="$XDG_CACHE_HOME/ffx4"
export FFX4_RUNTIME_DIR="$XDG_RUNTIME_DIR/ffx4"

mkdir -p "$FFX4_CONFIG_DIR" "$FFX4_CACHE_DIR" "$FFX4_RUNTIME_DIR"

# ========================== // Configuration Defaults // ==========================
default_config() {
	ADVANCED_MODE=false
	VERBOSE_MODE=false
	BULK_MODE=false
	REMOVE_AUDIO=false
	CLEAN_META_DEFAULT=true
	COMPOSITE_MODE=false
	MAX_1080=false
	INTERPOLATE=false
	OUTPUT_DIR="$(pwd)"
	SPECIFIC_FPS=""
	PTS_FACTOR=""
	ADV_CONTAINER="mp4"
	ADV_RES="1920x1080"
	ADV_FPS="60"
	ADV_CODEC="libx264"
	ADV_PIX_FMT="yuv420p"
	ADV_CRF="18"
	ADV_BR="10M"
	ADV_MULTIPASS="false"
}
default_config

# ========================== // Command-Line Parser // ==========================
REMAINING_ARGS=()

parse_global_options() {
	while [ $# -gt 0 ]; do
		case "$1" in
		-A | --advanced) ADVANCED_MODE=true ;;
		-v | --verbose) VERBOSE_MODE=true ;;
		-b | --bulk) BULK_MODE=true ;;
		-an) REMOVE_AUDIO=true ;;
		-C | --composite) COMPOSITE_MODE=true ;;
		-P | --max-1080) MAX_1080=true ;;
		-f | --fps)
			SPECIFIC_FPS="$2"
			shift
			;;
		-p | --pts)
			PTS_FACTOR="$2"
			shift
			;;
		-i | --interpolate) INTERPOLATE=true ;;
		-o | --output-dir)
			OUTPUT_DIR="$2"
			shift
			;;
		--container)
			ADV_CONTAINER="$2"
			shift
			;;
		--resolution)
			ADV_RES="$2"
			shift
			;;
		--codec)
			ADV_CODEC="$2"
			shift
			;;
		*) REMAINING_ARGS+=("$1") ;;
		esac
		shift
	done
}

# ========================== // Logging & Traps // ==========================
TEMP_FILES=()
TEMP_DIRS=()

register_temp_file() { TEMP_FILES+=("$1"); }
register_temp_dir() { TEMP_DIRS+=("$1"); }

cleanup_all() {
	for f in "${TEMP_FILES[@]}"; do [ -f "$f" ] && rm -f "$f"; done
	for d in "${TEMP_DIRS[@]}"; do [ -d "$d" ] && rm -rf "$d"; done
}
trap 'cleanup_all; exit' INT TERM HUP EXIT

error_exit() {
	echo "❌ Error: $*" >&2
	exit 1
}
verbose_log() { [ "$VERBOSE_MODE" = true ] && echo "[VERBOSE] $*"; }

# ========================== // Command Existence // ==========================
command_exists() { command -v "$1" >/dev/null 2>&1; }
absolute_path() {
	local in_path

	in_path="$1"
	command_exists readlink && readlink -f "$in_path" 2>/dev/null || echo "$(cd "$(dirname "$in_path")" && pwd)/$(basename "$in_path")"
}

# ======================== // Get Default Filename // ============================
get_default_filename() {
	local base

	base="${1:-out}"
	local suffix

	suffix="${2:-tmp}"
	local ext

	ext="${3:-mp4}"
	local candidate

	candidate="${base}_${suffix}.${ext}"
	local counter

	counter=1
	while [ -e "$candidate" ]; do
		candidate="${base}_${suffix}_${counter}.${ext}"
		counter=$((counter + 1))
	done
	echo "$candidate"
}

# ========================== // Audio Option Builder // ==========================
get_audio_opts_arr() {
	if [ "$REMOVE_AUDIO" = true ]; then
		echo "-an"
	else
		echo "-c:a aac -b:a 128k"
	fi
}

# ========================== // Byte Formatter // ==========================
bytes_to_human() {
	local bytes

	bytes="${1:-0}"
	if [ "$bytes" -lt 1024 ]; then
		echo "${bytes} B"
	elif [ "$bytes" -lt 1048576 ]; then
		printf "%.2f KiB" "$(bc -l <<<"${bytes}/1024")"
	elif [ "$bytes" -lt 1073741824 ]; then
		printf "%.2f MiB" "$(bc -l <<<"${bytes}/1048576")"
	else
		printf "%.2f GiB" "$(bc -l <<<"${bytes}/1073741824")"
	fi
}

# ========================== // DTS & Timestamp Validation // ==========================
check_dts_for_file() {
	local file

	file="$1" prev="" problem=0
	while IFS= read -r line; do
		if ! [[ "$line" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then continue; fi
		if [ -n "$prev" ] && [ "$(bc -l <<<"$line < $prev")" -eq 1 ]; then
			echo "❌ Non-monotonic DTS in '$file' (prev: $prev, curr: $line)" >&2
			problem=1
			break
		fi
		prev="$line"
	done < <(ffprobe -v error -select_streams v -show_entries frame=pkt_dts_time -of csv=p=0 "$file" 2>/dev/null)
	return $problem
}

fix_dts() {
	local file

	file="$1" tmpf
	tmpf="$(mktemp --suffix=.mp4)"
	register_temp_file "$tmpf"

	local audio_opts
	audio_opts=($(get_audio_opts_arr))

	if ! ffmpeg -y -fflags +genpts -i "$file" -c:v copy "${audio_opts[@]}" -movflags +faststart "$tmpf"; then
		# Fallback to re-encode
		ffmpeg -y -fflags +genpts -i "$file" -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset medium "${audio_opts[@]}" "$tmpf" || {
			echo "❌ fix_dts: Fallback re-encode failed." >&2
			rm -f "$tmpf"
			return 1
		}
	fi
	echo "$tmpf"
}

ensure_dts_correct() {
	local file

	file="$1"
	[ ! -f "$file" ] && error_exit "DTS fix: '$file' not found"
	if ! check_dts_for_file "$file"; then
		verbose_log "⏱ DTS issues found in '$file'; applying fix..."
		local fixed
		fixed="$(fix_dts "$file")" || return 1
		echo "$fixed"
	else
		echo "$file"
	fi
}

# ========================== // Moov Atom Handling // ==========================
check_moov_atom() {
	local file

	file="$1"
	ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file" >/dev/null 2>&1
}

moov_fallback() {
	local in_file

	in_file="$1" out_file="$2"
	local audio_opts
	audio_opts=($(get_audio_opts_arr))

	verbose_log "⚙️ moov_fallback: Re-encoding for faststart."
	ffmpeg -y -i "$in_file" -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset medium "${audio_opts[@]}" -movflags +faststart "$out_file" || {
		error_exit "❌ moov_fallback: Failed to re-encode $in_file"
	}
}

# ========================== // Advanced Prompting // ==========================
advanced_prompt() {
	if [ "$ADVANCED_MODE" = true ]; then
		echo "⚙️ Advanced Mode: Configure output encoding options."
		read -rp "Container extension [mp4/mkv/mov] (default: mp4): " val
		[ -n "$val" ] && ADV_CONTAINER="$val"

		read -rp "Resolution (e.g., 1920x1080, default: 1920x1080): " val
		[ -n "$val" ] && ADV_RES="$val"

		read -rp "Frame rate [24/30/60] (default: 60): " val
		[ -n "$val" ] && ADV_FPS="$val"

		read -rp "Codec [1=libx264, 2=libx265] (default: 1): " val
		[ "$val" = "2" ] && ADV_CODEC="libx265"

		read -rp "Pixel format [1=yuv420p, 2=yuv422p] (default: 1): " val
		[ "$val" = "2" ] && ADV_PIX_FMT="yuv422p"

		read -rp "CRF value (default: 18): " val
		[ -n "$val" ] && ADV_CRF="$val"

		read -rp "Bitrate (e.g., 10M, default: 10M): " val
		[ -n "$val" ] && ADV_BR="$val"

		read -rp "Enable multipass? (y/N): " val
		val="$(echo "$val" | tr '[:upper:]' '[:lower:]')"
		[ "$val" = "y" ] || [ "$val" = "yes" ] && ADV_MULTIPASS=true

		echo "🔧 Config => Container=$ADV_CONTAINER, Res=$ADV_RES, FPS=$ADV_FPS, Codec=$ADV_CODEC, PixFmt=$ADV_PIX_FMT, CRF=$ADV_CRF, BR=$ADV_BR, Multi=$ADV_MULTIPASS"
	fi
}

# ========================== // Probe Subcommand // ==========================
cmd_probe() {
	advanced_prompt
	local input

	input="${1:-}"
	if [ -z "$input" ] && command_exists fzf; then
		input="$(fzf)"
	fi
	[ -z "$input" ] && error_exit "No input provided."
	[ ! -f "$input" ] && error_exit "File not found: $input"

	local sz hsz fps dur res container
	sz="$(stat -c '%s' "$input" 2>/dev/null || echo 0)"
	hsz="$(bytes_to_human "$sz")"

	res="$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$input")"
	fps="$(ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of default=nokey=1:noprint_wrappers=1 "$input")"
	dur="$(ffprobe -v error -show_entries format=duration -of default=nokey=1:noprint_wrappers=1 "$input")"
	container="$(ffprobe -v error -show_entries format=format_name -of default=noprint_wrappers=1:nokey=1 "$input" | head -n1)"

	local cyan

	cyan="\033[36m"
	local reset

	reset="\033[0m"
	echo -e "${cyan}# === PROBE REPORT ===${reset}"
	echo -e "${cyan}File:${reset}        $input"
	echo -e "${cyan}Container:${reset}   $container"
	echo -e "${cyan}Size:${reset}        $hsz"
	echo -e "${cyan}Resolution:${reset}  $res"
	echo -e "${cyan}Frame Rate:${reset}  $fps"
	echo -e "${cyan}Duration:${reset}    ${dur}s"

	if [[ "$fps" =~ ^([0-9]+)/([0-9]+)$ ]]; then
		local num

		num="${BASH_REMATCH[1]}"
		local den

		den="${BASH_REMATCH[2]}"
		if [ "$den" -ne 0 ]; then
			local rate
			rate="$(bc -l <<<"$num / $den")"
			printf "${cyan}Parsed FPS:${reset} %.2f\n" "$rate"
		fi
	fi

	if [[ "$res" =~ x ]]; then
		local height

		height="${res##*x}"
		if [[ "$height" =~ ^[0-9]+$ ]] && [ "$height" -gt 1080 ]; then
			read -rp "🔺 Detected >1080p. Downscale? (y/N): " yn
			yn="$(echo "$yn" | tr '[:upper:]' '[:lower:]')"
			[[ "$yn" =~ ^(y|yes)$ ]] && cmd_process "$input"
		fi
	fi
}

# ========================== // Deinterlace Detector // ==========================
is_interlaced() {
	local input

	input="$1"
	local interlaced
	interlaced=$(ffprobe -v error -select_streams v:0 -show_entries stream=field_order -of default=nokey=1:noprint_wrappers=1 "$input")
	case "$interlaced" in
	tt | bb | tb | bt | bt_tb | bt_bt | tb_tb | tb_bt) return 0 ;;
	*) return 1 ;;
	esac
}

get_deinterlace_filter() {
	is_interlaced "$1" && echo "yadif=deint=interlaced" || echo "null"
}

# ========================== // Process Subcommand // ==========================
cmd_process() {
	advanced_prompt
	local input

	input="${1:-}"
	local output

	output="${2:-}"
	local forced_fps

	forced_fps="${3:-}"
	[ -z "$input" ] && error_exit "process: <input> required."
	[ ! -s "$input" ] && error_exit "process: '$input' not found or empty."

	local base

	base="$(basename "$input")"
	local bare

	bare="${base%.*}"
	[ -z "$output" ] && output="$(get_default_filename "$bare" "processed" "$ADV_CONTAINER")"
	[ -n "$forced_fps" ] && ADV_FPS="$forced_fps"

	local fixed_input
	fixed_input="$(ensure_dts_correct "$input")" || error_exit "process: DTS correction failed"

	if [ "$MAX_1080" = true ]; then
		local orig_height
		orig_height="$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$fixed_input" || echo 0)"
		if [[ "$orig_height" =~ ^[0-9]+$ ]] && [ "$orig_height" -gt 1080 ]; then
			ADV_RES="1920x1080"
			verbose_log "process: Height > 1080p; downscaling enabled."
		fi
	fi

	local audio_opts
	audio_opts=($(get_audio_opts_arr))

	local scale_filter

	scale_filter="scale=${ADV_RES}:force_original_aspect_ratio=decrease"
	local deint_filter

	deint_filter="$(get_deinterlace_filter "$fixed_input")"
	local full_filter

	full_filter="$scale_filter"
	[ "$deint_filter" != "null" ] && full_filter="${deint_filter},${scale_filter}"

	if [ "$ADV_MULTIPASS" = true ]; then
		ffmpeg -y -i "$fixed_input" -vf "$full_filter" -r "$ADV_FPS" -c:v "$ADV_CODEC" -b:v "$ADV_BR" -preset medium -pass 1 -an -f mp4 /dev/null || error_exit "pass1 failed"
		ffmpeg -y -i "$fixed_input" -vf "$full_filter" -r "$ADV_FPS" -c:v "$ADV_CODEC" -b:v "$ADV_BR" -preset medium -pass 2 "${audio_opts[@]}" -movflags +faststart "$output" || error_exit "pass2 failed"
	else
		ffmpeg -y -i "$fixed_input" -vf "$full_filter" -r "$ADV_FPS" -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset medium "${audio_opts[@]}" -movflags +faststart "$output" || error_exit "process: encode failed"
	fi

	! check_moov_atom "$output" && moov_fallback "$fixed_input" "$output"
	! check_moov_atom "$output" && error_exit "process: moov atom missing after fallback"
	echo "✅ Processed: $output"
}

# ========================== // Composite Layout // ==========================
composite_group() {
	local files

	files=("$@")
	local count

	count="${#files[@]}"
	[ "$count" -eq 0 ] && return 1

	local c_file
	c_file="$(mktemp --suffix=.mp4)"
	register_temp_file "$c_file"

	local w

	w=1280 h=720
	[ -n "${TARGET_WIDTH:-}" ] && w="$TARGET_WIDTH"
	[ -n "${TARGET_HEIGHT:-}" ] && h="$TARGET_HEIGHT"

	local audio_opts
	audio_opts=($(get_audio_opts_arr))

	case "$count" in
	1)
		ffmpeg -y -i "${files[0]}" -c copy "$c_file" || error_exit "composite_group: copy failed"
		;;
	2)
		ffmpeg -y -i "${files[0]}" -i "${files[1]}" \
			-filter_complex "hstack=inputs=2, pad=${w}:${h}:((ow-iw)/2):((oh-ih)/2):black" \
			-c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset medium -pix_fmt "$ADV_PIX_FMT" \
			"${audio_opts[@]}" "$c_file" || error_exit "composite_group: 2-input failed"
		;;
	3)
		ffmpeg -y -i "${files[0]}" -i "${files[1]}" -i "${files[2]}" \
			-filter_complex "vstack=inputs=3" \
			-c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset medium -pix_fmt "$ADV_PIX_FMT" \
			"${audio_opts[@]}" "$c_file" || error_exit "composite_group: 3-input failed"
		;;
	4)
		ffmpeg -y -i "${files[0]}" -i "${files[1]}" -i "${files[2]}" -i "${files[3]}" \
			-filter_complex "[0:v][1:v]hstack=2[top];[2:v][3:v]hstack=2[bottom];[top][bottom]vstack=2" \
			-c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset medium -pix_fmt "$ADV_PIX_FMT" \
			"${audio_opts[@]}" "$c_file" || error_exit "composite_group: 4-input failed"
		;;
	*)
		local rows

		rows=2 cols=3
		[ "$count" -gt 6 ] && {
			rows=3
			cols=3
		}
		local sw sh layout=""
		sw=$(bc <<<"$w / $cols")
		sh=$(bc <<<"$h / $rows")
		for ((i = 0; i < count; i++)); do
			local col

			col=$((i % cols)) row=$((i / cols))
			local xx

			xx=$((col * sw)) yy=$((row * sh))
			layout+="${xx}_${yy}"
			[ $((i + 1)) -lt "$count" ] && layout+="|"
		done
		ffmpeg -y $(for f in "${files[@]}"; do printf -- "-i %s " "$(absolute_path "$f")"; done) \
			-filter_complex "xstack=inputs=$count:layout=${layout}:fill=black" \
			-c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset medium -pix_fmt "$ADV_PIX_FMT" \
			"${audio_opts[@]}" "$c_file" || error_exit "composite_group: dynamic xstack failed"
		;;
	esac

	! check_moov_atom "$c_file" && moov_fallback "${files[0]}" "$c_file"
	echo "$c_file"
}

# ========================== // Merge Subcommand // ==========================
cmd_merge() {
	advanced_prompt
	local files=() output="" forced_fps=""

	files=() output="" forced_fps=""
	while [ $# -gt 0 ]; do
		case "$1" in
		-o | --output)
			output="$2"
			shift 2
			;;
		-s | --fps)
			forced_fps="$2"
			shift 2
			;;
		*)
			files+=("$1")
			shift
			;;
		esac
	done

	if [ "${#files[@]}" -eq 0 ] && command_exists fzf; then
		mapfile -t files < <(fzf --multi | tr '\n' '\0' | xargs -0 -n1)
	fi

	[ "${#files[@]}" -eq 0 ] && error_exit "No input files provided."

	[ -z "$output" ] && output="$(get_default_filename "output" "merged" "mp4")"
	local tf

	tf="$ADV_FPS"
	[ -n "$forced_fps" ] && tf="$forced_fps"

	local heights

	heights=() max_h=0
	for ((i = 0; i < ${#files[@]}; i++)); do
		local f

		f="${files[$i]}"
		[ ! -f "$f" ] && error_exit "File not found: $f"
		local fixed

		fixed="$(ensure_dts_correct "$f")" || error_exit "DTS failed: $f"
		files[$i]="$fixed"

		local h

		h="$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$fixed")"
		[[ "$h" =~ ^[0-9]+$ ]] && [ "$h" -gt "$max_h" ] && max_h="$h"
		heights+=("$h")
	done

	TARGET_HEIGHT="$max_h"
	TARGET_WIDTH="$(bc <<<"$max_h * 16 / 9")"

	local preprocessed

	preprocessed=()
	for f in "${files[@]}"; do
		local tmpf

		tmpf="$(mktemp --suffix=.mp4)"
		register_temp_file "$tmpf"
		local audio_opts
		audio_opts=($(get_audio_opts_arr))
		echo "🧪 DEBUG: output=$output"
		echo "🧪 DEBUG: files=(${files[*]})"
		ffmpeg -y -i "${f}" -r "$tf" \
			-vf "pad=${TARGET_WIDTH}:${TARGET_HEIGHT}:(ow-iw)/2:(oh-ih)/2:color=black" \
			-c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset medium "${audio_opts[@]}" "$tmpf" || error_exit "preproc failed"
		preprocessed+=("$tmpf")
	done

	if [ "$COMPOSITE_MODE" = true ]; then
		local -A groups group_map
		for ((i = 0; i < ${#files[@]}; i++)); do
			local h

			h="${heights[$i]}"
			groups["$h"]=$((${groups["$h"]:-0} + 1))
			group_map["$h"]+="${preprocessed[$i]}|"
		done

		local segments

		segments=()
		for h in "${!groups[@]}"; do
			IFS='|' read -r -a gfiles <<<"${group_map[$h]}"
			local valid

			valid=()
			for f in "${gfiles[@]}"; do [ -n "$f" ] && valid+=("$f"); done
			[ "${#valid[@]}" -gt 1 ] && segments+=("$(composite_group "${valid[@]}")") || segments+=("${valid[@]}")
		done
		preprocessed=("${segments[@]}")
	fi

	local concat_list
	concat_list="$(mktemp)"
	register_temp_file "$concat_list"
	for seg in "${preprocessed[@]}"; do echo "file '$(absolute_path "$seg")'" >>"$concat_list"; done

	ffmpeg -y -f concat -safe 0 -i "$concat_list" -c copy "$output" || error_exit "merge: concat failed"
	auto_clean "$output"
	echo "✅ Merged: $output"
}

# ========================== // Looperang Subcommand // ==========================
cmd_looperang() {
	advanced_prompt
	local input

	input="$1" output="${2:-}"
	[ -z "$input" ] && error_exit "looperang requires <input>"
	[ ! -f "$input" ] && error_exit "File not found: $input"
	[ -z "$output" ] && output="$(get_default_filename "${input%.*}" "looperang" "mp4")"

	local fixed_input

	fixed_input="$(ensure_dts_correct "$input")"

	local dir_f

	dir_f="$(mktemp -d)"
	register_temp_dir "$dir_f"
	local dir_r

	dir_r="$(mktemp -d)"
	register_temp_dir "$dir_r"

	ffmpeg -y -i "$fixed_input" -qscale:v 2 "$dir_f/frame-%06d.jpg" || error_exit "frame extract failed"
	local count

	count="$(find "$dir_f" -type f | wc -l)"
	[ "$count" -eq 0 ] && error_exit "No frames extracted"

	local i

	i=1
	for frm in $(find "$dir_f" -type f | sort -r); do
		cp "$frm" "$(printf "%s/frame-%06d.jpg" "$dir_r" "$i")"
		i=$((i + 1))
	done

	local fwd_mp4

	fwd_mp4="$(mktemp --suffix=.mp4)"
	register_temp_file "$fwd_mp4"
	local rev_mp4

	rev_mp4="$(mktemp --suffix=.mp4)"
	register_temp_file "$rev_mp4"
	local framerate

	framerate="$(ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of csv=p=0 "$fixed_input" || echo "30")"

	ffmpeg -y -framerate "$framerate" -i "$dir_f/frame-%06d.jpg" -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset medium -pix_fmt "$ADV_PIX_FMT" "$fwd_mp4"
	ffmpeg -y -framerate "$framerate" -i "$dir_r/frame-%06d.jpg" -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset medium -pix_fmt "$ADV_PIX_FMT" "$rev_mp4"

	local concat_list

	concat_list="$(mktemp)"
	register_temp_file "$concat_list"
	echo "file '$fwd_mp4'" >>"$concat_list"
	echo "file '$rev_mp4'" >>"$concat_list"

	ffmpeg -y -f concat -safe 0 -i "$concat_list" -c copy "$output" || error_exit "looperang: concat failed"
	auto_clean "$output"
	echo "✅ Looperang created: $output"
}

# ========================== // Slowmo Subcommand // ==========================
cmd_slowmo() {
	advanced_prompt
	local input

	input="$1" output="${2:-}" factor="${3:-2}"
	[ -z "$input" ] && error_exit "slowmo requires <input>"
	[ ! -f "$input" ] && error_exit "File not found: $input"
	[ -z "$output" ] && output="$(get_default_filename "${input%.*}" "slowmo" "mp4")"

	[ -n "$PTS_FACTOR" ] && factor="$PTS_FACTOR"
	local fps_val

	fps_val="${SPECIFIC_FPS:-60}"

	local filter
	if [ "$INTERPOLATE" = true ]; then
		[ -z "$SPECIFIC_FPS" ] && fps_val="120"
		filter="minterpolate=fps=${fps_val}:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1,setpts=${factor}*PTS"
	else
		filter="setpts=${factor}*PTS"
	fi

	local audio_opts
	audio_opts=($(get_audio_opts_arr))

	ffmpeg -y -i "$input" -filter_complex "$filter,scale=-2:1080,fps=$fps_val" -r "$fps_val" \
		-c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset medium "${audio_opts[@]}" "$output" || error_exit "slowmo failed"
	auto_clean "$output"
	echo "✅ Slow-motion processed: $output"
}

# ========================== // Fix Subcommand // ==========================
cmd_fix() {
	advanced_prompt
	local input

	input="$1" output="$2"
	[ -z "$input" ] || [ -z "$output" ] && error_exit "fix requires <input> <output>"
	[ ! -f "$input" ] && error_exit "File not found: $input"

	local audio_opts
	audio_opts=($(get_audio_opts_arr))

	ffmpeg -y -fflags +genpts -i "$input" -c:v copy "${audio_opts[@]}" -movflags +faststart "$output" ||
		ffmpeg -y -fflags +genpts -i "$input" -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset medium "${audio_opts[@]}" "$output" ||
		error_exit "fix: both copy and re-encode failed"

	auto_clean "$output"
	echo "✅ Fixed: $output"
}

# ========================== // Cleanmeta Subcommand // ==========================
cmd_cleanmeta() {
	advanced_prompt
	local input

	input="$1" output="$2"
	[ -z "$input" ] || [ -z "$output" ] && error_exit "clean requires <input> <output>"
	[ ! -f "$input" ] && error_exit "File not found: $input"

	local audio_opts
	audio_opts=($(get_audio_opts_arr))

	ffmpeg -y -i "$input" -map_metadata -1 -c:v copy "${audio_opts[@]}" -movflags +faststart "$output" ||
		ffmpeg -y -i "$input" -map_metadata -1 -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset medium "${audio_opts[@]}" "$output" ||
		error_exit "clean: both copy and re-encode failed"

	auto_clean "$output"
	echo "✅ Cleaned metadata: $output"
}

# ========================== // Help Message // ==========================
display_usage() {
	cat <<EOF
Usage: ffx [global options] <command> [args]

Global Options:
  -A, --advanced       Enable interactive advanced options
  -v, --verbose        Enable verbose logging
  -b, --bulk           Enable batch operations
  -an                  Strip all audio tracks
  -C, --composite      Enable grouped composite in merge
  -P, --max-1080       Enforce 1080p maximum
  -o, --output <dir>   Output directory
  -f, --fps <val>      Force specific frame rate
  -p, --pts <val>      Set PTS factor (slowmo)
  -i, --interpolate    Use interpolation in slowmo

Commands:
  probe        [<file>]               → Analyze file info
  process      <in> [out] [fps]       → Re-encode/downscale to 1080p
  merge        [-o out] [-s fps] <...>→ Merge or composite multiple
  looperang    <in> [out]             → Create reverse loop video
  slowmo       <in> [out] [factor]    → Apply slow motion
  fix          <in> <out>             → Fix DTS/moov/meta issues
  clean        <in> <out>             → Strip all non-essential metadata
  help                              → Display this help message
EOF
	exit 0
}

# ========================== // Global Option Parser // ==========================
parse_global_options() {
	REMAINING_ARGS=()
	while [ $# -gt 0 ]; do
		case "$1" in
		-A | --advanced) ADVANCED_MODE=true ;;
		-v | --verbose) VERBOSE_MODE=true ;;
		-b | --bulk) BULK_MODE=true ;;
		-an) REMOVE_AUDIO=true ;;
		-C | --composite) COMPOSITE_MODE=true ;;
		-P | --max1080) MAX_1080=true ;;
		-i | --interpolate) INTERPOLATE=true ;;
		-o | --output)
			OUTPUT_DIR="$2"
			shift
			;;
		-f | --fps)
			SPECIFIC_FPS="$2"
			shift
			;;
		-p | --pts)
			PTS_FACTOR="$2"
			shift
			;;
		help) display_usage ;;
		*) REMAINING_ARGS+=("$1") ;;
		esac
		shift
	done
}

# ========================== // Dispatcher // ==========================
main_dispatch() {
	local cmd

	cmd="$1"
	shift
	case "$cmd" in
	probe) cmd_probe "$@" ;;
	process) cmd_process "$@" ;;
	merge) cmd_merge "$@" ;;
	looperang) cmd_looperang "$@" ;;
	slowmo) cmd_slowmo "$@" ;;
	fix) cmd_fix "$@" ;;
	clean) cmd_cleanmeta "$@" ;;
	help) display_usage ;;
	*)
		echo "Unknown command: $cmd"
		display_usage
		;;
	esac
}

# ========================== // Main Entry // ==========================
main() {
	[ $# -lt 1 ] && display_usage
	parse_global_options "$@"
	[ "${#REMAINING_ARGS[@]}" -lt 1 ] && display_usage

	local subcmd

	subcmd="${REMAINING_ARGS[0]}"
	shift
	main_dispatch "$subcmd" "${REMAINING_ARGS[@]:1}"
}

# ========================== // Cleanup Trap // ==========================
trap 'cleanup_all; exit' INT TERM HUP

# ========================== // Footer Auto-Execution // ==========================
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	main "$@"
fi

# ====== ADDITIONS FROM ffxd.compare NOT IN ORIGINAL ======

#!/usr/bin/env bash
#shellcheck disable=SC2207,SC2034,SC2046,SC2004,SC1009,SC1073,SC1078,SC1079,SC1036,SC1050,SC2317
# Author: 4ndr0666 — Production Revision: ffx4.compare vFinal
set -euo pipefail
IFS=$'\n\t'

# ========================== // XDG Compliant Globals // ==========================
: "${XDG_CONFIG_HOME:="$HOME/.config"}"
: "${XDG_CACHE_HOME:="$HOME/.cache"}"
: "${XDG_RUNTIME_DIR:="${TMPDIR:-/tmp}"}"

export FFX4_CONFIG_DIR="$XDG_CONFIG_HOME/ffx4"
export FFX4_CACHE_DIR="$XDG_CACHE_HOME/ffx4"
export FFX4_RUNTIME_DIR="$XDG_RUNTIME_DIR/ffx4"

mkdir -p "$FFX4_CONFIG_DIR" "$FFX4_CACHE_DIR" "$FFX4_RUNTIME_DIR"

# ========================== // Configuration Defaults // ==========================
default_config() {
	ADVANCED_MODE=false
	VERBOSE_MODE=false
	BULK_MODE=false
	REMOVE_AUDIO=false
	CLEAN_META_DEFAULT=true
	COMPOSITE_MODE=false
	MAX_1080=false
	INTERPOLATE=false
	OUTPUT_DIR="$(pwd)"
	SPECIFIC_FPS=""
	PTS_FACTOR=""
	ADV_CONTAINER="mp4"
	ADV_RES="1920x1080"
	ADV_FPS="60"
	ADV_CODEC="libx264"
	ADV_PIX_FMT="yuv420p"
	ADV_CRF="18"
	ADV_BR="10M"
	ADV_MULTIPASS="false"
}
default_config

# ========================== // Command-Line Parser // ==========================
REMAINING_ARGS=()

parse_global_options() {
	while [ $# -gt 0 ]; do
		case "$1" in
		-A | --advanced) ADVANCED_MODE=true ;;
		-v | --verbose) VERBOSE_MODE=true ;;
		-b | --bulk) BULK_MODE=true ;;
		-an) REMOVE_AUDIO=true ;;
		-C | --composite) COMPOSITE_MODE=true ;;
		-P | --max-1080) MAX_1080=true ;;
		-f | --fps)
			SPECIFIC_FPS="$2"
			shift
			;;
		-p | --pts)
			PTS_FACTOR="$2"
			shift
			;;
		-i | --interpolate) INTERPOLATE=true ;;
		-o | --output-dir)
			OUTPUT_DIR="$2"
			shift
			;;
		--container)
			ADV_CONTAINER="$2"
			shift
			;;
		--resolution)
			ADV_RES="$2"
			shift
			;;
		--codec)
			ADV_CODEC="$2"
			shift
			;;
		*) REMAINING_ARGS+=("$1") ;;
		esac
		shift
	done
}

# ========================== // Logging & Traps // ==========================
TEMP_FILES=()
TEMP_DIRS=()

register_temp_file() { TEMP_FILES+=("$1"); }
register_temp_dir() { TEMP_DIRS+=("$1"); }

cleanup_all() {
	for f in "${TEMP_FILES[@]}"; do [ -f "$f" ] && rm -f "$f"; done
	for d in "${TEMP_DIRS[@]}"; do [ -d "$d" ] && rm -rf "$d"; done
}
trap 'cleanup_all; exit' INT TERM HUP EXIT

error_exit() {
	echo "❌ Error: $*" >&2
	exit 1
}
verbose_log() { [ "$VERBOSE_MODE" = true ] && echo "[VERBOSE] $*"; }

# ========================== // Command Existence // ==========================
command_exists() { command -v "$1" >/dev/null 2>&1; }
absolute_path() {
	local in_path

	in_path="$1"
	command_exists readlink && readlink -f "$in_path" 2>/dev/null || echo "$(cd "$(dirname "$in_path")" && pwd)/$(basename "$in_path")"
}

advanced_prompt() {
	if [ "$ADVANCED_MODE" = true ]; then
		echo "⚙️ Advanced Mode: Configure output encoding options."
		read -rp "Container extension [mp4/mkv/mov] (default: mp4): " val
		[ -n "$val" ] && ADV_CONTAINER="$val"
		read -rp "Resolution (e.g., 1920x1080, default: 1920x1080): " val
		[ -n "$val" ] && ADV_RES="$val"
		read -rp "Frame rate [24/30/60] (default: 60): " val
		[ -n "$val" ] && ADV_FPS="$val"
		read -rp "Codec [1=libx264, 2=libx265] (default: 1): " val
		[ "$val" = "2" ] && ADV_CODEC="libx265"
		read -rp "Pixel format [1=yuv420p, 2=yuv422p] (default: 1): " val
		[ "$val" = "2" ] && ADV_PIX_FMT="yuv422p"
		read -rp "CRF value (default: 18): " val
		[ -n "$val" ] && ADV_CRF="$val"
		read -rp "Bitrate (e.g., 10M, default: 10M): " val
		[ -n "$val" ] && ADV_BR="$val"
		read -rp "Enable multipass? (y/N): " val
		val="$(echo "$val" | tr '[:upper:]' '[:lower:]')"
		[ "$val" = "y" ] || [ "$val" = "yes" ] && ADV_MULTIPASS=true
		echo "🔧 Config => Container=$ADV_CONTAINER, Res=$ADV_RES, FPS=$ADV_FPS, Codec=$ADV_CODEC, PixFmt=$ADV_PIX_FMT, CRF=$ADV_CRF, BR=$ADV_BR, Multi=$ADV_MULTIPASS"
	fi
}

is_interlaced() {
	local input="$1"
	local interlaced
	interlaced=$(ffprobe -v error -select_streams v:0 -show_entries stream=field_order -of default=nokey=1:noprint_wrappers=1 "$input")
	case "$interlaced" in
	tt | bb | tb | bt | bt_tb | bt_bt | tb_tb | tb_bt) return 0 ;;
	*) return 1 ;;
	esac
}

get_deinterlace_filter() {
	is_interlaced "$1" && echo "yadif=deint=interlaced" || echo "null"
}

# ========================== // Composite Layout // ==========================
composite_group() {
	local files=("$@") count="${#files[@]}"
	[ "$count" -eq 0 ] && return 1
	local c_file w h audio_opts

	c_file="$(mktemp --suffix=.mp4)"
	register_temp_file "$c_file"
	w=1280; h=720
	[ -n "${TARGET_WIDTH:-}" ] && w="$TARGET_WIDTH"
	[ -n "${TARGET_HEIGHT:-}" ] && h="$TARGET_HEIGHT"
	audio_opts=($(get_audio_opts_arr))

	case "$count" in
	1)
		ffmpeg -y -i "${files[0]}" -c copy "$c_file" || error_exit "composite: copy failed"
		;;
	2)
		ffmpeg -y -i "${files[0]}" -i "${files[1]}" \
			-filter_complex "hstack=inputs=2,pad=${w}:${h}:(ow-iw)/2:(oh-ih)/2:color=black" \
			-c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset medium -pix_fmt "$ADV_PIX_FMT" \
			"${audio_opts[@]}" "$c_file" || error_exit "composite: 2-input failed"
		;;
	3)
		ffmpeg -y -i "${files[0]}" -i "${files[1]}" -i "${files[2]}" \
			-filter_complex "vstack=inputs=3" \
			-c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset medium -pix_fmt "$ADV_PIX_FMT" \
			"${audio_opts[@]}" "$c_file" || error_exit "composite: 3-input failed"
		;;
	4)
		ffmpeg -y -i "${files[0]}" -i "${files[1]}" -i "${files[2]}" -i "${files[3]}" \
			-filter_complex "[0:v][1:v]hstack=2[top];[2:v][3:v]hstack=2[bottom];[top][bottom]vstack=2" \
			-c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset medium -pix_fmt "$ADV_PIX_FMT" \
			"${audio_opts[@]}" "$c_file" || error_exit "composite: 4-input failed"
		;;
	*)
		local rows=2 cols=3 sw sh layout=""
		[ "$count" -gt 6 ] && rows=3 && cols=3
		sw=$(bc <<<"$w / $cols")
		sh=$(bc <<<"$h / $rows")
		for ((i = 0; i < count; i++)); do
			local col=$((i % cols)) row=$((i / cols))
			layout+="$((col * sw))_$((row * sh))"
			[ $((i + 1)) -lt "$count" ] && layout+="|"
		done
		ffmpeg -y $(for f in "${files[@]}"; do printf -- "-i %s " "$(absolute_path "$f")"; done) \
			-filter_complex "xstack=inputs=$count:layout=${layout}:fill=black" \
			-c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset medium -pix_fmt "$ADV_PIX_FMT" \
			"${audio_opts[@]}" "$c_file" || error_exit "composite: xstack failed"
		;;
	esac

	! check_moov_atom "$c_file" && moov_fallback "${files[0]}" "$c_file"
	echo "$c_file"
}

# ========================== // Merge Subcommand // ==========================
cmd_merge() {
	advanced_prompt
	local files=() output="" forced_fps=""
	while [ $# -gt 0 ]; do
		case "$1" in
		-o | --output) output="$2"; shift 2 ;;
		-s | --fps) forced_fps="$2"; shift 2 ;;
		*) files+=("$1"); shift ;;
		esac
	done

	if [ "${#files[@]}" -eq 0 ] && command_exists fzf; then
		mapfile -t files < <(fzf --multi)
	fi
	[ "${#files[@]}" -eq 0 ] && error_exit "merge: No input files."
	[ -z "$output" ] && output="$(get_default_filename "output" "merged" "mp4")"

	local tf="${forced_fps:-$ADV_FPS}" heights=() max_h=0
	for ((i = 0; i < ${#files[@]}; i++)); do
		local f="${files[$i]}" fixed
		[ ! -f "$f" ] && error_exit "merge: File not found: $f"
		fixed="$(ensure_dts_correct "$f")" || error_exit "merge: DTS failed: $f"
		files[$i]="$fixed"
		local h
		h="$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$fixed")"
		[[ "$h" =~ ^[0-9]+$ ]] && [ "$h" -gt "$max_h" ] && max_h="$h"
		heights+=("$h")
	done

	TARGET_HEIGHT="$max_h"
	TARGET_WIDTH="$(bc <<<"$max_h * 16 / 9")"

	local preprocessed=()
	for f in "${files[@]}"; do
		local tmpf
		tmpf="$(mktemp --suffix=.mp4)"
		register_temp_file "$tmpf"
		ffmpeg -y -i "$f" -r "$tf" \
			-vf "pad=${TARGET_WIDTH}:${TARGET_HEIGHT}:(ow-iw)/2:(oh-ih)/2:color=black" \
			-c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset medium "${audio_opts[@]}" "$tmpf" || error_exit "merge: preprocess failed"
		preprocessed+=("$tmpf")
	done

	if [ "$COMPOSITE_MODE" = true ]; then
		local segments=() group_map=() keys=()
		for ((i = 0; i < ${#files[@]}; i++)); do
			local h="${heights[$i]}" key="h$h"
			group_map["$key"]+="${preprocessed[$i]}|"
			[[ ! " ${keys[*]} " =~ " $key " ]] && keys+=("$key")
		done
		for k in "${keys[@]}"; do
			IFS='|' read -r -a group <<<"${group_map[$k]}"
			segments+=("$(composite_group "${group[@]}")")
		done
		preprocessed=("${segments[@]}")
	fi

	local concat_list
	concat_list="$(mktemp)"
	register_temp_file "$concat_list"
	for seg in "${preprocessed[@]}"; do echo "file '$(absolute_path "$seg")'" >>"$concat_list"; done

	ffmpeg -y -f concat -safe 0 -i "$concat_list" -c copy "$output" || error_exit "merge: concat failed"
	auto_clean "$output"
	echo "✅ Merged: $output"
}
display_usage() {
	cat <<EOF
Usage: ffx [global options] <command> [args]

Global Options:
  -A, --advanced       Enable interactive advanced options
  -v, --verbose        Enable verbose logging
  -b, --bulk           Enable batch operations
  -an                  Strip all audio tracks
  -C, --composite      Enable grouped composite in merge
  -P, --max-1080       Enforce 1080p maximum
  -o, --output <dir>   Output directory
  -f, --fps <val>      Force specific frame rate
  -p, --pts <val>      Set PTS factor (slowmo)
  -i, --interpolate    Use interpolation in slowmo

Commands:
  probe        [<file>]               → Analyze file info
  process      <in> [out] [fps]       → Re-encode/downscale to 1080p
  merge        [-o out] [-s fps] <...>→ Merge or composite multiple
  looperang    <in> [out]             → Create reverse loop video
  slowmo       <in> [out] [factor]    → Apply slow motion
  fix          <in> <out>             → Fix DTS/moov/meta issues
  clean        <in> <out>             → Strip all non-essential metadata
  help                              → Display this help message
EOF
	exit 0
}
get_default_filename() {
	local base="${1:-out}"
	local suffix="${2:-tmp}"
	local ext="${3:-mp4}"
	local candidate="${base}_${suffix}.${ext}"
	local counter=1
	while [ -e "$candidate" ]; do
		candidate="${base}_${suffix}_${counter}.${ext}"
		counter=$((counter + 1))
	done
	echo "$candidate"
}

get_audio_opts_arr() {
	if [ "$REMOVE_AUDIO" = true ]; then
		echo "-an"
	else
		echo "-c:a aac -b:a 128k"
	fi
}

bytes_to_human() {
	local bytes="${1:-0}"
	if [ "$bytes" -lt 1024 ]; then
		echo "${bytes} B"
	elif [ "$bytes" -lt 1048576 ]; then
		printf "%.2f KiB" "$(bc -l <<<"${bytes}/1024")"
	elif [ "$bytes" -lt 1073741824 ]; then
		printf "%.2f MiB" "$(bc -l <<<"${bytes}/1048576")"
	else
		printf "%.2f GiB" "$(bc -l <<<"${bytes}/1073741824")"
	fi
}

check_dts_for_file() {
	local file="$1" prev="" problem=0
	while IFS= read -r line; do
		if ! [[ "$line" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then continue; fi
		if [ -n "$prev" ] && [ "$(bc -l <<<"$line < $prev")" -eq 1 ]; then
			echo "❌ Non-monotonic DTS in '$file' (prev: $prev, curr: $line)" >&2
			problem=1
			break
		fi
		prev="$line"
	done < <(ffprobe -v error -select_streams v -show_entries frame=pkt_dts_time -of csv=p=0 "$file" 2>/dev/null)
	return $problem
}

fix_dts() {
	local file="$1"
	local tmpf
	tmpf="$(mktemp --suffix=.mp4)"
	register_temp_file "$tmpf"
	local audio_opts
	audio_opts=($(get_audio_opts_arr))

	if ! ffmpeg -y -fflags +genpts -i "$file" -c:v copy "${audio_opts[@]}" -movflags +faststart "$tmpf"; then
		ffmpeg -y -fflags +genpts -i "$file" -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset medium "${audio_opts[@]}" "$tmpf" || {
			echo "❌ fix_dts: Fallback re-encode failed." >&2
			rm -f "$tmpf"
			return 1
		}
	fi
	echo "$tmpf"
}

ensure_dts_correct() {
	local file="$1"
	[ ! -f "$file" ] && error_exit "DTS fix: '$file' not found"
	if ! check_dts_for_file "$file"; then
		verbose_log "⏱ DTS issues found in '$file'; applying fix..."
		local fixed
		fixed="$(fix_dts "$file")" || return 1
		echo "$fixed"
	else
		echo "$file"
	fi
}

check_moov_atom() {
	local file="$1"
	ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file" >/dev/null 2>&1
}

moov_fallback() {
	local in_file="$1" out_file="$2"
	local audio_opts
	audio_opts=($(get_audio_opts_arr))

	verbose_log "⚙️ moov_fallback: Re-encoding for faststart."
	ffmpeg -y -i "$in_file" -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset medium "${audio_opts[@]}" -movflags +faststart "$out_file" || {
		error_exit "❌ moov_fallback: Failed to re-encode $in_file"
	}
}

# ========================== // Global Option Parser // ==========================
parse_global_options() {
	REMAINING_ARGS=()
	while [ $# -gt 0 ]; do
		case "$1" in
		-A | --advanced) ADVANCED_MODE=true ;;
		-v | --verbose) VERBOSE_MODE=true ;;
		-b | --bulk) BULK_MODE=true ;;
		-an) REMOVE_AUDIO=true ;;
		-C | --composite) COMPOSITE_MODE=true ;;
		-P | --max1080) MAX_1080=true ;;
		-i | --interpolate) INTERPOLATE=true ;;
		-o | --output)
			OUTPUT_DIR="$2"
			shift
			;;
		-f | --fps)
			SPECIFIC_FPS="$2"
			shift
			;;
		-p | --pts)
			PTS_FACTOR="$2"
			shift
			;;
		help) display_usage ;;
		*) REMAINING_ARGS+=("$1") ;;
		esac
		shift
	done
}

# ========================== // Dispatcher // ==========================
main_dispatch() {
	local cmd="$1"
	shift
	case "$cmd" in
	probe) cmd_probe "$@" ;;
	process) cmd_process "$@" ;;
	merge) cmd_merge "$@" ;;
	looperang) cmd_looperang "$@" ;;
	slowmo) cmd_slowmo "$@" ;;
	fix) cmd_fix "$@" ;;
	clean) cmd_cleanmeta "$@" ;;
	help) display_usage ;;
	*)
		echo "Unknown command: $cmd"
		display_usage
		;;
	esac
}

# ========================== // Main Entry // ==========================
main() {
	[ $# -lt 1 ] && display_usage
	parse_global_options "$@"
	[ "${#REMAINING_ARGS[@]}" -lt 1 ] && display_usage
	local subcmd="${REMAINING_ARGS[0]}"
	shift
	main_dispatch "$subcmd" "${REMAINING_ARGS[@]:1}"
}

# ========================== // Cleanup Trap // ==========================
trap 'cleanup_all; exit' INT TERM HUP

# ========================== // Footer Auto-Execution // ==========================
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
	main "$@"
fi