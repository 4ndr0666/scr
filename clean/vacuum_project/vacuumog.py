"""
This module provides a comprehensive set of utilities for system maintenance tasks
such as cleaning caches, managing system services, and optimizing storage. It is
designed to be run on systems using pacman as the package manager.
"""

import logging
import os
import re
import shutil
import stat
import subprocess
from datetime import datetime
from functools import partial

# Constants for Dependency Scan Log and Package Manager Command
DEP_SCAN_LOG = "/usr/local/bin/dependency_scan.log"
PACMAN_CMD = ["sudo", "pacman", "-Sy", "--noconfirm"]

class Style:
    """Defines the style used for terminal output."""
    GREEN = '\033[0;32m'
    BOLD = '\033[1m'
    RED = '\033[0;31m'
    NC = '\033[0m'  # No Color
    SUCCESS = "✔️"
    FAILURE = "❌"
    INFO = "➡️"
    EXPLOSION = "💥"

def manage_system_service(service_name: str, action: str):
    """
    Manages a system service by executing an action such as start, stop, restart, enable, or disable.

    :param service_name: Name of the service to manage.
    :param action: Action to perform on the service.
    """
    assert action in ["start", "stop", "restart", "enable", "disable"], "Invalid action specified"
    try:
        subprocess.run(["sudo", "systemctl", action, service_name], check=True)
        log_and_print(f"{Style.SUCCESS} {service_name} successfully {action}ed.", Style.INFO)
    except subprocess.CalledProcessError as e:
        log_and_print(f"{Style.FAILURE} Failed to {action} {service_name}: {e}", Style.ERROR)

def confirm_operation(message: str) -> bool:
    """
    Prompts for confirmation before performing an operation.

    :param message: The message to display for confirmation.
    :return: True if confirmed, False otherwise.
    """
    return input(f"{message} (y/N): ").lower().strip() == 'y'

# Setup Logging Configuration
def setup_logging() -> str:
    """Sets up logging for the system maintenance script."""
    log_dir = os.path.expanduser("~/.local/share/system_maintenance")
    os.makedirs(log_dir, exist_ok=True)
    log_file_path = os.path.join(log_dir, datetime.now().strftime("%Y%m%d_%H%M%S_system_maintenance.log"))
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)
    file_handler = logging.FileHandler(log_file_path)
    stream_handler = logging.StreamHandler()
    log_format = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    file_handler.setFormatter(logging.Formatter(log_format))
    stream_handler.setFormatter(logging.Formatter(log_format))
    logger.addHandler(file_handler)
    logger.addHandler(stream_handler)
    return log_file_path

def format_message(message: str, style: str) -> str:
    """Formats a message for terminal output with a given style."""
    return f"{Style.BOLD}{style}{message}{Style.NC}"

def execute_command(command: list, error_message: str = None) -> str:
    """Executes a system command and handles errors."""
    try:
        result = subprocess.run(command, capture_output=True, text=True, check=True)
        logging.info("Command executed successfully: " + ' '.join(command))
        return result.stdout
    except subprocess.CalledProcessError as e:
        error_msg = error_message or f"Failed to execute command: {' '.join(command)}\nError: {e.stderr}"
        logging.error(error_msg)
        raise SystemExit(error_msg) from e

# Define missing functions for complete logic implementation
def log_and_print(message: str, style=Style.INFO, level: str = 'info'):
    """
    Logs and prints a message with a specified style and log level.

    :param message: The message to log and print.
    :param style: The style to apply to the printed message.
    :param level: The log level ('info', 'error', or 'warning').
    """
    formatted_message = format_message(message, style)
    print(formatted_message)
    if level == 'info':
        logging.info(message)
    elif level == 'error':
        logging.error(message)
    elif level == 'warning':
        logging.warning(message)

def chmod_file_or_directory(file_path: str):
    """
    Adjusts permissions for a file or directory to ensure it's accessible.

    :param file_path: Path to the file or directory whose permissions are to be adjusted.
    """
    if os.path.isfile(file_path):
        os.chmod(file_path, stat.S_IRUSR | stat.S_IWUSR | stat.S_IRGRP | stat.S_IROTH)
        log_and_print(f"Fixed permissions for file: {file_path}", Style.INFO)
    elif os.path.isdir(file_path):
        os.chmod(file_path, stat.S_IRWXU | stat.S_IRGRP | stat.S_IXGRP | stat.S_IROTH | stat.S_IXOTH)
        log_and_print(f"Fixed permissions for directory: {file_path}", Style.INFO)



