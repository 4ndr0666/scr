#!/usr/bin/python3

import os
import subprocess
import sys
import shutil
import stat
import time
import logging
import datetime
import re
from functools import partial
import threading
import itertools

# Set up basic logging configuration
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Spinner function with docstring:
def spinner(symbols='|/-\\', speed=0.1):
    """
    A console spinner for indicating progress with customizable symbols and speed.

    Args:
        symbols (str): A string of symbols to cycle through for the spinner. Defaults to '|/-\\'.
        speed (float): The delay in seconds between each spinner update. Defaults to 0.1 seconds.

    Returns:
        tuple: A thread object and a stop function to stop the spinner.
    """
    spinner_running = True
    spinner_symbols = itertools.cycle(symbols)

    def spin():
        while spinner_running:
            sys.stdout.write(next(spinner_symbols) + '\r')
            sys.stdout.flush()
            time.sleep(speed)

    try:
        spinner_thread = threading.Thread(target=spin)
        spinner_thread.start()
    except Exception as e:
        logging.error(f"Failed to start spinner thread: {e}")
        return None, None
    
    return spinner_thread, lambda: setattr(spinner, 'spinner_running', False)

# Colors and symbols
GREEN = '\033[38;2;57;255;20m'
BOLD = '\033[1m'
RED = '\033[0;31m'
NC = '\033[0m'  # No Color
SUCCESS = "✔️"
FAILURE = "❌"
INFO = "➡️"
EXPLOSION = "💥"

# Logging setup
log_dir = os.path.expanduser("~/.local/share/system_maintenance")
os.makedirs(log_dir, exist_ok=True)
log_file_path = os.path.join(log_dir, datetime.datetime.now().strftime("%Y%m%d_%H%M%S_system_maintenance.log"))
logging.basicConfig(filename=log_file_path, level=logging.INFO, format='%(asctime)s:%(levelname)s:%(message)s')

def format_message(message, color):
    """
    Format a message with the given color and bold text.

    Args:
        message (str): The message to format.
        color (str): The ANSI color code to apply.

    Returns:
        str: The formatted message.
    """
    return f"{BOLD}{color}{message}{NC}"

def log_and_print(message, level='info'):
    """
    Print and log a message at the specified log level.

    Args:
        message (str): The message to log and print.
        level (str): The log level ('info', 'error', 'warning'). Defaults to 'info'.
    """
    print(message)
    if level == 'info':
        logging.info(message)
    elif level == 'error':
        logging.error(message)
    elif level == 'warning':
        logging.warning(message)
    else:
        logging.info(f"Unhandled log level: {level}. Message: {message}")

def execute_command(command, error_message=None):
    """
    Execute a shell command and log the output or error.

    Args:
        command (list): The command to execute as a list of arguments.
        error_message (str, optional): Custom error message to log in case of failure.

    Returns:
        str: The standard output of the command, or None if an error occurred.
    """
    try:
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
        logging.info(result.stdout)
        if result.stderr:
            logging.error(result.stderr)
        return result.stdout
    except subprocess.CalledProcessError as e:
        log_message = error_message or f"Command '{e.cmd}' failed with error: {e.stderr.strip()}"
        log_and_print(format_message(log_message, RED), 'error')
        return None
    except Exception as e:
        log_message = error_message or f"Command execution failed with error: {str(e)}"
        log_and_print(format_message(log_message, RED), 'error')
        return None

def confirm_deletion(file_or_dir):
    """
    Ask for confirmation before deletion.

    Args:
        file_or_dir (str): The file or directory to confirm deletion for.

    Returns:
        bool: True if user confirms deletion, False otherwise.
    """
    confirm = input(f"Do you really want to delete {file_or_dir}? [y/N]: ").strip().lower()
    return confirm == 'y'

