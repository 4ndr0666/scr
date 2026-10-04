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


### G13 — Enterprise installer uninstall ownership boundary

An unmanaged invocation link previously caused the uninstall path to ignore the collision and continue deleting the requested installation target. That allowed an explicit uninstall path to remove a directory without proving that its invocation link belonged to 4ndr0pac. The remediation now fails closed when /usr/local/bin/4ndr0pac is a symlink to another target, and the installer GUP gate verifies that both dry-run and real uninstall leave the unrelated target unchanged.


### G14 — Enterprise installer install ownership boundary

The installation path previously refused to overwrite a regular-file invocation collision but would move and replace an unmanaged /usr/local/bin/4ndr0pac symlink. The remediation now verifies an existing symlink resolves to the requested installation before permitting replacement; an unrelated target is rejected in both dry-run and real installation. The installer GUP gate verifies the collision is rejected and neither the unrelated target nor invocation link is mutated.


### G17 — Enterprise installer rollback cleanup failure

The rollback trap previously attempted recovery-backup deletion with an unchecked rm -rf. If that cleanup failed after the original installation had been restored, the transaction returned the original failure without reporting the cleanup failure or retaining an explicit recovery state. The remediation treats rollback-backup cleanup as a checked operation, retains the recovery artifact on failure, and reports the incomplete cleanup while preserving the original transaction status. The installer GUP gate injects a controlled rollback cleanup failure and verifies target restoration, failure reporting, and recovery-artifact retention.

### G16 — Enterprise installer filesystem-boundary ownership

The installer could still accept an existing reserved filesystem directory as the requested installation target when the ownership checks happened to be satisfiable. The remediation rejects filesystem roots and reserved system directories before installation or uninstall transaction processing. The installer GUP gate exercises the reserved-boundary set in dry-run mode and requires fail-closed rejection without filesystem mutation.

### G15 — Enterprise installer target ownership boundary

The installation path previously protected the invocation link from unmanaged replacement but did not prove that an existing installation target belonged to 4ndr0pac. An arbitrary existing directory supplied through `--path` could therefore be moved into rollback storage and replaced.

The remediation now fails closed when an existing target is not a managed 4ndr0pac directory: it must be a real directory, its invocation link must resolve to the requested target, and the managed runtime/GUP payload files must be present. The installer GUP gate verifies both dry-run and real installation reject an unmanaged existing target without mutating the target or creating an invocation link.


### G18 — Enterprise installer uninstall target ownership

The uninstall path previously accepted an existing installation target when the managed invocation link was absent. Because uninstall then moved that target into recovery storage and removed it, a caller-supplied arbitrary directory could be deleted without proving that 4ndr0pac owned it.

The remediation now fails closed when an existing uninstall target lacks the managed invocation link. G18 adds isolated dry-run and real-uninstall coverage and verifies that the unrelated target remains unchanged and no invocation link is created.

The evidence remains limited to the installer transaction harness and does not execute package-manager operations.


### G19 — Enterprise installer path canonicalization

The installer previously masked `readlink -f` failure during installation-path normalization and continued with the uncanonicalized input. Although later filesystem checks could reject some malformed paths, canonicalization failure itself was not a fail-closed validation boundary.

The remediation treats canonicalization as an explicit transaction precondition. A failed `readlink -f` now aborts before installation or uninstall processing, reports the path-validation failure, and leaves the supplied path unchanged. The G19 gate uses an isolated symlink-loop path to force canonicalization failure and verifies explicit rejection without filesystem mutation.

The evidence remains limited to the installer transaction harness and does not execute package-manager operations.


### G20 — Enterprise installer invocation-link proof failure

The installer previously suppressed `readlink` failure while proving ownership of an existing `/usr/local/bin/4ndr0pac` symlink. The comparison still failed closed when inspection returned an empty value, but the ownership-proof dependency failure was masked as an ordinary collision.

The remediation makes invocation-link inspection an explicit precondition. A failed `readlink` now emits a dedicated diagnostic and aborts before installation or uninstall processing. The G20 gate injects an isolated `readlink` failure for the managed invocation path and verifies explicit rejection without mutation for both install and uninstall dry-runs.

The evidence remains limited to the installer transaction harness; it does not execute package-manager operations.


### G21 — Enterprise installer Python payload validation

The installer previously used a `find ... -print -quit | grep -q .` probe under `set -o pipefail` to decide whether Python payload validation was necessary. Because `grep -q` can terminate the pipe before `find` completes, a normal Python-containing payload can produce a SIGPIPE status and cause the conditional to skip validation. This is an avoidable LBYL probe at the payload-validation boundary.

