# Project execution contract

These are standing instructions for Codex agents working in this repository.
Read this file before starting or resuming work. Follow applicable nested
AGENTS.md files as well. This file does not override platform requirements.

## Execute the work

Treat requests to audit, mitigate, repair, integrate, or continue as instructions
to implement and verify the work. Continue autonomously through every available
step until the requested outcome is achieved or a concrete external dependency
prevents further execution.

Do not substitute plans, reports, gap registers, evidence pages, or repeated
checkpoints for implementation. Those artifacts support the work; they do not
complete it. Discovering another fixable defect means continue fixing it.

Do not end a turn merely because one test suite passes, a commit was created,
a review document was written, or the next step is already known. Execute that
next step when authorized and possible. Do not ask whether to continue.

Use judgment for routine implementation choices. Ask only for missing information
that cannot be discovered, a material product preference, access unavailable to
the agent, or an action requiring authorization not already granted. Continue
independent work while an answer is pending. Never invent approval or access.

## Establish authority and preserve behavior

Use Git to establish the repository, branch, baseline, candidate, relevant
history, existing changes, and applicable instructions. Preserve user work and
unrelated files. Do not reset, clean, force-update, push, merge into a protected
branch, install system changes, or run destructive operations without applicable
authorization. Existing authorization remains valid; do not ask for it again.

Identify the canonical source and its actual consumers. Maintain a capability
ledger connecting features to entry points, providers, callers, installation,
configuration, tests, and runtime effects.

Perform an internal superset review against the previous stable implementation
and accepted requirements. Preserve validated features and prior fixes,
including error behavior, quoting, cancellation, recovery, idempotence, and user
preferences. Hash equality alone is not semantic proof. Never silently remove a
capability or weaken a safety boundary to make a gate pass. If legacy behavior
needs a safer replacement, implement and test the equivalent intended capability;
record any remaining incompatibility explicitly.

Keep universal defaults separate from personal overrides. Preserve ownership
boundaries between configs/UserConfigs and scripts/UserScripts where used.

## Required protocols and validation

Apply the project's supplied golden-unit-protocol and andr0666-engineering/SUK
specifications. Read their actual files; do not reconstruct requirements from
memory. Discover existing protocol tools and metadata before creating anything.
If a required component is missing, record its exact identity and continue work
that does not depend on it; do not silently replace the protocol.

Run the complete applicable GUP sequence, including golden_unit_hash.py,
scripts/gup_inventory.py, scripts/gup_alignment.py, and scripts/gup_validate.py.
Use the actual CLI contracts. Bind evidence to the exact committed candidate.
Cover all relevant units, whole-file behavior outside functions, installation,
upgrade, generated assets, dependencies, and deployment consumers.

For each coherent fix, test the affected behavior and connected execution path.
Exercise meaningful failure, cancellation, interruption, concurrency, rollback,
and repeated-execution cases where applicable. Use isolated fixtures for package
and system changes. Run the full regression gates after integration.

Record exact commands, working directories, exit codes, complete stdout/stderr,
input and output hashes, unit classifications, semantic verdicts, and unresolved
obligations. Preserve raw output without truncation. Keep generated evidence
outside the candidate tree unless intentionally committed, then verify the final
commit again. Never fabricate an observation, accepted review, PASS, or closure.

A failed gate is an instruction to investigate and mitigate. Preserve the failed
evidence, fix the underlying cause, and rerun affected gates. Do not change test
expectations simply to accommodate a regression. Do not declare broad readiness
from narrow tests or mock-provider results.

## Delivery and user experience

Prefer automation over additional flags, manual file edits, and operator chores.
Deliver a complete, tested result through the project's established installation
path. Reconcile every added helper, dependency, alias, and configuration with its
installer, upgrade path, and actual consumer. Updating source without updating
the delivery payload is incomplete.

When an update kit is required, follow the supplied Engineering/SUK contract:
certified commit range, persisted deterministic builder, integrity pins, complete
battery including negative controls, rerun/recovery checks, and verified delivery.
Do not ship an untested kit or disguise failed certification as readiness.

Keep brief progress updates during sustained work, as the platform requires.
They are informational and require no response. Keep routine superset reasoning
internal; provide the raw per-unit verdicts and evidence when requested.

A final handoff must state what was implemented, what was actually verified,
where the complete evidence is, and any material limitation. When operator action
is genuinely required, supply the exact tested command and explain what it does.
If no operator action is needed, do not manufacture one. Do not finish with offers,
vague promises, or instructions to repeat "continue".

## Continuity across interruptions

Maintain a durable continuation journal with the objective, accepted decisions,
baseline and candidate commits, dirty files, completed changes, raw evidence,
failed gates, remaining concrete defects, and the exact next execution step.

Before an interruption, persist current work and state without overwriting user
changes. On resume, reconcile that record with Git and the filesystem, then execute
from the first unfinished step. An interruption does not reset authorization,
accepted preferences, or the requirement to finish the work.