def process_dep_scan_log(log_file):
    """
    Process the dependency scan log to fix file permissions and install missing dependencies.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    log_and_print(f"{INFO} Processing dependency scan log...")
    spinner_thread, stop_spinner = spinner()  # Start the spinner
    dep_scan_log = "/usr/local/bin/dependency_scan.log"
    if os.path.isfile(dep_scan_log):
        try:
            with open(dep_scan_log, "r") as log:
                for line in log:
                    if "permission warning" in line:
                        file_path = line.split(": ")[1].strip()
                        fix_permissions(file_path)
                    if "missing dependency" in line:
                        dependency = line.split(": ")[1].strip()
                        install_missing_dependency(dependency)
        except IOError as e:
            log_and_print(f"{FAILURE} Error reading dependency scan log: {e}", 'error')
    else:
        log_and_print(f"{FAILURE} Dependency scan log file not found.", 'error')
    log_and_print(f"{SUCCESS} Dependency scan log processing completed.", 'info')
    stop_spinner()  # Stop the spinner

def fix_permissions(file_path):
    """
    Fix the permissions for the given file or directory.

    Args:
        file_path (str): Path to the file or directory.
    """
    try:
        if os.path.isfile(file_path):
            os.chmod(file_path, stat.S_IRUSR | stat.S_IWUSR | stat.S_IRGRP | stat.S_IROTH)
            log_and_print(f"{INFO}Fixed permissions for file: {file_path}", 'info')
        elif os.path.isdir(file_path):
            os.chmod(file_path, stat.S_IRWXU | stat.S_IRGRP | stat.S_IXGRP | stat.S_IROTH | stat.S_IXOTH)
            log_and_print(f"{INFO}Fixed permissions for directory: {file_path}", 'info')
    except OSError as e:
        log_and_print(f"{FAILURE} Error fixing permissions for {file_path}: {e}", 'error')

def install_missing_dependency(dependency):
    """
    Install the missing dependency using the package manager.

    Args:
        dependency (str): Name of the missing dependency.
    """
    log_and_print(f"{INFO}Attempting to install missing dependency: {dependency}", 'info')
    result = execute_command(["sudo", "pacman", "-Sy", "--noconfirm", dependency])
    if result:
        log_and_print(f"{SUCCESS} Successfully installed missing dependency: {dependency}", 'info')
    else:
        log_and_print(f"{FAILURE} Failed to install missing dependency: {dependency}", 'error')

def manage_cron_job(log_file):
    """
    Interactively manage system cron jobs.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    log_and_print(f"{INFO} Managing system cron jobs...", 'info')
    spinner_thread, stop_spinner = spinner()  # Start the spinner

    try:
        # Retrieve existing cron jobs
        result = subprocess.run(["sudo", "crontab", "-l"], capture_output=True, text=True, check=True)
        existing_crons = result.stdout.strip().split('\n')
        
        print("Existing cron jobs:\n")
        for i, cron in enumerate(existing_crons, 1):
            print(f"{i}. {cron}")
        print()

        # Choose to add or delete a cron job
        choice = input("Do you want to add a new cron job or delete an existing one? (add/delete): ").strip().lower()

        if choice == "add":
            new_cron = input("Enter the new cron job entry: ").strip()
            existing_crons.append(new_cron)
            new_crons = '\n'.join(existing_crons)
            update_cron_jobs(new_crons)
            log_and_print(f"{SUCCESS} New cron job added successfully.", 'info')

        elif choice == "delete":
            cron_to_delete = int(input("Enter the number of the cron job entry to delete: ").strip())
            if 1 <= cron_to_delete <= len(existing_crons):
                del existing_crons[cron_to_delete - 1]
                new_crons = '\n'.join(existing_crons)
                update_cron_jobs(new_crons)
                log_and_print(f"{SUCCESS} Cron job deleted successfully.", 'info')
            else:
                log_and_print(f"{FAILURE} Invalid selection. No changes made.", 'error')

        else:
            log_and_print(f"{INFO} No changes made to cron jobs.", 'info')

    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error managing cron jobs: {e.stderr.strip()}", 'error')
    finally:
        stop_spinner()  # Stop the spinner

def update_cron_jobs(new_crons):
    """
    Update the system cron jobs with the new entries.

    Args:
        new_crons (str): The new cron jobs to set.
    """
    temp_file_path = os.path.expanduser("~/.cron_temp")
    try:
        with open(temp_file_path, "w") as temp_file:
            temp_file.write(new_crons)
        subprocess.run(["sudo", "crontab", temp_file_path], check=True)
    finally:
        if os.path.exists(temp_file_path):
            os.remove(temp_file_path)

