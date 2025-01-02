#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
A Python script to find duplicate files using jdupes, optionally move them to a
defined "duplicates" directory, and provide detailed logs for each step.

Requirements:
    - jdupes installed on the system (https://github.com/jbruchon/jdupes)
"""

import os
import sys
import logging
import subprocess
import datetime
from pathlib import Path

# -------------------------------------------------------------------
# Configure Logging
# -------------------------------------------------------------------
LOG_FORMAT = (
    "%(asctime)s - %(levelname)s - %(message)s"
)
logging.basicConfig(
    format=LOG_FORMAT,
    level=logging.INFO,
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)

# -------------------------------------------------------------------
# Utility Functions
# -------------------------------------------------------------------
def run_command(cmd):
    """
    Execute a system command and return its (returncode, stdout, stderr).
    Logs both stdout and stderr streams and returns them along with the code.
    """
    logger.info("Running command: %s", " ".join(cmd))

    try:
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=False,
        )
        logger.info("Command returned code %s", result.returncode)
        if result.stderr:
            logger.warning("Command stderr: %s", result.stderr.strip())
        return result.returncode, result.stdout, result.stderr
    except Exception as e:
        logger.error("Failed to run command %s: %s", " ".join(cmd), str(e))
        return 1, "", str(e)


def ensure_jdupes_installed():
    """
    Check if jdupes is installed by calling 'jdupes --version'.
    If not installed or if there's an error, logs and exits the script.
    """
    retcode, _, _ = run_command(["jdupes", "--version"])
    if retcode == 0:
        logger.info("jdupes is installed.")
    else:
        logger.error("jdupes is not installed or not found in PATH. Exiting.")
        sys.exit(1)


# -------------------------------------------------------------------
# Main Duplicate-Finder and Mover
# -------------------------------------------------------------------
def find_and_move_duplicates(
    target_dir,
    move=False,
    duplicates_dir="duplicates",
    recurse=False,
    sort_mode="name",
    quick=False,
):
    """
    Main function that:
      1) Finds duplicate files using jdupes
      2) Optionally moves duplicates to a specified duplicates directory
      3) Logs the process thoroughly

    Args:
        target_dir (str): Path to the directory to scan for duplicates
        move (bool): Whether to move the duplicates or only list them
        duplicates_dir (str): Subdirectory name or absolute path for duplicates
        recurse (bool): If True, will use jdupes in recursive mode (-r)
        sort_mode (str): Sorting option for jdupes (e.g. 'name', 'size'...). 
        quick (bool): If True, adds quick option (-Q) to jdupes for hashing.

    Returns:
        List of duplicate file paths
    """
    # Validate target directory
    target_dir_path = Path(target_dir).expanduser().resolve()
    if not target_dir_path.is_dir():
        logger.error("Invalid target directory: %s", target_dir)
        return []

    # Prepare jdupes command
    cmd = ["jdupes"]
    # If user wants recursion:
    if recurse:
        cmd.append("-r")

    # If user wants quick hashing:
    if quick:
        cmd.append("-Q")

    # -A: Print all sets without prompting to delete
    # -o: Specify ordering. Default: name
    cmd += ["-A", "-o", sort_mode, str(target_dir_path)]

    # Run jdupes
    ret, stdout, stderr = run_command(cmd)
    if ret != 0:
        logger.error(
            "Error finding duplicates in %s: %s", str(target_dir_path), stderr.strip()
        )
        return []

    # Parse duplicates from jdupes output
    duplicates = []
    lines = stdout.strip().splitlines()
    # jdupes separates sets with blank lines, listing each file in a set
    # We combine them into a single list of paths:
    for line in lines:
        if line.strip():
            duplicates.append(line.strip())

    if not duplicates:
        logger.info("No duplicates found in %s", target_dir_path)
        return []

    logger.info("Found duplicates in %s: %s", target_dir, duplicates)

    # Move duplicates if requested
    if move:
        # If duplicates_dir is relative, place inside the target_dir
        dup_target = Path(duplicates_dir).expanduser().resolve()
        if not dup_target.is_absolute():
            # Create duplicates dir inside home or another location as needed
            dup_target = target_dir_path.joinpath(duplicates_dir).resolve()

        # If the duplicates directory does not exist, create it
        if not dup_target.exists():
            logger.info("Creating duplicates directory: %s", str(dup_target))
            try:
                dup_target.mkdir(parents=True, exist_ok=True)
            except Exception as e:
                logger.error("Failed to create duplicates directory: %s", str(e))
                return duplicates

        moved_count = 0
        for fpath in duplicates:
            src = Path(fpath).expanduser().resolve()
            if not src.is_file():
                continue
            # Construct the destination path
            dest = dup_target.joinpath(src.name)
            # If a conflict might exist, incorporate a datetime-named folder:
            if dest.exists():
                # If an item with that name already exists, 
                # create a new time-based subdirectory to avoid collisions
                subdir_name = datetime.datetime.now().strftime(
                    "duplicates_%Y%m%d_%H%M%S"
                )
                final_dup_dir = Path.home().joinpath(subdir_name)
                if not final_dup_dir.exists():
                    try:
                        final_dup_dir.mkdir(parents=True, exist_ok=True)
                    except Exception as e:
                        logger.error("Failed to create subdirectory: %s", str(e))
                        continue

                new_dest = final_dup_dir.joinpath(src.name)
                try:
                    src.replace(new_dest)
                    logger.info("Moved %s -> %s", str(src), str(new_dest))
                    moved_count += 1
                except Exception as e:
                    logger.error("Failed to move %s: %s", str(src), str(e))
            else:
                # Move directly to duplicates_dir
                try:
                    src.replace(dest)
                    logger.info("Moved %s -> %s", str(src), str(dest))
                    moved_count += 1
                except Exception as e:
                    logger.error("Failed to move %s: %s", str(src), str(e))

        logger.info("Finished moving %d duplicate files.", moved_count)
    return duplicates


# -------------------------------------------------------------------
# Main Script Entrypoint
# -------------------------------------------------------------------
def main():
    """
    The main entrypoint. Adjust the parameters as needed for your use case.
    Example usage patterns can be customized here.
    """
    # Ensure jdupes is installed
    ensure_jdupes_installed()

    # Example usage:
    # Provide the target directory as the first argument (if present),
    # or default to the current working directory.
    target_dir = sys.argv[1] if len(sys.argv) > 1 else str(Path.cwd())

    # Example config: move duplicates, place them into "duplicates" subdir, do not recurse
    # Adjust as needed or parse additional CLI arguments for dynamic usage
    found_dups = find_and_move_duplicates(
        target_dir=target_dir,
        move=True,                 # True: actually move duplicates
        duplicates_dir="duplicates", 
        recurse=False,            # set True to recurse subdirs
        sort_mode="name",         # 'name' or 'size'
        quick=False,              # 'False' means no quick hashing
    )

    if found_dups:
        logger.info(
            "Duplicate files have been processed. Total duplicates found: %d",
            len(found_dups),
        )
    else:
        logger.info("No duplicates found or none were processed.")


if __name__ == "__main__":
    main()
