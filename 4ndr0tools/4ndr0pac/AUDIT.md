# 4NDR0PAC GUP Audit

## Scope

This audit covers the `4ndr0tools/4ndr0pac` frontend/backend boundary.
The Golden Unit intentionally uses a fake backend and never invokes pacman,
sudo, package helpers, or system mutation paths.

## Safety controls

- Dangerous menu directives are explicitly enumerated in `DIRECTIVES`.
- The same danger classification is applied in interactive and one-shot modes.
- One-shot execution refuses dangerous directives unless the operator enters
  `y` or `yes` at the confirmation prompt.
- `--dry-run` never prompts and never invokes the backend.
- Backend exit status is returned to the caller.
- The frontend refuses a world-writable backend path.
- Backend arguments are passed as an argv vector rather than through a shell
  command string assembled from user input.

## Golden Unit

Run from this directory:

```text
./gup_4ndr0pac.sh
```

The harness proves, against an isolated fake backend:

1. Python and Bash syntax are valid.
2. Exactly five dangerous directives are exposed as confirmation-gated.
3. `Remove Packages` cannot reach the backend after a negative confirmation.
4. A positive confirmation reaches the backend with the expected flag and args.
5. A safe directive propagates its backend status and arguments.
6. `--dry-run` prints the command without invoking the backend.
7. Numeric alias `6` remains protected by the same danger gate.

## Evidence boundary

A successful Golden Unit run proves the frontend control boundary only. It is
not evidence that package-manager operations are safe to execute on a live
Arch Linux installation. Live backend operations require a separate controlled
system test environment.
