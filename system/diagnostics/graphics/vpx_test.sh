#!/usr/bin/env bash
# vpx_test.sh — Validate VP8/VP9 encode/playback pipeline
set -euo pipefail
IFS=$'\n\t'

# ─── Config ────────────────────────────────────────────────────────────────
INPUT_URL="https://media.xiph.org/video/derf/y4m/akiyo_cif.y4m"
INPUT_FILE="test_input.y4m"
VP8_OUT="test_vp8.webm"
VP9_OUT="test_vp9.webm"

# ─── Helpers ───────────────────────────────────────────────────────────────
log() { printf "\n👉 %s\n" "$*"; }
fail() { printf "❌ %s\n" "$*" >&2; exit 1; }

# ─── Download Known Good Input ─────────────────────────────────────────────
if [[ ! -f "$INPUT_FILE" ]]; then
  log "Downloading test Y4M video clip..."
  curl -L --fail --retry 3 -o "$INPUT_FILE" "$INPUT_URL" || fail "Download failed"
else
  log "Using cached $INPUT_FILE"
fi

# ─── VP8 Encode ────────────────────────────────────────────────────────────
log "Encoding VP8 with libvpx + libvorbis..."
ffmpeg -hide_banner -y -i "$INPUT_FILE" \
  -c:v libvpx -b:v 1M -crf 10 -c:a libvorbis "$VP8_OUT"

# ─── VP9 Encode ────────────────────────────────────────────────────────────
log "Encoding VP9 with libvpx-vp9 + libopus..."
ffmpeg -hide_banner -y -i "$INPUT_FILE" \
  -c:v libvpx-vp9 -b:v 0 -crf 30 -c:a libopus "$VP9_OUT"

# ─── Probe Outputs ─────────────────────────────────────────────────────────
log "FFprobe output: VP8"
ffprobe -v error -show_format -show_streams "$VP8_OUT" | grep -E 'codec_name|duration|bit_rate'

log "FFprobe output: VP9"
ffprobe -v error -show_format -show_streams "$VP9_OUT" | grep -E 'codec_name|duration|bit_rate'

# ─── Playback Test ─────────────────────────────────────────────────────────
log "Attempting playback with mpv (10 frames each)..."
mpv --no-config --vo=null --ao=null --frames=10 "$VP8_OUT" || fail "VP8 playback failed"
mpv --no-config --vo=null --ao=null --frames=10 "$VP9_OUT" || fail "VP9 playback failed"

log "✅ VPX test passed — both VP8 and VP9 are functional."