def run_all_tasks():
    for key in map(str, range(1, 27)):
        try:
            menu_options[key]()
        except KeyError as e:
            log_and_print(format_message(f"Error executing task {key}: {e}", Style.RED), 'error')

def confirm_deletion(file_or_dir):
    confirm = input(f"Do you really want to delete {file_or_dir}? [y/N]: ").lower().strip()
    return confirm == 'y'

def process_dep_scan_log():
    log_and_print(f"{Style.INFO} Processing dependency scan log...")
    if os.path.isfile(DEP_SCAN_LOG):
        with open(DEP_SCAN_LOG) as log:
            for line in log:
                if "permission warning" in line:
                    process_permission_warning(line)
                elif "missing dependency" in line:
                    install_missing_dependency(line.split(": ")[1].strip())
    else:
        log_and_print(f"{Style.FAILURE} Dependency scan log file not found.", 'error')
    log_and_print(f"{Style.SUCCESS} Dependency scan log processing completed.", 'info')

def process_permission_warning(line):
    file_path = line.split(": ")[1].strip()
    chmod_file_or_directory(file_path)

def install_missing_dependency(dependency):
    log_and_print(f"{Style.INFO}Attempting to install missing dependency: {dependency}", 'info')
    result = execute_command(PACMAN_CMD + [dependency])
    if result:
        log_and_print(f"{Style.SUCCESS} Successfully installed missing dependency: {dependency}", 'info')
    else:
        log_and_print(f"{Style.FAILURE} Failed to install missing dependency: {dependency}", 'error')

#2 --- // Manage_Cron_Job_with_Corrected_Grep:
def manage_cron_job():
    cron_command = f"find {log_dir} -name '*_permissions.log' -mtime +30 -exec rm {{}} \\;"
    cron_entry = f"0 0 * * * {cron_command}"
    try:
        # Deduplicate cron jobs if exist:
        existing_crons_result = subprocess.run(["sudo", "crontab", "-l"], capture_output=True, text=True)
        if existing_crons_result.returncode in [0, 1]:  # Allow 'no crontab' error
            existing_crons = existing_crons_result.stdout
            new_crons = '\n'.join([line for line in existing_crons.splitlines() if cron_command not in line])

            # Add the new cron job:
            new_crons += f"\n{cron_entry}\n"

            temp_cron_path = os.path.expanduser("~/.cron_temp")
            with open(temp_cron_path, "w") as temp_file:
                temp_file.write(new_crons)

            subprocess.run(["sudo", "crontab", temp_cron_path], check=True)
            os.remove(temp_cron_path)

            log_and_print(f"{Style.SUCCESS} Cron job set up to delete old logs.", 'info')
        else:
            log_and_print(f"{Style.FAILURE} Error reading existing cron jobs: {existing_crons_result.stderr.strip()}", 'error')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{Style.FAILURE} Error managing cron job: {e.stderr.strip()}", 'error')

# --- // BROKEN_SYMLINKS:
def remove_broken_symlinks():
    log_and_print(f"{Style.INFO} Searching for broken symbolic links...", 'info')
    try:
        # Start the spinner
        _, stop_spinner = spinner()

        # Long-running command that searches for broken symlinks
        broken_links = subprocess.check_output(
            ["sudo", "find", "/", "-xtype", "l"],
            stderr=subprocess.STDOUT,
            text=True
        ).strip()

        # Stop the spinner once the command is done
        stop_spinner()

        if broken_links:
            log_and_print(f"{Style.INFO} Broken symbolic links found:\n{broken_links}", 'info')
            # Logic to handle removal of broken links could go here
        else:
            log_and_print(f"{Style.SUCCESS} No broken symbolic links found.", 'info')
    except subprocess.CalledProcessError as e:
        # Ensure the spinner is stopped in case of an error
        stop_spinner()
        log_and_print(f"{Style.FAILURE} Error searching for broken symbolic links: {e.output.strip()}", 'error')


#4 --- // Cleanup_Old_Kernel_Images:

