#!/usr/bin/python3
"""
Author: 4ndr0666
=================== // VACUUM.PY //
This script bundles many common system-maintenance tasks
(package verification, journal cleanup, orphan removal, etc.)
behind an interactive TUI.  **It must be run as root.**
"""

from __future__ import annotations

import datetime
import itertools
import json
import logging
import logging.handlers
import os
import select
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
import time
from contextlib import contextmanager
from pathlib import Path
from typing import Callable, List

# Optional third-party (fail-soft where missing)

try:
    import netifaces  # Used in security_audit()
except ModuleNotFoundError:  # pragma: no cover
    netifaces = None

# Configurable paths / defaults

XDG_DATA_HOME: str = os.environ.get(
    "XDG_DATA_HOME", os.path.expanduser("~/.local/share")
)
LOG_BASE_DIR: str = os.path.join(XDG_DATA_HOME, "vacuum_logs")
DEFAULT_JOURNAL_RETENTION: str = "1d"
DEFAULT_PACCACHE_RETAIN: int = 2
DEFAULT_TEMP_AGE_DAYS: int = 2
DEFAULT_SWAPPINESS: int = 60
DEFAULT_LOG_PRIORITY: int = 3
DEFAULT_CRON_DAYS_BACK: int = 1
DEFAULT_UNUSED_SERVICES: list[str] = [
    "bluetooth.service",
    "cups.service",
    "geoclue.service",
    "avahi-daemon.service",
    "sshd.service",
]

# Colour / Glyphs

GREEN = "\033[0;36m"  # Made CYAN intentionally
YELLOW = "\033[0;33m"
RED = "\033[0;31m"
BOLD = "\033[1m"
NC = "\033[0m"
SUCCESS = "✔️"
FAILURE = "❌"
INFO = "➡️"
WARNING = "⚠️"

# Spinner setup

SPINNER_STYLES: dict[str, str] = {
    "dots": "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏",
    "bars": "|/-\\",
    "arrows": "←↖↑↗→↘↓↙",
}
DEFAULT_SPINNER_STYLE: str = SPINNER_STYLES["dots"]  # ← **do not change**


@contextmanager
def spinning_spinner(symbols: str = DEFAULT_SPINNER_STYLE, speed: float = 0.1):
    """Console spinner; use only when *no* user input is expected."""
    run_flag = threading.Event()
    run_flag.set()
    cycle = itertools.cycle(symbols)

    def _spin():
        while run_flag.is_set():
            sys.stdout.write(next(cycle) + "\r")
            sys.stdout.flush()
            time.sleep(speed)

    thread = threading.Thread(target=_spin, daemon=True)
    thread.start()
    try:
        yield
    finally:
        run_flag.clear()
        thread.join(timeout=speed * 2)
        sys.stdout.write(" " * 80 + "\r")
        sys.stdout.flush()


# Utility functions


def format_message(msg: str, colour: str) -> str:
    return f"{BOLD}{colour}{msg}{NC}"


def log_and_print(msg: str, level: str = "info") -> None:
    print(msg)
    getattr(logging, level, logging.info)(msg)


def execute_command(
    command: List[str],
    *,
    error_message: str | None = None,
    check: bool = False,
    capture_output: bool = True,
    text: bool = True,
    **kwargs,
) -> subprocess.CompletedProcess:
    """Wrapper around subprocess.run with consistent logging."""
    logging.debug("Exec: %s", " ".join(command))
    try:
        cp = subprocess.run(
            command,
            capture_output=capture_output,
            text=text,
            check=check,
            **kwargs,
        )
        if cp.stdout:
            logging.debug("stdout ▶ %s", cp.stdout.rstrip())
        if cp.stderr:
            logging.debug("stderr ▶ %s", cp.stderr.rstrip())
        if cp.returncode != 0 and not check:
            msg = error_message or f"Command failed: {' '.join(command)}"
            log_and_print(format_message(msg, RED), "error")
        return cp
    except FileNotFoundError:
        msg = error_message or f"Command not found: {command[0]}"
        log_and_print(format_message(msg, RED), "error")
        logging.error(msg)
        return subprocess.CompletedProcess(command, 127, "", msg)
    except subprocess.CalledProcessError as exc:
        msg = error_message or f"Cmd failed: {' '.join(exc.cmd)}"
        logging.error("%s\n%s", msg, exc.stderr or exc.output)
        if not check:
            log_and_print(format_message(msg, RED), "error")
        raise
    except Exception as exc:  # noqa: BLE001
        msg = error_message or f"Unexpected error: {exc}"
        logging.exception(msg)
        log_and_print(format_message(msg, RED), "error")
        return subprocess.CompletedProcess(command, -1, "", str(exc))


def prompt_with_timeout(
    prompt: str,
    *,
    timeout: int = 30,
    default: str = "Q",
    persistent: bool = False,
) -> str:
    """Prompt user; auto-return *default* after *timeout* (unless persistent)."""
    if persistent:
        while True:
            ans = input(prompt).strip()
            if ans:
                return ans
            log_and_print(f"{INFO} Input required.", "info")
    else:
        sys.stdout.write(prompt)
        sys.stdout.flush()
        ready, _, _ = select.select([sys.stdin], [], [], timeout)
        if ready:
            ans = sys.stdin.readline().strip()
            return ans or default
        print(f"\n{YELLOW}No input in {timeout}s; default '{default}'.{NC}")
        return default


