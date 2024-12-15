#!/usr/bin/python3

import os
import subprocess
import sys
import select
import shutil
import stat
import time
import logging
import datetime
import pexpect
import re
from functools import partial
import threading
import itertools
from contextlib import contextmanager

# Set up basic logging configuration
log_dir = os.path.expanduser("~/.local/share/system_maintenance")
os.makedirs(log_dir, exist_ok=True)
log_file_path = os.path.join(
    log_dir, datetime.datetime.now().strftime("%Y%m%d_%H%M%S_system_maintenance.log")
)
logging.basicConfig(
    filename=log_file_path,
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
)

# Spinner context manager
@contextmanager
def spinning_spinner(symbols="|/-\\", speed=0.1):
    """
    A context manager that manages a console spinner to indicate progress.
    The spinner automatically stops when the context is exited.
    """
    spinner_running = threading.Event()
    spinner_running.set()
    spinner_symbols = itertools.cycle(symbols)

    def spin():
        while spinner_running.is_set():
            sys.stdout.write(next(spinner_symbols) + "\r")
            sys.stdout.flush()
            time.sleep(speed)

    spinner_thread = threading.Thread(target=spin)
    spinner_thread.start()

    try:
        yield
    finally:
        spinner_running.clear()
        spinner_thread.join()
        sys.stdout.write(" " * 10 + "\r")
        sys.stdout.flush()


# Colors and symbols
GREEN = "\033[38;2;57;255;20m"
BOLD = "\033[1m"
RED = "\033[0;31m"
NC = "\033[0m"  # No Color
SUCCESS = "✔️"
FAILURE = "❌"
INFO = "➡️"
WARNING = "⚠️"

def format_message(message, color):
    """
    Format a message with the given color and bold text.
    """
    return f"{BOLD}{color}{message}{NC}"

def log_and_print(message, level="info"):
    """
    Print and log a message at the specified log level.
    """
    print(message)
    if level == "info":
        logging.info(message)
    elif level == "error":
        logging.error(message)
    elif level == "warning":
        logging.warning(message)
    else:
        logging.info(f"Unhandled log level: {level}. Message: {message}")

def execute_command(command, error_message=None):
    """
    Execute a shell command and log the output or error.
    """
    try:
        result = subprocess.run(
            command, capture_output=True, text=True, check=True
        )
        logging.info(result.stdout)
        if result.stderr:
            logging.error(result.stderr)
        return result.stdout
    except subprocess.CalledProcessError as e:
        stderr = e.stderr.strip() if e.stderr else e.output.strip()
        log_message = error_message or f"Command '{e.cmd}' failed with error: {stderr}"
        log_and_print(format_message(log_message, RED), "error")
        return None
    except Exception as e:
        log_message = error_message or f"Command execution failed with error: {str(e)}"
        log_and_print(format_message(log_message, RED), "error")
        return None

def prompt_with_timeout(prompt: str, timeout: int = 30, default: str = "Q") -> str:
    """
    Prompt the user for input with a timeout and default value.
    """
    sys.stdout.write(prompt)
    sys.stdout.flush()

    try:
        ready, _, _ = select.select([sys.stdin], [], [], timeout)
        if ready:
            user_input = sys.stdin.readline().strip()
            return user_input if user_input else default
        else:
            print(
                f"\n{GREEN}No input detected within {timeout} seconds, using default: {default}{NC}"
            )
            return default
    except Exception as e:
        log_and_print(f"{FAILURE} Error reading input: {str(e)}", "error")
        return default

def confirm_deletion(file_or_dir):
    """
    Ask for confirmation before deletion.
    """
    confirm = prompt_with_timeout(
        f"Do you really want to delete {file_or_dir}? [y/N]: ", timeout=10, default="n"
    ).lower()
    return confirm == "y"

def process_dep_scan_log(log_file):
    """
    Process the dependency scan log to fix file permissions and install missing dependencies.
    """
    log_and_print(f"{INFO} Processing dependency scan log...")
    dep_scan_log = os.path.expanduser("~/dependency_scan.log")
    if os.path.isfile(dep_scan_log):
        try:
            with spinning_spinner():
                with open(dep_scan_log, "r") as log:
                    for line in log:
                        if "permission warning" in line:
                            file_path = line.split(": ")[1].strip()
                            fix_permissions(file_path)
                        if "missing dependency" in line:
                            dependency = line.split(": ")[1].strip()
                            install_missing_dependency(dependency)
            log_and_print(f"{SUCCESS} Dependency scan log processing completed.", "info")
        except IOError as e:
            log_and_print(f"{FAILURE} Error reading dependency scan log: {e}", "error")
    else:
        log_and_print(f"{FAILURE} Dependency scan log file not found.", "error")

def fix_permissions(file_path):
    """
    Fix the permissions for the given file or directory.
    """
    try:
        if os.path.isfile(file_path):
            os.chmod(
                file_path,
                stat.S_IRUSR | stat.S_IWUSR | stat.S_IRGRP | stat.S_IROTH,
            )
            log_and_print(f"{INFO} Fixed permissions for file: {file_path}", "info")
        elif os.path.isdir(file_path):
            os.chmod(
                file_path,
                stat.S_IRWXU
                | stat.S_IRGRP
                | stat.S_IXGRP
                | stat.S_IROTH
                | stat.S_IXOTH,
            )
            log_and_print(f"{INFO} Fixed permissions for directory: {file_path}", "info")
    except OSError as e:
        log_and_print(
            f"{FAILURE} Error fixing permissions for {file_path}: {e}", "error"
        )

def install_missing_dependency(dependency):
    """
    Install the missing dependency using the package manager.
    """
    log_and_print(
        f"{INFO} Attempting to install missing dependency: {dependency}", "info"
    )
    if execute_command(
        ["pacman", "-Qi", dependency], "Dependency check failed"
    ) is None:
        result = execute_command(
            ["sudo", "pacman", "-Sy", "--noconfirm", dependency]
        )
        if result:
            log_and_print(
                f"{SUCCESS} Successfully installed missing dependency: {dependency}",
                "info",
            )
        else:
            log_and_print(
                f"{FAILURE} Failed to install missing dependency: {dependency}",
                "error",
            )
    else:
        log_and_print(f"{INFO} Dependency {dependency} is already installed.", "info")

def manage_cron_job(log_file):
    """
    Interactively manage system cron jobs.
    """
    log_and_print(f"{INFO} Managing system cron jobs...", "info")
    with spinning_spinner():
        try:
            result = subprocess.run(
                ["sudo", "crontab", "-l"],
                capture_output=True,
                text=True,
                check=True,
            )
            existing_crons = result.stdout.strip().split("\n")
            if existing_crons == [""]:
                existing_crons = []

            log_and_print("Existing cron jobs:\n", "info")
            for i, cron in enumerate(existing_crons, 1):
                log_and_print(f"{i}. {cron}", "info")

            choice = prompt_with_timeout(
                "Do you want to add a new cron job or delete an existing one? (add/delete/skip): ",
                timeout=10,
                default="skip",
            ).lower()

            if choice == "add":
                new_cron = input("Enter the new cron job entry: ").strip()
                if new_cron:
                    existing_crons.append(new_cron)
                    new_crons = "\n".join(existing_crons) + "\n"
                    update_cron_jobs(new_crons)
                    log_and_print(f"{SUCCESS} New cron job added successfully.", "info")
                else:
                    log_and_print(
                        f"{FAILURE} No cron job entry provided. Aborting addition.",
                        "error",
                    )

            elif choice == "delete":
                cron_to_delete = input(
                    "Enter the number of the cron job entry to delete: "
                ).strip()
                if cron_to_delete.isdigit():
                    cron_to_delete = int(cron_to_delete)
                    if 1 <= cron_to_delete <= len(existing_crons):
                        del existing_crons[cron_to_delete - 1]
                        new_crons = "\n".join(existing_crons) + "\n"
                        update_cron_jobs(new_crons)
                        log_and_print(
                            f"{SUCCESS} Cron job deleted successfully.", "info"
                        )
                    else:
                        log_and_print(
                            f"{FAILURE} Invalid selection. No changes made.", "error"
                        )
                else:
                    log_and_print(
                        f"{FAILURE} Invalid input. Please enter a number.", "error"
                    )

            else:
                log_and_print(f"{INFO} No changes made to cron jobs.", "info")

        except subprocess.CalledProcessError as e:
            log_and_print(
                f"{FAILURE} Error managing cron jobs: {e.stderr.strip()}", "error"
            )

