# **CODEX: Ffx Project - Media Toolkit, Unified CLI, Pipeline, and Core Suite**

## **Project Summary**

**Ffx:** A minimalist, XDG-compliant, shell-based media utility for video merging, composition, repair, and re-encoding. It targets maximal robustness and idempotency, featuring interactive advanced modes, automated layout, lossless-first logic, and a vibrant, informative TUI.

**Iterations**: There are several iterations of the script in the ffx_project directory conataining various features with each upgraded release. The goal is to create a unified release encapsulating all of the features offered in all previous iterations for a enterprise release titled "ffxd".

---

## **Feature Set – Confirmed (Current Implementation)**

### **A. Global Options \[GLOBAL]**

| Flag                  | Description                                 |
| --------------------- | ------------------------------------------- |
| `-a`, `--advanced`    | Interactive advanced prompt/config          |
| `-v`, `--verbose`     | Verbose/log FFmpeg output and status        |
| `-b`, `--bulk`        | Bulk/batch processing in process/fix/clean  |
| `-n`, `--noaudio`     | Remove all audio streams                    |
| `-c`, `--composite`   | Composite (grid) output mode for merge      |
| `-m`, `--max1080`     | Enforce 1080p height maximum                |
| `-o`, `--output-dir`  | Custom output directory                     |
| `-f`, `--fps`         | Override/force specific frame rate          |
| `-p`, `--pts`         | Set playback speed (slowmo, time effects)   |
| `-i`, `--interpolate` | Enable motion interpolation in slowmo/merge |

**Actions:**

* All commands inherit these options via a single global parser (`parse_global_options`).
* Each command must document support for these flags and process as required.

---

### **B. Primary Commands \[COMMANDS]**

| Command     | Description                                                        |
| ----------- | ------------------------------------------------------------------ |
| `process`   | Downscale/fix videos with lossless priority; batch or single input |
| `merge`     | Lossless merge, auto-re-encode as needed, idempotent naming        |
| `composite` | Auto-grid stack N videos in dynamic layouts (1–9 inputs)           |
| `looperang` | Concatenate video and its reverse for a "boomerang" effect         |
| `slowmo`    | Apply slow motion with optional interpolation                      |
| `fix`       | Fixes duration/timestamps/DTS/moov atom via multi-stage escalation |
| `clean`     | Removes all nonessential metadata                                  |
| `probe`     | Detailed probe/analysis with interactive suggestions               |
| `help`      | Styled usage/help                                                  |

**Actions:**

* Each command must call the global parser and support fzf file selection if no file argument(s) are given.
* Output filenames must be auto-generated idempotently unless overridden.

---

### **C. Required Features \[REQ]**

* **XDG compliance**: Use `$XDG_CONFIG_HOME`, `$XDG_CACHE_HOME`, `$XDG_RUNTIME_DIR` for config, temp, and runtime, with robust fallbacks.
* **Idempotency**: All output files use non-clobbering logic, e.g., `_merged`, `_processed`, auto-increment on collision.
* **Interactive Advanced Prompt**: On `--advanced`, prompt for all encoding options and persist/load from config.
* **Composite Layout**: Automated detection of "leader" aspect ratio; symmetric layout for all files in grid.
* **Two-pass/bitrate support**: Enable via advanced options; controlled by config or prompt.
* **Robust fallback/repair**: `process` and `fix` escalate (copy → rewrap → re-encode) if any phase fails, ensuring playback compatibility.
* **Tempfile and resource cleanup**: All tempfiles/dirs registered and purged on exit via trap.

---

## **Work Tickets & Team Actions**

### **1. \[GLOBAL/PARSER] Unified Global Flag Parsing**

* Refactor all global flag handling into a single, reusable function.
* Ensure short and long forms are supported and passed to all sub-commands.
* Maintain mapping to internal variables as described above.
* **Assignee:** CLI/Framework

---

### **2. \[COMMAND/PROCESS] Robust Processing Pipeline**

* Implement `cmd_process` with fzf fallback, multi-phase repair, idempotent naming.
* Downscale to 1080p unless overridden, prefer lossless `-qp 0`.
* Handle bulk and single mode, log status.
* **Assignee:** Media/Codec

---

### **3. \[COMMAND/MERGE] Composite & Merge Engine**

* Implement `cmd_merge` supporting composite mode (`--composite`).
* Auto-detect largest input resolution; provide interactive prompt if mismatch.
* Re-encode only if required (lossless by default).
* **Assignee:** Media/Codec

---

### **4. \[COMMAND/COMPOSITE] Auto Grid/Stack Layout**

* Implement fully automated grid layout logic.
* Dynamically generate xstack/hstack/vstack for N inputs, preserving AR.
* Pad and center as required, allow custom resolution in advanced mode.
* **Assignee:** Layout/UX

---

### **5. \[COMMAND/SLOWMO/LOOPERANG] High-FPS and Time Effects**

* Implement slowmo (`--pts`, `--interpolate`) and looperang (forward/reverse).
* Support high-FPS with minterpolate when requested.
* **Assignee:** Media/Codec

---

### **6. \[COMMAND/FIX/CLEAN] Repair & Metadata Clean**

* Escalate fix (copy → rewrap → re-encode) if needed.
* Remove nonessential metadata in clean.
* Ensure output is always idempotent and safe.
* **Assignee:** Media/Codec

---

### **7. \[COMMAND/PROBE] Smart Analysis & Guidance**

* Implement probe with colored output, interactive suggestions (e.g., "File is >1080p, process?").
* fzf fallback for file selection.
* **Assignee:** CLI/UX

---

### **8. \[XDG/ENV] Environment & Resource Management**

* Ensure all XDG directories and fallback logic are in place for all commands.
* Implement universal cleanup via trap for tempfiles/dirs.
* **Assignee:** Framework

---

### **9. \[TUI/UX] Visual/Styled Menu and Feedback**

* Use colorized banners, headings, and per-step status feedback.
* Ensure usage/help is clean, clear, and comprehensive.
* **Assignee:** CLI/UX

---

### **10. \[TEST/COVERAGE] Matrix & CLI Tests**

* Matrix tests for process/merge/composite with diverse media specs.
* CLI umbrella tests for each command.
* Ensure idempotency and edge-case coverage.
* **Assignee:** QA/CI

---

## **Audit & Review Instructions**

* All modules must expose internal variables and config to the top-level script for easy audit.
* Every global and command-specific option must have doc-comment in source, and be represented in the help menu.
* Each command’s default behavior, output filename policy, and fallback logic must be documented in source and in user-facing docs.

---

## **Further Enhancements / Roadmap**

### **A. \[PERSISTENCE]**

* Implement saving/loading advanced prompt options in config (XDG path).
* Track last-used settings for repeatability.

### **B. \[AUTO-UPGRADE]**

* Add auto-update or version-check functionality for CLI script.

### **C. \[PLUGINS/EXT]**

* Enable user-extensible filterbank or preset system.

### **D. \[PERF/EXPERT]**

* Multi-threaded/parallel processing for bulk operations.
* Expose more codec and filter options for expert users.

### **E. \[UX POLISH]**

* Richer colored progress bars, animated banners, or ASCII art for branding.

### **F. \[DOCS/CI]**

* Full Markdown/manual documentation.
* Automated CI with test matrix reporting.

---

## **References & Crosslinks**

* See `coding_plan.md` for integration outline and gap mitigation checklist.
* See `README.md` for top-level usage and dependencies.
* See `ffx_todo.md` for historical design intent and implementation notes.
* See source comments in each command for expected input/outputs.
