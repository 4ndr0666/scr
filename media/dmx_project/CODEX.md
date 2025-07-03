## 0 Executive Abstract & Objectives

The **DMX** video-processing suite currently exists in two branches:

| Branch          | Status       | Unique Add-Ons                                                                                  |
| --------------- | ------------ | ----------------------------------------------------------------------------------------------- |
| `main` (stable) | prod-ready   | Original feature set (15 interactive ops)                                                       |
| `beta`          | experimental | • VapourSynth “Slo-mo” preset<br>• `batch_enhance_video()` pipeline<br>• User-space build paths |

Consolidation is required to deliver **DMX V2**—a single, hardened release that:

1. **Merges** β-only capabilities without regression.
2. **Exposes** all features in the UI/CLI.
3. **Modernises** the default colour theme to *Cyan Glass* (`#15FFFF` on black, translucent accents).
4. **Normalises** configuration discovery (system vs user prefixes).
5. Establishes a **clean ticket ledger** for cross-functional execution, QA, CI/CD, and audit tracking.

The following dossier segments every change into discrete, assignable **tickets**, each with:

* **Title, Objective, Priority, Owner placeholder, Estimate (story points), and unique JIRA-style ID**
* Exhaustive **acceptance criteria**
* **Implementation blueprint** (files, functions, examples)
* **Code, Infra, QA, Docs and Security** subtasks
* **Automated checks** and **roll-back strategy**

A **rubric** for production sign-off is appended (§9), followed by **future-roadmap** proposals (§10).

---

## 1 Glossary (quick reference)

| Term            | Meaning                                                       |
| --------------- | ------------------------------------------------------------- |
| **VP**          | `VideoProcessor` class                                        |
| **UI**          | `UserInterface` class                                         |
| **CFG**         | `~/.config/dmx/config.json`                                   |
| **ANSI**        | Terminal escape sequences for colours                         |
| **CS**          | Colour scheme “Cyan Glass”—FG `#15FFFF`, BG `#000000` (black) |
| **SP**          | Story Points (Fibonacci)                                      |
| **CI-pipeline** | `scr/0-tests/` unit + lint + ShellCheck jobs                  |

---

## 2 Ticket Matrix (master list)

| ID          | Title                                                        | Prio | SP | Blockers |
| ----------- | ------------------------------------------------------------ | ---- | -- | -------- |
| **DMX-101** | Expose *Batch Enhance* in main menu                          | P1   | 3  | —        |
| **DMX-102** | Add VapourSynth **Slo-mo** option grouping                   | P2   | 2  | 101      |
| **DMX-103** | Config path auto-detect & migration dialog                   | P1   | 5  | —        |
| **DMX-104** | Global **Cyan Glass** colour scheme (ANSI + prompt\_toolkit) | P1   | 8  | —        |
| **DMX-105** | Introduce `__version__`, banner, build stamp                 | P3   | 1  | 103      |
| **DMX-106** | Update Help/README/docs to new features                      | P2   | 3  | 101, 104 |
| **DMX-107** | Unit tests for path precedence & batch enhance               | P1   | 5  | 101, 103 |
| **DMX-108** | CI automation for colour-regression snapshots                | P2   | 5  | 104      |
| **DMX-109** | Security review: new default paths, plugin loading           | P1   | 3  | 103      |
| **DMX-110** | QA Regression & Release Candidate sign-off                   | P1   | 8  | All      |

---

## 3 Detailed Ticket Specifications

### DMX-101 Expose **Batch Enhance** Feature

*Priority P1 • 3 SP*

| Section                 | Detail                                                                                                                                                                                                                                                                                                                             |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Goal**                | Provide an interactive entry-point so users can trigger the new `VideoProcessor.batch_enhance_video()` pipeline from the main menu/completer.                                                                                                                                                                                      |
| **Acceptance Criteria** | 1. Main menu lists **“Batch Enhance”** option.<br>2. Selecting triggers prompt → pipeline runs, artifact saved.<br>3. `print_help()` reflects the new option.<br>4. Shell history and logs clearly tag the operation with `BATCH_ENHANCE`.                                                                                         |
| **Code Changes**        | *Files*:<br>• `user_interface.py` (function list)<br>• `video_processor.py` (no functional edits, but ensure method signature matches UI)<br><br>*Add handler*:<br>`python<br>def handle_batch_enhance(self):<br>    video = self.select_single_video()<br>    if video:<br>        self.processor.batch_enhance_video(video)<br>` |
| **Docs**                | Update `README.md` quick-start and man-page.                                                                                                                                                                                                                                                                                       |
| **QA**                  | • Unit: stub video → asserts output file exists.<br>• Manual: run end-to-end on 3 sample clips (SD, FHD, 4K).                                                                                                                                                                                                                      |
| **Security**            | Ensure script injection paths sanitised via `sanitize_filename`.                                                                                                                                                                                                                                                                   |
| **Roll-back**           | Toggle via `ENABLE_BATCH_ENHANCE` env flag (default `true`).                                                                                                                                                                                                                                                                       |

