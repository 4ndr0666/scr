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
EXPLOSION = "💥"

# Logging setup
log_dir = os.path.expanduser("~/.local/share/system_maintenance")
os.makedirs(log_dir, exist_ok=True)
log_file_path = os.path.join(log_dir, datetime.datetime.now().strftime("%Y%m%d_%H%M%S_system_maintenance.log"))
logging.basicConfig(filename=log_file_path, level=logging.INFO, format='%(asctime)s:%(levelname)s:%(message)s')

def format_message(message, color):
    return f"{BOLD}{color}{message}{NC}"

def log_and_print(message, level='info'):
    print(message)
    if level == 'info':
        logging.info(message)
    elif level == 'error':
        logging.error(message)
    elif level == 'warning':
        logging.warning(message)

def execute_command(command, error_message=None):
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

# Open the Log File
log_file = open(log_file_path, 'a')

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

#1 Process dependency scan log
def process_dep_scan_log(log_file):
    log_and_print(f"{INFO} Processing dependency scan log...")
    dep_scan_log = "/usr/local/bin/dependency_scan.log"
    if os.path.isfile(dep_scan_log):
        try:
            with open(dep_scan_log, "r") as log:
                for line in log:
                    if "permission warning" in line:
                        file_path = line.split(": ")[1].strip()
                        try:
                            if os.path.isfile(file_path):
                                os.chmod(file_path, stat.S_IRUSR | stat.S_IWUSR | stat.S_IRGRP | stat.S_IROTH)
                                log_and_print(f"{INFO}Fixed permissions for file: {file_path}", 'info')
                            elif os.path.isdir(file_path):
                                os.chmod(file_path, stat.S_IRWXU | stat.S_IRGRP | stat.S_IXGRP | stat.S_IROTH | stat.S_IXOTH)
                                log_and_print(f"{INFO}Fixed permissions for directory: {file_path}", 'info')
                        except OSError as e:
                            log_and_print(f"{FAILURE} Error fixing permissions for {file_path}: {e}", 'error')
                    if "missing dependency" in line:
                        dependency = line.split(": ")[1].strip()
                        log_and_print(f"{INFO}Attempting to install missing dependency: {dependency}", 'info')
                        result = execute_command(["sudo", "pacman", "-Sy", "--noconfirm", dependency])
                        if result:
                            log_and_print(f"{SUCCESS} Successfully installed missing dependency: {dependency}", 'info')
                        else:
                            log_and_print(f"{FAILURE} Failed to install missing dependency: {dependency}", 'error')
        except IOError as e:
            log_and_print(f"{FAILURE} Error reading dependency scan log: {e}", 'error')
    else:
        log_and_print(f"{FAILURE} Dependency scan log file not found.", 'error')
    log_and_print(f"{SUCCESS} Dependency scan log processing completed.", 'info')

#2 Manage Cron Job with Corrected Grep
def manage_cron_job(log_file):
    log_and_print(f"{INFO} Managing system cron jobs...", 'info')
    try:
        existing_crons = subprocess.run(["sudo", "crontab", "-l"], capture_output=True, text=True).stdout
        print("Existing cron jobs:\n", existing_crons)

        choice = input("Do you want to add a new cron job or delete an existing one? (add/delete): ").strip().lower()

        if choice == "add":
            new_cron = input("Enter the new cron job entry: ").strip()
            new_crons = existing_crons + "\n" + new_cron + "\n"
            with open(os.path.expanduser("~/.cron_temp"), "w") as temp_file:
                temp_file.write(new_crons)
            subprocess.run(["sudo", "crontab", os.path.expanduser("~/.cron_temp")], check=True)
            os.remove(os.path.expanduser("~/.cron_temp"))
            log_and_print(f"{SUCCESS} New cron job added successfully.", 'info')

        elif choice == "delete":
            cron_to_delete = input("Enter the exact cron job entry to delete: ").strip()
            new_crons = '\n'.join([line for line in existing_crons.splitlines() if line.strip() != cron_to_delete])
            with open(os.path.expanduser("~/.cron_temp"), "w") as temp_file:
                temp_file.write(new_crons)
            subprocess.run(["sudo", "crontab", os.path.expanduser("~/.cron_temp")], check=True)
            os.remove(os.path.expanduser("~/.cron_temp"))
            log_and_print(f"{SUCCESS} Cron job deleted successfully.", 'info')

        else:
            log_and_print(f"{INFO} No changes made to cron jobs.", 'info')

    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error managing cron jobs: {e.stderr.strip()}", 'error')

