# Historical Deletion Blob Review — Candidate Leads

**Protocol:** GUP 7.0.1  
**Scope:** `4ndr0tools/4ndr0service`  
**Review state:** `EVIDENCE_EXPANDED — DISPOSITIONS STILL UNRESOLVED`  
**CI run:** [39511741964](https://github.com/4ndr0666/scr/actions/runs/39511741964)  
**Artifact SHA-256:** `354bd498efa79ae92d67fea61ab9bf34f3af3c6fdeca3633204df282bfb33725`

## Counts and interpretation

- The rename-aware history audit continues to report **52** historical deleted paths absent from the candidate. All 52 remain `UNRESOLVED`.
- The new blob scanner deliberately runs Git history with rename detection disabled to avoid hiding byte-identical rename candidates. It reports **55** raw historical deleted path candidates absent from the candidate: **2** have an exact current-blob match and **53** have no exact blob match.
- The three additional paths visible only in the raw no-renames scan are:
  - `4ndr0tools/4ndr0service/env_maintenance.service`
  - `4ndr0tools/4ndr0service/env_maintenance.timer`
  - `4ndr0tools/4ndr0service/test/tools/4ndr0service_env_migrate.sh`
- These counts are intentionally not merged into one disposition total: the reports use different rename-detection semantics. Exact blob identity is a review lead, not semantic proof. No historical deletion is authorized for retirement.

## Exact-blob candidates

### 1. User-scoped systemd timer template

- Historical path: `4ndr0tools/4ndr0service/systemd/user/env_maintenance.timer`
- Current exact-blob match: `4ndr0tools/4ndr0service/systemd/env_maintenance.timer`
- Blob SHA: `d0b43b5b4a7f5b3077bbe2723883c87007cc9262`
- Historical commit: `c2a617e2d06584be51dbd6cd4c30706cde8856b8`
- GitHub commit metadata explicitly records a rename from the historical path to the current path with zero content changes.
- Current integration evidence: `systemd/install_env_maintenance.sh` sets `SYSTEMD_SRC_DIR="$_SCRIPT_DIR"` and deploys `"$SYSTEMD_SRC_DIR"/*.timer` to `$XDG_CONFIG_HOME/systemd/user`. With the installer in `systemd/`, the flat current template path is consistent with this loader/deployment path.
- Disposition: `UNRESOLVED`. Exact blob and rename metadata support a translation candidate, but end-to-end install/migration/runtime proof is still required before recording `TRANSLATED`.

### 2. Historical migration-path name now points to an installer snapshot

- Historical path: `4ndr0tools/4ndr0service/test/tools/4ndr0service_env_migrate.sh`
- Current exact-blob match: `4ndr0tools/4ndr0service/test/tools/error_mitigations.sh`
- Blob SHA: `ee5c386727db0e7eb8768b5fb84dd9cae37187af`
- Historical commit: `0ed45470d981c426a08730b66b7abeacb4a30391`
- GitHub commit metadata explicitly records a rename to `error_mitigations.sh` with zero content changes.
- Semantic warning: the current file header identifies its content as `install.sh`; the body implements installation, migration, systemd deployment and rollback behavior. It is not an error-mitigation helper suite as the previous capability ledger row claimed. The ledger has been corrected to reflect the observed role mismatch.
- Disposition: `UNRESOLVED_ROLE_MISMATCH`. Do not delete, relocate, invoke, or consolidate this file until its callers, intended ownership, install-copy behavior and relationship to the canonical `install.sh` are established. This finding requires explicit caller and deployment review.

## CI validation

Run `39511741964` passed:
- source/candidate scope inventory and subtree parity checks;
- existing history audit and its 2 synthetic tests;
- new blob continuity scan and 3 synthetic tests (exact match, no exact match, invalid ref fail-closed);
- existing service runtime gate, **19/19**.

The uploaded artifact contains both JSON reports. Its retention is seven days due to repository policy. The report digest identifies the ZIP artifact, not the extracted JSON files.

## Remaining work

1. Trace references, dynamic discovery, package/install copy behavior, and runtime callers for both exact-blob candidates.
2. Add targeted install/runtime regression coverage for the timer template path before assigning a final disposition.
3. Resolve the three raw no-renames-only candidates and reconcile the 52-path rename-aware audit with Git's rename metadata without suppressing evidence.
4. Continue all-path semantic capability review and nine-surface integration closure. Canonical baseline remains unset; no GUP/SUK certification is claimed.
