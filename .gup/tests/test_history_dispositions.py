#!/usr/bin/env python3
"""Regression tests for fail-closed GUP historical disposition register validation."""
from __future__ import annotations
import json, subprocess, sys, tempfile, unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "audit_history_continuity.py"
SCOPE = "service"
PROTOCOL = {"schema_version": 1, "protocol": "GUP", "protocol_version": "7.0.1", "scope_root": SCOPE}

def run(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False, timeout=30)

class DispositionRegisterTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.assertEqual(run("git", "init", "-q", str(self.root)).returncode, 0)
        run("git", "-C", str(self.root), "config", "user.name", "GUP Test")
        run("git", "-C", str(self.root), "config", "user.email", "gup-test@example.invalid")
        scope = self.root / SCOPE; scope.mkdir()
        (scope / "old.sh").write_text("old capability\n", encoding="utf-8")
        (scope / "kept.sh").write_text("kept capability\n", encoding="utf-8")
        self.commit("add old path")
        self.deletion_commit = self.commit("delete old path", delete="old.sh")
        self.source_commit = self.commit("source inventory")
        (self.root / SCOPE / "test_runtime.sh").write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
        self.commit("candidate adds runtime test")
        self.register_path = self.root / "register.json"; self.audit_path = self.root / "audit.json"
        self.row = {"path": f"{SCOPE}/old.sh", "deletion_commit": self.deletion_commit,
                    "deletion_date": "2026-01-01", "deletion_subject": "delete old path",
                    "disposition": "unresolved", "rationale": "Historical behavior has not been semantically reconciled.",
                    "evidence": [f"https://github.com/example/repo/commit/{self.deletion_commit}"], "review_evidence": []}
        self.write_register([self.row])

    def commit(self, message: str, delete: str | None = None) -> str:
        if delete: (self.root / SCOPE / delete).unlink()
        run("git", "-C", str(self.root), "add", "-A")
        result = run("git", "-C", str(self.root), "commit", "--allow-empty", "-qm", message)
        self.assertEqual(result.returncode, 0, result.stderr)
        return run("git", "-C", str(self.root), "rev-parse", "HEAD").stdout.strip()

    def write_register(self, rows: list[dict[str, object]]) -> None:
        self.register_path.write_text(json.dumps(dict(PROTOCOL, source_commit=self.source_commit, records=rows)), encoding="utf-8")

    def audit(self) -> subprocess.CompletedProcess[str]:
        return run(sys.executable, str(SCRIPT), "--root", str(self.root), "--scope", SCOPE,
                   "--source-commit", self.source_commit, "--dispositions", str(self.register_path), "--output", str(self.audit_path))

    def test_complete_unresolved_register_is_reported_and_blocks_baseline(self) -> None:
        result = self.audit(); self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(self.audit_path.read_text(encoding="utf-8"))
        deleted = {row["path"]: row for row in report["historical_deleted_paths"]}
        self.assertEqual(deleted[f"{SCOPE}/old.sh"]["disposition"], "unresolved")
        self.assertEqual(report["baseline_status"], "BLOCKED_UNRESOLVED_HISTORY")

    def test_missing_or_stale_register_entries_fail_closed(self) -> None:
        self.write_register([]); missing = self.audit()
        self.assertNotEqual(missing.returncode, 0); self.assertIn("coverage mismatch", missing.stderr)
        extra = dict(self.row, path=f"{SCOPE}/not-a-real-history.sh")
        self.write_register([self.row, extra]); stale = self.audit()
        self.assertNotEqual(stale.returncode, 0); self.assertIn("coverage mismatch", stale.stderr)

    def test_unauthorized_retirement_fails_closed(self) -> None:
        self.write_register([dict(self.row, disposition="authorized-retired")])
        result = self.audit(); self.assertNotEqual(result.returncode, 0)
        self.assertIn("user_authorization=true", result.stderr)

    def test_translation_requires_current_target_and_behavior_test(self) -> None:
        row = dict(self.row, disposition="translated", target=f"{SCOPE}/missing-target.sh", behavior_tests=["test/test_runtime.sh"])
        self.write_register([row]); missing_target = self.audit()
        self.assertNotEqual(missing_target.returncode, 0); self.assertIn("current target path", missing_target.stderr)
        row["target"] = f"{SCOPE}/kept.sh"; row["behavior_tests"] = []
        self.write_register([row]); missing_test = self.audit()
        self.assertNotEqual(missing_test.returncode, 0); self.assertIn("behavior-level test evidence", missing_test.stderr)

    def test_valid_translation_is_accepted_without_certifying_baseline(self) -> None:
        row = dict(self.row, disposition="translated", target=f"{SCOPE}/kept.sh",
                   behavior_tests=[f"{SCOPE}/test_runtime.sh"])
        self.write_register([row])
        result = self.audit()
        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(self.audit_path.read_text(encoding="utf-8"))
        self.assertEqual(report["historical_deleted_paths"][0]["disposition"], "translated")
        self.assertEqual(report["baseline_status"], "HISTORY_REVIEW_REQUIRED")

    def test_wrong_deletion_commit_fails_closed(self) -> None:
        self.write_register([dict(self.row, deletion_commit="0" * 40)])
        result = self.audit(); self.assertNotEqual(result.returncode, 0)
        self.assertIn("deletion commit mismatch", result.stderr)

if __name__ == "__main__":
    unittest.main(verbosity=2)
