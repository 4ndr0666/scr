#!/usr/bin/env python3
"""Regression tests for the GUP history audit using isolated synthetic Git repositories."""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "audit_history_continuity.py"


def run(*args: str, cwd: Path | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        check=False, timeout=30,
    )


class HistoryAuditTests(unittest.TestCase):
    def test_historical_deletion_is_unresolved_and_never_authorized(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            self.assertEqual(run("git", "init", "-q", str(root)).returncode, 0)
            run("git", "-C", str(root), "config", "user.name", "GUP Test")
            run("git", "-C", str(root), "config", "user.email", "gup-test@example.invalid")
            scope = root / "service"
            scope.mkdir()
            (scope / "retired.sh").write_text("old capability\n", encoding="utf-8")
            (scope / "kept.sh").write_text("kept capability\n", encoding="utf-8")
            run("git", "-C", str(root), "add", "-A")
            self.assertEqual(run("git", "-C", str(root), "commit", "-qm", "baseline").returncode, 0)
            (scope / "retired.sh").unlink()
            (scope / "new.sh").write_text("new capability\n", encoding="utf-8")
            run("git", "-C", str(root), "add", "-A")
            self.assertEqual(run("git", "-C", str(root), "commit", "-qm", "remove old path").returncode, 0)
            source = run("git", "-C", str(root), "rev-parse", "HEAD").stdout.strip()
            result = run(
                sys.executable, str(SCRIPT), "--root", str(root),
                "--scope", "service", "--source-commit", source,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            report = json.loads(result.stdout)
            deleted = {row["path"]: row for row in report["historical_deleted_paths"]}
            self.assertIn("service/retired.sh", deleted)
            self.assertEqual(deleted["service/retired.sh"]["disposition"], "unresolved")
            self.assertEqual(report["baseline_status"], "BLOCKED_UNRESOLVED_HISTORY")

    def test_source_paths_missing_from_candidate_are_blocking(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            run("git", "init", "-q", str(root))
            run("git", "-C", str(root), "config", "user.name", "GUP Test")
            run("git", "-C", str(root), "config", "user.email", "gup-test@example.invalid")
            scope = root / "service"
            scope.mkdir()
            (scope / "critical.sh").write_text("critical\n", encoding="utf-8")
            run("git", "-C", str(root), "add", "-A")
            run("git", "-C", str(root), "commit", "-qm", "source")
            source = run("git", "-C", str(root), "rev-parse", "HEAD").stdout.strip()
            (scope / "critical.sh").unlink()
            run("git", "-C", str(root), "add", "-A")
            run("git", "-C", str(root), "commit", "-qm", "remove critical")
            result = run(
                sys.executable, str(SCRIPT), "--root", str(root),
                "--scope", "service", "--source-commit", source,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            report = json.loads(result.stdout)
            missing = [r for r in report["records"] if r["disposition"] == "UNRESOLVED_MISSING_FROM_CANDIDATE"]
            self.assertEqual([r["path"] for r in missing], ["service/critical.sh"])
            self.assertEqual(report["baseline_status"], "BLOCKED_UNRESOLVED_HISTORY")


if __name__ == "__main__":
    unittest.main(verbosity=2)
