# ffxd — Unified XDG-Compliant Video Toolkit

**Author:** 4ndr0666  
**Maintainer:** andrew+ffxd@yourdomain.com  
**Last Updated:** 2024-06-24  
**Version:** v4.0-alpha

---

## Project Overview

ffxd is a minimalist, POSIX-compliant, XDG-respecting shell suite for robust, lossless video merging, grid composition, slow motion, boomerang effects, cleaning, and repair.  
All commands use safe defaults, are idempotent, and provide rich logging and verbose output for power users and audit trails.

---

## Features

- Unified CLI with strict shell safety and argument validation
- Lossless-first pipeline (e.g., process, merge with `-qp 0`)
- Idempotent output file naming (auto-suffix; auto-increment pending)
- Full XDG directory compliance (config, cache, temp)
- Interactive “advanced” mode for granular control (pending, ticket #3)
- Bulk processing, verbose and error logging
- Clean, color-coded help output

---

## Requirements

- bash 5+
- ffmpeg (4.x+)
- ffprobe
- mktemp, findutils
- Optional: fzf (for future interactive file picking)

---

## Usage

```sh
# Process video(s)
./ffxd process [global options] file1.mp4 [file2 ...]

# Merge multiple videos (lossless-first)
./ffxd merge [global options] file1.mp4 file2.mp4 [fileN ...]

# Composite grid
./ffxd composite [global options] file1.mp4 file2.mp4 [up to 4, 9 support pending]

# Boomerang effect
./ffxd looperang [global options] file.mp4

# Slow-motion
./ffxd slowmo [global options] file.mp4 -p 0.5

# Fix duration/timestamp, force CFR
./ffxd fix [global options] file.mp4

# Clean runtime and cache
./ffxd clean

# Probe file info
./ffxd probe file.mp4

# Help
./ffxd help
````

---

## Global Options

| Short | Long          | Description                                  |
| ----- | ------------- | -------------------------------------------- |
| -a    | --advanced    | Interactive advanced prompt (pending)        |
| -v    | --verbose     | Verbose output/logging                       |
| -b    | --bulk        | Bulk/batch process for 'process'             |
| -n    | --noaudio     | Remove all audio streams                     |
| -m    | --max1080     | Limit output to 1080p height                 |
| -o    | --output-dir  | Output directory (default: cwd)              |
| -f    | --fps         | Force output FPS                             |
| -p    | --pts         | Set slowmo/speed factor                      |
| -i    | --interpolate | Enable motion interpolation (requires --fps) |

---

## Current Implementation Notes

* All features and error logging are production-grade and copy/paste safe.
* Output file names: `${basename}_processed.mp4`, `${basename}_merged.mp4`, etc.; auto-increment feature in progress.
* Interactive advanced prompt and 5–9 input composite grid support are under active development (see work tickets).
* Colorized, timestamped logs and advanced metadata scrubbing on the roadmap.

---

## Escalated Work Tickets (as of 2024-06-24)

See [work ticket](#) in repo root or docs/ for real-time ticket matrix.

* Output file idempotency/auto-increment
* Composite grid generalization (up to 9)
* Interactive advanced prompt
* Function header/documentation coverage
* Full CLI test matrix expansion

---

## Contributors & Contacts

* **Primary Maintainer:** 4ndr0666 ([andrew+ffxd@yourdomain.com](mailto:andrew+ffxd@yourdomain.com))
* **Review/Audit:** ChatGPT (OpenAI, audit completed 2024-06-24)
* **Current status:** v4.0-alpha, live branch

---

## License

MIT — See LICENSE for details.

---

## Changelog

* **2024-06-24**: v4.0-alpha, all core commands implemented, code audit and real-world ticketing in place.
* **2024-06-20**: XDG compliance finalized, global options expanded.
* **2024-06-09**: Core shell skeleton, initial stubs and usage.
