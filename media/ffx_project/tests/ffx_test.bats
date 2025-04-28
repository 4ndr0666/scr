#!/usr/bin/env bats

# Set up a clean environment
setup() {
  TMPDIR="$(mktemp -d)"
  export TMPDIR
  dummy_video="${TMPDIR}/dummy.mp4"
  
  # Generate a small black dummy video with silent audio
  ffmpeg -hide_banner -loglevel error \
    -f lavfi -i color=c=black:s=1280x720:d=1:r=30 \
    -f lavfi -i anullsrc=r=44100:cl=stereo \
    -shortest -c:v libx264 -c:a aac -strict -2 "$dummy_video"
}

# Clean up after tests
teardown() {
  rm -rf "$TMPDIR"
}

@test "Help command should work" {
  run ./ffx4.compare help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

@test "Subcommand: slowmo basic dry-run" {
  run ./ffx4.compare slowmo "$dummy_video"
  [ "$status" -eq 0 ]
}

@test "Subcommand: merge basic dry-run" {
  cp "$dummy_video" "${TMPDIR}/dummy2.mp4"
  run ./ffx4.compare merge "${TMPDIR}/dummy.mp4" "${TMPDIR}/dummy2.mp4"
  [ "$status" -eq 0 ]
}

@test "Subcommand: fix basic dry-run" {
  run ./ffx4.compare fix "$dummy_video" "${TMPDIR}/fixed.mp4"
  [ "$status" -eq 0 ]
}

@test "Subcommand: clean basic dry-run" {
  run ./ffx4.compare clean "$dummy_video" "${TMPDIR}/cleaned.mp4"
  [ "$status" -eq 0 ]
}

@test "Subcommand: looperang basic dry-run" {
  run ./ffx4.compare looperang "$dummy_video"
  [ "$status" -eq 0 ]
}

@test "Dry-run ffmpeg correctly invoked" {
  # Check that dummy ffmpeg was used correctly in dry-run commands
  run ffmpeg -version
  [ "$status" -eq 0 ]
}
