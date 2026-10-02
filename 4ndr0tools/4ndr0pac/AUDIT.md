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

## M14 enterprise installer payload gate

The installer gate uses an isolated copy of the shipped payload. It injects generated Python bytecode, requires the installer dry-run to reject the contaminated payload, verifies that no target is created, removes the injected artifacts, and then requires a clean dry-run to succeed without creating a target. This converts the M14-R1 manual oracle into a repository-resident GUP regression gate.

The gate does not execute a real deployment and therefore does not establish proof for live package-manager or filesystem operations beyond the dry-run boundary.

## Evidence boundary

A successful Golden Unit run proves the frontend control boundary only. It is
not evidence that package-manager operations are safe to execute on a live
Arch Linux installation. Live backend operations require a separate controlled
system test environment.

## M2 backend gap closure

The registered backend gaps G2 and G3 were remediated on `gup/4ndr0pac-gap-mitigation-2`.

- G2: fixed lifecycle sleeps were removed from the reflector and NTP recovery paths; the remaining one-second delay is only interactive invalid-option UI pacing.
- G3: the recovery path no longer edits `/etc/pacman.conf` or creates `/etc/pacman.conf.backup`. It derives an isolated temporary pacman configuration, restricts it to mode 0600, passes it explicitly with `--config`, and removes it with a subshell EXIT trap.
- Backend gap scanner: `gup_gap_scan.sh` is part of the CI workflow and fails closed on the registered G2/G3 patterns.
- Golden Unit: `gup_4ndr0pac.sh` remains the frontend safety-boundary test and is executed by the same CI workflow.
- Local verification recorded for this remediation: Bash syntax check, `git diff --check`, fixed-sleep scan, and G3 invariant scan completed without findings.

The evidence boundary remains unchanged: these checks do not constitute authorization or proof for uncontrolled live package-manager operations.

## Superset semantic review

The remediation was reviewed against the preceding stable 4ndr0pac v1.6.0 backend and frontend feature inventory.

- All 36 backend functions present in the stable backend remain present.
- The one-shot backend dispatch aliases are unchanged.
- The frontend directive inventory remains intact, including all confirmation-gated operations.
- The v1.6.0 fixes for Topgrade dispatch, dependency-tree aliases, flag forwarding, stale database-lock handling, guarded cache tooling, pamac translation, and read-only analysis remain present.
- No fixed lifecycle sleep was reintroduced.
- The recovery path remains isolated from the live /etc/pacman.conf.

### Semantic hardening completed

- Recovery configuration generation now replaces every active SigLevel directive in the copied configuration with SigLevel = Never, including the normal [options] directive and repository-local overrides. If [options] is absent, the isolated configuration receives an explicit [options] section.
- Keyring package names are normalized from package names ending in -keyring to the keyring basenames expected by pacman-key --populate.
- Broken pacman keyring deletion is fail-closed; a failed destructive cleanup aborts keyring repair rather than being masked.
- Desktop-environment removal retains user configuration when package removal fails.
- Cleanup and optional subsystem failures are reported explicitly instead of being presented as successful completion.
- Mirror fallback and orphan-query failures now have explicit fallback states.
- The mirror-repair package-database cleanup uses xargs -r so an empty match cannot invoke sed without targets.

Current Arch documentation confirms that pacman --config selects an alternate configuration, SigLevel = Never suppresses signature checking, repository-specific SigLevel settings override the global default, and pacman-key --populate accepts keyring basenames from /usr/share/pacman/keyrings. [Arch pacman(8), pacman.conf(5), pacman-key(8)]

These semantic checks are supplemental to the Golden Unit and backend gap scanner; neither constitutes authorization for uncontrolled live package-manager execution.
