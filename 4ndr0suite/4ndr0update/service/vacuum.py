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
import itertools
import threading
from functools import partial
from contextlib import contextmanager

# Set up basic logging configuration
log_dir = os.path.expanduser("~/.local/share/system_maintenance")
os.makedirs(log_dir, exist_ok=True)
log_file_path = os.path.join(log_dir, datetime.datetime.now().strftime("%Y%m%d_%H%M%S_system_maintenance.log"))
logging.basicConfig(filename=log_file_path, level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Colors and symbols
GREEN = '\033[38;2;57;255;20m'
BOLD = '\033[1m'
RED = '\033[0;31m'
NC = '\033[0m'  # No Color
SUCCESS = "✔️"
FAILURE = "❌"
INFO = "➡️"

COLORS = {
    "red": "\033[0;31m",
    "GREEN": "\033[38;2;57;255;20m",  # Soft green
    "cyan": "\033[38;2;21;255;255m",  # #15FFFF
    "yellow": "\033[0;33m",  # Yellow for warnings
    "bold": "\033[1m",
    "reset": "\033[0m",
}

# Spinner context manager
@contextmanager
def spinning_spinner(symbols='|/-\\', speed=0.1):
    """
    A context manager that manages a console spinner to indicate progress.
    The spinner automatically stops when the context is exited.
    
    Args:
        symbols (str): Symbols used for the spinner.
        speed (float): Speed of the spinner in seconds.
    """
    spinner_running = threading.Event()
    spinner_running.set()
    spinner_symbols = itertools.cycle(symbols)

    def spin():
        while spinner_running.is_set():
            sys.stdout.write(next(spinner_symbols) + '\r')
            sys.stdout.flush()
            time.sleep(speed)

    spinner_thread = threading.Thread(target=spin)
    spinner_thread.start()

    try:
        yield
    finally:
        spinner_running.clear()
        spinner_thread.join()
        sys.stdout.write(' ' * 10 + '\r')
        sys.stdout.flush()

# Custom spinner symbols (Dots is the default)
SPINNER_STYLES = {
    "dots": '⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏',
    "bars": '|/-\\',
    "arrows": '←↖↑↗→↘↓↙',
}

DEFAULT_SPINNER_STYLE = SPINNER_STYLES["dots"]

# Function to format messages with colors
def format_message(message, color):
    """
    Format a message with the given color and bold text.

    Args:
        message (str): The message to format.
        color (str): The ANSI color code to apply.

    Returns:
        str: The formatted message.
    """
    return f"{COLORS['bold']}{COLORS[color]}{message}{COLORS['reset']}"

# Function to log and print messages
def log_and_print(message, level='info'):
    """
    Print and log a message at the specified log level, with color formatting for the console.

    Args:
        message (str): The message to log and print.
        level (str): The log level ('info', 'error', 'warning'). Defaults to 'info'.
    """
    # Color-code based on the log level
    if level == 'info':
        print(format_message(message, color="cyan"))
        logging.info(message)
    elif level == 'error':
        print(format_message(message, color="red"))
        logging.error(message)
    elif level == 'warning':
        print(format_message(message, color="yellow"))
        logging.warning(message)
    else:
        print(format_message(f"Unhandled log level: {level}. Message: {message}", color="yellow"))
        logging.info(f"Unhandled log level: {level}. Message: {message}")

# Function to execute shell commands and handle errors
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
        result = subprocess.run(command, capture_output=True, text=True, check=True)
        logging.info(result.stdout)
        if result.stderr:
            logging.error(result.stderr)
        return result.stdout
    except subprocess.CalledProcessError as e:
        log_message = error_message or f"Command '{e.cmd}' failed with error: {e.stderr.strip()}"
        log_and_print(format_message(log_message, "red"), 'error')
        return None
    except Exception as e:
        log_message = error_message or f"Command execution failed with error: {str(e)}"
        log_and_print(format_message(log_message, "red"), 'error')
        return None

# Function to prompt user for input with a timeout
def prompt_with_timeout(prompt, timeout=10, default=None):
    """
    Prompt the user for input with a timeout.

    Args:
        prompt (str): The prompt message to display.
        timeout (int): The timeout duration in seconds.
        default: The default value to return if no input is provided within the timeout.

    Returns:
        str: The user input or the default value.
    """
    sys.stdout.write(prompt)
    sys.stdout.flush()
    ready, _, _ = select.select([sys.stdin], [], [], timeout)
    if ready:
        response = sys.stdin.readline().strip()
        if response:  # Ensure non-empty input
            return response
        else:
            return default
    else:
        return default

def confirm_deletion(file_or_dir, timeout=10, default_response='n'):
    """
    Ask for confirmation before deletion.

    Args:
        file_or_dir (str): The file or directory to confirm deletion for.
        timeout (int): The timeout duration for the prompt in seconds. Defaults to 10 seconds.
        default_response (str): The default response if the user does not provide input. Defaults to 'n'.

    Returns:
        bool: True if user confirms deletion, False otherwise.
    """
    colored_file_or_dir = format_message(file_or_dir, color="cyan")
    confirm = prompt_with_timeout(f"Do you really want to delete {colored_file_or_dir}? [y/N]: ", timeout=timeout, default=default_response).lower()

    if confirm == 'y':
        log_and_print(f"{format_message('Confirmed:', color='cyan')} Deleting {colored_file_or_dir}.", level='info')
        return True
    else:
        log_and_print(f"{format_message('Aborted:', color='red')} Deletion of {colored_file_or_dir}.", level='info')
        return False

def process_dep_scan_log(log_file="/usr/local/bin/dependency_scan.log", auto_resolve=False, verbose=True):
    """
    Process the dependency scan log to fix file permissions and install missing dependencies.
    The function will automatically fill in missing dependencies or fix permission issues from the previous scan.

    Args:
        log_file (str): Path to the log file where processing information is logged. Defaults to '/usr/local/bin/dependency_scan.log'.
        auto_resolve (bool): If True, automatically fix issues without user prompts.
        verbose (bool): If True, provides detailed output for each step taken.
    """
    
    # Start processing the log
    log_and_print(f"{INFO} Processing dependency scan log from {format_message(log_file, color='cyan')}...")
    
    # Check if the log file exists
    if os.path.isfile(log_file):
        missing_dependencies = set()  # Use a set to avoid duplicates
        permission_issues = []

        try:
            # Start spinner to show activity
            with spinning_spinner():
                with open(log_file, "r") as log:
                    for line in log:
                        # Check for permission warnings
                        if "permission warning" in line:
                            file_path = line.split(": ")[1].strip()
                            permission_issues.append(file_path)
                            if verbose:
                                log_and_print(f"{INFO} Permission issue found for {format_message(file_path, color='cyan')}", 'info')
                        
                        # Check for missing dependencies
                        elif "missing dependency" in line:
                            dependency = line.split(": ")[1].strip()
                            missing_dependencies.add(dependency)
                            if verbose:
                                log_and_print(f"{INFO} Missing dependency detected: {format_message(dependency, color='cyan')}", 'info')

            # Resolve permission issues
            if permission_issues:
                log_and_print(f"{INFO} Fixing permission issues...", 'info')
                for file_path in permission_issues:
                    if auto_resolve or confirm(f"Do you want to fix permissions for {format_message(file_path, color='cyan')}? [y/N] "):
                        fix_permissions(file_path)
                    else:
                        log_and_print(f"{FAILURE} Skipped permission fix for {file_path}", 'warning')

            # Resolve missing dependencies
            if missing_dependencies:
                log_and_print(f"{INFO} Installing missing dependencies...", 'info')
                for dependency in missing_dependencies:
                    if auto_resolve or confirm(f"Do you want to install the missing dependency {format_message(dependency, color='cyan')}? [y/N] "):
                        install_missing_dependency(dependency)
                    else:
                        log_and_print(f"{FAILURE} Skipped installation of {dependency}", 'warning')

            log_and_print(f"{SUCCESS} Dependency scan log processing completed.", 'info')

        # Handle any file I/O errors
        except IOError as e:
            log_and_print(f"{FAILURE} Error reading dependency scan log: {e}", 'error')
    else:
        log_and_print(f"{FAILURE} Dependency scan log file not found at {format_message(log_file, color='cyan')}.", 'error')

# Helper function to confirm an action
def confirm(prompt):
    response = prompt_with_timeout(prompt, timeout=10, default='n').lower()
    return response == 'y'

def fix_permissions(package_name=None):
    """
    Fix the permissions for files installed by a given pacman package or all installed packages.

    Args:
        package_name (str, optional): The name of the package whose file permissions need to be fixed.
                                      If None, it runs for all installed packages.

    Returns:
        bool: True if permissions were successfully fixed, False otherwise.
    """
    try:
        # If no package is provided, fix permissions for all installed packages
        if not package_name:
            log_and_print(f"{INFO} No package specified. Running for all installed packages...", 'info')
            package_list_cmd = ["pacman", "-Qq"]
            package_output = subprocess.run(package_list_cmd, capture_output=True, text=True, check=True)
            packages = package_output.stdout.strip().splitlines()
        else:
            packages = [package_name]

        # Loop through each package
        for pkg in packages:
            log_and_print(f"{INFO} Fetching file list and expected permissions for {format_message(pkg, 'cyan')}...", 'info')

            # Retrieve list of files installed by the package
            pacman_cmd = ["pacman", "-Qlq", pkg]  
            pacman_output = subprocess.run(pacman_cmd, capture_output=True, text=True, check=True)
            files = pacman_output.stdout.strip().splitlines()

            for file in files:
                # Check permission status using pacman
                pacman_permissions_cmd = ["pacman", "-Qkk", pkg]
                permission_check = subprocess.run(pacman_permissions_cmd, capture_output=True, text=True, check=True)
                permission_output = permission_check.stdout.strip()

                # If permission mismatch found, fix the permissions
                if "Permissions mismatch" in permission_output:
                    log_and_print(f"{INFO} Permission mismatch detected for {format_message(file, 'cyan')}...", 'info')

                    # Reset permissions to match defaults
                    subprocess.run(["sudo", "chmod", "--reference", file, file], check=True)
                    log_and_print(f"{SUCCESS} Permissions reset for {format_message(file, 'cyan')}.", 'info')

        return True

    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Failed to fix permissions: {e.stderr.strip()}", 'error')
        return False
    except Exception as e:
        log_and_print(f"{FAILURE} Unexpected error: {str(e)}", 'error')
        return False

def install_missing_dependency(dependency, interactive=False):
    """
    Install the missing dependency using the package manager, with optional interactive mode.

    Args:
        dependency (str): Name of the missing dependency.
        interactive (bool): If True, prompt the user before installing the dependency.
    """
    log_and_print(f"{INFO} Attempting to verify or install missing dependency: {format_message(dependency, '#15FFFF')}", 'info')

    try:
        # Check if the package is installed
        check_installation_cmd = ["sudo", "pacman", "-Qi", dependency]
        result = subprocess.run(check_installation_cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            # If installed, check file integrity and update the package if needed
            log_and_print(f"{INFO} {format_message(dependency, '#15FFFF')} is installed. Verifying file integrity...", 'info')

            integrity_check_cmd = ["sudo", "pacman", "-Qkk", dependency]
            integrity_result = subprocess.run(integrity_check_cmd, capture_output=True, text=True)

            if "0 missing files" not in integrity_result.stdout:
                log_and_print(f"{WARN} Missing or mismatched files detected for {format_message(dependency, '#15FFFF')}. Reinstalling package...", 'warning')
                
                # Reinstall the package if integrity issues are found
                reinstall_cmd = ["sudo", "pacman", "-S", "--noconfirm", "--needed", dependency]
                reinstall_result = subprocess.run(reinstall_cmd, capture_output=True, text=True)

                if reinstall_result.returncode == 0:
                    log_and_print(f"{SUCCESS} Successfully reinstalled {format_message(dependency, '#15FFFF')} to fix integrity issues.", 'info')
                else:
                    log_and_print(f"{FAILURE} Failed to reinstall {format_message(dependency, '#15FFFF')}.", 'error')
            else:
                log_and_print(f"{SUCCESS} {format_message(dependency, '#15FFFF')} passed integrity check. No issues found.", 'info')

            # Ensure the package is fully up to date
            log_and_print(f"{INFO} Ensuring {format_message(dependency, '#15FFFF')} is up to date...", 'info')
            update_cmd = ["sudo", "pacman", "-Sy", "--noconfirm", dependency]
            update_result = subprocess.run(update_cmd, capture_output=True, text=True)
            
            if update_result.returncode == 0:
                log_and_print(f"{SUCCESS} {format_message(dependency, '#15FFFF')} is up to date.", 'info')
            else:
                log_and_print(f"{FAILURE} Failed to update {format_message(dependency, '#15FFFF')}.", 'error')

        else:
            # If not installed, check if it's an AUR package and handle installation accordingly
            log_and_print(f"{INFO} {format_message(dependency, '#15FFFF')} is not installed. Installing...", 'info')
            
            if interactive:
                user_input = input(f"Do you want to install {format_message(dependency, '#15FFFF')}? [y/N]: ").strip().lower()
                if user_input != 'y':
                    log_and_print(f"{INFO} Installation of {format_message(dependency, '#15FFFF')} canceled by user.", 'info')
                    return

            # Attempt to install the package via pacman or AUR helper
            install_cmd = ["sudo", "pacman", "-S", "--noconfirm", dependency]
            install_result = subprocess.run(install_cmd, capture_output=True, text=True)

            if install_result.returncode == 0:
                log_and_print(f"{SUCCESS} Successfully installed {format_message(dependency, '#15FFFF')}.", 'info')
            else:
                log_and_print(f"{FAILURE} Failed to install {format_message(dependency, '#15FFFF')} via pacman. Checking AUR...", 'error')
                
                if check_aur_helper_installed():
                    aur_install_result = install_aur_package(dependency)
                    if aur_install_result:
                        log_and_print(f"{SUCCESS} Successfully installed {format_message(dependency, '#15FFFF')} from AUR.", 'info')
                    else:
                        log_and_print(f"{FAILURE} Failed to install {format_message(dependency, '#15FFFF')} from AUR.", 'error')
                else:
                    log_and_print(f"{FAILURE} No AUR helper found. Cannot install {format_message(dependency, '#15FFFF')}.", 'error')

    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error occurred during installation or verification: {str(e)}", 'error')

# Utility function to check if an AUR helper is installed
def check_aur_helper_installed():
    """
    Check if an AUR helper is installed (yay, paru, or trizen).

    Returns:
        bool: True if an AUR helper is found, False otherwise.
    """
    aur_helpers = ["yay", "paru", "trizen"]
    for helper in aur_helpers:
        if shutil.which(helper):
            log_and_print(f"{INFO} AUR helper {format_message(helper, '#15FFFF')} found.", 'info')
            return True
    log_and_print(f"{FAILURE} No AUR helper found.", 'error')
    return False

# Utility function to install an AUR package
def install_aur_package(dependency):
    """
    Attempt to install a package from AUR using the available AUR helper.

    Args:
        dependency (str): Name of the AUR package to install.

    Returns:
        bool: True if the package was successfully installed, False otherwise.
    """
    aur_helpers = ["yay", "paru", "trizen"]
    for helper in aur_helpers:
        if shutil.which(helper):
            log_and_print(f"{INFO} Installing {format_message(dependency, '#15FFFF')} from AUR using {format_message(helper, '#15FFFF')}...", 'info')
            install_cmd = [helper, "-S", "--noconfirm", dependency]
            result = subprocess.run(install_cmd, capture_output=True, text=True)
            return result.returncode == 0
    return False

def manage_cron_job(log_file):
    """
    Interactively manage system cron jobs, including viewing, adding, editing, and deleting.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    log_and_print(f"{INFO} Managing system cron jobs...", 'info')
    
    try:
        # Backup existing cron jobs before making any changes
        backup_cron_jobs()

        # Retrieve current cron jobs
        result = subprocess.run(["sudo", "crontab", "-l"], capture_output=True, text=True, check=True)
        existing_crons = result.stdout.strip().split('\n')

        if not existing_crons or existing_crons == ['']:
            log_and_print(f"{INFO} No existing cron jobs found.", 'info')
        else:
            log_and_print(f"{INFO} Existing cron jobs:", 'info')
            for i, cron in enumerate(existing_crons, 1):
                log_and_print(f"{i}. {format_message(cron, '#15FFFF')}", 'info')

        # Interactive options: Add, Edit, Delete
        choice = prompt_with_timeout(
            "Do you want to add, edit, or delete a cron job? (add/edit/delete): ", 
            timeout=10, default='skip').lower()

        if choice == "add":
            add_new_cron_job(existing_crons)
        elif choice == "edit":
            edit_cron_job(existing_crons)
        elif choice == "delete":
            delete_cron_job(existing_crons)
        else:
            log_and_print(f"{INFO} No changes made to cron jobs.", 'info')

    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error managing cron jobs: {e.stderr.strip()}", 'error')
    except Exception as ex:
        log_and_print(f"{FAILURE} Unexpected error: {str(ex)}", 'error')


# Helper function to backup cron jobs
def backup_cron_jobs():
    """
    Back up the current cron jobs before making any modifications.
    """
    backup_file = os.path.expanduser(f"~/.cron_backup_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.txt")
    try:
        result = subprocess.run(["sudo", "crontab", "-l"], capture_output=True, text=True, check=True)
        with open(backup_file, "w") as f:
            f.write(result.stdout)
        log_and_print(f"{SUCCESS} Cron jobs backed up to {backup_file}.", 'info')
    except subprocess.CalledProcessError:
        log_and_print(f"{FAILURE} Failed to back up cron jobs.", 'error')


# Helper function to add a new cron job
def add_new_cron_job(existing_crons):
    """
    Prompt the user to add a new cron job, validate the syntax, and update the cron job list.
    
    Args:
        existing_crons (list): List of current cron jobs.
    """
    new_cron = input("Enter the new cron job entry (e.g., '* * * * * command'): ").strip()
    if validate_cron_syntax(new_cron):
        existing_crons.append(new_cron)
        update_cron_jobs(existing_crons)
        log_and_print(f"{SUCCESS} New cron job added successfully.", 'info')
    else:
        log_and_print(f"{FAILURE} Invalid cron job syntax. Aborting addition.", 'error')


# Helper function to edit an existing cron job
def edit_cron_job(existing_crons):
    """
    Prompt the user to select and edit an existing cron job.
    
    Args:
        existing_crons (list): List of current cron jobs.
    """
    if not existing_crons or existing_crons == ['']:
        log_and_print(f"{INFO} No cron jobs to edit.", 'info')
        return

    for i, cron in enumerate(existing_crons, 1):
        log_and_print(f"{i}. {cron}", 'info')

    try:
        cron_to_edit = int(input(f"Enter the number of the cron job to edit (1-{len(existing_crons)}): ").strip())
        if 1 <= cron_to_edit <= len(existing_crons):
            new_cron = input(f"Editing cron job {cron_to_edit}. Enter new cron syntax: ").strip()
            if validate_cron_syntax(new_cron):
                existing_crons[cron_to_edit - 1] = new_cron
                update_cron_jobs(existing_crons)
                log_and_print(f"{SUCCESS} Cron job {cron_to_edit} updated successfully.", 'info')
            else:
                log_and_print(f"{FAILURE} Invalid cron syntax. Aborting edit.", 'error')
        else:
            log_and_print(f"{FAILURE} Invalid cron job selection.", 'error')
    except ValueError:
        log_and_print(f"{FAILURE} Invalid input. Please enter a valid number.", 'error')


# Helper function to delete a cron job
def delete_cron_job(existing_crons):
    """
    Prompt the user to select and delete an existing cron job.
    
    Args:
        existing_crons (list): List of current cron jobs.
    """
    if not existing_crons or existing_crons == ['']:
        log_and_print(f"{INFO} No cron jobs to delete.", 'info')
        return

    for i, cron in enumerate(existing_crons, 1):
        log_and_print(f"{i}. {cron}", 'info')

    try:
        cron_to_delete = int(input(f"Enter the number of the cron job to delete (1-{len(existing_crons)}): ").strip())
        if 1 <= cron_to_delete <= len(existing_crons):
            log_and_print(f"{INFO} Deleting cron job {cron_to_delete}: {existing_crons[cron_to_delete - 1]}", 'info')
            del existing_crons[cron_to_delete - 1]
            update_cron_jobs(existing_crons)
            log_and_print(f"{SUCCESS} Cron job {cron_to_delete} deleted successfully.", 'info')
        else:
            log_and_print(f"{FAILURE} Invalid cron job selection.", 'error')
    except ValueError:
        log_and_print(f"{FAILURE} Invalid input. Please enter a valid number.", 'error')


# Helper function to update cron jobs after changes
def update_cron_jobs(new_crons):
    """
    Update the system cron jobs with the new entries.

    Args:
        new_crons (list): The new cron jobs to set.
    """
    temp_file_path = os.path.expanduser("~/.cron_temp")
    try:
        with open(temp_file_path, "w") as temp_file:
            temp_file.write('\n'.join(new_crons) + '\n')
        subprocess.run(["sudo", "crontab", temp_file_path], check=True)
        log_and_print(f"{SUCCESS} Cron jobs updated successfully.", 'info')
    except Exception as e:
        log_and_print(f"{FAILURE} Error updating cron jobs: {str(e)}", 'error')
    finally:
        if os.path.exists(temp_file_path):
            os.remove(temp_file_path)


# Helper function to validate cron syntax
def validate_cron_syntax(cron_entry):
    """
    Validate the syntax of a cron job entry using regex.

    Args:
        cron_entry (str): The cron job entry to validate.

    Returns:
        bool: True if valid, False otherwise.
    """
    cron_pattern = r'^(\*|[0-5]?\d) (\*|[01]?\d|2[0-3]) (\*|[0-2]?\d|3[01]) (\*|[01]?\d|2[0-3]) (\*|[0-6]) .+$'
    if re.match(cron_pattern, cron_entry):
        log_and_print(f"{SUCCESS} Cron syntax validated for {format_message(cron_entry, '#15FFFF')}.", 'info')
        return True
    else:
        log_and_print(f"{FAILURE} Invalid cron syntax: {format_message(cron_entry, '#15FFFF')}.", 'error')
        return False

def remove_broken_symlinks(log_file):
    """
    Search for and remove broken symbolic links, with user confirmation and backup option.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    log_and_print(f"{INFO} Searching for broken symbolic links...", 'info')

    broken_links_backup = []
    
    with spinning_spinner():
        try:
            # Use parallelism to search for broken symlinks in specified directories
            search_dirs = SYMLINKS_CHECK  # List of directories to check, defined elsewhere
            broken_links = []
            
            # Search in parallel across directories
            def find_broken_symlinks(directory):
                try:
                    result = subprocess.check_output(["sudo", "find", directory, "-xtype", "l"], text=True)
                    broken_links.extend(result.splitlines())
                except subprocess.CalledProcessError:
                    log_and_print(f"{FAILURE} Failed to search for broken symlinks in {directory}.", 'error')

            threads = [threading.Thread(target=find_broken_symlinks, args=(dir_path,)) for dir_path in search_dirs]
            for t in threads:
                t.start()
            for t in threads:
                t.join()

            if broken_links:
                log_and_print(f"{INFO} Broken symbolic links found:", 'info')
                for i, link in enumerate(broken_links, 1):
                    log_and_print(f"{i}. {format_message(link, '#15FFFF')}", 'info')

                # Offer backup before deletion
                backup_choice = prompt_with_timeout("Do you want to back up the list of broken symlinks before deletion? [y/N]: ", timeout=10, default='n').lower()
                if backup_choice == 'y':
                    backup_broken_symlinks(broken_links)
                
                deleted_links = []
                for link in broken_links:
                    if confirm_deletion(link):
                        try:
                            os.remove(link)
                            log_and_print(f"{SUCCESS} Deleted broken symlink: {format_message(link, '#15FFFF')}", 'info')
                            deleted_links.append(link)
                        except OSError as e:
                            log_and_print(f"{FAILURE} Error deleting broken symlink {link}: {e}", 'error')

                log_and_print(f"{INFO} Summary of deleted broken symlinks:", 'info')
                for link in deleted_links:
                    log_and_print(f"{INFO} {link}", 'info')
            else:
                log_and_print(f"{SUCCESS} No broken symbolic links found.", 'info')

        except subprocess.CalledProcessError as e:
            log_and_print(f"{FAILURE} Error searching for broken symbolic links: {e.output.strip()}", 'error')


# Helper function to back up broken symlinks to a file
def backup_broken_symlinks(broken_links):
    """
    Backup the list of broken symlinks to a file for reference before deletion.

    Args:
        broken_links (list): List of broken symlink paths.
    """
    backup_file = os.path.expanduser(f"~/.broken_symlinks_backup_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.txt")
    try:
        with open(backup_file, "w") as f:
            for link in broken_links:
                f.write(f"{link}\n")
        log_and_print(f"{SUCCESS} Broken symlinks backed up to {backup_file}.", 'info')
    except Exception as e:
        log_and_print(f"{FAILURE} Failed to back up broken symlinks: {e}", 'error')

def clean_old_kernels(log_file):
    """
    Clean up old kernel images, with user confirmation and optional backup.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    log_and_print(f"{INFO} Cleaning up old kernel images...", 'info')

    with spinning_spinner():
        try:
            # Retrieve list of explicitly installed packages and the current running kernel
            explicitly_installed = subprocess.check_output(["pacman", "-Qet"], text=True).strip().split('\n')
            current_kernel = subprocess.check_output(["uname", "-r"], text=True).strip()
            current_kernel_major_version = '.'.join(current_kernel.split('.')[:2])

            kernels_to_remove = []

            for pkg in explicitly_installed:
                if "linux" in pkg:
                    pkg_name = pkg.split()[0]

                    # Skip the currently running kernel
                    if current_kernel_major_version not in pkg_name:
                        log_and_print(f"{INFO} Old kernel version detected: {format_message(pkg_name, '#15FFFF')}", 'info')
                        kernels_to_remove.append(pkg_name)

            if kernels_to_remove:
                log_and_print(f"{INFO} The following kernels can be removed:", 'info')
                for i, kernel in enumerate(kernels_to_remove, 1):
                    log_and_print(f"{i}. {format_message(kernel, '#15FFFF')}", 'info')

                # Backup option before removing old kernels
                backup_choice = prompt_with_timeout("Do you want to back up the old kernels before removal? [y/N]: ", timeout=10, default='n').lower()
                if backup_choice == 'y':
                    backup_old_kernels(kernels_to_remove)

                confirm = prompt_with_timeout(f"Do you want to remove these old kernels? [y/N]: ", timeout=10, default='n').lower()
                if confirm == 'y':
                    subprocess.run(["sudo", "pacman", "-Rns"] + kernels_to_remove, check=True)
                    log_and_print(f"{SUCCESS} Old kernel images cleaned up: {', '.join(kernels_to_remove)}", 'info')
                else:
                    log_and_print(f"{INFO} Kernel cleanup canceled by user.", 'info')
            else:
                log_and_print(f"{INFO} No old kernel images to remove.", 'info')

        except subprocess.CalledProcessError as e:
            log_and_print(f"{FAILURE} Error: {e.stderr.strip()}", 'error')


# Helper function to back up old kernels before removal
def backup_old_kernels(kernels_to_remove):
    """
    Backup old kernels to a specified location before removal.

    Args:
        kernels_to_remove (list): List of old kernels to back up.
    """
    backup_dir = os.path.expanduser(f"~/old_kernel_backups_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}")
    os.makedirs(backup_dir, exist_ok=True)

    for kernel in kernels_to_remove:
        log_and_print(f"{INFO} Backing up {format_message(kernel, '#15FFFF')} to {backup_dir}", 'info')
        try:
            # Use rsync or cp to backup kernel-related files (initramfs, vmlinuz, etc.)
            kernel_files = subprocess.check_output(["find", "/boot", "-name", f"*{kernel}*"], text=True).strip().split('\n')
            for kernel_file in kernel_files:
                if kernel_file:
                    shutil.copy(kernel_file, backup_dir)
                    log_and_print(f"{SUCCESS} Backed up {format_message(kernel_file, '#15FFFF')}", 'info')
        except subprocess.CalledProcessError as e:
            log_and_print(f"{FAILURE} Error backing up kernel files for {kernel}: {e.stderr.strip()}", 'error')

def vacuum_journalctl(log_file):
    """
    Vacuum journalctl logs with options for time-based and size-based vacuuming, providing detailed output.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    log_and_print(f"{INFO} Vacuuming journalctl logs...", 'info')

    # Offer the user choices for vacuuming options
    vacuum_option = prompt_with_timeout(
        "Do you want to vacuum logs by (1) time (default: 1 day) or (2) size limit (e.g., 200M)? [1/2]: ",
        timeout=10,
        default='1'
    ).lower()

    with spinning_spinner():
        try:
            if vacuum_option == '1' or vacuum_option == '':
                # Time-based vacuum (default: logs older than 1 day)
                vacuum_time = prompt_with_timeout(
                    "Specify the time for vacuuming logs (e.g., 1d, 2h, 1w) [default: 1d]: ",
                    timeout=10,
                    default='1d'
                )
                log_and_print(f"{INFO} Vacuuming journalctl logs older than {format_message(vacuum_time, '#15FFFF')}...", 'info')
                result = subprocess.run(
                    ["sudo", "journalctl", f"--vacuum-time={vacuum_time}"], 
                    check=True, capture_output=True, text=True
                )

            elif vacuum_option == '2':
                # Size-based vacuum (e.g., limiting to 200M)
                vacuum_size = prompt_with_timeout(
                    "Specify the size limit for journalctl logs (e.g., 200M, 1G) [default: 200M]: ",
                    timeout=10,
                    default='200M'
                )
                log_and_print(f"{INFO} Vacuuming journalctl logs to reduce total size to {format_message(vacuum_size, '#15FFFF')}...", 'info')
                result = subprocess.run(
                    ["sudo", "journalctl", f"--vacuum-size={vacuum_size}"], 
                    check=True, capture_output=True, text=True
                )

            log_and_print(f"{SUCCESS} Journalctl vacuumed successfully. Details:\n{result.stdout.strip()}", 'info')

        except subprocess.CalledProcessError as e:
            log_and_print(f"{FAILURE} Error: Failed to vacuum journalctl logs: {e.stderr.strip()}", 'error')
        except Exception as e:
            log_and_print(f"{FAILURE} Unexpected error during journalctl vacuum: {str(e)}", 'error')

def clear_cache(log_file):
    """
    Clear various system caches such as package cache, browser cache, and font cache, logging success or failure.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    log_and_print(f"{INFO} Clearing system caches...", 'info')

    # Ask the user what type of caches they want to clear
    cache_options = {
        '1': "Clear Package Cache (Pacman)",
        '2': "Clear Browser Cache (Firefox, Chrome/Chromium)",
        '3': "Clear Font Cache",
        '4': "Clear All"
    }

    print("\nChoose the caches to clear:")
    for key, value in cache_options.items():
        print(f"{GREEN}{key}{NC}) {value}")

    cache_choice = prompt_with_timeout("Enter your choice [1-4]: ", timeout=10, default='1').strip()

    with spinning_spinner():
        try:
            # Option 1: Clear package cache
            if cache_choice == '1' or cache_choice == '4':
                log_and_print(f"{INFO} Clearing package cache (Pacman)...", 'info')
                subprocess.run(["sudo", "pacman", "-Sc", "--noconfirm"], check=True)
                log_and_print(f"{SUCCESS} Package cache cleaned.", 'info')

            # Option 2: Clear browser cache (Firefox, Chrome/Chromium)
            if cache_choice == '2' or cache_choice == '4':
                browser_cache_dirs = [
                    os.path.expanduser("~/.cache/mozilla/firefox/"),
                    os.path.expanduser("~/.cache/google-chrome/"),
                    os.path.expanduser("~/.cache/chromium/")
                ]
                log_and_print(f"{INFO} Clearing browser cache (Firefox, Chrome/Chromium)...", 'info')
                for browser_dir in browser_cache_dirs:
                    if os.path.exists(browser_dir):
                        shutil.rmtree(browser_dir, ignore_errors=True)
                        log_and_print(f"{SUCCESS} Cleared cache for {format_message(browser_dir, '#15FFFF')}", 'info')
                    else:
                        log_and_print(f"{INFO} No cache found for {format_message(browser_dir, '#15FFFF')}", 'info')

            # Option 3: Clear font cache
            if cache_choice == '3' or cache_choice == '4':
                log_and_print(f"{INFO} Clearing font cache...", 'info')
                subprocess.run(["sudo", "fc-cache", "-fv"], check=True)
                log_and_print(f"{SUCCESS} Font cache updated successfully.", 'info')

            log_and_print(f"{SUCCESS} Cache clearing operation completed.", 'info')

        except subprocess.CalledProcessError as e:
            log_and_print(f"{FAILURE} Error clearing caches: {e.stderr.strip()}", 'error')
        except Exception as e:
            log_and_print(f"{FAILURE} Unexpected error during cache clearing: {str(e)}", 'error')

def clear_trash(log_file):
    """
    Automatically or interactively clear the trash system-wide, logging success or failure.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    log_and_print(f"{INFO} Clearing trash...", 'info')
    
    trash_paths = {
        'User Trash': os.path.expanduser("~/.local/share/Trash/*"),
        'Root Trash': "/root/.local/share/Trash/*",
        'Temporary Files': "/tmp/*"
    }

    # Ask for confirmation
    confirm = prompt_with_timeout("Do you want to clear trash directories? [y/N]: ", timeout=10, default='n').lower()
    if confirm != 'y':
        log_and_print(f"{INFO} Trash clearing aborted by user.", 'info')
        return

    # Offer the user granular control over which trash directories to clear
    print(f"{INFO} Choose the trash directories to clear (or press 0 to clear all):")
    for idx, (name, path) in enumerate(trash_paths.items(), 1):
        print(f"{idx}) {name} ({path})")
    print("0) Clear all")

    choice = prompt_with_timeout("Enter your choice [0-3]: ", timeout=10, default='0').strip()

    # Determine paths to clear based on user's choice
    if choice == '0':
        paths_to_clear = list(trash_paths.values())
    elif choice in ['1', '2', '3']:
        paths_to_clear = [list(trash_paths.values())[int(choice) - 1]]
    else:
        log_and_print(f"{FAILURE} Invalid selection. Aborting trash clearing.", 'error')
        return

    # Proceed with clearing the selected trash directories
    with spinning_spinner():
        for path in paths_to_clear:
            if os.path.exists(path):
                try:
                    subprocess.run(["sudo", "rm", "-rf", path], check=True)
                    log_and_print(f"{SUCCESS} Trash cleared for path: {format_message(path, '#15FFFF')}.", 'info')
                except subprocess.CalledProcessError as e:
                    log_and_print(f"{FAILURE} Error: Failed to clear trash for path {path}: {e.stderr.strip()}", 'error')
            else:
                log_and_print(f"{FAILURE} Path {format_message(path, '#15FFFF')} does not exist.", 'error')

def optimize_databases(log_file):
    """
    Optimize system databases with interactive options, logging success or failure for each step.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    log_and_print(f"{INFO} Optimizing system databases...", 'info')

    # Function to execute commands with retry logic
    def run_command(command, success_message, failure_message):
        max_retries = 3
        retry_count = 0

        while retry_count < max_retries:
            try:
                subprocess.run(command, check=True, capture_output=True, text=True)
                log_and_print(f"{SUCCESS} {success_message}", 'info')
                return
            except subprocess.CalledProcessError as e:
                retry_count += 1
                log_and_print(f"{FAILURE} {failure_message}: {e.stderr.strip()}", 'error')
                if retry_count < max_retries:
                    log_and_print(f"{INFO} Retrying ({retry_count}/{max_retries})...", 'info')

        log_and_print(f"{FAILURE} {failure_message} after {max_retries} attempts.", 'error')

    # Define a list of database operations
    db_operations = {
        '1': ("Update mlocate database", ["sudo", "updatedb"], "mlocate database updated.", "Failed to update mlocate database"),
        '2': ("Update pkgfile database", ["sudo", "pkgfile", "-u"], "pkgfile database updated.", "Failed to update pkgfile database"),
        '3': ("Upgrade pacman database", ["sudo", "pacman-db-upgrade"], "pacman database upgraded.", "Failed to upgrade pacman database"),
        '4': ("Clean package cache", ["sudo", "pacman", "-Sc"], "Package cache cleaned.", "Failed to clean package cache"),
        '5': ("Sync filesystem changes", ["sync"], "Filesystem changes synced.", "Failed to sync filesystem changes"),
        '6': ("Refresh pacman keys", ["sudo", "pacman-key", "--refresh-keys"], "Keys refreshed.", "Failed to refresh keys"),
        '7': ("Populate pacman keys and update trust", ["sudo", "pacman-key", "--populate"], "Keys populated.", "Failed to populate keys"),
        '8': ("Update pacman trust database", ["sudo", "pacman-key", "--updatedb"], "Trust database updated.", "Failed to update trust database"),
        '9': ("Refresh package list", ["sudo", "pacman", "-Syy"], "Package list refreshed.", "Failed to refresh package list")
    }

    # Provide options to the user
    print(f"\n{INFO} Select the databases to optimize (or press 0 to optimize all):")
    for key, (description, _, _, _) in db_operations.items():
        print(f"{key}) {description}")
    print(f"0) Run all optimizations")

    choice = prompt_with_timeout("Enter your choice [0-9]: ", timeout=10, default='0').strip()

    # Handle the selected operations or all optimizations
    with spinning_spinner():
        if choice == '0':
            # Run all optimizations in sequence
            for key, (description, command, success_message, failure_message) in db_operations.items():
                log_and_print(f"{INFO} {description}...", 'info')
                run_command(command, success_message, failure_message)
            log_and_print(f"{SUCCESS} All system databases optimized.", 'info')
        elif choice in db_operations:
            description, command, success_message, failure_message = db_operations[choice]
            log_and_print(f"{INFO} {description}...", 'info')
            run_command(command, success_message, failure_message)
        else:
            log_and_print(f"{FAILURE} Invalid choice. Aborting database optimization.", 'error')

def clean_aur_dir(log_file):
    """
    Clean the AUR directory, deleting only uninstalled or old versions of packages. 
    The function logs success or failure for each deletion.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    log_and_print(f"{INFO} Cleaning AUR directory...", 'info')

    try:
        # Detect the appropriate AUR helper (yay, paru, trizen)
        aur_helper = detect_aur_helper()

        # Get the AUR cache directory from the detected helper
        aur_cache_dir = subprocess.check_output([aur_helper, "-Qc"], text=True).strip()
        if not os.path.isdir(aur_cache_dir):
            log_and_print(f"{FAILURE} The specified path is not a valid directory: {aur_cache_dir}", 'error')
            return

        # Change to the AUR cache directory
        os.chdir(aur_cache_dir)

        # Define a regex to match package files in the cache directory
        pkgname_regex = re.compile(r'(?P<pkgname>.*?)-(?P<pkgver>[^-]+)-(?P<arch>x86_64|any|i686)\.pkg\.tar\.(xz|zst|gz|bz2|lrz|lzo|lz4|lz)$')

        # Collect the package files and their details
        files = {}
        for f in os.listdir():
            if not os.path.isfile(f):
                continue
            match = pkgname_regex.match(f)
            if match:
                files[f] = match.groupdict()

        # Get a list of installed AUR packages
        installed_packages = subprocess.check_output([aur_helper, "-Qm"], text=True).splitlines()
        installed = {pkg.split()[0]: pkg.split()[1] for pkg in installed_packages}

        # Track files to delete (either uninstalled or outdated)
        files_to_delete = []
        for f, file_info in files.items():
            pkgname = file_info['pkgname']
            pkgver = file_info['pkgver']
            if pkgname not in installed or pkgver != installed[pkgname]:
                files_to_delete.append(f)

        if not files_to_delete:
            log_and_print(f"{SUCCESS} No old or uninstalled packages found to clean.", 'info')
            return

        # Ask the user if they want to delete files one by one or all at once
        log_and_print(f"{INFO} Old or uninstalled package files found:", 'info')
        for i, file in enumerate(files_to_delete, 1):
            log_and_print(f"{i}) {file}", 'info')

        delete_choice = prompt_with_timeout("Do you want to delete (a)ll or (o)ne-by-one? [a/o]: ", timeout=10, default='a').lower()

        if delete_choice == 'a':
            # Delete all old/uninstalled packages in one go
            for file in files_to_delete:
                try:
                    os.remove(file)
                    log_and_print(f"{SUCCESS} Deleted: {file}", 'info')
                except OSError as e:
                    log_and_print(f"{FAILURE} Failed to delete {file}: {e}", 'error')
        elif delete_choice == 'o':
            # Delete files one by one interactively
            for file in files_to_delete:
                confirm = prompt_with_timeout(f"Delete {file}? [y/N]: ", timeout=10, default='n').lower()
                if confirm == 'y':
                    try:
                        os.remove(file)
                        log_and_print(f"{SUCCESS} Deleted: {file}", 'info')
                    except OSError as e:
                        log_and_print(f"{FAILURE} Failed to delete {file}: {e}", 'error')
                else:
                    log_and_print(f"{INFO} Skipped: {file}", 'info')
        else:
            log_and_print(f"{FAILURE} Invalid choice. No files were deleted.", 'error')

        log_and_print(f"{SUCCESS} AUR directory cleaned successfully.", 'info')

    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error: Failed to clean AUR directory: {e.stderr.strip()}", 'error')
    except Exception as e:
        log_and_print(f"{FAILURE} Unexpected error: {str(e)}", 'error')


def detect_aur_helper():
    """
    Detect the available AUR helper from the system (yay, paru, trizen, etc.).
    
    Returns:
        str: The detected AUR helper command (yay, paru, trizen).
    """
    aur_helpers = ["yay", "paru", "trizen"]
    for helper in aur_helpers:
        if shutil.which(helper):
            return helper
    raise Exception("No supported AUR helper found.")

def handle_pacnew_pacsave(log_file):
    """
    Handle .pacnew and .pacsave files, allowing the user to interactively choose to remove, skip, 
    or merge them with existing configuration files.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    log_and_print(f"{INFO} Handling .pacnew and .pacsave files...", 'info')

    try:
        # Find all .pacnew and .pacsave files in the /etc directory
        pacnew_files = subprocess.check_output(["sudo", "find", "/etc", "-type", "f", "-name", "*.pacnew"], text=True).splitlines()
        pacsave_files = subprocess.check_output(["sudo", "find", "/etc", "-type", "f", "-name", "*.pacsave"], text=True).splitlines()

        # Check if any files were found
        if not pacnew_files and not pacsave_files:
            log_and_print(f"{SUCCESS} No .pacnew or .pacsave files found.", 'info')
            return

        # Create a list to hold a summary of actions taken
        actions_summary = []

        # Ask the user for their preferred merge tool
        merge_tool = select_merge_tool()

        # Handle .pacnew files
        if pacnew_files:
            log_and_print(f"{INFO} Found .pacnew files:", 'info')
            for file in pacnew_files:
                log_and_print(f"{INFO} {file}", 'info')
                action = prompt_with_timeout(
                    f"Do you want to (m)erge, (r)emove, or (s)kip {file}? [m/r/s]: ",
                    timeout=15, default='s').lower()

                if action == 'm':
                    original_file = file.replace(".pacnew", "")
                    merge_files(file, original_file, merge_tool)
                    actions_summary.append(f"Merged .pacnew file: {file} with {original_file}")
                elif action == 'r':
                    os.remove(file)
                    log_and_print(f"{SUCCESS} Removed .pacnew file: {file}", 'info')
                    actions_summary.append(f"Removed .pacnew file: {file}")
                elif action == 's':
                    log_and_print(f"{INFO} Skipped .pacnew file: {file}", 'info')
                    actions_summary.append(f"Skipped .pacnew file: {file}")
                else:
                    log_and_print(f"{FAILURE} Invalid choice for {file}. Skipping...", 'error')
                    actions_summary.append(f"Skipped .pacnew file: {file}")

        # Handle .pacsave files
        if pacsave_files:
            log_and_print(f"{INFO} Found .pacsave files:", 'info')
            for file in pacsave_files:
                log_and_print(f"{INFO} {file}", 'info')
                action = prompt_with_timeout(
                    f"Do you want to (m)erge, (r)emove, or (s)kip {file}? [m/r/s]: ",
                    timeout=15, default='s').lower()

                if action == 'm':
                    original_file = file.replace(".pacsave", "")
                    merge_files(file, original_file, merge_tool)
                    actions_summary.append(f"Merged .pacsave file: {file} with {original_file}")
                elif action == 'r':
                    os.remove(file)
                    log_and_print(f"{SUCCESS} Removed .pacsave file: {file}", 'info')
                    actions_summary.append(f"Removed .pacsave file: {file}")
                elif action == 's':
                    log_and_print(f"{INFO} Skipped .pacsave file: {file}", 'info')
                    actions_summary.append(f"Skipped .pacsave file: {file}")
                else:
                    log_and_print(f"{FAILURE} Invalid choice for {file}. Skipping...", 'error')
                    actions_summary.append(f"Skipped .pacsave file: {file}")

        # Display the summary of actions taken
        log_and_print(f"{INFO} Summary of actions taken:", 'info')
        for action in actions_summary:
            log_and_print(f"{INFO} {action}", 'info')

    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error finding or handling .pacnew/.pacsave files: {e.stderr.strip()}", 'error')
    except Exception as e:
        log_and_print(f"{FAILURE} Unexpected error: {str(e)}", 'error')


def select_merge_tool():
    """
    Let the user choose a merge tool for handling .pacnew and .pacsave files. 
    Supports vimdiff, diffuse, and meld.

    Returns:
        str: The selected merge tool.
    """
    available_tools = ["vimdiff", "diffuse", "meld"]
    installed_tools = [tool for tool in available_tools if shutil.which(tool)]

    if not installed_tools:
        log_and_print(f"{FAILURE} No merge tools found. Please install vimdiff, diffuse, or meld.", 'error')
        return None

    if len(installed_tools) == 1:
        log_and_print(f"{INFO} Using default merge tool: {installed_tools[0]}", 'info')
        return installed_tools[0]

    # Prompt user to select a merge tool
    tool_selection = prompt_with_timeout(
        f"Select merge tool ({'/'.join(installed_tools)}): ", timeout=15, default=installed_tools[0]
    )

    if tool_selection in installed_tools:
        log_and_print(f"{INFO} Selected merge tool: {tool_selection}", 'info')
        return tool_selection
    else:
        log_and_print(f"{INFO} Invalid tool selection. Defaulting to {installed_tools[0]}.", 'info')
        return installed_tools[0]


def merge_files(new_file, original_file, merge_tool):
    """
    Allow the user to interactively merge the new configuration file (.pacnew or .pacsave) 
    with the original file using the selected merge tool.

    Args:
        new_file (str): The path to the .pacnew or .pacsave file.
        original_file (str): The path to the original file being replaced.
        merge_tool (str): The tool selected by the user for merging.
    """
    log_and_print(f"{INFO} Merging {new_file} into {original_file} using {merge_tool}...", 'info')

    try:
        subprocess.run([merge_tool, new_file, original_file], check=True)
        log_and_print(f"{SUCCESS} Merged {new_file} into {original_file} successfully.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error merging {new_file} into {original_file}: {e.stderr.strip()}", 'error')
    except Exception as e:
        log_and_print(f"{FAILURE} Unexpected error during merge: {str(e)}", 'error')

def verify_installed_packages(log_file):
    """
    Verify installed packages for missing files and automatically reinstall them, logging a summary of actions taken.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    log_and_print(f"{INFO} Checking for packages with missing files...", 'info')

    try:
        # Stop the spinner before prompting the user
        print(f"{format_message('Choose an option:', 'cyan')}\n1) Single package\n2) System-wide")
        choice = input(f"{format_message('Enter your choice (1 or 2):', 'cyan')} ").strip()

        # Validate the user's choice and set up the command
        if choice == "1":
            package = input(f"{format_message('Enter the package name to check:', 'cyan')} ").strip()
            if not package:
                log_and_print(f"{FAILURE} No package name provided. Exiting.", 'error')
                return
            command = f"pacman -Qk {package} | grep -v ' 0 missing files'"
        elif choice == "2":
            command = "pacman -Qk | grep -v ' 0 missing files' | awk '{print $1}'"
        else:
            log_and_print(f"{FAILURE} Invalid choice. Exiting.", 'error')
            return

        with spinning_spinner():
            result = subprocess.run(command, shell=True, capture_output=True, text=True)
            missing_packages = result.stdout.strip().split('\n')

            # Filter out empty lines and lines that aren't package names
            missing_packages = [pkg for pkg in missing_packages if pkg and not pkg.endswith(':')]

            if not missing_packages:
                log_and_print(f"{SUCCESS} No packages with missing files found.", 'info')
                return

            # Display the list of missing packages and confirm reinstallation
            log_and_print(f"{INFO} Packages with missing files detected:\n", 'info')
            for pkg in missing_packages:
                log_and_print(f" - {pkg}", 'info')

            confirm = prompt_with_timeout(f"Do you want to reinstall the packages with missing files? [y/N]: ", timeout=15, default='n').lower()
            if confirm == 'y':
                log_and_print(f"{INFO} Reinstalling packages with missing files...", 'info')
                reinstall_command = ["sudo", "pacman", "-S", "--noconfirm"] + missing_packages
                subprocess.run(reinstall_command, check=True)
                log_and_print(f"{SUCCESS} Packages reinstalled successfully.", 'info')
            else:
                log_and_print(f"{INFO} Package reinstallation skipped by user.", 'info')

    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error verifying installed packages: {e.stderr.strip() if e.stderr else e}", 'error')
    except Exception as e:
        log_and_print(f"{FAILURE} Unexpected error: {str(e)}", 'error')

def check_failed_cron_jobs(log_file):
    """
    Check for failed cron jobs by scanning system logs for cron-related errors, and optionally attempt to repair them.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    log_and_print(f"{INFO} Checking for failed cron jobs...", 'info')
    try:
        # Search system logs for any cron-related errors (cron errors are often found in syslog or journalctl)
        if os.path.exists("/var/log/syslog"):
            failed_jobs = subprocess.check_output(["grep", "-i", "cron.*error", "/var/log/syslog"], text=True)
        else:
            # Use journalctl if syslog is unavailable
            failed_jobs = subprocess.check_output(["sudo", "journalctl", "-u", "cron", "-p", "err"], text=True)

        if failed_jobs.strip():
            log_and_print(f"{FAILURE} Failed cron jobs detected. Review logs for details.", 'error')
            log_and_print(f"{failed_jobs}", 'error')

            # Offer the user the option to attempt repair
            repair = prompt_with_timeout(f"Do you want to attempt to repair the failed cron jobs? [y/N]: ", timeout=15, default='n')
            if repair.lower() == "y":
                log_and_print(f"{INFO} Attempting to repair failed cron jobs...", 'info')
                repair_failed_cron_jobs()  # Helper function to restart cron jobs or fix errors
            else:
                log_and_print(f"{INFO} Cron job repair skipped by user.", 'info')
        else:
            log_and_print(f"{SUCCESS} No failed cron jobs detected.", 'info')

    except subprocess.CalledProcessError:
        log_and_print(f"{INFO} No failed cron jobs detected or syslog not accessible.", 'info')
    except Exception as ex:
        log_and_print(f"{FAILURE} Unexpected error while checking cron jobs: {str(ex)}", 'error')


def repair_failed_cron_jobs():
    """
    Helper function to attempt repairing failed cron jobs.
    Restarts the cron service and resets any failed systemd units related to cron.
    """
    try:
        log_and_print(f"{INFO} Restarting the cron service...", 'info')
        subprocess.run(["sudo", "systemctl", "restart", "cron"], check=True)
        log_and_print(f"{SUCCESS} Cron service restarted successfully.", 'info')

        log_and_print(f"{INFO} Resetting failed cron-related systemd units...", 'info')
        subprocess.run(["sudo", "systemctl", "reset-failed", "cron"], check=True)
        log_and_print(f"{SUCCESS} Failed cron units reset.", 'info')

    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Failed to repair cron jobs: {e.stderr.strip()}", 'error')
    except Exception as e:
        log_and_print(f"{FAILURE} Unexpected error during cron repair: {str(e)}", 'error')

def clear_docker_images(log_file):
    """
    Clear Docker images if Docker is installed. Provides options for clearing all images or only unused ones.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    if shutil.which("docker"):
        log_and_print(f"{INFO} Docker detected. Preparing to clean Docker images...", 'info')

        # Check if there are any Docker images to prune
        try:
            # List all existing Docker images
            result = subprocess.run(["sudo", "docker", "image", "ls", "-a"], capture_output=True, text=True, check=True)
            if not result.stdout.strip():
                log_and_print(f"{SUCCESS} No Docker images found to clean.", 'info')
                return
            else:
                log_and_print(f"{INFO} Existing Docker images:\n{result.stdout}", 'info')

            # Ask the user if they want to remove all images or only unused ones
            prune_option = prompt_with_timeout(
                "Do you want to remove all Docker images (a) or only unused ones (u)? [a/u/N]: ", timeout=10, default='n'
            ).lower()

            if prune_option == 'a':
                log_and_print(f"{INFO} Removing all Docker images...", 'info')
                prune_command = ["sudo", "docker", "image", "prune", "-af"]
            elif prune_option == 'u':
                log_and_print(f"{INFO} Removing only unused Docker images...", 'info')
                prune_command = ["sudo", "docker", "image", "prune", "-f"]
            else:
                log_and_print(f"{INFO} Docker image cleanup canceled by user.", 'info')
                return

            # Run the prune command based on user input
            with spinning_spinner():
                subprocess.run(prune_command, check=True)

            log_and_print(f"{SUCCESS} Docker image cleanup completed successfully.", 'info')

        except subprocess.CalledProcessError as e:
            log_and_print(f"{FAILURE} Error clearing Docker images: {e.stderr.strip()}", 'error')
    else:
        log_and_print(f"{INFO} Docker is not installed. Skipping Docker image cleanup.", 'info')

def clear_temp_folder(log_file):
    """
    Clear the temporary folder by removing files older than a certain number of days (default: 2).
    Provides user options to choose the age of files to delete. Logs success or failure.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    log_and_print(f"{INFO} Preparing to clear the temporary folder...", 'info')

    try:
        # Allow the user to customize the age of files to delete, with a default of 2 days
        default_age = "2"
        file_age = prompt_with_timeout(
            f"Enter the minimum age (in days) of temp files to delete [default: {default_age}]: ", 
            timeout=10, default=default_age
        ).strip()

        if not file_age.isdigit() or int(file_age) < 1:
            log_and_print(f"{FAILURE} Invalid input. Defaulting to {default_age} days.", 'warning')
            file_age = default_age

        log_and_print(f"{INFO} Deleting files older than {format_message(file_age + ' days', 'cyan')} from /tmp...", 'info')

        # Command to delete temp files older than the specified number of days
        delete_command = ["sudo", "find", "/tmp", "-type", "f", "-atime", f"+{file_age}", "-delete"]

        # Running the command with a progress spinner
        with spinning_spinner():
            subprocess.run(delete_command, check=True)

        log_and_print(f"{SUCCESS} Temporary files older than {file_age} days have been deleted.", 'info')

    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error clearing the temporary folder: {e.stderr.strip()}", 'error')
    except Exception as e:
        log_and_print(f"{FAILURE} Unexpected error while clearing the temporary folder: {str(e)}", 'error')

def check_rmshit_script(log_file=None, no_confirm=False, dry_run=False):
    """
    Clean up unnecessary files specified in the script or additional user-specified paths.

    Args:
        log_file (str): Path to the log file where processing information is logged.
        no_confirm (bool): If True, skip confirmation prompts for file deletion.
        dry_run (bool): If True, perform a dry run where no files are actually deleted.
    """
    log_and_print(f"{INFO} Cleaning up unnecessary files...", 'info')
    
    # List of predefined paths to clean
    default_files = [
        '~/.adobe', '~/.macromedia', '~/.FRD/log/app.log', '~/.FRD/links.txt',
        '~/.objectdb', '~/.gstreamer-0.10', '~/.pulse', '~/.esd_auth',
        '~/.config/enchant', '~/.spicec', '~/.dropbox-dist', '~/.parallel',
        '~/.dbus', '~/.distlib/', '~/.bazaar/', '~/.bzr.log', '~/.nv/',
        '~/.viminfo', '~/.npm/', '~/.swt/', '~/.oracle_jre_usage/', '~/.jssc/',
        '~/.tox/', '~/.pylint.d/', '~/.qute_test/', '~/.QtWebEngineProcess/', 
        '~/.qutebrowser/', '~/.asy/', '~/.cmake/', '~/.cache/mozilla/', 
        '~/.cache/chromium/', '~/.cache/google-chrome/', '~/.cache/spotify/', 
        '~/.cache/steam/', '~/.zoom/', '~/.Skype/', '~/.minecraft/logs/',
        '~/.thumbnails/', '~/.local/share/Trash/', '~/.vim/.swp', '~/.vim/.backup',
        '~/.vim/.undo', '~/.emacs.d/auto-save-list/', '~/.cache/JetBrains/', 
        '~/.vscode/extensions/', '~/.npm/_logs/', '~/.npm/_cacache/', '~/.composer/cache/',
        '~/.gem/cache/', '~/.cache/pip/', '~/.gnupg/', '~/.wget-hsts', '~/.docker/', 
        '~/.local/share/baloo/', '~/.kde/share/apps/okular/docdata/', '~/.local/share/akonadi/', 
        '~/.xsession-errors', '~/.cache/gstreamer-1.0/', '~/.cache/fontconfig/', '~/.cache/mesa/', 
        '~/.nv/ComputeCache/'
    ]

    # Ask user to input additional paths to clean
    new_paths = input("Enter any additional paths to clean (separated by space): ").split()
    
    # Expand user and environment variables in paths
    paths_to_clean = [os.path.expanduser(path) for path in default_files + new_paths]

    # Option for global confirmation
    if not no_confirm and not dry_run:
        confirm = prompt_with_timeout(
            f"Do you want to proceed with deleting {len(paths_to_clean)} paths? [y/N]: ", timeout=10, default='n'
        ).lower()
        if confirm != 'y':
            log_and_print(f"{INFO} Cleanup aborted by user.", 'info')
            return

    # Function to delete a path with optional dry run and error handling
    def delete_path(path):
        try:
            if dry_run:
                log_and_print(f"{INFO} Dry Run: Would delete {path}", 'info')
            else:
                if os.path.isfile(path):
                    os.remove(path)
                    log_and_print(f"{SUCCESS} Deleted file: {format_message(path, 'cyan')}", 'info')
                elif os.path.isdir(path):
                    shutil.rmtree(path)
                    log_and_print(f"{SUCCESS} Deleted directory: {format_message(path, 'cyan')}", 'info')
        except OSError as e:
            log_and_print(f"{FAILURE} Error deleting {format_message(path, 'cyan')}: {e}", 'error')

    # Iterate over paths and delete each
    for path in paths_to_clean:
        if os.path.exists(path):
            if no_confirm or dry_run:
                delete_path(path)
            else:
                confirm = prompt_with_timeout(
                    f"Do you really want to delete {format_message(path, 'cyan')}? [y/N]: ", timeout=10, default='n'
                ).lower()
                if confirm == 'y':
                    delete_path(path)
                else:
                    log_and_print(f"{INFO} Skipped {format_message(path, 'cyan')}", 'info')
        else:
            log_and_print(f"{WARNING} Path not found: {format_message(path, 'cyan')}", 'warning')

    log_and_print(f"{SUCCESS} Unnecessary files cleaned up.", 'info')

def remove_old_ssh_known_hosts(log_file=None, days=365, interactive=False, dry_run=False):
    """
    Remove old SSH known hosts entries.

    Args:
        log_file (str): Path to the log file where processing information is logged.
        days (int): Number of days old an entry should be before it's considered for removal.
        interactive (bool): If True, prompts the user for confirmation before deleting each entry.
        dry_run (bool): If True, lists entries that would be removed without deleting them.
    """
    ssh_known_hosts_file = os.path.expanduser("~/.ssh/known_hosts")
    
    if not os.path.isfile(ssh_known_hosts_file):
        log_and_print(f"{INFO} No SSH known_hosts file found. Skipping.", 'info')
        return

    log_and_print(f"{INFO} Removing SSH known_hosts entries older than {days} days...", 'info')
    
    # Backup the known_hosts file
    backup_file = ssh_known_hosts_file + f".backup_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}"
    try:
        shutil.copy2(ssh_known_hosts_file, backup_file)
        log_and_print(f"{SUCCESS} Backup created: {format_message(backup_file, 'cyan')}", 'info')
    except OSError as e:
        log_and_print(f"{FAILURE} Failed to create backup of known_hosts: {e}", 'error')
        return

    # Prepare command to filter old entries
    find_command = f"sudo find {ssh_known_hosts_file} -mtime +{days}"

    try:
        with spinning_spinner():
            result = subprocess.run(find_command.split(), capture_output=True, text=True, check=True)
            old_entries = result.stdout.strip().split('\n')
            
            if not old_entries or all(not entry.strip() for entry in old_entries):
                log_and_print(f"{INFO} No old SSH known_hosts entries older than {days} days found.", 'info')
                return
            
            # Dry run: show what would be deleted
            if dry_run:
                log_and_print(f"{INFO} Dry Run: The following entries would be deleted:\n", 'info')
                for entry in old_entries:
                    log_and_print(f"{INFO} {entry}", 'info')
                return

            # Process each old entry for deletion
            for entry in old_entries:
                if interactive:
                    confirm = prompt_with_timeout(
                        f"Do you want to remove {format_message(entry, 'cyan')}? [y/N]: ", timeout=10, default='n'
                    ).lower()
                    if confirm != 'y':
                        log_and_print(f"{INFO} Skipping {format_message(entry, 'cyan')}", 'info')
                        continue
                
                try:
                    os.remove(entry)
                    log_and_print(f"{SUCCESS} Removed old SSH known_hosts entry: {format_message(entry, 'cyan')}", 'info')
                except OSError as e:
                    log_and_print(f"{FAILURE} Failed to remove {format_message(entry, 'cyan')}: {e}", 'error')
    
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error processing SSH known_hosts: {e.stderr.strip()}", 'error')

def remove_orphan_vim_undo_files(log_file=None, custom_dir=None, interactive=False, dry_run=False):
    """
    Remove orphan Vim undo files (.un~) in the user's home directory (or a custom directory).
    Orphan undo files are those for which the original file no longer exists.

    Args:
        log_file (str): Path to the log file where processing information is logged.
        custom_dir (str, optional): Custom directory to search for orphan Vim undo files. Defaults to None (user's home).
        interactive (bool): If True, prompts the user for confirmation before deleting each orphan undo file.
        dry_run (bool): If True, lists the orphan undo files that would be removed without actually deleting them.
    """
    # Use home directory or custom directory if provided
    search_dir = os.path.expanduser("~") if not custom_dir else os.path.expanduser(custom_dir)
    
    log_and_print(f"{INFO} Searching for orphan Vim undo files in {format_message(search_dir, 'cyan')}...", 'info')

    # Backup directory for orphan undo files
    backup_dir = os.path.join(search_dir, "vim_undo_backups")
    os.makedirs(backup_dir, exist_ok=True)

    with spinning_spinner():
        try:
            orphan_files = []
            for root, _, files in os.walk(search_dir):
                for file in files:
                    if file.endswith(".un~"):
                        original_file = os.path.splitext(os.path.join(root, file))[0]
                        if not os.path.exists(original_file):
                            orphan_files.append(os.path.join(root, file))

            if not orphan_files:
                log_and_print(f"{INFO} No orphan Vim undo files found.", 'info')
                return

            # Dry run: show what would be deleted
            if dry_run:
                log_and_print(f"{INFO} Dry Run: The following orphan undo files would be deleted:\n", 'info')
                for orphan in orphan_files:
                    log_and_print(f"{INFO} {orphan}", 'info')
                return

            # Process each orphan undo file
            for orphan in orphan_files:
                if interactive:
                    confirm = prompt_with_timeout(
                        f"Do you want to remove {format_message(orphan, 'cyan')}? [y/N]: ", timeout=10, default='n'
                    ).lower()
                    if confirm != 'y':
                        log_and_print(f"{INFO} Skipping {format_message(orphan, 'cyan')}", 'info')
                        continue

                try:
                    # Backup the orphan file
                    shutil.copy2(orphan, os.path.join(backup_dir, os.path.basename(orphan)))
                    log_and_print(f"{INFO} Backup created for {format_message(orphan, 'cyan')} at {backup_dir}.", 'info')

                    # Remove the orphan undo file
                    os.remove(orphan)
                    log_and_print(f"{SUCCESS} Removed orphan Vim undo file: {format_message(orphan, 'cyan')}.", 'info')
                except OSError as e:
                    log_and_print(f"{FAILURE} Failed to remove {format_message(orphan, 'cyan')}: {e}", 'error')

            log_and_print(f"{SUCCESS} Orphan Vim undo file cleanup completed.", 'info')

        except Exception as e:
            log_and_print(f"{FAILURE} Error during orphan Vim undo file cleanup: {str(e)}", 'error')

def force_log_rotation(log_file, custom_conf=None, verbose=False, dry_run=False, interactive=False):
    """
    Force log rotation with optional configurations and modes.

    Args:
        log_file (str): Path to the log file where processing information is logged.
        custom_conf (str, optional): Path to a custom logrotate configuration file. Defaults to /etc/logrotate.conf.
        verbose (bool, optional): If True, enables verbose output during log rotation.
        dry_run (bool, optional): If True, simulates the log rotation without making any changes.
        interactive (bool, optional): If True, prompts the user to select the logrotate configuration file.
    """
    # Default logrotate configuration
    logrotate_conf = custom_conf or "/etc/logrotate.conf"

    log_and_print(f"{INFO} Forcing log rotation...", 'info')

    # Check if logrotate is installed
    if not shutil.which("logrotate"):
        log_and_print(f"{FAILURE} logrotate is not installed. Attempting to install...", 'error')
        try:
            subprocess.run(["sudo", "pacman", "-S", "--noconfirm", "logrotate"], check=True)
            log_and_print(f"{SUCCESS} logrotate successfully installed.", 'info')
        except subprocess.CalledProcessError:
            log_and_print(f"{FAILURE} Failed to install logrotate. Exiting...", 'error')
            return

    # Check for available logrotate configurations
    if interactive:
        conf_files = ["/etc/logrotate.conf"]
        if os.path.exists("/etc/logrotate.d"):
            conf_files += [os.path.join("/etc/logrotate.d", f) for f in os.listdir("/etc/logrotate.d")]

        log_and_print(f"{INFO} Available logrotate configurations:", 'info')
        for idx, conf in enumerate(conf_files, 1):
            log_and_print(f"{idx}. {conf}", 'info')

        choice = prompt_with_timeout(f"Choose a configuration file to use (1-{len(conf_files)}): ", timeout=15, default="1")
        if choice.isdigit() and 1 <= int(choice) <= len(conf_files):
            logrotate_conf = conf_files[int(choice) - 1]
        else:
            log_and_print(f"{FAILURE} Invalid selection. Exiting...", 'error')
            return

    # Construct the logrotate command with options
    logrotate_cmd = ["sudo", "logrotate"]
    if dry_run:
        logrotate_cmd += ["-d"]  # Dry run option (simulate without changes)
    if verbose:
        logrotate_cmd += ["-v"]  # Verbose option
    logrotate_cmd += ["-f", logrotate_conf]

    # Run the logrotate command
    try:
        subprocess.run(logrotate_cmd, check=True)
        log_and_print(f"{SUCCESS} Log rotation forced using {format_message(logrotate_conf, 'cyan')}.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error: Failed to force log rotation: {e.stderr.strip()}", 'error')

def manage_zram(log_file, reconfigure=False):
    """
    Check ZRam configuration, and configure if not set up or if the user requests reconfiguration.

    Args:
        log_file (str): Path to the log file where processing information is logged.
        reconfigure (bool, optional): If True, reconfigures ZRam even if it's already set up.
    """
    log_and_print(f"{INFO} Checking ZRam configuration...", 'info')

    try:
        # Check ZRam status
        zram_status = subprocess.check_output(["zramctl"], text=True).strip()

        if zram_status:
            log_and_print(f"{SUCCESS} ZRam is configured. Current status:\n{zram_status}", 'info')

            swap_status = subprocess.check_output(["swapon", "--show"], text=True)
            if "/dev/zram" in swap_status:
                log_and_print(f"{SUCCESS} ZRam is actively used as swap:\n{swap_status}", 'info')
            else:
                log_and_print(f"{WARNING} ZRam device exists but is not used as swap.", 'warning')

            # Ask the user if they want to reconfigure
            if reconfigure or prompt_with_timeout("Do you want to reconfigure ZRam? [y/N]: ", default="n").lower() == 'y':
                log_and_print(f"{INFO} Reconfiguring ZRam...", 'info')
                configure_zram()
            else:
                log_and_print(f"{INFO} No changes made to ZRam configuration.", 'info')

        else:
            log_and_print(f"{INFO} ZRam is not configured. Configuring now...", 'info')
            configure_zram()

    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error while checking ZRam configuration: {e}", 'error')
    except Exception as ex:
        log_and_print(f"{FAILURE} Unexpected error: {str(ex)}", 'error')

def configure_zram():
    """
    Configure ZRam for better memory management and swap usage.
    """
    log_and_print(f"{INFO} Configuring ZRam for better memory management...", 'info')

    if shutil.which("zramctl"):
        try:
            # Calculate 25% of total memory for ZRam size
            mem_total_cmd = "awk '/MemTotal/ {print int($2 * 1024 * 0.25)}' /proc/meminfo"
            mem_total_output = subprocess.check_output(mem_total_cmd, shell=True).strip()
            mem_total = int(mem_total_output)
            log_and_print(f"Calculated ZRam size: {format_message(str(mem_total), '#15FFFF')} bytes", 'info')

            # Find or create the ZRam device
            try:
                log_and_print(f"Attempting to find an existing ZRam device...", 'info')
                zram_device = subprocess.run(["sudo", "zramctl", "--find", "--size", str(mem_total)],
                                             stdout=subprocess.PIPE, text=True, check=True).stdout.strip()
                log_and_print(f"{INFO} Using existing ZRam device: {zram_device}", 'info')
            except subprocess.CalledProcessError:
                log_and_print(f"No free ZRam device found. Creating a new one...", 'info')
                subprocess.run(["sudo", "modprobe", "zram"], check=True)
                zram_device = subprocess.run(["sudo", "zramctl", "--find", "--size", str(mem_total)],
                                             stdout=subprocess.PIPE, text=True, check=True).stdout.strip()
                log_and_print(f"{SUCCESS} Created new ZRam device: {zram_device}", 'info')

            # Set up ZRam as swap
            log_and_print(f"Setting up {format_message(zram_device, '#15FFFF')} as swap...", 'info')
            subprocess.run(["sudo", "mkswap", zram_device], check=True)
            subprocess.run(["sudo", "swapon", zram_device, "-p", "32767"], check=True)

            log_and_print(f"{SUCCESS} ZRam configured successfully on {zram_device} with size {format_message(str(mem_total), '#15FFFF')} bytes.", 'info')
        except subprocess.CalledProcessError as e:
            log_and_print(f"{FAILURE} Error configuring ZRam: {str(e)}", 'error')
    else:
        log_and_print(f"{FAILURE} ZRam is not available. Please install zramctl.", 'error')

def adjust_swappiness(log_file):
    """
    Adjust the swappiness value for better performance. The swappiness will always be set to 10.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    swappiness_value = 10
    log_and_print(f"{INFO} Adjusting swappiness to {format_message(str(swappiness_value), 'cyan')}...", 'info')
    try:
        subprocess.run(["sudo", "sysctl", f"vm.swappiness={swappiness_value}"], check=True)
        log_and_print(f"{SUCCESS} Swappiness adjusted to {format_message(str(swappiness_value), 'cyan')}.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error: Failed to adjust swappiness: {e.stderr.strip()}", 'error')

def disable_unused_services(log_file):
    """
    Disable unused services to improve system performance, including sshd.

    Args:
        log_file (str): Path to the log file where processing information is logged.
    """
    services_to_disable = [
        "bluetooth.service",
        "cups.service",
        "geoclue.service",  # GPS-related services
        "avahi-daemon.service",
        "sshd.service"  # Added sshd service
    ]
    
    for service in services_to_disable:
        try:
            check_service = subprocess.run(
                ["systemctl", "is-enabled", service], stdout=subprocess.PIPE, text=True
            )
            if check_service.returncode == 0:
                subprocess.run(["sudo", "systemctl", "disable", service], check=True)
                subprocess.run(["sudo", "systemctl", "stop", service], check=True)
                subprocess.run(["sudo", "systemctl", "mask", service], check=True)
                log_and_print(f"{SUCCESS} Disabled and masked {format_message(service, '#15FFFF')}.", 'info')
            else:
                log_and_print(f"{INFO} {service} is already disabled.", 'info')
        except subprocess.CalledProcessError as e:
            log_and_print(f"{FAILURE} Error: Failed to disable {format_message(service, '#15FFFF')}: {e.stderr.strip()}", 'error')

def run_all_tasks(log_file):
    """
    Run all maintenance tasks sequentially, or optionally in parallel.
    Logs results and handles errors.

    Args:
        log_file (str): Path to the log file where results are logged.
    """
    log_and_print(f"{INFO} Starting to run all maintenance tasks...", 'info')

    # List of tasks to execute
    tasks = [
        ("Process Dependency Log", process_dep_scan_log),
        ("Manage Cron Jobs", manage_cron_job),
        ("Remove Broken Symlinks", remove_broken_symlinks),
        ("Clean Old Kernels", clean_old_kernels),
        ("Vacuum Journalctl", vacuum_journalctl),
        ("Clear Cache", clear_cache),
        ("Update Font Cache", update_font_cache),
        ("Clear Trash", clear_trash),
        ("Optimize Databases", optimize_databases),
        ("Clean AUR Directory", clean_aur_dir),
        ("Handle Pacnew and Pacsave Files", handle_pacnew_pacsave),
        ("Verify Installed Packages", verify_installed_packages),
        ("Check Failed Cron Jobs", check_failed_cron_jobs),
        ("Clear Docker Images", clear_docker_images),
        ("Clear Temp Folder", clear_temp_folder),
        ("Remove Unnecessary Files", check_rmshit_script),
        ("Remove Old SSH Known Hosts", remove_old_ssh_known_hosts),
        ("Remove Orphan Vim Undo Files", remove_orphan_vim_undo_files),
        ("Force Log Rotation", force_log_rotation),
        ("Configure ZRam", configure_zram),
        ("Adjust Swappiness", adjust_swappiness),
        ("Disable Unused Services", disable_unused_services)
    ]

    # Initialize a task counter
    total_tasks = len(tasks)
    completed_tasks = 0
    failed_tasks = []

    # Execute each task sequentially
    for task_name, task_func in tasks:
        try:
            log_and_print(f"{INFO} Running task: {format_message(task_name, 'cyan')}...", 'info')

            with spinning_spinner():
                task_func(log_file)

            log_and_print(f"{SUCCESS} Task completed: {format_message(task_name, 'cyan')}", 'info')
            completed_tasks += 1
        except Exception as e:
            log_and_print(f"{FAILURE} Task failed: {format_message(task_name, 'cyan')} - Error: {str(e)}", 'error')
            failed_tasks.append(task_name)

    # Display a final summary of task results
    log_and_print(f"\n{INFO} Maintenance tasks completed.", 'info')
    log_and_print(f"{SUCCESS} {completed_tasks}/{total_tasks} tasks completed successfully.", 'info')

    if failed_tasks:
        log_and_print(f"{FAILURE} The following tasks failed: {', '.join(failed_tasks)}", 'error')
    else:
        log_and_print(f"{SUCCESS} All tasks completed successfully!", 'info')

    log_and_print("Exiting maintenance mode.", 'info')

# Corrected menu options with partial
menu_options = {
    '1': partial(process_dep_scan_log, log_file_path),
    '2': partial(manage_cron_job, log_file_path),
    '3': partial(remove_broken_symlinks, log_file_path),
    '4': partial(clean_old_kernels, log_file_path),
    '5': partial(vacuum_journalctl, log_file_path),
    '6': partial(clear_cache, log_file_path),
    '7': partial(clear_trash, log_file_path),
    '8': partial(optimize_databases, log_file_path),
    '9': partial(clean_aur_dir, log_file_path),
    '10': partial(adjust_swappiness, log_file_path),  # Correctly linked to swappiness adjustment
    '11': partial(handle_pacnew_pacsave, log_file_path),  # Pacnew/pacsave handling
    '12': partial(verify_installed_packages, log_file_path),
    '13': partial(clear_docker_images, log_file_path),
    '14': partial(clear_temp_folder, log_file_path),
    '15': partial(check_rmshit_script, log_file_path),
    '16': partial(remove_old_ssh_known_hosts, log_file_path),
    '17': partial(remove_orphan_vim_undo_files, log_file_path),
    '18': partial(force_log_rotation, log_file_path),
    '19': partial(configure_zram, log_file_path),
    '20': partial(disable_unused_services, log_file_path),
    '0': partial(run_all_tasks, log_file_path)  # Run all tasks sequentially
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
        print(f"{GREEN}1{NC}) Process Dependency Log              {GREEN}11{NC}) Handle Pacnew and Pacsave Files")
        print(f"{GREEN}2{NC}) Manage Cron Jobs                   {GREEN}12{NC}) Verify Installed Packages")
        print(f"{GREEN}3{NC}) Remove Broken Symlinks             {GREEN}13{NC}) Clear Docker Images")
        print(f"{GREEN}4{NC}) Clean Old Kernels                  {GREEN}14{NC}) Clear Temp Folder")
        print(f"{GREEN}5{NC}) Vacuum Journalctl                  {GREEN}15{NC}) Run rmshit")
        print(f"{GREEN}6{NC}) Clear Cache                        {GREEN}16{NC}) Remove Old SSH Known Hosts")
        print(f"{GREEN}7{NC}) Clear Trash                        {GREEN}17{NC}) Remove Orphan Vim Undo Files")
        print(f"{GREEN}8{NC}) Optimize Databases                 {GREEN}18{NC}) Force Log Rotation")
        print(f"{GREEN}9{NC}) Clean AUR Directory                {GREEN}19{NC}) Configure ZRam")
        print(f"{GREEN}10{NC}) Adjust Swappiness                 {GREEN}20{NC}) Disable Unused Services")
        print(f"{GREEN}0{NC}) Run All Tasks                      {GREEN}Q{NC}) Quit")

        print(f"{GREEN}By your command:{NC}")

        command = input().strip().upper()

        if command in menu_options:
            try:
                menu_options[command]()
            except Exception as e:
                log_and_print(format_message(f"Error executing option: {e}", 'red'), 'error')  # Replace RED with 'red'
        elif command == 'Q':
            break
        else:
            log_and_print(format_message("Invalid choice. Please try again.", 'red'), 'error')  # Replace RED with 'red'

        input("Press Enter to continue...")

if __name__ == "__main__":
    main()
