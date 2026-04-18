#!/usr/bin/python3

"""
File: vacuum.py
Author: 4ndr0666
Date: 12-13-24
Desc: Arch Linux Maintenance Script
======================================== // VACUUM.PY //"""
import os
import subprocess
import sys
import select
import shutil
import time
import logging
import datetime
import pexpect
import re
import threading
import itertools
import json
import tempfile
import socket
from contextlib import contextmanager

############################
# CONFIGURABLE PATHS/LOGS #
############################

XDG_DATA_HOME = os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share"))
LOG_BASE_DIR = os.path.join(XDG_DATA_HOME, "logs")
os.makedirs(LOG_BASE_DIR, exist_ok=True)

log_file_path = os.path.join(
    LOG_BASE_DIR,
    datetime.datetime.now().strftime("%Y%m%d_%H%M%S_system_maintenance.log"),
)
logging.basicConfig(
    filename=log_file_path,
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
)

############################
# SPINNER / COLORS / UTILS #
############################

SPINNER_STYLES = {
    "dots": "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏",
    "bars": "|/-\\",
    "arrows": "←↖↑↗→↘↓↙",
}
DEFAULT_SPINNER_STYLE = SPINNER_STYLES["dots"]


@contextmanager
def spinning_spinner(symbols=DEFAULT_SPINNER_STYLE, speed=0.1):
    """
    A context manager that manages a console spinner to indicate progress.
    The spinner automatically stops when the context is exited.
    IMPORTANT: Only use this when there is no user input prompt expected.
    """
    spinner_running = threading.Event()
    spinner_running.set()
    spinner_symbols = itertools.cycle(symbols)

    def spin():
        while spinner_running.is_set():
            sys.stdout.write(next(spinner_symbols) + "\r")
            sys.stdout.flush()
            time.sleep(speed)

    spinner_thread = threading.Thread(target=spin, daemon=True)
    spinner_thread.start()

    try:
        yield
    finally:
        spinner_running.clear()
        spinner_thread.join()
        sys.stdout.write(" " * 10 + "\r")
        sys.stdout.flush()


GREEN = "\033[38;2;21;255;255m"
BOLD = "\033[1m"
RED = "\033[0;31m"
NC = "\033[0m"
SUCCESS = "✔️"
FAILURE = "❌"
INFO = "➡️"
WARNING = "⚠️"


def format_message(message, color):
    """Format a message with the given color and bold text."""
    return f"{BOLD}{color}{message}{NC}"


