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
log_dir = os.path.expanduser("~/.local/share/system_maintenance")
os.makedirs(log_dir, exist_ok=True)
log_file_path = os.path.join(log_dir, datetime.datetime.now().strftime("%Y%m%d_%H%M%S_system_maintenance.log"))
logging.basicConfig(filename=log_file_path, level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Spinner function with improved handling
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

    spinner_thread = threading.Thread(target=spin)
    spinner_thread.start()

    def stop_spinner():
        nonlocal spinner_running
        spinner_running = False
        spinner_thread.join()  # Wait for the spinner thread to finish
        sys.stdout.write(' ' * 10 + '\r')  # Clear the spinner line
        sys.stdout.flush()

    return spinner_thread, stop_spinner

# Colors and symbols
GREEN = '\033[38;2;57;255;20m'
BOLD = '\033[1m'
RED = '\033[0;31m'
NC = '\033[0m'  # No Color
SUCCESS = "✔️"
FAILURE = "❌"
INFO = "➡️"

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
            log_and_print(f"{INFO} Fixed permissions for file: {file_path}", 'info')
        elif os.path.isdir(file_path):
            os.chmod(file_path, stat.S_IRWXU | stat.S_IRGRP | stat.S_IXGRP | stat.S_IROTH | stat.S_IXOTH)
            log_and_print(f"{INFO} Fixed permissions for directory: {file_path}", 'info')
    except OSError as e:
        log_and_print(f"{FAILURE} Error fixing permissions for {file_path}: {e}", 'error')

def install_missing_dependency(dependency):
    """
    Install the missing dependency using the package manager.

    Args:
        dependency (str): Name of the missing dependency.
    """
    log_and_print(f"{INFO} Attempting to install missing dependency: {dependency}", 'info')
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
        stop_spinner()  # Ensure spinner is stopped

        if broken_links:
            broken_links_list = broken_links.split('\n')
            log_and_print(f"{INFO} Broken symbolic links found:\n", 'info')
            for i, link in enumerate(broken_links_list, 1):
                print(f"{i}. {link}")
            print()

            deleted_links = []
            for link in broken_links_list:
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
        stop_spinner()  # Ensure spinner is stopped
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
                valid_action = False
                while not valid_action:
                    action = input("Do you want to remove, skip, or overwrite this file? (remove/skip/overwrite): ").strip().lower()
                    if action in ["remove", "skip", "overwrite"]:
                        valid_action = True
                    else:
                        print(f"{FAILURE} Invalid input. Please enter 'remove', 'skip', or 'overwrite'.")

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

def check_failed_cron_jobs(log_file):
    """
    Check for failed cron jobs and optionally attempt to repair them.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    log_and_print(f"{INFO} Checking for failed cron jobs...", 'info')
    try:
        failed_jobs = subprocess.check_output(["grep", "-i", "cron.*error", "/var/log/syslog"], text=True)
        if failed_jobs:
            log_and_print(f"{FAILURE} Failed cron jobs detected. Review syslog for details.", 'error')
            print(failed_jobs)
            repair = input("Do you want to attempt to repair the failed cron jobs? (y/n): ").strip().lower()
            if repair == "y":
                log_and_print(f"{SUCCESS} Attempting to repair failed cron jobs...", 'info')
                # Repair logic here
        else:
            log_and_print(f"{SUCCESS} No failed cron jobs detected.", 'info')
    except subprocess.CalledProcessError:
        log_and_print(f"{INFO} No failed cron jobs detected or syslog not accessible.", 'info')

def clear_docker_images(log_file):
    """
    Clear Docker images if Docker is installed.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    if shutil.which("docker"):
        log_and_print(f"{INFO} Clearing Docker images...", 'info')
        try:
            subprocess.run(["sudo", "docker", "image", "prune", "-af"], check=True)
            log_and_print(f"{SUCCESS} Docker images cleared.", 'info')
        except subprocess.CalledProcessError as e:
            log_and_print(f"{FAILURE} Error: Failed to clear Docker images: {e.stderr.strip()}", 'error')
    else:
        log_and_print(f"{INFO} Docker is not installed. Skipping Docker image cleanup.", 'info')

def clear_temp_folder(log_file):
    """
    Clear the temporary folder.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    log_and_print(f"{INFO} Clearing the temporary folder...", 'info')
    spinner_thread, stop_spinner = spinner()  # Start the spinner

    try:
        subprocess.run(["sudo", "find", "/tmp", "-type", "f", "-atime", "+2", "-delete"], check=True)
        log_and_print(f"{SUCCESS} Temporary folder cleared.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error: Failed to clear the temporary folder: {e.stderr.strip()}", 'error')
    finally:
        stop_spinner()  # Ensure spinner is stopped

def check_rmshit_script(log_file=None):
    """
    Clean up unnecessary files specified in the script.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    log_and_print(f"{INFO} Cleaning up unnecessary files...")
    shittyfiles = [
        '~/.adobe',
        '~/.macromedia',
        '~/.FRD/log/app.log',
        '~/.FRD/links.txt',
        '~/.objectdb',
        '~/.gstreamer-0.10',
        '~/.pulse',
        '~/.esd_auth',
        '~/.config/enchant',
        '~/.spicec',
        '~/.dropbox-dist',
        '~/.parallel',
        '~/.dbus',
        '~/.distlib/',
        '~/.bazaar/',
        '~/.bzr.log',
        '~/.nv/',
        '~/.viminfo',
        '~/.npm/',
        '~/.java/',
        '~/.swt/',
        '~/.oracle_jre_usage/',
        '~/.jssc/',
        '~/.tox/',
        '~/.pylint.d/',
        '~/.qute_test/',
        '~/.QtWebEngineProcess/',
        '~/.qutebrowser/',
        '~/.asy/',
        '~/.cmake/',
        '~/.cache/mozilla/',
        '~/.cache/chromium/',
        '~/.cache/google-chrome/',
        '~/.cache/spotify/',
        '~/.cache/steam/',
        '~/.zoom/',
        '~/.Skype/',
        '~/.minecraft/logs/',
        '~/.thumbnails/',
        '~/.local/share/Trash/',
        '~/.vim/.swp',
        '~/.vim/.backup',
        '~/.vim/.undo',
        '~/.emacs.d/auto-save-list/',
        '~/.cache/JetBrains/',
        '~/.vscode/extensions/',
        '~/.npm/_logs/',
        '~/.npm/_cacache/',
        '~/.composer/cache/',
        '~/.gem/cache/',
        '~/.cache/pip/',
        '~/.gnupg/',
        '~/.wget-hsts',
        '~/.docker/',
        '~/.local/share/baloo/',
        '~/.kde/share/apps/okular/docdata/',
        '~/.local/share/akonadi/',
        '~/.xsession-errors',
        '~/.cache/gstreamer-1.0/',
        '~/.cache/fontconfig/',
        '~/.cache/mesa/',
        '~/.nv/ComputeCache/'
    ]
    new_paths = input("Enter any additional paths to clean (separated by space): ").split()
    shittyfiles.extend(new_paths)
    for path in shittyfiles:
        expanded_path = os.path.expanduser(path)
        if os.path.exists(expanded_path) and confirm_deletion(expanded_path):
            try:
                if os.path.isfile(expanded_path):
                    os.remove(expanded_path)
                    log_and_print(f"{INFO} Deleted file: {expanded_path}", 'info')
                elif os.path.isdir(expanded_path):
                    shutil.rmtree(expanded_path)
                    log_and_print(f"{INFO} Deleted directory: {expanded_path}", 'info')
            except OSError as e:
                log_and_print(f"{FAILURE} Error deleting {expanded_path}: {e}", 'error')
    log_and_print(f"{SUCCESS} Unnecessary files cleaned up.", 'info')

def remove_old_ssh_known_hosts(log_file):
    """
    Remove old SSH known hosts entries.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    ssh_known_hosts_file = os.path.expanduser("~/.ssh/known_hosts")
    if os.path.isfile(ssh_known_hosts_file):
        log_and_print(f"{INFO} Removing old SSH known hosts entries...", 'info')
        try:
            subprocess.run(["sudo", "find", ssh_known_hosts_file, "-mtime", "+365", "-exec", "sed", "-i", "/^$/d", "{}", ";"], check=True)
            log_and_print(f"{SUCCESS} Old SSH known hosts entries removed.", 'info')
        except subprocess.CalledProcessError as e:
            log_and_print(f"{FAILURE} Error: Failed to remove old SSH known hosts entries: {e.stderr.strip()}", 'error')
    else:
        log_and_print(f"{INFO} No SSH known hosts file found. Skipping.", 'info')

def remove_orphan_vim_undo_files(log_file):
    """
    Remove orphan Vim undo files.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    log_and_print(f"{INFO} Searching for orphan Vim undo files...", 'info')
    home_dir = os.path.expanduser("~")
    for root, _, files in os.walk(home_dir):
        for file in files:
            if file.endswith(".un~"):
                original_file = os.path.splitext(os.path.join(root, file))[0]
                if not os.path.exists(original_file):
                    try:
                        os.remove(os.path.join(root, file))
                        log_and_print(f"{SUCCESS} Removed orphan Vim undo file: {file}", 'info')
                    except OSError as e:
                        log_and_print(f"{FAILURE} Error: Failed to remove orphan Vim undo file: {e}", 'error')

def force_log_rotation(log_file):
    """
    Force log rotation.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    log_and_print(f"{INFO} Forcing log rotation...", 'info')
    try:
        subprocess.run(["sudo", "logrotate", "-f", "/etc/logrotate.conf"], check=True)
        log_and_print(f"{SUCCESS} Log rotation forced.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error: Failed to force log rotation: {e.stderr.strip()}", 'error')

def configure_zram(log_file):
    """
    Configure ZRam for better memory management.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    log_and_print(f"INFO: Configuring ZRam for better memory management...", 'info')

    if shutil.which("zramctl"):
        try:
            # Calculate 25% of the total memory
            mem_total_cmd = "awk '/MemTotal/ {print int($2 * 1024 * 0.25)}' /proc/meminfo"
            mem_total_output = subprocess.check_output(mem_total_cmd, shell=True).strip()
            log_and_print(f"Memory calculation output: {mem_total_output}", 'info')
            mem_total = int(mem_total_output)
            log_and_print(f"Calculated ZRam size: {mem_total} bytes", 'info')

            try:
                # Find or create a new zram device with the specified size
                log_and_print("Attempting to find an existing zram device...", 'info')
                zram_device = subprocess.run(["sudo", "zramctl", "--find", "--size", str(mem_total)], 
                                             stdout=subprocess.PIPE, text=True, check=True).stdout.strip()
                log_and_print(f"Using existing zram device: {zram_device}", 'info')
            except subprocess.CalledProcessError:
                log_and_print("No free zram device found. Creating a new one...", 'info')
                subprocess.run(["sudo", "modprobe", "zram"], check=True)
                zram_device = subprocess.run(["sudo", "zramctl", "--find", "--size", str(mem_total)], 
                                             stdout=subprocess.PIPE, text=True, check=True).stdout.strip()
                log_and_print(f"Created new zram device: {zram_device}", 'info')

            # Set up the zram device as swap
            log_and_print(f"Setting up {zram_device} as swap...", 'info')
            subprocess.run(["sudo", "mkswap", zram_device], check=True)
            subprocess.run(["sudo", "swapon", zram_device, "-p", "32767"], check=True)

            log_and_print(f"SUCCESS: ZRam configured successfully on {zram_device} with size {mem_total} bytes.", 'info')
        except subprocess.CalledProcessError as e:
            log_and_print(f"FAILURE: Error configuring ZRam: {str(e)}", 'error')
    else:
        log_and_print("FAILURE: ZRam not available. Please install zramctl.", 'error')
        
def check_zram_configuration(log_file):
    """
    Check ZRam configuration and configure if not already set.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    log_and_print("INFO: Checking ZRam configuration...", 'info')
    
    try:
        zram_status = subprocess.check_output(["zramctl"], text=True).strip()
        
        if zram_status:
            log_and_print(f"SUCCESS: ZRam is configured. Current status:\n{zram_status}", 'info')
            
            # Optional: Further check if the ZRam is being used as swap
            swap_status = subprocess.check_output(["swapon", "--show"], text=True)
            if "/dev/zram" in swap_status:
                log_and_print(f"SUCCESS: ZRam is actively used as swap:\n{swap_status}", 'info')
            else:
                log_and_print("WARNING: ZRam device exists but is not used as swap.", 'warning')
        else:
            log_and_print("INFO: ZRam is not configured. Configuring now...", 'info')
            configure_zram(log_file)
            
    except subprocess.CalledProcessError as e:
        log_and_print(f"FAILURE: Error while checking ZRam configuration: {e}", 'error')
    except Exception as ex:
        log_and_print(f"FAILURE: Unexpected error: {str(ex)}", 'error')
        
def adjust_swappiness(log_file):
    """
    Adjust the swappiness value for better performance.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    swappiness_value = 10  # Recommended for systems with low RAM
    log_and_print(f"{INFO} Adjusting swappiness to {swappiness_value}...", 'info')
    try:
        subprocess.run(["sudo", "sysctl", f"vm.swappiness={swappiness_value}"], check=True)
        log_and_print(f"{SUCCESS} Swappiness adjusted to {swappiness_value}.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error: Failed to adjust swappiness: {e.stderr.strip()}", 'error')

def clear_system_cache(log_file):
    """
    Clear PageCache, dentries, and inodes.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    log_and_print(f"{INFO} Clearing PageCache, dentries, and inodes...", 'info')
    try:
        subprocess.run(["sudo", "sh", "-c", "echo 3 > /proc/sys/vm/drop_caches"], check=True)
        log_and_print(f"{SUCCESS} System caches cleared.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error: Failed to clear system cache: {e.stderr.strip()}", 'error')

def disable_unused_services(log_file):
    """
    Disable unused services to improve system performance.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    services_to_disable = ["bluetooth.service", "cups.service"]  # List of services to disable
    for service in services_to_disable:
        try:
            check_service = subprocess.run(["systemctl", "is-enabled", service], stdout=subprocess.PIPE, text=True)
            if check_service.returncode == 0:
                subprocess.run(["sudo", "systemctl", "disable", service], check=True)
                log_and_print(f"{SUCCESS} Disabled {service}.", 'info')
            else:
                log_and_print(f"{INFO} {service} is already disabled.", 'info')
        except subprocess.CalledProcessError as e:
            log_and_print(f"{FAILURE} Error: Failed to disable {service}: {e.stderr.strip()}", 'error')

def check_and_restart_systemd_units(log_file):
    """
    Check and restart failed systemd units.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    log_and_print(f"{INFO} Checking and restarting failed systemd units...", 'info')
    try:
        units = subprocess.check_output(["systemctl", "--failed"], text=True)
        if "0 loaded units listed" in units:
            log_and_print(f"{SUCCESS} No failed systemd units.", 'info')
        else:
            log_and_print(f"{INFO} Restarting failed systemd units...", 'info')
            subprocess.run(["sudo", "systemctl", "reset-failed"], check=True)
            log_and_print(f"{SUCCESS} Failed systemd units restarted.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error: Failed to check or restart systemd units: {e.stderr.strip()}", 'error')

def clean_package_cache(log_file):
    """
    Clean package cache using pacman.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    log_and_print(f"{INFO} Cleaning package cache...", 'info')
    spinner_thread, stop_spinner = spinner()  # Start the spinner

    try:
        subprocess.run(["sudo", "pacman", "-Sc", "--noconfirm"], check=True)
        log_and_print(f"{SUCCESS} Package cache cleaned.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error cleaning package cache: {e.stderr.strip()}", 'error')
    finally:
        stop_spinner()  # Ensure spinner is stopped

def run_all_tasks(log_file):
    """
    Run all maintenance tasks.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    for key in [str(k) for k in range(1, 27)]:
        try:
            menu_options[key]()
        except KeyError as e:
            log_and_print(format_message(f"Error executing task {key}: {e}", RED), 'error')

# Define menu options with partial
menu_options = {
    '1': partial(process_dep_scan_log, log_file_path),
    '2': partial(manage_cron_job, log_file_path),
    '3': partial(remove_broken_symlinks, log_file_path),
    '4': partial(clean_old_kernels, log_file_path),
    '5': partial(vacuum_journalctl, log_file_path),
    '6': partial(clear_cache, log_file_path),
    '7': partial(update_font_cache, log_file_path),
    '8': partial(clear_trash, log_file_path),
    '9': partial(optimize_databases, log_file_path),
    '10': partial(clean_package_cache, log_file_path),
    '11': partial(clean_aur_dir, log_file_path),
    '12': partial(handle_pacnew_pacsave, log_file_path),
    '13': partial(verify_installed_packages, log_file_path),
    '14': partial(check_failed_cron_jobs, log_file_path),
    '15': partial(clear_docker_images, log_file_path),
    '16': partial(clear_temp_folder, log_file_path),
    '17': partial(check_rmshit_script, log_file_path),
    '18': partial(remove_old_ssh_known_hosts, log_file_path),
    '19': partial(remove_orphan_vim_undo_files, log_file_path),
    '20': partial(force_log_rotation, log_file_path),
    '21': partial(configure_zram, log_file_path),
    '22': partial(check_zram_configuration, log_file_path),
    '23': partial(adjust_swappiness, log_file_path),
    '24': partial(clear_system_cache, log_file_path),
    '25': partial(disable_unused_services, log_file_path),
    '26': partial(check_and_restart_systemd_units, log_file_path),
    '0': partial(run_all_tasks, log_file_path)
}

# Main Menu
def main():
    """
    Display the main menu and handle user input.
    """
    while True:
        os.system('clear')
        print(f"===================================================================")
        print(f"    ================= {GREEN}// Vacuum Menu //{NC} =======================")
        print("===================================================================")
        print(f"{GREEN}1{NC}) Process Dependency Log              {GREEN}14{NC}) Check Failed Cron Jobs")
        print(f"{GREEN}2{NC}) Manage Cron Jobs                   {GREEN}15{NC}) Clear Docker Images")
        print(f"{GREEN}3{NC}) Remove Broken Symlinks             {GREEN}16{NC}) Clear Temp Folder")
        print(f"{GREEN}4{NC}) Clean Old Kernels                  {GREEN}17{NC}) Run rmshit.py")
        print(f"{GREEN}5{NC}) Vacuum Journalctl                  {GREEN}18{NC}) Remove Old SSH Known Hosts")
        print(f"{GREEN}6{NC}) Clear Cache                        {GREEN}19{NC}) Remove Orphan Vim Undo Files")
        print(f"{GREEN}7{NC}) Update Font Cache                  {GREEN}20{NC}) Force Log Rotation")
        print(f"{GREEN}8{NC}) Clear Trash                        {GREEN}21{NC}) Configure ZRam")
        print(f"{GREEN}9{NC}) Optimize Databases                 {GREEN}22{NC}) Check ZRam Configuration")
        print(f"{GREEN}10{NC}) Clean Package Cache               {GREEN}23{NC}) Adjust Swappiness")
        print(f"{GREEN}11{NC}) Clean AUR Directory               {GREEN}24{NC}) Clear System Cache")
        print(f"{GREEN}12{NC}) Handle Pacnew and Pacsave Files   {GREEN}25{NC}) Disable Unused Services")
        print(f"{GREEN}13{NC}) Verify Installed Packages         {GREEN}26{NC}) Fix Systemd Units")
        print(f"{GREEN}0{NC}) Run All Tasks                      {GREEN}Q{NC}) Quit")

        print(f"{GREEN}By your command:{NC}")

        command = input().strip().upper()

        if command in menu_options:
            try:
                menu_options[command]()
            except Exception as e:
                log_and_print(format_message(f"Error executing option: {e}", RED), 'error')
        elif command == 'Q':
            break
        else:
            log_and_print(format_message("Invalid choice. Please try again.", RED), 'error')

        input("Press Enter to continue...")

if __name__ == "__main__":
    main()
