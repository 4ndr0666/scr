#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
A Python script to find duplicate files using jdupes, with a menu-driven interface,
configuration management, and idempotent duplicate handling.

Requirements:
    - jdupes installed on the system (https://github.com/jbruchon/jdupes)
"""

import sys
import logging
import subprocess
import json
from pathlib import Path
import datetime

# -------------------------------------------------------------------
# Global Variables & Configuration
# -------------------------------------------------------------------
APP_NAME = "jdupes_wrapper.py"
APP_VERSION = "1.0"
CONFIG_FILE = "jdupes_config.json"
MOVED_FILES_LOG = "moved_files.log"
LOG_FILE = "jdupes_wrapper.log"

# Default configuration
DEFAULT_CONFIG = {
    "duplicates_dir": "duplicates",
    "scan_directories": [],
}

config = {}
already_moved = set()  # To store duplicates already moved for idempotency

# -------------------------------------------------------------------
# Configure Logging
# -------------------------------------------------------------------
LOG_FORMAT = "% (asctime)s - %(levelname)s - %(message)s"
logging.basicConfig(
    filename=LOG_FILE,
    level=logging.INFO,
    format=LOG_FORMAT,
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)

# Console handler for logging to stdout
console_handler = logging.StreamHandler(sys.stdout)
console_handler.setLevel(logging.INFO)
console_handler.setFormatter(logging.Formatter("% (levelname)s - %(message)s"))
logger.addHandler(console_handler)


# -------------------------------------------------------------------
# Utility Functions
# -------------------------------------------------------------------
def run_command(cmd):
    """
    Execute a system command and return its (returncode, stdout, stderr).
    Logs both stdout and stderr streams and returns them along with the code.
    """
    logger.info(f"Running command: {'. '.join(cmd)}")

    try:
        result = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=False,
        )
        logger.info(f"Command returned code {result.returncode}")
        if result.stderr:
            logger.warning(f"Command stderr: {result.stderr.strip()}")
        return result.returncode, result.stdout, result.stderr
    except Exception as e:
        logger.error(f"Failed to run command {'. '.join(cmd)}: {e}")
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


def load_config():
    """Loads configuration from jdupes_config.json or creates a default one."""
    global config
    if Path(CONFIG_FILE).exists():
        try:
            with open(CONFIG_FILE, "r") as f:
                config = json.load(f)
            logger.info(f"Configuration loaded from {CONFIG_FILE}.")
        except json.JSONDecodeError as e:
            logger.error(
                f"Error decoding JSON from {CONFIG_FILE}: {e}. Using default config."
            )
            config = DEFAULT_CONFIG
    else:
        config = DEFAULT_CONFIG
        logger.info(
            f"Config file not found. Creating default config at {CONFIG_FILE}..."
        )
        save_config()

    # Ensure duplicates directory exists
    dup_dir = Path(config["duplicates_dir"]).expanduser().resolve()
    if not dup_dir.exists():
        try:
            dup_dir.mkdir(parents=True, exist_ok=True)
            logger.info(f"Created duplicates directory: {dup_dir}")
        except Exception as e:
            logger.error(f"Failed to create duplicates directory {dup_dir}: {e}")
            sys.exit(1)


def save_config():
    """Saves current configuration to jdupes_config.json."""
    try:
        with open(CONFIG_FILE, "w") as f:
            json.dump(config, f, indent=4)
        logger.info(f"Configuration saved to {CONFIG_FILE}.")
    except Exception as e:
        logger.error(f"Failed to save configuration to {CONFIG_FILE}: {e}")


def load_moved_files_log():
    """Loads previously moved files for idempotency."""
    global already_moved
    if Path(MOVED_FILES_LOG).exists():
        try:
            with open(MOVED_FILES_LOG, "r") as f:
                for line in f:
                    already_moved.add(line.strip())
            logger.info(f"Loaded moved files information from {MOVED_FILES_LOG}.")
        except Exception as e:
            logger.error(f"Failed to load moved files log {MOVED_FILES_LOG}: {e}")
    else:
        logger.info(
            f"{MOVED_FILES_LOG} not found. It will be created after moving duplicates."
        )


def save_moved_files_log():
    """Saves newly moved files to the log."""
    try:
        with open(MOVED_FILES_LOG, "w") as f:
            for file_path in already_moved:
                f.write(f"{file_path}\n")
        logger.info(f"Updated {MOVED_FILES_LOG} with newly moved files.")
    except Exception as e:
        logger.error(f"Failed to save moved files log {MOVED_FILES_LOG}: {e}")


# -------------------------------------------------------------------
# Menu-Driven Interface Functions
# -------------------------------------------------------------------
def main_menu():
    """Displays the main menu and gets user choice."""
    print("\n====================================")
    print(f"       {APP_NAME} - Version: {APP_VERSION}")
    print("====================================")
    print("1) Configure Directories to Scan")
    print("2) Configure Duplicates Folder")
    print("3) Run Duplicate Scan & Process")
    print("4) Help & Learning")
    print("5) Exit")
    print("====================================")
    choice = input("Select an option: ").strip()
    return choice


def configure_scan_directories():
    """Allows user to add/remove directories to scan."""
    print("\nCurrent directories in config:")
    if not config["scan_directories"]:
        print("  None configured.")
    else:
        for i, dir_path in enumerate(config["scan_directories"]):
            print(f"  {i+1}. {dir_path}")

    print("\nEnter new directories to add (space-separated).")
    print("Example: /path/to/dir1 /path/to/dir2")
    print("Leave blank to keep current or enter 'clear' to remove all.")
    input_str = input("Directories > ").strip()

    if input_str.lower() == "clear":
        config["scan_directories"] = []
        print("All scan directories cleared.")
    elif input_str:
        new_dirs = [Path(d).expanduser().resolve() for d in input_str.split()]
        for new_dir in new_dirs:
            if new_dir.is_dir():
                if str(new_dir) not in config["scan_directories"]:
                    config["scan_directories"].append(str(new_dir))
                    logger.info(f"Added directory: {new_dir}")
                else:
                    print(f"Directory already exists: {new_dir}")
            else:
                print(f"Warning: Directory not found or invalid: {new_dir}")
                logger.warning(f"Attempted to add invalid directory: {new_dir}")
    save_config()
    print("Scan directories updated.")


def configure_duplicates_folder():
    """Allows user to set the destination folder for duplicates."""
    print(f"\nCurrent destination folder for duplicates: {config['duplicates_dir']}")
    new_dest = input(
        "Enter new duplicates folder (or press Enter to keep current): "
    ).strip()
    if new_dest:
        new_dest_path = Path(new_dest).expanduser().resolve()
        if not new_dest_path.exists():
            try:
                new_dest_path.mkdir(parents=True, exist_ok=True)
                logger.info(f"Created duplicates directory: {new_dest_path}")
            except Exception as e:
                logger.error(f"Failed to create directory {new_dest_path}: {e}")
                print(
                    f"ERROR: Could not create directory '{new_dest_path}'. Check logs."
                )
                return
        config["duplicates_dir"] = str(new_dest_path)
        save_config()
        print(f"Destination folder updated to: {config['duplicates_dir']}")
    else:
        print(f"No changes made. Destination remains: {config['duplicates_dir']}")


def show_educational_info():
    """Displays help and educational information about jdupes."""
    print("\n==================== HELP & LEARNING ====================")
    print("This script automates the process of scanning directories for duplicate ")
    print("files using the 'jdupes' tool, then safely moves duplicates into a ")
    print("designated folder to help organize or remove them.\n")
    print("Below are some pointers if you want to manage or run jdupes manually:")
    print("---------------------------------------------------------")
    print("1) Installing jdupes (Arch Linux):")
    print("   sudo pacman -S jdupes")
    print("")
    print("2) Basic jdupes usage:")
    print("   jdupes /path/to/dir1 /path/to/dir2")
    print("   - This scans the specified directories for duplicates and displays them.")
    print("")
    print("3) Additional jdupes arguments:")
    print("   - -r : recursive scan of subdirectories")
    print("   - -L : hardlink duplicates instead of listing them")
    print("   - -m : summarize certain output (varies by version)")
    print("")
    print("4) Manual duplicate cleanup:")
    print("   - Move or remove identified duplicates at your discretion.")
    print("   - Always verify crucial data backups before removal.")
    print("")
    print("5) Encouraging Manual Review:")
    print(
        "   - You can safely run 'jdupes' with '-n' or '-X size+=5k' filters to refine which duplicates to consider."
    )
    print("   - Run 'man jdupes' or 'jdupes --help' to learn more advanced usage.")
    print("")
    print("6) For advanced or custom workflows, integrate jdupes in scripts or use")
    print("   the C library that jdupes provides. This wrapper is an example of how")
    print("   to orchestrate jdupes results into automated actions.\n")
    print("=========================================================\n")
    input("Press Enter to return to the main menu.")


# -------------------------------------------------------------------
# Duplicate Processing Functions
# -------------------------------------------------------------------
def process_duplicate_group(group_files):
    """
    Processes a group of duplicate files. The first file is kept, others are handled.
    """
    if not group_files:
        return

    keep_file = Path(group_files[0]).expanduser().resolve()
    logger.debug(f"Keeping file: {keep_file}")

    duplicates_to_handle = group_files[1:]
    if not duplicates_to_handle:
        return

    print(f"\nFound duplicates for: {keep_file}")
    for i, dup_file in enumerate(duplicates_to_handle):
        print(f"  {i+1}. {dup_file}")

    print("\nHow would you like to handle these duplicates?")
    print("1) Move to duplicates folder")
    print("2) Delete permanently")
    print("3) Skip (do nothing)")
    choice = input("Select an option: ").strip()

    if choice == "1":
        move_duplicates(duplicates_to_handle)
    elif choice == "2":
        delete_duplicates(duplicates_to_handle)
    elif choice == "3":
        print("Skipping these duplicates.")
    else:
        print("Invalid choice. Skipping these duplicates.")


def move_duplicates(files_to_move):
    """Moves a list of files to the configured duplicates directory."""
    duplicates_dir = Path(config["duplicates_dir"]).expanduser().resolve()
    if not duplicates_dir.is_dir():
        logger.error(
            f"Duplicates directory {duplicates_dir} does not exist or is not a directory."
        )
        print(
            f"ERROR: Duplicates directory '{duplicates_dir}' is invalid. Check config."
        )
        return

    for src_path_str in files_to_move:
        src_path = Path(src_path_str).expanduser().resolve()

        if str(src_path) in already_moved:
            logger.info(f"Skipping (already moved): {src_path}")
            continue

        if not src_path.is_file():
            logger.warning(f"File not found or not a file (skipping): {src_path}")
            print(f"WARNING: File does not exist (skipping): {src_path}")
            continue

        filename = src_path.name
        destination = duplicates_dir / filename

        # Handle naming conflicts by appending a number
        count = 1
        while destination.exists():
            destination = duplicates_dir / f"{count}_{filename}"
            count += 1

        try:
            src_path.rename(destination)  # atomic move
            already_moved.add(str(src_path))
            logger.info(f"Moved {src_path} -> {destination}")
            print(f"Moved {src_path} -> {destination}")
        except Exception as e:
            logger.error(f"Failed to move {src_path}: {e}")
            print(f"ERROR: Could not move {src_path}. Check logs for details.")


def delete_duplicates(files_to_delete):
    """Deletes a list of files permanently."""
    confirm = (
        input("Are you sure you want to PERMANENTLY DELETE these files? (yes/no): ")
        .strip()
        .lower()
    )
    if confirm != "yes":
        print("Deletion cancelled.")
        return

    for file_path_str in files_to_delete:
        file_path = Path(file_path_str).expanduser().resolve()

        if str(file_path) in already_moved:
            logger.info(f"Skipping deletion (already moved): {file_path}")
            continue

        if not file_path.is_file():
            logger.warning(
                f"File not found or not a file (skipping deletion): {file_path}"
            )
            print(f"WARNING: File does not exist (skipping deletion): {file_path}")
            continue

        try:
            file_path.unlink()  # Delete the file
            already_moved.add(str(file_path))  # Mark as processed
            logger.info(f"Deleted {file_path}")
            print(f"Deleted {file_path}")
        except Exception as e:
            logger.error(f"Failed to delete {file_path}: {e}")
            print(f"ERROR: Could not delete {file_path}. Check logs for details.")


def run_duplicate_scan_and_process():
    """Runs jdupes and processes the found duplicates."""
    scan_dirs = config["scan_directories"]

    if not scan_dirs:
        logger.warning("No directories specified in config. Please configure first.")
        print(
            "No directories specified. Please configure directories before scanning.\n"
        )
        return

    # Validate directories
    for dir_path_str in scan_dirs:
        dir_path = Path(dir_path_str).expanduser().resolve()
        if not dir_path.is_dir():
            logger.warning(f"Directory not found or inaccessible: {dir_path}")
            print(f"WARNING: Directory not found or inaccessible: {dir_path}\n")
            return

    # Construct jdupes command
    # -r: recursive, -A: print all sets without prompting, -o name: sort by name
    cmd = ["jdupes", "-r", "-A", "-o", "name"] + scan_dirs
    logger.info(f"Executing command: {'. '.join(cmd)}")
    print("\nRunning jdupes for duplicates scan...")
    print("(This may take a while depending on data size.)")

    ret, stdout, stderr = run_command(cmd)

    if ret != 0:
        logger.error(f"Error running jdupes: {stderr.strip()}")
        print(f"ERROR: jdupes command failed. Check logs for details.\n")
        return

    lines = stdout.strip().splitlines()
    current_duplicate_group = []
    for line in lines:
        if not line.strip():  # Blank line separates groups
            if len(current_duplicate_group) > 1:
                process_duplicate_group(current_duplicate_group)
            current_duplicate_group = []
        else:
            current_duplicate_group.append(line.strip())

    # Process the last group if not empty
    if len(current_duplicate_group) > 1:
        process_duplicate_group(current_duplicate_group)

    print(
        "\nDuplicate processing complete. Check log and duplicates folder for moved/deleted files.\n"
    )
    logger.info("jdupes scan and duplicate processing complete.")
    save_moved_files_log()


# -------------------------------------------------------------------
# Main Script Entrypoint
# -------------------------------------------------------------------
def main():
    """Main script execution flow."""
    ensure_jdupes_installed()
    load_config()
    load_moved_files_log()

    while True:
        choice = main_menu()
        if choice == "1":
            configure_scan_directories()
        elif choice == "2":
            configure_duplicates_folder()
        elif choice == "3":
            run_duplicate_scan_and_process()
        elif choice == "4":
            show_educational_info()
        elif choice == "5":
            logger.info(f"Exiting {APP_NAME}. User requested exit.")
            print(f"\nExiting {APP_NAME}. Goodbye!\n")
            break
        else:
            print("Invalid choice. Please try again.")


if __name__ == "__main__":
    main()
