#!/usr/bin/env python3

import os
import subprocess
import signal
import sys
import shutil
import stat
import logging
import datetime
import re
from functools import partial
import threading
import itertools
import time

# Set up basic logging configuration
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Spinner function with docstring
def spinner():
    """A simple console spinner for indicating progress."""
    spinner_running = True
    spinner_symbols = itertools.cycle('|/-\\')

    def spin():
        while spinner_running:
            sys.stdout.write(next(spinner_symbols) + '\r')
            sys.stdout.flush()
            time.sleep(0.1)

    spinner_thread = threading.Thread(target=spin)
    spinner_thread.start()
    return spinner_thread, lambda: setattr(spinner, 'spinner_running', False)

# Colors and symbols
GREEN = '\033[38;2;57;255;20m'
BOLD = '\033[1m'
RED = '\033[0;31m'
NC = '\033[0m'  # No Color
SUCCESS = "✔️"
FAILURE = "❌"
INFO = "➡️"

# Logging setup
log_dir = os.path.expanduser("~/.local/share/system_maintenance")
os.makedirs(log_dir, exist_ok=True)
log_file_path = os.path.join(log_dir, datetime.datetime.now().strftime("%Y%m%d_%H%M%S_system_maintenance.log"))
logging.basicConfig(filename=log_file_path, level=logging.INFO, format='%(asctime)s:%(levelname)s:%(message)s')

def format_message(message, color):
    return f"{BOLD}{color}{message}{NC}"

def log_and_print(message, level='info'):
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    message_with_time = f"{timestamp} - {message}"
    print(message_with_time)
    if level == 'info':
        logging.info(message_with_time)
    elif level == 'error':
        logging.error(message_with_time)
    elif level == 'warning':
        logging.warning(message_with_time)

def execute_command(command, error_message=None):
    try:
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
        logging.info(result.stdout)
        if result.stderr:
            logging.error(result.stderr)
        return result.stdout
    except subprocess.CalledProcessError as e:
        log_message = error_message or f"Command '{e.cmd}' failed with error: {e.stderr.strip()} (return code: {e.returncode})"
        log_and_print(format_message(log_message, RED), 'error')
        return None

# Run all tasks
def run_all_tasks(log_file):
    for key in [str(k) for k in range(1, 27)]:
        try:
            menu_options[key]()
        except KeyError as e:
            log_and_print(format_message(f"Error executing task {key}: {e}", RED), 'error')

def confirm_deletion(file_or_dir):
    """Ask for confirmation before deletion."""
    confirm = input(f"Do you really want to delete {file_or_dir}? [y/N]: ").strip().lower()
    return confirm == 'y'

# Task Functions

def process_dep_scan_log(log_file):
    log_and_print(f"{INFO} Processing dependency scan log...")
    dep_scan_log = "/usr/local/bin/dependency_scan.log"
    if os.path.isfile(dep_scan_log):
        with open(dep_scan_log, "r") as log:
            for line in log:
                if "permission warning" in line:
                    file_path = line.split(": ")[1].strip()
                    if os.path.isfile(file_path):
                        os.chmod(file_path, stat.S_IRUSR | stat.S_IWUSR | stat.S_IRGRP | stat.S_IROTH)
                        log_and_print(f"{INFO} Fixed permissions for file: {file_path}", 'info')
                    elif os.path.isdir(file_path):
                        os.chmod(file_path, stat.S_IRWXU | stat.S_IRGRP | stat.S_IXGRP | stat.S_IROTH | stat.S_IXOTH)
                        log_and_print(f"{INFO} Fixed permissions for directory: {file_path}", 'info')
                if "missing dependency" in line:
                    dependency = line.split(": ")[1].strip()
                    log_and_print(f"{INFO} Attempting to install missing dependency: {dependency}", 'info')
                    result = execute_command(["sudo", "pacman", "-Sy", "--noconfirm", dependency])
                    if result:
                        log_and_print(f"{SUCCESS} Successfully installed missing dependency: {dependency}", 'info')
                    else:
                        log_and_print(f"{FAILURE} Failed to install missing dependency: {dependency}", 'error')
    else:
        log_and_print(f"{FAILURE} Dependency scan log file not found.", 'error')
    log_and_print(f"{SUCCESS} Dependency scan log processing completed.", 'info')