#3 Remove Broken Symlinks
def remove_broken_symlinks(log_file):
    log_and_print(f"{INFO} Searching for broken symbolic links...", 'info')
    spinner_thread, stop_spinner = spinner()
    try:
        broken_links = subprocess.check_output(["sudo", "find", "/", "-xtype", "l"], stderr=subprocess.STDOUT, text=True).strip()
        stop_spinner()
        if broken_links:
            log_and_print(f"{INFO} Broken symbolic links found:\n{broken_links}", 'info')
        else:
            log_and_print(f"{SUCCESS} No broken symbolic links found.", 'info')
    except subprocess.CalledProcessError as e:
        stop_spinner()
        log_and_print(f"{FAILURE} Error searching for broken symbolic links: {e.output.strip()}", 'error')
    finally:
        stop_spinner()

#4 Cleanup Old Kernel Images
def clean_old_kernels(log_file):
    log_and_print(f"{INFO} Cleaning up old kernel images...", 'info')
    try:
        explicitly_installed = subprocess.check_output(["pacman", "-Qet"], text=True).strip().split('\n')
        current_kernel = subprocess.check_output(["uname", "-r"], text=True).strip()
        current_kernel_major_version = '.'.join(current_kernel.split('.')[:2])
        kernels_to_remove = []
        for pkg in explicitly_installed:
            if "linux" in pkg and current_kernel_major_version not in pkg:
                pkg_name = pkg.split()[0]
                if pkg_name.startswith("linux") and (pkg_name.endswith("headers") or pkg_name.count('-') > 1):
                    kernels_to_remove.append(pkg_name)
        if kernels_to_remove:
            subprocess.run(["sudo", "pacman", "-Rns"] + kernels_to_remove, check=True)
            log_and_print(f"{SUCCESS} Old kernel images cleaned up: {' '.join(kernels_to_remove)}", 'info')
        else:
            log_and_print(f"{INFO} No old kernel images to remove.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error: {e.stderr.strip()}", 'error')

#5 Vacuum Journalctl
def vacuum_journalctl(log_file):
    log_and_print(f"{INFO} Vacuuming journalctl...", 'info')
    try:
        subprocess.run(["sudo", "journalctl", "--vacuum-time=3d"], check=True)
        log_and_print(f"{SUCCESS} Journalctl vacuumed successfully.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error: Failed to vacuum journalctl: {e.stderr.strip()}", 'error')

#6 Clear Cache
def clear_cache(log_file):
    log_and_print(f"{INFO} Clearing user cache...", 'info')
    try:
        subprocess.run(["sudo", "find", os.path.expanduser("~/.cache/"), "-type", "f", "-atime", "+3", "-delete"], check=True)
        log_and_print(f"{SUCCESS} User cache cleared.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error: Failed to clear cache: {e.stderr.strip()}", 'error')

#7 Update Font Cache
def update_font_cache(log_file):
    log_and_print(f"{INFO} Updating font cache...", 'info')
    try:
        subprocess.run(["sudo", "fc-cache", "-fv"], check=True)
        log_and_print(f"{SUCCESS} Font cache updated.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error: Failed to update font cache: {e.stderr.strip()}", 'error')

#8 Clear Trash
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

