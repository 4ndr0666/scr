#!/usr/bin/env bats

setup() {
  TMPDIR="$(mktemp -d)"
  export TMPDIR
  cd "$TMPDIR"

  # Create mock files representing various failure cases
  ffmpeg -y -f lavfi -i testsrc=duration=2:size=640x360:rate=30     -c:v libx264 -qp 0 -pix_fmt yuv420p normal.mp4 >/dev/null 2>&1

  # Simulate a file with bad DTS (concatenated style)
  ffmpeg -y -f lavfi -i testsrc=duration=2:size=640x360:rate=30     -c:v libx264 -pix_fmt yuv420p segment1.mp4 >/dev/null 2>&1
  ffmpeg -y -f lavfi -i testsrc=duration=2:size=640x360:rate=30     -c:v libx264 -pix_fmt yuv420p segment2.mp4 >/dev/null 2>&1

  echo "file 'segment1.mp4'" > concat.txt
  echo "file 'segment2.mp4'" >> concat.txt
  ffmpeg -y -f concat -safe 0 -i concat.txt -c copy broken_dts.mp4 >/dev/null 2>&1

  # Copy script into sandbox
  SCRIPT_ABS="$(realpath "$BATS_TEST_FILENAME")"
  SCRIPT_DIR="$(dirname "$SCRIPT_ABS")"
  cp "$SCRIPT_DIR/ffx-process-v1.sh" ./process.sh
  chmod +x ./process.sh
}

teardown() {
  rm -rf "$TMPDIR"
}

@test "Process should succeed on normal mp4" {
  ./process.sh normal.mp4 fixed1.mp4
  [ -f fixed1.mp4 ]
  run mpv --no-config --vo=null --ao=null --frames=60 fixed1.mp4
  [ "$status" -eq 0 ]
}

@test "Process should escalate and succeed on DTS error file" {
  ./process.sh broken_dts.mp4 fixed2.mp4
  [ -f fixed2.mp4 ]
  run mpv --no-config --vo=null --ao=null --frames=60 fixed2.mp4
  [ "$status" -eq 0 ]
}
