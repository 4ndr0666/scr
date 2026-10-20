#!/usr/bin/env python3
"""Find exact Git-blob matches for historical deletions without assigning dispositions.

Exact content identity is a candidate lead only; it does not establish semantic
replacement. All historical deletions remain unresolved until separately reviewed.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


def git(root: Path, *args: str) -> bytes:
    result = subprocess.run(
        ["git", "-C", str(root), *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        timeout=120,
    )
    if result.returncode:
        raise RuntimeError(
            result.stderr.decode("utf-8", "replace").strip()
            or f"git {' '.join(args)} failed ({result.returncode})"
        )
    return result.stdout


def tree_blobs(root: Path, commit: str, scope: str) -> dict[str, dict[str, str]]:
    git(root, "cat-file", "-e", f"{commit}^{{commit}}")
    raw = git(root, "ls-tree", "-r", "-z", "--full-tree", commit, "--", scope)
    found: dict[str, dict[str, str]] = {}
    for record in raw.split(bytes([0])):
        if not record:
            continue
        metadata, raw_path = record.split(bytes([9]), 1)
        mode, kind, oid = metadata.decode("ascii").split()
        path = raw_path.decode("utf-8", "surrogateescape")
        if kind == "blob":
            found[path] = {"mode": mode, "git_blob_sha": oid}
    return found


def deletion_events(root: Path, commit: str, scope: str) -> list[dict[str, str]]:
    raw = git(
        root, "log", "--diff-filter=D", "--no-renames", "--name-status",
        "--format=COMMIT%x09%H%x09%cs%x09%s", commit, "--", scope,
    )
    current: tuple[str, str, str] | None = None
    records: dict[str, dict[str, str]] = {}
    for line in raw.decode("utf-8", "surrogateescape").splitlines():
        if line.startswith("COMMIT\t"):
            parts = line.split("\t", 3)
            current = (parts[1], parts[2], parts[3]) if len(parts) == 4 else None
            continue
        parts = line.split("\t")
        if len(parts) != 2 or parts[0] != "D" or current is None:
            continue
        path = parts[1]
        if path not in records:
            records[path] = {
                "path": path,
                "deletion_commit": current[0],
                "deletion_date": current[1],
                "deletion_subject": current[2],
            }
    return [records[path] for path in sorted(records)]


def atomic_write(path: Path, payload: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="wb", prefix=f".{path.name}.", suffix=".tmp",
            dir=path.parent, delete=False,
        ) as stream:
            temporary = Path(stream.name)
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
        temporary.replace(path)
        directory_fd = os.open(path.parent, os.O_RDONLY)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".")
    parser.add_argument("--scope", default="4ndr0tools/4ndr0service")
    parser.add_argument("--candidate-commit", default="HEAD")
    parser.add_argument("--output")
    args = parser.parse_args()
    root = Path(args.root).resolve()
    try:
        candidate_commit = git(root, "rev-parse", "--verify", f"{args.candidate_commit}^{{commit}}").decode().strip()
        candidate = tree_blobs(root, candidate_commit, args.scope)
        deleted = [row for row in deletion_events(root, candidate_commit, args.scope) if row["path"] not in candidate]
        parent_trees: dict[str, dict[str, dict[str, str]]] = {}
        for row in deleted:
            deletion_commit = row["deletion_commit"]
            parent = git(root, "rev-parse", f"{deletion_commit}^").decode().strip()
            if parent not in parent_trees:
                parent_trees[parent] = tree_blobs(root, parent, args.scope)
            old = parent_trees[parent].get(row["path"])
            row["deleted_git_blob_sha"] = old["git_blob_sha"] if old else None
            row["exact_blob_matches_in_candidate"] = (
                sorted(path for path, info in candidate.items()
                       if old and info["git_blob_sha"] == old["git_blob_sha"] and path != row["path"])
            )
            row["disposition"] = "UNRESOLVED"
            row["match_interpretation"] = (
                "EXACT_BLOB_MATCH_REQUIRES_SEMANTIC_REVIEW"
                if row["exact_blob_matches_in_candidate"]
                else "NO_EXACT_BLOB_MATCH_FOUND"
            )
        matched = sum(bool(row["exact_blob_matches_in_candidate"]) for row in deleted)
        report: dict[str, Any] = {
            "schema_version": 1,
            "protocol": "GUP",
            "protocol_version": "7.0.1",
            "scope_root": args.scope,
            "candidate_commit": candidate_commit,
            "candidate_file_count": len(candidate),
            "historical_deleted_path_count": len(deleted),
            "deleted_paths_with_exact_blob_match": matched,
            "deleted_paths_without_exact_blob_match": len(deleted) - matched,
            "all_dispositions_remain_unresolved": all(row["disposition"] == "UNRESOLVED" for row in deleted),
            "records": deleted,
            "limitations": [
                "Exact Git blob identity is evidence of byte-for-byte content identity only.",
                "A matching blob does not prove equivalent callers, interfaces, configuration, deployment, runtime behavior, or intended ownership.",
                "No disposition is inferred, and no historical deletion is authorized for retirement.",
                "No exact blob match does not prove capability loss; semantic replacements may differ in content.",
            ],
        }
        encoded = (json.dumps(report, indent=2, sort_keys=True) + "\n").encode("utf-8")
        if args.output:
            atomic_write(Path(args.output), encoded)
        else:
            sys.stdout.buffer.write(encoded)
        print(
            f"GUP deletion blob continuity: deleted={len(deleted)} exact_blob_matches={matched} "
            f"unmatched={len(deleted) - matched}; all dispositions UNRESOLVED",
            file=sys.stderr,
        )
        return 0
    except (OSError, RuntimeError, subprocess.SubprocessError, ValueError, IndexError) as exc:
        print(f"GUP deletion blob continuity failed closed: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
