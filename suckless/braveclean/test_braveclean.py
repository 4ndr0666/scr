#!/usr/bin/env python3
"""Sandboxed behavioural proofs for braveclean.c (GUP runtime harness).

Isolation: every scenario runs against a throw-away HOME under a mkdtemp tree;
the real HOME is never passed to the binary. Every subprocess carries a hard
timeout. Cleanup (tree removal, fake-process kill) lives in finally blocks.

Usage: python3 test_braveclean.py [/path/to/braveclean_binary]
       With no argument the binary ./braveclean next to this script is used
       (build it first with `make`).
"""
import os
import shutil
import signal
import sqlite3
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
BIN = os.path.abspath(sys.argv[1] if len(sys.argv) > 1
                      else os.path.join(HERE, "braveclean"))
if not (os.path.isfile(BIN) and os.access(BIN, os.X_OK)):
    sys.exit("test_braveclean: binary not found or not executable: %s\n"
             "Build it first (`make`) or pass its path as the first argument." % BIN)
RESULTS = []


def record(name, ok, detail):
    RESULTS.append((name, ok, detail))
    print("[%s] %s -- %s" % ("PASS" if ok else "FAIL", name, detail))


def mkfile(path, data=b"x"):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(data)


def bloated_db(path):
    """Create a sqlite db whose file stays large after rows are deleted."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    c = sqlite3.connect(path)
    c.execute("CREATE TABLE t(id INTEGER PRIMARY KEY, b BLOB)")
    c.executemany("INSERT INTO t(b) VALUES (?)", [(os.urandom(1024),) for _ in range(3000)])
    c.commit()
    c.execute("DELETE FROM t")
    c.commit()
    c.close()


def run_tool(home, args=(), env_extra=None, stdin="y\n"):
    env = {"HOME": home, "PATH": os.environ.get("PATH", "/usr/bin:/bin")}
    if env_extra:
        env.update(env_extra)
    p = subprocess.run([BIN, *args], input=stdin, text=True, capture_output=True,
                       env=env, timeout=120)
    return p


def wal_snapshot(tmp, name):
    """Return (src_conn, [paths]) -- a crash-state copy of a WAL db whose last
    900 committed rows exist ONLY in the -wal file (never checkpointed)."""
    live = os.path.join(tmp, name + ".live.sqlite")
    c = sqlite3.connect(live)
    c.execute("PRAGMA journal_mode=WAL")
    c.execute("PRAGMA wal_autocheckpoint=0")
    c.execute("CREATE TABLE kv(k INTEGER PRIMARY KEY, v TEXT)")
    c.executemany("INSERT INTO kv(v) VALUES (?)", [("base",)] * 100)
    c.commit()
    c.execute("PRAGMA wal_checkpoint(TRUNCATE)")
    c.executemany("INSERT INTO kv(v) VALUES (?)", [("wal-only",)] * 900)
    c.commit()
    return c, live


def count_rows(path):
    c = sqlite3.connect(path)
    try:
        return c.execute("SELECT count(*) FROM kv").fetchone()[0]
    finally:
        c.close()


def scenario_main():
    tmp = tempfile.mkdtemp(prefix="bc_sandbox_", dir=HERE)
    live_conn = None
    try:
        home = os.path.join(tmp, "home")
        brave = os.path.join(home, ".config/BraveSoftware/Brave-Browser")
        dflt = os.path.join(brave, "Default")
        for d in ("GPUCache", "Code Cache", "Service Worker", "DawnCache"):
            mkfile(os.path.join(dflt, d, "blob"))
        bloated_db(os.path.join(dflt, "foo.sqlite"))      # *.sqlite
        bloated_db(os.path.join(dflt, "History"))         # extensionless, as Chromium names its DBs
        hist_before = os.path.getsize(os.path.join(dflt, "History"))
        prefs = os.path.join(dflt, "Preferences")                       # non-SQLite, extensionless
        mkfile(prefs, b'{"a": 1}')
        foo_before = os.path.getsize(os.path.join(dflt, "foo.sqlite"))
        mkfile(os.path.join(brave, "Guest Profile", "root_marker"))     # real Chromium layout
        mkfile(os.path.join(dflt, "Guest Profile", "nested_marker"))    # where the code looks

        # Firefox profile holding a crash-state WAL database
        ff = os.path.join(home, ".mozilla/firefox")
        os.makedirs(os.path.join(ff, "abc.default"))
        with open(os.path.join(ff, "profiles.ini"), "w") as f:
            f.write("[Profile0]\nName=x\nIsRelative=1\nPath=abc.default\nDefault=1\n")
        live_conn, live = wal_snapshot(tmp, "places")
        key4 = os.path.join(ff, "abc.default", "key4.db")               # NSS key store: must stay untouched
        bloated_db(key4)
        key4_before = os.path.getsize(key4)
        snap_ctl = os.path.join(tmp, "ctl.sqlite")
        snap_tgt = os.path.join(ff, "abc.default", "places.sqlite")
        for src_suffix, dst in (("", snap_ctl), ("", snap_tgt)):
            shutil.copy(live, dst)
            shutil.copy(live + "-wal", dst + "-wal")
        ctl_rows = count_rows(snap_ctl)
        record("T0 control: crash snapshot recovers all committed rows", ctl_rows == 1000,
               "rows readable by SQLite recovery = %d (expect 1000)" % ctl_rows)

        p = run_tool(home)  # NO --deep-clean
        record("T1 tool exits 0 in sandbox", p.returncode == 0, "rc=%d" % p.returncode)
        have_notify = shutil.which("notify-send") is not None
        record("T1b notify-send absent -> console fallback printed",
               have_notify or "Cleanup complete!" in p.stdout,
               "notify-send present=%s" % have_notify)

        gone = {d: not os.path.exists(os.path.join(dflt, d))
                for d in ("GPUCache", "Code Cache", "Service Worker", "DawnCache")}
        help_txt = run_tool(home, ["--help"]).stdout
        deep_par = help_txt.split("-d, --deep-clean")[1].split("-h, --help")[0]
        record("T2 help text matches behaviour: standard set always removed, not listed under -d",
               gone["GPUCache"] and gone["Code Cache"] and gone["Service Worker"]
               and "GPUCache" not in deep_par and "Always removed" in help_txt,
               "removed=%s; GPUCache listed under -d=%s" % (gone, "GPUCache" in deep_par))
        record("T2b WITHOUT -d: DawnCache is preserved (true opt-in target)", not gone["DawnCache"],
               "DawnCache removed=%s" % gone["DawnCache"])

        foo_after = os.path.getsize(os.path.join(dflt, "foo.sqlite"))
        hist_after = os.path.getsize(os.path.join(dflt, "History"))
        record("T3a *.sqlite database is vacuumed", foo_after < foo_before,
               "foo.sqlite %d -> %d bytes" % (foo_before, foo_after))
        record("T3b extensionless Chromium DB (History) is vacuumed", hist_after < hist_before,
               "History %d -> %d bytes (unchanged => never targeted)" % (hist_before, hist_after))
        record("T3c non-SQLite extensionless file (Preferences) is left byte-identical",
               open(prefs, "rb").read() == b'{"a": 1}', "content intact")
        record("T3d Firefox key4.db is NOT vacuumed (strict *.sqlite for Firefox)",
               os.path.getsize(key4) == key4_before,
               "key4.db %d -> %d bytes" % (key4_before, os.path.getsize(key4)))

        root_marker = os.path.exists(os.path.join(brave, "Guest Profile", "root_marker"))
        nested_marker = os.path.exists(os.path.join(dflt, "Guest Profile", "nested_marker"))
        record("T4 Guest Profile at <user-data-root>/Guest Profile is cleared", not root_marker,
               "root marker survives=%s; nested Default/Guest Profile marker survives=%s"
               % (root_marker, nested_marker))

        tgt_rows = count_rows(snap_tgt) if os.path.exists(snap_tgt) else -1
        record("T5 committed WAL-only rows survive the run", tgt_rows == 1000,
               "rows after tool = %d (before = 1000)" % tgt_rows)
    finally:
        if live_conn is not None:
            try:
                live_conn.close()
            except sqlite3.Error:
                pass
        shutil.rmtree(tmp, ignore_errors=True)


def scenario_deep():
    tmp = tempfile.mkdtemp(prefix="bc_sandbox_", dir=HERE)
    try:
        home = os.path.join(tmp, "home")
        dflt = os.path.join(home, ".config/BraveSoftware/Brave-Browser/Default")
        for d in ("DawnCache", "Crash Reports", "Local Traces"):
            mkfile(os.path.join(dflt, d, "blob"))
        p = run_tool(home, ["--deep-clean"])
        gone = all(not os.path.exists(os.path.join(dflt, d))
                   for d in ("DawnCache", "Crash Reports", "Local Traces"))
        record("T6 WITH -d: extended targets removed", p.returncode == 0 and gone,
               "rc=%d removed_all=%s" % (p.returncode, gone))
        h = run_tool(home, ["--help"])
        bad = run_tool(home, ["--bogus"])
        record("T7 --help rc=0, unknown option rc=1", h.returncode == 0 and bad.returncode == 1,
               "help rc=%d, bogus rc=%d" % (h.returncode, bad.returncode))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def spawn_fake_chrome(tmp):
    fb = tempfile.mkdtemp(prefix="fakebin_", dir=tmp)
    fake = os.path.join(fb, "chrome")
    shutil.copy(shutil.which("sleep"), fake)
    return subprocess.Popen([fake, "300"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def alive(proc):
    return proc.poll() is None


def scenario_failopen():
    tmp = tempfile.mkdtemp(prefix="bc_sandbox_", dir=HERE)
    procs = []
    try:
        home = os.path.join(tmp, "home")
        os.makedirs(os.path.join(home, ".config/chromium/Default"))

        # control: normal PATH -> running browser is terminated
        c1 = spawn_fake_chrome(tmp)
        procs.append(c1)
        time.sleep(0.3)
        p = run_tool(home)
        time.sleep(0.3)
        record("T8a control: pgrep/pkill available -> live 'chrome' is terminated",
               "Terminating" in p.stdout and not alive(c1),
               "terminate_msg=%s still_alive=%s" % ("Terminating" in p.stdout, alive(c1)))

        # fail-open: pgrep unresolvable -> exit 127 is read as 'not running'
        c2 = spawn_fake_chrome(tmp)
        procs.append(c2)
        time.sleep(0.3)
        p = run_tool(home, env_extra={"PATH": "/nonexistent"})
        proceeded = "Detected Engine" in p.stdout
        record("T8b pgrep missing -> tool aborts (rc 2) and does not clean",
               p.returncode == 2 and not proceeded and alive(c2),
               "tool_proceeded_to_clean=%s browser_still_alive=%s rc=%d"
               % (proceeded, alive(c2), p.returncode))

        # pkill missing while pgrep works: the TERM stage must also fail closed
        c3 = spawn_fake_chrome(tmp)
        procs.append(c3)
        time.sleep(0.3)
        only = tempfile.mkdtemp(prefix="pgrep_only_", dir=tmp)
        os.symlink(shutil.which("pgrep"), os.path.join(only, "pgrep"))
        os.symlink(shutil.which("timeout"), os.path.join(only, "timeout"))
        p = run_tool(home, env_extra={"PATH": only})
        record("T8c pkill missing (pgrep present) -> tool aborts (rc 2) and does not clean",
               p.returncode == 2 and "Detected Engine" not in p.stdout and alive(c3),
               "rc=%d proceeded=%s browser_still_alive=%s"
               % (p.returncode, "Detected Engine" in p.stdout, alive(c3)))

        # pgrep that hangs: the hard timeout must trip and the run must abort
        hang = tempfile.mkdtemp(prefix="hang_", dir=tmp)
        fake_pgrep = os.path.join(hang, "pgrep")
        with open(fake_pgrep, "w") as f:
            f.write("#!/bin/sh\nexec sleep 120\n")
        os.chmod(fake_pgrep, 0o755)
        t0 = time.time()
        p = run_tool(home, env_extra={"PATH": hang + os.pathsep + os.environ.get("PATH", "")})
        dt = time.time() - t0
        record("T8d hung pgrep -> hard timeout trips, tool aborts (rc 2) in < 20 s",
               p.returncode == 2 and dt < 20 and "Detected Engine" not in p.stdout,
               "rc=%d elapsed=%.1fs" % (p.returncode, dt))
    finally:
        for pr in procs:
            if alive(pr):
                pr.send_signal(signal.SIGKILL)
                pr.wait(timeout=10)
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    scenario_main()
    scenario_deep()
    scenario_failopen()
    fails = [r for r in RESULTS if not r[1]]
    print("\nSUMMARY: %d/%d checks passed" % (len(RESULTS) - len(fails), len(RESULTS)))
    for n, _, d in fails:
        print("  FAILED: %s" % n)
    sys.exit(1 if fails else 0)