def update_cron_jobs(new_crons):
    """
    Update the system cron jobs with the new entries.
    """
    temp_file_path = "/tmp/cron_temp"
    try:
        with open(temp_file_path, "w") as temp_file:
            temp_file.write(new_crons)
        subprocess.run(["sudo", "crontab", temp_file_path], check=True)
    except Exception as e:
        log_and_print(f"{FAILURE} Error updating cron jobs: {str(e)}", "error")
    finally:
        if os.path.exists(temp_file_path):
            os.remove(temp_file_path)

def remove_broken_symlinks(log_file):
    """
    Find and remove broken symbolic links in the user's home directory.
    """
    log_and_print(f"{INFO} Searching for broken symbolic links...", "info")
    broken_links = []
    try:
        command = ["find", os.path.expanduser("~"), "-xtype", "l"]
        result = subprocess.run(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
        )
        broken_links = result.stdout.strip().split("\n") if result.stdout else []

        if not broken_links:
            log_and_print(f"{SUCCESS} No broken symbolic links found.", "info")
            return

        log_and_print(f"{INFO} Found {len(broken_links)} broken symbolic links:", "info")
        for link in broken_links:
            print(link)

        confirm = prompt_with_timeout(
            "Do you want to remove these broken symbolic links? [y/N]: ", timeout=15, default="n"
        ).lower()

        if confirm != "y":
            log_and_print(f"{INFO} Broken symbolic link removal aborted by user.", "info")
            return

        for link in broken_links:
            try:
                os.remove(link)
                logging.info(f"Removed broken symlink: {link}")
            except Exception as e:
                logging.error(f"Failed to remove {link}: {str(e)}")

        log_and_print(f"{SUCCESS} Broken symbolic links removed.", "info")

    except Exception as e:
        log_and_print(f"{FAILURE} Error searching for broken symbolic links: {str(e)}", "error")

def clean_old_kernels(log_file):
    """
    Clean up old kernel images, with user confirmation.
    """
    log_and_print(f"{INFO} Cleaning up old kernel images...", "info")
    with spinning_spinner():
        try:
            explicitly_installed = subprocess.check_output(
                ["pacman", "-Qeq"], text=True
            ).strip().split("\n")
            current_kernel = subprocess.check_output(["uname", "-r"], text=True).strip()
            current_kernel_version = current_kernel.split("-")[0]
            kernels_to_remove = []

            for pkg in explicitly_installed:
                if pkg.startswith("linux") and pkg != f"linux{current_kernel_version}":
                    kernels_to_remove.append(pkg)

            if kernels_to_remove:
                log_and_print("Kernels to be removed:", "info")
                for i, kernel in enumerate(kernels_to_remove, 1):
                    log_and_print(f"{i}. {kernel}", "info")

                confirm = prompt_with_timeout(
                    "Do you want to remove these kernels? [y/N]: ",
                    timeout=10,
                    default="n",
                ).lower()
                if confirm == "y":
                    subprocess.run(
                        ["sudo", "pacman", "-Rns", "--noconfirm"] + kernels_to_remove,
                        check=True,
                    )
                    log_and_print(
                        f"{SUCCESS} Old kernel images cleaned up: {' '.join(kernels_to_remove)}",
                        "info",
                    )
                else:
                    log_and_print(f"{INFO} Kernel cleanup canceled by user.", "info")
            else:
                log_and_print(f"{INFO} No old kernel images to remove.", "info")
        except subprocess.CalledProcessError as e:
            log_and_print(f"{FAILURE} Error: {e.stderr.strip()}", "error")

def vacuum_journalctl(log_file):
    """
    Vacuum journalctl logs older than 1 day, providing detailed output.
    """
    log_and_print(f"{INFO} Vacuuming journalctl logs older than 1 day...", "info")
    with spinning_spinner():
        try:
            result = subprocess.run(
                ["sudo", "journalctl", "--vacuum-time=1d"],
                check=True,
                capture_output=True,
                text=True,
            )
            log_and_print(
                f"{SUCCESS} Journalctl vacuumed successfully. Details:\n{result.stdout}",
                "info",
            )
        except subprocess.CalledProcessError as e:
            log_and_print(
                f"{FAILURE} Error: Failed to vacuum journalctl: {e.stderr.strip()}",
                "error",
            )

def clear_cache(log_file):
    """
    Clear user cache files older than 1 day, logging success or failure.
    """
    log_and_print(f"{INFO} Clearing user cache...", "info")
    with spinning_spinner():
        try:
            subprocess.run(["sudo", "pacman", "-Sc", "--noconfirm"], check=True)
            log_and_print(f"{SUCCESS} Package cache cleaned.", "info")
        except subprocess.CalledProcessError as e:
            log_and_print(
                f"{FAILURE} Error cleaning package cache: {e.stderr.strip()}", "error"
            )

            cache_dir = "/var/cache/pacman/pkg/"
            problematic_files = []

            try:
                for root, dirs, files in os.walk(cache_dir):
                    for file in files:
                        file_path = os.path.join(root, file)
                        if re.search(
                            r"\.aria2$|\.part$|\.crdownload$|\.unrecognized$", file
                        ):
                            problematic_files.append(file_path)

                for file_path in problematic_files:
                    try:
                        os.remove(file_path)
                        log_and_print(
                            f"{SUCCESS} Removed problematic file: {file_path}", "info"
                        )
                    except FileNotFoundError:
                        log_and_print(
                            f"{INFO} File not found, skipping: {file_path}", "info"
                        )
                    except OSError as os_error:
                        log_and_print(
                            f"{FAILURE} Failed to remove file {file_path}: {os_error}",
                            "error",
                        )

            except Exception as scan_error:
                log_and_print(
                    f"{FAILURE} Error scanning for problematic files: {scan_error}",
                    "error",
                )

def update_font_cache(log_file):
    """
    Update the font cache, logging success or failure.
    """
    log_and_print(f"{INFO} Updating font cache...", "info")
    with spinning_spinner():
        try:
            result = subprocess.run(
                ["sudo", "fc-cache", "-fv"],
                check=True,
                capture_output=True,
                text=True,
            )
            log_and_print(
                f"{SUCCESS} Font cache updated successfully. Details:\n{result.stdout}",
                "info",
            )
        except subprocess.CalledProcessError as e:
            log_and_print(
                f"{FAILURE} Error: Failed to update font cache: {e.stderr.strip()}",
                "error",
            )

def clear_trash(log_file):
    """
    Clear the user's trash directory.
    """
    log_and_print(f"{INFO} Clearing trash...", "info")
    try:
        trash_dir = os.path.expanduser("~/.local/share/Trash")
        if os.path.exists(trash_dir):
            for item in os.listdir(trash_dir):
                item_path = os.path.join(trash_dir, item)
                if os.path.isfile(item_path) or os.path.islink(item_path):
                    os.unlink(item_path)
                elif os.path.isdir(item_path):
                    shutil.rmtree(item_path)
            log_and_print(f"{SUCCESS} Trash cleared successfully.", "info")
        else:
            log_and_print(f"{INFO} Trash directory does not exist.", "info")
    except Exception as e:
        log_and_print(f"{FAILURE} Error clearing trash: {str(e)}", "error")

