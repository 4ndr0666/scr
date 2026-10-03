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

### G7 — Enterprise installer payload integrity

The enterprise installer must reject generated or transient artifacts before deployment and prove that a rejected dry-run cannot create an installation target. The M14 remediation adds a dedicated installer gate that contaminates an isolated payload copy with Python bytecode, verifies fail-closed rejection, then verifies a clean payload dry-run succeeds without filesystem mutation. The gate is executed by the GUP CI workflow.

## Evidence boundary

The existing Golden Unit proves the Python frontend safety boundary with a fake backend. This register extends the proof surface to backend static invariants, but it intentionally does not execute pacman, sudo, firmware updates, bootloader operations, repository installers, or live filesystem mutations.

`gup_gap_scan.sh` fails closed when the registered backend patterns are present. It is a remediation gate, not an assertion that the current backend is already compliant.

## Milestone M2

M2 is complete when G2 and G3 are both eliminated, the gap scanner passes, the existing Golden Unit passes, shell syntax checks pass, and the resulting evidence is recorded in `AUDIT.md`.

### G8 — Enterprise installer stage-commit rollback boundary

The installer must restore an existing installation if the atomic stage-to-target rename fails after the previous target has already been moved into rollback storage. The remediation restores the prior target whenever `_TARGET_MOVED` is true, independently of `_TARGET_INSTALLED`, and the installer GUP gate injects a single controlled stage-commit `mv` failure to prove the preexisting target is restored with its original contents.

### G9 — Enterprise installer rollback failure preservation

Rollback must fail closed when restoration or cleanup operations fail. A failed restoration must not be followed by deletion of the only rollback backup. The remediation reports rollback failure, retains recovery artifacts, and the installer GUP gate injects a controlled restoration failure to verify the backup remains available while the failed target is not silently accepted.

### G10 — Enterprise installer post-commit recovery cleanup

After a deployment has been validated, deletion of the previous-installation recovery backup is itself a transaction boundary. If that cleanup fails, the validated deployment must remain installed, the cleanup failure must propagate, and the recovery backup must be retained rather than being deleted by the EXIT trap. The installer GUP gate injects a controlled rollback-backup removal failure and verifies all three invariants.

### G11 — Enterprise installer uninstall transaction

Uninstall must not delete the managed installation and invocation link as independent live-path operations. The remediation moves each managed object into rollback storage before committing the uninstall, closes the rollback boundary only after both moves succeed, and treats recovery-backup disposal as post-commit cleanup. If backup disposal fails, the installed objects remain absent and the recovery backup is retained so cleanup can be retried without losing the prior installation.


### G12 — Enterprise installer uninstall staging rollback coverage

The uninstall transaction stages the installation before the invocation link. A failure while staging the link must restore the already-staged installation and the original managed link. This gate verifies that intermediate transaction state is recoverable and that uninstall does not leave a partially removed installation.
