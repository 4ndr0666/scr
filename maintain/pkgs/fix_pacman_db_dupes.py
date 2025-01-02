#!/usr/bin/env python3
# File: fix_pacman_db_duplicates.py
# Author: 4ndr0666
# Description:
#   This script attempts to fully automate the detection and resolution of duplicated pacman database entries.
#   It does not require manual intervention. It backs up the pacman database, identifies duplicates, removes
#   extraneous entries, and then re-installs the affected packages to ensure a consistent state.
#
# Requirements:
#   - Must be run as root
#   - Uses python3, coreutils, and pacman
#
# Steps:
#   1. Backup /var/lib/pacman/local to /var/lib/pacman/local.bak.<timestamp>
#   2. Identify duplicated database entries by analyzing directories in /var/lib/pacman/local
#   3. For each duplicated package:
#       a. Determine which entry to keep. Prefer the one matching the currently installed version, if available,
#          otherwise keep the lexicographically highest version directory.
#       b. Remove other directories for that package.
#   4. After cleaning up, attempt to re-install all affected packages in one go to ensure DB consistency.
#
# Notes:
#   - If issues persist even after this script runs, consider restoring from the backup and seeking further troubleshooting.
#
# No placeholders or manual steps required. The script will handle everything automatically.

import os
import sys
import subprocess
import time
import shutil

PACMAN_LOCAL_DB = "/var/lib/pacman/local"

