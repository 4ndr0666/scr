#!/usr/bin/env python3
"""Produce fail-closed, Git-derived path history evidence for the GUP service scope.

The report is observational: historical deletions without an approved disposition remain
UNRESOLVED and keep baseline approval blocked. It never edits Git state or authorizes removal.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path


def git(root: Path, *args: str, check: bool = True) -> bytes:
    result = subprocess.run(
        ["git", "-C", str(root), *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        timeout=120,
    )
    if check and result.returncode:
        raise RuntimeError(
            result.stderr.decode("utf-8", "replace").strip()
            or f"git {' '.join(args)} failed ({result.returncode})"
        )
    return result.stdout


def tree_files(root: Path, commit: str, scope: str) -> dict[str, dict[str, str]]:
    git(root, "cat-file", "-e", f"{commit}^{{commit}}")
    raw = git(root, "ls-tree", "-r", "-z", "--full-tree", commit, "--", scope)
    result: dict[str, dict[str, str]] = {}
    for record in raw.split(bytes([0])):
        if not record:
            continue
        metadata, raw_path = record.split(bytes([9]), 1)
        mode, kind, oid = metadata.decode("ascii").split()
        path = raw_path.decode("utf-8", "surrogateescape")
        if kind == "blob":
            result[path] = {"mode": mode, "git_blob_sha": oid}
    return result


def path_history(root: Path, commit: str, path: str) -> dict[str, object]:
    raw = git(root, "log", "--follow", "--format=%H%x09%cs%x09%s", commit, "--", path)
    rows = []
    for line in raw.decode("utf-8", "replace").splitlines():
        parts = line.split("\t", 2)
        if len(parts) == 3:
            rows.append({"commit": parts[0], "date": parts[1], "subject": parts[2]})
    rename_raw = git(
        root, "log", "--follow", "--find-renames", "--format=", "--name-status",
        commit, "--", path,
    )
    renames = []
    for line in rename_raw.decode("utf-8", "surrogateescape").splitlines():
        parts = line.split("\t")
        if len(parts) == 3 and parts[0].startswith("R"):
            renames.append({"similarity": parts[0][1:], "from": parts[1], "to": parts[2]})
    return {
        "commit_count": len(rows),
        "oldest": rows[-1] if rows else None,
        "newest": rows[0] if rows else None,
        "rename_events": renames,
        "history_status": "OBSERVED" if rows else "UNRESOLVED_NO_HISTORY",
    }


def deleted_paths(root: Path, commit: str, scope: str, current: set[str]) -> list[dict[str, str]]:
    raw = git(
        root, "log", "--diff-filter=D", "--find-renames", "--name-status",
        "--format=COMMIT%x09%H%x09%cs%x09%s", commit, "--", scope,
    )
    commit_meta: tuple[str, str, str] | None = None
    records: dict[str, dict[str, str]] = {}
    for line in raw.decode("utf-8", "surrogateescape").splitlines():
        if line.startswith("COMMIT\t"):
            parts = line.split("\t", 3)
            if len(parts) == 4:
                commit_meta = (parts[1], parts[2], parts[3])
            continue
        parts = line.split("\t")
        if len(parts) == 2 and parts[0] == "D" and commit_meta:
            path = parts[1]
            if path not in current and path not in records:
                records[path] = {
                    "path": path,
                    "deletion_commit": commit_meta[0],
                    "deletion_date": commit_meta[1],
                    "deletion_subject": commit_meta[2],
                    "disposition": "unresolved",
                }
    return [records[path] for path in sorted(records)]



DISPOSITION_STATUSES = {"preserved", "translated", "authorized-retired", "unresolved"}


def load_disposition_register(path: Path, scope: str, source_commit: str,
                              historical_deleted: list[dict[str, str]],
                              missing_source_paths: set[str],
                              candidate_paths: set[str]) -> dict[str, dict[str, object]]:
    """Validate exact path coverage and evidence-backed disposition semantics."""
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise RuntimeError(f"cannot read disposition register {path}: {exc}") from exc
    if not isinstance(data, dict):
        raise RuntimeError("disposition register root must be an object")
    identity = {"schema_version": 1, "protocol": "GUP", "protocol_version": "7.0.1",
                "scope_root": scope, "source_commit": source_commit}
    for key, expected in identity.items():
        if data.get(key) != expected:
            raise RuntimeError(f"disposition register {key} mismatch: expected {expected!r}")
    rows = data.get("records")
    if not isinstance(rows, list):
        raise RuntimeError("disposition register records must be an array")
    by_path: dict[str, dict[str, object]] = {}
    for row in rows:
        if not isinstance(row, dict):
            raise RuntimeError("each disposition record must be an object")
        path_value = row.get("path")
        if not isinstance(path_value, str) or not path_value or path_value in by_path:
            raise RuntimeError(f"invalid or duplicate disposition path: {path_value!r}")
        by_path[path_value] = row
    deleted_by_path = {row["path"]: row for row in historical_deleted}
    expected_paths = set(deleted_by_path) | missing_source_paths
    actual_paths = set(by_path)
    missing, stale = sorted(expected_paths - actual_paths), sorted(actual_paths - expected_paths)
    if missing or stale:
        raise RuntimeError(f"disposition register coverage mismatch: missing={missing}, stale_or_extra={stale}")
    for path_value, row in by_path.items():
        status, rationale, evidence = row.get("disposition"), row.get("rationale"), row.get("evidence")
        if not isinstance(status, str) or status not in DISPOSITION_STATUSES:
            raise RuntimeError(f"invalid disposition for {path_value}: {status!r}")
        if not isinstance(rationale, str) or not rationale.strip():
            raise RuntimeError(f"disposition for {path_value} needs a non-empty rationale")
        if not isinstance(evidence, list) or not evidence or any(
            not isinstance(item, str) or not item.strip() for item in evidence
        ):
            raise RuntimeError(f"disposition for {path_value} needs non-empty evidence references")
        if path_value in deleted_by_path and row.get("deletion_commit") != deleted_by_path[path_value]["deletion_commit"]:
            raise RuntimeError(f"deletion commit mismatch for {path_value}")
        if status == "preserved":
            target = row.get("target", path_value)
            if not isinstance(target, str) or target not in candidate_paths:
                raise RuntimeError(f"preserved disposition for {path_value} needs a current target path")
        elif status == "translated":
            target, tests = row.get("target"), row.get("behavior_tests")
            if not isinstance(target, str) or target not in candidate_paths:
                raise RuntimeError(f"translated disposition for {path_value} needs a current target path")
            if not isinstance(tests, list) or not tests or any(
                not isinstance(item, str) or not item.strip()
                or (item not in candidate_paths and not item.startswith("https://github.com/"))
                for item in tests
            ):
                raise RuntimeError(f"translated disposition for {path_value} needs reproducible behavior-level test evidence")
        elif status == "authorized-retired":
            if row.get("user_authorization") is not True:
                raise RuntimeError(f"retirement of {path_value} requires user_authorization=true")
            authorization = row.get("authorization_reference")
            if not isinstance(authorization, str) or not authorization.strip():
                raise RuntimeError(f"retirement of {path_value} needs an authorization reference")
    return by_path


def atomic_write(path: Path, payload: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        mode="wb", prefix=f".{path.name}.", suffix=".tmp", dir=path.parent, delete=False
    ) as stream:
        temporary = Path(stream.name)
        stream.write(payload)
        stream.flush()
        import os
        os.fsync(stream.fileno())
    try:
        temporary.replace(path)
        fd = __import__("os").open(path.parent, __import__("os").O_RDONLY)
        try:
            __import__("os").fsync(fd)
        finally:
            __import__("os").close(fd)
    finally:
        temporary.unlink(missing_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".")
    parser.add_argument("--scope", default="4ndr0tools/4ndr0service")
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--output")
    parser.add_argument("--dispositions", help="validate and apply a machine-readable GUP disposition register")
    args = parser.parse_args()
    root = Path(args.root).resolve()
    try:
        head = git(root, "rev-parse", "HEAD").decode().strip()
        git(root, "merge-base", "--is-ancestor", args.source_commit, head)
        source = tree_files(root, args.source_commit, args.scope)
        candidate = tree_files(root, head, args.scope)
        if not source:
            raise RuntimeError("source commit has no tracked files under the requested scope")
        source_paths, candidate_paths = set(source), set(candidate)
        records = []
        for path in sorted(source_paths | candidate_paths):
            record: dict[str, object] = {
                "path": path,
                "source_present": path in source,
                "candidate_present": path in candidate,
                "source_git_blob_sha": source.get(path, {}).get("git_blob_sha"),
                "candidate_git_blob_sha": candidate.get(path, {}).get("git_blob_sha"),
            }
            if path in source and path in candidate:
                record["disposition"] = "PRESERVED_PATH"
            elif path in source:
                record["disposition"] = "UNRESOLVED_MISSING_FROM_CANDIDATE"
            else:
                record["disposition"] = "NEW_PATH"
            record["history"] = path_history(root, args.source_commit if path in source else head, path)
            records.append(record)
        deleted = deleted_paths(root, args.source_commit, args.scope, candidate_paths)
        missing_source_paths = source_paths - candidate_paths
        dispositions = {}
        if args.dispositions:
            disposition_path = Path(args.dispositions)
            if not disposition_path.is_absolute():
                disposition_path = root / disposition_path
            dispositions = load_disposition_register(
                disposition_path, args.scope, args.source_commit, deleted,
                missing_source_paths, candidate_paths,
            )
            for row in deleted:
                reviewed = dispositions[row["path"]]
                row["disposition"] = reviewed["disposition"]
                row["rationale"] = reviewed["rationale"]
                row["evidence"] = reviewed["evidence"]
            for record in records:
                if record["path"] in missing_source_paths:
                    reviewed = dispositions[record["path"]]
                    record["reviewed_disposition"] = reviewed["disposition"]
                    record["disposition_evidence"] = reviewed["evidence"]
                    record["disposition_rationale"] = reviewed["rationale"]
        unresolved = []
        for record in records:
            if record["path"] in missing_source_paths and args.dispositions:
                if record.get("reviewed_disposition") == "UNRESOLVED":
                    unresolved.append(record["path"])
            elif str(record["disposition"]).startswith("UNRESOLVED"):
                unresolved.append(record["path"])
        unresolved.extend(r["path"] for r in deleted if r["disposition"] == "unresolved")
        report = {
            "schema_version": 1,
            "protocol": "GUP",
            "protocol_version": "7.0.1",
            "scope_root": args.scope,
            "source_commit": args.source_commit,
            "candidate_commit": head,
            "source_file_count": len(source),
            "candidate_file_count": len(candidate),
            "preserved_source_paths": len(source_paths & candidate_paths),
            "new_candidate_paths": len(candidate_paths - source_paths),
            "missing_source_paths": len(source_paths - candidate_paths),
            "historical_deleted_paths": deleted,
            "historical_deleted_path_count": len(deleted),
            "unresolved_path_count": len(set(unresolved)),
            "baseline_status": "BLOCKED_UNRESOLVED_HISTORY" if unresolved else "HISTORY_REVIEW_REQUIRED",
            "records": records,
            "limitations": [
                "Git path and rename observations do not prove semantic capability preservation.",
                "When --dispositions is supplied, historical dispositions are validated against exact path coverage and Git deletion identities; UNRESOLVED entries remain blockers.",
                "No deleted path is authorized for retirement by this report.",
                "The source commit is an inventory candidate, not an approved canonical baseline.",
            ],
        }
        encoded = (json.dumps(report, indent=2, sort_keys=True) + "\n").encode()
        if args.output:
            atomic_write(Path(args.output), encoded)
        else:
            sys.stdout.buffer.write(encoded)
        print(
            f"GUP history audit: source={len(source)} candidate={len(candidate)} "
            f"historical_deleted={len(deleted)} unresolved={len(set(unresolved))}",
            file=sys.stderr,
        )
        for row in deleted:
            print(
                "GUP historical deletion disposition: "
                + json.dumps(row, sort_keys=True, ensure_ascii=True),
                file=sys.stderr,
            )
        return 0
    except (OSError, RuntimeError, subprocess.SubprocessError, ValueError) as exc:
        print(f"GUP history audit failed closed: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
