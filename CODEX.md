# CODEX.md

**Work Order: Shell Script Remediation (pre-commit & ShellCheck)**

---

## Scope

This task applies only to files listed as failing in the attached pre-commit/ShellCheck findings and *explicitly named* in this order.
**Do not modify any scripts outside those referenced in the current work order.**

---

## Directives (per CODEX.md & AGENTS.md)

### General

* All code changes must be full, explicit, and in-place. No placeholders or omitted logic.
* All scripts must be modular, XDG-compliant, and strictly pass `shellcheck` and `shfmt`.
* All revisions must implement `--help` and `--dry-run` where relevant.
* *All revisions must be cleaned of merge artifacts with*
  `0-tests/codex-merge-clean.sh <file ...>`
  *before lint, test, or commit.*

### Coding Standards

* Quote all variables, especially in command arguments and redirections.
* Use long-form flags (e.g., `--help`), avoid short flags unless standard.
* Prefer `printf` over `echo`; all output must be non-interactive/pipeline-safe.
* Variable declarations and assignments must be separate.
* Avoid cyclomatic complexity: use clear, logical, testable functions.
* Strict error handling (`set -euo pipefail`); check all critical command returns.
* Validate input/output and check file existence/permissions.
* Avoid ambiguous constructs, placeholder lines, or unquoted expansions.
* **Redirection:** No use of `&>`; always `>file 2>&1`.
* No unbound/arbitrary variables; all variables must be assigned.
* All exports must be validated.
* Satisfy XDG Base Directory requirements for any file path handling.
* For all scripts that touch the filesystem, enforce dry-run and logging to `$XDG_DATA_HOME/logs/`.
* All scripts must be linted via `shellcheck` (no errors/warnings) and formatted with `shfmt`.

### Function Validation

* Each function must be:

  * Idempotent, logically isolated, explicitly error-handling.
  * Free of ambiguity, unnecessary newlines, or improper word splitting.
  * Disclose function count and total script line count after revision.
  * Compare with original; on gross mismatch, retry up to 3 times.

---

## Task Steps

1. **Review shellcheck/pre-commit findings for all listed scripts.**
2. For each issue, apply remediation according to the Coding Standards above.
3. Remove all CODEX or merge artifact markers before proceeding.
4. Validate scripts pass `shellcheck` and `shfmt` with zero warnings or errors.
5. Ensure all variable assignments, quoting, and control structures are correct and robust.
6. For any ambiguity or policy conflict, document and justify in a comment in the script and in `CODEX.md`.
7. Update or add test cases (preferably with `bats`) as feasible.
8. Write a summary of changes to `0-tests/task_outcome.md` and update `0-tests/CHANGELOG.md` with per-script entries.
9. Before finalizing, disclose the number of functions and total line count for each revised script.
10. **Do not bypass any lint, dry-run, or policy enforcement steps.**

---

## Success Criteria

* All targeted scripts pass `pre-commit run --all-files` and `shellcheck` cleanly.
* All code changes strictly follow AGENTS.md and this CODEX.md.
* No placeholders or omitted sections; all functional logic is present and validated.
* All changes and any exceptions are documented as per instructions above.

---

**End of Work Order**