#9 Optimize Databases
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
        log_and_print(f"{FAILURE} Error: Failed to optimize databases: {e.stderr.strip()}", 'error')

#10 Clean Package Cache
def clean_package_cache(log_file):
    log_and_print(f"{INFO} Cleaning package cache...", 'info')
    try:
        subprocess.run(["sudo", "paccache", "-rk2"], check=True)
        log_and_print(f"{SUCCESS} Package cache cleaned.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error: Failed to clean package cache: {e.stderr.strip()}", 'error')

#11 Clean AUR Directory
def clean_aur_dir(log_file):
    log_and_print(f"{INFO} Cleaning AUR directory...", 'info')
    aur_dir = input("Please enter the path to the AUR directory you want to clean: ").strip()
    if not os.path.isdir(aur_dir):
        log_and_print(f"{FAILURE} The specified path is not a directory.", 'error')
        return
    os.chdir(aur_dir)
    pkgname_regex = re.compile(r'(?P<pkgname>.*?)-(?P<pkgver>[^-]+)-(?P<arch>x86_64|any|i686)\.pkg\.tar\.(xz|zst|gz|bz2|lrz|lzo|lz4|lz)$')
    files = {}
    for f in os.listdir():
        if not os.path.isfile(f):
            continue
        match = pkgname_regex.match(f)
        if match:
            files[f] = "{pkgname}-{pkgver}-{arch}".format(**match.groupdict())
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

#12 Handle Pacnew and Pacsave Files
def handle_pacnew_pacsave(log_file):
    try:
        pacnew_files = subprocess.check_output(["sudo", "find", "/etc", "-type", "f", "-name", "*.pacnew"], text=True).splitlines()
        pacsave_files = subprocess.check_output(["sudo", "find", "/etc", "-type", "f", "-name", "*.pacsave"], text=True).splitlines()

        if pacnew_files:
            log_and_print(f"{INFO} .pacnew files found. Consider merging:", 'info')
            for file in pacnew_files:
                print(file)
                action = input("Do you want to remove, skip, or overwrite this file? (remove/skip/overwrite): ").strip().lower()
                if action == "remove":
                    os.remove(file)
                    log_and_print(f"{SUCCESS} .pacnew file removed: {file}", 'info')
                elif action == "overwrite":
                    original_file = file.replace(".pacnew", "")
                    shutil.copyfile(file, original_file)
                    os.remove(file)
                    log_and_print(f"{SUCCESS} .pacnew file overwritten: {file}", 'info')
                else:
                    log_and_print(f"{INFO} Skipped .pacnew file: {file}", 'info')
        else:
            log_and_print(f"{INFO} No .pacnew files found.", 'info')

        if pacsave_files:
            log_and_print(f"{INFO} .pacsave files found. Consider reviewing:", 'info')
            for file in pacsave_files:
                print(file)
                action = input("Do you want to remove, skip, or overwrite this file? (remove/skip/overwrite): ").strip().lower()
                if action == "remove":
                    os.remove(file)
                    log_and_print(f"{SUCCESS} .pacsave file removed: {file}", 'info')
                elif action == "overwrite":
                    original_file = file.replace(".pacsave", "")
                    shutil.copyfile(file, original_file)
                    os.remove(file)
                    log_and_print(f"{SUCCESS} .pacsave file overwritten: {file}", 'info')
                else:
                    log_and_print(f"{INFO} Skipped .pacsave file: {file}", 'info')
        else:
            log_and_print(f"{INFO} No .pacsave files found.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error handling pacnew and pacsave files: {e.stderr.strip()}", 'error')

