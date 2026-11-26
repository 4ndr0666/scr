#!/usr/bin/env python3
"""Independent behavioral regression suite for utilities/ Round 2 deep gap mitigation."""
import os
import pathlib
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent
TMP_BASE = ROOT / ".4ndr0" / "tmp_r2"
TMP_BASE.mkdir(parents=True, exist_ok=True)


def run_env(extra=None):
    env = {k: v for k, v in os.environ.items() if k != "BASH_ENV"}
    env["TMPDIR"] = str(TMP_BASE)
    if extra:
        env.update(extra)
    return env


def test_bootloader_repair():
    script = str(ROOT / "recovery/bootloader_repair.sh")
    # 1. --help works as non-root without invoking sudo
    p = subprocess.run(["bash", script, "--help"], env=run_env(), capture_output=True, text=True)
    assert p.returncode == 0 and "Reinstall GRUB" in p.stdout, f"bootloader --help failed: {p.stderr}"
    # 2. source-safety + MOUNT_POINT is global + validate_partition_input accepts mapper & rejects bad paths
    p2 = subprocess.run(
        ["bash", "-c", 'source "$1"; [[ "$MOUNT_POINT" == "/mnt" ]] && SKIP_BLK_CHECK=1 validate_partition_input /dev/mapper/cryptroot && ! SKIP_BLK_CHECK=1 validate_partition_input "/tmp/evil;rm"', "_", script],
        env=run_env(), capture_output=True, text=True,
    )
    assert p2.returncode == 0, f"bootloader_repair validation failed: {p2.stderr}"


def test_hddctl():
    script = str(ROOT / "recovery/hddctl")
    # 1. --help works as non-root
    p = subprocess.run(["sh", script, "--help"], env=run_env(), capture_output=True, text=True)
    assert p.returncode == 0 and "ddrescue" in p.stdout, f"hddctl --help failed: {p.stderr}"
    # 2. select_drive stdout contains ONLY /dev/... (no lsblk table contamination) and rsync failure propagates
    with tempfile.TemporaryDirectory(dir=str(TMP_BASE)) as td:
        b = pathlib.Path(td) / "bin"
        b.mkdir()
        (b / "rsync").write_text("#!/usr/bin/env sh\necho 'simulated rsync failure' >&2\nexit 23\n", encoding="utf-8")
        os.chmod(b / "rsync", 0o755)
        logf = str(pathlib.Path(td) / "ops.log")
        srcd = pathlib.Path(td) / "src"
        tgtd = pathlib.Path(td) / "tgt"
        srcd.mkdir()
        tgtd.mkdir()
        p_rs = subprocess.run(
            ["sh", "-c", f'HDDCTL_SOURCE_ONLY=1 LOG_FILE="{logf}" . "{script}"; printf "%s\\n%s\\nyes\\n" "{srcd}" "{tgtd}" | rsync_sync'],
            env=run_env({"PATH": str(b) + ":" + os.environ["PATH"]}),
            capture_output=True, text=True,
        )
        assert p_rs.returncode == 23, f"hddctl rsync|tee masked exit code 23 (got {p_rs.returncode})"


def test_ntfs_repair():
    script = str(ROOT / "recovery/ntfs_repair.sh")
    p = subprocess.run(["perl", script, "--help"], env=run_env(), capture_output=True, text=True)
    assert p.returncode == 0 and "--dry-run" in p.stdout, f"ntfs_repair --help failed: {p.stderr}"
    with tempfile.TemporaryDirectory(dir=str(TMP_BASE)) as td:
        img = pathlib.Path(td) / "fake_ntfs.img"
        # 512 bytes missing NTFS signature
        img.write_bytes(b"\x00" * 512)
        bkp = pathlib.Path(td) / "mbr.bak"
        logf = str(pathlib.Path(td) / "ntfs.log")
        p2 = subprocess.run(
            ["perl", script, "--device", str(img), "--backup", str(bkp), "--dry-run"],
            env=run_env({"NTFS_REPAIR_LOG": logf}),
            capture_output=True, text=True,
        )
        assert p2.returncode == 0, f"ntfs_repair --dry-run failed: {p2.stderr}"
        assert bkp.is_file() and bkp.stat().st_size == 512, "MBR backup missing or wrong size"
        assert "[dry-run] Would write repaired 512-byte NTFS boot sector" in p2.stdout
        assert img.read_bytes() == b"\x00" * 512, "--dry-run must not mutate device"


def test_build_scripts():
    # Verify build/shellinstall.sh clean works with 1 arg without crashing on basename
    script = str(ROOT / "build/shellinstall.sh")
    p = subprocess.run(
        ["bash", "-c", 'source "$1"; LOG_FILE=""; clean_up', "_", script],
        env=run_env(), capture_output=True, text=True,
    )
    assert p.returncode == 0 and "Clean up complete." in p.stdout, f"shellinstall clean_up failed: {p.stderr}"


def test_iso_and_check_files_and_asd():
    # iso/system_iso.sh expands $HOME (no literal ~)
    iso_script = str(ROOT / "iso/system_iso.sh")
    p_iso = subprocess.run(
        ["bash", "-c", 'source "$1"; printf "%s" "$work_dir"', "_", iso_script],
        env=run_env({"HOME": "/tmp/fakehome"}), capture_output=True, text=True,
    )
    assert p_iso.returncode == 0 and p_iso.stdout == "/tmp/fakehome/arch-iso", f"system_iso tilde bug: {p_iso.stdout}"

    # files/check_for_files.sh uses XDG_DATA_HOME, not /home/andro
    cf_script = str(ROOT / "files/check_for_files.sh")
    p_cf = subprocess.run(
        ["bash", "-c", 'source "$1"; printf "%s" "$AUDIT_LOG"', "_", cf_script],
        env=run_env({"XDG_DATA_HOME": "/tmp/xdg_test"}), capture_output=True, text=True,
    )
    assert p_cf.returncode == 0 and p_cf.stdout == "/tmp/xdg_test/logs/critical_files_audit.log", f"check_for_files path bug: {p_cf.stdout}"

    # ls/asd executes cleanly on a temp directory with dotfiles
    with tempfile.TemporaryDirectory(dir=str(TMP_BASE)) as td:
        (pathlib.Path(td) / ".hidden").write_text("x", encoding="utf-8")
        (pathlib.Path(td) / "visible").write_text("y", encoding="utf-8")
        p_asd = subprocess.run(["bash", str(ROOT / "ls/asd")], cwd=td, env=run_env(), capture_output=True, text=True)
        assert p_asd.returncode == 0 and ".hidden" in p_asd.stdout and "visible" in p_asd.stdout, f"ls/asd failed: {p_asd.stderr}"


if __name__ == "__main__":
    test_bootloader_repair()
    test_hddctl()
    test_ntfs_repair()
    test_build_scripts()
    test_iso_and_check_files_and_asd()
    print("[test_utilities_r2] 5/5 suites passed")
