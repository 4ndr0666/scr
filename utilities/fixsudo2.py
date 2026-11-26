#!/usr/bin/env python3
"""
4NDR0666OS - Sudo Lazarus
Version: 2.3.0
Description: Resurrects broken sudo binaries by correcting permissions/ownership.
             Also repairs /dev/null if it has been corrupted or replaced.
Critical Feature: Uses Fallback Escalation (pkexec/su) if sudo is dead.
Enhancements: dry-run mode, re-exec guard, shlex quoting, stderr errors,
              TTY color detection, sudoers.d support, distro path probing,
              /dev/null character-device integrity check and recreation.
"""

import os
import sys
import subprocess
import shutil
import shlex
import stat
import argparse

# ─── CONFIG ───────────────────────────────────────────────────────────────────

TARGET_CANDIDATES = [
    # sudo binary (setuid root)
    [{"path": "/usr/bin/sudo",          "mode": 0o4755, "uid": 0, "gid": 0}],

    # sudo shared library – probe Arch / Debian / RHEL locations
    [
        {"path": "/usr/lib/sudo/sudoers.so",      "mode": 0o644, "uid": 0, "gid": 0},
        {"path": "/usr/lib64/sudo/sudoers.so",     "mode": 0o644, "uid": 0, "gid": 0},
        {"path": "/usr/libexec/sudo/sudoers.so",   "mode": 0o644, "uid": 0, "gid": 0},
    ],

    # sudoers config
    [{"path": "/etc/sudoers",           "mode": 0o440, "uid": 0, "gid": 0}],

    # sudoers drop-in directory
    [{"path": "/etc/sudoers.d",         "mode": 0o750, "uid": 0, "gid": 0}],

    # sudo runtime state directory
    [{"path": "/var/lib/sudo",          "mode": 0o711, "uid": 0, "gid": 0}],

    # sudo timestamp directory
    [
        {"path": "/run/sudo",           "mode": 0o711, "uid": 0, "gid": 0},
        {"path": "/var/run/sudo",       "mode": 0o711, "uid": 0, "gid": 0},
    ],
]

# /dev/null is handled separately — it is a character device, not a plain file.
DEV_NULL_TARGET = {
    "path":  "/dev/null",
    "mode":  0o666,          # permissions only (no setuid/setgid)
    "uid":   0,
    "gid":   0,
    "major": 1,              # char device: mem(1), minor 3 = null
    "minor": 3,
}

# ─── RE-EXEC GUARD ────────────────────────────────────────────────────────────
_REEXEC_ENV_KEY = "_LAZARUS_REEXEC"

# ─── COLORS ───────────────────────────────────────────────────────────────────
def _supports_color() -> bool:
    return hasattr(sys.stdout, "isatty") and sys.stdout.isatty()

COLORS = {
    "RED":    "\033[91m",
    "GREEN":  "\033[92m",
    "YELLOW": "\033[93m",
    "RESET":  "\033[0m",
} if _supports_color() else {k: "" for k in ("RED", "GREEN", "YELLOW", "RESET")}


# ─── LOGGING ──────────────────────────────────────────────────────────────────
def log(msg: str, color: str = "GREEN", *, err: bool = False) -> None:
    """Print a prefixed, optionally coloured message.

    Args:
        msg:   Human-readable message.
        color: Key into COLORS dict.
        err:   If True, write to stderr (used for warnings/errors).
    """
    line = f"{COLORS.get(color, '')}[*] {msg}{COLORS['RESET']}"
    print(line, file=sys.stderr if err else sys.stdout)


# ─── PRIVILEGE HELPERS ────────────────────────────────────────────────────────
def is_root() -> bool:
    return os.geteuid() == 0


def escalate() -> None:
    """Fallback privilege escalation chain.

    Attempts pkexec then su.  A re-exec guard in the environment prevents
    infinite escalation loops (e.g. if pkexec drops back to the same user).
    Never returns on success; exits non-zero on total failure.
    """
    if os.environ.get(_REEXEC_ENV_KEY):
        log("Re-exec guard triggered: escalation already attempted once.", "RED", err=True)
        log("FATAL: Still not root after escalation. Aborting.", "RED", err=True)
        sys.exit(1)

    env       = os.environ.copy()
    env[_REEXEC_ENV_KEY] = "1"
    argv      = [sys.executable] + sys.argv

    # 1. PolicyKit / pkexec ─────────────────────────────────────────────────
    if shutil.which("pkexec"):
        log("Attempting escalation via PolicyKit (pkexec)...", "YELLOW")
        try:
            result = subprocess.run(["pkexec"] + argv, env=env)
            sys.exit(result.returncode)
        except FileNotFoundError:
            pass
        except Exception as exc:
            log(f"pkexec raised: {exc}", "RED", err=True)

    # 2. su ─────────────────────────────────────────────────────────────────
    if shutil.which("su"):
        log("Attempting escalation via su (requires root password)...", "YELLOW")
        quoted_cmd = " ".join(shlex.quote(a) for a in argv)
        try:
            result = subprocess.run(["su", "-c", quoted_cmd], env=env)
            sys.exit(result.returncode)
        except FileNotFoundError:
            pass
        except Exception as exc:
            log(f"su raised: {exc}", "RED", err=True)

    log(
        "FATAL: All escalation vectors failed. "
        "Boot to single-user/rescue mode and run manually as root.",
        "RED", err=True,
    )
    sys.exit(1)