def optimize_databases(log_file):
    """
    Optimize system databases, logging success or failure for each step.
    """
    log_and_print(f"{INFO} Optimizing system databases...", "info")

    def run_command(command, success_message, failure_message):
        try:
            subprocess.run(command, check=True, capture_output=True, text=True)
            log_and_print(f"{SUCCESS} {success_message}", "info")
        except subprocess.CalledProcessError as e:
            log_and_print(f"{FAILURE} {failure_message}: {e.stderr.strip()}", "error")

    with spinning_spinner():
        try:
            log_and_print(f"{INFO} Updating mlocate database...", "info")
            run_command(
                ["sudo", "updatedb"],
                "mlocate database updated.",
                "Failed to update mlocate database",
            )

            log_and_print(f"{INFO} Updating pkgfile database...", "info")
            run_command(
                ["sudo", "pkgfile", "-u"],
                "pkgfile database updated.",
                "Failed to update pkgfile database",
            )

            log_and_print(f"{INFO} Upgrading pacman database...", "info")
            run_command(
                ["sudo", "pacman-db-upgrade"],
                "pacman database upgraded.",
                "Failed to upgrade pacman database",
            )

            log_and_print(f"{INFO} Cleaning package cache...", "info")
            run_command(
                ["sudo", "pacman", "-Sc", "--noconfirm"],
                "Package cache cleaned.",
                "Failed to clean package cache",
            )

            log_and_print(f"{INFO} Syncing filesystem changes...", "info")
            run_command(
                ["sync"],
                "Filesystem changes synced.",
                "Failed to sync filesystem changes",
            )

            log_and_print(f"{INFO} Refreshing pacman keys...", "info")
            run_command(
                ["sudo", "pacman-key", "--refresh-keys"],
                "Keys refreshed.",
                "Failed to refresh keys",
            )

            log_and_print(f"{INFO} Populating keys and updating trust...", "info")
            run_command(
                ["sudo", "pacman-key", "--populate"],
                "Keys populated.",
                "Failed to populate keys",
            )
            run_command(
                ["sudo", "pacman-key", "--updatedb"],
                "Trust database updated.",
                "Failed to update trust database",
            )

            log_and_print(f"{INFO} Refreshing package list...", "info")
            run_command(
                ["sudo", "pacman", "-Syy"],
                "Package list refreshed.",
                "Failed to refresh package list",
            )

            log_and_print(f"{SUCCESS} System databases optimized.", "info")
        except Exception as e:
            log_and_print(
                f"{FAILURE} Unexpected error during database optimization: {str(e)}",
                "error",
            )

def is_interactive():
    return sys.stdin.isatty()

def clean_package_cache(log_file):
    """
    Clean the package cache using paccache.
    """
    log_and_print(f"{INFO} Cleaning package cache...", "info")
    try:
        if is_interactive():
            confirm = prompt_with_timeout(
                "Do you want to proceed with cleaning the package cache? [Y/n]: ", timeout=15, default="Y"
            )
            if confirm:
                confirm = confirm.strip().lower()
            else:
                confirm = "y"

            if confirm != "y":
                log_and_print(f"{INFO} Package cache cleaning aborted by user.", "info")
                return
        else:
            log_and_print(f"{INFO} Running in non-interactive mode. Proceeding with cleaning.", "info")

        cache_dir = "/var/cache/pacman/pkg/"
        temp_files = [f for f in os.listdir(cache_dir) if f.endswith('.aria2') or f.startswith('download-')]
        for temp_file in temp_files:
            temp_file_path = os.path.join(cache_dir, temp_file)
            if os.path.isfile(temp_file_path):
                os.remove(temp_file_path)
                logging.info(f"Removed temporary file: {temp_file_path}")
            else:
                logging.warning(f"Expected file but found directory: {temp_file_path}")

        command = ["sudo", "paccache", "-rk2"]
        result = subprocess.run(command, capture_output=True, text=True)
        if result.returncode == 0:
            logging.info(result.stdout)
            log_and_print(f"{SUCCESS} Package cache cleaned.", "info")
        else:
            logging.error(result.stderr)
            log_and_print(f"{FAILURE} Error cleaning package cache: {result.stderr.strip()}", "error")
    except Exception as e:
        log_and_print(f"{FAILURE} Error cleaning package cache: {str(e)}", "error")

def clean_aur_dir(log_file):
    """
    Clean the AUR directory, deleting only uninstalled or old versions of packages, and log success or failure.
    """
    log_and_print(f"{INFO} Cleaning AUR directory...", "info")
    with spinning_spinner():
        try:
            aur_dir = os.path.expanduser("/home/build/")
            if not os.path.isdir(aur_dir):
                log_and_print(
                    f"{FAILURE} The specified path is not a directory: {aur_dir}",
                    "error",
                )
                return

            os.chdir(aur_dir)
            pkgname_regex = re.compile(
                r"(?P<pkgname>.*?)-(?P<pkgver>[^-]+)-(?P<arch>x86_64|any|i686)\.pkg\.tar\.(xz|zst|gz|bz2|lrz|lzo|lz4|lz)$"
            )
            files = {}
            for f in os.listdir():
                if not os.path.isfile(f):
                    continue
                match = pkgname_regex.match(f)
                if match:
                    files[f] = match.groupdict()

            installed_packages = subprocess.check_output(
                ["expac", "-Qs", "%n %v"], universal_newlines=True
            ).splitlines()
            installed = {pkg.split()[0]: pkg.split()[1] for pkg in installed_packages}

            for f, file_info in files.items():
                pkgname = file_info["pkgname"]
                pkgver = file_info["pkgver"]
                if pkgname not in installed or pkgver != installed[pkgname]:
                    log_and_print(f"{INFO} Deleting: {f}", "info")
                    try:
                        os.remove(f)
                    except OSError as e:
                        log_and_print(f"{FAILURE} Error deleting file {f}: {e}", "error")

            log_and_print(f"{SUCCESS} AUR directory cleaned.", "info")
        except subprocess.CalledProcessError as e:
            log_and_print(
                f"{FAILURE} Error: Failed to clean AUR directory: {e.stderr.strip()}",
                "error",
            )

def handle_pacnew_pacsave(log_file):
    """
    Automatically handle .pacnew and .pacsave files, logging a summary of actions taken.
    """
    log_and_print(f"{INFO} Handling .pacnew and .pacsave files...", "info")
    with spinning_spinner():
        try:
            pacnew_files = subprocess.check_output(
                ["sudo", "find", "/etc", "-type", "f", "-name", "*.pacnew"],
                text=True,
            ).splitlines()
            pacsave_files = subprocess.check_output(
                ["sudo", "find", "/etc", "-type", "f", "-name", "*.pacsave"],
                text=True,
            ).splitlines()

            actions_summary = []

            if pacnew_files:
                log_and_print(f"{INFO} Found .pacnew files.", "info")
                for file in pacnew_files:
                    action = prompt_with_timeout(
                        f"Do you want to merge, replace, or remove {file}? (merge/replace/remove): ",
                        timeout=10,
                        default="skip",
                    ).lower()
                    if action == "merge":
                        original_file = file.replace(".pacnew", "")
                        subprocess.run(["sudo", "diff", "-u", original_file, file])
                        log_and_print(
                            f"{INFO} Merging not implemented in this script.", "info"
                        )
                        actions_summary.append(f"Skipped merging .pacnew file: {file}")
                    elif action == "replace":
                        original_file = file.replace(".pacnew", "")
                        shutil.copyfile(file, original_file)
                        os.remove(file)
                        actions_summary.append(f"Replaced with .pacnew file: {file}")
                    elif action == "remove":
                        os.remove(file)
                        actions_summary.append(f"Removed .pacnew file: {file}")
                    else:
                        actions_summary.append(f"Skipped .pacnew file: {file}")

            if pacsave_files:
                log_and_print(f"{INFO} Found .pacsave files.", "info")
                for file in pacsave_files:
                    action = prompt_with_timeout(
                        f"Do you want to restore or remove {file}? (restore/remove): ",
                        timeout=10,
                        default="skip",
                    ).lower()
                    if action == "restore":
                        original_file = file.replace(".pacsave", "")
                        shutil.copyfile(file, original_file)
                        os.remove(file)
                        actions_summary.append(f"Restored from .pacsave file: {file}")
                    elif action == "remove":
                        os.remove(file)
                        actions_summary.append(f"Removed .pacsave file: {file}")
                    else:
                        actions_summary.append(f"Skipped .pacsave file: {file}")

            if actions_summary:
                log_and_print(f"{INFO} Summary of actions taken:", "info")
                for action in actions_summary:
                    log_and_print(f"{INFO} {action}", "info")
            else:
                log_and_print(f"{INFO} No .pacnew or .pacsave files found.", "info")

        except subprocess.CalledProcessError as e:
            log_and_print(
                f"{FAILURE} Error finding or handling .pacnew/.pacsave files: {e.stderr.strip()}",
                "error",
            )
        except Exception as ex:
            log_and_print(f"{FAILURE} Unexpected error: {str(ex)}", "error")