def manage_cron_job(log_file):
    cron_command = f"find {log_dir} -name '*_permissions.log' -mtime +30 -exec rm {{}} \\;"
    cron_entry = f"0 0 * * * {cron_command}"
    try:
        existing_crons = subprocess.run(["sudo", "crontab", "-l"], capture_output=True, text=True).stdout
        new_crons = '\n'.join([line for line in existing_crons.splitlines() if cron_command not in line])
        new_crons += f"{cron_entry}\n"
        with open(os.path.expanduser("~/.cron_temp"), "w") as temp_file:
            temp_file.write(new_crons)
        subprocess.run(["sudo", "crontab", os.path.expanduser("~/.cron_temp")], check=True)
        os.remove(os.path.expanduser("~/.cron_temp"))
        log_and_print(f"{SUCCESS} Cron job set up to delete old logs.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error managing cron job: {e.stderr.strip()}", 'error')

def remove_broken_symlinks(log_file):
    log_and_print(f"{INFO} Searching for broken symbolic links...", 'info')
    try:
        stop_spinner = spinner()
        broken_links = subprocess.check_output(["sudo", "find", "/", "-xtype", "l"], stderr=subprocess.STDOUT, text=True).strip()
        stop_spinner[1]()
        if broken_links:
            log_and_print(f"{INFO} Broken symbolic links found:\n{broken_links}", 'info')
        else:
            log_and_print(f"{SUCCESS} No broken symbolic links found.", 'info')
    except subprocess.CalledProcessError as e:
        stop_spinner[1]()
        log_and_print(f"{FAILURE} Error searching for broken symbolic links: {e.output.strip()}", 'error')

def clean_old_kernels(log_file):
    log_and_print(f"{INFO} Cleaning up old kernel images...", 'info')
    try:
        explicitly_installed = subprocess.check_output(["pacman", "-Qet"], text=True).strip().split('\n')
        current_kernel = subprocess.check_output(["uname", "-r"], text=True).strip()
        current_kernel_major_version = '.'.join(current_kernel.split('.')[:2])
        kernels_to_remove = [pkg.split()[0] for pkg in explicitly_installed if "linux" in pkg and current_kernel_major_version not in pkg]
        if kernels_to_remove:
            subprocess.run(["sudo", "pacman", "-Rns"] + kernels_to_remove, check=True)
            log_and_print(f"{SUCCESS} Old kernel images cleaned up: {' '.join(kernels_to_remove)}", 'info')
        else:
            log_and_print(f"{INFO} No old kernel images to remove.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error: {e.stderr.strip()}", 'error')

def vacuum_journalctl(log_file):
    log_and_print(f"{INFO} Vacuuming journalctl...", 'info')
    try:
        subprocess.run(["sudo", "journalctl", "--vacuum-time=3d"], check=True)
        log_and_print(f"{SUCCESS} Journalctl vacuumed successfully.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error: Failed to vacuum journalctl: {e.stderr.strip()}", 'error')

def clear_cache(log_file):
    log_and_print(f"{INFO} Clearing user cache...", 'info')
    try:
        subprocess.run(["sudo", "find", os.path.expanduser("~/.cache/"), "-type", "f", "-atime", "+3", "-delete"], check=True)
        log_and_print(f"{SUCCESS} User cache cleared.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error: Failed to clear cache: {e.stderr.strip()}", 'error')

def update_font_cache(log_file):
    log_and_print(f"{INFO} Updating font cache...", 'info')
    try:
        subprocess.run(["sudo", "fc-cache", "-fv"], check=True)
        log_and_print(f"{SUCCESS} Font cache updated.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error: Failed to update font cache: {e.stderr.strip()}", 'error')