def clean_old_kernels():
    log_and_print(f"{Style.INFO} Cleaning up old kernel images...", 'info')
    try:
        # List explicitly installed packages that are not required by any other package
        explicitly_installed_result = subprocess.run(["pacman", "-Qet"], capture_output=True, text=True, check=True)
        explicitly_installed = explicitly_installed_result.stdout.strip().split('\n')

        # Get currently running kernel version
        current_kernel_result = subprocess.run(["uname", "-r"], capture_output=True, text=True, check=True)
        current_kernel = current_kernel_result.stdout.strip()

        # Derive the major version of the current kernel (e.g., '5.10.16-arch1-1' becomes '5.10')
        current_kernel_major_version = '.'.join(current_kernel.split('.')[:2])

        kernels_to_remove = []
        for pkg in explicitly_installed:
            if "linux" in pkg and current_kernel_major_version not in pkg:
                pkg_name = pkg.split()[0]
                # Determine if the package is a kernel or kernel headers, avoiding the current kernel
                if pkg_name.startswith("linux") and (pkg_name.endswith("headers") or pkg_name.count('-') > 1):
                    kernels_to_remove.append(pkg_name)

        # Execute removal of identified old kernels
        if kernels_to_remove:
            remove_command = ["sudo", "pacman", "-Rns"] + kernels_to_remove
            subprocess.run(remove_command, check=True)
            log_and_print(f"{Style.SUCCESS} Old kernel images cleaned up: {' '.join(kernels_to_remove)}", 'info')
        else:
            log_and_print(f"{Style.INFO} No old kernel images to remove.", 'info')
    except subprocess.CalledProcessError as e:
        # Handle errors from subprocess execution, including failed removals
        log_and_print(f"{Style.FAILURE} Error cleaning up old kernels: {e.stderr.strip()}", 'error')



#5 --- // Vacuum_Journalctl:
def vacuum_journalctl():
    log_and_print(f"{Style.INFO} Vacuuming journalctl...", 'info')
    try:
        subprocess.run(["sudo", "journalctl", "--vacuum-time=3d"], check=True)
        log_and_print(f"{Style.SUCCESS} Journalctl vacuumed successfully.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{Style.FAILURE} Error: Failed to vacuum journalctl: {e.stderr.strip()}", 'error')



#6 --- // Clear_Cache:
def clear_cache():
    log_and_print(f"{Style.INFO} Clearing user cache...", 'info')
    try:
        cache_path = os.path.expanduser("~/.cache/")
        subprocess.run(["sudo", "find", cache_path, "-type", "f", "-atime", "+3", "-delete"], check=True)
        log_and_print(f"{Style.SUCCESS} User cache cleared.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{Style.FAILURE} Error: Failed to clear cache: {e.stderr.strip()}", 'error')




#7 --- // Update_Font_Cache:
def update_font_cache():
    log_and_print(f"{Style.INFO} Updating font cache...", 'info')
    try:
        subprocess.run(["sudo", "fc-cache", "-fv"], check=True)
        log_and_print(f"{Style.SUCCESS} Font cache updated.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{Style.FAILURE} Error: Failed to update font cache: {e.stderr.strip()}", 'error')



#8 --- // Clear_Trash:
def clear_trash():
    log_and_print(f"{Style.INFO} Clearing trash...", 'info')
    choice = input("Do you want to clear the trash? (y/n): ")
    if choice.lower() == "y":
        try:
            trash_paths = [os.path.join(os.path.expanduser("~/.local/share/Trash"), subdir) for subdir in ["files/*", "info/*"]]
            for trash_path in trash_paths:
                subprocess.run(["sudo", "rm", "-rf", trash_path], check=True)
            log_and_print(f"{Style.SUCCESS} Trash cleared.", 'info')
        except subprocess.CalledProcessError as e:
            log_and_print(f"{Style.FAILURE} Error: Failed to clear trash: {e.stderr.strip()}", 'error')
    else:
        log_and_print(f"{Style.INFO} Skipping trash clearance.", 'info')