def is_interactive() -> bool:
    return sys.stdin.isatty()


UNSAFE_DELETE_PATHS: list[str] = ["/", "/srv", "/boot", "/etc", "/usr", "/bin", "/var"]


def is_path_safe_to_delete(path: str) -> bool:
    path = os.path.abspath(path)
    return not any(
        path == bad or path.startswith(bad + os.sep) for bad in UNSAFE_DELETE_PATHS
    )


# Logging setup


def _setup_logging() -> None:
    os.makedirs(LOG_BASE_DIR, exist_ok=True)
    logfile = Path(LOG_BASE_DIR) / f"{datetime.datetime.now():%Y%m%d_%H%M%S}.log"
    formatter = logging.Formatter("%(asctime)s | %(levelname)-8s | %(message)s")

    fh = logging.handlers.RotatingFileHandler(
        logfile, maxBytes=2_000_000, backupCount=5, encoding="utf-8"
    )
    fh.setFormatter(formatter)
    fh.setLevel(logging.DEBUG)

    ch = logging.StreamHandler(sys.stdout)
    ch.setFormatter(formatter)
    ch.setLevel(logging.INFO)

    logging.basicConfig(level=logging.DEBUG, handlers=[fh, ch])
    logging.info("===== Vacuum session started =====")


_setup_logging()

# Permissions


def fix_permissions(
    target: str,
    *,
    file_mode: int = 0o644,
    dir_mode: int = 0o755,
    owner: str | None = None,
    group: str | None = None,
    recursive: bool = False,
) -> None:
    owner = owner or os.getlogin()
    group = group or owner

    def _apply(p: Path, is_dir: bool) -> None:
        try:
            os.chmod(p, dir_mode if is_dir else file_mode)
            shutil.chown(p, user=owner, group=group)
            logging.debug("Perms fixed: %s", p)
        except (PermissionError, OSError) as exc:
            log_and_print(format_message(f"{FAILURE} {p}: {exc}", RED), "error")

    p = Path(target)
    if p.is_file():
        _apply(p, False)
    elif p.is_dir():
        _apply(p, True)
        if recursive:
            for root, dirs, files in os.walk(p):
                for d in dirs:
                    _apply(Path(root) / d, True)
                for f in files:
                    _apply(Path(root) / f, False)
    else:
        log_and_print(
            format_message(f"{WARNING} Path missing: {target}", YELLOW), "warning"
        )


# Dependencies


def install_missing_dependency_batch(deps: List[str]) -> None:
    missing: list[str] = []
    for dep in deps:
        if execute_command(["pacman", "-Qi", dep]).returncode != 0:
            missing.append(dep)
    if not missing:
        return
    log_and_print(f"{INFO} Installing deps: {', '.join(missing)}", "info")
    execute_command(
        ["sudo", "pacman", "-Sy", "--needed", "--noconfirm", *missing],
        error_message="Dependency install failed",
        check=False,
    )


def install_missing_dependency(dep: str) -> None:
    install_missing_dependency_batch([dep])


# Dependency-scan Processor


def process_dep_scan_log() -> None:
    scan_file = Path(XDG_DATA_HOME) / "logs" / "dependency_scan.jsonl"
    if not scan_file.is_file():
        log_and_print(
            format_message(
                f"{WARNING} No dependency_scan.jsonl at {scan_file}", YELLOW
            ),
            "warning",
        )
        return

    perms: list[str] = []
    deps: list[str] = []

    with spinning_spinner(), scan_file.open(encoding="utf-8") as fh:
        for line in fh:
            if not line.strip():
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            match entry.get("issue_type"):
                case "permission_warning":
                    perms.append(entry.get("target", ""))
                case "missing_dependency":
                    deps.append(entry.get("target", ""))

    for p in set(perms):
        fix_permissions(p, recursive=True)
    install_missing_dependency_batch(list(set(deps)))

    log_and_print(f"{SUCCESS} Dependency log handled.", "info")


# Cron manager


def _write_crontab(content: str) -> None:
    with tempfile.NamedTemporaryFile("w+", delete=False, encoding="utf-8") as tf:
        tf.write(content)
        temp = tf.name
    os.chmod(temp, 0o600)
    try:
        execute_command(["sudo", "crontab", temp], check=True)
    finally:
        Path(temp).unlink(missing_ok=True)


# Cron tasks