def clear_trash(log_file):
    log_and_print(f"{INFO} Clearing trash...", 'info')
    choice = input("Do you want to clear the trash? (y/n): ")
    if choice.lower() == "y":
        try:
            trash_path = os.path.expanduser("~/.local/share/Trash/*")
            subprocess.run(["sudo", "rm", "-rf", trash_path], check=True)
            log_and_print(f"{SUCCESS} Trash cleared.", 'info')
        except subprocess.CalledProcessError as e:
            log_and_print(f"{FAILURE} Error: Failed to clear trash: {e.stderr.strip()}", 'error')
    else:
        log_and_print(f"{INFO} Skipping trash clearance.", 'info')

def optimize_databases(log_file):
    log_and_print(f"{INFO} Optimizing system databases...", 'info')
    try:
        subprocess.run(["sudo", "updatedb"], check=True)
        log_and_print(f"{SUCCESS} 'locate' database updated.", 'info')
        subprocess.run(["sudo", "pkgfile", "-u"], check=True)
        log_and_print(f"{SUCCESS} 'pkgfile' database updated.", 'info')
        subprocess.run(["sudo", "pacman-key", "--refresh-keys"], check=True)
        log_and_print(f"{SUCCESS} Pacman keyring refreshed.", 'info')
        log_and_print(f"{SUCCESS} System databases optimized.", 'info')
    except subprocess.CalledProcessError as e:
        error_message = e.stderr.strip() if e.stderr else "Command failed without an error message"
        log_and_print(f"{FAILURE} Error: Failed to optimize databases: {error_message}", 'error')

def clean_package_cache(log_file):
    log_and_print(f"{INFO} Cleaning package cache...", 'info')
    try:
        subprocess.run(["sudo", "paccache", "-rk2"], check=True)
        log_and_print(f"{SUCCESS} Package cache cleaned.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error: Failed to clean package cache: {e.stderr.strip()}", 'error')

def clean_aur_dir(log_file):
    log_and_print(f"{INFO} Cleaning AUR directory...", 'info')
    aur_dir = input("Please enter the path to the AUR directory you want to clean: ").strip()
    if not os.path.isdir(aur_dir):
        log_and_print(f"{FAILURE} The specified path is not a directory.", 'error')
        return
    os.chdir(aur_dir)
    pkgname_regex = re.compile(r'(?P<pkgname>.*?)-(?P<pkgver>[^-]+)-(?P<arch>x86_64|any|i686)\.pkg\.tar\.(xz|zst|gz|bz2|lrz|lzo|lz4|lz)$')
    files = {f: "{pkgname}-{pkgver}-{arch}".format(**pkgname_regex.match(f).groupdict()) for f in os.listdir() if os.path.isfile(f) and pkgname_regex.match(f)}
    try:
        installed = subprocess.check_output(["expac", "-Qs", "%n-%v-%a"], universal_newlines=True).splitlines()
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error obtaining installed packages list: {e.stderr.strip()}", 'error')
        return
    for f in sorted(files):
        ff = files[f]
        if ff not in installed:
            log_and_print(f"{INFO} Deleting: {f}", 'info')
            try:
                os.remove(f)
            except OSError as e:
                log_and_print(f"{FAILURE} Error deleting file {f}: {e}", 'error')
    log_and_print(f"{SUCCESS} AUR directory cleaned.", 'info')

def handle_pacnew_pacsave(log_file):
    pacnew_files = subprocess.check_output(["sudo", "find", "/etc", "-type", "f", "-name", "*.pacnew"], text=True).splitlines()
    pacsave_files = subprocess.check_output(["sudo", "find", "/etc", "-type", "f", "-name", "*.pacsave"], text=True).splitlines()
    if pacnew_files:
        log_and_print(f"{INFO} .pacnew files found. Consider merging:", 'info')
        for file in pacnew_files:
            print(file)
    else:
        log_and_print(f"{INFO} No .pacnew files found.", 'info')
    if pacsave_files:
        log_and_print(f"{INFO} .pacsave files found. Consider reviewing:", 'info')
        for file in pacsave_files:
            print(file)
    else:
        log_and_print(f"{INFO} No .pacsave files found.", 'info')

def confirm_action(prompt):
    while True:
        choice = input(f"{prompt} (y/n): ").strip().lower()
        if choice in ['y', 'n']:
            return choice == 'y'
        else:
            print("Invalid input. Please enter 'y' or 'n'.")