def verify_installed_packages(log_file):
    """
    Verify installed packages for missing files and automatically reinstall them,
    handling both official and AUR packages.
    """
    log_and_print(f"{INFO} Checking for packages with missing files...", "info")

    try:
        print("Choose an option:\n1) Single package\n2) System-wide")
        choice = input("Enter your choice (1 or 2): ").strip()

        if choice == "1":
            package = input("Enter the package name to check: ").strip()
            if not package:
                log_and_print(f"{FAILURE} No package name provided. Exiting.", "error")
                return
            command = ["pacman", "-Qk", package]
        elif choice == "2":
            command = ["pacman", "-Qk"]
        else:
            log_and_print(f"{FAILURE} Invalid choice. Exiting.", "error")
            return

        with spinning_spinner():
            result = subprocess.run(
                command, capture_output=True, text=True
            )
            output = result.stdout + result.stderr
            lines = output.strip().split("\n")
            missing_packages = set()
            details = []

            for line in lines:
                if ": 0 missing files" not in line:
                    details.append(line)
                    match = re.match(r"warning: (\S+): .*", line)
                    if match:
                        pkg_name = match.group(1)
                        missing_packages.add(pkg_name)

            if not missing_packages:
                log_and_print(f"{SUCCESS} No packages with missing files found.", "info")
                return

            logging.info("Packages with missing files:\n" + "\n".join(details))

            log_and_print(
                f"{INFO} Found {len(missing_packages)} packages with missing files. Details logged.",
                "info",
            )

            confirm = prompt_with_timeout(
                f"Do you want to reinstall these packages to restore missing files? [y/N]: ",
                timeout=15,
                default="n",
            ).lower()

            if confirm != "y":
                log_and_print(f"{INFO} Reinstallation aborted by user.", "info")
                return

            log_and_print(f"{INFO} Updating keyrings before reinstallation...", "info")
            keyring_update = subprocess.run(
                ["sudo", "pacman", "-Sy", "archlinux-keyring", "chaotic-keyring", "--noconfirm"],
                capture_output=True,
                text=True
            )
            if keyring_update.returncode != 0:
                logging.error(keyring_update.stderr)
                log_and_print(f"{FAILURE} Failed to update keyrings.", "error")
                return
            else:
                logging.info(keyring_update.stdout)

            pacman_lock = "/var/lib/pacman/db.lck"
            if os.path.exists(pacman_lock):
                log_and_print(f"{INFO} Removing pacman lock file...", "info")
                subprocess.run(["sudo", "rm", "-f", pacman_lock])

            aur_helper = detect_aur_helper()

            official_packages = []
            aur_packages = []
            for pkg in missing_packages:
                if is_aur_package(pkg):
                    aur_packages.append(pkg)
                else:
                    official_packages.append(pkg)

            if official_packages:
                log_and_print(f"{INFO} Reinstalling official packages...", "info")
                reinstall_packages_pexpect(official_packages)

            if aur_packages and aur_helper:
                log_and_print(f"{INFO} Reinstalling AUR packages...", "info")
                reinstall_aur_packages(aur_packages, aur_helper)
            elif aur_packages:
                log_and_print(f"{FAILURE} AUR packages detected but no AUR helper found.", "error")
                log_and_print(f"Please install an AUR helper like 'yay' or 'paru'.", "error")

        log_and_print(f"{SUCCESS} Package verification and reinstallation completed.", "info")

    except Exception as e:
        log_and_print(f"{FAILURE} Unexpected error: {str(e)}", "error")

def detect_aur_helper():
    """
    Detect available AUR helper.
    """
    aur_helpers = ['yay', 'paru', 'trizen']
    for helper in aur_helpers:
        if shutil.which(helper):
            log_and_print(f"{INFO} AUR helper detected: {helper}", "info")
            return helper
    return None

def is_aur_package(package):
    """
    Check if a package is an AUR package.
    """
    result = subprocess.run(['pacman', '-Si', package], capture_output=True, text=True)
    if 'error: package' in result.stdout.lower():
        return True
    else:
        return False

def reinstall_aur_packages(packages, aur_helper):
    """
    Reinstall AUR packages using the specified AUR helper.
    """
    for pkg in packages:
        log_and_print(f"{INFO} Reinstalling AUR package {pkg} using {aur_helper}...", "info")
        command = f"{aur_helper} -S {pkg} --noconfirm"
        child = pexpect.spawn(command, encoding='utf-8', timeout=600)

        try:
            child.logfile = open(log_file_path, 'a')
            child.expect(pexpect.EOF)
            child.close()
            if child.exitstatus == 0:
                log_and_print(f"{SUCCESS} AUR package {pkg} reinstalled successfully.", "info")
            else:
                log_and_print(f"{FAILURE} Failed to reinstall AUR package {pkg}.", "error")
        except Exception as e:
            log_and_print(f"{FAILURE} Error reinstalling AUR package {pkg}: {str(e)}", "error")

def reinstall_packages_pexpect(packages, max_retries=3):
    """
    Reinstall a list of packages using pexpect to automate pacman interactions.
    """
    for pkg in packages:
        success = False
        retries = 0
        while not success and retries < max_retries:
            log_and_print(f"{INFO} Reinstalling {pkg} (Attempt {retries+1}/{max_retries})...", "info")
            command = f"sudo pacman -S {pkg} --noconfirm --needed"
            child = pexpect.spawn(command, encoding='utf-8', timeout=300)

            try:
                while True:
                    index = child.expect([
                        pexpect.EOF,
                        pexpect.TIMEOUT,
                        r':: Import PGP key .* \[Y/n\]',
                        r':: Replace .* \[Y/n\]',
                        r':: Proceed with installation\? \[Y/n\]',
                        r':: (.*) exists in filesystem',
                        r'error: .*',
                    ])
                    if index == 0:  # EOF
                        break
                    elif index == 1:  # TIMEOUT
                        log_and_print(f"{FAILURE} Reinstallation timed out.", "error")
                        break
                    elif index == 2:  # Import PGP key
                        child.sendline('y')
                    elif index == 3:  # Replace package
                        child.sendline('y')
                    elif index == 4:  # Proceed with installation
                        child.sendline('y')
                    elif index == 5:  # File exists in filesystem
                        file_conflict = child.match.group(1)
                        log_and_print(f"{INFO} Overwriting conflicting file: {file_conflict}", "info")
                        child.sendline('y')
                    elif index == 6:  # Error
                        error_msg = child.after.strip()
                        logging.error(error_msg)
                        handle_pacman_errors(error_msg)
                        break

                child.expect(pexpect.EOF)
                child.close()
                if child.exitstatus == 0:
                    success = True
                    log_and_print(f"{SUCCESS} Package {pkg} reinstalled successfully.", "info")
                    logging.info(child.before)
                else:
                    logging.error(child.before + (child.after if child.after else ''))
                    retries += 1
            except Exception as e:
                logging.error(str(e))
                retries += 1

        if not success:
            log_and_print(f"{FAILURE} Failed to reinstall {pkg} after {max_retries} attempts.", "error")