def manage_cron_job() -> None:
    """
    Interactive cron-job editor:
      • Lists existing system-wide crontab entries
      • Shows any FAILED cron logs in the last 24 h
      • Lets the user add or delete entries
    """
    log_and_print(f"{INFO} Managing system cron …", "info")

    # --- show current crontab -------------------------------------------------
    current = execute_command(["sudo", "crontab", "-l"], check=False)
    lines: list[str] = (
        [ln for ln in current.stdout.splitlines() if ln.strip()]
        if current.stdout
        else []
    )
    if lines:
        print("\nCurrent system crontab:")
        for i, ln in enumerate(lines, 1):
            print(f" {i:2d}) {ln}")
    else:
        print("\n(no entries)")

    # --- show failures --------------------------------------------------------
    fail_journal = execute_command(
        ["journalctl", "-u", "cron", "--since", "24 hours ago"], check=False
    ).stdout
    failed = (
        [ln for ln in fail_journal.splitlines() if "FAILED" in ln.upper()]
        if fail_journal
        else []
    )
    if failed:
        log_and_print(
            format_message("Recent cron failures detected:", YELLOW), "warning"
        )
        for ln in failed:
            print(ln)

    # --- user action ----------------------------------------------------------
    action = prompt_with_timeout("(A)dd / (D)elete / (Q)uit: ", persistent=True).lower()
    if action == "a":
        new_entry = input("Enter full crontab line: ").rstrip()
        if new_entry:
            lines.append(new_entry)
            _write_crontab("\n".join(lines) + "\n")
            log_and_print(f"{SUCCESS} Entry added.", "info")
        return

    if action == "d":
        if not lines:
            return
        try:
            idx = int(input("Delete entry #: ").strip())
            if 1 <= idx <= len(lines):
                del lines[idx - 1]
                _write_crontab("\n".join(lines) + ("\n" if lines else ""))
                log_and_print(f"{SUCCESS} Entry removed.", "info")
        except (ValueError, IndexError):
            log_and_print(format_message("Invalid selection.", RED), "error")
        return


# Broken-symlink cleaner


def remove_broken_symlinks() -> None:
    """Find and delete dangling symlinks below $HOME."""
    home = Path.home()
    res = execute_command(["find", str(home), "-xtype", "l"], check=False)
    broken = [ln for ln in res.stdout.splitlines() if ln.strip()] if res.stdout else []
    if not broken:
        log_and_print(f"{SUCCESS} No broken symlinks.", "info")
        return

    print("\nDangling symlinks:")
    for ln in broken:
        print(" ", ln)

    if prompt_with_timeout("Remove all? [y/N]: ", persistent=True).lower() != "y":
        return

    with spinning_spinner():
        for link in broken:
            try:
                os.remove(link)
                logging.info("Removed %s", link)
            except OSError as exc:
                logging.error("Failed removing %s: %s", link, exc)
    log_and_print(f"{SUCCESS} Broken symlinks removed.", "info")


# Kernel housekeeping


def clean_old_kernels() -> None:
    """
    Identify orphaned kernel packages (pacman -Qdtq → startswith 'linux')
    and remove them via pacman -Rns after confirmation.
    """
    log_and_print(f"{INFO} Scanning for orphan kernels …", "info")
    cp = execute_command(["pacman", "-Qdtq"], check=False)
    if cp.returncode not in (0, 1):  # 1 == no orphans
        log_and_print(format_message("pacman -Qdtq failed.", RED), "error")
        return

    kernels = [p for p in cp.stdout.splitlines() if p.startswith("linux")]
    if not kernels:
        log_and_print(f"{SUCCESS} No orphan kernel packages.", "info")
        return

    print("\nOrphan kernels:")
    for k in kernels:
        print(" ", k)

    if (
        prompt_with_timeout("Remove with pacman -Rns? [y/N]: ", persistent=True).lower()
        != "y"
    ):
        return

    with spinning_spinner():
        rm = execute_command(
            ["sudo", "pacman", "-Rns", "--noconfirm", *kernels], check=False
        )
        if rm.returncode == 0:
            log_and_print(f"{SUCCESS} Orphan kernels removed.", "info")
        else:
            log_and_print(
                format_message("Kernel removal errors occurred.", RED), "error"
            )


# Journal vacuuming


def vacuum_journalctl(retention: str = DEFAULT_JOURNAL_RETENTION) -> None:
    log_and_print(f"{INFO} Vacuuming journal older than {retention} …", "info")
    cp = execute_command(
        ["sudo", "journalctl", f"--vacuum-time={retention}"], check=False
    )
    if cp.returncode == 0:
        log_and_print(f"{SUCCESS} Journal trimmed.", "info")
    else:
        log_and_print(format_message("journalctl vacuum failed.", RED), "error")


# Font-cache refresh


def update_font_cache() -> None:
    log_and_print(f"{INFO} Rebuilding font cache …", "info")
    cp = execute_command(["sudo", "fc-cache", "-fv"], check=False)
    if cp.returncode == 0:
        log_and_print(f"{SUCCESS} Font cache updated.", "info")


# Trash-bin cleanup


def _trash_dirs() -> list[str]:
    dirs: list[str] = []
    for path in Path("/home").glob("*"):
        t = path / ".local/share/Trash"
        if t.is_dir():
            dirs.append(str(t))
    root_trash = Path("/root/.local/share/Trash")
    if root_trash.is_dir():
        dirs.append(str(root_trash))
    return dirs


def clear_trash() -> None:
    dirs = _trash_dirs()
    if not dirs:
        log_and_print(f"{SUCCESS} No trash directories.", "info")
        return
    if prompt_with_timeout("Empty all trash? [y/N]: ", persistent=True).lower() != "y":
        return

    with spinning_spinner():
        for d in dirs:
            for item in Path(d).iterdir():
                try:
                    if item.is_dir():
                        shutil.rmtree(item, ignore_errors=True)
                    else:
                        item.unlink(missing_ok=True)
                except OSError as exc:
                    logging.warning("Failed deleting %s: %s", item, exc)
    log_and_print(f"{SUCCESS} Trash emptied.", "info")


# Database optimisation