#9 --- // Optimize_Databases:
def optimize_databases():
    log_and_print(f"{Style.INFO} Optimizing system databases...", 'info')
    optimization_steps = [
        (["sudo", "updatedb"], "'locate' database updated."),
        (["sudo", "pkgfile", "-u"], "'pkgfile' database updated."),
        (["sudo", "pacman-key", "--refresh-keys"], "Pacman keyring refreshed."),
        (["sudo", "journalctl", "--vacuum-size=500M"], "Systemd journal logs optimized to retain only the last 500MB."),
        (["sudo", "mandb"], "Manual pages database rebuilt."),
        (["sudo", "update-mime-database", "/usr/share/mime"], "Shared MIME-info database updated.")
    ]

    for command, success_message in optimization_steps:
        try:
            subprocess.run(command, check=True)
            log_and_print(f"{Style.SUCCESS} {success_message}", 'info')
        except subprocess.CalledProcessError as e:
            error_message = e.stderr.strip() if e.stderr else "Command failed without an error message"
            log_and_print(f"{Style.FAILURE} Error: Failed to optimize databases: {error_message}", 'error')
            return  # Exit the function on the first error encountered

    log_and_print(f"{Style.SUCCESS} System databases optimized.", 'info')




#10 --- // Clean_Package_Cache:
def clean_package_cache():
    log_and_print(f"{Style.INFO} Cleaning package cache...", 'info')
    try:
        subprocess.run(["sudo", "paccache", "-rk2"], check=True)
        log_and_print(f"{Style.SUCCESS} Package cache cleaned.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{Style.FAILURE} Error: Failed to clean package cache: {e.stderr.strip()}", 'error')



#11 --- // Clean_AUR_dir:
def clean_aur_dir():
    log_and_print(f"{Style.INFO} Cleaning AUR directory...", 'info')
    aur_dir = input("Please enter the path to the AUR directory you want to clean: ").strip()

    if not os.path.isdir(aur_dir):
        log_and_print(f"{Style.FAILURE} The specified path is not a directory.", 'error')
        return

    pkgname_regex = re.compile(r'(?P<pkgname>.*?)-(?P<pkgver>[^-]+)-(?P<arch>x86_64|any|i686)\.pkg\.tar\.(xz|zst|gz|bz2|lrz|lzo|lz4|lz)$')
    files = {}

    for f in os.listdir(aur_dir):
        full_path = os.path.join(aur_dir, f)
        if not os.path.isfile(full_path):
            continue
        match = pkgname_regex.match(f)
        if match:
            files[full_path] = "{pkgname}-{pkgver}-{arch}".format(**match.groupdict())

    try:
        installed = subprocess.check_output(["expac", "-Qs", "%n-%v-%a"], universal_newlines=True).splitlines()
    except subprocess.CalledProcessError as e:
        log_and_print(f"{Style.FAILURE} Error obtaining installed packages list: {e.stderr.strip()}", 'error')
        return

    for f, ff in sorted(files.items()):
        if ff not in installed:
            log_and_print(f"{Style.INFO} Deleting: {f}", 'info')
            try:
                os.remove(f)
            except OSError as e:
                log_and_print(f"{Style.FAILURE} Error deleting file {f}: {e}", 'error')

    log_and_print(f"{Style.SUCCESS} AUR directory cleaned.", 'info')




#12 --- // Handle_Pacnew_and_Pacsave_Files:
def handle_pacnew_pacsave():
    log_and_print(f"{Style.INFO} Searching for .pacnew and .pacsave files...", 'info')
    try:
        pacnew_files = subprocess.check_output(["sudo", "find", "/etc", "-type", "f", "-name", "*.pacnew"], text=True).splitlines()
        pacsave_files = subprocess.check_output(["sudo", "find", "/etc", "-type", "f", "-name", "*.pacsave"], text=True).splitlines()

        if pacnew_files:
            log_and_print(f"{Style.INFO} .pacnew files found. Consider merging:", 'info')
            for file in pacnew_files:
                print(f"  {file}")
        else:
            log_and_print(f"{Style.INFO} No .pacnew files found.", 'info')

        if pacsave_files:
            log_and_print(f"{Style.INFO} .pacsave files found. Consider reviewing:", 'info')
            for file in pacsave_files:
                print(f"  {file}")
        else:
            log_and_print(f"{Style.INFO} No .pacsave files found.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{Style.FAILURE} Error searching for .pacnew and .pacsave files: {e.stderr.strip()}", 'error')