# ─── GENERIC FILE/DIR REPAIR ──────────────────────────────────────────────────
def resolve_target(candidates: list[dict]) -> dict | None:
    """Return the first candidate whose path exists on this system."""
    for candidate in candidates:
        if os.path.lexists(candidate["path"]):
            return candidate
    return None


def format_mode(mode: int) -> str:
    return f"{mode:04o}"


def backup_metadata(path: str) -> dict:
    info = os.lstat(path)
    return {
        "path": path,
        "uid":  info.st_uid,
        "gid":  info.st_gid,
        "mode": info.st_mode & 0o7777,
    }


def check_target(target: dict) -> tuple[bool, str]:
    """Return (needs_repair, human-readable reason) for a plain file/dir."""
    info         = os.lstat(target["path"])
    current_mode = info.st_mode & 0o7777
    issues       = []
    if current_mode  != target["mode"]: issues.append(f"mode {format_mode(current_mode)} → {format_mode(target['mode'])}")
    if info.st_uid   != target["uid"]:  issues.append(f"uid {info.st_uid} → {target['uid']}")
    if info.st_gid   != target["gid"]:  issues.append(f"gid {info.st_gid} → {target['gid']}")
    return bool(issues), ", ".join(issues)


def repair_target(target: dict, *, dry_run: bool = False) -> bool:
    """Inspect and optionally repair a single plain-file/directory target."""
    path = target["path"]

    if not os.path.lexists(path):
        log(f"Not found, skipping: {path}", "YELLOW")
        return True

    try:
        needs_repair, reason = check_target(target)
    except OSError as exc:
        log(f"Cannot stat {path}: {exc}", "RED", err=True)
        return False

    if not needs_repair:
        log(f"OK: {path}")
        return True

    snapshot = backup_metadata(path)
    log(
        f"{'[DRY-RUN] Would repair' if dry_run else 'Repairing'}: "
        f"{path}  ({reason})",
        "YELLOW",
    )

    if dry_run:
        return True

    try:
        os.lchown(path, target["uid"], target["gid"])

        if not stat.S_ISLNK(os.lstat(path).st_mode):
            os.chmod(path, target["mode"])
        else:
            log(f"  Symlink detected, skipping chmod: {path}", "YELLOW")

        log(
            f"Fixed: {path}  "
            f"(was: uid={snapshot['uid']} gid={snapshot['gid']} "
            f"mode={format_mode(snapshot['mode'])})",
            "GREEN",
        )
        return True

    except PermissionError as exc:
        log(f"Permission denied on {path}: {exc}", "RED", err=True)
    except OSError as exc:
        log(f"OS error on {path}: {exc}", "RED", err=True)

    return False


# ─── /dev/null REPAIR ─────────────────────────────────────────────────────────
def repair_dev_null(target: dict = DEV_NULL_TARGET, *, dry_run: bool = False) -> bool:
    """/dev/null-specific repair.

    /dev/null must be a character device (major=1, minor=3) with mode 0o666,
    owned by root:root.  Three distinct failure modes are handled:

      1. Missing entirely            → recreate with os.mknod()
      2. Wrong file type             → remove impostor, recreate device node
         (e.g. replaced by a regular file — a common 'permission denied on
         /dev/null' symptom that confuses many sysadmins)
      3. Correct device type but bad → fix ownership / permissions only
         uid / gid / mode

    Args:
        target:  Dict with keys: path, mode, uid, gid, major, minor.
        dry_run: If True, report issues but make no changes.

    Returns:
        True if clean or successfully repaired; False on error.
    """
    path = target["path"]

    # ── Case 1: completely missing ──────────────────────────────────────────
    if not os.path.lexists(path):
        log(f"/dev/null is MISSING – this will break almost everything.", "RED", err=True)
        if dry_run:
            log(f"[DRY-RUN] Would recreate character device: {path}", "YELLOW")
            return True
        return _create_dev_null(target)

    # ── Inspect what's there ────────────────────────────────────────────────
    try:
        info = os.lstat(path)
    except OSError as exc:
        log(f"Cannot stat {path}: {exc}", "RED", err=True)
        return False

    is_char_dev   = stat.S_ISCHR(info.st_mode)
    current_major = os.major(info.st_rdev) if is_char_dev else None
    current_minor = os.minor(info.st_rdev) if is_char_dev else None
    current_mode  = info.st_mode & 0o7777

    # ── Case 2: wrong file type (impostor) ──────────────────────────────────
    if not is_char_dev or current_major != target["major"] or current_minor != target["minor"]:
        type_label = _node_type_label(info.st_mode)
        log(
            f"/dev/null is CORRUPTED: found {type_label} "
            f"(expected char device {target['major']}:{target['minor']}). "
            f"This is the classic 'permission denied on /dev/null' root cause.",
            "RED", err=True,
        )
        if dry_run:
            log(f"[DRY-RUN] Would remove impostor and recreate character device: {path}", "YELLOW")
            return True
        log(f"Removing impostor node: {path}", "YELLOW")
        try:
            os.unlink(path)
        except OSError as exc:
            log(f"Failed to remove impostor {path}: {exc}", "RED", err=True)
            return False
        return _create_dev_null(target)

    # ── Case 3: correct device node, wrong meta ──────────────────────────────
    issues = []
    if current_mode    != target["mode"]: issues.append(f"mode {format_mode(current_mode)} → {format_mode(target['mode'])}")
    if info.st_uid     != target["uid"]:  issues.append(f"uid {info.st_uid} → {target['uid']}")
    if info.st_gid     != target["gid"]:  issues.append(f"gid {info.st_gid} → {target['gid']}")

    if not issues:
        log(f"OK: {path}  (char {target['major']}:{target['minor']}, mode={format_mode(current_mode)})")
        return True

    reason = ", ".join(issues)
    log(
        f"{'[DRY-RUN] Would repair' if dry_run else 'Repairing'}: "
        f"{path}  ({reason})",
        "YELLOW",
    )
    if dry_run:
        return True

    try:
        os.lchown(path, target["uid"], target["gid"])
        os.chmod(path, target["mode"])
        log(f"Fixed: {path}  ({reason})", "GREEN")
        return True
    except OSError as exc:
        log(f"OS error fixing {path}: {exc}", "RED", err=True)
        return False