def optimize_databases(skips: list[str] | None = None) -> None:
    """
    Refresh a handful of local databases.  Pass step-IDs via *skips* to omit.
    IDs:  mlocate  pkgfile  pacman-key  pacman-sync  sync
    """
    skips = skips or []
    steps: dict[str, tuple[list[str], str]] = {
        "mlocate": (["sudo", "updatedb"], "mlocate DB updated"),
        "pkgfile": (["sudo", "pkgfile", "-u"], "pkgfile DB updated"),
        "pacman-key": (
            ["sudo", "pacman-key", "--refresh-keys"],
            "pacman keys refreshed",
        ),
        "pacman-sync": (["sudo", "pacman", "-Syy"], "Pacman sync complete"),
        "sync": (["sync"], "Filesystem synced"),
    }

    log_and_print(f"{INFO} Optimising databases …", "info")
    with spinning_spinner():
        for key, (cmd, msg) in steps.items():
            if key in skips:
                logging.debug("Skipped %s", key)
                continue
            cp = execute_command(cmd, check=False)
            if cp.returncode == 0:
                logging.info(msg)
            else:
                logging.warning("Step %s returned non-zero", key)


# Package-cache maintenance


def clean_package_cache(retain_versions: int = DEFAULT_PACCACHE_RETAIN) -> None:
    """Run *paccache -rk{retain_versions}* to purge old packages."""
    if not shutil.which("paccache"):
        log_and_print(format_message("paccache not installed.", RED), "error")
        return
    log_and_print(f"{INFO} Cleaning package cache …", "info")
    execute_command(["sudo", "paccache", f"-rk{retain_versions}"], check=False)
    log_and_print(f"{SUCCESS} Cache cleaned.", "info")


def clear_cache() -> None:  # back-compat menu option
    clean_package_cache()


# AUR directory cleanup


def clean_aur_dir(aur_dir: str | None = None) -> None:
    """
    Delete package files in *aur_dir* whose version no longer matches the
    installed package.  Also offers to delete source directories.
    """
    from pathlib import Path

    aur_dir = aur_dir or os.path.expanduser("~/aur")
    pdir = Path(aur_dir)
    if not pdir.is_dir():
        log_and_print(
            format_message(f"AUR dir not found: {aur_dir}", YELLOW), "warning"
        )
        return

    pkg_re = re.compile(
        r"^(?P<name>.+)-(?P<ver>[^-]+)-x86_64\.pkg\.tar\.(?:zst|xz|gz)$"
    )
    installed: dict[str, str] = {}
    cp = execute_command(["expac", "-Qs", "%n %v"], check=False)
    if cp.returncode == 0:
        for line in cp.stdout.splitlines():
            n, v = line.split(maxsplit=1)
            installed[n] = v

    stale: list[Path] = []
    for f in pdir.iterdir():
        if f.is_file():
            m = pkg_re.match(f.name)
            if m and installed.get(m["name"]) != m["ver"]:
                stale.append(f)

    if stale:
        print("\nOut-of-date AUR packages:")
        for f in stale:
            print(" ", f.name)
        if (
            prompt_with_timeout("Delete these files? [y/N]: ", persistent=True).lower()
            == "y"
        ):
            for f in stale:
                f.unlink(missing_ok=True)
            log_and_print(f"{SUCCESS} Stale AUR packages deleted.", "info")

    # offer to purge unused source dirs
    for src in pdir.iterdir():
        if src.is_dir() and src.name not in installed:
            if (
                prompt_with_timeout(
                    f"Delete source dir {src.name}? [y/N]: ", persistent=True
                ).lower()
                == "y"
            ):
                shutil.rmtree(src, ignore_errors=True)
                logging.info("Deleted %s", src)


# Pacnew / Pacsave


def handle_pacnew_pacsave() -> None:
    """
    Locate *.pacnew / *.pacsave under /etc and allow the user to merge,
    replace (with backup) or delete each file.
    """
    log_and_print(f"{INFO} Searching for .pacnew / .pacsave …", "info")
    pacnew = execute_command(
        ["sudo", "find", "/etc", "-type", "f", "-name", "*.pacnew"], check=False
    ).stdout.splitlines()
    pacsave = execute_command(
        ["sudo", "find", "/etc", "-type", "f", "-name", "*.pacsave"], check=False
    ).stdout.splitlines()

    def _prompt_file(fn: str, mode: str) -> None:
        print(f"\n{mode}: {fn}")
        act = prompt_with_timeout(
            "(R)eplace/(D)elete/(S)kip: ", persistent=True
        ).lower()
        if act == "d":
            Path(fn).unlink(missing_ok=True)
            logging.info("Deleted %s", fn)
        elif act == "r":
            orig = fn.replace(f".{mode}", "")
            backup = orig + ".bak"
            shutil.copy2(orig, backup)
            shutil.copy2(fn, orig)
            Path(fn).unlink(missing_ok=True)
            logging.info("Replaced %s (backup at %s)", orig, backup)

    for f in pacnew:
        _prompt_file(f, "pacnew")
    for f in pacsave:
        _prompt_file(f, "pacsave")


# Pacman -Qk verify & reinstall (official only)


