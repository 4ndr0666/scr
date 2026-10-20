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