def remove_broken_symlinks(log_file):
    """
    Search for and remove broken symbolic links, with user confirmation.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    log_and_print(f"{INFO} Searching for broken symbolic links...", 'info')
    spinner_thread, stop_spinner = spinner()  # Start the spinner

    try:
        broken_links = subprocess.check_output(["sudo", "find", "/", "-xtype", "l"], stderr=subprocess.STDOUT, text=True).strip()
        stop_spinner()

        if broken_links:
            broken_links_list = broken_links.split('\n')
            log_and_print(f"{INFO} Broken symbolic links found:\n", 'info')
            for i, link in enumerate(broken_links_list, 1):
                print(f"{i}. {link}")
            print()

            deleted_links = []
            for i, link in enumerate(broken_links_list, 1):
                confirm = input(f"Do you want to delete the broken symlink {link}? [y/N]: ").strip().lower()
                if confirm == 'y':
                    try:
                        os.remove(link)
                        log_and_print(f"{SUCCESS} Deleted broken symlink: {link}", 'info')
                        deleted_links.append(link)
                    except OSError as e:
                        log_and_print(f"{FAILURE} Error deleting broken symlink {link}: {e}", 'error')

            log_and_print(f"{INFO} Summary of deleted broken symlinks:", 'info')
            for link in deleted_links:
                log_and_print(f"{INFO} {link}", 'info')

        else:
            log_and_print(f"{SUCCESS} No broken symbolic links found.", 'info')

    except subprocess.CalledProcessError as e:
        stop_spinner()
        log_and_print(f"{FAILURE} Error searching for broken symbolic links: {e.output.strip()}", 'error')
    finally:
        stop_spinner()  # Ensure spinner is stopped

def clean_old_kernels(log_file):
    """
    Clean up old kernel images, with user confirmation.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    log_and_print(f"{INFO} Cleaning up old kernel images...", 'info')
    spinner_thread, stop_spinner = spinner()  # Start the spinner

    try:
        # Get a list of all installed kernels
        explicitly_installed = subprocess.check_output(["pacman", "-Qet"], text=True).strip().split('\n')
        current_kernel = subprocess.check_output(["uname", "-r"], text=True).strip()
        current_kernel_major_version = '.'.join(current_kernel.split('.')[:2])
        kernels_to_remove = []

        # Identify old kernels to remove
        for pkg in explicitly_installed:
            if "linux" in pkg:
                pkg_name = pkg.split()[0]
                if (pkg_name.startswith("linux") and 
                    (pkg_name.endswith("headers") or pkg_name.count('-') > 1) and 
                    current_kernel_major_version not in pkg_name):
                    kernels_to_remove.append(pkg_name)

        if kernels_to_remove:
            print("Kernels to be removed:")
            for i, kernel in enumerate(kernels_to_remove, 1):
                print(f"{i}. {kernel}")

            confirm = input("Do you want to remove these kernels? [y/N]: ").strip().lower()
            if confirm == 'y':
                subprocess.run(["sudo", "pacman", "-Rns"] + kernels_to_remove, check=True)
                log_and_print(f"{SUCCESS} Old kernel images cleaned up: {' '.join(kernels_to_remove)}", 'info')
            else:
                log_and_print(f"{INFO} Kernel cleanup canceled by user.", 'info')
        else:
            log_and_print(f"{INFO} No old kernel images to remove.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error: {e.stderr.strip()}", 'error')
    finally:
        stop_spinner()  # Ensure spinner is stopped

def vacuum_journalctl(log_file):
    """
    Vacuum journalctl logs older than 1 day, providing detailed output.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    log_and_print(f"{INFO} Vacuuming journalctl logs older than 1 day...", 'info')
    spinner_thread, stop_spinner = spinner()  # Start the spinner

    try:
        result = subprocess.run(["sudo", "journalctl", "--vacuum-time=1d"], check=True, capture_output=True, text=True)
        log_and_print(f"{SUCCESS} Journalctl vacuumed successfully. Details:\n{result.stdout}", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error: Failed to vacuum journalctl: {e.stderr.strip()}", 'error')
    finally:
        stop_spinner()  # Ensure spinner is stopped

def clear_cache(log_file):
    """
    Clear user cache files older than 1 day, logging success or failure.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    log_and_print(f"{INFO} Clearing user cache...", 'info')
    spinner_thread, stop_spinner = spinner()  # Start the spinner

    try:
        subprocess.run(["sudo", "find", os.path.expanduser("~/.cache/"), "-type", "f", "-atime", "+1", "-delete"], check=True)
        log_and_print(f"{SUCCESS} User cache cleared.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error: Failed to clear cache: {e.stderr.strip()}", 'error')
    finally:
        stop_spinner()  # Ensure spinner is stopped

