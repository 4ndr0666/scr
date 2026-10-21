# GUP Continuity Worklog

Append-only record. Entries must cite Git identities and bounded evidence; conversational recollection is not authority.

## 2026-10-20 — inventory bootstrap

- Task: establish a non-destructive GUP scope register for `4ndr0tools/4ndr0service`.
- Observed main commit: `e00d2ca39ca4b5dd7bf9e5c96d0130e042521360`.
- Observed recursive tree object: `bcc1e9652ca6a45d1f8e6bbc246e01885125e305`.
- Captured service paths: 48 files and 6 directories from the complete, non-truncated Git tree response.
- Source package: uploaded Golden Unit Protocol skill bundle; its six synthetic Git-repository tests passed locally (6/6).
- Scope limit: path/blob inventory only; no claim of semantic baseline, history completeness, or GUP certification.
- State: `BLOCKED_BASELINE_NOT_ESTABLISHED` until refs/history, feature matrix, integration graph, and behavior-preservation evidence are reconciled.

## 2026-10-20 — refs/history observation and broad-radius integration pass

- Main after PR #161 merge: commit `5c6ff8734052e633638325b657c3e29cb48105ed`, tree `98c8f9d5bd30d87b1c50476d88d1cd870fb4fbb2`.
- Git matching-refs observation: 10 branches, zero tags. Full observed branch heads and limitations are recorded in `.gup/evidence/history-observation.json`.
- Compared the retained service-related branches with current main. The service CI-gap branch was 16 commits behind / 0 ahead; pipx fix was 13 behind / 0 ahead; pipx contract tests were 10 behind / 0 ahead; inventory bootstrap branch was 1 behind / 0 ahead. The merged changes are therefore present in main according to the comparison endpoint; stale refs are not evidence of unmerged functionality.
- Observed path history: 42 commits returned for `common.sh` (from 2025-01-17 through 2026-10-20) and 27 for `main.sh` (from 2024-12-03 through 2026-09-26). This is not yet a per-path history/rename/disposition audit for all 48 scope files.
- Added `.gup/evidence/capability-ledger.md` with an initial semantic map, previously fixed defect classes and explicit open findings.
- Added `.gup/evidence/integration-closure-initial.md` with all nine required integration surfaces and a first-pass entry/loading/deployment graph. Every surface remains PARTIAL.
- Source observations include production sourcing of `test/verify_environment.sh`, a possible `controller.sh` / `manage_files.sh` load-order interaction, dynamically discovered service/plugin/view files, config-key writers/readers, systemd path rewriting and duplicated versioned runtime tests. These are investigation targets, not authorization to delete or refactor.
- Existing CI evidence on PR #161: 44 shell scripts syntax-checked; service runtime gate 19/19; pipx inventory regression proof 8 passed / 0 failed; ShellCheck passed. These narrow gates do not establish GUP certification.
- Baseline decision remains `BLOCKED_BASELINE_NOT_ESTABLISHED`. No complete local checkout inventory/status/SHA-256 evidence or all-path semantic comparison exists yet.

## 2026-10-20 — exact service subtree parity

- PR #162 merged as `34f1b65fe671cec1cd8c62667c41eaa73770d840`.
- Compared the service subtree at candidate baseline `e00d2ca39ca4b5dd7bf9e5c96d0130e042521360` with the post-PR #162 commit. Both resolve `4ndr0tools/4ndr0service` to tree `354d670544905ef12622023ded9c561b2b99afa1`.
- The tree comparison reports 54 entries (48 blobs and 6 directories) at each point, with zero added, missing, or changed path/mode/blob entries. Evidence is stored in `.gup/evidence/scope-tree-parity.json`.
- Added a CI step to recompute both subtree identities from the Git object database and verify the recorded parity evidence. This is an immutable historical comparison, not a rule that future service changes must match the baseline.
- Evidence limit: Git tree parity proves exact object-level equality for this scope at these commits; it does not establish semantic correctness, historical completeness, or independent SHA-256 inventory.
- GUP tooling integration is still pending. Package v7.0.1 identity vs v7.0.0 executable metadata remains a known compatibility defect to resolve under isolated regression tests.
- Canonical baseline remains unset; all nine integration surfaces remain PARTIAL.

