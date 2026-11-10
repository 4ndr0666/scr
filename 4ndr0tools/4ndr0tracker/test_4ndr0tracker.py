#!/usr/bin/env python3
"""Comprehensive test suite for 4ndr0tracker.py (Superset & Gap Mitigation Verification)."""

import importlib.util
import io
import os
import subprocess
import tempfile
import unittest
import urllib.error
from pathlib import Path
from unittest import mock


REPO_DIR = Path(__file__).resolve().parent
MODULE_PATH = REPO_DIR / "4ndr0tracker.py"

spec = importlib.util.spec_from_file_location("ndr0tracker", MODULE_PATH)
tracker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tracker)


class Test4ndr0TrackerSuperset(unittest.TestCase):
    def test_01_normalize_and_junk_filtering(self) -> None:
        self.assertEqual(
            tracker._normalize("  'https://example.com/v/12345' "),
            "https://example.com/v/12345",
        )
        self.assertEqual(
            tracker._normalize("//cdn.example.org/e/abc987"),
            "https://cdn.example.org/e/abc987",
        )
        # Reject junk substrings & image extensions
        self.assertIsNone(tracker._normalize("https://gravatar.com/avatar/123456"))
        self.assertIsNone(tracker._normalize("https://example.com/wp-content/uploads/pic.mp4"))
        self.assertIsNone(tracker._normalize("https://example.com/thumb.webp?width=200"))
        self.assertIsNone(tracker._normalize("https://example.com/icon.SVG#layer"))
        # Reject invalid netloc / control chars / short strings
        self.assertIsNone(tracker._normalize("https://////////"))
        self.assertIsNone(tracker._normalize("https://localhost/no-dot"))
        self.assertIsNone(tracker._normalize("https://example.com/bad\x00url"))
        self.assertIsNone(tracker._normalize("ftp://example.com/file.mp4"))

    def test_02_extract_urls_superset_and_surrogate_safety(self) -> None:
        raw = r"""
        <div data-video-url="https://vid.example.com/e/alpha1"
             data-lazy-src="//cdn.example.com/d/beta2">
          <a href="https://example.com/watch?v=1&amp;t=10">Link</a>
          <img src="https://example.com/banner.jpg" />
          <script>
            var u = "https:\/\/stream.example.com\/f\/gamma3\u003fhd=1";
            var astral = "https://example.com/v/\ud83d\ude80";
            var lone = "https://example.com/v/\ud800test";
          </script>
        </div>
        """
        urls = tracker.extract_urls(raw)
        self.assertIn("https://vid.example.com/e/alpha1", urls)
        self.assertIn("https://cdn.example.com/d/beta2", urls)
        self.assertIn("https://example.com/watch?v=1&t=10", urls)
        self.assertIn("https://stream.example.com/f/gamma3?hd=1", urls)
        # Ensure extracted strings encode cleanly to UTF-8 (zero lone surrogates)
        for u in urls:
            u.encode("utf-8")

    def test_03_allocate_output_filename_atomic_increment(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            old_cwd = os.getcwd()
            os.chdir(td)
            try:
                f1 = tracker.allocate_output_filename()
                self.assertTrue(os.path.exists(f1))
                self.assertTrue(f1.startswith("4NDR0-TRACKER1_"))
                f2 = tracker.allocate_output_filename()
                self.assertTrue(os.path.exists(f2))
                self.assertTrue(f2.startswith("4NDR0-TRACKER2_"))
            finally:
                os.chdir(old_cwd)

    def test_04_select_file_with_fzf_timeout_and_stderr_passthrough(self) -> None:
        with mock.patch("subprocess.run") as m_run:
            m_run.return_value = subprocess.CompletedProcess(
                args=["fzf"], returncode=0, stdout=" /tmp/selected.txt \n"
            )
            res = tracker.select_file_with_fzf()
            self.assertEqual(res, "/tmp/selected.txt")
            _, kwargs = m_run.call_args
            self.assertEqual(kwargs.get("stdout"), subprocess.PIPE)
            self.assertIsNone(kwargs.get("stderr"))
            self.assertEqual(kwargs.get("timeout"), tracker._FZF_TIMEOUT)

            m_run.side_effect = subprocess.TimeoutExpired(cmd="fzf", timeout=120)
            self.assertIsNone(tracker.select_file_with_fzf())

    def test_05_read_raw_input_eof_and_direct_pipe_preservation(self) -> None:
        # Immediate EOF on menu prompt returns "" without raising EOFError
        with mock.patch("sys.argv", ["4ndr0tracker.py"]):
            with mock.patch("builtins.input", side_effect=EOFError):
                self.assertEqual(tracker.read_raw_input(), "")

        # Direct piped URLs without leading "1" or "2" preserves the first line
        inputs = iter(["https://example.com/video-1", "https://example.com/video-2", "", ""])
        with mock.patch("sys.argv", ["4ndr0tracker.py"]):
            with mock.patch("builtins.input", side_effect=lambda *a: next(inputs)):
                raw = tracker.read_raw_input()
                self.assertIn("https://example.com/video-1", raw)
                self.assertIn("https://example.com/video-2", raw)

    def test_06_fetch_base64_fonts_success_and_fallback(self) -> None:
        fake_css = b"@font-face { src: url('https://fonts.gstatic.com/s/font.woff2') format('woff2'); }"
        fake_woff = b"WOFF2BYTES"
        with mock.patch.object(tracker, "_fetch", side_effect=[fake_css, fake_woff]):
            out = tracker.fetch_base64_fonts()
            self.assertIn("data:font/woff2;charset=utf-8;base64,", out)
            self.assertNotIn("https://fonts.gstatic.com/s/font.woff2", out)

        with mock.patch.object(tracker, "_fetch", side_effect=urllib.error.URLError("offline")):
            fallback = tracker.fetch_base64_fonts()
            self.assertIn('<link rel="preconnect"', fallback)

    def test_07_generate_html_and_orphan_cleanup(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            out_path = os.path.join(td, "4NDR0-TRACKER1_test.html")
            urls = [
                "https://example.com/v/one",
                'https://example.com/v/two?x=1&y="2"',
            ]
            with mock.patch.object(tracker, "fetch_base64_fonts", return_value="<style></style>"):
                tracker.generate_html(urls, out_path)

            content = Path(out_path).read_text(encoding="utf-8")
            self.assertIn("4NDR0-TRACKER — 2 Units", content)
            self.assertIn('data-url="https://example.com/v/one"', content)
            self.assertIn('data-url="https://example.com/v/two?x=1&amp;y=&quot;2&quot;"', content)
            self.assertIn("function safeLoadArray(key)", content)
            self.assertIn("function finalizeLeave(li, url)", content)
            self.assertIn("function finalizeEnter(li, url)", content)
            self.assertIn("pendingTimers", content)


if __name__ == "__main__":
    unittest.main(verbosity=2)
