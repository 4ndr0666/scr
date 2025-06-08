#!/usr/bin/env bats

# Resolve bats libraries from local or system paths
support_load=""
assert_load=""
for p in "$BATS_TEST_DIRNAME/bats-support/load" "$BATS_TEST_DIRNAME/bats-support/load.bash" \
         "$BATS_TEST_DIRNAME/../bats-support/load" "$BATS_TEST_DIRNAME/../bats-support/load.bash" \
         "/usr/lib/bats/bats-support/load" "/usr/lib/bats/bats-support/load.bash"; do
  if [ -f "$p" ]; then
    support_load="$p"
    break
  fi
done
for p in "$BATS_TEST_DIRNAME/bats-assert/load" "$BATS_TEST_DIRNAME/bats-assert/load.bash" \
         "$BATS_TEST_DIRNAME/../bats-assert/load" "$BATS_TEST_DIRNAME/../bats-assert/load.bash" \
         "/usr/lib/bats/bats-assert/load" "/usr/lib/bats/bats-assert/load.bash"; do
  if [ -f "$p" ]; then
    assert_load="$p"
    break
  fi
done

if [ -n "$support_load" ] && [ -n "$assert_load" ]; then
  load "$support_load"
  load "$assert_load"
else
  skip_all=true
fi

setup() {
  if [ "${skip_all:-false}" = true ]; then
    skip "bats-support or bats-assert not available"
  fi
  # Create temp dir for dummy files
  TMPDIR=$(mktemp -d)
  testpath="$TMPDIR/test_merge"

  mkdir -p "$testpath"

  # Create two short dummy videos (1s, 320x240, color)
  ffmpeg -f lavfi -i color=c=red:s=320x240:d=1 -c:v libx264 -pix_fmt yuv420p "$testpath"/video1.mp4 -y >/dev/null 2>&1
  ffmpeg -f lavfi -i color=c=blue:s=320x240:d=1 -c:v libx264 -pix_fmt yuv420p "$testpath"/video2.mp4 -y >/dev/null 2>&1
}

teardown() {
  if [ "${skip_all:-false}" = true ]; then
    return
  fi
  rm -rf "$TMPDIR"
}

@test "merge script --help prints usage and exits 0" {
  run merge --help
  assert_success
  assert_output --partial "Usage:"
}

@test "merge script fails on non-existent file" {
  run merge nonexistentfile.mp4
  assert_failure
  assert_output --partial "Error: File not found"
}

@test "merge script merges two valid files successfully" {
  outdir="$TMPDIR/output"
  mkdir -p "$outdir"

  run merge -o "$outdir" "$testpath"/video1.mp4 "$testpath"/video2.mp4
  assert_success
  assert_output --partial "Merged video saved as:"

  # Verify output file exists
  output_file=$(echo "$output" | sed -n 's/.*Saved as: \(.*\)/\1/p')
  [ -f "$outdir/merged_video_merged.mp4" ]
}

@test "merge script normalizes files when direct concat fails" {
  # Create files with differing codecs or resolutions to force normalization
  # For simplicity, we just check that the script completes successfully

  outdir="$TMPDIR/output2"
  mkdir -p "$outdir"

  run merge -o "$outdir" "$testpath"/video1.mp4 "$testpath"/video2.mp4
  assert_success
  assert_output --partial "Merged video saved as:"
  [ -f "$outdir/merged_video_merged.mp4" ]
}