## 2026-10-20 — exact service subtree parity

- PR #162 merged as `34f1b65fe671cec1cd8c62667c41eaa73770d840`.
- Compared `4ndr0tools/4ndr0service` at baseline candidate `e00d2ca39ca4b5dd7bf9e5c96d0130e042521360` and post-PR #162 commit. Both resolve to subtree `354d670544905ef12622023ded9c561b2b99afa1`.
- Tree comparison reports 54 entries (48 files and 6 directories), zero added paths, zero missing paths, and zero mode/blob changes. Evidence is stored in `.gup/evidence/scope-tree-parity.json`.
- This proves exact object-level equality for the service scope at those commits; it does not prove semantic correctness, complete historical continuity, or an independent SHA-256 inventory.
- GUP tooling integration and v7.0.1/v7.0.0 package-version reconciliation remain outstanding. Canonical baseline remains unset; all nine integration surfaces remain PARTIAL.


## 2026-10-20 — Git-derived historical path audit

- Audit implementation: `.gup/scripts/audit_history_continuity.py`; isolated regression tests: `.gup/tests/test_history_audit.py`.
- Source inventory commit: `e00d2ca39ca4b5dd7bf9e5c96d0130e042521360`; PR branch base/main observation: `b25fc1e53a8c94f7f6f5a5730e1b571bad81f2a4`.
- CI run `39358222503` completed successfully for audit execution, the two synthetic history-disposition tests, the existing scope inventory/parity checks, and the service runtime gate.
- Audit observation: 48 source files and 48 candidate files; 52 historical deleted paths were found under the service scope and all 52 are `UNRESOLVED`. No deletion is treated as authorized retirement.
- CI artifact `gup-service-history-audit`, artifact ID `12236705122`, SHA-256 `c43b1e478b6e420945bea2f1163d6967905bbacef34b937b13732d01f44cea5a`; retention is 30 days from creation.
- The workflow now emits each unresolved deletion record to its logs for review. The report records path history/rename observations and explicitly states that Git history does not prove semantic capability preservation.
- Canonical baseline remains unset. Historical deletion dispositions and semantic preservation review remain blockers; GUP/SUK certification is not claimed.


## 2026-10-20 — GUP v7.0.1 tooling metadata reconciliation

- Finding: uploaded GUP bundle declared v7.0.1 in `SKILL.md` and the v7.0.1 changelog, while `gup_init.py`, `gup_validate.py`, the evidence schema, README, docs, and test fixture still used v7.0.0.
- Reconciled artifact: `gup-v7.0.1-reconciled.zip`, SHA-256 `416dbb20c953808ef15a4ed2dbd14e6c2d782411ed1025be71f1396fe1720cff`. The artifact is delivered separately from this repository commit; it is not claimed to be vendored.
- Changed only version declarations, evidence-contract values, documentation paths/headings, the test evidence fixture, and an added version-consistency regression. Gate logic and historical contract sections were not changed.
- Validation: `python -m unittest discover -s /tmp/gup-v7.0.1-reconciled/tests -v` passed 7/7 tests; `golden_unit_hash.py --selftest` passed 23/23 assertions.
- Evidence: `.gup/evidence/tooling-version-reconciliation.json`.
- Status: `VERSION_METADATA_RECONCILED_ARTIFACT_VALIDATED_NOT_VENDORED`. The out-of-band artifact pin must be compared against the separately delivered digest. This does not close service integration surfaces or establish a canonical baseline; GUP/SUK certification is not claimed.


## 2026-10-20 — exact-blob leads for historical deletions

- Added `.gup/scripts/audit_deleted_blob_matches.py` to compare each historical deleted path's last pre-deletion Git blob identity against the current candidate tree. The output distinguishes byte-identical candidate paths from paths with no exact blob match.
- Added isolated synthetic Git tests at `.gup/tests/test_deleted_blob_matches.py`: exact-blob lead, no-match behavior, and invalid-ref fail-closed behavior.
- Integrated the analysis and tests into `.github/workflows/4ndr0service-gup.yml`; both history reports are uploaded as the `gup-service-history-audit` artifact.
- Safety rule: exact blob identity is only a review lead. It does not prove caller/interface/configuration/runtime equivalence. All 52 historical deletions remain `UNRESOLVED`; no deletion is authorized for retirement.
- Validation status at authoring time: awaiting PR CI execution. No GUP/SUK certification is claimed.