def verify_installed_packages() -> None:
    """
    Run pacman -Qk and offer to reinstall **official-repo** packages that
    report issues.  AUR packages are listed for manual handling.
    """
    log_and_print(f"{INFO} Checking packages with pacman -Qk …", "info")
    cp = execute_command(["pacman", "-Qk"], check=False)
    lines = [
        ln for ln in cp.stdout.splitlines() if ln and ": 0 missing files" not in ln
    ]
    if not lines:
        log_and_print(f"{SUCCESS} No package errors found.", "info")
        return

    # extract package names
    warn_re = re.compile(r"warning:\s+(\S+):")
    pkgs = {warn_re.search(ln).group(1) for ln in lines if warn_re.search(ln)}

    official, aur = [], []
    for p in pkgs:
        if is_official_package(p):
            official.append(p)
        else:
            aur.append(p)

    if official:
        ans = prompt_with_timeout(
            f"Reinstall {len(official)} official packages? [y/N]: ", persistent=True
        ).lower()
        if ans == "y":
            execute_command(
                ["sudo", "pacman", "-S", "--noconfirm", "--needed", *official],
                check=False,
            )

    if aur:
        log_and_print(
            format_message(
                f"AUR packages need manual reinstall:\n  {' '.join(aur)}", YELLOW
            ),
            "warning",
        )


# Cron-failure inspection


def check_failed_cron_jobs(days_back: int = DEFAULT_CRON_DAYS_BACK) -> None:
    cp = execute_command(
        ["journalctl", "-u", "cron", "--since", f"{days_back} days ago"], check=False
    )
    fails = [ln for ln in cp.stdout.splitlines() if "FAILED" in ln.upper()]
    if fails:
        log_and_print(f"{FAILURE} Cron job failures:", "error")
        for ln in fails:
            print(ln)
    else:
        log_and_print(f"{SUCCESS} No cron failures.", "info")


# ───────────────────────── Docker system prune ─────────────────────── #
def clear_docker_images(dry_run: bool = False, remove_volumes: bool = False) -> None:
    if not shutil.which("docker"):
        log_and_print(f"{INFO} Docker not installed.", "info")
        return
    cmd = ["sudo", "docker", "system", "prune", "-a", "-f"]
    if remove_volumes:
        cmd.append("--volumes")
    if dry_run:
        log_and_print(f"{INFO} [dry-run] {' '.join(cmd)}", "info")
        return
    execute_command(cmd, check=False)
    log_and_print(f"{SUCCESS} Docker cleanup complete.", "info")


# ───────────────────── /tmp & /var/tmp cleanup runner ───────────────── #
def clear_temp_folder(
    age_days: int = DEFAULT_TEMP_AGE_DAYS,
    whitelist: list[str] | None = None,
) -> None:
    whitelist = whitelist or []
    targets = ["/tmp", "/var/tmp"]
    log_and_print(f"{INFO} Removing files ≥{age_days} days old …", "info")
    for root in targets:
        files = execute_command(
            ["sudo", "find", root, "-type", "f", "-mtime", f"+{age_days}"],
            check=False,
        ).stdout.splitlines()
        files = [f for f in files if not any(w in f for w in whitelist)]
        for f in files:
            try:
                os.remove(f)
            except OSError as exc:
                logging.warning("Failed remove %s: %s", f, exc)
    log_and_print(f"{SUCCESS} Temp cleanup done.", "info")


# ───────────────────── rmshit interactive cleaner ──────────────────── #
def check_rmshit_script(config_path: str | None = None) -> None:
    """
    Read newline path list from *config_path* (defaults to LOG dir) and
    offer to delete each safe-to-remove entry.
    """
    config_path = config_path or os.path.join(LOG_BASE_DIR, "rmshit_paths.txt")
    if not Path(config_path).is_file():
        log_and_print(format_message("Path list not found.", YELLOW), "warning")
        return

    for raw in Path(config_path).read_text().splitlines():
        p = os.path.expanduser(raw.strip())
        if not p or not os.path.exists(p):
            continue
        if not is_path_safe_to_delete(p):
            log_and_print(f"{WARNING} Skipped unsafe path {p}", "warning")
            continue
        if prompt_with_timeout(f"Delete {p}? [y/N]: ", persistent=True).lower() == "y":
            try:
                if os.path.isfile(p):
                    os.remove(p)
                else:
                    shutil.rmtree(p)
                logging.info("Deleted %s", p)
            except OSError as exc:
                logging.error("Failed deleting %s: %s", p, exc)


# ──────────────── SSH known_hosts pruning & helpers ───────────────── #
def is_host_reachable(host: str) -> bool:
    """
    Resolve *host* then send a single-packet ping.
    Returns **True** on success.
    """
    try:
        socket.gethostbyname(host)
        return (
            subprocess.run(
                ["ping", "-c", "1", "-W", "1", host],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            ).returncode
            == 0
        )
    except (socket.gaierror, OSError):
        return False


def remove_old_ssh_known_hosts() -> None:
    """
    Make a backup of ~/.ssh/known_hosts, then remove any entries that neither
    resolve nor answer a ping.  Hashed hosts (leading “|”) are left untouched.
    """
    kh_file = Path.home() / ".ssh" / "known_hosts"
    if not kh_file.exists():
        log_and_print(f"{INFO} No known_hosts file found.", "info")
        return

    backup = kh_file.with_suffix(".bak")
    shutil.copy2(kh_file, backup)
    logging.info("known_hosts backup → %s", backup)

    kept: list[str] = []
    removed: list[str] = []

    for line in kh_file.read_text().splitlines():
        host_field = line.split()[0]
        if host_field.startswith("|"):  # hashed host – keep
            kept.append(line + "\n")
            continue
        host = host_field.split(",")[0]  # handle “[ip],[hostname]”
        if is_host_reachable(host):
            kept.append(line + "\n")
        else:
            removed.append(host)

    if not removed:
        log_and_print(f"{SUCCESS} All known_hosts entries appear valid.", "info")
        return

    if (
        prompt_with_timeout(
            f"Remove {len(removed)} unreachable host(s) from known_hosts? [y/N]: ",
            persistent=True,
        ).lower()
        != "y"
    ):
        log_and_print(f"{INFO} known_hosts unchanged.", "info")
        return

    kh_file.write_text("".join(kept))
    log_and_print(
        f"{SUCCESS} Pruned hosts: {', '.join(removed)} (backup kept).", "info"
    )