The remediation removes the probe and directly executes Python AST validation through `find -exec`. Python syntax failures now become an explicit validation failure, while a payload containing no Python files requires no Python invocation. The G21 installer gate injects invalid Python into an isolated payload and verifies fail-closed rejection without creating a target.

The evidence remains limited to the installer transaction harness and does not execute package-manager operations.


### G22 — Frontend temporary-artifact cleanup failure

The frontend EXIT cleanup helper previously suppressed failure from its temporary-artifact removal with `|| true`. A cleanup failure could therefore leave temporary artifacts while the process retained its prior success status.

The remediation makes the cleanup operation an explicit fail-closed boundary: removal failure emits a dedicated diagnostic and returns nonzero from the EXIT trap. The Golden Unit injects a targeted `rm` failure and requires the frontend to return the injected status while reporting the cleanup failure.

The evidence remains limited to the isolated frontend harness; it does not execute package-manager operations.


### G23 — Backend cleanup existence probes

The backend used `find -print -quit | grep -q` probes before removing temporary 4ndr0pac artifacts and package-cache transient files. Under `pipefail`, the short-circuit probe can turn a successful match into a SIGPIPE status and is an unnecessary LBYL boundary before the destructive operation.

The remediation executes each cleanup directly. An empty match remains a successful no-op, while a cleanup failure is reported and propagated from the maintenance or repair directive. The backend gap scanner rejects reintroduction of the pipe-based existence probe.

The evidence remains limited to static backend invariants and does not execute package-manager operations.


### G24 — Broken-symlink inspection existence probe

The maintenance directive used `find -print -quit | grep -q` to probe for broken symlinks before performing a second `find`. Under `pipefail`, the short-circuit probe is an unnecessary LBYL boundary and can expose SIGPIPE status from `find` rather than the state being inspected.

The remediation executes the broken-symlink inspection once, treats an inspection failure as an explicit fail-closed error, and renders the captured result without a second probe. The backend gap scanner now detects both the generic cleanup probe and this broken-symlink-specific form.

The evidence remains limited to the maintenance source and static GUP invariants; it does not execute package-manager operations.


### G25 — Pacman consistency diagnostic failure suppression

The maintenance directive executed `pacman -Dk` once to detect repository inconsistencies, then executed it a second time to render diagnostics while suppressing the second invocation with `|| true`. A diagnostic execution failure could therefore be hidden at the error-reporting boundary.

The remediation executes `pacman -Dk` once, captures its output, and renders that captured result when the consistency check fails. The backend gap scanner rejects reintroduction of the masked `pacman -Dk || true` form.

The evidence remains limited to static backend invariants; it does not execute package-manager operations.


### G26 — Pacman local database repair failure suppression

The maintenance repair directive piped pacman-local descriptor discovery through xargs sed -i and suppressed the entire inspection and mutation boundary with || true. A descriptor inspection failure or a failed database rewrite could therefore be reported as successful repair.

The remediation captures descriptor discovery, distinguishes the normal no-match status from inspection failure, and applies the rewrite to each discovered descriptor with explicit failure propagation. The backend gap scanner rejects reintroduction of the masked find/grep/xargs/sed form.

The evidence remains limited to static backend invariants; it does not execute package-manager operations.


### G27 — Pacman DBPath configuration-read failure suppression

The stale database-lock maintenance path parsed DBPath from /etc/pacman.conf with an unconditional || true. If the configuration could not be read or parsed, the failure was converted into the default database path and the maintenance operation could proceed against an unverified location.

The remediation makes the configuration read an explicit fail-closed boundary. A successful read still permits the existing default only when DBPath is absent; an awk/read failure now emits a diagnostic and aborts before lock inspection or removal. The backend gap scanner rejects reintroduction of the masked pacman.conf parsing form.

The evidence remains limited to static backend invariants and does not execute package-manager operations.


### G28 — Pacman CacheDir configuration-read failure suppression

The destructive maintenance path parsed CacheDir from /etc/pacman.conf with an unconditional || true. If the configuration could not be read, the failure was converted into the default cache path and package-cache cleanup could proceed against an unverified location.

The remediation makes the CacheDir configuration read an explicit fail-closed boundary. A successful read still permits the existing default only when CacheDir is absent; a failed read emits a dedicated diagnostic and aborts before cache cleanup. The backend gap scanner rejects reintroduction of the masked CacheDir parsing form.

The evidence remains limited to static backend invariants and does not execute package-manager operations.