def handle_pacman_errors(error_msg):
    """
    Handle common pacman errors during package installation.
    """
    if "key could not be looked up remotely" in error_msg or "signature is unknown trust" in error_msg:
        log_and_print(f"{INFO} Keyring issue detected. Updating keyrings...", "info")
        subprocess.run(
            ["sudo", "pacman", "-Sy", "archlinux-keyring", "chaotic-keyring", "--noconfirm"],
            capture_output=True,
            text=True
        )

    if "exists in filesystem" in error_msg:
        files = re.findall(r'[\s]([^\s]+) exists in filesystem', error_msg)
        if files:
            overwrite_files = ','.join(files)
            log_and_print(f"{INFO} Overwriting conflicting files: {overwrite_files}", "info")
            subprocess.run(
                ["sudo", "pacman", "-S", "--overwrite", overwrite_files, "--noconfirm"],
                capture_output=True,
                text=True
            )

    if "error: duplicated database entry" in error_msg:
        duplicated_entries = re.findall(r"error: duplicated database entry '([^']+)'", error_msg)
        if duplicated_entries:
            for entry in duplicated_entries:
                log_and_print(f"{INFO} Removing duplicated entry: {entry}", "info")
                subprocess.run(
                    ["sudo", "pacman", "-Rdd", entry, "--noconfirm"],
                    capture_output=True,
                    text=True
                )

def check_failed_cron_jobs(log_file):
    """
    Check for failed cron jobs and optionally attempt to repair them.
    """
    log_and_print(f"{INFO} Checking for failed cron jobs...", "info")
    try:
        cron_logs = subprocess.check_output(
            ["journalctl", "-u", "cron", "--since", "yesterday"],
            text=True,
            stderr=subprocess.DEVNULL,
        )
        failed_jobs = [
            line for line in cron_logs.split("\n") if "FAILED" in line.upper()
        ]
        if failed_jobs:
            log_and_print(
                f"{FAILURE} Failed cron jobs detected. Review logs for details.", "error"
            )
            for job in failed_jobs:
                log_and_print(job, "error")
            repair = prompt_with_timeout(
                "Do you want to attempt to repair the failed cron jobs? (y/n): ",
                timeout=10,
                default="n",
            ).lower()
            if repair == "y":
                log_and_print(
                    f"{INFO} Please check the cron job definitions and logs manually.",
                    "info",
                )
        else:
            log_and_print(f"{SUCCESS} No failed cron jobs detected.", "info")
    except subprocess.CalledProcessError:
        log_and_print(f"{INFO} No failed cron jobs detected or logs not accessible.", "info")

def clear_docker_images(log_file):
    """
    Clear Docker images if Docker is installed.
    """
    if shutil.which("docker"):
        log_and_print(f"{INFO} Clearing Docker images...", "info")
        try:
            subprocess.run(["sudo", "docker", "image", "prune", "-af"], check=True)
            log_and_print(f"{SUCCESS} Docker images cleared.", "info")
        except subprocess.CalledProcessError as e:
            log_and_print(
                f"{FAILURE} Error: Failed to clear Docker images: {e.stderr.strip()}",
                "error",
            )
    else:
        log_and_print(f"{INFO} Docker is not installed. Skipping Docker image cleanup.", "info")

def clear_temp_folder(log_file):
    """
    Clear the temporary folder.
    """
    log_and_print(f"{INFO} Clearing the temporary folder...", "info")
    with spinning_spinner():
        try:
            subprocess.run(
                ["sudo", "find", "/tmp", "-type", "f", "-atime", "+2", "-delete"],
                check=True,
            )
            log_and_print(f"{SUCCESS} Temporary folder cleared.", "info")
        except subprocess.CalledProcessError as e:
            log_and_print(
                f"{FAILURE} Error: Failed to clear the temporary folder: {e.stderr.strip()}",
                "error",
            )

def check_rmshit_script(log_file=None):
    """
    Clean up unnecessary files specified in the script.
    """
    log_and_print(f"{INFO} Cleaning up unnecessary files...", "info")
    paths_to_clean = [
        "~/.adobe",
        "~/.macromedia",
        "~/.FRD/log/app.log",
        "~/.FRD/links.txt",
        "~/.objectdb",
        "~/.gstreamer-0.10",
        "~/.pulse",
        "~/.esd_auth",
        "~/.config/enchant",
        "~/.spicec",
        "~/.dropbox-dist",
        "~/.parallel",
        "~/.dbus",
        "~/.distlib/",
        "~/.bazaar/",
        "~/.bzr.log",
        "~/.nv/",
        "~/.viminfo",
        "~/.npm/",
        "~/.java/",
        "~/.swt/",
        "~/.oracle_jre_usage/",
        "~/.jssc/",
        "~/.tox/",
        "~/.pylint.d/",
        "~/.qute_test/",
        "~/.QtWebEngineProcess/",
        "~/.qutebrowser/",
        "~/.asy/",
        "~/.cmake/",
        "~/.cache/mozilla/",
        "~/.cache/chromium/",
        "~/.cache/google-chrome/",
        "~/.cache/spotify/",
        "~/.cache/steam/",
        "~/.zoom/",
        "~/.Skype/",
        "~/.minecraft/logs/",
        "~/.thumbnails/",
        "~/.local/share/Trash/",
        "~/.vim/.swp",
        "~/.vim/.backup",
        "~/.vim/.undo",
        "~/.emacs.d/auto-save-list/",
        "~/.cache/JetBrains/",
        "~/.vscode/extensions/",
        "~/.npm/_logs/",
        "~/.npm/_cacache/",
        "~/.composer/cache/",
        "~/.gem/cache/",
        "~/.cache/pip/",
        "~/.gnupg/",
        "~/.wget-hsts",
        "~/.docker/",
        "~/.local/share/baloo/",
        "~/.kde/share/apps/okular/docdata/",
        "~/.local/share/akonadi/",
        "~/.xsession-errors",
        "~/.cache/gstreamer-1.0/",
        "~/.cache/fontconfig/",
        "~/.cache/mesa/",
        "~/.nv/ComputeCache/",
    ]
    new_paths = input(
        "Enter any additional paths to clean (separated by space): "
    ).split()
    paths_to_clean.extend(new_paths)
    for path in paths_to_clean:
        expanded_path = os.path.expanduser(path)
        if os.path.exists(expanded_path) and confirm_deletion(expanded_path):
            try:
                if os.path.isfile(expanded_path):
                    os.remove(expanded_path)
                    log_and_print(f"{INFO} Deleted file: {expanded_path}", "info")
                elif os.path.isdir(expanded_path):
                    shutil.rmtree(expanded_path)
                    log_and_print(f"{INFO} Deleted directory: {expanded_path}", "info")
            except OSError as e:
                log_and_print(
                    f"{FAILURE} Error deleting {expanded_path}: {e}", "error"
                )
    log_and_print(f"{SUCCESS} Unnecessary files cleaned up.", "info")

def remove_old_ssh_known_hosts(log_file):
    """
    Remove old SSH known hosts entries.
    """
    ssh_known_hosts_file = os.path.expanduser("~/.ssh/known_hosts")
    if os.path.isfile(ssh_known_hosts_file):
        log_and_print(f"{INFO} Removing old SSH known hosts entries...", "info")
        try:
            with open(ssh_known_hosts_file, 'r') as file:
                lines = file.readlines()
            new_lines = []
            for line in lines:
                if not line.strip():
                    continue
                host = line.split()[0]
                if not is_host_reachable(host):
                    continue
                new_lines.append(line)
            with open(ssh_known_hosts_file, 'w') as file:
                file.writelines(new_lines)
            log_and_print(f"{SUCCESS} Old SSH known hosts entries cleaned.", "info")
        except Exception as e:
            log_and_print(
                f"{FAILURE} Error: Failed to remove old SSH known hosts entries: {str(e)}",
                "error",
            )
    else:
        log_and_print(f"{INFO} No SSH known hosts file found. Skipping.", "info")

