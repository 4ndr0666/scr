# CODEX.md

This repository hosts all operational and automation scripts used on my local machine.

## Coding Conventions

- Every script should be modular, testable, and XDG-compliant.
- Use `shellcheck` on all `.sh` and `.zsh` files.
- Prefer long-form flags (`--help`) and avoid short flags unless they follow industry convention.
- All scripts must support `--help` and `--dry-run` where appropriate.

## Organizational Logic

- Scripts in `4ndr0tools/` are core bootstrap and customization utilities.
- `install/` contains package or system installers; each subfolder should be self-contained.
- `maintain/` holds automation for backups, cleanup, and ongoing system maintenance.
- `media/` is a sandbox for FFMPEG and multimedia manipulation. Always preserve lossless workflows unless lossy is specified.
- `security/` scripts must never make silent modifications. Always log proposed changes before execution.
- `systemd/` scripts are bound to Arch-based unit management. Use `systemctl --user` unless root is explicitly required.
- `utilities/` is a general-purpose toolkit grouped by domain (`build`, `chroot`, `sysadmin`, etc.)

## Command Policy

- Use `printf` over `echo`, support non-interactive and piped use.
- For scripts that modify the system state, enforce `sudo` validation and log actions to `$XDG_DATA_HOME/logs/`.
- All newly generated scripts must live in the appropriate category folder and be prefixed clearly (e.g., `ffx-*`, `exo-*`, `git-*`).

## AI Behavior

- Only make changes to scripts explicitly named or listed in the task prompt.
- For multi-file changes, maintain a clear changelog in `docs/CHANGELOG.md`.
- Write `task_outcome.md` to summarize any multi-step operations for review.

## Testing Instructions

- Place all validation scripts in `scripts/integration_tests.sh` or the relevant test folder.
- Use `bats` or inline test harnesses where feasible.
- Mock destructive commands in dry-run mode.

