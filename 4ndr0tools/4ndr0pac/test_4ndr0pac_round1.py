#!/usr/bin/env python3
"""Behavioral regression suite for 4ndr0pac Round 1 (zero-orphan cleanup, Arch News, journalctl p3)."""
import os
import pathlib
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent

SAMPLE_RSS = b"""<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"><channel><title>Arch Linux: Recent news updates</title>
  <item>
    <title>Manual intervention for foo 2.0</title>
    <pubDate>Tue, 24 Nov 2026 12:00:00 +0000</pubDate>
    <description>&lt;p&gt;Run &lt;code&gt;pacman -Syu&lt;/code&gt; &amp;amp; check config.&lt;/p&gt;</description>
  </item>
  <item>
    <title>Older notice</title>
    <pubDate>Mon, 01 Jan 2024 00:00:00 +0000</pubDate>
    <description>&lt;p&gt;Old item.&lt;/p&gt;</description>
  </item>
</channel></rss>
"""


def test_arch_news():
    with tempfile.TemporaryDirectory(dir=str(ROOT / ".4ndr0")) as td:
        feed = pathlib.Path(td) / "feed.xml"
        feed.write_bytes(SAMPLE_RSS)
        p = subprocess.run(
            [sys.executable, str(ROOT / "arch_news.py"), "--feed-file", str(feed), "--since", "2026-01-01"],
            capture_output=True, text=True, check=False,
        )
        assert p.returncode == 0, f"arch_news failed: {p.stderr}"
        assert "Manual intervention for foo 2.0" in p.stdout
        assert "pacman -Syu & check config." in p.stdout
        assert "Older notice" not in p.stdout

        bad = pathlib.Path(td) / "bad.xml"
        bad.write_bytes(b"<not-valid-xml")
        p_bad = subprocess.run(
            [sys.executable, str(ROOT / "arch_news.py"), "--feed-file", str(bad)],
            capture_output=True, text=True, check=False,
        )
        assert p_bad.returncode == 1, "malformed RSS must fail closed with rc=1"


def test_func_cleanup_zero_orphan():
    backend = (ROOT / "4ndr0pac.sh").read_text(encoding="utf-8")
    # Extract func_cleanup body cleanly
    start = backend.index("func_cleanup() {")
    end = backend.index("\n# ==============================================================================\n# FUNC_TOPGRADE", start)
    func_src = backend[start:end]

    with tempfile.TemporaryDirectory(dir=str(ROOT / ".4ndr0")) as td:
        td_path = pathlib.Path(td)
        bin_dir = td_path / "bin"
        bin_dir.mkdir()
        (bin_dir / "sudo").write_text('#!/usr/bin/env bash\nexit 0\n', encoding="utf-8")
        # Simulate real Arch pacman -Qtdq when 0 orphans exist: rc=1, empty stdout, empty stderr
        (bin_dir / "pacman").write_text('#!/usr/bin/env bash\nif [[ "${1:-}" == "-Qtdq" ]]; then exit 1; fi\nexit 0\n', encoding="utf-8")
        for f in ("sudo", "pacman"):
            os.chmod(bin_dir / f, 0o755)

        script = td_path / "run_cleanup.sh"
        script.write_text(
            "#!/usr/bin/env bash\nset -euo pipefail\nCYAN='' BRED='' BOLD='' RESET=''\n"
            + func_src
            + "\nprintf 'n\\nn\\n' | func_cleanup\n",
            encoding="utf-8",
        )
        env = {k: v for k, v in os.environ.items() if k != "BASH_ENV"}
        env["PATH"] = str(bin_dir) + ":" + env["PATH"]
        p = subprocess.run(["bash", str(script)], env=env, capture_output=True, text=True)
        assert p.returncode == 0, f"zero-orphan cleanup aborted unexpectedly: rc={p.returncode}, out={p.stdout}, err={p.stderr}"
        assert "no orphaned packages found." in p.stdout

        # Now simulate a real pacman -Qtdq operational error (rc=1 + stderr) -> must fail closed!
        (bin_dir / "pacman").write_text('#!/usr/bin/env bash\nif [[ "${1:-}" == "-Qtdq" ]]; then echo "error: could not open db" >&2; exit 1; fi\nexit 0\n', encoding="utf-8")
        os.chmod(bin_dir / "pacman", 0o755)
        p_err = subprocess.run(["bash", str(script)], env=env, capture_output=True, text=True)
        assert p_err.returncode == 1, f"real pacman -Qtdq error must fail closed, got rc={p_err.returncode}"
        assert "Unable to query orphaned packages" in p_err.stdout


def test_consolidation_surfaces():
    backend = (ROOT / "4ndr0pac.sh").read_text(encoding="utf-8")
    frontend = (ROOT / "4ndr0pac").read_text(encoding="utf-8")
    assert "func_news()" in backend, "func_news missing from 4ndr0pac.sh"
    assert "journalctl -p 3 -xb" in backend, "journalctl p3 check missing from func_analyze"
    assert '("Arch Linux News", "news", False)' in frontend, "Arch Linux News missing from Python frontend"
    assert 'VERSION = "1.7.0"' in frontend, "frontend version not bumped to 1.7.0"
    assert "v1.7.0" in backend, "backend version not aligned to v1.7.0"


if __name__ == "__main__":
    test_arch_news()
    test_func_cleanup_zero_orphan()
    test_consolidation_surfaces()
    print("[test_4ndr0pac_round1] 3/3 suites passed")
