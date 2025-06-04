#!/bin/sh
# ffxd-v2.sh — Media Toolkit: merge, process, composite multiple videos
#
# Subcommands:
#   help       Show this help
#   merge      Concatenate multiple videos into one
#   process    Repair a broken video file
#   composite  Tile multiple videos in a grid
#
# POSIX-sh compliant, ShellCheck-clean, and production-ready.

set -eu
TMPFILES=""
trap 'for f in $TMPFILES; do [ -f "$f" ] && rm -f "$f"; done' EXIT

print_help() {
	cat <<EOF
Media Toolkit — FFXD
Usage: $0 <command> [options]

Commands:
  help                Show this help
  merge               Concatenate multiple videos into one
  process             Repair a broken video file
  composite           Tile multiple videos in a grid

Run '$0 <command> --help' for details.
EOF
}

get_default_filename() {
	# Usage: get_default_filename [base] [ext]
	base=${1:-ffxd_out}
	ext=${2:-mp4}
	name="${base}.${ext}"
	n=1
	while [ -f "$name" ]; do
		name="${base}_${n}.${ext}"
		n=$((n + 1))
	done
	printf '%s\n' "$name"
}

normalize_inputs() {
	# $1 = ffmpeg video filter; rest = input files
	scale_filter=$1
	shift
	list=""
	for inp in "$@"; do
		[ ! -f "$inp" ] && printf 'Missing input: %s\n' "$inp" >&2 && exit 1
		tmpf=$(mktemp --suffix=.mp4)
		TMPFILES="${TMPFILES} ${tmpf}"
		ffmpeg -y -i "$inp" -vf "$scale_filter" -r 30 \
			-c:v libx264 -qp 0 -pix_fmt yuv420p -preset veryfast \
			"$tmpf" >/dev/null 2>&1
		list="${list}${tmpf}
"
	done
	printf '%s' "$list"
}

generate_filter_complex() {
	# $1 = number of inputs
	count=$1
	if [ "$count" -eq 1 ]; then
		printf 'null'
	elif [ "$count" -eq 2 ]; then
		printf '[0:v][1:v]hstack=inputs=2[v]'
	elif [ "$count" -eq 3 ]; then
		printf '[0:v][1:v][2:v]hstack=inputs=3[v]'
	elif [ "$count" -eq 4 ]; then
		printf '[0:v][1:v]hstack=2[top];[2:v][3:v]hstack=2[bottom];[top][bottom]vstack=2[v]'
	else
		cols=3
		layout=""
		i=0
		while [ "$i" -lt "$count" ]; do
			x=$(((i % cols) * 640))
			y=$(((i / cols) * 360))
			if [ -n "$layout" ]; then
				layout="${layout}|${x}_${y}"
			else
				layout="${x}_${y}"
			fi
			i=$((i + 1))
		done
		printf 'xstack=inputs=%s:layout=%s:fill=black[v]' "$count" "$layout"
	fi
}

cmd_merge() {
	# merge [--scale largest|composite|1080p] <in1> [in2 ...] <out>
	scale=""
	while [ $# -gt 0 ]; do
		case $1 in
		--help)
			cat <<EOF
Usage: $0 merge [--scale largest|composite|1080p] <in1> [in2 ...] <out>
Concatenate videos in order with optional scaling.
EOF
			return 0
			;;
		--scale)
			[ $# -lt 2 ] && {
				printf 'Missing scale value\n' >&2
				exit 1
			}
			scale=$2
			shift
			;;
		--*)
			printf 'Unknown option: %s\n' "$1" >&2
			exit 1
			;;
		*)
			break
			;;
		esac
		shift
	done

	[ $# -lt 2 ] && {
		printf 'Usage: %s merge [--scale ...] <in1> [in2 ...] <out>\n' "$0" >&2
		exit 1
	}

	# last argument is output
	for f in "$@"; do output=$f; done

	# build newline-separated input list (all but last)
	inputs_str=""
	for f in "$@"; do
		[ "$f" = "$output" ] && break
		inputs_str="${inputs_str}${f}
"
	done

	# strip trailing newline so normalize_inputs gets no empty
	inputs_str=$(printf '%s' "$inputs_str")

	# determine scaling filter
	if [ -z "$scale" ] || [ "$scale" = largest ]; then
		max_w=0
		max_h=0
		OLD_IFS=$IFS
		IFS='
'
		for inp in $inputs_str; do
			wh=$(ffprobe -v error -select_streams v:0 \
				-show_entries stream=width,height -of csv=p=0:s=' ' "$inp" 2>/dev/null || printf '0 0')
			w=$(printf '%s' "$wh" | awk '{print $1}')
			h=$(printf '%s' "$wh" | awk '{print $2}')
			[ "$w" -gt "$max_w" ] && max_w=$w
			[ "$h" -gt "$max_h" ] && max_h=$h
		done
		IFS=$OLD_IFS
		scale_filter="scale=${max_w}:${max_h}:force_original_aspect_ratio=decrease,\
pad=${max_w}:${max_h}:(ow-iw)/2:(oh-ih)/2:color=black"
	elif [ "$scale" = composite ]; then
		scale_filter="scale=640:360:force_original_aspect_ratio=decrease,\
pad=640:360:(ow-iw)/2:(oh-ih)/2:color=black"
	else
		scale_filter="scale=1920:1080:force_original_aspect_ratio=decrease,\
pad=1920:1080:(ow-iw)/2:(oh-ih)/2:color=black"
	fi

	# normalize inputs
	# shellcheck disable=SC2086
	norm_list=$(normalize_inputs "$scale_filter" $inputs_str)

	# split normalized into positional parameters
	OLD_IFS=$IFS
	IFS='
