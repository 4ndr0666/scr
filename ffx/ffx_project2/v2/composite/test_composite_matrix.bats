#!/usr/bin/env bats

generate_segment() {
  ffmpeg -y -f lavfi -i testsrc=duration=1:size=$2:rate=$3     -vf "drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:text='${1}':fontsize=48:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2"     -c:v $4 "$5" >/dev/null 2>&1
}

setup() {
  TMPDIR="$(mktemp -d)"
  export TMPDIR
  cd "$TMPDIR"
  for i in $(seq 1 6); do
    generate_segment "VID$i" 640x$((360 + 40 * i)) $((24 + i * 2)) libx264 v$i.mp4
  done
  SCRIPT_ABS="$(realpath "$BATS_TEST_FILENAME")"
  SCRIPT_DIR="$(dirname "$SCRIPT_ABS")"
  cp "$SCRIPT_DIR/ffx-composite-v1.sh" ./composite.sh
  chmod +x ./composite.sh
}

teardown() {
  rm -rf "$TMPDIR"
}

@test "Composite: 1 video (should stack)" {
  ./composite.sh v1.mp4
  [ -f composite.mp4 ]
  run mpv --no-config --vo=null --ao=null --frames=60 composite.mp4
  [ "$status" -eq 0 ]
}

@test "Composite: 2 videos (horizontal stack)" {
  ./composite.sh v1.mp4 v2.mp4
  [ -f composite.mp4 ]
  run mpv --no-config --vo=null --ao=null --frames=60 composite.mp4
  [ "$status" -eq 0 ]
}

@test "Composite: 4 videos (2x2 grid)" {
  ./composite.sh v1.mp4 v2.mp4 v3.mp4 v4.mp4
  [ -f composite.mp4 ]
  run mpv --no-config --vo=null --ao=null --frames=60 composite.mp4
  [ "$status" -eq 0 ]
}

@test "Composite: 6 videos (3x2 grid)" {
  ./composite.sh v1.mp4 v2.mp4 v3.mp4 v4.mp4 v5.mp4 v6.mp4
  [ -f composite.mp4 ]
  run mpv --no-config --vo=null --ao=null --frames=90 composite.mp4
  [ "$status" -eq 0 ]
}
