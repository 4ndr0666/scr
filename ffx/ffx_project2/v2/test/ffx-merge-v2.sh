#!/bin/sh
# ffx-merge-v2-scaled.sh — Merge with Interactive Resolution Control

set -e
trap 'for f in $TMPFILES; do [ -f "$f" ] && rm -f "$f"; done' EXIT
TMPFILES=""

get_default_filename() {
  base="$1" suffix="$2" ext="$3"
  name="${base}_${suffix}.${ext}"
  n=1
  while [ -f "$name" ]; do
    name="${base}_${suffix}${n}.${ext}"
    n=$((n+1))
  done
  echo "$name"
}

cmd_merge_v2() {
  crf="" fps="" speed="1.0" interpolate=false output="" scale=""
  input_files=() container="mp4"

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --crf) crf="$2"; shift ;;
      --fps) fps="$2"; shift ;;
      --speed) speed="$2"; shift ;;
      --interpolate) interpolate=true ;;
      --scale) scale="$2"; shift ;;
      --help)
        cat <<EOF
Usage: ffx merge [options] <input1> [input2 ...] [output.ext]
Options:
  --crf <int>       Use CRF instead of default lossless (QP 0)
  --fps <int>       Target FPS (default: max of inputs)
  --speed <float>   Playback speed (1.0=normal, 0.4=slowmo)
  --interpolate     Enable high-FPS motion smoothing
  --scale <mode>    Scale: largest | composite | 1080p (default)
  --help            Show this help
EOF
        return 0 ;;
      *)
        input_files+=("$1") ;;
    esac
    shift
  done

  last="${input_files[-1]}"
  if printf '%s' "$last" | grep -Eq '\.mp4$|\.mkv$|\.mov$'; then
    output="$last"
    unset 'input_files[${#input_files[@]}-1]'
    container="${output##*.}"
  fi

  [ "${#input_files[@]}" -eq 0 ] && command -v fzf >/dev/null &&
    mapfile -t input_files < <(fzf --multi)

  [ "${#input_files[@]}" -eq 0 ] && {
    echo "No input files." >&2
    return 1
  }

  [ -z "$output" ] && output="$(get_default_filename "output" "merged" "$container")"

  # Get largest resolution
  max_w=0; max_h=0
  for f in "${input_files[@]}"; do
    read w h <<<"$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=' ' "$f")"
    max_w=$(( w > max_w ? w : max_w ))
    max_h=$(( h > max_h ? h : max_h ))
  done

  # Prompt if scale unset
  if [ -z "$scale" ]; then
    echo "🎥 Largest input: ${max_w}x${max_h}"
    echo "Detected mixed resolutions."
    echo "Choose output rendering mode:"
    echo "  [1] Match largest resolution (${max_w}x${max_h})"
    echo "  [2] Composite smaller inputs to largest (pad)"
    echo "  [3] Downscale to 1080p"
    read -rp "Selection [1-3]: " sel
    case "$sel" in
      1) scale="largest" ;;
      2) scale="composite" ;;
      *) scale="1080p" ;;
    esac
  fi

  # Determine target FPS
  max_fps=0
  [ -z "$fps" ] && for f in "${input_files[@]}"; do
    fr="$(ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of csv=p=0 "$f")"
    val=$(bc -l <<<"${fr}") 2>/dev/null || val=0
    max_fps=$(bc <<<"if($val>$max_fps) $val else $max_fps")
  done && fps="${max_fps:-30}"

  norm=()
  for f in "${input_files[@]}"; do
    tmpf="$(mktemp --suffix=.mp4)"
    TMPFILES="$TMPFILES $tmpf"
    case "$scale" in
      largest)
        filter="scale=${max_w}:${max_h}" ;;
      composite)
        filter="scale=${max_w}:${max_h}:force_original_aspect_ratio=decrease,pad=${max_w}:${max_h}:(ow-iw)/2:(oh-ih)/2:color=black" ;;
      1080p|*)
        filter="scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2:color=black" ;;
    esac
    [ "$interpolate" = true ] && filter="minterpolate=fps=${fps}:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1,$filter"
    filter="$filter,setpts=${speed}*PTS"
    opts="-c:v libx264 -pix_fmt yuv420p -movflags +faststart -c:a aac -b:a 128k -preset medium"
    [ -n "$crf" ] && opts="-crf $crf $opts" || opts="-qp 0 $opts"
    ffmpeg -y -i "$f" -r "$fps" -vf "$filter" $opts "$tmpf" >/dev/null 2>&1
    norm+=("$tmpf")
  done

  listf="$(mktemp)"
  TMPFILES="$TMPFILES $listf"
  for n in "${norm[@]}"; do echo "file '$n'" >>"$listf"; done

  ffmpeg -y -f concat -safe 0 -i "$listf" -c copy "$output" >/dev/null 2>&1 || {
    echo "merge: concat failed" >&2
    return 1
  }

  echo "✅ Merged to: $output"
}

cmd_merge_v2 "$@"