'
	# shellcheck disable=SC2086
	set -- $norm_list
	IFS=$OLD_IFS

	count=$#
	filter_complex="[0:v][0:a]"
	i=1
	while [ "$i" -lt "$count" ]; do
		filter_complex="${filter_complex}[${i}:v][${i}:a]"
		i=$((i + 1))
	done
	filter_complex="${filter_complex}concat=n=${count}:v=1:a=1[v][a]"

	# build and run ffmpeg
	cmd="ffmpeg -y"
	for inp in "$@"; do
		cmd="${cmd} -i \"${inp}\""
	done
	cmd="${cmd} -filter_complex '${filter_complex}' -map '[v]' -map '[a]' \
-c:v libx264 -qp 0 -pix_fmt yuv420p -preset medium -c:a aac \"${output}\" >/dev/null 2>&1"
	eval "$cmd"

	printf '✅ Merged to: %s\n' "$output"
}

check_dts_monotonicity() {
	file=$1
	prev=""
	bad=0
	out=$(ffprobe -v error -select_streams v \
		-show_entries frame=pkt_dts_time -of csv=p=0 "$file" 2>/dev/null || printf '')
	OLD_IFS=$IFS
	IFS='
'
	for dts in $out; do
		[ -z "$dts" ] && continue
		if [ -n "$prev" ] && awk "BEGIN{exit !($dts < $prev)}"; then
			bad=1
			break
		fi
		prev=$dts
	done
	IFS=$OLD_IFS
	return $bad
}

cmd_process() {
	[ $# -lt 2 ] || [ "$1" = "--help" ] && {
		cat <<EOF
Usage: $0 process <input_file> <output_file>
Repair broken video by remuxing or re-encoding.
EOF
		[ $# -ge 1 ] && return 0 || exit 1
	}
	inp=$1
	outp=$2
	[ ! -f "$inp" ] && printf 'Missing input: %s\n' "$inp" >&2 && exit 1

	printf '🔧 Phase 1: Remux container...\n'
	if ffmpeg -y -i "$inp" -c copy -movflags +faststart "$outp" >/dev/null 2>&1; then
		printf '✅ Phase 1 succeeded.\n✅ Repaired: %s\n' "$outp"
		return 0
	fi

	printf '⚠️ Phase 1 failed. Phase 2: Remux with genpts...\n'
	if ffmpeg -y -fflags +genpts -i "$inp" -c:v copy -c:a aac \
		-movflags +faststart "$outp" >/dev/null 2>&1; then
		printf '✅ Phase 2 succeeded.\n✅ Repaired: %s\n' "$outp"
		return 0
	fi

	printf '⚠️ Phase 2 failed. Phase 3: Check DTS and re-encode...\n'
	if ! check_dts_monotonicity "$inp"; then
		ffmpeg -y -fflags +genpts -i "$inp" -c:v libx264 -qp 0 \
			-preset medium -c:a aac -movflags +faststart "$outp" >/dev/null 2>&1
		printf '✅ Phase 3 succeeded.\n✅ Repaired: %s\n' "$outp"
		return 0
	fi

	printf '🚫 All phases failed.\n' >&2
	return 1
}

cmd_composite() {
	[ $# -lt 1 ] && {
		printf 'Usage: %s composite <inputs>\n' "$0" >&2
		exit 1
	}

	max_w=0
	max_h=0
	for inp in "$@"; do
		wh=$(ffprobe -v error -select_streams v:0 \
			-show_entries stream=width,height -of csv=p=0:s=' ' "$inp" 2>/dev/null || printf '0 0')
		w=$(printf '%s' "$wh" | awk '{print $1}')
		h=$(printf '%s' "$wh" | awk '{print $2}')
		[ "$w" -gt "$max_w" ] && max_w=$w
		[ "$h" -gt "$max_h" ] && max_h=$h
	done
	[ "$max_w" -eq 0 ] && max_w=640
	[ "$max_h" -eq 0 ] && max_h=360

	scale_filter="scale=${max_w}:${max_h}:force_original_aspect_ratio=decrease,\
pad=${max_w}:${max_h}:(ow-iw)/2:(oh-ih)/2:color=black"

	norm_list=$(normalize_inputs "$scale_filter" "$@")

	OLD_IFS=$IFS
	IFS='
'
	# shellcheck disable=SC2086
	set -- $norm_list
	IFS=$OLD_IFS

	count=$#
	filter_complex=$(generate_filter_complex "$count")
	output=$(get_default_filename composite mp4)

	if [ "$filter_complex" = "null" ]; then
		cp "$1" "$output"
	else
		cmd="ffmpeg -y"
		for inp in "$@"; do
			cmd="${cmd} -i \"${inp}\""
		done
		cmd="${cmd} -filter_complex '${filter_complex}' -map '[v]' \
-c:v libx264 -qp 0 -pix_fmt yuv420p -preset medium \"${output}\" >/dev/null 2>&1"
		eval "$cmd"
	fi

	printf '✅ Composite created: %s\n' "$output"
}

# Dispatch
[ $# -ge 1 ] || {
	print_help >&2
	exit 1
}
case $1 in
help | -h | --help) print_help ;;
merge)
	shift
	cmd_merge "$@"
	;;
process)
	shift
	cmd_process "$@"
	;;
composite)
	shift
	cmd_composite "$@"
	;;
*)
	printf 'Unknown command: %s\n' "$1" >&2
	print_help >&2
	exit 1
	;;
esac
