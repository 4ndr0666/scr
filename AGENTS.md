# CODEX.md

This repository hosts all operational and automation scripts used on my local machine.

---

## Coding Conventions

- Every script must be modular, testable, and XDG-compliant.
- Use `shellcheck` and `shfmt` on all shellscripts.
- Prefer long-form flags (`--help`) and avoid short flags unless they follow industry convention.
- All scripts must support `--help` and `--dry-run` where appropriate.

---

## Code Standards Enforcement

To ensure long-term maintainability, clarity, and correctness, all contributions and AI-assisted edits must conform to the following **Code Directive**:

---

## General Enforcement

- Never use placeholders, half-measures, or omitted code lines. Provide all functional logic end-to-end.
- Prioritize local scoping, strict error handling, and complete path resolution.
- Always lint using ShellCheck where applicable. Adhere to XDG Base Directory Specification for file paths.
- Automation must minimize user intervention while safeguarding system integrity.
- All files must be cleaned of CODEX merge artifacts before any commit or pull request merge.
- Use the utility: `0-tests/codex-merge-clean.sh <file ...>` to ensure no `<<<<<<<<<<<<<<<<<<<CODEX_`, `=========================`, or `>>>>>>>>>>>>>>>>>Main` blocks remain.
- Run this tool after CODEX-assisted merges, and before lint, test, or commit stages.

---

## Function Validation Policy

All functions must be:
- **Well-defined and fully implemented**
- **Idempotent** and **accessible**
- **Logically isolated** with explicit error capture
- **Variable declarations separate from assignments**
- **Free from ambiguity, newlines, extraneous input, or bad splitting**
- **Free of cyclomatic complexity**, using clear flow constructs

Every function must explicitly check:
- Return status of critical commands
- Input/output validations
- File existence and permission conditions

---

## Redirection & Export Guidelines

- Avoid `&>` redirection. Use `>file 2>&1` consistently.
- Validate all exports.
- Avoid unbound or arbitrary variables—concretely assign all values.

---

## Final Review Protocol

For each script or multi-function revision:
1. Count and disclose the number of functions and lines.
2. Compare with the original to ensure alignment.
3. If a gross mismatch exists, retry up to 3 times before erroring.
4. Defer to human input only with a concise numerical decision list.
5. Before commit or PR merge, run `0-tests/codex-merge-clean.sh` on all changed files to remove leftover merge annotations. Reject any revision where these remain present.

# === OPTIONAL PRE-COMMIT HOOK ===
#
##!/usr/bin/env bash
#set -e
## Auto-clean all files staged for commit
#
#for f in $(git diff --cached --name-only); do
#    [ -f "$f" ] && 0-tests/codex-merge-clean.sh "$f"
#done
#git add .
# ------------------------------------

> *“Automation reduces toil, but people are still accountable. Adding new toil needs a very strong justification.”*

All revisions should favor **robust automation**, eliminating fragile assumptions or unnecessary user prompts.

---

## Organizational Logic

- `0-tests/`: testing + diagnostics/ codex utilities
- `4ndr0tools/`: core bootstrap + customization.
- `install/`: self-contained package/system installers.
- `maintain/`: automation for backups, cleanup, system hygiene.
- `media/`: FFMPEG/media manipulation (lossless-first).
- `security/`: handles permissions, gpg, networking and firewalls.
- `systemd/`: Arch-based unit management. Usee `systemctl --user` unless root required.
- `utilities/`: custom scripts for sysadmin tasks grouped by domain (`build`, `chroot`, etc.).

---

## Testing Instructions

- Use `bats` or inline test harnesses where feasible.
- Mock destructive commands in dry-run mode.

---

## Command Policy

- Use `printf` over `echo`, support non-interactive and piped use.
- For scripts that modify system state, enforce `sudo` validation and log actions to `$XDG_DATA_HOME/logs/`.
- All newly generated scripts must live in the appropriate category folder and be prefixed clearly (e.g., `ffx-*`, `exo-*`, `git-*`).


---

## AI Behavior

- Only make changes to scripts explicitly named or listed in the task prompt.
- For multi-file changes, maintain a clear changelog in `0-tests/CHANGELOG.md`.
- Write `task_outcome.md` to summarize any multi-step operations for review.
- Never bypass dry-run, lint, or policy enforcement unless explicitly disabled.
