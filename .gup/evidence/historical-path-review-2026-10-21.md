# Historical Path Review — Post-PR #167

**Protocol:** GUP 7.0.1  
**Scope:** `4ndr0tools/4ndr0service`  
**Candidate commit:** `407924afb16cd97803f88198de8e6e2217618854`  
**Post-merge workflow:** [39522409058](https://github.com/4ndr0666/scr/actions/runs/39522409058), conclusion `success`  
**Review result:** targeted evidence expanded; both historical path dispositions remain unresolved.

This review distinguishes Git object identity and rename metadata from semantic preservation. It authorizes no removal, relocation, or capability retirement.

## A. User-scoped systemd timer path

- Historical path: `4ndr0tools/4ndr0service/systemd/user/env_maintenance.timer`.
- Candidate path: `4ndr0tools/4ndr0service/systemd/env_maintenance.timer`.
- Historical blob: `d0b43b5b4a7f5b3077bbe2723883c87007cc9262`.
- Prior Git review records the current path as an exact-blob match and GitHub marks the path change as a zero-content-change rename.
- Current loader/deployment implementation: `systemd/install_env_maintenance.sh` sets `SYSTEMD_SRC_DIR` to the installer script's own `systemd/` directory and discovers `*.service` and `*.timer` directly in that directory. The top-level `install.sh` deploys from the suite source tree and invokes the systemd installation path unless `--skip-systemd` is selected.
- Targeted runtime proof: `test/systemd_installer_runtime.sh`, included in `test/gup_runtime_gate.sh`. It runs against a disposable suite tree and a mocked `systemctl`; the post-merge workflow passed. It proves flat timer discovery, custom suite-root rewriting, activation command ordering, source-template preservation and repeat-run byte stability under that mock.
- **Disposition remains `UNRESOLVED`.** The evidence strongly supports a path-translation hypothesis, but the isolated installer test is not proof of a real host's systemd daemon, user permissions, scheduled execution, top-level install/rollback/uninstall transaction, or migration from an already deployed legacy tree. Do not convert the historical deletion to `TRANSLATED` until the complete install/migration contract is reviewed and the disposition is recorded in a form the audit validator consumes.

## B. Historical migration-path name versus installer snapshot

- Historical path: `4ndr0tools/4ndr0service/test/tools/4ndr0service_env_migrate.sh`.
- Candidate path: `4ndr0tools/4ndr0service/test/tools/error_mitigations.sh`.
- Historical blob: `ee5c386727db0e7eb8768b5fb84dd9cae37187af`.
- GitHub commit `0ed45470d981c426a08730b66b7abeacb4a30391` records the rename with zero additions, deletions or content changes.
- The candidate file's header says `File: install.sh`; its body contains installer argument parsing, privileged filesystem mutation, install/uninstall, migration, rollback and optional systemd deployment. It is not a mitigation-test helper.
- The top-level installer syncs the source tree with `rsync -av --delete` when rsync exists; its fallback copies non-hidden source-tree entries. It then makes `.sh` payloads executable. Thus the snapshot is included in the deployed suite tree; this is not merely a file omitted from packaging.
- GitHub code search found no explicit in-repository invocation of `test/tools/error_mitigations.sh`, but absence from indexed text is not proof of unreachability. External operators or scripts may invoke the installed path; the snapshot could also be a stale alternate installer with independent compatibility expectations.
- **Disposition remains `UNRESOLVED_ROLE_MISMATCH`.** Do not execute the file, add it to the runtime gate, move it, consolidate it with `install.sh`, or delete it as part of this audit. Next evidence must establish ownership, documented external entry points, and whether its behavior differs from the current installer in ways relied on by users.

## Validation and limits

- Post-merge GUP run [39522409058](https://github.com/4ndr0666/scr/actions/runs/39522409058) passed all seven steps, including both history audits and the 20-test service runtime gate.
- These audit scripts intentionally leave all historical deletion records unresolved; this narrative does not alter their machine-readable classifications.
- The rename-aware audit still reports 52 historical deleted paths. The no-renames scan still uses a different 55-candidate population (2 exact-blob leads and 53 without exact matches); these counts must not be combined.
- Canonical baseline remains unset. All nine integration surfaces remain `PARTIAL`. No GUP or SUK certification is claimed.


## 2026-10-21 — bounded disposition decision for historical timer path

**Disposition:** `translated`, scoped to repository source-tree placement and installer discovery. This is not a claim of end-to-end host runtime closure.

- Historical path: `4ndr0tools/4ndr0service/systemd/user/env_maintenance.timer`.
- Current target: `4ndr0tools/4ndr0service/systemd/env_maintenance.timer`.
- Git commit [c2a617e2d06584be51dbd6cd4c30706cde8856b8](https://github.com/4ndr0666/scr/commit/c2a617e2d06584be51dbd6cd4c30706cde8856b8) records the path as a rename with zero additions/deletions and blob `d0b43b5b4a7f5b3077bbe2723883c87007cc9262`. This establishes exact content continuity for the template at that transition.
- The current `systemd/install_env_maintenance.sh` resolves its source directory from its own location and discovers `*.service` and `*.timer` in the flat `systemd/` directory. Top-level `install.sh` mirrors the suite source tree and invokes that installer unless `--skip-systemd` is selected.
- `test/systemd_installer_runtime.sh` runs in a disposable tree with mocked `systemctl`. It verifies flat template discovery, deployment to the user unit directory, custom suite-root rewrites, daily schedule content, source-template preservation, activation command ordering, and byte-stable repeated deployment. The post-merge GUP run [39526042800](https://github.com/4ndr0666/scr/actions/runs/39526042800) passed this test through the 20-test runtime gate.
- The register now marks this historical source path `translated` and binds it to the live target and behavior test, satisfying the validator's minimum translation-evidence contract.

**Explicit limits remain:** no real systemd daemon was invoked; host user/session permissions, actual scheduled execution, full top-level install transaction, rollback/uninstall, and migration of pre-existing deployed trees are not proven by the isolated test. Those remain integration-closure work and are not implied by this path-level disposition. No service file was changed, moved, deleted, or executed during the review.


## 2026-10-21 — correction: timer path has multiple content episodes

A deeper inspection of deletion commit [932754cadc7ded1724422cc30b5efa0051ab3391](https://github.com/4ndr0666/scr/commit/932754cadc7ded1724422cc30b5efa0051ab3391) invalidates the assumption that the current flat timer is an exact-blob successor to the historical deletion recorded in the register.

- That deletion commit removed `systemd/user/env_maintenance.timer` with blob `005bc0db2c357c5ac099bbac0e00d8ab5414881e`. Its content described daily environment verification and explicitly set `Unit=env_maintenance.service`.
- The same commit added a different path, `4ndr0service/env_maintenance.timer`, with blob `9aa13700327dad487613dee2620c6a93e2b9d617`.
- Later, commit [c2a617e2d06584be51dbd6cd4c30706cde8856b8](https://github.com/4ndr0666/scr/commit/c2a617e2d06584be51dbd6cd4c30706cde8856b8) records a zero-content-change rename from a later incarnation of `systemd/user/env_maintenance.timer` to `systemd/env_maintenance.timer`, blob `d0b43b5b4a7f5b3077bbe2723883c87007cc9262`. That blob is not the blob removed by the earlier deletion commit.
- The current installer and its isolated runtime test prove the later flat-path discovery/deployment behavior. They do not prove that the earlier deleted timer's specific semantics were preserved through the intervening path/content changes.

**Corrected disposition: `unresolved`.** The register does not mark the old path translated. The earlier append-only note's tentative translation decision is superseded by this correction; no service file was modified. Next review must trace the intermediate commits and service/timer pairing, including the root-level timer introduced in the deletion commit. Real host systemd behavior remains outside the current mock-based test boundary.
