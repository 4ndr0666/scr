# Ffx Project Coding Plan & Integration Outline

---

## 1. Gap Mitigations — Project Requirements

### Required Functionalities

- **1. Interactive “Advanced” Prompting**
    - Persistent config, validation, and user-driven option selection.

- **2. Fully Automated Composite Layout**
    - Leader aspect ratio detection.
    - Grid/xstack/pad logic for N inputs.

- **3. Two-pass, Moov Atom, Bitrate Control**
    - Enable via advanced prompt or config.
    - Lossless by default, fallback to re-encode as needed.

- **4. Merge/Composite Integration**
    - Merge command uses composite layout if enabled.

- **5. XDG Compliance**
    - `$XDG_CONFIG_HOME/ffx4/`, `$XDG_CACHE_HOME/ffx4/`, `$XDG_RUNTIME_DIR/ffx4/`.

- **6. Strict Idempotency**
    - No output file is ever overwritten without confirmation.

---

## 2. Reintegration Plan

### XDG Compliance

- All config, temp, and runtime files/directories are XDG-compliant.
- Fallback to `$HOME/.config`, `$HOME/.cache`, and `$TMPDIR` if unset.

### Interactive “Advanced” Mode

- Config is loaded and saved from XDG path.
- All encoding/container options can be set interactively.
- Validation for values (resolution regex, etc.).

### Composite Layout Algorithm

- Heights and widths of all inputs are parsed.
- “Leader” aspect ratio is computed.
- Grid (rows × cols) and layout string is auto-generated for xstack.
- Symmetry and visual centering are enforced.

### Two-Pass, Faststart

- If enabled, two-pass and bitrate encode is performed.
- All outputs are faststart optimized (`-movflags +faststart`).

### Merge Sub-Command

- Parses all global options and output file.
- Invokes composite layout as required.
- Idempotent: safe, auto-incrementing output filenames.

### Idempotency & Robust Error Handling

- All commands validate inputs.
- Missing args prompt usage/help.
- All temp files and dirs are managed and cleaned up on exit.

---

## 3. Flags & Command Matrix

- All global options and commands are parsed via a central function and inherited by sub-commands.
- Fzf fallback for input selection if none given.

### Global Options (Short/Long)

| Flag | Description |
|------|-------------|
| -a, --advanced    | Advanced mode  |
| -v, --verbose     | Verbose logging|
| -b, --bulk        | Bulk process   |
| -n, --noaudio     | Remove audio   |
| -c, --composite   | Composite grid |
| -m, --max1080     | 1080p maximum  |
| -o, --output-dir  | Output dir     |
| -f, --fps         | Framerate      |
| -p, --pts         | PTS/speed      |
| -i, --interpolate | Motion interp. |

### Commands

- `process <input> [output]`: Downscale/fix/repair, lossless-first.
- `merge [-o output] [files...]`: Merge/consolidate, auto-composite if enabled.
- `composite [files...]`: Visual grid (up to 9).
- `looperang [files...]`: Boomerang forward+reverse.
- `slowmo <input> [output] [pts]`: Slow motion, interpolation.
- `fix <input> <output>`: Repair, escalate as needed.
- `clean <input> <output>`: Remove nonessential metadata.
- `probe [file]`: Analyze file with suggestions.
- `help`: Usage info.

---

## 4. Testing & Audit

- CLI test suite and matrix covers all core workflows and edge cases.
- Modular BATS tests for merge, process, composite, and CLI.
- All feature additions/changes must be paired with test coverage and README/coding_plan update.

---

## 5. Further Enhancements Roadmap

- Persistent advanced prompt config, last-used recall
- Plugin/preset architecture for filterchains
- Parallel batch/bulk operation
- Auto-update/version-checking support
- Enhanced progress TUI/UX (colors, branding, animation)
- Full markdown/manual documentation and CI

---

## 6. Reference

- See README.md for install, dependencies, usage.
- All major logic and flags are doc-commented in source.
- Project directory: [bin/], [docs/], [test/]

---

*Update this plan with every milestone, PR, and architectural change for a living audit trail.*
