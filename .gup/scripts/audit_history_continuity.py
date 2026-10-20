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
                    "disposition": "UNRESOLVED",
                }
    return [records[path] for path in sorted(records)]


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
        unresolved = [r["path"] for r in records if str(r["disposition"]).startswith("UNRESOLVED")]
        unresolved.extend(r["path"] for r in deleted)
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
                "Historical deletions are UNRESOLVED until each receives an evidence-backed disposition.",
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
        return 0
    except (OSError, RuntimeError, subprocess.SubprocessError, ValueError) as exc:
        print(f"GUP history audit failed closed: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
