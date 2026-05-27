# Mpv-play.sh

>Here are all of the available flags and combinations for use with this script:

Flags:
  --recent          source: GTK recently-used database
  --images-only     source: images only
  --videos-only     source: video files only
  --recursive       descend into subdirectories
  --no-shuffle      play in sort -V order instead of random
  --loop            loop playlist indefinitely
  --duration N      image display duration in seconds (default: 5)
  --print           dry-run: print resolved playlist to stdout, no mpv
  --queue           append to running mpv IPC socket (auto-spawns if none)

Combos:
  <dir>                               play dir, shuffled
  <dir> --no-shuffle                  play dir, sorted
  <dir> --recursive                   play entire tree, shuffled
  <dir> --recursive --no-shuffle      play entire tree, sorted
  <dir> --images-only                 slideshow, shuffled
  <dir> --images-only --no-shuffle    slideshow, sorted
  <dir> --images-only --duration 10   slideshow, 10s per image
  <dir> --images-only --loop          slideshow, looping
  <dir> --videos-only                 videos only, shuffled
  <dir> --videos-only --recursive     videos from entire tree
  <dir> --queue                       queue whole dir into mpv
  <file> --queue                      queue single file into mpv
  --recent                            play recent, shuffled
  --recent --no-shuffle               play recent, most-recent-first order
  --recent --loop                     play recent, looping
  <dir> --recursive --print           inspect resolved playlist before playing
