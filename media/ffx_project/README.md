# Ffx Project — Minimalist, Idempotent Media Suite

**ffxd** is a unified, XDG-compliant, POSIX shell toolkit for robust, lossless video merging, compositing, and repair.  
It supports interactive advanced modes, batch automation, and a visually styled CLI with maximal idempotency and safety.

---

## Features

- **Lossless-first pipeline** (`-qp 0` default)
- **Automatic idempotent output naming**
- **Fully automated composite grid layouts**
- **Bulk/batch processing and repair**
- **Interactive “advanced” mode with persistent config**
- **Comprehensive global flags for all commands**
- **XDG directory compliance** for config/cache/runtime
- **Rich colored TUI and stepwise feedback**

---

## Requirements

- ffmpeg (4.x+ recommended)
- ffprobe
- POSIX-compatible shell (bash, zsh, dash)
- mktemp, findutils
- Optional: fzf (for interactive file selection)

---

## Usage

```sh
# Merge (with optional composite grid if --composite is set)
./ffxd merge [global options] file1 file2 ... [output.mp4]

# Lossless repair and normalization
./ffxd process [global options] file.mp4

# Create composite grid
./ffxd composite [global options] file1 file2 ...

# Boomerang effect (forward+reverse)
./ffxd looperang [global options] file.mp4

# Slow-motion (with/without interpolation)
./ffxd slowmo [global options] file.mp4

# Repair timestamps, moov atom, and DTS
./ffxd fix [global options] file.mp4

# Clean metadata
./ffxd clean [global options] file.mp4

# Probe/inspect file
./ffxd probe [global options] file.mp4

# Help/usage
./ffxd help
````

---

## Global Options

All commands support the following:

| Short | Long          | Description                             |
| ----- | ------------- | --------------------------------------- |
| -a    | --advanced    | Interactive advanced prompt/config      |
| -v    | --verbose     | Verbose/log FFmpeg output/status        |
| -b    | --bulk        | Bulk processing (process, fix, clean)   |
| -n    | --noaudio     | Remove all audio streams                |
| -c    | --composite   | Composite (grid) output mode            |
| -m    | --max1080     | Enforce maximum output height 1080p     |
| -o    | --output-dir  | Custom output directory                 |
| -f    | --fps         | Override/force specific frame rate      |
| -p    | --pts         | Playback speed factor (slowmo, time fx) |
| -i    | --interpolate | Enable motion interpolation             |

**Idempotent output naming** is enforced; files never clobber unless `-y` is explicitly set.

---

## Command Reference

See `./ffxd help` or the in-script help for up-to-date option details and example usage.

---

## Project Structure

```
bin/
  ffxd              # Unified CLI
  ffxd-merge        # Standalone merge logic
  ffxd-process      # Standalone process logic
  ...
docs/
  README.md
  coding_plan.md
  ...
test/
  test_ffxd_cli.bats  # CLI/test matrix
  ...
```

---

## License

MIT — see LICENSE file.

---

## Contact

Open PRs, issues, or email the maintainer for questions and collaboration.