---

### DMX-102 Restructure VapourSynth Menu & **Slo-mo**

*Priority P2 • 2 SP*

| Key Points                                                                             |
| -------------------------------------------------------------------------------------- |
| Group “Frame-rate Conversion” & “Slo-mo” under **Motion** header (indexing preserved). |
| Add explanatory tool-tips in menu printout.                                            |
| Acceptance: selecting “Motion → Slo-mo” calls existing transformation branch.          |

---

### DMX-103 Config Path Auto-Detect & Migration

*Priority P1 • 5 SP*

1. **Bootstrap**: On first run, probe in order:

   1. `$PATH` binaries (`/usr/bin/ffmpeg`),
   2. user-build (`~/bin/ffmpeg`),
   3. existing `CFG` values.
2. If current `CFG` mismatches discovered binary, prompt user:
   *“Detected ffmpeg at /usr/bin/ffmpeg but config points to \~/bin/ffmpeg – update? (y/n)”*
3. Write migrator util `utils/config_migrate.py`.
4. Log old→new mapping.
5. Acceptance: downgrade path results in graceful fallback; no duplicate keys.

---

### DMX-104 **Cyan Glass** Colour Scheme Overhaul

*Priority P1 • 8 SP*

#### 104-A ANSI Layer

* Replace `GREEN` with `CYAN = "\033[38;2;21;255;255m"` (RGB #15FFFF).
* Retain `RED`, `BOLD`, `NC`.
* Introduce `BG_BLACK = "\033[40m"` for banner blocks.
* All `print_status`, `print_warning`, banner outputs wrapped:
  `print(f"{BG_BLACK}{CYAN} ... {NC}")`.

#### 104-B prompt\_toolkit Theme

```python
style = Style.from_dict({
   "completion-menu.completion": "fg:#15ffff bg:#000000",
   "completion-menu.completion.current": "fg:#000000 bg:#15ffff",  # inverted highlight
})
```

*Add alpha “0.80” overlay by emitting `\033[2m` (dim) for unselected items.*

#### 104-C Transparency Note

Transparency in ANSI is terminal-dependent; we simulate via bold/dim toggles. README must caution.

#### 104-D Regression Harness

For every commit touching colours, run `tests/ansi_snapshot.py` capturing stdout glyph map; compare hash.

---

### DMX-105 Version & Build Banner

*Priority P3 • 1 SP*

| Implementation                                                                                                                                 | Example                                                                  |
| ---------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| `__version__ = "2.0.0-beta.{git_hash}"` auto-injected by CI step.<br>`def log_banner(): logger.info(f"DMX {__version__} - cfg:{CONFIG_FILE}")` | On start, file header: `print(f"{BG_BLACK}{CYAN}DMX {__version__}{NC}")` |

---

### DMX-106 Docs & Help

*Priority P2 • 3 SP*

* Update all inline help, man-page, `README.md`.
* Add screenshot of new colour palette (PNG in `docs/assets/`).
* Append CHANGELOG entry `## 2.0.0`.

---

### DMX-107 Unit Tests

*Priority P1 • 5 SP*

| Test ID                   | Focus                      | Method                |
| ------------------------- | -------------------------- | --------------------- |
| `test_cfg_precedence`     | env → cfg → default        | monkeypatch PATH env  |
| `test_batch_enhance_stub` | ensure pipeline returns 0  | use 5-sec colour bars |
| `test_colour_escape`      | verify `CYAN` ANSI present | regex stdout          |

All tests run in GitHub Actions matrix (Ubuntu, Arch).

---

### DMX-108 CI Snapshot for Colours

*Priority P2 • 5 SP*

* Write a GH Action job **`colour-diff.yml`** capturing `python dmx.py --help | aha` -> HTML snapshot; commit to `gh-pages` artefacts so reviewers can visual-diff.

---

### DMX-109 Security Review

*Priority P1 • 3 SP*

* Validate user-supplied paths for `ffms2_plugin` etc.
* Check for path traversal in `tempfile` usages.
* Document threat model for plugin DLL/SO loading (supply-chain).
* Output signed SBOM.

---

### DMX-110 QA Regression & RC Sign-off

*Priority P1 • 8 SP*

| Step                                             | Owner       | Tool                 |
| ------------------------------------------------ | ----------- | -------------------- |
| Functional matrix pass (15 + 2 new ops)          | QA-lead     | TestRail             |
| Colour contrast WCAG AA check                    | UX          | axe-cli              |
| Performance bench (speed-change 4K 60 → 120 FPS) | Perf team   | hyperfine            |
| Security checklist (DMX-109)                     | SecOps      | OpenSCAP             |
| Final gate                                       | Release Eng | GitHub Release Draft |

---

## 4 Cross-Functional Swim-Lanes

| Lane             | Primary Deliverables      |
| ---------------- | ------------------------- |
| **Backend**      | Tickets 101-103, 105, 109 |
| **Frontend/TUI** | 104, 106                  |
| **CI/DevOps**    | 107, 108                  |
| **QA**           | 110                       |
| **Docs**         | 106                       |

---

## 5 Automation & CI/CD Integration

1. **Pre-commit**: `ruff`, `black`, `shellcheck` for embedded bash.
2. **Unit**: pytest + `pytest-cov` ≥ 90 %.
3. **Build**: `make dist` packages tarball + PyPI wheel.
4. **Version bump**: CI reads `VERSION` file; semantic-release plugin.
5. **Artefact retention**: Keep log snapshots 30 days.
6. **Release**: Tag `v2.0.0`; publish binaries & SBOM.

---

## 6 Infrastructure Refactors

* Migrate logs to **dedicated directory per date** `logs/YYYY-MM-DD/video_processing.log`.
* Parameterise ThreadPool `MAX_WORKERS` via `env/flag` for container scaling.
* Provide `docker/Dockerfile` multi-stage (builder → runtime alpine).

---

## 7 Security & Compliance Addenda

* **Plugin sandboxing**: consider `LD_PRELOAD` deny-list.
* **Path sanitisation**: adopt `pathlib.Path.resolve().relative_to()` to forbid `..`.
* **SBOM**: generate CycloneDX JSON (`cdxgen`) on every release.
* **Licences**: verify all VapourSynth plugin licences are compatible (GPL/LGPL).

---

## 8 Approval Rubric (go/no-go)

| Category              | Gate                | Metric                    |
| --------------------- | ------------------- | ------------------------- |
| **Unit Coverage**     | ≥ 90 %              | `coverage xml`            |
| **CI Status**         | green               | GH shorthand              |
| **Colour Contrast**   | WCAG AA small text  | `axe-cli` score ≥ 4.5 : 1 |
| **Performance Regr.** | ± 5 % baseline      | hyperfine                 |
| **Security**          | 0 Critical CVE      | Trivy scan                |
| **Docs**              | Updated & versioned | diff                      |
| **SBOM**              | attached            | Artifact                  |

All gates must pass for Release Candidate to move to GA.

---

## 9 Further Enhancements (Post-V2 Road-Map)

1. **Plugin Marketplace**: dynamic discovery of third-party VapourSynth scripts.
2. **GUI (TUI+)**: leverage `Textual` for richer pseudo-GUI while maintaining terminal footprint.
3. **Preset Manager**: JSON-driven recipe book, shareable between users.
4. **GPU Hardware Encode**: probe NVENC/VAAPI/AMF, offer in menu.
5. **Telemetry (opt-in)**: anonymised usage stats feeding backlog prioritisation.
6. **Localization**: i18n with `gettext` (start with ES/DE).
7. **Docker Compose stack** for micro-service batch cluster (FFmpeg workers).

---

## 10 Conclusion & Next Steps

* **Sprint 0** = Planning & environment setup (CI runners, pre-commit).
* **Sprint 1** targets tickets **101, 103, 104** (critical path).
* **Sprint 2** addresses remaining feature tickets + docs.
* **Hard freeze** after Sprint 2; QA regression (110).
* **Release** `v2.0.0-GA` scheduled **T+6 weeks** from kickoff.

Project leads should now clone this document into the *AGENTS.md* canonical location, create corresponding JIRA tickets, and assign lane owners. A standing “War-room” channel on Slack (#dmx-v2-launch) should be spun up for cross-team comms. Continuous audit logs must reference ticket IDs in every commit message (`git commit -m "DMX-101: add batch handler"`).

---

### ℹ️ Questions, clarifications, or scope-adjustments should be raised as comments on the individual tickets before Sprint 0 concludes.