def is_host_reachable(host):
    """
    Check if a host is reachable.
    """
    try:
        subprocess.run(['ping', '-c', '1', '-W', '1', host], stdout=subprocess.DEVNULL)
        return True
    except Exception:
        return False

def remove_orphan_vim_undo_files(log_file):
    """
    Remove orphan Vim undo files.
    """
    log_and_print(f"{INFO} Searching for orphan Vim undo files...", "info")
    home_dir = os.path.expanduser("~")
    with spinning_spinner():
        for root, _, files in os.walk(home_dir):
            for file in files:
                if file.endswith(".un~"):
                    original_file = os.path.splitext(os.path.join(root, file))[0]
                    if not os.path.exists(original_file):
                        try:
                            os.remove(os.path.join(root, file))
                            log_and_print(
                                f"{SUCCESS} Removed orphan Vim undo file: {file}", "info"
                            )
                        except OSError as e:
                            log_and_print(
                                f"{FAILURE} Error: Failed to remove orphan Vim undo file: {e}",
                                "error",
                            )

def force_log_rotation(log_file):
    """
    Force log rotation.
    """
    log_and_print(f"{INFO} Forcing log rotation...", "info")
    try:
        subprocess.run(["sudo", "logrotate", "-f", "/etc/logrotate.conf"], check=True)
        log_and_print(f"{SUCCESS} Log rotation forced.", "info")
    except subprocess.CalledProcessError as e:
        log_and_print(
            f"{FAILURE} Error: Failed to force log rotation: {e.stderr.strip()}",
            "error",
        )

def configure_zram(log_file):
    """
    Configure ZRam for better memory management.
    """
    log_and_print(f"{INFO} Configuring ZRam for better memory management...", "info")

    if shutil.which("zramctl"):
        try:
            mem_total_output = subprocess.check_output(
                "awk '/MemTotal/ {print int($2 * 1024 * 0.25)}' /proc/meminfo",
                shell=True,
            ).strip()
            mem_total = int(mem_total_output)
            log_and_print(f"Calculated ZRam size: {mem_total} bytes", "info")

            zram_device = subprocess.check_output(
                ["sudo", "zramctl", "--find", "--size", str(mem_total)],
                text=True,
            ).strip()
            log_and_print(f"Using zram device: {zram_device}", "info")

            log_and_print(f"Setting up {zram_device} as swap...", "info")
            subprocess.run(["sudo", "mkswap", zram_device], check=True)
            subprocess.run(
                ["sudo", "swapon", zram_device, "-p", "32767"], check=True
            )

            log_and_print(
                f"{SUCCESS} ZRam configured successfully on {zram_device} with size {mem_total} bytes.",
                "info",
            )
        except subprocess.CalledProcessError as e:
            log_and_print(f"{FAILURE} Error configuring ZRam: {str(e)}", "error")
    else:
        log_and_print(f"{FAILURE} ZRam not available. Please install zramctl.", "error")

def check_zram_configuration(log_file):
    """
    Check ZRam configuration and configure if not already set.
    """
    log_and_print(f"{INFO} Checking ZRam configuration...", "info")

    try:
        zram_status = subprocess.check_output(["zramctl"], text=True).strip()

        if zram_status and "NAME" in zram_status:
            log_and_print(
                f"{SUCCESS} ZRam is configured. Current status:\n{zram_status}", "info"
            )

            swap_status = subprocess.check_output(["swapon", "--show"], text=True)
            if "/dev/zram" in swap_status:
                log_and_print(
                    f"{SUCCESS} ZRam is actively used as swap:\n{swap_status}", "info"
                )
            else:
                log_and_print(
                    f"{INFO} ZRam device exists but is not used as swap. Configuring now...",
                    "info",
                )
                configure_zram(log_file)
        else:
            log_and_print(f"{INFO} ZRam is not configured. Configuring now...", "info")
            configure_zram(log_file)

    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error while checking ZRam configuration: {e}", "error")
    except Exception as ex:
        log_and_print(f"{FAILURE} Unexpected error: {str(ex)}", "error")

def adjust_swappiness(log_file):
    """
    Adjust the swappiness value for better performance.
    """
    swappiness_value = 10
    log_and_print(f"{INFO} Adjusting swappiness to {swappiness_value}...", "info")
    try:
        subprocess.run(
            ["sudo", "sysctl", f"vm.swappiness={swappiness_value}"], check=True
        )
        log_and_print(f"{SUCCESS} Swappiness adjusted to {swappiness_value}.", "info")
    except subprocess.CalledProcessError as e:
        log_and_print(
            f"{FAILURE} Error: Failed to adjust swappiness: {e.stderr.strip()}",
            "error",
        )

def clear_system_cache(log_file):
    """
    Clear PageCache, dentries, and inodes.
    """
    log_and_print(f"{INFO} Clearing PageCache, dentries, and inodes...", "info")
    try:
        subprocess.run(
            ["sudo", "sh", "-c", "echo 3 > /proc/sys/vm/drop_caches"], check=True
        )
        log_and_print(f"{SUCCESS} System caches cleared.", "info")
    except subprocess.CalledProcessError as e:
        log_and_print(
            f"{FAILURE} Error: Failed to clear system cache: {e.stderr.strip()}",
            "error",
        )

def disable_unused_services(log_file):
    """
    Disable unused services to optimize system resources and improve security.
    """
    log_and_print(f"{INFO} Disabling unused services...", "info")
    services = [
        "bluetooth.service",
        "cups.service",
        "geoclue.service",
        "avahi-daemon.service",
        "sshd.service",
    ]

    for service in services:
        try:
            status_result = subprocess.run(
                ["systemctl", "is-active", service],
                capture_output=True,
                text=True,
            )

            if status_result.returncode == 0:
                subprocess.run(["sudo", "systemctl", "disable", "--now", service])
                log_and_print(f"{SUCCESS} {service} has been disabled and stopped.", "info")
            else:
                log_and_print(f"{INFO} {service} is already disabled.", "info")
        except Exception as e:
            log_and_print(f"{FAILURE} Error disabling {service}: {str(e)}", "error")

def check_and_restart_systemd_units(log_file):
    """
    Check and restart failed systemd units.
    """
    log_and_print(f"{INFO} Checking and restarting failed systemd units...", "info")
    try:
        units = subprocess.check_output(["systemctl", "--failed"], text=True)
        if "0 loaded units listed" in units:
            log_and_print(f"{SUCCESS} No failed systemd units.", "info")
        else:
            log_and_print(f"{INFO} Restarting failed systemd units...", "info")
            subprocess.run(["sudo", "systemctl", "reset-failed"], check=True)
            failed_units = [
                line.split()[0]
                for line in units.strip().split("\n")[1:]
                if line and not line.startswith("UNIT")
            ]
            for unit in failed_units:
                subprocess.run(["sudo", "systemctl", "restart", unit], check=True)
            log_and_print(f"{SUCCESS} Failed systemd units restarted.", "info")
    except subprocess.CalledProcessError as e:
        log_and_print(
            f"{FAILURE} Error: Failed to check or restart systemd units: {e.stderr.strip()}",
            "error",
        )

