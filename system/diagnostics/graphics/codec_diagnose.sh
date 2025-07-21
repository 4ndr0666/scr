#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

echo "==> OS and Kernel Info"
uname -a
echo

echo "==> FFmpeg Path and Version"
command -v ffmpeg || echo "ffmpeg not found"
ffmpeg -version || echo "ffmpeg failed"
echo

echo "==> MPV Path and Version"
command -v mpv || echo "mpv not found"
mpv --version || echo "mpv failed"
echo

echo "==> Installed video codec-related packages (pacman)"
pacman -Qqe | grep -Ei 'ffmpeg|vpx|x264|x265|mpv|dav1d|aom|libva|codec|libav|gst' || echo "No matching packages found"
echo

echo "==> FFmpeg Configured Codecs"
ffmpeg -codecs | grep -Ei 'vp[89]|opus|vorbis|webm|av1|h264|hevc'
echo

echo "==> FFmpeg Enabled Libraries"
ffmpeg -buildconf | sed -n '/Enabled/,/libavformat/p'
echo

echo "==> WebM Test: Creating a trimmed sample from valid input"
# Use a known good test clip (user may need to adjust this path)
TEST_INPUT="$(find . -type f -iname '*.webm' | head -n1)"
if [[ -z "$TEST_INPUT" ]]; then
  echo "No webm file found for testing in current directory"
  exit 1
fi

TEST_OUT="trimmed_test.webm"
echo "Using: $TEST_INPUT"

ffmpeg -y -i "$TEST_INPUT" -ss 00:00:01 -t 2 -c copy "$TEST_OUT" 2>&1 | tee ffmpeg_trim.log

echo
echo "==> FFprobe Output:"
ffprobe "$TEST_OUT" || echo "ffprobe failed"
echo

echo "==> MPV Playback Probe:"
mpv --vo=null --ao=null --frames=10 "$TEST_OUT" 2>&1 | tee mpv_test.log

echo
echo "==> Test file info:"
file "$TEST_OUT"
mediainfo "$TEST_OUT" || echo "mediainfo not installed"
