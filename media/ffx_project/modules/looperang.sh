#!/bin/sh

set -u

cleanup_and_exit() {
  code="$1"
  exit "$code"
}

prompt_continue() {
  printf "%s [y/N]: " "$1"
  read -r ans
  case "$ans" in
    [yY]) return 0 ;;
    *)    return 1 ;;
  esac
}

trap 'echo "Script interrupted! Cleaning up..."; cleanup_and_exit 1' INT TERM HUP

# 1) Use fzf to pick a file (adjust patterns if needed)
INPUT_FILE="$(ls -1 ./*.mov ./*.mp4 ./*.avi ./*.mkv ./*.ts 2>/dev/null | fzf --prompt="Select a video: ")"
if [ -z "${INPUT_FILE:-}" ]; then
  echo "No file selected. Exiting..."
  exit 1
fi

BASENAME="$(basename "$INPUT_FILE" | sed 's/\.[^.]*$//')"
FORWARD_FRAMES_DIR="forward_frames"
REVERSED_FRAMES_DIR="reversed_frames"
FORWARD_VIDEO="forward_${BASENAME}.mov"
REVERSED_VIDEO="reversed_${BASENAME}.mov"
LOOPERANG_VIDEO="${BASENAME}_looperang.mov"
CONCAT_LIST="concat_list_${BASENAME}.txt"

echo "Selected file: $INPUT_FILE"
echo "Will generate frames in: $FORWARD_FRAMES_DIR and $REVERSED_FRAMES_DIR"
echo "Final output: $LOOPERANG_VIDEO"
echo

# Confirm
if ! prompt_continue "Ready?"; then
  echo "Aborting."
  exit 0
fi

FPS="$(ffprobe -v 0 -select_streams v:0 -show_entries stream=avg_frame_rate -of csv=p=0 "$INPUT_FILE")"
if [ -z "$FPS" ]; then
  echo "Failed to detect FPS. Defaulting to 60."
  FPS="60"
fi

echo "Detected original FPS: $FPS"
echo
mkdir -p "$FORWARD_FRAMES_DIR" "$REVERSED_FRAMES_DIR"

echo "Extracting frames to $FORWARD_FRAMES_DIR ..."
ffmpeg -i "$INPUT_FILE" -qscale:v 2 "${FORWARD_FRAMES_DIR}/frame-%06d.jpg"
echo "Forward frames extraction complete."
echo

echo "Generating reversed frames..."
i=1
ls -1 "${FORWARD_FRAMES_DIR}"/*.jpg | sort -r | while read -r srcfile; do
  newname=$(printf "frame-%06d.jpg" "$i")
  cp "$srcfile" "${REVERSED_FRAMES_DIR}/${newname}"
  i=$(( i + 1 ))
done
echo "Reversed frames done."
echo

##############################################################################
# 6) Rebuild Forward Video @ Original FPS, Lossless H.264
##############################################################################
echo "Building forward video: $FORWARD_VIDEO (lossless, CRF=0, $FPS fps)"
ffmpeg \
  -framerate "$FPS" \
  -i "${FORWARD_FRAMES_DIR}/frame-%06d.jpg" \
  -c:v libx264 -crf 0 -preset medium \
  -pix_fmt yuv420p \
  -movflags +faststart \
  "$FORWARD_VIDEO"
echo

##############################################################################
# 7) Rebuild Reversed Video @ Same FPS, Lossless H.264
##############################################################################
echo "Building reversed video: $REVERSED_VIDEO (lossless, CRF=0, $FPS fps)"
ffmpeg \
  -framerate "$FPS" \
  -i "${REVERSED_FRAMES_DIR}/frame-%06d.jpg" \
  -c:v libx264 -crf 0 -preset medium \
  -pix_fmt yuv420p \
  -movflags +faststart \
  "$REVERSED_VIDEO"
echo

##############################################################################
# 8) Concatenate Forward + Reversed (No Re-encode)
##############################################################################
echo "Creating concat list: $CONCAT_LIST"
cat <<EOF > "$CONCAT_LIST"
file '$FORWARD_VIDEO'
file '$REVERSED_VIDEO'
EOF

echo "Concatenating to final: $LOOPERANG_VIDEO (using -c copy)..."
ffmpeg -safe 0 -f concat -i "$CONCAT_LIST" -c copy "$LOOPERANG_VIDEO"
echo

##############################################################################
# 9) Cleanup
##############################################################################
if prompt_continue "Cleanup intermediate frames/videos?"; then
  echo "Removing temporary files..."
  rm -rf "$FORWARD_FRAMES_DIR" "$REVERSED_FRAMES_DIR" "$FORWARD_VIDEO" "$REVERSED_VIDEO" "$CONCAT_LIST"
  echo "Cleanup complete."
fi

echo "Looperang creation finished. Output is: $LOOPERANG_VIDEO"
exit 0
