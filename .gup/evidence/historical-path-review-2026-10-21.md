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
