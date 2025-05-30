setup() {
  # Create a fakebin directory to override ffmpeg/ffprobe
  FAKEBIN="$BATS_TEST_TMPDIR/fakebin"
  mkdir -p "$FAKEBIN"

  # Fake ffmpeg
  cat >"$FAKEBIN/ffmpeg" <<'EOF'
#!/usr/bin/env bash
echo "[FAKE] ffmpeg $*" >&2

# Simulate frame extraction by creating dummy frames
if [[ "$*" == *"-qscale:v"* ]]; then
  FRAME_DIR=$(pwd)/test_frames
  mkdir -p "$FRAME_DIR"
  for i in {1..5}; do
    touch "$FRAME_DIR/frame-$(printf "%06d" "$i").jpg"
  done
fi

# Simulate encoding from frames to mp4
if [[ "$*" == *"frame-%06d.jpg"* ]]; then
  OUTFILE="${@: -1}"  # Last argument
  mkdir -p "$(dirname "$OUTFILE")"
  touch "$OUTFILE"
fiZQ

# Simulate concat operation to produce final output
if [[ "$*" == *"-f concat"* ]]; then
  OUTFILE="${@: -1}"  # Last argument
  mkdir -p "$(dirname "$OUTFILE")"
  touch "$OUTFILE"
fi

exit 0
EOF
  chmod +x "$FAKEBIN/ffmpeg"

  # Fake ffprobe
  cat >"$FAKEBIN/ffprobe" <<'EOF'
#!/usr/bin/env bash
# Always simulate success
echo "30"
exit 0
EOF
  chmod +x "$FAKEBIN/ffprobe"

  # Prepend fakebin to PATH
  PATH="$FAKEBIN:$PATH"
}
