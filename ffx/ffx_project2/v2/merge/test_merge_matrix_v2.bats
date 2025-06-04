#!/usr/bin/env bats

generate_segment() {
  ffmpeg -y -f lavfi -i testsrc=duration=2:size=$2:rate=$3 \
    -vf "drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:text='${1}':fontsize=48:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2" \
    -c:v $4 "$5" >/dev/null 2>&1
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
  cp "$SCRIPT_DIR/ffx-merge-v2.sh" ./merge.sh
  chmod +x ./merge.sh
}

teardown() {
  rm -rf "$TMPDIR"
}

@test "Merge v2 --scale largest" {
  ./merge.sh --scale largest a.mp4 b.mkv c.mov output.mp4
  [ -f output.mp4 ]
  run mpv --no-config --vo=null --ao=null --frames=300 --msg-level=ffmpeg/demuxer=debug output.mp4
  [ "$status" -eq 0 ]
  [[ "$output" == *"End of file"* ]] || [[ "$output" == *"AV: "* ]]
}

@test "Merge v2 --scale composite" {
  ./merge.sh --scale composite a.mp4 b.mkv c.mov output.mp4
  [ -f output.mp4 ]
  run mpv --no-config --vo=null --ao=null --frames=300 --msg-level=ffmpeg/demuxer=debug output.mp4
  [ "$status" -eq 0 ]
  [[ "$output" == *"End of file"* ]] || [[ "$output" == *"AV: "* ]]
}

@test "Merge v2 --scale 1080p" {
  ./merge.sh --scale 1080p a.mp4 b.mkv c.mov output.mp4
  [ -f output.mp4 ]
  run mpv --no-config --vo=null --ao=null --frames=300 --msg-level=ffmpeg/demuxer=debug output.mp4
  [ "$status" -eq 0 ]
  [[ "$output" == *"End of file"* ]] || [[ "$output" == *"AV: "* ]]
}
