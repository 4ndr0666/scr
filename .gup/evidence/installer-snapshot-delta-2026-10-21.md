# Installer Snapshot Delta Review — 2026-10-21

**Protocol:** GUP 7.0.1  
**Scope:** `4ndr0tools/4ndr0service`  
**Candidate:** `84a776b967a78555178fd3066ed55a99ffeed5ea`  
**Disposition:** `UNRESOLVED_ROLE_MISMATCH` — no change authorization inferred.

## Identity and deployment reach

- Historical path: `test/tools/4ndr0service_env_migrate.sh`.
- Rename commit: [`0ed45470d981c426a08730b66b7abeacb4a30391`](https://github.com/4ndr0666/scr/commit/0ed45470d981c426a08730b66b7abeacb4a30391), recorded as a rename with zero additions/deletions/changes.
- Historical/current snapshot blob: `ee5c386727db0e7eb8768b5fb84dd9cae37187af`; GitHub blob contents and current `test/tools/error_mitigations.sh` content compared byte-for-byte equal. The current path is mode `100755` in the GUP scope inventory.
- Snapshot size: 339 lines. Current `install.sh`: 294 lines, blob `9107b1dfe8b930c22bc2527142645ba1a1acbf3a`.
- Both headers say `File: install.sh`; the snapshot is an installer implementation, not a mitigation helper.
- Top-level `install.sh` copies the suite source tree to the target (rsync path excludes `.git/`, `__pycache__/`, `*.bak`, `.gemini/`, and `.github/`; fallback copies non-hidden top-level entries) and makes copied `.sh` files executable. Therefore the snapshot is deployed under the suite's `test/tools/` path.
- Repository code search found no explicit invocation of `test/tools/error_mitigations.sh`. This does not establish that it is unreachable: users, external automation, or installed-suite operators may invoke it by path.

## Static behavior differences against current `install.sh`

The scripts were read and compared as source text only. Neither was executed during this review.

| Concern | Historical snapshot at `test/tools/error_mitigations.sh` | Current `install.sh` | GUP implication |
|---|---|---|---|
| Uninstall / auditd | Removes suite, symlink, locks and user units; no auditd rule removal/reload path. | Also removes `/etc/audit/rules.d/4ndr0service.rules` and attempts `augenrules --load` or `auditctl -D`. | Different uninstall side effects; cannot treat as interchangeable. |
| User home when invoked through sudo | User-unit path uses `${XDG_CONFIG_HOME:-$HOME/.config}`; no `getent` resolution of `SUDO_USER` home in this block. | Resolves `SUDO_USER` home with `getent passwd` and uses it for systemd paths; sets `HOME` for downstream commands. | Different user/session path behavior. |
| Automatic jq installation | Logs a warning and continues if `pacman -S jq` fails. | Logs an error and exits nonzero if installation fails. | Different failure policy and install outcome. |
| Invocation symlink | Logs a warning and continues if symlink creation fails. | Logs an error and exits nonzero. | Different command availability guarantee. |
| Systemd activation | Logs a warning and continues if unit installation/activation fails. | Logs an error and exits nonzero, invoking the rollback trap when armed. | Different install transaction/rollback behavior. |
| Initial report verification | Warns and continues when `main.sh --report` fails. | Logs an error and exits nonzero. | Different verification and rollback semantics. |
| Dry-run completion | Ends with a conditional log expression; when `DRY_RUN=true`, the condition is false and the final list can leave a nonzero status under `set -e`. | Explicit dry-run completion branch and `exit 0`. | Current version has an explicit fix for scripted dry-run success. |
| Rollback guard | Contains the D-18 source-directory self-removal guard and safe-prefix restriction. | Contains the corresponding source-directory guard and safe-prefix restriction. | These protections are present in both; do not lose them during any future consolidation. |

## Decision and constraints

- Keep `test/tools/error_mitigations.sh` unchanged and executable until ownership, supported entry points and compatibility expectations are established.
- Do not run it, include it in a runtime test, rename it, consolidate it with `install.sh`, or retire it in this audit.
- The static deltas are evidence of behavioral divergence, not proof of which version external callers expect. No disposition beyond `UNRESOLVED_ROLE_MISMATCH` is justified.
- The timer historical path remains `unresolved` because the earlier deleted timer blob differs from the later rename blob; the current flat-path runtime test does not bridge that history gap.
- Canonical baseline remains unset; all nine integration surfaces remain PARTIAL. No GUP/SUK certification is claimed.
