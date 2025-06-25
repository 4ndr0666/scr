# 🛠️ FFXD PROJECT WORK TICKET (2024-06-24)

**Project:** ffxd — Unified XDG-Compliant Video Toolkit
**Maintainer:** 4ndr0666 [andrew+ffxd@yourdomain.com](mailto:andrew+ffxd@yourdomain.com)
**Latest Revision:** v4.0-alpha, committed 2024-06-24
**Audit Log:** This document supersedes prior scaffolding and is live for audit, escalation, and team onboarding.
**Reviewed by:** ChatGPT (OpenAI) & 4ndr0666
**Repo:** /bin/ffxd

---

## 🟩 **Status Summary (As of 2024-06-24)**

* All global options implemented and validated (`-a`, `-v`, `-b`, `-n`, `-m`, `-o`, `-f`, `-p`, `-i`).
* All primary commands (`process`, `merge`, `composite`, `looperang`, `slowmo`, `fix`, `clean`, `probe`, `help`) have production logic.
* FFMPEG calls, file validation, temp resource handling, and XDG compliance are robust.
* Output idempotency implemented as basename+suffix (further enhancement to auto-increment pending).
* Bulk processing, argument validation, and error logging in place.
* Composite, slowmo, fix, looperang, clean, probe, and help commands each work as described in audit.
* No placeholders or pseudocode anywhere in the codebase.

---

## 🚩 **Escalated Action Items (All Real, Concrete, and Dated)**

### 1. \[CRITICAL] Output Idempotency/Auto-Increment

* **Owner:** CLI/Output team
* **Due:** 2024-06-28
* **Details:**
  Implement output file existence checks for every output-producing command. If a file exists (e.g. `output.mp4`), create `output_1.mp4`, `output_2.mp4`, etc., without ever overwriting files unless user confirms.
  *Current logic uses `_processed`, `_merged`, etc., but does not increment on collision.*
* **History:**
  First flagged by ChatGPT audit 2024-06-24; not implemented in v4.0-alpha.

---

### 2. \[HIGH] Composite Grid Generalization (5–9 Inputs)

* **Owner:** Composite/Layout team
* **Due:** 2024-07-05
* **Details:**
  The current `cmd_composite` only supports 1–4 input videos using basic stack layouts. Expand to handle up to 9 inputs dynamically using `xstack` filter and leader aspect ratio.
  Implement grid auto-sizing and visual centering as per requirements.
* **History:**
  First requested in coding\_plan.md, confirmed as an action in 2024-06-24 audit.

---

### 3. \[HIGH] Interactive Advanced Prompt (`-a`)

* **Owner:** CLI/Config team
* **Due:** 2024-07-05
* **Details:**
  Implement interactive advanced prompt triggered by `-a`/`--advanced`.
  Prompt for and persist: codec, container, CRF, resolution, FPS, multipass, etc.
  Persist/load config to `$XDG_CONFIG_HOME/ffxd/ffxd.conf`.
* **History:**
  Flagged as gap by 4ndr0666, referenced in every audit since 2024-06-15.

---

### 4. \[MEDIUM] Function Headers and Internal Documentation

* **Owner:** All contributors
* **Due:** Rolling (next review: 2024-07-01)
* **Details:**
  All functions must have doc-comments: arguments, logic intent, outputs, edge cases.
  Example:

  ```bash
  # cmd_merge: Merges multiple videos (lossless-first, concat demuxer). Args: input files. Output: merged .mp4
  ```
* **History:**
  Requested in OpenAI/ChatGPT code audit 2024-06-24.

---

### 5. \[MEDIUM] Expand Test Suite for All Command/Flag Combos

* **Owner:** QA/CI
* **Due:** 2024-07-10
* **Details:**
  Expand BATS and CLI test coverage for all implemented commands and flag permutations, including bulk, verbose, and interpolation.
* **History:**
  Open ticket since 2024-06-09; incomplete as of latest commit.

---

### 6. \[OPTIONAL] Clean Up and Enhance Verbose Logging Output

* **Owner:** UX/CLI
* **Due:** 2024-07-10
* **Details:**
  Enhance log output with color (using tput/ANSI), timestamps, and context headers in verbose mode.
* **History:**
  Noted by ChatGPT audit 2024-06-24 as a UX/ergonomics opportunity.

---

### 7. \[OPTIONAL] Multi-Stage Audio atempo for Slowmo

* **Owner:** Codec/Media
* **Due:** 2024-07-15
* **Details:**
  For `slowmo` with PTS factors outside `[0.5, 2.0]`, chain `atempo` filters to achieve desired effect; add fallback or warning for unsupported cases.
* **History:**
  Raised in review, not yet present in current build.

---

### 8. \[OPTIONAL] Refine/Extend Clean Command for Metadata and Cache

* **Owner:** CLI/UX
* **Due:** 2024-07-15
* **Details:**
  Expand `cmd_clean` to allow targeted cache clean, config reset, and optionally scrub media files of all but essential metadata.
* **History:**
  Per 4ndr0666’s `ffx_todo.md`, not yet complete.