def run_cmd(cmd):
    return subprocess.run(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

def ensure_root():
    if os.geteuid() != 0:
        print("Error: This script must be run as root.")
        sys.exit(1)

def backup_db():
    timestamp = time.strftime("%Y%m%d%H%M%S")
    backup_dir = f"/var/lib/pacman/local.bak.{timestamp}"
    print(f"Backing up local pacman DB to {backup_dir}...")
    shutil.copytree(PACMAN_LOCAL_DB, backup_dir)
    print("Backup complete.")
    return backup_dir

def list_local_dirs():
    return [d for d in os.listdir(PACMAN_LOCAL_DB) if os.path.isdir(os.path.join(PACMAN_LOCAL_DB, d))]

def parse_pkginfo(dirpath):
    # Extract package name and version from PKGINFO file if present
    pkginfo_path = os.path.join(PACMAN_LOCAL_DB, dirpath, "PKGINFO")
    if not os.path.isfile(pkginfo_path):
        return None, None
    name = None
    version = None
    with open(pkginfo_path, "r") as f:
        for line in f:
            line = line.strip()
            if line.startswith("pkgname = "):
                name = line.split("=",1)[1].strip()
            elif line.startswith("pkgver = "):
                version = line.split("=",1)[1].strip()
    return name, version

def get_installed_version(pkg):
    # Query pacman for installed version of pkg
    r = run_cmd(f"pacman -Qi {pkg}")
    if r.returncode != 0:
        return None
    for line in r.stdout.splitlines():
        if line.startswith("Version"):
            return line.split(":",1)[1].strip()
    return None

def main():
    ensure_root()

    if not os.path.isdir(PACMAN_LOCAL_DB):
        print(f"Error: {PACMAN_LOCAL_DB} does not exist or not accessible.")
        sys.exit(1)

    backup_db_path = backup_db()

    # Gather package->[(dir, version)] mapping
    pkg_map = {}
    dirs = list_local_dirs()
    for d in dirs:
        name, ver = parse_pkginfo(d)
        if not name or not ver:
            # If no valid PKGINFO, skip
            continue
        pkg_map.setdefault(name, []).append((d, ver))

    # Identify duplicates
    duplicates = {pkg: entries for pkg, entries in pkg_map.items() if len(entries) > 1}
    if not duplicates:
        print("No duplicated database entries found.")
        # Even if user sees duplicates outside, we rely on PKGINFO parsing. If none found, exit gracefully.
        sys.exit(0)

    print("Duplicated entries found for packages:")
    for p in duplicates:
        print(f"  {p}")

    affected_packages = list(duplicates.keys())

    # Attempt to fix duplicates
    for pkg, entries in duplicates.items():
        # entries: list of (dir, version)
        installed_version = get_installed_version(pkg)
        # If we have installed_version, pick the entry whose version matches it exactly if possible,
        # else pick the lexicographically highest version.
        best_entry = None
        if installed_version:
            # Try exact match
            for (d, v) in entries:
                # installed_version can differ from v slightly (e.g. epoch?), attempt a rough match:
                # If installed_version is substring of v or equal to v, consider a match.
                if installed_version == v or installed_version in v:
                    best_entry = (d, v)
                    break
        if not best_entry:
            # No exact match found, pick lexicographically highest version
            sorted_entries = sorted(entries, key=lambda x: x[1])  # sort by version lexicographically
            best_entry = sorted_entries[-1]

        # Remove all other entries
        for (d, v) in entries:
            if d != best_entry[0]:
                # Remove directory
                full_path = os.path.join(PACMAN_LOCAL_DB, d)
                shutil.rmtree(full_path)

    # Now duplicates should be resolved at directory level.
    # Attempt a single pacman operation to reinstall all affected packages, ensuring DB consistency.
    # We'll run `pacman -S --noconfirm pkg1 pkg2 pkg3 ...`.
    # If this fails, we might try removing all directories for that pkg and re-installing from scratch, but let's try once first.
    print("Reinstalling affected packages to ensure a clean DB:")
    # Remove duplicates from affected_packages (just unique)
    affected_packages = list(set(affected_packages))
    affected_packages_str = " ".join(affected_packages)

    # If any error occurs, we do fallback inside an exception handler
    try:
        # First, let's try a direct reinstall
        r = run_cmd(f"pacman -S --noconfirm {affected_packages_str}")
        if r.returncode != 0:
            print("Re-install attempt failed. Attempting fallback...")

            # Fallback: remove all directories for affected packages and install fresh
            # This is a more drastic measure
            for pkg in affected_packages:
                # Remove any directory that matches the pkg
                # repopulate dirs and parse again just in case
                dirs_now = list_local_dirs()
                for d in dirs_now:
                    n, v = parse_pkginfo(d)
                    if n == pkg:
                        full_path = os.path.join(PACMAN_LOCAL_DB, d)
                        shutil.rmtree(full_path, ignore_errors=True)

            # Now install them fresh
            r2 = run_cmd(f"pacman -S --noconfirm {affected_packages_str}")
            if r2.returncode != 0:
                print("Fallback installation also failed. Consider restoring from the backup and manual intervention.")
                print(f"Backup: {backup_db_path}")
                sys.exit(1)
            else:
                print("Fallback installation succeeded. DB should now be consistent.")
        else:
            print("Re-installation succeeded. DB should now be consistent.")
    except Exception as e:
        print("An error occurred during re-installation attempts:", e)
        print("Consider restoring from the backup and manual intervention.")
        print(f"Backup: {backup_db_path}")
        sys.exit(1)

    # Final check (optional)
    # We won't fail script if still duplicates, but we can warn user
    # Re-run logic to detect duplicates quickly
    dirs_now = list_local_dirs()
    temp_map = {}
    for d in dirs_now:
        n, v = parse_pkginfo(d)
        if n and v:
            temp_map.setdefault(n, []).append((d,v))
    final_duplicates = {p: arr for p, arr in temp_map.items() if len(arr) > 1}
    if final_duplicates:
        print("Warning: duplicates still found after attempted fix:")
        for p in final_duplicates:
            print(f"  {p}")
        print("You may need manual intervention or consider restoring the backup.")
        print(f"Backup: {backup_db_path}")
        sys.exit(1)

    print("All done. No duplicates remain. System should be stable now.")

if __name__ == "__main__":
    main()