def security_audit(log_file):
    """
    Perform a security audit to identify potential vulnerabilities.
    """
    log_and_print(f"{INFO} Performing security audit...", "info")
    try:
        log_and_print(f"{INFO} Checking for open ports...", "info")
        result = subprocess.run(["sudo", "ss", "-tuln"], capture_output=True, text=True)
        if result.returncode == 0:
            open_ports = result.stdout.strip()
            logging.info("Open ports and listening services:\n" + open_ports)
            log_and_print(f"{INFO} Open ports and listening services logged.", "info")
        else:
            logging.error(result.stderr)
            log_and_print(f"{FAILURE} Error checking open ports: {result.stderr.strip()}", "error")

        lynis_path = shutil.which("lynis")
        if lynis_path:
            log_and_print(f"{INFO} Running Lynis security scan...", "info")
            lynis_cmd = ["sudo", "lynis", "audit", "system", "-Q"]
            lynis_result = subprocess.run(lynis_cmd, capture_output=True, text=True)
            if lynis_result.returncode == 0:
                logging.info("Lynis scan results:\n" + lynis_result.stdout)
                log_and_print(f"{INFO} Lynis security scan completed. Results logged.", "info")
            else:
                logging.error(lynis_result.stderr)
                log_and_print(f"{FAILURE} Error running Lynis: {lynis_result.stderr.strip()}", "error")
        else:
            log_and_print(f"{INFO} Lynis not installed. Skipping vulnerability scan.", "info")
            log_and_print(f"Install Lynis with 'sudo pacman -S lynis' to enable this feature.", "info")

        log_and_print(f"{INFO} Checking for package updates and security patches...", "info")
        update_result = subprocess.run(["sudo", "pacman", "-Syuw", "--noconfirm"], capture_output=True, text=True)
        if update_result.returncode == 0:
            logging.info(update_result.stdout)
            log_and_print(f"{SUCCESS} Package database synchronized.", "info")
            upgrade_result = subprocess.run(["checkupdates"], capture_output=True, text=True)
            if upgrade_result.returncode == 0 and upgrade_result.stdout.strip():
                updates = upgrade_result.stdout.strip()
                logging.info("Packages to update:\n" + updates)
                log_and_print(f"{WARNING} Updates are available. Please consider updating your system.", "warning")
            else:
                log_and_print(f"{SUCCESS} All packages are up to date.", "info")
        else:
            logging.error(update_result.stderr)
            log_and_print(f"{FAILURE} Error updating package database: {update_result.stderr.strip()}", "error")

    except Exception as e:
        log_and_print(f"{FAILURE} Error during security audit: {str(e)}", "error")

def manage_users_and_groups(log_file):
    """
    Manage user accounts and groups.
    """
    log_and_print(f"{INFO} Managing users and groups...", "info")
    try:
        if os.geteuid() != 0:
            log_and_print(f"{FAILURE} This function must be run as root.", "error")
            return

        print("Select operation:")
        options = [
            "1) View User's Groups",
            "2) Add User to Group",
            "3) Remove User from Group",
            "4) Apply Standard Group Preset",
            "5) Check and Enable Wheel Group in Sudoers",
            "6) Exit"
        ]
        for option in options:
            print(option)

        choice = input("Enter your choice (1-6): ").strip()

        if choice == "1":
            username = input("Enter username: ").strip()
            if username:
                try:
                    groups = subprocess.check_output(["id", "-nG", username], text=True).strip()
                    log_and_print(f"{INFO} Groups for {username}: {groups}", "info")
                except subprocess.CalledProcessError as e:
                    log_and_print(f"{FAILURE} Error retrieving groups for {username}: {e}", "error")
            else:
                log_and_print(f"{FAILURE} Username cannot be empty.", "error")

        elif choice == "2":
            username = input("Enter username: ").strip()
            if username:
                result = subprocess.run(["cut", "-d:", "-f1", "/etc/group"], capture_output=True, text=True)
                if result.returncode == 0:
                    all_groups = result.stdout.strip().split('\n')
                    selected_groups = select_items_from_list(all_groups, "Select group(s) to add user to:")
                    if selected_groups:
                        for group in selected_groups:
                            subprocess.run(["sudo", "usermod", "-aG", group, username], check=False)
                        log_and_print(f"{SUCCESS} {username} added to groups: {', '.join(selected_groups)}", "info")
                    else:
                        log_and_print(f"{INFO} No groups selected.", "info")
                else:
                    log_and_print(f"{FAILURE} Error retrieving groups: {result.stderr.strip()}", "error")
            else:
                log_and_print(f"{FAILURE} Username cannot be empty.", "error")

        elif choice == "3":
            username = input("Enter username: ").strip()
            if username:
                groups = subprocess.check_output(["id", "-nG", username], text=True).strip().split()
                if groups:
                    selected_groups = select_items_from_list(groups, "Select group(s) to remove user from:")
                    if selected_groups:
                        for group in selected_groups:
                            subprocess.run(["sudo", "gpasswd", "-d", username, group], check=False)
                        log_and_print(f"{SUCCESS} {username} removed from groups: {', '.join(selected_groups)}", "info")
                    else:
                        log_and_print(f"{INFO} No groups selected.", "info")
                else:
                    log_and_print(f"{INFO} User {username} is not a member of any groups.", "info")
            else:
                log_and_print(f"{FAILURE} Username cannot be empty.", "error")

        elif choice == "4":
            username = input("Enter username: ").strip()
            if username:
                standard_groups = ["adm", "users", "disk", "wheel", "cdrom", "audio", "video", "usb", "optical", "storage", "scanner", "lp", "network", "power"]
                for group in standard_groups:
                    subprocess.run(["sudo", "usermod", "-aG", group, username], check=False)
                log_and_print(f"{SUCCESS} Applied standard group preset to {username}.", "info")
            else:
                log_and_print(f"{FAILURE} Username cannot be empty.", "error")

        elif choice == "5":
            with open('/etc/sudoers', 'r') as sudoers_file:
                sudoers_content = sudoers_file.read()
            if '%wheel ALL=(ALL) ALL' not in sudoers_content:
                log_and_print(f"{INFO} Enabling 'wheel' group in sudoers...", "info")
                subprocess.run(['sudo', 'bash', '-c', 'echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers'], check=False)
                log_and_print(f"{SUCCESS} 'wheel' group has been enabled in sudoers.", "info")
            else:
                log_and_print(f"{INFO} 'wheel' group is already enabled in sudoers.", "info")

        elif choice == "6":
            log_and_print(f"{INFO} Exiting user and group management.", "info")
            return

        else:
            log_and_print(f"{FAILURE} Invalid choice.", "error")

    except Exception as e:
        log_and_print(f"{FAILURE} Error managing users/groups: {str(e)}", "error")

def select_items_from_list(items, prompt):
    """
    Allow the user to select items from a list.
    """
    try:
        if shutil.which('fzf'):
            fzf_command = ['fzf', '-m', '--prompt', prompt]
            result = subprocess.run(fzf_command, input='\n'.join(items), capture_output=True, text=True)
            if result.returncode == 0:
                selected_items = result.stdout.strip().split('\n')
                return selected_items
            else:
                return []
        else:
            print(prompt)
            for idx, item in enumerate(items, 1):
                print(f"{idx}) {item}")
            selections = input("Enter the numbers of the items to select (comma-separated): ").strip()
            if selections:
                indices = [int(s) - 1 for s in selections.split(',') if s.strip().isdigit()]
                selected_items = [items[i] for i in indices if 0 <= i < len(items)]
                return selected_items
            else:
                return []
    except Exception as e:
        log_and_print(f"{FAILURE} Error selecting items: {str(e)}", "error")
        return []

