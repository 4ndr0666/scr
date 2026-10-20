#!/usr/bin/env python3
"""Regression tests for exact-blob historical deletion evidence."""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "audit_deleted_blob_matches.py"


def run(*args: str, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        check=False, timeout=30,
    )


class DeletedBlobMatchTests(unittest.TestCase):
    def make_repo(self, root: Path) -> Path:
        self.assertEqual(run("git", "init", "-q", str(root)).returncode, 0)
        run("git", "-C", str(root), "config", "user.name", "GUP Test")
        run("git", "-C", str(root), "config", "user.email", "gup-test@example.invalid")
        (root / "service").mkdir()
        (root / "service" / "legacy.sh").write_text("stable payload\n", encoding="utf-8")
        run("git", "-C", str(root), "add", "-A")
        self.assertEqual(run("git", "-C", str(root), "commit", "-qm", "baseline").returncode, 0)
        return root

    def test_identical_candidate_blob_is_a_lead_not_a_disposition(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = self.make_repo(Path(td))
            (root / "service" / "replacement.sh").write_text("stable payload\n", encoding="utf-8")
            (root / "service" / "legacy.sh").unlink()
            run("git", "-C", str(root), "add", "-A")
            self.assertEqual(run("git", "-C", str(root), "commit", "-qm", "copy then delete").returncode, 0)
            result = run(sys.executable, str(SCRIPT), "--root", str(root), "--scope", "service")
            self.assertEqual(result.returncode, 0, result.stderr)
            report = json.loads(result.stdout)
            row = next(row for row in report["records"] if row["path"] == "service/legacy.sh")
            self.assertEqual(row["exact_blob_matches_in_candidate"], ["service/replacement.sh"])
            self.assertEqual(row["match_interpretation"], "EXACT_BLOB_MATCH_REQUIRES_SEMANTIC_REVIEW")
            self.assertEqual(row["disposition"], "UNRESOLVED")
            self.assertTrue(report["all_dispositions_remain_unresolved"])

    def test_no_exact_match_stays_unresolved(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = self.make_repo(Path(td))
            (root / "service" / "legacy.sh").unlink()
            (root / "service" / "replacement.sh").write_text("different payload\n", encoding="utf-8")
            run("git", "-C", str(root), "add", "-A")
            self.assertEqual(run("git", "-C", str(root), "commit", "-qm", "replace content").returncode, 0)
            result = run(sys.executable, str(SCRIPT), "--root", str(root), "--scope", "service")
            self.assertEqual(result.returncode, 0, result.stderr)
            report = json.loads(result.stdout)
            row = next(row for row in report["records"] if row["path"] == "service/legacy.sh")
            self.assertEqual(row["exact_blob_matches_in_candidate"], [])
            self.assertEqual(row["match_interpretation"], "NO_EXACT_BLOB_MATCH_FOUND")
            self.assertEqual(row["disposition"], "UNRESOLVED")

    def test_output_is_atomically_replaced_and_reruns_are_byte_stable(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = self.make_repo(Path(td))
            (root / "service" / "legacy.sh").unlink()
            (root / "service" / "replacement.sh").write_text("different payload\\n", encoding="utf-8")
            run("git", "-C", str(root), "add", "-A")
            self.assertEqual(run("git", "-C", str(root), "commit", "-qm", "replace content").returncode, 0)
            output = root / "reports" / "continuity.json"
            command = [
                sys.executable, str(SCRIPT), "--root", str(root),
                "--scope", "service", "--output", str(output),
            ]
            first = run(*command)
            self.assertEqual(first.returncode, 0, first.stderr)
            first_bytes = output.read_bytes()
            second = run(*command)
            self.assertEqual(second.returncode, 0, second.stderr)
            self.assertEqual(output.read_bytes(), first_bytes)
            self.assertEqual(list(output.parent.glob(".continuity.json.*.tmp")), [])

    def test_invalid_commit_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = self.make_repo(Path(td))
            result = run(
                sys.executable, str(SCRIPT), "--root", str(root),
                "--scope", "service", "--candidate-commit", "missing-ref",
            )
            self.assertEqual(result.returncode, 2)
            self.assertIn("failed closed", result.stderr.lower())


if __name__ == "__main__":
    unittest.main(verbosity=2)