def verify_installed_packages(log_file):
    """
    Verifies installed packages for missing files and attempts to reinstall them.
    Parameters:
    log_file (file object): The file object for logging.
    Returns:
    None
    """
    # Ask the user if they want to update the mirror list
    if confirm_action("Do you want to update the mirror list?"):
        print("➡️ Updating mirror list...")
        stop_spinner = spinner()
        try:
            subprocess.run(
                "sudo reflector --country 'United States' --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist",
                shell=True,
                check=True,
            )
            stop_spinner[1]()  # Stop the spinner
            print("✔️ Mirror list updated successfully.")
        except subprocess.CalledProcessError:
            stop_spinner[1]()  # Stop the spinner
            print("❌ Error updating mirror list.")
            return False
    else:
        print("➡️ Skipping mirror list update.")

    # Check for packages with missing files
    print("➡️ Checking for packages with missing files...")
    stop_spinner = spinner()
    result = subprocess.run("pacman -Qk | grep -v ' 0 missing files' | awk '{print $1}'", shell=True, capture_output=True, text=True)
    stop_spinner[1]()  # Stop the spinner
    missing_packages = result.stdout.strip().split('\n')
    missing_packages = [pkg.rstrip(':') for pkg in missing_packages]  # Clean up package names

    if not missing_packages or missing_packages == ['']:
        print("➡️ No packages with missing files found.")
        return

    # Reinstall packages with missing files
    print("➡️ Reinstalling packages with missing files...")
    stop_spinner = spinner()
    command = "paru -S --noconfirm " + ' '.join(missing_packages)
    try:
        subprocess.run(command, shell=True, check=True)
        stop_spinner[1]()  # Stop the spinner
        print("✔️ Packages reinstalled successfully.")
    except subprocess.CalledProcessError as e:
        stop_spinner[1]()  # Stop the spinner
        print(f"❌ Error verifying installed packages: Command '{command}' returned non-zero exit status {e.returncode}.")
        print(e.stderr)

def check_failed_cron_jobs(log_file):
    log_and_print(f"{INFO} Checking for failed cron jobs...", 'info')
    try:
        failed_jobs = subprocess.check_output(["grep", "-i", "cron.*error", "/var/log/syslog"], text=True)
        if failed_jobs:
            log_and_print(f"{FAILURE} Failed cron jobs detected. Review syslog for details.", 'error')
            print(failed_jobs)
        else:
            log_and_print(f"{SUCCESS} No failed cron jobs detected.", 'info')
    except subprocess.CalledProcessError:
        log_and_print(f"{INFO} No failed cron jobs detected or syslog not accessible.", 'info')

def clear_docker_images(log_file):
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
    log_and_print(f"{INFO} Clearing the temporary folder...", 'info')
    try:
        subprocess.run(["sudo", "find", "/tmp", "-type", "f", "-atime", "+2", "-delete"], check=True)
        log_and_print(f"{SUCCESS} Temporary folder cleared.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error: Failed to clear the temporary folder: {e.stderr.strip()}", 'error')