def update_font_cache(log_file):
    """
    Update the font cache, logging success or failure.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    log_and_print(f"{INFO} Updating font cache...", 'info')
    spinner_thread, stop_spinner = spinner()  # Start the spinner

    try:
        result = subprocess.run(["sudo", "fc-cache", "-fv"], check=True, capture_output=True, text=True)
        log_and_print(f"{SUCCESS} Font cache updated successfully. Details:\n{result.stdout}", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error: Failed to update font cache: {e.stderr.strip()}", 'error')
    finally:
        stop_spinner()  # Ensure spinner is stopped

def clear_trash(log_file):
    """
    Automatically clear the trash system-wide, logging success or failure.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    log_and_print(f"{INFO} Clearing trash...", 'info')
    spinner_thread, stop_spinner = spinner()  # Start the spinner

    trash_paths = [
        os.path.expanduser("~/.local/share/Trash/*"),
        "/root/.local/share/Trash/*",
        "/tmp/*"
    ]

    for path in trash_paths:
        try:
            subprocess.run(["sudo", "rm", "-rf", path], check=True)
            log_and_print(f"{SUCCESS} Trash cleared for path: {path}", 'info')
        except subprocess.CalledProcessError as e:
            log_and_print(f"{FAILURE} Error: Failed to clear trash for path {path}: {e.stderr.strip()}", 'error')

    stop_spinner()  # Ensure spinner is stopped

def optimize_databases(log_file):
    """
    Optimize system databases, logging success or failure for each step.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    log_and_print(f"{INFO} Optimizing system databases...", 'info')
    spinner_thread, stop_spinner = spinner()  # Start the spinner

    def run_command(command, success_message, failure_message):
        try:
            subprocess.run(command, check=True, capture_output=True, text=True)
            log_and_print(f"{SUCCESS} {success_message}", 'info')
        except subprocess.CalledProcessError as e:
            log_and_print(f"{FAILURE} {failure_message}: {e.stderr.strip()}", 'error')

    try:
        log_and_print(f"{INFO} Updating mlocate database...", 'info')
        run_command(["sudo", "updatedb"], "mlocate database updated.", "Failed to update mlocate database")

        log_and_print(f"{INFO} Updating pkgfile database...", 'info')
        run_command(["sudo", "pkgfile", "-u"], "pkgfile database updated.", "Failed to update pkgfile database")

        log_and_print(f"{INFO} Upgrading pacman database...", 'info')
        run_command(["sudo", "pacman-db-upgrade"], "pacman database upgraded.", "Failed to upgrade pacman database")

        log_and_print(f"{INFO} Cleaning package cache...", 'info')
        run_command(["yes", "|", "sudo", "pacman", "-Sc"], "Package cache cleaned.", "Failed to clean package cache")

        log_and_print(f"{INFO} Syncing filesystem changes...", 'info')
        run_command(["sync"], "Filesystem changes synced.", "Failed to sync filesystem changes")

        log_and_print(f"{INFO} Refreshing pacman keys...", 'info')
        run_command(["sudo", "pacman-key", "--refresh-keys"], "Keys refreshed.", "Failed to refresh keys")

        log_and_print(f"{INFO} Populating keys and updating trust...", 'info')
        run_command(["sudo", "pacman-key", "--populate"], "Keys populated.", "Failed to populate keys")
        run_command(["sudo", "pacman-key", "--updatedb"], "Trust database updated.", "Failed to update trust database")

        log_and_print(f"{INFO} Refreshing package list...", 'info')
        run_command(["sudo", "pacman", "-Syy"], "Package list refreshed.", "Failed to refresh package list")

        log_and_print(f"{SUCCESS} System databases optimized.", 'info')
    except Exception as e:
        log_and_print(f"{FAILURE} Unexpected error during database optimization: {str(e)}", 'error')
    finally:
        stop_spinner()  # Ensure spinner is stopped

def clean_aur_dir(log_file):
    """
    Clean the AUR directory, deleting only uninstalled or old versions of packages, and log success or failure.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    log_and_print(f"{INFO} Cleaning AUR directory...", 'info')
    spinner_thread, stop_spinner = spinner()  # Start the spinner

    try:
        # Using trizen to find the AUR directory
        aur_dir = subprocess.check_output(["trizen", "-Qc"], text=True).strip()
        if not os.path.isdir(aur_dir):
            log_and_print(f"{FAILURE} The specified path is not a directory: {aur_dir}", 'error')
            return

        os.chdir(aur_dir)
        pkgname_regex = re.compile(r'(?P<pkgname>.*?)-(?P<pkgver>[^-]+)-(?P<arch>x86_64|any|i686)\.pkg\.tar\.(xz|zst|gz|bz2|lrz|lzo|lz4|lz)$')
        files = {}
        for f in os.listdir():
            if not os.path.isfile(f):
                continue
            match = pkgname_regex.match(f)
            if match:
                files[f] = match.groupdict()
        
        installed_packages = subprocess.check_output(["expac", "-Qs", "%n %v %a"], universal_newlines=True).splitlines()
        installed = {pkg.split()[0]: pkg.split()[1] for pkg in installed_packages}

        for f, file_info in files.items():
            pkgname = file_info['pkgname']
            pkgver = file_info['pkgver']
            if pkgname not in installed or pkgver != installed[pkgname]:
                log_and_print(f"{INFO} Deleting: {f}", 'info')
                try:
                    os.remove(f)
                except OSError as e:
                    log_and_print(f"{FAILURE} Error deleting file {f}: {e}", 'error')
        
        log_and_print(f"{SUCCESS} AUR directory cleaned.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error: Failed to clean AUR directory: {e.stderr.strip()}", 'error')
    finally:
        stop_spinner()  # Ensure spinner is stopped