# ─────────────────────── Orphan Vim undo cleaner ──────────────────── #
def remove_orphan_vim_undo_files() -> None:
    """Delete *.un~ files whose original counterpart is gone."""
    count = 0
    for undo in Path.home().rglob("*.un~"):
        if not undo.with_suffix("").exists():
            try:
                undo.unlink()
                count += 1
            except OSError as exc:
                logging.warning("Couldn't delete %s: %s", undo, exc)
    if count:
        log_and_print(f"{SUCCESS} Removed {count} orphan Vim undo files.", "info")
    else:
        log_and_print(f"{INFO} No orphan Vim undo files found.", "info")


# ────────────────────────── Force log rotation ────────────────────── #
def force_log_rotation(config_path: str = "/etc/logrotate.conf") -> None:
    """Run **logrotate -f** on *config_path*."""
    if not Path(config_path).is_file():
        log_and_print(f"{FAILURE} Config {config_path} not found.", "error")
        return
    execute_command(["sudo", "logrotate", "-f", config_path], check=False)
    log_and_print(f"{SUCCESS} Log rotation forced.", "info")


# ────────────────────────────── zram utils ────────────────────────── #
def configure_zram(percentage: float = 0.25) -> None:
    """
    Create a zram device sized at *percentage* × system RAM and enable it as
    swap (priority 32767).  Skips if systemd zram service exists.
    """
    if Path("/etc/systemd/system/zram_setup.service").exists():
        log_and_print(f"{INFO} systemd zram service present – skipping.", "info")
        return
    if not shutil.which("zramctl"):
        log_and_print(f"{FAILURE} zramctl not installed.", "error")
        return

    mem_total = (
        int(subprocess.check_output(["awk", "/MemTotal/ {print $2}", "/proc/meminfo"]))
        * 1024
    )
    size_bytes = int(mem_total * percentage)

    device = subprocess.check_output(
        ["sudo", "zramctl", "--find", "--size", str(size_bytes)], text=True
    ).strip()
    execute_command(["sudo", "mkswap", device], check=True)
    execute_command(["sudo", "swapon", device, "-p", "32767"], check=True)
    log_and_print(
        f"{SUCCESS} zram {device} enabled ({size_bytes // 2**20} MiB).", "info"
    )


def check_zram_configuration() -> None:
    """Report zram status; configure if none active."""
    status = subprocess.check_output(["zramctl"]).decode()
    if "/dev/zram" in status:
        log_and_print(f"{SUCCESS} Active zram devices:\n{status}", "info")
    else:
        log_and_print(f"{WARNING} No active zram – configuring.", "warning")
        configure_zram()


# ────────────────────────── Swappiness tweak ──────────────────────── #
def adjust_swappiness(value: int = DEFAULT_SWAPPINESS) -> None:
    """sysctl vm.swappiness=<value> (runtime only)."""
    execute_command(["sudo", "sysctl", f"vm.swappiness={value}"], check=False)
    log_and_print(f"{SUCCESS} Swappiness set to {value}.", "info")


# ─────────────────────────── Drop FS caches ───────────────────────── #
def clear_system_cache() -> None:
    """Echo 3 > /proc/sys/vm/drop_caches after confirmation."""
    if (
        prompt_with_timeout(
            "Clear PageCache + dentries/inodes? [y/N]: ", persistent=True
        ).lower()
        != "y"
    ):
        return
    execute_command(
        ["sudo", "sh", "-c", "echo 3 > /proc/sys/vm/drop_caches"], check=False
    )
    log_and_print(f"{SUCCESS} System caches cleared.", "info")


# ────────────── Disable unused services (with backup list) ─────────── #
def disable_unused_services(
    services: list[str] | None = None,
    reversible: bool = True,
) -> None:
    services = services or DEFAULT_UNUSED_SERVICES
    backup: Path | None = None
    if reversible:
        backup = (
            Path(DEFAULT_LOG_DIR)
            / f"services_backup_{datetime.now():%Y%m%d_%H%M%S}.txt"
        )
        backup.write_text("Previously enabled services:\n")

    for svc in services:
        if (
            subprocess.run(
                ["systemctl", "is-enabled", svc], capture_output=True
            ).stdout.strip()
            == b"enabled"
        ):
            execute_command(["sudo", "systemctl", "disable", "--now", svc], check=False)
            log_and_print(f"{SUCCESS} Disabled {svc}", "info")
            if backup:
                backup.write_text(svc + "\n", append=True)
        else:
            logging.debug("%s already disabled / not present", svc)

    if backup and backup.stat().st_size > 30:
        log_and_print(f"{INFO} Backup saved → {backup}", "info")