def check_rmshit_script(log_file=None):
    """Clean up unnecessary files."""
    log_and_print(f"{INFO} Cleaning up unnecessary files...")
    shittyfiles = [
        '~/.adobe', '~/.macromedia', '~/.FRD/log/app.log', '~/.FRD/links.txt', '~/.objectdb',
        '~/.gstreamer-0.10', '~/.pulse', '~/.esd_auth', '~/.config/enchant', '~/.spicec',
        '~/.dropbox-dist', '~/.parallel', '~/.dbus', '~/.distlib/', '~/.bazaar/', '~/.bzr.log',
        '~/.nv/', '~/.viminfo', '~/.npm/', '~/.java/', '~/.swt/', '~/.oracle_jre_usage/',
        '~/.jssc/', '~/.tox/', '~/.pylint.d/', '~/.qute_test/', '~/.QtWebEngineProcess/',
        '~/.qutebrowser/', '~/.asy/', '~/.cmake/', '~/.cache/mozilla/', '~/.cache/chromium/',
        '~/.cache/google-chrome/', '~/.cache/spotify/', '~/.cache/steam/', '~/.zoom/',
        '~/.Skype/', '~/.minecraft/logs/', '~/.thumbnails/', '~/.local/share/Trash/',
        '~/.vim/.swp', '~/.vim/.backup', '~/.vim/.undo', '~/.emacs.d/auto-save-list/',
        '~/.cache/JetBrains/', '~/.vscode/extensions/', '~/.npm/_logs/', '~/.npm/_cacache/',
        '~/.composer/cache/', '~/.gem/cache/', '~/.cache/pip/', '~/.gnupg/', '~/.wget-hsts',
        '~/.docker/', '~/.local/share/baloo/', '~/.kde/share/apps/okular/docdata/',
        '~/.local/share/akonadi/', '~/.xsession-errors', '~/.cache/gstreamer-1.0/',
        '~/.cache/fontconfig/', '~/.cache/mesa/', '~/.nv/ComputeCache/'
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
    log_and_print(f"{INFO} Searching for orphan Vim undo files...", 'info')
    home_dir = os.path.expanduser("~")
    for root, dirs, files in os.walk(home_dir):
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
    log_and_print(f"{INFO} Forcing log rotation...", 'info')
    try:
        subprocess.run(["sudo", "logrotate", "-f", "/etc/logrotate.conf"], check=True)
        log_and_print(f"{SUCCESS} Log rotation forced.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error: Failed to force log rotation: {e.stderr.strip()}", 'error')

def configure_zram(log_file):
    log_and_print(f"{INFO} Configuring ZRam for better memory management...", 'info')
    if shutil.which("zramctl"):
        try:
            mem_total_cmd = ["awk", '/MemTotal/{printf "%d\\n", $2 * 1024 * 0.25}', "/proc/meminfo"]
            mem_total = int(subprocess.check_output(mem_total_cmd).decode().strip())
            zram_device = subprocess.run(["sudo", "zramctl", "--find", "--size", str(mem_total)], stdout=subprocess.PIPE, text=True, check=True).stdout.strip()
            subprocess.run(["sudo", "mkswap", zram_device], check=True)
            subprocess.run(["sudo", "swapon", zram_device, "-p", "32767"], check=True)
            log_and_print(f"{SUCCESS} ZRam configured successfully on {zram_device}.", 'info')
        except subprocess.CalledProcessError as e:
            log_and_print(f"{FAILURE} Error: {e.stderr.decode().strip()}" if e.stderr else "Error occurred, but no stderr output.", 'error')
    else:
        log_and_print(f"{FAILURE} ZRam not available. Consider installing it first.", 'error')

def check_zram_configuration(log_file):
    log_and_print(f"{INFO} Checking ZRam configuration...", 'info')
    try:
        zram_status = subprocess.check_output(["zramctl"], text=True)
        if zram_status:
            log_and_print(f"{SUCCESS} ZRam is configured correctly.", 'info')
        else:
            log_and_print(f"{INFO} ZRam is not configured. Configuring now...", 'info')
            configure_zram(log_file)
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error: Failed to check ZRam configuration: {e.stderr.strip()}", 'error')

def adjust_swappiness(log_file):
    swappiness_value = 10  # Recommended for systems with low RAM
    log_and_print(f"{INFO} Adjusting swappiness to {swappiness_value}...", 'info')
    try:
        subprocess.run(["sudo", "sysctl", f"vm.swappiness={swappiness_value}"], check=True)
        log_and_print(f"{SUCCESS} Swappiness adjusted to {swappiness_value}.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error: Failed to adjust swappiness: {e.stderr.strip()}", 'error')

def clear_system_cache(log_file):
    log_and_print(f"{INFO} Clearing PageCache, dentries, and inodes...", 'info')
    try:
        subprocess.run(["sudo", "sh", "-c", "echo 3 > /proc/sys/vm/drop_caches"], check=True)
        log_and_print(f"{SUCCESS} System caches cleared.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error: Failed to clear system cache: {e.stderr.strip()}", 'error')

def disable_unused_services(log_file):
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

# Main menu
def main():
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