#13 --- // Verify_Installed_Packages:
def verify_installed_packages():
    log_and_print(f"{Style.INFO} Verifying installed packages...", 'info')
    try:
        result = subprocess.run(["sudo", "pacman", "-Qkk"], check=False, text=True, capture_output=True)
        if result.returncode == 0:
            log_and_print(f"{Style.SUCCESS} All installed packages verified with no issues.", 'info')
        else:
            log_and_print(f"{Style.FAILURE} Issues found with installed packages:", 'error')
            print(result.stdout + result.stderr)
            log_and_print(f"{Style.INFO} Consider running 'pacman -Qkk' manually to investigate further.", 'info')
    except Exception as e:  # General exception catch if subprocess fails to execute
        log_and_print(f"{Style.FAILURE} Unexpected error verifying packages: {e}", 'error')



#14 --- // Check_failed_cron_jobs:
def check_failed_cron_jobs():
    log_and_print(f"{Style.INFO} Checking for failed cron jobs using journalctl...", 'info')
    try:
        failed_jobs = subprocess.check_output(["journalctl", "_SYSTEMD_UNIT=cron.service", "-p", "err", "-b"], text=True)
        if failed_jobs.strip():
            log_and_print(f"{Style.FAILURE} Failed cron jobs detected. Review journalctl for details:\n{failed_jobs}", 'error')
        else:
            log_and_print(f"{Style.SUCCESS} No failed cron jobs detected in the current boot.", 'info')
    except subprocess.CalledProcessError:
        log_and_print(f"{Style.INFO} Unable to access journal logs or no failed cron jobs detected.", 'info')


#15 --- // Clear_Docker_Images:
def clear_docker_images():
    if shutil.which("docker"):
        log_and_print(f"{Style.INFO} Clearing Docker images...", 'info')
        try:
            subprocess.run(["sudo", "docker", "image", "prune", "-af"], check=True)
            log_and_print(f"{Style.SUCCESS} Docker images cleared.", 'info')
        except subprocess.CalledProcessError as e:
            log_and_print(f"{Style.FAILURE} Error: Failed to clear Docker images: {e.stderr.strip()}", 'error')
    else:
        log_and_print(f"{Style.INFO} Docker is not installed. Skipping Docker image cleanup.", 'info')



#16 --- // Clear_temp_folder:
def clear_temp_folder():
    log_and_print(f"{Style.INFO} Clearing the temporary folder...", 'info')
    try:
        subprocess.run(["sudo", "find", "/tmp", "-mindepth", "1", "-delete"], check=True)
        log_and_print(f"{Style.SUCCESS} Temporary folder cleared.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{Style.FAILURE} Error: Failed to clear the temporary folder: {e.stderr.strip()}", 'error')

#17 --- Run_rmshit.py:
def check_rmshit_script():
    """Clean up unnecessary files with user confirmation."""
    log_and_print(f"{Style.INFO} Cleaning up unnecessary files...")

    # Improved logic to handle paths securely and efficiently
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
            '~/.thumbnails/',  # Redundant with '~/.cache/.thumbnails', consider keeping only one
            '~/.local/share/Trash/',  # Trash directory, safe to empty if confirmed with the user
           #'/var/tmp/',  # Be cautious with system-wide directories like '/tmp/', which may contain files needed by other users or system services
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
            '~/.nv/ComputeCache/',
            # ... (Add the rest of the default paths here)
    ]
    # Ask for additional paths to clean, with careful validation
    new_paths = input("Enter any additional paths to clean (separated by space): ").split()
    for path in new_paths:
        if path.startswith(("/", "usr", "bin", "sbin", "etc", "var", "lib", "dev", "proc", "sys", "/root")):
            log_and_print(f"{Style.FAILURE} Unsafe path specified, skipping: {path}", 'error')
            continue
        shittyfiles.append(path)

    for path in shittyfiles:
        expanded_path = os.path.expanduser(path)
        if os.path.exists(expanded_path) and confirm_deletion(expanded_path):
            try:
                if os.path.isfile(expanded_path) or os.path.islink(expanded_path):
                    os.remove(expanded_path)
                elif os.path.isdir(expanded_path):
                    shutil.rmtree(expanded_path)
                log_and_print(f"{Style.INFO} Deleted: {expanded_path}", 'info')
            except OSError as e:
                log_and_print(f"{Style.FAILURE} Error deleting {expanded_path}: {str(e)}", 'error')

    log_and_print(f"{Style.SUCCESS} Unnecessary files cleaned up.", 'info')