def log_and_print(message, level="info"):
    """Print and log a message at the specified log level."""
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
    Returns (True, stdout) on success, (False, stderr or error message) on failure.

    FIX: Original returned (False, stderr) whenever result.stderr was non-empty,
    even on rc=0. Many standard tools (pacman, find, pacman -Qi) write informational
    text to stderr on success. The returncode is the authoritative success signal;
    stderr is now logged as a warning rather than treated as a failure indicator.
    """
    try:
        result = subprocess.run(command, capture_output=True, text=True, check=True)
        logging.info(result.stdout)
        if result.stderr:
            logging.warning(result.stderr)
        return True, result.stdout.strip()
    except subprocess.CalledProcessError as e:
        stderr = e.stderr.strip() if e.stderr else (e.output.strip() if e.output else "")
        log_message = error_message or f"Command '{e.cmd}' failed with error: {stderr}"
        log_and_print(format_message(log_message, RED), "error")
        return False, log_message
    except Exception as e:
        log_message = error_message or f"Command execution failed with error: {str(e)}"
        log_and_print(format_message(log_message, RED), "error")
        return False, log_message


def prompt_with_timeout(
    prompt: str, timeout: int = 30, default: str = "Q", persistent=False
) -> str:
    """
    Prompt the user for input with a timeout and default value.
    If persistent=True, it won't time out and will wait until user response.
    """
    if persistent:
        while True:
            user_input = input(prompt).strip()
            if user_input:
                return user_input
            else:
                log_and_print(f"{INFO} Input is required. Please respond.", "info")
    else:
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


###################################
# 1. process_dep_scan_log
###################################


def process_dep_scan_log():
    """
    Reads a structured log (JSON lines) from $XDG_DATA_HOME/logs/dependency_scan.jsonl.
    Fixes permission warnings and installs missing dependencies in a single pass.
    """
    log_and_print(f"{INFO} Processing dependency scan log (JSONL) ...", "info")

    dep_scan_jsonl = os.path.join(LOG_BASE_DIR, "dependency_scan.jsonl")
    if not os.path.isfile(dep_scan_jsonl):
        log_and_print(
            f"{FAILURE} Dependency scan JSON log file not found: {dep_scan_jsonl}",
            "error",
        )
        return

    permission_fixes = []
    missing_deps = []

    try:
        with spinning_spinner():
            with open(dep_scan_jsonl, "r") as infile:
                for line in infile:
                    if not line.strip():
                        continue
                    try:
                        entry = json.loads(line)
                        issue_type = entry.get("issue_type", "")
                        target = entry.get("target", "")
                        if issue_type == "permission_warning":
                            permission_fixes.append(target)
                        elif issue_type == "missing_dependency":
                            missing_deps.append(target)
                    except json.JSONDecodeError:
                        logging.warning(
                            f"Unrecognized log line (not valid JSON): {line.strip()}"
                        )

            for file_path in set(permission_fixes):
                fix_permissions(file_path)

            if missing_deps:
                log_and_print(
                    f"{INFO} Installing missing dependencies in batch: {missing_deps}",
                    "info",
                )
                install_missing_dependency_batch(list(set(missing_deps)))

        log_and_print(f"{SUCCESS} Dependency scan log processing completed.", "info")

    except IOError as e:
        log_and_print(f"{FAILURE} Error reading dependency scan log: {e}", "error")


##########################################################
# 2. fix_permissions
##########################################################


def _get_current_user():
    """
    Resolve the effective owner username safely across tty and non-tty contexts.

    FIX: os.getlogin() raises OSError when there is no controlling terminal
    (cron, systemd service, sudo without tty). Use pwd.getpwuid(os.getuid())
    as the authoritative fallback — it works in all execution contexts.
    """
    import pwd
    # If running under sudo, prefer the original user for ownership assignment.
    sudo_user = os.environ.get("SUDO_USER")
    if sudo_user:
        return sudo_user
    try:
        return pwd.getpwuid(os.getuid()).pw_name
    except (KeyError, OSError):
        return str(os.getuid())


def fix_permissions(
    file_path, file_mode=None, dir_mode=None, owner=None, group=None, recursive=False
):
    """
    Fix the permissions for the given file or directory with possible recursion and ownership checks.
    """
    default_file_mode = 0o644
    default_dir_mode = 0o755
    file_mode = file_mode if file_mode else default_file_mode
    dir_mode = dir_mode if dir_mode else default_dir_mode

    current_user = _get_current_user()
    owner = owner if owner else current_user
    group = group if group else current_user

    try:
        if os.path.isfile(file_path):
            os.chmod(file_path, file_mode)
            shutil.chown(file_path, user=owner, group=group)
            log_and_print(f"{INFO} Fixed permissions for file: {file_path}", "info")
        elif os.path.isdir(file_path):
            os.chmod(file_path, dir_mode)
            shutil.chown(file_path, user=owner, group=group)
            log_and_print(
                f"{INFO} Fixed permissions for directory: {file_path}", "info"
            )
            if recursive:
                for root, dirs, files in os.walk(file_path):
                    for d in dirs:
                        path_d = os.path.join(root, d)
                        os.chmod(path_d, dir_mode)
                        shutil.chown(path_d, user=owner, group=group)
                    for f in files:
                        path_f = os.path.join(root, f)
                        os.chmod(path_f, file_mode)
                        shutil.chown(path_f, user=owner, group=group)
        else:
            log_and_print(f"{WARNING} Not a file or directory: {file_path}", "warning")

    except OSError as e:
        log_and_print(
            f"{FAILURE} Error fixing permissions for {file_path}: {e}", "error"
        )


#####################################################
# 3. install_missing_dependency — batch approach
#####################################################


def install_missing_dependency_batch(dependencies):
    """
    Batch install missing dependencies using pacman.
    """
    log_and_print(
        f"{INFO} Attempting to install these missing dependencies: {dependencies}",
        "info",
    )
    to_install = []
    for dep in dependencies:
        success, _ = execute_command(["pacman", "-Qi", dep])
        if success:
            log_and_print(f"{INFO} Dependency {dep} is already installed.", "info")
        else:
            to_install.append(dep)

    if to_install:
        success, result_output = execute_command(
            ["sudo", "pacman", "-Sy", "--noconfirm"] + to_install
        )
        if success:
            log_and_print(
                f"{SUCCESS} Successfully installed missing dependencies: {to_install}",
                "info",
            )
        else:
            log_and_print(
                f"{FAILURE} Failed to install missing dependencies: {to_install}",
                "error",
            )
    else:
        log_and_print(f"{INFO} All dependencies are already installed.", "info")


def install_missing_dependency(dependency):
    """Kept for backward-compat; delegates to the batch approach."""
    install_missing_dependency_batch([dependency])


##################################
# 4. manage_cron_job
##################################


def manage_cron_job():
    """
    Manage system cron jobs: display existing entries, show failed cron logs,
    then allow addition or deletion of jobs.

    FIX: journalctl -u cron changed to -u cronie, which is the correct systemd
    unit name for the cronie daemon on Arch Linux. 'cron' as a unit name matches
    nothing on a standard Arch installation, causing silent empty results.
    """
    log_and_print(f"{INFO} Managing system cron jobs...", "info")

    existing_crons = []
    try:
        result = subprocess.run(
            ["sudo", "crontab", "-l"], capture_output=True, text=True, check=True
        )
        raw_crons = result.stdout.strip().split("\n")
        existing_crons = [c for c in raw_crons if c]
    except subprocess.CalledProcessError as e:
        if e.returncode == 1 and "no crontab for" in e.stderr.lower():
            existing_crons = []
        else:
            log_and_print(
                f"{FAILURE} Error reading system cron: {e.stderr.strip()}", "error"
            )

    if existing_crons:
        log_and_print("Existing system cron jobs:", "info")
        for i, cron in enumerate(existing_crons, start=1):
            log_and_print(f"{i}. {cron}", "info")
    else:
        log_and_print(f"{INFO} No existing cron jobs found.", "info")

    # FIX: Use 'cronie' — the correct Arch Linux systemd unit name for cronie.
    try:
        cron_logs = subprocess.check_output(
            ["journalctl", "-u", "cronie", "--since", "24 hours ago"],
            text=True,
            stderr=subprocess.DEVNULL,
        )
        failed_jobs = [
            line for line in cron_logs.split("\n") if "FAILED" in line.upper()
        ]
        if failed_jobs:
            log_and_print(
                f"{WARNING} Failed cron jobs detected in last 24 hours:", "warning"
            )
            for job in failed_jobs:
                log_and_print(f"{FAILURE} {job}", "error")
        else:
            log_and_print(f"{INFO} No failed cron jobs in the last 24 hours.", "info")
    except subprocess.CalledProcessError:
        log_and_print(
            f"{INFO} No failed cron jobs detected or logs not accessible.", "info"
        )

    choice = prompt_with_timeout(
        "Do you want to (a)dd a new cron job or (d)elete an existing one? (a/d/skip): ",
        persistent=True,
    ).lower()

    if choice == "a":
        new_cron = input("Enter the new cron job entry: ").strip()
        if new_cron:
            existing_crons.append(new_cron)
            new_crons = "\n".join(existing_crons) + "\n"
            update_cron_jobs(new_crons)
            log_and_print(f"{SUCCESS} New cron job added successfully.", "info")
        else:
            log_and_print(
                f"{FAILURE} No cron job entry provided. Aborting addition.", "error"
            )

    elif choice == "d":
        if not existing_crons:
            log_and_print(f"{INFO} No cron jobs to delete.", "info")
            return
        cron_to_delete = prompt_with_timeout(
            "Enter the number of the cron job entry to delete: ", persistent=True
        )
        if cron_to_delete.isdigit():
            idx = int(cron_to_delete)
            if 1 <= idx <= len(existing_crons):
                del existing_crons[idx - 1]
                new_crons = "\n".join(existing_crons) + "\n" if existing_crons else ""
                update_cron_jobs(new_crons)
                log_and_print(f"{SUCCESS} Cron job deleted successfully.", "info")
            else:
                log_and_print(f"{FAILURE} Invalid selection. No changes made.", "error")
        else:
            log_and_print(f"{FAILURE} Invalid input. Please enter a number.", "error")

    else:
        log_and_print(f"{INFO} No changes made to cron jobs.", "info")


def update_cron_jobs(new_crons):
    """Update the system cron jobs with the new entries."""
    with tempfile.NamedTemporaryFile(mode="w", delete=False) as temp_file:
        temp_file.write(new_crons)
        temp_file_path = temp_file.name
    try:
        subprocess.run(["sudo", "crontab", temp_file_path], check=True)
    except Exception as e:
        log_and_print(f"{FAILURE} Error updating cron jobs: {str(e)}", "error")
    finally:
        if os.path.exists(temp_file_path):
            os.remove(temp_file_path)


##########################
# 5. remove_broken_symlinks
##########################


def remove_broken_symlinks():
    """
    Finds and removes broken symbolic links system-wide.
    Bulk listing with a single persistent confirmation prompt.
    """
    log_and_print(f"{INFO} Searching for broken symbolic links...", "info")
    search_path = "/"
    broken_links = []

    try:
        command = ["find", search_path, "-xtype", "l"]
        result = subprocess.run(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            check=True,
        )
        broken_links = [
            lnk for lnk in result.stdout.strip().split("\n") if lnk.strip()
        ]

        if not broken_links:
            log_and_print(f"{SUCCESS} No broken symbolic links found.", "info")
            return

        log_and_print(
            f"{INFO} Found {len(broken_links)} broken symbolic links:", "info"
        )
        for link in broken_links:
            print(link)

        confirm = prompt_with_timeout(
            "Do you want to remove these broken symbolic links? [y/N]: ",
            persistent=True,
        ).lower()

        if confirm != "y":
            log_and_print(
                f"{INFO} Broken symbolic link removal aborted by user.", "info"
            )
            return

        with spinning_spinner():
            for link in broken_links:
                try:
                    os.remove(link)
                    logging.info(f"Removed broken symlink: {link}")
                except Exception as e:
                    logging.error(f"Failed to remove {link}: {str(e)}")

        log_and_print(f"{SUCCESS} Broken symbolic links removed.", "info")

    except subprocess.CalledProcessError as e:
        log_and_print(
            f"{FAILURE} Error searching for broken symbolic links: {str(e)}", "error"
        )


###############################################
# 6. clean_old_kernels
###############################################


def clean_old_kernels():
    """
    Clean old kernel versions not in use. Retains the currently running kernel
    and removes others via pacman if traceable.
    """
    log_and_print(f"{INFO} Scanning for old kernel modules to clean...", "info")
    current_kernel = os.uname().release
    modules_path = "/usr/lib/modules"

    if not os.path.isdir(modules_path):
        log_and_print(f"{FAILURE} Modules directory not found: {modules_path}", "error")
        return

    try:
        installed_versions = [
            d
            for d in os.listdir(modules_path)
            if os.path.isdir(os.path.join(modules_path, d))
            and re.match(r"^\d+\.\d+", d)
        ]
        old_versions = [v for v in installed_versions if v != current_kernel]

        if not old_versions:
            log_and_print(f"{SUCCESS} No old kernel modules found to clean.", "info")
            return

        log_and_print(
            f"{INFO} Found old kernel module versions: {old_versions}", "info"
        )

        confirm = prompt_with_timeout(
            f"Do you want to remove these old kernels: {old_versions}? [y/N]: ",
            persistent=True,
        ).lower()

        if confirm != "y":
            log_and_print(f"{INFO} Kernel cleanup aborted by user.", "info")
            return

        with spinning_spinner():
            for version in old_versions:
                module_path = os.path.join(modules_path, version)
                try:
                    result = subprocess.run(
                        ["pacman", "-Qo", module_path],
                        capture_output=True,
                        text=True,
                        check=True,
                    )
                    pkg_line = result.stdout.strip()
                    pkg_name = pkg_line.split(" is owned by ")[-1].split()[0]
                    log_and_print(
                        f"{INFO} Removing kernel package: {pkg_name} (version: {version})",
                        "info",
                    )

                    remove_result = subprocess.run(
                        ["sudo", "pacman", "-Rns", "--noconfirm", pkg_name],
                        capture_output=True,
                        text=True,
                    )

                    if remove_result.returncode == 0:
                        log_and_print(
                            f"{SUCCESS} Removed old kernel package: {pkg_name}", "info"
                        )
                    else:
                        log_and_print(
                            f"{FAILURE} Failed to remove package {pkg_name}. Attempting manual cleanup.",
                            "error",
                        )
                        shutil.rmtree(module_path, ignore_errors=True)
                        log_and_print(
                            f"{WARNING} Manually removed kernel module: {version}",
                            "warning",
                        )

                except subprocess.CalledProcessError:
                    log_and_print(
                        f"{WARNING} Kernel version {version} not owned by any package. Removing manually...",
                        "warning",
                    )
                    shutil.rmtree(module_path, ignore_errors=True)
                    log_and_print(
                        f"{SUCCESS} Removed orphaned kernel module: {version}", "info"
                    )

    except Exception as e:
        log_and_print(f"{FAILURE} Error during kernel cleanup: {str(e)}", "error")


################################
# 7. vacuum_journalctl
################################


def vacuum_journalctl(retention="1d"):
    """Vacuum journalctl logs older than 'retention' (default '1d')."""
    log_and_print(f"{INFO} Vacuuming journalctl logs older than {retention}...", "info")
    with spinning_spinner():
        try:
            result = subprocess.run(
                ["sudo", "journalctl", f"--vacuum-time={retention}"],
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


######################################
# 8. clear_cache
######################################


def clear_cache():
    """
    Unified with clean_package_cache(). Retained in the menu (option 6) as a
    named shortcut; delegates entirely to clean_package_cache().
    Note: 'DEPRECATED' label removed — the function is live and operational.
    """
    log_and_print(f"{INFO} Clearing user package cache (unified) ...", "info")
    clean_package_cache()


##############################
# 9. update_font_cache
##############################


def update_font_cache():
    """Update the font cache, logging success or failure."""
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


##########################
# 10. clear_trash
##########################


def clear_trash():
    """
    Clear trash for all users if possible.
    Enumerates /home/*/.local/share/Trash and /root/.local/share/Trash.
    """
    trash_dirs = []
    home_base = "/home"
    if os.path.isdir(home_base):
        for username in os.listdir(home_base):
            user_trash = os.path.join(home_base, username, ".local/share/Trash")
            if os.path.exists(user_trash):
                trash_dirs.append(user_trash)
    root_trash = "/root/.local/share/Trash"
    if os.path.exists(root_trash):
        trash_dirs.append(root_trash)

    if not trash_dirs:
        log_and_print(f"{INFO} No trash directories found.", "info")
        return

    with spinning_spinner():
        for trash_dir in trash_dirs:
            log_and_print(f"{INFO} Clearing trash in {trash_dir}...", "info")
            try:
                for item in os.listdir(trash_dir):
                    item_path = os.path.join(trash_dir, item)
                    if os.path.isfile(item_path) or os.path.islink(item_path):
                        os.unlink(item_path)
                    elif os.path.isdir(item_path):
                        shutil.rmtree(item_path)
                log_and_print(f"{SUCCESS} Trash cleared for {trash_dir}.", "info")
            except Exception as e:
                log_and_print(
                    f"{FAILURE} Error clearing trash {trash_dir}: {str(e)}", "error"
                )


###############################
# 11. optimize_databases
###############################


def optimize_databases(skips=None):
    """
    Optimize system databases, logging success or failure for each step.
    :param skips: optional list of step IDs to skip
    """
    if not skips:
        skips = []
    log_and_print(f"{INFO} Optimizing system databases (skips={skips})...", "info")

    def run_command(command, success_message, failure_message, skip_id=None):
        if skip_id and skip_id in skips:
            log_and_print(f"{WARNING} Skipping step: {skip_id}", "warning")
            return
        try:
            subprocess.run(command, check=True, capture_output=True, text=True)
            log_and_print(f"{SUCCESS} {success_message}", "info")
        except subprocess.CalledProcessError as e:
            log_and_print(f"{FAILURE} {failure_message}: {e.stderr.strip()}", "error")

    with spinning_spinner():
        try:
            run_command(
                ["sudo", "updatedb"],
                "mlocate database updated.",
                "Failed to update mlocate database",
                skip_id="mlocate",
            )
            run_command(
                ["sudo", "pkgfile", "-u"],
                "pkgfile database updated.",
                "Failed to update pkgfile database",
                skip_id="pkgfile",
            )
            run_command(
                ["sudo", "pacman-db-upgrade"],
                "pacman database upgraded.",
                "Failed to upgrade pacman database",
                skip_id="pacman-db",
            )
            run_command(
                ["sudo", "pacman", "-Sc", "--noconfirm"],
                "Package cache cleaned.",
                "Failed to clean package cache",
                skip_id="pacman-cache",
            )
            run_command(
                ["sync"],
                "Filesystem changes synced.",
                "Failed to sync filesystem changes",
                skip_id="sync",
            )
            run_command(
                ["sudo", "pacman-key", "--refresh-keys"],
                "Keys refreshed.",
                "Failed to refresh keys",
                skip_id="pacman-key",
            )
            run_command(
                ["sudo", "pacman-key", "--populate"],
                "Keys populated.",
                "Failed to populate keys",
                skip_id="pacman-key",
            )
            run_command(
                ["sudo", "pacman-key", "--updatedb"],
                "Trust database updated.",
                "Failed to update trust database",
                skip_id="pacman-key",
            )
            run_command(
                ["sudo", "pacman", "-Syy"],
                "Package list refreshed.",
                "Failed to refresh package list",
                skip_id="pacman-sync",
            )
            log_and_print(f"{SUCCESS} System databases optimized.", "info")
        except Exception as e:
            log_and_print(
                f"{FAILURE} Unexpected error during database optimization: {str(e)}",
                "error",
            )


############################
# 12. clean_package_cache
############################


def clean_package_cache(retain_versions=2):
    """
    Clean the package cache using paccache.
    Provide advanced retention options (retain_versions).
    """
    log_and_print(
        f"{INFO} Cleaning package cache (retain_versions={retain_versions}) ...", "info"
    )
    try:
        if is_interactive():
            confirm = prompt_with_timeout(
                "Do you want to proceed with cleaning the package cache? [Y/n]: ",
                timeout=15,
                default="Y",
            )
            confirm = (confirm or "y").strip().lower()
            if confirm != "y":
                log_and_print(f"{INFO} Package cache cleaning aborted by user.", "info")
                return
        else:
            log_and_print(
                f"{INFO} Running in non-interactive mode. Proceeding with cleaning.",
                "info",
            )

        cache_dir = "/var/cache/pacman/pkg/"
        temp_files = [
            f
            for f in os.listdir(cache_dir)
            if f.endswith(".aria2") or f.startswith("download-")
        ]
        for temp_file in temp_files:
            temp_file_path = os.path.join(cache_dir, temp_file)
            if os.path.isfile(temp_file_path):
                os.remove(temp_file_path)
                logging.info(f"Removed temporary file: {temp_file_path}")

        command = ["sudo", "paccache", f"-rk{retain_versions}"]
        result = subprocess.run(command, capture_output=True, text=True)
        if result.returncode == 0:
            logging.info(result.stdout)
            log_and_print(
                f"{SUCCESS} Package cache cleaned with retain_versions={retain_versions}.",
                "info",
            )
        else:
            logging.error(result.stderr)
            log_and_print(
                f"{FAILURE} Error cleaning package cache: {result.stderr.strip()}",
                "error",
            )
    except Exception as e:
        log_and_print(f"{FAILURE} Error cleaning package cache: {str(e)}", "error")


##############################
# 13. clean_aur_dir
##############################


def clean_aur_dir(aur_dir=None):
    """
    Clean the AUR directory, deleting only uninstalled or old versions of packages.
    Also removes old source directories if they differ from installed versions.

    FIX: Original used os.chdir(aur_dir) which is a process-global side effect —
    every subsequent function that relies on CWD would see the wrong directory.
    Replaced with os.listdir(aur_dir) and explicit absolute paths throughout.

    FIX: Default path had a double slash ('/home/andro/.local/cache/yay//').
    Corrected to single slash and normalised with os.path.normpath().
    """
    log_and_print(f"{INFO} Cleaning AUR directory...", "info")
    if not aur_dir:
        aur_dir = os.path.normpath(
            os.path.expanduser("/home/andro/.local/cache/yay")
        )

    with spinning_spinner():
        try:
            if not os.path.isdir(aur_dir):
                log_and_print(
                    f"{FAILURE} The specified path is not a directory: {aur_dir}",
                    "error",
                )
                return

            pkgname_regex = re.compile(
                r"(?P<pkgname>.*?)-(?P<pkgver>[^-]+)-(?P<arch>x86_64|any|i686)\.pkg\.tar\.(xz|zst|gz|bz2|lrz|lzo|lz4|lz)$"
            )
            files = {}
            for f in os.listdir(aur_dir):
                full_path = os.path.join(aur_dir, f)
                if not os.path.isfile(full_path):
                    continue
                match = pkgname_regex.match(f)
                if match:
                    files[f] = match.groupdict()

            installed_packages = {}
            try:
                expac_data = subprocess.check_output(
                    ["expac", "-Qs", "%n %v"], universal_newlines=True
                ).splitlines()
                for line in expac_data:
                    parts = line.split()
                    if len(parts) >= 2:
                        installed_packages[parts[0]] = parts[1]
            except subprocess.CalledProcessError as e:
                log_and_print(
                    f"{FAILURE} expac not installed or error running expac: {e.stderr}",
                    "error",
                )
                return

            to_remove = []
            for f, file_info in files.items():
                pkgname = file_info["pkgname"]
                pkgver = file_info["pkgver"]
                if (
                    pkgname not in installed_packages
                    or pkgver != installed_packages[pkgname]
                ):
                    log_and_print(f"{INFO} Deleting old AUR package file: {f}", "info")
                    to_remove.append(f)

            for f in to_remove:
                try:
                    os.remove(os.path.join(aur_dir, f))
                except OSError as e:
                    log_and_print(f"{FAILURE} Error deleting file {f}: {e}", "error")

            for item in os.listdir(aur_dir):
                item_path = os.path.join(aur_dir, item)
                if os.path.isdir(item_path):
                    if item not in installed_packages:
                        confirm = prompt_with_timeout(
                            f"Remove old AUR source directory '{item}'? [y/N]: ",
                            persistent=True,
                        ).lower()
                        if confirm == "y":
                            shutil.rmtree(item_path, ignore_errors=True)
                            log_and_print(
                                f"{INFO} Deleted source directory: {item}", "info"
                            )

            log_and_print(f"{SUCCESS} AUR directory cleaned.", "info")
        except subprocess.CalledProcessError as e:
            log_and_print(
                f"{FAILURE} Error: Failed to clean AUR directory: {e.stderr.strip()}",
                "error",
            )


#####################################
# 14. handle_pacnew_pacsave
#####################################


def handle_pacnew_pacsave():
    """
    Automatically handle .pacnew and .pacsave files with single-character prompts:
    - pacnew: (m)erge, (r)eplace, (d)elete, (s)kip
    - pacsave: (R)estore, (d)elete, (s)kip

    FIX: Original wrapped the entire function body — including all interactive
    prompt_with_timeout() calls — inside a spinning_spinner() context manager.
    The spinner's background thread writes to stdout continuously while the
    terminal is waiting for user input, causing garbled output and making the
    prompt unreadable. The spinner is now used only for the initial subprocess
    discovery phase (find commands) where no input is expected; all interactive
    prompt loops execute outside it.
    """
    log_and_print(f"{INFO} Handling .pacnew and .pacsave files...", "info")

    # Discovery phase only — no interactive prompts inside the spinner.
    pacnew_files = []
    pacsave_files = []
    try:
        with spinning_spinner():
            pacnew_files = subprocess.check_output(
                ["sudo", "find", "/etc", "-type", "f", "-name", "*.pacnew"],
                text=True,
            ).splitlines()
            pacsave_files = subprocess.check_output(
                ["sudo", "find", "/etc", "-type", "f", "-name", "*.pacsave"],
                text=True,
            ).splitlines()
            pacnew_files = [f for f in pacnew_files if f.strip()]
            pacsave_files = [f for f in pacsave_files if f.strip()]
    except subprocess.CalledProcessError as e:
        log_and_print(
            f"{FAILURE} Error finding .pacnew/.pacsave files: {e.stderr.strip()}",
            "error",
        )
        return
    except Exception as ex:
        log_and_print(f"{FAILURE} Unexpected error during discovery: {str(ex)}", "error")
        return

    # Interactive phase — spinner is stopped, terminal is clean.
    actions_summary = []

    if pacnew_files:
        log_and_print(f"{INFO} Found .pacnew files.", "info")
        for file in pacnew_files:
            print(f".pacnew file: {file}")
        for file in pacnew_files:
            action = prompt_with_timeout(
                f"File: {file}\n(m)erge, (r)eplace, (d)elete, (s)kip? ",
                persistent=True,
            ).lower()
            if action == "m":
                log_and_print(
                    f"{INFO} Merging not implemented. Skipping {file}.", "info"
                )
                actions_summary.append(f"Skipped merging .pacnew file: {file}")
            elif action == "r":
                original_file = file.replace(".pacnew", "")
                backup_file = original_file + ".bak"
                try:
                    if os.path.exists(original_file):
                        shutil.copy2(original_file, backup_file)
                        actions_summary.append(
                            f"Backed up original file to {backup_file}"
                        )
                    shutil.copyfile(file, original_file)
                    os.remove(file)
                    actions_summary.append(f"Replaced with .pacnew file: {file}")
                except Exception as ex:
                    log_and_print(
                        f"{FAILURE} Error replacing file: {ex}", "error"
                    )
                    actions_summary.append(f"Failed replace for: {file}")
            elif action == "d":
                try:
                    os.remove(file)
                    actions_summary.append(f"Removed .pacnew file: {file}")
                except Exception as ex:
                    log_and_print(
                        f"{FAILURE} Error removing file: {ex}", "error"
                    )
                    actions_summary.append(f"Failed removal: {file}")
            else:
                actions_summary.append(f"Skipped .pacnew file: {file}")

    if pacsave_files:
        log_and_print(f"{INFO} Found .pacsave files.", "info")
        for file in pacsave_files:
            print(f".pacsave file: {file}")
        for file in pacsave_files:
            action = prompt_with_timeout(
                f"File: {file}\n(R)estore, (d)elete, (s)kip? ", persistent=True
            ).lower()
            if action == "r":
                original_file = file.replace(".pacsave", "")
                backup_file = original_file + ".bak"
                try:
                    if os.path.exists(original_file):
                        shutil.copy2(original_file, backup_file)
                        actions_summary.append(
                            f"Backed up original file to {backup_file}"
                        )
                    shutil.copyfile(file, original_file)
                    os.remove(file)
                    actions_summary.append(f"Restored from .pacsave file: {file}")
                except Exception as ex:
                    log_and_print(
                        f"{FAILURE} Error restoring file: {ex}", "error"
                    )
                    actions_summary.append(f"Failed restore: {file}")
            elif action == "d":
                try:
                    os.remove(file)
                    actions_summary.append(f"Removed .pacsave file: {file}")
                except Exception as ex:
                    log_and_print(
                        f"{FAILURE} Error removing file: {ex}", "error"
                    )
                    actions_summary.append(f"Failed removal: {file}")
            else:
                actions_summary.append(f"Skipped .pacsave file: {file}")

    if actions_summary:
        log_and_print(f"{INFO} Summary of actions taken:", "info")
        for action in actions_summary:
            log_and_print(f"{INFO} {action}", "info")
    else:
        log_and_print(f"{INFO} No .pacnew or .pacsave files found.", "info")


##############################################
# 15. verify_installed_packages
##############################################


def verify_installed_packages():
    """
    Verify installed packages for missing files and automatically reinstall them
    in batch. Distinguishes between official and AUR packages.
    Outputs a missing_dependency_pkglist.txt for user reference.
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
            result = subprocess.run(command, capture_output=True, text=True)
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
            log_and_print(
                f"{SUCCESS} No packages with missing files found.", "info"
            )
            return

        logging.info("Packages with missing files:\n" + "\n".join(details))

        log_and_print(
            f"{INFO} Found {len(missing_packages)} packages with missing files. Details logged.",
            "info",
        )

        pkglist_path = os.path.join(LOG_BASE_DIR, "missing_dependency_pkglist.txt")
        try:
            with open(pkglist_path, "w") as f:
                for pkg in missing_packages:
                    f.write(pkg + "\n")
            log_and_print(
                f"{SUCCESS} Missing packages listed in: {pkglist_path}", "info"
            )
        except IOError as e:
            log_and_print(f"{FAILURE} Error writing pkglist: {str(e)}", "error")

        confirm = prompt_with_timeout(
            "Do you want to reinstall these packages to restore missing files? [y/N]: ",
            persistent=True,
        ).lower()

        if confirm != "y":
            log_and_print(f"{INFO} Reinstallation aborted by user.", "info")
            return

        log_and_print(f"{INFO} Updating keyrings before reinstallation...", "info")
        keyring_update = subprocess.run(
            [
                "sudo",
                "pacman",
                "-Sy",
                "archlinux-keyring",
                "chaotic-keyring",
                "--noconfirm",
            ],
            capture_output=True,
            text=True,
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
            if is_official_package(pkg):
                official_packages.append(pkg)
            else:
                aur_packages.append(pkg)

        if official_packages:
            log_and_print(
                f"{INFO} Reinstalling official packages in batch: {official_packages}",
                "info",
            )
            reinstall_packages_pexpect(official_packages)

        if aur_packages:
            if aur_helper:
                log_and_print(
                    f"{INFO} Reinstalling AUR packages in batch: {aur_packages}",
                    "info",
                )
                reinstall_aur_packages(aur_packages, aur_helper)
            else:
                log_and_print(
                    f"{FAILURE} AUR packages detected but no AUR helper found.",
                    "error",
                )
                log_and_print(
                    "Please install an AUR helper like 'yay' or 'paru'.", "error"
                )

        log_and_print(
            f"{SUCCESS} Package verification and reinstallation completed.", "info"
        )

    except Exception as e:
        log_and_print(f"{FAILURE} Unexpected error: {str(e)}", "error")


def detect_aur_helper():
    """Detect available AUR helper with memoization."""
    if hasattr(detect_aur_helper, "_cached_helper"):
        return detect_aur_helper._cached_helper

    aur_helpers = ["yay", "paru", "trizen"]
    found_helper = None
    for helper in aur_helpers:
        if shutil.which(helper):
            log_and_print(f"{INFO} AUR helper detected: {helper}", "info")
            found_helper = helper
            break
    detect_aur_helper._cached_helper = found_helper
    return found_helper


def is_official_package(package):
    """
    Check if a package is in official repos by running 'pacman -Si'.
    If it fails, we assume AUR or non-existent.
    """
    result = subprocess.run(["pacman", "-Si", package], capture_output=True, text=True)
    return result.returncode == 0 and "Repository" in result.stdout


###########################################
# 16. reinstall_aur_packages
###########################################


def reinstall_aur_packages(packages, aur_helper):
    """
    Reinstall AUR packages in batch using pexpect for automation.

    FIX: Original assigned an open() file handle to child.logfile but never
    closed it, leaking the file descriptor regardless of success or failure.
    The handle is now tracked explicitly and closed in a finally block.
    """
    if not packages:
        return
    combined = " ".join(packages)
    log_and_print(
        f"{INFO} Reinstalling AUR packages with {aur_helper}: {combined}", "info"
    )
    command = f"{aur_helper} -S {combined} --noconfirm"
    child = pexpect.spawn(command, encoding="utf-8", timeout=600)

    log_fh = open(log_file_path, "a")
    try:
        child.logfile = log_fh
        while True:
            index = child.expect(
                [
                    pexpect.EOF,
                    r":: Import PGP key .* \[Y/n\]",
                    r":: Replace .* \[Y/n\]",
                    r":: Proceed with installation\? \[Y/n\]",
                    r":: (.*) exists in filesystem",
                    r"error: .*",
                ]
            )
            if index == 0:
                break
            elif index == 1:
                child.sendline("y")
            elif index == 2:
                child.sendline("y")
            elif index == 3:
                child.sendline("y")
            elif index == 4:
                child.sendline("y")
            elif index == 5:
                error_msg = child.after.strip()
                logging.error(error_msg)
                handle_pacman_errors(error_msg)
                break

        child.expect(pexpect.EOF)
        child.close()
        if child.exitstatus == 0:
            log_and_print(
                f"{SUCCESS} AUR packages reinstalled successfully: {combined}", "info"
            )
        else:
            log_and_print(
                f"{FAILURE} Failed to reinstall some AUR packages: {combined}", "error"
            )
    except Exception as e:
        log_and_print(f"{FAILURE} Error reinstalling AUR packages: {str(e)}", "error")
    finally:
        log_fh.close()


############################################
# 17. reinstall_packages_pexpect
############################################


def reinstall_packages_pexpect(packages, max_retries=3):
    """
    Reinstall a list of official packages using pexpect, in one go, with retry.

    FIX: Original opened a log file handle inside the inner closure run_reinstall_once()
    and assigned it to child.logfile without closing it — a file descriptor leak on
    every call including failure paths and retries. The handle is now managed with
    an explicit finally block inside the closure.
    """
    if not packages:
        return
    package_line = " ".join(packages)
    log_and_print(
        f"{INFO} Reinstalling official packages in batch: {package_line}", "info"
    )

    prompts = {
        "IMPORT_PGP": r":: Import PGP key .* \[Y/n\]",
        "REPLACE": r":: Replace .* \[Y/n\]",
        "PROCEED": r":: Proceed with installation\? \[Y/n\]",
        "FILE_EXISTS": r":: (.*) exists in filesystem",
        "ERROR": r"error: .*",
    }

    def run_reinstall_once(pkgs):
        command = f"sudo pacman -S {pkgs} --noconfirm --needed"
        child = pexpect.spawn(command, encoding="utf-8", timeout=300)
        log_fh = open(log_file_path, "a")
        try:
            child.logfile = log_fh
            while True:
                index = child.expect(
                    [
                        pexpect.EOF,
                        prompts["IMPORT_PGP"],
                        prompts["REPLACE"],
                        prompts["PROCEED"],
                        prompts["FILE_EXISTS"],
                        prompts["ERROR"],
                    ]
                )
                if index == 0:
                    break
                elif index == 1:
                    child.sendline("y")
                elif index == 2:
                    child.sendline("y")
                elif index == 3:
                    child.sendline("y")
                elif index == 4:
                    child.sendline("y")
                elif index == 5:
                    error_msg = child.after.strip()
                    logging.error(error_msg)
                    handle_pacman_errors(error_msg)
                    break

            child.expect(pexpect.EOF)
            child.close()
            return child.exitstatus
        except Exception as e:
            logging.error(str(e))
            return 1
        finally:
            log_fh.close()

    success = False
    retries = 0
    while not success and retries < max_retries:
        exit_code = run_reinstall_once(package_line)
        if exit_code == 0:
            success = True
            log_and_print(
                f"{SUCCESS} Packages reinstalled successfully: {package_line}", "info"
            )
        else:
            retries += 1
            log_and_print(
                f"{FAILURE} Attempt {retries}/{max_retries} failed. Retrying...",
                "error",
            )

    if not success:
        log_and_print(
            f"{FAILURE} Failed to reinstall packages after {max_retries} attempts: {package_line}",
            "error",
        )


################################
# 18. handle_pacman_errors
################################


def handle_pacman_errors(error_msg):
    """Handle common pacman error patterns with targeted remediation."""
    if (
        "key could not be looked up remotely" in error_msg
        or "signature is unknown trust" in error_msg
    ):
        log_and_print(f"{INFO} Keyring issue detected. Updating keyrings...", "info")
        subprocess.run(
            [
                "sudo",
                "pacman",
                "-Sy",
                "archlinux-keyring",
                "chaotic-keyring",
                "--noconfirm",
            ],
            capture_output=True,
            text=True,
        )

    if "exists in filesystem" in error_msg:
        files = re.findall(r"[\s]([^\s]+) exists in filesystem", error_msg)
        if files:
            overwrite_files = ",".join(files)
            log_and_print(
                f"{INFO} Overwriting conflicting files: {overwrite_files}", "info"
            )
            subprocess.run(
                [
                    "sudo",
                    "pacman",
                    "-S",
                    f"--overwrite={overwrite_files}",
                    "--noconfirm",
                ],
                capture_output=True,
                text=True,
            )

    if "error: duplicated database entry" in error_msg:
        duplicated_entries = re.findall(
            r"error: duplicated database entry '([^']+)'", error_msg
        )
        if duplicated_entries:
            for entry in duplicated_entries:
                log_and_print(f"{INFO} Removing duplicated entry: {entry}", "info")
                subprocess.run(
                    ["sudo", "pacman", "-Rdd", entry, "--noconfirm"],
                    capture_output=True,
                    text=True,
                )

    if "conflicting files" in error_msg and "and exists in filesystem" in error_msg:
        conflict_files = re.findall(r"conflicting files: (.*?)\n", error_msg, re.DOTALL)
        if conflict_files:
            merged_conflicts = ",".join(conflict_files)
            subprocess.run(
                [
                    "sudo",
                    "pacman",
                    "-S",
                    f"--overwrite={merged_conflicts}",
                    "--noconfirm",
                ],
                check=False,
            )


############################
# 19. check_failed_cron_jobs
############################


def check_failed_cron_jobs(days_back=1):
    """
    Check for failed cron jobs from 'days_back' days ago.

    FIX: Changed journalctl unit from 'cron' to 'cronie'. On Arch Linux the
    cronie daemon registers with systemd as 'cronie', not 'cron'. Using 'cron'
    produced empty results silently, making all failure detection a no-op.
    """
    log_and_print(
        f"{INFO} Checking for failed cron jobs in last {days_back} day(s)...", "info"
    )
    since_arg = f"{days_back} days ago"
    try:
        cron_logs = subprocess.check_output(
            ["journalctl", "-u", "cronie", "--since", since_arg],
            text=True,
            stderr=subprocess.DEVNULL,
        )
        failed_jobs = [
            line for line in cron_logs.split("\n") if "FAILED" in line.upper()
        ]
        if failed_jobs:
            log_and_print(
                f"{FAILURE} Failed cron jobs detected. Review logs for details.",
                "error",
            )
            for job in failed_jobs:
                log_and_print(job, "error")
            repair = prompt_with_timeout(
                "Do you want to attempt to repair the failed cron jobs? (y/n): ",
                persistent=True,
            ).lower()
            if repair == "y":
                log_and_print(
                    f"{INFO} Please check the cron job definitions and logs manually.",
                    "info",
                )
        else:
            log_and_print(f"{SUCCESS} No failed cron jobs detected.", "info")
    except subprocess.CalledProcessError:
        log_and_print(
            f"{INFO} No failed cron jobs detected or logs not accessible.", "info"
        )


########################################
# 20. clear_docker_images
########################################


def clear_docker_images(dry_run=False, remove_volumes=False):
    """Clear Docker images if Docker is installed."""
    if shutil.which("docker"):
        log_and_print(f"{INFO} Clearing Docker images/containers...", "info")
        try:
            command = ["sudo", "docker", "system", "prune", "-a", "-f"]
            if remove_volumes:
                command.append("--volumes")
            if dry_run:
                log_and_print(
                    f"{INFO} [Dry Run] Command would be: {' '.join(command)}", "info"
                )
            else:
                subprocess.run(command, check=True)
            log_and_print(
                f"{SUCCESS} Docker images cleared (remove_volumes={remove_volumes}, dry_run={dry_run}).",
                "info",
            )
        except subprocess.CalledProcessError as e:
            log_and_print(
                f"{FAILURE} Error: Failed to clear Docker images: {e.stderr.strip()}",
                "error",
            )
    else:
        log_and_print(
            f"{INFO} Docker is not installed. Skipping Docker image cleanup.", "info"
        )


##################################
# 21. clear_temp_folder
##################################


def clear_temp_folder(age_days=2, whitelist=None):
    """
    Clear the temporary folder of files older than 'age_days'.
    If whitelist is provided, skip those files.
    """
    log_and_print(
        f"{INFO} Clearing the temporary folder (age > {age_days} days)...", "info"
    )
    if whitelist is None:
        whitelist = []
    with spinning_spinner():
        try:
            if os.path.isfile("/usr/lib/tmpfiles.d/tmp.conf"):
                log_and_print(
                    f"{WARNING} Systemd tmpfiles might already handle /tmp. Operation could be redundant.",
                    "warning",
                )

            find_command = [
                "sudo",
                "find",
                "/tmp",
                "-type",
                "f",
                "-atime",
                f"+{age_days}",
            ]
            result = subprocess.run(
                find_command, capture_output=True, text=True, check=True
            )
            old_files = result.stdout.strip().split("\n") if result.stdout else []
            old_files = [
                f
                for f in old_files
                if f.strip() and not any(wl in f for wl in whitelist)
            ]

            if not old_files:
                log_and_print(
                    f"{SUCCESS} No old files in /tmp older than {age_days} days (excluding whitelist).",
                    "info",
                )
                return

            log_and_print(
                f"{INFO} Found {len(old_files)} old files in /tmp, removing now...",
                "info",
            )
            for file_path in old_files:
                try:
                    os.remove(file_path)
                except Exception as e:
                    log_and_print(
                        f"{FAILURE} Failed to remove {file_path}: {e}", "error"
                    )

            log_and_print(f"{SUCCESS} Temporary folder cleared.", "info")
        except subprocess.CalledProcessError as e:
            log_and_print(
                f"{FAILURE} Error: Failed to list or remove old files in /tmp: {e.stderr.strip()}",
                "error",
            )


####################################
# 22. check_rmshit_script
####################################


def check_rmshit_script(config_path=None):
    """
    Clean up unnecessary files specified in an external config.
    - Path list is loaded from an external config file.
    - User selectively removes each path interactively.
    - Basic safety checks skip critical paths.
    """
    log_and_print(
        f"{INFO} Cleaning up unnecessary files using rmshit script logic...", "info"
    )
    if not config_path:
        config_path = os.path.join(LOG_BASE_DIR, "rmshit_paths.txt")
        if not os.path.isfile(config_path):
            default_paths = [
                "~/.adobe", "~/.macromedia", "~/.FRD/log/app.log",
                "~/.FRD/links.txt", "~/.objectdb", "~/.gstreamer-0.10",
                "~/.pulse", "~/.esd_auth", "~/.config/enchant", "~/.spicec",
                "~/.dropbox-dist", "~/.parallel", "~/.dbus", "~/.distlib/",
                "~/.bazaar/", "~/.bzr.log", "~/.nv/", "~/.viminfo", "~/.npm/",
                "~/.java/", "~/.swt/", "~/.oracle_jre_usage/", "~/.jssc/",
                "~/.tox/", "~/.pylint.d/", "~/.qute_test/",
                "~/.QtWebEngineProcess/", "~/.qutebrowser/", "~/.asy/",
                "~/.cmake/", "~/.cache/mozilla/", "~/.cache/chromium/",
                "~/.cache/google-chrome/", "~/.cache/spotify/",
                "~/.cache/steam/", "~/.zoom/", "~/.Skype/",
                "~/.minecraft/logs/", "~/.thumbnails/",
                "~/.local/share/Trash/", "~/.vim/.swp", "~/.vim/.backup",
                "~/.vim/.undo", "~/.emacs.d/auto-save-list/",
                "~/.cache/JetBrains/", "~/.vscode/extensions/",
                "~/.npm/_logs/", "~/.npm/_cacache/", "~/.composer/cache/",
                "~/.gem/cache/", "~/.cache/pip/", "~/.gnupg/", "~/.wget-hsts",
                "~/.docker/", "~/.local/share/baloo/",
                "~/.kde/share/apps/okular/docdata/",
                "~/.local/share/akonadi/", "~/.xsession-errors",
                "~/.cache/gstreamer-1.0/", "~/.cache/fontconfig/",
                "~/.cache/mesa/", "~/.nv/ComputeCache/",
            ]
            with open(config_path, "w") as f:
                for p in default_paths:
                    f.write(p + "\n")
            log_and_print(
                f"{INFO} Created default rmshit config at {config_path}", "info"
            )

    try:
        with open(config_path, "r") as infile:
            paths_to_clean = [line.strip() for line in infile if line.strip()]
    except IOError as e:
        log_and_print(f"{FAILURE} Could not read {config_path}: {e}", "error")
        return

    new_paths_input = input(
        "Enter any additional paths to clean (space-separated, or leave blank): "
    ).strip()
    if new_paths_input:
        paths_to_clean.extend(new_paths_input.split())

    for path in paths_to_clean:
        expanded_path = os.path.expanduser(path)
        if not os.path.exists(expanded_path):
            continue
        confirm = prompt_with_timeout(
            f"Remove {expanded_path}? [y/N]: ", persistent=True
        ).lower()
        if confirm == "y":
            if expanded_path in [os.path.expanduser("~"), "/root", "/etc"]:
                log_and_print(
                    f"{WARNING} Skipping critical path: {expanded_path}", "warning"
                )
                continue
            try:
                if os.path.isfile(expanded_path):
                    os.remove(expanded_path)
                    log_and_print(f"{INFO} Deleted file: {expanded_path}", "info")
                elif os.path.isdir(expanded_path):
                    shutil.rmtree(expanded_path)
                    log_and_print(
                        f"{INFO} Deleted directory: {expanded_path}", "info"
                    )
            except OSError as e:
                log_and_print(
                    f"{FAILURE} Error deleting {expanded_path}: {e}", "error"
                )

    log_and_print(f"{SUCCESS} Unnecessary files cleaned up.", "info")


######################################
# 23. remove_old_ssh_known_hosts / is_host_reachable
######################################


def is_host_reachable(host):
    """
    Check if a host is reachable: DNS resolution then single ping.
    """
    try:
        resolve_result = subprocess.run(
            ["getent", "hosts", host], capture_output=True, text=True
        )
        if resolve_result.returncode != 0:
            logging.info(f"Host {host} does not resolve. Marking unreachable.")
            return False
        ping_cmd = ["ping", "-c", "1", "-W", "1", host]
        result = subprocess.run(
            ping_cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
        return result.returncode == 0
    except Exception:
        return False


def remove_old_ssh_known_hosts():
    """Remove SSH known hosts entries that are unreachable or do not resolve."""
    ssh_known_hosts_file = os.path.expanduser("~/.ssh/known_hosts")
    if os.path.isfile(ssh_known_hosts_file):
        log_and_print(f"{INFO} Removing old SSH known hosts entries...", "info")
        try:
            with open(ssh_known_hosts_file, "r") as file:
                lines = file.readlines()
            new_lines = []
            for line in lines:
                if not line.strip():
                    continue
                host = line.split()[0]
                if not is_host_reachable(host):
                    logging.info(f"Removing unreachable or unresolvable host: {host}")
                else:
                    new_lines.append(line)
            with open(ssh_known_hosts_file, "w") as file:
                file.writelines(new_lines)
            log_and_print(f"{SUCCESS} Old SSH known hosts entries cleaned.", "info")
        except Exception as e:
            log_and_print(
                f"{FAILURE} Error: Failed to remove old SSH known hosts entries: {str(e)}",
                "error",
            )
    else:
        log_and_print(f"{INFO} No SSH known hosts file found. Skipping.", "info")


###############################
# 24. remove_orphan_vim_undo_files
###############################


def remove_orphan_vim_undo_files():
    """Remove orphan Vim undo files (.un~) if the original file does not exist."""
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
                                f"{SUCCESS} Removed orphan Vim undo file: {file}",
                                "info",
                            )
                        except OSError as e:
                            log_and_print(
                                f"{FAILURE} Error: Failed to remove orphan Vim undo file: {e}",
                                "error",
                            )


######################################
# 25. force_log_rotation
######################################


def force_log_rotation(config_path="/etc/logrotate.conf"):
    """Force log rotation using a configurable logrotate config file path."""
    log_and_print(f"{INFO} Forcing log rotation with config {config_path}...", "info")
    if not os.path.isfile(config_path):
        log_and_print(
            f"{FAILURE} logrotate config not found: {config_path}", "error"
        )
        return
    try:
        subprocess.run(["sudo", "logrotate", "-f", config_path], check=True)
        log_and_print(
            f"{SUCCESS} Log rotation forced with config {config_path}.", "info"
        )
    except subprocess.CalledProcessError as e:
        log_and_print(
            f"{FAILURE} Error: Failed to force log rotation: {e.stderr.strip()}",
            "error",
        )


##########################################
# 26. configure_zram
##########################################


def configure_zram():
    """
    Configure ZRam for better memory management if not already handled by systemd.
    Checks for an existing service or script before acting.
    If not found, sets up zram immediately at 25% RAM.
    """
    log_and_print(f"{INFO} Configuring ZRam for better memory management...", "info")

    zram_service = "/etc/systemd/system/zram_setup.service"
    zram_script = "/usr/local/bin/zram_setup.py"

    if os.path.isfile(zram_service) or os.path.isfile(zram_script):
        log_and_print(
            f"{INFO} A systemd zram service or script already exists. Skipping direct config.",
            "info",
        )
        return

    if not shutil.which("zramctl"):
        log_and_print(
            f"{FAILURE} ZRam not available. Please install zramctl.", "error"
        )
        return

    with spinning_spinner():
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

            subprocess.run(["sudo", "mkswap", zram_device], check=True)
            subprocess.run(["sudo", "swapon", zram_device, "-p", "32767"], check=True)

            log_and_print(
                f"{SUCCESS} ZRam configured successfully on {zram_device} with size {mem_total} bytes.",
                "info",
            )
        except subprocess.CalledProcessError as e:
            log_and_print(f"{FAILURE} Error configuring ZRam: {str(e)}", "error")


############################################
# 27. check_zram_configuration
############################################


def check_zram_configuration():
    """Check ZRam configuration and set up if not yet configured."""
    log_and_print(f"{INFO} Checking ZRam configuration...", "info")

    if not shutil.which("zramctl"):
        log_and_print(
            f"{FAILURE} zramctl not installed. Skipping ZRam checks.", "error"
        )
        return

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
                    f"{INFO} ZRam device exists but not used as swap. Configuring now...",
                    "info",
                )
                configure_zram()
        else:
            log_and_print(
                f"{INFO} ZRam is not configured. Checking for systemd service ...",
                "info",
            )
            zram_service = "/etc/systemd/system/zram_setup.service"
            if not os.path.isfile(zram_service):
                configure_zram()
            else:
                log_and_print(
                    f"{INFO} zram_setup.service found. Systemd likely manages ZRam. Skipping direct config.",
                    "info",
                )

    except subprocess.CalledProcessError as e:
        log_and_print(
            f"{FAILURE} Error while checking ZRam configuration: {e}", "error"
        )
    except Exception as ex:
        log_and_print(f"{FAILURE} Unexpected error: {str(ex)}", "error")


###################################
# 28. adjust_swappiness
###################################


def adjust_swappiness(value=133, force=False):
    """
    Adjust the swappiness sysctl param to 'value'.
    If force=False and user has /etc/sysctl.d/* config, skip changing at runtime.
    """
    swappiness_file = "/etc/sysctl.d/99-IPv4.conf"
    if not force and os.path.isfile(swappiness_file):
        log_and_print(
            f"{INFO} /etc/sysctl.d/99-IPv4.conf already manages swappiness. Skipping direct set.",
            "info",
        )
        return

    log_and_print(f"{INFO} Adjusting swappiness to {value}...", "info")
    try:
        subprocess.run(
            ["sudo", "sysctl", f"vm.swappiness={value}"], check=True
        )
        log_and_print(f"{SUCCESS} Swappiness adjusted to {value}.", "info")
    except subprocess.CalledProcessError as e:
        log_and_print(
            f"{FAILURE} Error: Failed to adjust swappiness: {e.stderr.strip()}",
            "error",
        )


################################
# 29. clear_system_cache
################################


def clear_system_cache(confirm_before=True):
    """Clear PageCache, dentries, and inodes with optional user confirmation."""
    if confirm_before:
        confirm = prompt_with_timeout(
            "Warning: Clearing system caches can degrade performance temporarily. Proceed? [y/N]: ",
            persistent=True,
        )
        if confirm.lower() != "y":
            log_and_print(f"{INFO} System cache clearing aborted by user.", "info")
            return

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


#####################################
# 30. disable_unused_services
#####################################


def disable_unused_services(services=None, reversible=True):
    """
    Disable a list of unused services, checking if installed first.
    Stores a backup of previously enabled services if reversible=True.
    """
    log_and_print(f"{INFO} Disabling unused services...", "info")
    if services is None:
        services = [
            "bluetooth.service",
            "cups.service",
            "geoclue.service",
            "avahi-daemon.service",
            "sshd.service",
        ]
    backup_file = None
    if reversible:
        backup_file = os.path.join(
            LOG_BASE_DIR,
            datetime.datetime.now().strftime("services_backup_%Y%m%d_%H%M%S.txt"),
        )
        with open(backup_file, "w") as bf:
            bf.write("Previously enabled services:\n")

    for service in services:
        try:
            status_result = subprocess.run(
                ["systemctl", "is-enabled", service],
                capture_output=True,
                text=True,
            )
            if "enabled" in status_result.stdout:
                subprocess.run(
                    ["sudo", "systemctl", "disable", "--now", service], check=False
                )
                log_and_print(
                    f"{SUCCESS} {service} has been disabled and stopped.", "info"
                )
                if reversible and backup_file:
                    with open(backup_file, "a") as bf:
                        bf.write(service + "\n")
            else:
                log_and_print(
                    f"{INFO} {service} is not enabled or not installed.", "info"
                )
        except Exception as e:
            log_and_print(
                f"{FAILURE} Error disabling {service}: {str(e)}", "error"
            )

    if reversible and backup_file:
        log_and_print(
            f"{INFO} Backup of disabled services stored in {backup_file}", "info"
        )


##################################
# 31. check_and_restart_systemd_units
##################################


def check_and_restart_systemd_units():
    """Check and optionally restart failed systemd units individually."""
    log_and_print(
        f"{INFO} Checking and restarting failed systemd units...", "info"
    )
    try:
        units_out = subprocess.check_output(["systemctl", "--failed"], text=True)
        if "0 loaded units listed" in units_out:
            log_and_print(f"{SUCCESS} No failed systemd units.", "info")
            return

        log_and_print(f"{INFO} Restarting failed systemd units...", "info")
        subprocess.run(["sudo", "systemctl", "reset-failed"], check=True)
        lines = units_out.strip().split("\n")[1:]
        failed_units = []
        for line in lines:
            if line and not line.startswith("UNIT"):
                parts = line.split()
                if parts and parts[0].endswith(".service"):
                    failed_units.append(parts[0])

        for unit in failed_units:
            confirm = prompt_with_timeout(
                f"Restart failed unit {unit}? [y/N]: ", persistent=True
            ).lower()
            if confirm == "y":
                subprocess.run(
                    ["sudo", "systemctl", "restart", unit], check=False
                )
        log_and_print(
            f"{SUCCESS} Finished attempting restarts on failed units.", "info"
        )
    except subprocess.CalledProcessError as e:
        log_and_print(
            f"{FAILURE} Error: Failed to check or restart systemd units: {e.stderr.strip()}",
            "error",
        )


###################################
# 32. security_audit
###################################


def security_audit():
    """
    Targeted network security audit for a machine using ExpressVPN + JDownloader.
    1) Check open ports via ss
    2) If ExpressVPN tun0 is active, run nmap on main interface
    3) Warn if JDownloader ports (9665/9666) are exposed on non-VPN interfaces

    FIX: open_ports was only assigned inside `if result.returncode == 0:` but
    referenced unconditionally in the JDownloader check below that block.
    If `ss` failed, the NameError would crash the entire function. open_ports
    is now initialised to an empty string before the conditional block.
    """
    log_and_print(f"{INFO} Performing a targeted network security audit...", "info")
    open_ports = ""  # FIX: initialise before conditional assignment
    try:
        log_and_print(f"{INFO} Checking for open ports on all interfaces...", "info")
        result = subprocess.run(["sudo", "ss", "-tuln"], capture_output=True, text=True)
        if result.returncode == 0:
            open_ports = result.stdout.strip()
            logging.info("Open ports and listening services:\n" + open_ports)
            log_and_print(f"{INFO} Open ports and listening services logged.", "info")
        else:
            logging.error(result.stderr)
            log_and_print(
                f"{FAILURE} Error checking open ports: {result.stderr.strip()}", "error"
            )

        log_and_print(f"{INFO} Checking if ExpressVPN (tun0) is active...", "info")
        tun0_check = subprocess.run(
            ["ip", "addr", "show", "dev", "tun0"], capture_output=True, text=True
        )
        tun0_active = tun0_check.returncode == 0

        if tun0_active:
            log_and_print(
                f"{INFO} ExpressVPN tun0 is active. Checking for listening services on enp2s0...",
                "info",
            )
            interface = "enp2s0"
            nmap_cmd = [
                "sudo",
                "nmap",
                "-sT",
                "-p-",
                "-oN",
                os.path.join(LOG_BASE_DIR, "nmap_mainiface.txt"),
                interface,
            ]
            log_and_print(
                f"{INFO} Running nmap on {interface} for full TCP port range scan...",
                "info",
            )
            try:
                subprocess.run(nmap_cmd, check=True)
                log_and_print(
                    f"{SUCCESS} Nmap scan completed. Check logs for results.", "info"
                )
            except subprocess.CalledProcessError as nmap_err:
                log_and_print(
                    f"{FAILURE} Nmap scan failed: {nmap_err.stderr}", "error"
                )
        else:
            log_and_print(
                f"{WARNING} ExpressVPN tun0 interface not found. Skipping interface-based checks.",
                "warning",
            )

        suspicious_ports = [
            line
            for line in open_ports.splitlines()
            if any(p in line for p in ["9665", "9666"])
        ]
        if suspicious_ports:
            log_and_print(
                f"{WARNING} JDownloader2 ports are open on a non-VPN interface:\n{''.join(suspicious_ports)}",
                "warning",
            )
            log_and_print(
                f"{INFO} Consider restricting JDownloader traffic to tun0 only.", "info"
            )

    except Exception as e:
        log_and_print(f"{FAILURE} Error during security audit: {str(e)}", "error")


#######################################
# 33. manage_users_and_groups / select_items_from_list
#######################################


def manage_users_and_groups():
    """
    Delegate to external 'grouctl' script if present, otherwise use built-in
    minimal user/group management.
    """
    grouctl_path = shutil.which("grouctl")
    if grouctl_path:
        log_and_print(f"{INFO} Found grouctl script: {grouctl_path}", "info")
        log_and_print(f"{INFO} Launching grouctl for user management...", "info")
        subprocess.run(["sudo", grouctl_path])
    else:
        log_and_print(
            f"{WARNING} grouctl script not found. Falling back to minimal approach...",
            "warning",
        )
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
                "6) Exit",
            ]
            for option in options:
                print(option)

            choice = input("Enter your choice (1-6): ").strip()

            if choice == "1":
                username = input("Enter username: ").strip()
                if username:
                    try:
                        groups = subprocess.check_output(
                            ["id", "-nG", username], text=True
                        ).strip()
                        log_and_print(
                            f"{INFO} Groups for {username}: {groups}", "info"
                        )
                    except subprocess.CalledProcessError as e:
                        log_and_print(
                            f"{FAILURE} Error retrieving groups for {username}: {e}",
                            "error",
                        )
                else:
                    log_and_print(f"{FAILURE} Username cannot be empty.", "error")

            elif choice == "2":
                username = input("Enter username: ").strip()
                if username:
                    result = subprocess.run(
                        ["cut", "-d:", "-f1", "/etc/group"],
                        capture_output=True,
                        text=True,
                    )
                    if result.returncode == 0:
                        all_groups = result.stdout.strip().split("\n")
                        selected_groups = select_items_from_list(
                            all_groups, "Select group(s) to add user to:"
                        )
                        if selected_groups:
                            for group in selected_groups:
                                subprocess.run(
                                    ["sudo", "usermod", "-aG", group, username],
                                    check=False,
                                )
                            log_and_print(
                                f"{SUCCESS} {username} added to groups: {', '.join(selected_groups)}",
                                "info",
                            )
                        else:
                            log_and_print(f"{INFO} No groups selected.", "info")
                    else:
                        log_and_print(
                            f"{FAILURE} Error retrieving groups: {result.stderr.strip()}",
                            "error",
                        )
                else:
                    log_and_print(f"{FAILURE} Username cannot be empty.", "error")

            elif choice == "3":
                username = input("Enter username: ").strip()
                if username:
                    try:
                        groups = (
                            subprocess.check_output(["id", "-nG", username], text=True)
                            .strip()
                            .split()
                        )
                    except subprocess.CalledProcessError:
                        log_and_print(
                            f"{FAILURE} User {username} not found.", "error"
                        )
                        return
                    if groups:
                        selected_groups = select_items_from_list(
                            groups, "Select group(s) to remove user from:"
                        )
                        if selected_groups:
                            for group in selected_groups:
                                subprocess.run(
                                    ["sudo", "gpasswd", "-d", username, group],
                                    check=False,
                                )
                            log_and_print(
                                f"{SUCCESS} {username} removed from groups: {', '.join(selected_groups)}",
                                "info",
                            )
                        else:
                            log_and_print(f"{INFO} No groups selected.", "info")
                    else:
                        log_and_print(
                            f"{INFO} User {username} is not a member of any groups.",
                            "info",
                        )
                else:
                    log_and_print(f"{FAILURE} Username cannot be empty.", "error")

            elif choice == "4":
                username = input("Enter username: ").strip()
                if username:
                    standard_groups = [
                        "adm", "users", "disk", "wheel", "cdrom", "audio",
                        "video", "usb", "optical", "storage", "scanner", "lp",
                        "network", "power",
                    ]
                    for group in standard_groups:
                        subprocess.run(
                            ["sudo", "usermod", "-aG", group, username], check=False
                        )
                    log_and_print(
                        f"{SUCCESS} Applied standard group preset to {username}.",
                        "info",
                    )
                else:
                    log_and_print(f"{FAILURE} Username cannot be empty.", "error")

            elif choice == "5":
                wheel_sudoers = "/etc/sudoers.d/wheel-sudo"
                if not os.path.isfile(wheel_sudoers):
                    with open(wheel_sudoers, "w") as wf:
                        wf.write("%wheel ALL=(ALL) ALL\n")
                    subprocess.run(
                        ["sudo", "chmod", "440", wheel_sudoers], check=False
                    )
                    log_and_print(
                        f"{SUCCESS} 'wheel' group has been enabled in sudoers.", "info"
                    )
                else:
                    log_and_print(
                        f"{INFO} 'wheel' group is already enabled in sudoers.", "info"
                    )

            elif choice == "6":
                log_and_print(
                    f"{INFO} Exiting user and group management.", "info"
                )
                return

            else:
                log_and_print(f"{FAILURE} Invalid choice.", "error")

        except Exception as e:
            log_and_print(
                f"{FAILURE} Error managing users/groups: {str(e)}", "error"
            )


def select_items_from_list(items, prompt):
    """Allow the user to select items from a list, using fzf if available."""
    try:
        if shutil.which("fzf"):
            fzf_command = ["fzf", "-m", "--prompt", prompt]
            result = subprocess.run(
                fzf_command, input="\n".join(items), capture_output=True, text=True
            )
            if result.returncode == 0:
                return result.stdout.strip().split("\n")
            else:
                return []
        else:
            print(prompt)
            for idx, item in enumerate(items, 1):
                print(f"{idx}) {item}")
            selections = input(
                "Enter the numbers of the items to select (comma-separated): "
            ).strip()
            if selections:
                indices = [
                    int(s) - 1 for s in selections.split(",") if s.strip().isdigit()
                ]
                return [items[i] for i in indices if 0 <= i < len(items)]
            else:
                return []
    except Exception as e:
        log_and_print(f"{FAILURE} Error selecting items: {str(e)}", "error")
        return []


####################################
# 34. configure_firewall
####################################


def configure_firewall():
    """
    Minimal UFW reset: deny incoming, allow outgoing, optionally allow/deny SSH.
    """
    log_and_print(
        f"{INFO} Configuring firewall settings (basic UFW reset)...", "info"
    )
    try:
        if not shutil.which("ufw"):
            log_and_print(
                f"{FAILURE} UFW is not installed. Install it with 'sudo pacman -S ufw'.",
                "error",
            )
            return

        confirm_reset = prompt_with_timeout(
            "Do you want to reset UFW to default settings? [y/N]: ", persistent=True
        ).lower()
        if confirm_reset == "y":
            subprocess.run(["sudo", "ufw", "reset"], check=False)
            log_and_print(f"{INFO} UFW settings reset to default.", "info")

        subprocess.run(
            ["sudo", "ufw", "default", "deny", "incoming"], check=False
        )
        subprocess.run(
            ["sudo", "ufw", "default", "allow", "outgoing"], check=False
        )
        log_and_print(
            f"{INFO} Set default policies: deny incoming, allow outgoing.", "info"
        )

        ssh_confirm = prompt_with_timeout(
            "Do you want to allow SSH connections? [Y/n]: ", persistent=True
        ).lower()
        if ssh_confirm != "n":
            subprocess.run(["sudo", "ufw", "allow", "ssh"], check=False)
            log_and_print(f"{INFO} SSH connections allowed.", "info")
        else:
            subprocess.run(["sudo", "ufw", "deny", "ssh"], check=False)
            log_and_print(f"{INFO} SSH connections denied.", "info")

        subprocess.run(["sudo", "ufw", "--force", "enable"], check=False)
        log_and_print(f"{SUCCESS} UFW enabled.", "info")
        subprocess.run(["sudo", "ufw", "status", "verbose"], check=False)

    except Exception as e:
        log_and_print(f"{FAILURE} Error configuring firewall: {str(e)}", "error")


####################################
# 35. monitor_system_logs
####################################


def monitor_system_logs(priority=3, services=None):
    """
    Monitor system logs for errors or warnings of a given priority or higher.
    Optionally filter by specific service names.
    """
    if services is None:
        services = []
    log_and_print(
        f"{INFO} Monitoring system logs (priority >= {priority})...", "info"
    )
    try:
        cmd = ["journalctl", f"-p{priority}", "-xb"]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode == 0:
            logs = result.stdout.strip()
            if logs:
                if services:
                    filtered = [
                        line
                        for line in logs.split("\n")
                        if any(svc in line for svc in services)
                    ]
                    if filtered:
                        log_and_print(
                            f"{INFO} Filtered system logs (services={services}):",
                            "info",
                        )
                        for line in filtered:
                            print(line)
                        logging.info(
                            "Filtered system logs:\n" + "\n".join(filtered)
                        )
                    else:
                        log_and_print(
                            f"{SUCCESS} No relevant logs found for services={services}.",
                            "info",
                        )
                else:
                    log_and_print(f"{INFO} System errors/warnings found:", "info")
                    print(logs)
                    logging.info("System errors:\n" + logs)
            else:
                log_and_print(
                    f"{SUCCESS} No system errors detected at priority >= {priority}.",
                    "info",
                )
        else:
            logging.error(result.stderr)
            log_and_print(
                f"{FAILURE} Error monitoring system logs: {result.stderr.strip()}",
                "error",
            )
    except Exception as e:
        log_and_print(f"{FAILURE} Error monitoring system logs: {str(e)}", "error")


####################################
# 36. generate_system_report
####################################


def generate_system_report(output_format="json", output_file=None):
    """
    Generate a structured report of system information.
    Default output: logs/system_report.json (JSON format).
    Includes uname, lsb_release, lshw (if available), inxi (if available),
    /proc/meminfo, and /proc/cpuinfo.
    """
    log_and_print(
        f"{INFO} Generating system information report (format={output_format})...",
        "info",
    )
    if not output_file:
        output_file = os.path.join(LOG_BASE_DIR, "system_report.json")

    report = {}
    uname_result = subprocess.run(["uname", "-a"], capture_output=True, text=True)
    report["uname"] = uname_result.stdout.strip()

    try:
        lsb_result = subprocess.run(
            ["lsb_release", "-a"], capture_output=True, text=True
        )
        report["lsb_release"] = lsb_result.stdout.strip()
    except FileNotFoundError:
        report["lsb_release"] = "lsb_release not found"

    if shutil.which("lshw"):
        try:
            lshw_result = subprocess.run(
                ["sudo", "lshw", "-json"], capture_output=True, text=True, check=True
            )
            try:
                report["hardware"] = json.loads(lshw_result.stdout)
            except json.JSONDecodeError:
                report["hardware_raw"] = lshw_result.stdout.strip()
        except subprocess.CalledProcessError as e:
            log_and_print(
                f"{FAILURE} Error running lshw: {e.stderr.strip()}", "error"
            )
    else:
        report["hardware"] = "lshw not installed"

    if shutil.which("inxi"):
        inxi_result = subprocess.run(
            ["inxi", "-Fxxxz"], capture_output=True, text=True
        )
        report["inxi"] = inxi_result.stdout.strip()
    else:
        report["inxi"] = "inxi not installed"

    with open("/proc/meminfo", "r") as meminfo:
        report["meminfo"] = meminfo.read()

    with open("/proc/cpuinfo", "r") as cpuinfo:
        report["cpuinfo"] = cpuinfo.read()

    try:
        if output_format.lower() == "json":
            with open(output_file, "w") as outfile:
                json.dump(report, outfile, indent=2)
            log_and_print(
                f"{SUCCESS} System report saved as JSON: {output_file}", "info"
            )
        else:
            with open(output_file, "w") as outfile:
                outfile.write(str(report))
            log_and_print(
                f"{SUCCESS} System report saved as text: {output_file}", "info"
            )
    except IOError as e:
        log_and_print(f"{FAILURE} Error writing system report: {str(e)}", "error")


############################
# 37. is_interactive
############################


def is_interactive():
    return sys.stdin.isatty()


############################
# 38. run_all_tasks
############################


def run_all_tasks():
    """
    Run all maintenance tasks in numeric order (1 through 31).
    """
    for key in [str(k) for k in range(1, 32)]:
        try:
            menu_options[key]()
        except KeyError as e:
            log_and_print(
                format_message(f"Error executing task {key}: {e}", RED), "error"
            )


############################
# MENU DEFINITIONS
############################

menu_options = {
    "1": process_dep_scan_log,
    "2": manage_cron_job,
    "3": remove_broken_symlinks,
    "4": clean_old_kernels,
    "5": vacuum_journalctl,
    "6": clear_cache,
    "7": update_font_cache,
    "8": clear_trash,
    "9": optimize_databases,
    "10": clean_package_cache,
    "11": clean_aur_dir,
    "12": handle_pacnew_pacsave,
    "13": verify_installed_packages,
    "14": check_failed_cron_jobs,
    "15": clear_docker_images,
    "16": clear_temp_folder,
    "17": check_rmshit_script,
    "18": remove_old_ssh_known_hosts,
    "19": remove_orphan_vim_undo_files,
    "20": force_log_rotation,
    "21": configure_zram,
    "22": check_zram_configuration,
    "23": adjust_swappiness,
    "24": clear_system_cache,
    "25": disable_unused_services,
    "26": check_and_restart_systemd_units,
    "27": security_audit,
    "28": manage_users_and_groups,
    "29": configure_firewall,
    "30": monitor_system_logs,
    "31": generate_system_report,
    "0": run_all_tasks,
}

################################
# main
################################


def main():
    """Display the main menu and handle user input."""
    # FIX: Removed redundant `import os / sys / subprocess` statements that
    # were nested inside main(). All three modules are imported at the top of
    # the file and are available throughout; re-importing inside a function is
    # a no-op but adds clutter and misleads readers about the module's structure.

    if os.geteuid() != 0:
        try:
            print("Attempting to escalate privileges via sudo...")
            subprocess.check_call(["sudo", sys.executable] + sys.argv)
            sys.exit(0)
        except subprocess.CalledProcessError as e:
            print(f"Error escalating privileges: {e}")
            sys.exit(e.returncode)

    while True:
        os.system("clear")
        print(f"{GREEN}#{NC} --- {GREEN}//{NC} Vacuum {GREEN}//{NC}")
        print("")
        print(
            f"{GREEN}1{NC}) Process Dependency Log             {GREEN}17{NC}) Clean Unnecessary Files"
        )
        print(
            f"{GREEN}2{NC}) Manage Cron Jobs                   {GREEN}18{NC}) Remove Old SSH Known Hosts"
        )
        print(
            f"{GREEN}3{NC}) Remove Broken Symlinks             {GREEN}19{NC}) Remove Orphan Vim Undo Files"
        )
        print(
            f"{GREEN}4{NC}) Clean Old Kernels                  {GREEN}20{NC}) Force Log Rotation"
        )
        print(
            f"{GREEN}5{NC}) Vacuum Journalctl                  {GREEN}21{NC}) Configure ZRam"
        )
        print(
            f"{GREEN}6{NC}) Clear Cache                        {GREEN}22{NC}) Check ZRam Configuration"
        )
        print(
            f"{GREEN}7{NC}) Update Font Cache                  {GREEN}23{NC}) Adjust Swappiness"
        )
        print(
            f"{GREEN}8{NC}) Clear Trash                        {GREEN}24{NC}) Clear System Cache"
        )
        print(
            f"{GREEN}9{NC}) Optimize Databases                 {GREEN}25{NC}) Disable Unused Services"
        )
        print(
            f"{GREEN}10{NC}) Clean Package Cache               {GREEN}26{NC}) Fix Systemd Units"
        )
        print(
            f"{GREEN}11{NC}) Clean AUR Directory               {GREEN}27{NC}) Perform Security Audit"
        )
        print(
            f"{GREEN}12{NC}) Handle Pacnew/Pacsave Files       {GREEN}28{NC}) Manage Users and Groups"
        )
        print(
            f"{GREEN}13{NC}) Verify Installed Packages         {GREEN}29{NC}) Configure Firewall"
        )
        print(
            f"{GREEN}14{NC}) Check Failed Cron Jobs            {GREEN}30{NC}) Monitor System Logs"
        )
        print(
            f"{GREEN}15{NC}) Clear Docker Images               {GREEN}31{NC}) Generate System Report"
        )
        print(f"{GREEN}16{NC}) Clear Temp Folder                 {GREEN}Q{NC}) Quit")
        print(f"{GREEN}0{NC}) Run All Tasks")
        print("")
        print(f"{GREEN}By your command:{NC}")

        command = prompt_with_timeout("Enter your choice: ", timeout=30, default="Q")
        command = (command or "Q").strip().upper()

        if command == "Q":
            break
        elif command in menu_options:
            try:
                menu_options[command]()
            except Exception as e:
                log_and_print(
                    format_message(f"Error executing option: {e}", RED), "error"
                )
        else:
            log_and_print(
                format_message("Invalid choice. Please try again.", RED), "error"
            )

        input("Press Enter to continue...")


if __name__ == "__main__":
    main()
