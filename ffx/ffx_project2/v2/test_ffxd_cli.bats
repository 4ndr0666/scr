#!/usr/bin/env bats

generate_segment() {
  ffmpeg -y -f lavfi -i testsrc=duration=1:size=$2:rate=$3     -vf "drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:text='${1}':fontsize=48:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2"     -c:v $4 "$5" >/dev/null 2>&1
}

setup() {
  TMPDIR="$(mktemp -d)"
  export TMPDIR
  cd "$TMPDIR"
  generate_segment "ONE" 640x360 24 libx264 a.mp4
  generate_segment "TWO" 1280x720 30 libx265 b.mkv
  generate_segment "THREE" 854x480 60 mpeg4 c.mov
  SCRIPT_ABS="$(realpath "$BATS_TEST_FILENAME")"
  SCRIPT_DIR="$(dirname "$SCRIPT_ABS")"
  cp "$SCRIPT_DIR/ffxd-v2.sh" ./ffxd
  chmod +x ./ffxd
}

teardown() {
  rm -rf "$TMPDIR"
}

@test "CLI: Help menu shows" {
  run ./ffxd help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Media Toolkit"* ]]
}

@test "Merge CLI: Merge multiple files to output" {
  run ./ffxd merge --scale 1080p a.mp4 b.mkv c.mov merged.mp4
  [ -f merged.mp4 ]
  run mpv --no-config --vo=null --ao=null --frames=60 merged.mp4
  [ "$status" -eq 0 ]
}

@test "Process CLI: Repair input file" {
  cp a.mp4 broken.mp4
  run ./ffxd process broken.mp4 repaired.mp4
  [ -f repaired.mp4 ]
  run mpv --no-config --vo=null --ao=null --frames=30 repaired.mp4
  [ "$status" -eq 0 ]
}

@test "Composite CLI: 3 files into grid" {
  run ./ffxd composite a.mp4 b.mkv c.mov
  [ -f composite.mp4 ]
  run mpv --no-config --vo=null --ao=null --frames=60 composite.mp4
  [ "$status" -eq 0 ]
}
