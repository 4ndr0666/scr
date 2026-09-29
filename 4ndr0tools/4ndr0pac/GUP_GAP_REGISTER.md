# 4ndr0pac GUP Gap Register

Baseline: `main` after GUP remediation PR #126.

## Closed gaps

No registered GUP gaps remain in the M2/M3 backend scope.


### G4 — Recovery configuration precedence

The isolated recovery configuration previously inserted `SigLevel = Never` before the first section. Because pacman processes configuration top-to-bottom and repository-specific settings override the global default, that construction could leave the normal `[options]` setting or repository-local `SigLevel` effective. The remediation now rewrites active `SigLevel` directives in the isolated copy and ensures `[options]` contains `SigLevel = Never`.

### G5 — Keyring population target normalization

The prior `${keyrings[@]/#/-keyring}` expansion prepended `-keyring` to package names. The remediation strips the package suffix with `${keyrings[@]%-keyring}`, matching pacman-key keyring basenames.

### G6 — Destructive failure propagation

Broken keyring removal, orphan removal, desktop-environment removal, cleanup operations, and optional subsystem refreshes no longer silently convert actionable failures into success states.

### G2 — Fixed-delay lifecycle synchronization

The Bash backend previously contained fixed sleeps coupled to system lifecycle operations:

- reflector completion followed by `sleep 10` before `pacman -Syy` in `func_fix`;
- reflector completion followed by `sleep 3` before `pacman -Syyuu` in `func_m`;
- `ntpd -qg` followed by `sleep 10` before `hwclock -w` in `func_fix`.

These delays do not establish a state predicate. The remediation is to remove the sleeps and rely on the successful completion of the preceding command or an explicit readiness predicate where one is actually required.

### G3 — Temporary global signature-policy weakening

`func_fix` previously rewrote `/etc/pacman.conf` to `SigLevel = Never` and relied on an EXIT trap plus normal-path restoration. This is not equivalent to an atomic scoped configuration override: an uncatchable process termination can leave the system in a weakened verification state.

The remediation is to stop editing the live global configuration for this recovery path. Use a temporary, isolated pacman configuration/keyring context or another scoped mechanism that cannot persist a weaker global signature policy.

## Evidence boundary

The existing Golden Unit proves the Python frontend safety boundary with a fake backend. This register extends the proof surface to backend static invariants, but it intentionally does not execute pacman, sudo, firmware updates, bootloader operations, repository installers, or live filesystem mutations.

`gup_gap_scan.sh` fails closed when the registered backend patterns are present. It is a remediation gate, not an assertion that the current backend is already compliant.

## Milestone M2

M2 is complete when G2 and G3 are both eliminated, the gap scanner passes, the existing Golden Unit passes, shell syntax checks pass, and the resulting evidence is recorded in `AUDIT.md`.