def configure_firewall(log_file):
    """
    Configure firewall settings using UFW.
    """
    log_and_print(f"{INFO} Configuring firewall settings...", "info")
    try:
        if not shutil.which('ufw'):
            log_and_print(f"{FAILURE} UFW is not installed. Install it with 'sudo pacman -S ufw'.", "error")
            return

        confirm_reset = prompt_with_timeout(
            "Do you want to reset UFW to default settings? [y/N]: ", timeout=15, default="n"
        ).lower()
        if confirm_reset == 'y':
            subprocess.run(['sudo', 'ufw', 'reset'], check=False)
            log_and_print(f"{INFO} UFW settings reset to default.", "info")

        subprocess.run(['sudo', 'ufw', 'default', 'deny', 'incoming'], check=False)
        subprocess.run(['sudo', 'ufw', 'default', 'allow', 'outgoing'], check=False)
        log_and_print(f"{INFO} Set default policies: deny incoming, allow outgoing.", "info")

        ssh_confirm = prompt_with_timeout(
            "Do you want to allow SSH connections? [Y/n]: ", timeout=15, default="Y"
        ).lower()
        if ssh_confirm != 'n':
            subprocess.run(['sudo', 'ufw', 'allow', 'ssh'], check=False)
            log_and_print(f"{INFO} SSH connections allowed.", "info")
        else:
            subprocess.run(['sudo', 'ufw', 'deny', 'ssh'], check=False)
            log_and_print(f"{INFO} SSH connections denied.", "info")

        subprocess.run(['sudo', 'ufw', '--force', 'enable'], check=False)
        log_and_print(f"{SUCCESS} UFW enabled.", "info")

        subprocess.run(['sudo', 'ufw', 'status', 'verbose'], check=False)

    except Exception as e:
        log_and_print(f"{FAILURE} Error configuring firewall: {str(e)}", "error")

def monitor_system_logs(log_file):
    """
    Monitor system logs for errors or warnings.
    """
    log_and_print(f"{INFO} Monitoring system logs...", "info")
    try:
        result = subprocess.run(["journalctl", "-p", "3", "-xb"], capture_output=True, text=True)
        errors = result.stdout.strip()
        if errors:
            log_and_print(f"{INFO} System errors found:", "info")
            print(errors)
            logging.info("System errors:\n" + errors)
        else:
            log_and_print(f"{SUCCESS} No system errors detected.", "info")
    except Exception as e:
        log_and_print(f"{FAILURE} Error monitoring system logs: {str(e)}", "error")

def generate_system_report(log_file):
    """
    Generate a detailed report of system information.
    """
    log_and_print(f"{INFO} Generating system information report...", "info")
    try:
        if shutil.which('neofetch'):
            subprocess.run(["neofetch"], check=False)
        else:
            log_and_print(f"{INFO} 'neofetch' is not installed. Install it with 'sudo pacman -S neofetch'.", "info")
            uname_result = subprocess.run(["uname", "-a"], capture_output=True, text=True)
            print(uname_result.stdout)
            lsb_result = subprocess.run(["lsb_release", "-a"], capture_output=True, text=True)
            print(lsb_result.stdout)

        if shutil.which('lshw'):
            log_and_print(f"{INFO} Hardware Information:", "info")
            subprocess.run(["sudo", "lshw", "-short"], check=False)
        else:
            log_and_print(f"{INFO} 'lshw' is not installed. Install it with 'sudo pacman -S lshw'.", "info")
    except Exception as e:
        log_and_print(f"{FAILURE} Error generating system report: {str(e)}", "error")

def run_all_tasks(log_file):
    """
    Run all maintenance tasks.
    """
    for key in [str(k) for k in range(1, 31)]:
        try:
            menu_options[key]()
        except KeyError as e:
            log_and_print(format_message(f"Error executing task {key}: {e}", RED), "error")

# Define menu options with partial
menu_options = {
    "1": partial(process_dep_scan_log, log_file_path),
    "2": partial(manage_cron_job, log_file_path),
    "3": partial(remove_broken_symlinks, log_file_path),
    "4": partial(clean_old_kernels, log_file_path),
    "5": partial(vacuum_journalctl, log_file_path),
    "6": partial(clear_cache, log_file_path),
    "7": partial(update_font_cache, log_file_path),
    "8": partial(clear_trash, log_file_path),
    "9": partial(optimize_databases, log_file_path),
    "10": partial(clean_package_cache, log_file_path),
    "11": partial(clean_aur_dir, log_file_path),
    "12": partial(handle_pacnew_pacsave, log_file_path),
    "13": partial(verify_installed_packages, log_file_path),
    "14": partial(check_failed_cron_jobs, log_file_path),
    "15": partial(clear_docker_images, log_file_path),
    "16": partial(clear_temp_folder, log_file_path),
    "17": partial(check_rmshit_script, log_file_path),
    "18": partial(remove_old_ssh_known_hosts, log_file_path),
    "19": partial(remove_orphan_vim_undo_files, log_file_path),
    "20": partial(force_log_rotation, log_file_path),
    "21": partial(configure_zram, log_file_path),
    "22": partial(check_zram_configuration, log_file_path),
    "23": partial(adjust_swappiness, log_file_path),
    "24": partial(clear_system_cache, log_file_path),
    "25": partial(disable_unused_services, log_file_path),
    "26": partial(check_and_restart_systemd_units, log_file_path),
    "27": partial(security_audit, log_file_path),
    "28": partial(manage_users_and_groups, log_file_path),
    "29": partial(configure_firewall, log_file_path),
    "30": partial(monitor_system_logs, log_file_path),
    "31": partial(generate_system_report, log_file_path),
    "0": partial(run_all_tasks, log_file_path),
}

# Main Menu
def main():
    """
    Display the main menu and handle user input.
    """
    while True:
        os.system("clear")
        print(f"===================================================================")
        print(f"    ================= {GREEN}// System Maintenance Menu //{NC} =================")
        print("===================================================================")
        print(f"{GREEN}1{NC}) Process Dependency Log              {GREEN}17{NC}) Clean Unnecessary Files")
        print(f"{GREEN}2{NC}) Manage Cron Jobs                   {GREEN}18{NC}) Remove Old SSH Known Hosts")
        print(f"{GREEN}3{NC}) Remove Broken Symlinks             {GREEN}19{NC}) Remove Orphan Vim Undo Files")
        print(f"{GREEN}4{NC}) Clean Old Kernels                  {GREEN}20{NC}) Force Log Rotation")
        print(f"{GREEN}5{NC}) Vacuum Journalctl                  {GREEN}21{NC}) Configure ZRam")
        print(f"{GREEN}6{NC}) Clear Cache                        {GREEN}22{NC}) Check ZRam Configuration")
        print(f"{GREEN}7{NC}) Update Font Cache                  {GREEN}23{NC}) Adjust Swappiness")
        print(f"{GREEN}8{NC}) Clear Trash                        {GREEN}24{NC}) Clear System Cache")
        print(f"{GREEN}9{NC}) Optimize Databases                 {GREEN}25{NC}) Disable Unused Services")
        print(f"{GREEN}10{NC}) Clean Package Cache               {GREEN}26{NC}) Fix Systemd Units")
        print(f"{GREEN}11{NC}) Clean AUR Directory               {GREEN}27{NC}) Perform Security Audit")
        print(f"{GREEN}12{NC}) Handle Pacnew and Pacsave Files   {GREEN}28{NC}) Manage Users and Groups")
        print(f"{GREEN}13{NC}) Verify Installed Packages         {GREEN}29{NC}) Configure Firewall")
        print(f"{GREEN}14{NC}) Check Failed Cron Jobs            {GREEN}30{NC}) Monitor System Logs")
        print(f"{GREEN}15{NC}) Clear Docker Images               {GREEN}31{NC}) Generate System Report")
        print(f"{GREEN}16{NC}) Clear Temp Folder                 {GREEN}Q{NC}) Quit")
        print(f"{GREEN}0{NC}) Run All Tasks")

        print(f"{GREEN}By your command:{NC}")

        command = prompt_with_timeout(
            "Enter your choice: ", timeout=30, default="Q"
        )

        if command:
            command = command.strip().upper()
        else:
            command = "Q"

        if command == "Q":
            break
        elif command in menu_options:
            try:
                menu_options[command]()
            except Exception as e:
                log_and_print(format_message(f"Error executing option: {e}", RED), "error")
        else:
            log_and_print(format_message("Invalid choice. Please try again.", RED), "error")

        input("Press Enter to continue...")

if __name__ == "__main__":
    main()