#18 --- // Remove_old_SSH_known_hosts:
def remove_old_ssh_known_hosts():
    ssh_known_hosts_file = os.path.expanduser("~/.ssh/known_hosts")
    if os.path.isfile(ssh_known_hosts_file):
        log_and_print(f"{Style.INFO} Manual review recommended for SSH known_hosts entries.", 'info')
        log_and_print(f"{Style.INFO} SSH known_hosts file path: {ssh_known_hosts_file}", 'info')

        # Provide instructions for manual review
        log_and_print(f"{Style.INFO} Use 'ssh-keygen -F [hostname]' to check for a host in the known_hosts file.", 'info')
        log_and_print(f"{Style.INFO} Use 'ssh-keygen -R [hostname]' to remove a host from the known_hosts file.", 'info')
        log_and_print(f"{Style.INFO} Consider reviewing and removing outdated or unused entries manually.", 'info')
    else:
        log_and_print(f"{Style.INFO} No SSH known_hosts file found. Skipping.", 'info')



#19 --- Remove_orphan_Vim_undo_files:
def remove_orphan_vim_undo_files():
    log_and_print(f"{Style.INFO} Searching for orphan Vim undo files...", 'info')
    home_dir = os.path.expanduser("~")
    for root, dirs, files in os.walk(home_dir):
        for file in files:
            if file.endswith(".un~"):
                original_file = os.path.splitext(os.path.join(root, file))[0]
                if not os.path.exists(original_file):
                    try:
                        os.remove(os.path.join(root, file))
                        log_and_print(f"{Style.SUCCESS} Removed orphan Vim undo file: {file}", 'info')
                    except OSError as e:
                        log_and_print(f"{Style.FAILURE} Error: Failed to remove orphan Vim undo file: {e}", 'error')


#20 --- // Force_log_rotation:
def force_log_rotation():
    log_and_print(f"{Style.INFO} Forcing log rotation...", 'info')
    try:
        subprocess.run(["sudo", "logrotate", "-f", "/etc/logrotate.conf"], check=True)
        log_and_print(f"{Style.SUCCESS} Log rotation forced. Ensure to review logrotate configurations for optimal performance.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{Style.FAILURE} Error: Failed to force log rotation: {e.stderr.strip()}", 'error')




#21 --- // Configure_ZRam:
def configure_zram():
    log_and_print(f"{Style.INFO} Configuring ZRam for better memory management...", 'info')
    if shutil.which("zramctl"):
        try:
            mem_total_cmd = ["awk", '/MemTotal/{printf "%d\\n", $2 * 1024 * 0.25}', "/proc/meminfo"]
            mem_total = int(subprocess.check_output(mem_total_cmd).decode().strip())
            zram_device = subprocess.run(["sudo", "zramctl", "--find", "--size", str(mem_total)], stdout=subprocess.PIPE, text=True, check=True).stdout.strip()
            subprocess.run(["sudo", "mkswap", zram_device], check=True)
            subprocess.run(["sudo", "swapon", zram_device, "-p", "32767"], check=True)
            log_and_print(f"{Style.SUCCESS} ZRam configured successfully on {zram_device}.", 'info')
            log_and_print(f"{Style.INFO} Consider reviewing ZRam configurations periodically to adjust as per system usage.", 'info')
        except subprocess.CalledProcessError as e:
            log_and_print(f"{Style.FAILURE} Error: Failed to configure ZRam: {e.stderr.strip()}", 'error')
    else:
        log_and_print(f"{Style.FAILURE} ZRam not available. Consider installing it first.", 'error')




#22 --- // Check_ZRam_configuration:
def check_zram_configuration():
    log_and_print(f"{Style.INFO} Checking ZRam configuration...", 'info')
    try:
        zram_status = subprocess.check_output(["zramctl"], text=True)
        if zram_status.strip():
            log_and_print(f"{Style.SUCCESS} ZRam is configured correctly. Here's the current setup:\n{zram_status}", 'info')
        else:
            log_and_print(f"{Style.INFO} ZRam is not configured. Configuring now...", 'info')
            configure_zram()
    except subprocess.CalledProcessError as e:
        log_and_print(f"{Style.FAILURE} Error: Failed to check ZRam configuration: {e.stderr.strip()}", 'error')