# ──────────────── Restart failed systemd service units ─────────────── #
def check_and_restart_systemd_units() -> None:
    failed = subprocess.check_output(["systemctl", "--failed", "--no-legend"]).decode()
    if not failed.strip():
        log_and_print(f"{SUCCESS} No failed units.", "info")
        return

    execute_command(["sudo", "systemctl", "reset-failed"], check=False)
    for unit in (ln.split()[0] for ln in failed.splitlines() if ln.strip()):
        if (
            prompt_with_timeout(f"Restart {unit}? [y/N]: ", persistent=True).lower()
            == "y"
        ):
            execute_command(["sudo", "systemctl", "restart", unit], check=False)


# ───────────────────────── Network security audit ──────────────────── #
def _default_iface() -> str | None:
    """Return primary outbound interface name."""
    try:
        out = subprocess.check_output(["ip", "route", "show", "default"]).decode()
        return out.split()[4]
    except Exception:
        return None


def security_audit() -> None:
    """
    1. Log listening sockets.
    2. If tun0 active (ExpressVPN), scan common ports on primary interface.
    3. Warn if JDownloader ports (9665/9666) are exposed.
    """
    sockets = subprocess.check_output(["ss", "-tuln"]).decode()
    logging.info("Listening sockets:\n%s", sockets)

    if " 9665 " in sockets or " 9666 " in sockets:
        log_and_print(
            f"{WARNING} JDownloader ports detected – ensure VPN rules in place.",
            "warning",
        )

    if (
        subprocess.run(
            ["ip", "addr", "show", "dev", "tun0"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        ).returncode
        != 0
    ):
        return  # VPN not active – nothing more

    iface = _default_iface()
    if not iface:
        return
    if not shutil.which("nmap"):
        log_and_print(f"{WARNING} nmap not found – skipping scan.", "warning")
        return

    ip_addr = (
        subprocess.check_output(["ip", "-br", "addr", "show", iface])
        .decode()
        .split()[2]
        .split("/")[0]
    )
    out_file = Path(DEFAULT_LOG_DIR) / f"nmap_{iface}.txt"
    log_and_print(f"{INFO} nmap scan (1–1024) → {out_file}", "info")
    execute_command(
        ["sudo", "nmap", "-sT", "-p", "1-1024", "-oN", str(out_file), ip_addr],
        check=False,
    )


# ───────────────────────── User / group helper ─────────────────────── #
def manage_users_and_groups() -> None:
    if os.geteuid() != 0:
        log_and_print(f"{FAILURE} Run as root for user management.", "error")
        return

    helper = shutil.which("grouctl")
    if helper:
        execute_command(["sudo", helper], check=False)
        return

    print(
        "1) View user's groups\n"
        "2) Add user to group\n"
        "3) Remove user from group\n"
        "4) Quit"
    )
    choice = input("Choice: ").strip()
    if choice not in {"1", "2", "3"}:
        return
    username = input("Username: ").strip()

    if choice == "1":
        execute_command(["id", "-nG", username], check=False)
        return

    groups = (
        subprocess.check_output(["cut", "-d:", "-f1", "/etc/group"]).decode().split()
    )
    selected = select_items_from_list(groups, "Select groups: ")
    if not selected:
        return

    for g in selected:
        cmd = (
            ["usermod", "-aG", g, username]
            if choice == "2"
            else ["gpasswd", "-d", username, g]
        )
        execute_command(["sudo", *cmd], check=False)


# ─────────────────────── Basic UFW configuration ───────────────────── #
def configure_firewall() -> None:
    if not shutil.which("ufw"):
        log_and_print(f"{FAILURE} ufw not installed.", "error")
        return

    if (
        prompt_with_timeout("Reset UFW to defaults? [y/N]: ", persistent=True).lower()
        == "y"
    ):
        execute_command(["sudo", "ufw", "reset"], check=False)

    execute_command(["sudo", "ufw", "default", "deny", "incoming"], check=False)
    execute_command(["sudo", "ufw", "default", "allow", "outgoing"], check=False)

    if prompt_with_timeout("Allow SSH? [Y/n]: ", persistent=True).lower() != "n":
        execute_command(["sudo", "ufw", "allow", "ssh"], check=False)

    execute_command(["sudo", "ufw", "--force", "enable"], check=False)
    execute_command(["sudo", "ufw", "status", "verbose"], check=False)


# ────────────────────── journalctl log monitoring ──────────────────── #
def monitor_system_logs(
    priority: int = DEFAULT_LOG_PRIORITY, services: list[str] | None = None
) -> None:
    cmd = ["journalctl", f"-p{priority}", "-xb"]
    out = subprocess.check_output(cmd).decode()
    if services:
        out = "\n".join(
            ln for ln in out.splitlines() if any(svc in ln for svc in services)
        )
    if out.strip():
        print(out)
        logging.info(out)
    else:
        log_and_print(f"{SUCCESS} No log entries ≥priority {priority}.", "info")


# ────────────── Lightweight system-information report ─────────────── #
def generate_system_report(
    output_format: str = "json", output_file: str | None = None
) -> None:
    report = {
        "uname": subprocess.check_output(["uname", "-a"]).decode().strip(),
        "meminfo": Path("/proc/meminfo").read_text(),
        "cpuinfo": Path("/proc/cpuinfo").read_text(),
    }
    try:
        report["lsb_release"] = subprocess.check_output(["lsb_release", "-a"]).decode()
    except Exception:
        report["lsb_release"] = "N/A"

    outfile = output_file or os.path.join(DEFAULT_LOG_DIR, "system_report.json")
    Path(outfile).write_text(json.dumps(report, indent=2))
    log_and_print(f"{SUCCESS} System report → {outfile}", "info")


# ───────────────────── Batch runner for non-interactive ────────────── #
NON_INTERACTIVE_TASKS = [
    process_dep_scan_log,
    remove_broken_symlinks,
    clean_old_kernels,
    vacuum_journalctl,
    clear_cache,
    update_font_cache,
    clear_trash,
    optimize_databases,
    clean_package_cache,
    clean_aur_dir,
    handle_pacnew_pacsave,
    verify_installed_packages,
    check_failed_cron_jobs,
    clear_docker_images,
    clear_temp_folder,
    check_rmshit_script,
    remove_old_ssh_known_hosts,
    remove_orphan_vim_undo_files,
    force_log_rotation,
    configure_zram,
    check_zram_configuration,
    adjust_swappiness,
    clear_system_cache,
    disable_unused_services,
    check_and_restart_systemd_units,
    security_audit,
    monitor_system_logs,
    generate_system_report,
]


def run_all_tasks() -> None:
    for func in NON_INTERACTIVE_TASKS:
        try:
            func()
        except Exception as exc:  # pragma: no cover
            log_and_print(f"{FAILURE} {func.__name__} crashed: {exc}", "error")


# ──────────────────────── Interactive TUI menu ─────────────────────── #

# Each entry: (key  , function reference           , text shown in menu)
MENU: list[tuple[str, Callable[[], None], str]] = [
    ("1", process_dep_scan_log, "Process dependency log"),
    ("2", manage_cron_job, "Manage cron jobs"),
    ("3", remove_broken_symlinks, "Remove broken symlinks"),
    ("4", clean_old_kernels, "Clean orphan kernels"),
    ("5", vacuum_journalctl, "Vacuum journalctl"),
    ("6", clear_cache, "Clear cache"),
    ("7", update_font_cache, "Update font cache"),
    ("8", clear_trash, "Clear trash"),
    ("9", optimize_databases, "Optimise databases"),
    ("10", clean_package_cache, "Clean package cache"),
    ("11", clean_aur_dir, "Clean AUR directory"),
    ("12", handle_pacnew_pacsave, "Handle pacnew/pacsave"),
    ("13", verify_installed_packages, "Verify installed packages"),
    ("14", check_failed_cron_jobs, "Check failed cron jobs"),
    ("15", clear_docker_images, "Clear Docker images"),
    ("16", clear_temp_folder, "Clear /tmp files"),
    ("17", check_rmshit_script, "Clean custom paths"),
    ("18", remove_old_ssh_known_hosts, "Prune SSH known_hosts"),
    ("19", remove_orphan_vim_undo_files, "Remove orphan Vim undo files"),
    ("20", force_log_rotation, "Force log rotation"),
    ("21", configure_zram, "Configure zram"),
    ("22", check_zram_configuration, "Check zram status"),
    ("23", adjust_swappiness, "Adjust swappiness"),
    ("24", clear_system_cache, "Drop FS caches"),
    ("25", disable_unused_services, "Disable unused services"),
    ("26", check_and_restart_systemd_units, "Restart failed units"),
    ("27", security_audit, "Security audit"),
    ("28", manage_users_and_groups, "User / group mgmt"),
    ("29", configure_firewall, "Configure firewall"),
    ("30", monitor_system_logs, "Monitor system logs"),
    ("31", generate_system_report, "Generate system report"),
    ("0", run_all_tasks, "Run all non-interactive tasks"),
]


def _print_menu() -> None:
    """Nicely formatted two-column menu."""
    cols = shutil.get_terminal_size().columns
    print(f"{GREEN}{BOLD}// Vacuum //{NC}\n")
    for i in range(0, len(MENU), 2):
        left_key, _, left_txt = MENU[i]
        line = f"{GREEN}{left_key:>2}{NC}) {left_txt:33}"
        if i + 1 < len(MENU):
            right_key, _, right_txt = MENU[i + 1]
            line += f"{GREEN}{right_key:>2}{NC}) {right_txt}"
        print(line[:cols])


def main_menu() -> None:
    """Top-level interactive loop."""
    while True:
        os.system("clear")
        _print_menu()
        choice = (
            prompt_with_timeout("Choice (Q=quit): ", timeout=30, default="Q")
            .strip()
            .upper()
        )

        if choice == "Q":
            break
        matched = False
        for key, fn, _ in MENU:
            if key == choice:
                matched = True
                try:
                    fn()
                except Exception as exc:  # pragma: no cover
                    log_and_print(f"{FAILURE} {fn.__name__} crashed: {exc}", "error")
                break
        if not matched:
            log_and_print(f"{FAILURE} Invalid option.", "error")

        if is_interactive():
            input("Press <Enter> to continue…")


# ─────────────────────────── Program entry ─────────────────────────── #
if __name__ == "__main__":
    # Root escalation *before* any further logic
    if os.geteuid() != 0:
        os.execvp("sudo", ["sudo", sys.executable, *sys.argv])

    # Logging was initialised on import via _setup_logging()
    main_menu()