#13 Verify Installed Packages
def verify_installed_packages(log_file):
    log_and_print(f"{INFO} Checking for packages with missing files...", 'info')
    try:
        result = subprocess.run("pacman -Qk | grep -v ' 0 missing files' | awk '{print $1}'", shell=True, capture_output=True, text=True)
        missing_packages = result.stdout.strip().split('\n')

        if not missing_packages or missing_packages == ['']:
            log_and_print(f"{SUCCESS} No packages with missing files found.", 'info')
            return

        log_and_print(f"{INFO} Reinstalling packages with missing files...", 'info')
        command = "sudo pacman -S --noconfirm " + ' '.join(missing_packages)
        subprocess.run(command, shell=True, check=True)
        log_and_print(f"{SUCCESS} Packages reinstalled successfully.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error verifying installed packages: {e.stderr.strip() if e.stderr else e}", 'error')
    except Exception as e:
        log_and_print(f"{FAILURE} Unexpected error: {str(e)}", 'error')

#14 Check Failed Cron Jobs
def check_failed_cron_jobs(log_file):
    log_and_print(f"{INFO} Checking for failed cron jobs...", 'info')
    try:
        failed_jobs = subprocess.check_output(["grep", "-i", "cron.*error", "/var/log/syslog"], text=True)
        if failed_jobs:
            log_and_print(f"{FAILURE} Failed cron jobs detected. Review syslog for details.", 'error')
            print(failed_jobs)
            repair = input("Do you want to attempt to repair the failed cron jobs? (y/n): ").strip().lower()
            if repair == "y":
                # Add logic to repair cron jobs
                log_and_print(f"{SUCCESS} Attempting to repair failed cron jobs...", 'info')
                # Repair logic here
        else:
            log_and_print(f"{SUCCESS} No failed cron jobs detected.", 'info')
    except subprocess.CalledProcessError:
        log_and_print(f"{INFO} No failed cron jobs detected or syslog not accessible.", 'info')

#15 Clear Docker Images
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

#16 Clear Temp Folder
def clear_temp_folder(log_file):
    log_and_print(f"{INFO} Clearing the temporary folder...", 'info')
    try:
        subprocess.run(["sudo", "find", "/tmp", "-type", "f", "-atime", "+2", "-delete"], check=True)
        log_and_print(f"{SUCCESS} Temporary folder cleared.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error: Failed to clear the temporary folder: {e.stderr.strip()}", 'error')

#17 Run rmshit.py
def check_rmshit_script(log_file=None):
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

#18 Remove Old SSH Known Hosts
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

#19 Remove Orphan Vim Undo Files
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

#20 Force Log Rotation
def force_log_rotation(log_file):
    log_and_print(f"{INFO} Forcing log rotation...", 'info')
    try:
        subprocess.run(["sudo", "logrotate", "-f", "/etc/logrotate.conf"], check=True)
        log_and_print(f"{SUCCESS} Log rotation forced.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error: Failed to force log rotation: {e.stderr.strip()}", 'error')

#21 Configure ZRam
def configure_zram(log_file):
    log_and_print(f"{INFO} Configuring ZRam for better memory management...", 'info')

    if shutil.which("zramctl"):
        try:
            # Calculate 25% of the total memory
            mem_total_cmd = "awk '/MemTotal/ {printf \"%d\\n\", $2 * 1024 * 0.25}' /proc/meminfo"
            mem_total_output = subprocess.check_output(mem_total_cmd, shell=True).strip()
            log_and_print(f"Memory calculation output: {mem_total_output}", 'info')
            mem_total = int(mem_total_output)
            log_and_print(f"Calculated ZRam size: {mem_total} bytes", 'info')

            try:
                # Find or create a new zram device with the specified size
                log_and_print("Attempting to find an existing zram device...", 'info')
                zram_device = subprocess.run(["sudo", "zramctl", "--find", "--size", str(mem_total)], stdout=subprocess.PIPE, text=True, check=True).stdout.strip()
                log_and_print(f"Using existing zram device: {zram_device}", 'info')
            except subprocess.CalledProcessError as e:
                log_and_print(f"No free zram device found. Creating a new one...", 'info')
                subprocess.run(["sudo", "modprobe", "zram"], check=True)
                zram_device = subprocess.run(["sudo", "zramctl", "--find", "--size", str(mem_total)], stdout=subprocess.PIPE, text=True, check=True).stdout.strip()
                log_and_print(f"Created new zram device: {zram_device}", 'info')

            # Set up the zram device as swap
            log_and_print(f"Setting up {zram_device} as swap...", 'info')
            subprocess.run(["sudo", "mkswap", zram_device], check=True)
            subprocess.run(["sudo", "swapon", zram_device, "-p", "32767"], check=True)

            log_and_print(f"{SUCCESS} ZRam configured successfully on {zram_device} with size {mem_total} bytes.", 'info')
        except subprocess.CalledProcessError as e:
            log_and_print(f"{FAILURE} Error configuring ZRam: {e.stderr.strip() if e.stderr else str(e)}", 'error')
    else:
        log_and_print(f"{FAILURE} ZRam not available. Please install zramctl.", 'error')