#23 --- // Adjust_swappiness:
def adjust_swappiness():
    swappiness_value = 10  # Recommended value might vary based on system usage and available RAM
    log_and_print(f"{Style.INFO} Adjusting swappiness to {swappiness_value}...", 'info')
    try:
        subprocess.run(["sudo", "sysctl", f"vm.swappiness={swappiness_value}"], check=True)
        log_and_print(f"{Style.SUCCESS} Swappiness adjusted to {swappiness_value}.", 'info')
        log_and_print(f"{Style.INFO} Consider monitoring system performance and adjust as needed.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{Style.FAILURE} Error: Failed to adjust swappiness: {e.stderr.strip()}", 'error')




#24 --- // Clear_system_cache:
def clear_system_cache():
    log_and_print(f"{Style.INFO} Clearing PageCache, dentries, and inodes...", 'info')
    try:
        # Using 'sync' command to ensure file system buffers are flushed before dropping caches
        subprocess.run(["sudo", "sh", "-c", "sync && echo 3 > /proc/sys/vm/drop_caches"], check=True)
        log_and_print(f"{Style.SUCCESS} System caches cleared. This operation is safe but consider running during low-activity periods.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{Style.FAILURE} Error: Failed to clear system cache: {e.stderr.strip()}", 'error')



#25 --- // Disable_unused_services:

def disable_unused_services():
    services_to_disable = ["bluetooth.service", "cups.service"]  # Example list, adjust based on your needs
    for service in services_to_disable:
        try:
            # Check if the service is enabled before attempting to disable it
            check_service = subprocess.run(["systemctl", "is-enabled", service], capture_output=True, text=True)
            if check_service.returncode == 0:
                # Confirm with the user before disabling the service
                if confirm_operation(f"Do you wish to disable {service}?"):
                    manage_system_service(service, "disable")
                else:
                    log_and_print(f"{Style.INFO} Skipping disabling {service}.", 'info')
            else:
                log_and_print(f"{Style.INFO} {service} is already disabled or not found.", 'info')
        except subprocess.CalledProcessError as e:
            log_and_print(f"{Style.FAILURE} Error checking status of {service}: {e.stderr.strip()}", 'error')


#26 --- // Check_failed_systemd_units:
def check_and_manage_system_health():
    log_and_print(f"{Style.INFO} Checking system health: systemd services, units, and journal errors...", 'info')

    # Check for failed systemd services and units
    try:
        failed_units = subprocess.check_output(["systemctl", "--failed"], text=True).strip()
        if "0 loaded units listed" not in failed_units:
            log_and_print(f"{Style.FAILURE} Failed systemd services/units detected:\n{failed_units}", 'error')
            # Offer to restart failed units
            choice = input("Attempt to restart failed units? (y/N): ").strip().lower()
            if choice == "y":
                subprocess.run(["sudo", "systemctl", "reset-failed"], check=True)
                log_and_print(f"{Style.SUCCESS} Attempted to restart failed systemd units. Please review unit statuses and logs for further investigation.", 'info')
            else:
                log_and_print(f"{Style.INFO} Skipping restart of failed units.", 'info')
        else:
            log_and_print(f"{Style.SUCCESS} No failed systemd services/units detected.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{Style.FAILURE} Error checking for failed systemd services/units: {e.stderr.strip()}", 'error')

    # Check for high-priority journal errors
    try:
        journal_errors = subprocess.check_output(["journalctl", "-p", "3", "-xb"], text=True).strip()
        if journal_errors:
            log_and_print(f"{Style.FAILURE} High-priority errors found in system logs:\n{journal_errors}", 'error')
        else:
            log_and_print(f"{Style.SUCCESS} No high-priority errors in system logs.", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{Style.FAILURE} Error checking system logs: {e.stderr.strip()}", 'error')

#27 --- // OPTIMIZE_STORAGE:
def optimize_storage():
    log_and_print(f"{Style.INFO} Optimizing storage: SSD trimming and disk usage analysis...", 'info')

    # SSD Trimming
    if shutil.which("fstrim"):
        try:
            subprocess.run(["sudo", "fstrim", "-av"], check=True)
            log_and_print(f"{Style.SUCCESS} SSDs trimmed successfully.", 'info')
        except subprocess.CalledProcessError as e:
            log_and_print(f"{Style.FAILURE} Error trimming SSDs: {e.stderr.strip()}", 'error')
    else:
        log_and_print(f"{Style.INFO} fstrim utility not found. Skipping SSD trimming.", 'info')

    # Disk Usage Analysis - Making it interactive
    analyze_path = input("Enter the path you want to analyze for disk usage (e.g., /, /home): ").strip()
    analyze_path = analyze_path if analyze_path else "/"  # Default to "/" if input is empty

    log_and_print(f"{Style.INFO} Analyzing disk usage for: {analyze_path}", 'info')
    try:
        subprocess.run(["sudo", "du", "-sh", analyze_path], check=True, stdout=subprocess.PIPE)
        log_and_print(f"{Style.SUCCESS} Disk usage analyzed for: {analyze_path}", 'info')
    except subprocess.CalledProcessError as e:
        log_and_print(f"{Style.FAILURE} Error analyzing disk usage at {analyze_path}: {e.stderr.strip()}", 'error')



# --- // Define_menuoptions_with_partial:
log_file_path = setup_logging()

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
    '26': partial(check_and_manage_system_health, log_file_path),
    '27': partial(optimize_storage, log_file_path),
    '0': partial(run_all_tasks, log_file_path)
}