def _create_dev_null(target: dict) -> bool:
    """Create /dev/null as a character device node. Requires root."""
    path      = target["path"]
    dev_t     = os.makedev(target["major"], target["minor"])
    node_mode = stat.S_IFCHR | target["mode"]   # S_IFCHR tells mknod: char device
    try:
        os.mknod(path, node_mode, dev_t)
        os.chown(path, target["uid"], target["gid"])
        log(
            f"Recreated: {path}  "
            f"(char {target['major']}:{target['minor']}, "
            f"mode={format_mode(target['mode'])})",
            "GREEN",
        )
        return True
    except OSError as exc:
        log(f"Failed to create {path}: {exc}", "RED", err=True)
        return False


def _node_type_label(st_mode: int) -> str:
    """Human-readable file-type string from st_mode."""
    checks = [
        (stat.S_ISREG,  "regular file"),
        (stat.S_ISDIR,  "directory"),
        (stat.S_ISLNK,  "symlink"),
        (stat.S_ISBLK,  "block device"),
        (stat.S_ISFIFO, "FIFO/pipe"),
        (stat.S_ISSOCK, "socket"),
    ]
    for fn, label in checks:
        if fn(st_mode):
            return label
    return "unknown file type"


# ─── CLI ──────────────────────────────────────────────────────────────────────
def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Sudo Lazarus – resurrect broken sudo + /dev/null.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "After a successful run verify with:\n"
            "  sudo -v          # confirms sudo works\n"
            "  echo x > /dev/null && echo ok   # confirms /dev/null works"
        ),
    )
    p.add_argument(
        "-n", "--dry-run",
        action="store_true",
        help="Report issues without making any changes.",
    )
    p.add_argument(
        "--no-escalate",
        action="store_true",
        help="Exit instead of attempting privilege escalation.",
    )
    p.add_argument(
        "--skip-dev-null",
        action="store_true",
        help="Skip /dev/null integrity check.",
    )
    return p


# ─── MAIN ─────────────────────────────────────────────────────────────────────
def main() -> None:
    args = build_parser().parse_args()

    if not is_root():
        log("Not running as root. sudo is likely broken.", "RED", err=True)
        if args.no_escalate:
            log("--no-escalate set; aborting.", "RED", err=True)
            sys.exit(1)
        escalate()
        return

    mode_label = " [DRY-RUN]" if args.dry_run else ""
    log(f"Initiating Sudo Resurrection Protocol{mode_label}...", "GREEN")

    failed = 0

    # ── /dev/null (repair first — many tools implicitly need it) ────────────
    if not args.skip_dev_null:
        log("--- /dev/null integrity check ---", "GREEN")
        if not repair_dev_null(dry_run=args.dry_run):
            failed += 1

    # ── sudo + sudoers targets ───────────────────────────────────────────────
    log("--- sudo/sudoers repair ---", "GREEN")
    for candidates in TARGET_CANDIDATES:
        target = resolve_target(candidates)
        if target is None:
            paths = ", ".join(c["path"] for c in candidates)
            log(f"No candidate found for group [{paths}], skipping.", "YELLOW")
            continue
        if not repair_target(target, dry_run=args.dry_run):
            failed += 1

    # ── Summary ─────────────────────────────────────────────────────────────
    if failed:
        log(f"Protocol finished with {failed} error(s). Review output above.", "RED", err=True)
        sys.exit(1)

    log(
        f"Protocol complete{mode_label}. "
        + (
            "No changes made."
            if args.dry_run
            else "Verify with:  sudo -v  &&  echo x > /dev/null && echo ok"
        ),
        "GREEN",
    )


if __name__ == "__main__":
    main()