## 2026-10-20 — exact-blob review and CI validation

- PR #166 workflow run [39511741964](https://github.com/4ndr0666/scr/actions/runs/39511741964) passed the scope inventory, subtree parity, existing history audit (2/2 tests), exact-blob scanner (3/3 tests), artifact upload, and service runtime gate (19/19).
- Uploaded artifact ID `12305498141`, SHA-256 `354bd498efa79ae92d67fea61ab9bf34f3af3c6fdeca3633204df282bfb33725`; the repository policy shortened retention to seven days.
- Rename-aware audit: 52 historical deleted paths, all `UNRESOLVED`. No-renames blob scan: 55 raw deleted-path candidates; 2 exact current-blob matches, 53 without exact matches. Three additional raw candidates appear only when rename detection is disabled; counts are deliberately kept distinct.
- Exact-blob review identified `systemd/user/env_maintenance.timer` → `systemd/env_maintenance.timer` (blob `d0b43b5b4a7f5b3077bbe2723883c87007cc9262`) and `test/tools/4ndr0service_env_migrate.sh` → `test/tools/error_mitigations.sh` (blob `ee5c386727db0e7eb8768b5fb84dd9cae37187af`). GitHub commit metadata marks both as zero-content-change renames.
- Semantic finding: current `test/tools/error_mitigations.sh` contains an installer implementation (header says `install.sh`), not an error-mitigation helper suite. The capability ledger was corrected to `UNRESOLVED_ROLE_MISMATCH`; no file was removed or relocated.
- Evidence: `.gup/evidence/deletion-blob-review.md`. Exact blob identity remains non-semantic evidence. Canonical baseline remains unset; all nine integration surfaces remain PARTIAL; GUP/SUK certification is not claimed.


## 2026-10-20 — evidence-output durability hardening

- GUP review found the new blob scanner wrote report output directly, unlike the existing history auditor's atomic evidence write contract.
- Updated `.gup/scripts/audit_deleted_blob_matches.py` to write a same-directory temporary file, flush and `fsync` it, atomically replace the target, `fsync` the directory, and clean up temporary residue on success or failure.
- Added a regression test proving repeated output generation is byte-stable and leaves no temporary files.
- This is a tooling-only correction; no service runtime files or historical dispositions changed. PR CI must validate the final commit before merge.


## 2026-10-20 — final-head GUP validation

