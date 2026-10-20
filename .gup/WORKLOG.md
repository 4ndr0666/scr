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