def handle_pacnew_pacsave(log_file):
    """
    Automatically handle .pacnew and .pacsave files, logging a summary of actions taken.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    log_and_print(f"{INFO} Handling .pacnew and .pacsave files...", 'info')
    spinner_thread, stop_spinner = spinner()  # Start the spinner

    try:
        pacnew_files = subprocess.check_output(["sudo", "find", "/etc", "-type", "f", "-name", "*.pacnew"], text=True).splitlines()
        pacsave_files = subprocess.check_output(["sudo", "find", "/etc", "-type", "f", "-name", "*.pacsave"], text=True).splitlines()

        actions_summary = []

        if pacnew_files:
            for file in pacnew_files:
                os.remove(file)
                actions_summary.append(f"Removed .pacnew file: {file}")

        if pacsave_files:
            log_and_print(f"{INFO} .pacsave files found. Consider reviewing:", 'info')
            for file in pacsave_files:
                print(file)
                action = input("Do you want to remove, skip, or overwrite this file? (remove/skip/overwrite): ").strip().lower()
                if action == "remove":
                    os.remove(file)
                    actions_summary.append(f"Removed .pacsave file: {file}")
                elif action == "overwrite":
                    original_file = file.replace(".pacsave", "")
                    shutil.copyfile(file, original_file)
                    os.remove(file)
                    actions_summary.append(f"Overwritten .pacsave file: {file}")
                else:
                    actions_summary.append(f"Skipped .pacsave file: {file}")

        log_and_print(f"{INFO} Summary of actions taken:", 'info')
        for action in actions_summary:
            log_and_print(f"{INFO} {action}", 'info')

        if not pacnew_files:
            log_and_print(f"{INFO} No .pacnew files found.", 'info')
        if not pacsave_files:
            log_and_print(f"{INFO} No .pacsave files found.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error handling pacnew and pacsave files: {e.stderr.strip()}", 'error')
    finally:
        stop_spinner()  # Ensure spinner is stopped

def verify_installed_packages(log_file):
    """
    Verify installed packages for missing files and automatically reinstall them, logging a summary of actions taken.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    log_and_print(f"{INFO} Checking for packages with missing files...", 'info')
    spinner_thread, stop_spinner = spinner()  # Start the spinner

    try:
        choice = input("Do you want to check a single package or system-wide? (single/system): ").strip().lower()
        if choice == "single":
            package = input("Enter the package name to check: ").strip()
            result = subprocess.run(f"pacman -Qk {package} | grep -v ' 0 missing files'", shell=True, capture_output=True, text=True)
        else:
            result = subprocess.run("pacman -Qk | grep -v ' 0 missing files' | awk '{print $1}'", shell=True, capture_output=True, text=True)
        
        missing_packages = result.stdout.strip().split('\n')
        
        if not missing_packages or missing_packages == ['']:
            log_and_print(f"{SUCCESS} No packages with missing files found.", 'info')
            return

        log_and_print(f"{INFO} Reinstalling packages with missing files...", 'info')
        command = ["sudo", "pacman", "-S", "--noconfirm"] + missing_packages
        subprocess.run(command, check=True)
        log_and_print(f"{SUCCESS} Packages reinstalled successfully.", 'info')

        log_and_print(f"{INFO} Summary of reinstalled packages:", 'info')
        for pkg in missing_packages:
            log_and_print(f"{INFO} Reinstalled: {pkg}", 'info')

    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error verifying installed packages: {e.stderr.strip() if e.stderr else e}", 'error')
    except Exception as e:
        log_and_print(f"{FAILURE} Unexpected error: {str(e)}", 'error')
    finally:
        stop_spinner()  # Ensure spinner is stopped
