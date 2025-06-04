# CODEX.md

This repository hosts all operational and automation scripts used on my local machine.

---

## Coding Conventions

- Every script must be modular, testable, and XDG-compliant.
- Use `shellcheck` on all `.sh` and `.zsh` files.
- Prefer long-form flags (`--help`) and avoid short flags unless they follow industry convention.
- All scripts must support `--help` and `--dry-run` where appropriate.

---

## Code Standards Enforcement

To ensure long-term maintainability, clarity, and correctness, all contributions and AI-assisted edits must conform to the following **Code Directive**:

### General Enforcement
- Never use placeholders, half-measures, or omitted code lines. Provide all functional logic end-to-end.
- Prioritize local scoping, strict error handling, and complete path resolution.
- Always lint using ShellCheck where applicable. Adhere to XDG Base Directory Specification for file paths.
- Automation must minimize user intervention while safeguarding system integrity. 

### Function Validation Policy
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

### Redirection & Export Guidelines
- Avoid `&>` redirection. Use `>file 2>&1` consistently.
- Validate all exports.
- Avoid unbound or arbitrary variables—concretely assign all values.

### Final Review Protocol
For each script or multi-function revision:
1. Count and disclose the number of functions and lines.
2. Compare with the original to ensure alignment.
3. If a gross mismatch exists, retry up to 3 times before erroring.
4. Defer to human input only with a concise numerical decision list.

> *“Automation reduces toil, but people are still accountable. Adding new toil needs a very strong justification.”*

All revisions should favor **robust automation**, eliminating fragile assumptions or unnecessary user prompts.

---

## Organizational Logic

- `4ndr0tools/`: core bootstrap + customization
- `install/`: self-contained package/system installers
- `maintain/`: automation for backups, cleanup, system hygiene
- `media/`: FFMPEG/media manipulation (lossless-first)
- `security/`: must log proposed changes before execution
- `systemd/`: `systemctl --user` unless root required
- `utilities/`: toolkit grouped by domain (`build`, `chroot`, etc.)

---

## Command Policy

- Use `printf` instead of `echo`, support piping and scripting
- All state-modifying scripts must enforce `sudo` and log actions to `$XDG_DATA_HOME/logs/`
- Scripts must reside in proper folders with prefixed names: `ffx-*`, `exo-*`, `git-*`, etc.

---

## AI Behavior

- Modify only explicitly named files.
- Multi-file changes must update `docs/CHANGELOG.md`
- Summarize complex workflows in `task_outcome.md`
- Never bypass dry-run, lint, or policy enforcement unless explicitly disabled.

---

## Testing Instructions

- Use `scripts/integration_tests.sh` or appropriate subfolder.
- Prefer `bats` or inline test harnesses for shell environments.
- Mock all destructive behavior under dry-run flag.