# --- // MAIN_FUNCTION_DEFINITIONS // ======================================
def main():
    while True:
        os.system('clear')  # Clears the screen
        # Header
        print(f"{Style.GREEN}==================================================================={Style.NC}")
        print(f"{Style.GREEN}================= // Vacuum.py Main Menu // ======================{Style.NC}")
        print(f"{Style.GREEN}==================================================================={Style.NC}")

        # Menu options
        print(f"{Style.GREEN}1{Style.NC}) Process Dependency Log              {Style.GREEN}14{Style.NC}) Check Failed Cron Jobs")
        print(f"{Style.GREEN}2{Style.NC}) Manage Cron Jobs                   {Style.GREEN}15{Style.NC}) Clear Docker Images")
        print(f"{Style.GREEN}3{Style.NC}) Remove Broken Symlinks             {Style.GREEN}16{Style.NC}) Clear Temp Folder")
        print(f"{Style.GREEN}4{Style.NC}) Clean Old Kernels                  {Style.GREEN}17{Style.NC}) Run rmshit.py")
        print(f"{Style.GREEN}5{Style.NC}) Vacuum Journalctl                  {Style.GREEN}18{Style.NC}) Remove Old SSH Known Hosts")
        print(f"{Style.GREEN}6{Style.NC}) Clear Cache                        {Style.GREEN}19{Style.NC}) Remove Orphan Vim Undo Files")
        print(f"{Style.GREEN}7{Style.NC}) Update Font Cache                  {Style.GREEN}20{Style.NC}) Force Log Rotation")
        print(f"{Style.GREEN}8{Style.NC}) Clear Trash                        {Style.GREEN}21{Style.NC}) Configure ZRam")
        print(f"{Style.GREEN}9{Style.NC}) Optimize Databases                 {Style.GREEN}22{Style.NC}) Check ZRam Configuration")
        print(f"{Style.GREEN}10{Style.NC}) Clean Package Cache               {Style.GREEN}23{Style.NC}) Adjust Swappiness")
        print(f"{Style.GREEN}11{Style.NC}) Clean AUR Directory               {Style.GREEN}24{Style.NC}) Clear System Cache")
        print(f"{Style.GREEN}12{Style.NC}) Handle Pacnew and Pacsave Files   {Style.GREEN}25{Style.NC}) Disable Unused Services")
        print(f"{Style.GREEN}13{Style.NC}) Verify Installed Packages         {Style.GREEN}26{Style.NC}) Manage System Health")
        print(f"                                      {Style.GREEN}27{Style.NC}) Optimize Storage")
        print("0) Run All Tasks                      Q) Quit")

        command = input(f"{Style.GREEN}By your command:{Style.NC} ").strip().upper()

        if command in menu_options:
            try:
                menu_options[command]()
            except Exception as e:
                log_and_print(f"Error executing option: {e}", Style.RED, 'error')
        elif command == 'Q':
            break
        else:
            log_and_print("Invalid choice. Please try again.", Style.RED, 'error')

        input("Press Enter to continue...")

if __name__ == "__main__":
    main()
