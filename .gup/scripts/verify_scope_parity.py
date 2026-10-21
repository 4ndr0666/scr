#!/usr/bin/env python3
"""Verify the committed historical service-subtree parity record."""
import json
import subprocess
from pathlib import Path

EVIDENCE = Path(".gup/evidence/scope-tree-parity.json")
SCOPE = "4ndr0tools/4ndr0service"


def git_tree(commit: str) -> str:
    return subprocess.run(
        ["git", "rev-parse", f"{commit}:{SCOPE}"],
        check=True, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
    ).stdout.strip()


def main() -> int:
    evidence = json.loads(EVIDENCE.read_text(encoding="utf-8"))
    if evidence.get("protocol") != "GUP" or evidence.get("protocol_version") != "7.0.1":
        raise SystemExit("Unexpected GUP protocol identity")
    if evidence.get("scope_root") != SCOPE:
        raise SystemExit("Unexpected scope root")
    baseline = evidence.get("baseline_candidate_commit")
    candidate = evidence.get("compared_candidate_commit")
    expected = evidence.get("baseline_scope_tree_sha")
    if evidence.get("candidate_scope_tree_sha") != expected:
        raise SystemExit("Recorded subtree identities disagree")
    if evidence.get("result") != "EXACT_PATH_MODE_BLOB_PARITY":
        raise SystemExit("Evidence does not record exact subtree parity")
    expected_summary = {
        "baseline_entries": 54, "candidate_entries": 54,
        "baseline_files": 48, "candidate_files": 48,
        "added_paths": 0, "missing_paths": 0, "changed_mode_or_blob": 0,
    }
    if evidence.get("summary") != expected_summary:
        raise SystemExit("Unexpected parity summary")
    for label, commit in (("baseline", baseline), ("candidate", candidate)):
        if not isinstance(commit, str) or len(commit) != 40:
            raise SystemExit(f"Invalid {label} commit identity")
        actual = git_tree(commit)
        if actual != expected:
            raise SystemExit(f"{label} subtree mismatch: actual={actual} expected={expected}")
    print(f"GUP service subtree parity verified: {expected}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