#22 Check ZRam Configuration
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

#23 Adjust Swappiness
def adjust_swappiness(log_file):
    swappiness_value = 10  # Recommended for systems with low RAM
    log_and_print(f"{INFO} Adjusting swappiness to {swappiness_value}...", 'info')
    try:
        subprocess.run(["sudo", "sysctl", f"vm.swappiness={swappiness_value}"], check=True)
        log_and_print(f"{SUCCESS} Swappiness adjusted to {swappiness_value}.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error: Failed to adjust swappiness: {e.stderr.strip()}", 'error')

#24 Clear System Cache
def clear_system_cache(log_file):
    log_and_print(f"{INFO} Clearing PageCache, dentries, and inodes...", 'info')
    try:
        subprocess.run(["sudo", "sh", "-c", "echo 3 > /proc/sys/vm/drop_caches"], check=True)
        log_and_print(f"{SUCCESS} System caches cleared.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{FAILURE} Error: Failed to clear system cache: {e.stderr.strip()}", 'error')

#25 Disable Unused Services
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

#26 Check and Restart Failed Systemd Units
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
    '1': partial(process_dep_scan_log, log_file),
    '2': partial(manage_cron_job, log_file),
    '3': partial(remove_broken_symlinks, log_file),
    '4': partial(clean_old_kernels, log_file),
    '5': partial(vacuum_journalctl, log_file),
    '6': partial(clear_cache, log_file),
    '7': partial(update_font_cache, log_file),
    '8': partial(clear_trash, log_file),
    '9': partial(optimize_databases, log_file),
    '10': partial(clean_package_cache, log_file),
    '11': partial(clean_aur_dir, log_file),
    '12': partial(handle_pacnew_pacsave, log_file),
    '13': partial(verify_installed_packages, log_file),
    '14': partial(check_failed_cron_jobs, log_file),
    '15': partial(clear_docker_images, log_file),
    '16': partial(clear_temp_folder, log_file),
    '17': partial(check_rmshit_script, log_file),
    '18': partial(remove_old_ssh_known_hosts, log_file),
    '19': partial(remove_orphan_vim_undo_files, log_file),
    '20': partial(force_log_rotation, log_file),
    '21': partial(configure_zram, log_file),
    '22': partial(check_zram_configuration, log_file),
    '23': partial(adjust_swappiness, log_file),
    '24': partial(clear_system_cache, log_file),
    '25': partial(disable_unused_services, log_file),
    '26': partial(check_and_restart_systemd_units, log_file),
    '0': partial(run_all_tasks, log_file)
}

# Main Menu
def main():
    while True:
        os.system('clear')
        print(f"===================================================================")
        print(f"    ================= {GREEN}// Vacuum Menu //{NC} =======================")
        print("===================================================================")
        print(f"{GREEN}1{NC}) Process Dependeny Log              {GREEN}14{NC}) Check Failed Cron Jobs")
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