- Final code head at validation: `85d2a017a95463cbef4005dcf60cf4332f305c46`.
- GUP run [39512139716](https://github.com/4ndr0666/scr/actions/runs/39512139716) passed: source/candidate inventory and parity, history audit (2/2), blob analysis (4/4, including atomic/idempotent output), artifact upload, and service runtime gate (19/19).
- Final-head history artifact ID `12305948676`, SHA-256 `2cb0c798c6fe1e52840c9bb4d81f72436e64d962bb6a0eec38d296151fd3fd82`, seven-day retention.
- CodeQL Advanced remains in progress at this entry. Do not treat PR #166 as fully cleared until CodeQL completes and all required checks for the final head are successful.
- Findings remain unchanged: 52 rename-aware historical deletions unresolved; 55 no-renames raw candidates, 2 exact-blob leads; canonical baseline unset; all nine integration surfaces PARTIAL; no GUP/SUK certification.


## 2026-10-20 — systemd deployment path integration proof

- Added `test/systemd_installer_runtime.sh` and included it in `test/gup_runtime_gate.sh`; the runtime gate now enumerates 20 named tests.
- GUP run [39518240154](https://github.com/4ndr0666/scr/actions/runs/39518240154) passed at code head `6ffa9a92ec7647279640554691151116ddaab605`, including syntax, source inventory, subtree parity, history audit, exact-blob audit, and runtime gate.
- The isolated systemd test passed with a mocked `systemctl`: flat service/timer discovery, custom root containing spaces, deployed path rewrites, activation command sequence, unchanged source templates, byte-stable rerun, and missing-service generation. It did not touch host systemd.
- Evidence: `.gup/evidence/systemd-installation-closure.md`; capability ledger updated to distinguish mocked runtime proof from host-level behavior.
- Historical timer path `systemd/user/env_maintenance.timer` remains `UNRESOLVED` pending final disposition review despite exact blob identity, Git rename metadata and the targeted path test.
- `test/tools/error_mitigations.sh` remains `UNRESOLVED_ROLE_MISMATCH`: it is an executable installer snapshot, not a helper suite. No explicit invocation was found in GitHub code search, but search absence does not establish unreachability; no execution, move or deletion was performed.
- Canonical baseline unset; 52 rename-aware historical deletions remain unresolved; all nine integration surfaces remain PARTIAL; no GUP/SUK certification.

## 2026-10-21 — CodeQL status-check and runner maintenance

- PR #167 head before this entry: `5a36dc21b93074f50d6d58e394cc9de5c81a9a49`.
- Updated `.github/workflows/codeql.yml` to use `actions/checkout@v5` (Node.js 24-compatible action runtime), pin Linux analysis jobs to `ubuntu-24.04`, and expose `workflow_dispatch` so the default-branch CodeQL baseline can be explicitly refreshed after merge.
- The CodeQL check initially reported `1 configuration not found` for `/language:rust` while the Rust analysis job was still running. After all six language-analysis jobs completed successfully, the same head's CodeQL check updated to success: “No new alerts in code changed by this pull request.” This is observed timing evidence, not a claim that the warning annotations were security findings.
- CodeQL workflow run [39521599718](https://github.com/4ndr0666/scr/actions/runs/39521599718): all six configured language jobs passed. GUP run [39521599757](https://github.com/4ndr0666/scr/actions/runs/39521599757): passed. ShellCheck run [39521599714](https://github.com/4ndr0666/scr/actions/runs/39521599714): passed.
- No service runtime files or historical path dispositions changed. The neutral CodeQL check is resolved on the recorded head; the runner deprecation and `ubuntu-latest` migration warnings are addressed in this workflow.
- Canonical baseline remains unset; 52 rename-aware historical deletions remain unresolved; all nine integration surfaces remain PARTIAL. No GUP/SUK certification is claimed.



## 2026-10-21 — post-merge validation after PR #167

- PR #167 merged as `407924afb16cd97803f88198de8e6e2217618854`; GitHub default branch `main` points to this commit. Commit tree: `61ccd4d50e74ba986bf237bdb80d23ccc90fbfdf`.
- Post-merge GUP workflow [39522409058](https://github.com/4ndr0666/scr/actions/runs/39522409058) completed with conclusion `success`. All seven steps succeeded: Bash syntax, service scope inventory, recorded subtree parity, historical path audit, exact-blob analysis, audit artifact upload, and the service runtime gate.
- Updated `.gup/project.json` to record the observed main commit/tree and bounded post-merge CI evidence. The project remains `BLOCKED_BASELINE_NOT_ESTABLISHED`; candidate and canonical baseline remain null.
- Corrected a stale blocker: the GUP v7.0.1 metadata-reconciled artifact passed its separate local tests and is not vendored here. Repository-level complete-checkout inventory and tool integration remain unproven.
- The successful workflow reran the observational audits only; it does not assign semantic dispositions to historical deletions, prove all nine integration surfaces closed, or establish GUP/SUK certification.
- Next review: inspect the systemd timer path translation and installer-snapshot role mismatch using Git history, current source/caller references, installation copy rules and the new isolated installer test. Preserve `UNRESOLVED` unless the evidence supports a documented disposition; no path is deleted, moved or invoked as part of this review.


## 2026-10-21 — targeted historical path review after PR #167

- Reviewed the two exact-blob historical deletion leads against candidate source, installer copy/dispatch behavior, Git rename metadata, and the post-merge runtime evidence. Added `.gup/evidence/historical-path-review-2026-10-21.md`.
- Timer path: historical `systemd/user/env_maintenance.timer` and current `systemd/env_maintenance.timer` share blob `d0b43b5b4a7f5b3077bbe2723883c87007cc9262`; Git rename metadata reports no content change. Current systemd installer discovers flat `systemd/*.timer`, and `install.sh` points to `systemd/install_env_maintenance.sh`. PR #167's isolated mocked-systemctl test passed post-merge. Historical disposition remains `UNRESOLVED` until complete install/migration and host-runtime boundaries are reviewed and an auditable disposition mechanism exists.
- Installer snapshot: Git commit `0ed45470d981c426a08730b66b7abeacb4a30391` records `test/tools/4ndr0service_env_migrate.sh` → `test/tools/error_mitigations.sh` as a zero-content-change rename. Current file content is an installer, and top-level install syncs the source tree then marks all `.sh` files executable. No explicit in-repository invocation was found in code search; this does not exclude external callers. State remains `UNRESOLVED_ROLE_MISMATCH`; file was not executed, moved, consolidated, or deleted.
- Updated capability ledger with post-merge GUP evidence and corrected stale runtime-gate count/tooling-version blocker wording. The initial integration-closure document remains a historical first-pass record; all nine surfaces remain PARTIAL.
- Post-merge GUP run [39522409058](https://github.com/4ndr0666/scr/actions/runs/39522409058) passed. The rename-aware report still has 52 unresolved historical deletions; the no-renames report still has 55 raw candidates (2 exact-blob leads, 53 without exact matches). Counts remain separate.
- No baseline approval or certification is claimed. The next engineering gap is to make reviewed dispositions machine-readable and validator-enforced, then continue the per-path audit and nine-surface closure without weakening the fail-closed behavior.


## 2026-10-21 — machine-readable historical-disposition register

- PR #168 merged as `92b4c86c1010f4581790f2b4a94472059723809a`; default-branch GUP run [39523204937](https://github.com/4ndr0666/scr/actions/runs/39523204937) passed at this commit. Tree: `8362e5694ccb6e4d25fb4aa21b6055831b182021`.
- Added `.gup/evidence/historical-dispositions.json` with one record for each of the 52 historical deletion paths observed by that run. All 52 remain `UNRESOLVED`; no authorization to retire any path is inferred.
- Each record is tied to the observed deletion commit, contains explicit rationale and a Git commit evidence reference, and preserves the two targeted path reviews as unresolved.
- The history audit now optionally consumes a disposition register and validates protocol identity, source commit, exact path coverage, duplicate/stale entries, deletion-commit identity, rationale/evidence, and status-specific requirements for `PRESERVED`, `TRANSLATED`, and `AUTHORIZED_RETIRED`. CI supplies the register, so missing or malformed entries fail closed.
- Added a JSON Schema and isolated synthetic-Git regression tests for valid unresolved records, missing/stale coverage, unauthorized retirement, translation without a live target or behavior-level test evidence, and mismatched deletion identity.
- The register is a review-tracking control, not closure evidence: 52 paths remain unresolved, canonical baseline remains unset, all nine integration surfaces remain PARTIAL, and no GUP/SUK certification is claimed.


## 2026-10-21 — final-head validation for historical-disposition register

- Final code head before this evidence append: `538b06aeb9237446712db8514951c53ebdd7168c`.
- GUP run [39524287798](https://github.com/4ndr0666/scr/actions/runs/39524287798) passed. The audit reported 48 source files, 49 candidate files, 52 historical deleted paths and 52 unresolved dispositions. Existing history tests passed 2/2; disposition-register tests passed 7/7; exact-blob tests passed 4/4; service runtime gate passed 20/20.
- CodeQL Advanced run [39524292855](https://github.com/4ndr0666/scr/actions/runs/39524292855) passed all six configured language jobs. The GitHub CodeQL status check is success. ShellCheck status is success; the changed-shell-file scan was skipped because this change did not modify service shell files.
- Intermediate CI runs exposed a shell continuation typo, a synthetic test fixture requiring empty commits, and legacy assertions using the old uppercase disposition spelling. Each was corrected; the final recorded head passed the complete GUP and CodeQL suites.
- The register is complete as an inventory, not as semantic closure. All 52 statuses remain `unresolved`; no user-authorized retirement is recorded. Canonical baseline remains unset, all nine integration surfaces remain PARTIAL, and no GUP/SUK certification is claimed.


## 2026-10-21 — post-PR #169 merge and timer path disposition

- PR #169 merged as `34b04e2a8f60f549de5f4041497ab17a9a64be48`; GitHub reports a verified merge signature. Merge tree: `cf8a5f6d1ea6fa17cf9b2b79d210032f12f0e64a`.
- Default-branch GUP run [39526042800](https://github.com/4ndr0666/scr/actions/runs/39526042800) passed all seven workflow steps, including the machine-readable disposition register and the 20-test service runtime gate. ShellCheck run [39526042758](https://github.com/4ndr0666/scr/actions/runs/39526042758) passed. CodeQL Advanced run [39526042799](https://github.com/4ndr0666/scr/actions/runs/39526042799) was still in progress at this evidence capture; final language-job completion must be checked before declaring all merge checks complete.
- Reviewed the timer source-tree transition using Git rename metadata, the current top-level installer dispatch, the systemd installer source-directory discovery, and the isolated runtime test. A deeper check of deletion commit `932754cadc7ded1724422cc30b5efa0051ab3391` found that the deleted timer blob (`005bc0db2c357c5ac099bbac0e00d8ab5414881e`) differs from the later flat-path rename blob (`d0b43b5b4a7f5b3077bbe2723883c87007cc9262`). The deletion commit also added a separate root-level timer blob (`9aa13700327dad487613dee2620c6a93e2b9d617`). The record therefore remains `unresolved`; no translation is inferred across these distinct content episodes.
- The mocked installer test still establishes the current flat-path deployment contract, but it does not prove semantic continuity from the older timer episode or real host scheduling, daemon/permission behavior, full top-level installation transaction, rollback/uninstall, or migration of deployed trees.
- The separate `test/tools/4ndr0service_env_migrate.sh` → `test/tools/error_mitigations.sh` zero-content-change rename remains a role/ownership mismatch and is not in the 52 deletion register because Git records it as a rename. It remains unexecuted and untouched.
- Current history register remains 52 `unresolved` records. Canonical baseline remains unset; all nine integration surfaces remain PARTIAL; no GUP/SUK certification is claimed.


## 2026-10-21 — PR #170 merge verification and installer-snapshot semantic delta

- PR #170 merged as `84a776b967a78555178fd3066ed55a99ffeed5ea`; GitHub reports a verified merge signature and tree `ee030302d26ffeef5c325ace238ff302f9065347`.
- Post-merge GUP run [39528015383](https://github.com/4ndr0666/scr/actions/runs/39528015383) passed. ShellCheck [39528015224](https://github.com/4ndr0666/scr/actions/runs/39528015224) passed. CodeQL Advanced [39528015278](https://github.com/4ndr0666/scr/actions/runs/39528015278) completed successfully across all six configured language jobs.
- The timer disposition remains `unresolved`: the blob removed in commit `932754cadc7ded1724422cc30b5efa0051ab3391` (`005bc0db2c357c5ac099bbac0e00d8ab5414881e`) is distinct from the later flat-path rename blob `d0b43b5b4a7f5b3077bbe2723883c87007cc9262`. The earlier tentative translated paragraph in the review narrative has been removed; the correction and original unresolved finding remain.
- Static review of the installer snapshot found exact identity between its historical blob `ee5c386727db0e7eb8768b5fb84dd9cae37187af` and current `test/tools/error_mitigations.sh`. It is 339 lines and mode `100755`. Current `install.sh` is 294 lines, blob `9107b1dfe8b930c22bc2527142645ba1a1acbf3a`. The snapshot is copied by the top-level source-tree sync and made executable, but code search found no explicit in-repository invocation. External/manual callers remain possible.
- Material static behavior differences are recorded in `.gup/evidence/installer-snapshot-delta-2026-10-21.md`: uninstall/auditd cleanup, `SUDO_USER` home resolution, fatal-vs-warning policies for jq install, symlink, systemd activation and report verification, and dry-run completion exit behavior. No script was executed. No file was moved, edited, consolidated, or deleted.
- Historical register remains 52 `unresolved` records; the timer path has multiple distinct content episodes and remains unresolved. Canonical baseline remains unset; all nine integration surfaces remain PARTIAL; no GUP/SUK certification is claimed.
