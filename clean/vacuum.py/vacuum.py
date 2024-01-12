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

# --- // Colors_and_symbols:
GREEN = '\033[0;32m'
BOLD = '\033[1m'
RED = '\033[0;31m'
NC = '\033[0m'  # No Color
SUCCESS = "✔️"
FAILURE = "❌"
INFO = "➡️"
EXPLOSION = "💥"

# --- // ECHO_WITH_COLOR:
# Success:
def prominent(message):
    print(f"{GREEN}{message}{NC}")

# Error:
def bug(message):
    print(f"{GREEN}{message}{NC}")

# --- // Logging_setup:
log_dir = os.path.join(os.path.expanduser("~"), ".local/share/system_maintenance")
os.makedirs(log_dir, exist_ok=True)
log_file_path = os.path.join(log_dir, datetime.datetime.now().strftime("%Y%m%d_%H%M%S_system_maintenance.log"))
logging.basicConfig(filename=log_file_path, level=logging.INFO, format='%(asctime)s:%(levelname)s:%(message)s')

# --- // Helper_functions:
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

# --- // Init_logfile:
system_maintenance_log_dir = os.path.join(os.path.expanduser("~"), ".local/share/system_maintenance")
system_maintenance_log_file_path = os.path.join(system_maintenance_log_dir, datetime.datetime.now().strftime("%Y%m%d_%H%M%S_system_maintenance.log"))
os.makedirs(system_maintenance_log_dir, exist_ok=True)

# --- // Open the Log File:
log_file = open(system_maintenance_log_file_path, 'a')
# --- // Run_all_tasks:
def run_all_tasks(log_file):
    # Sequentially execute all tasks
    for key in [str(k) for k in range(1, 27)]:
        try:
            menu_options[key]()
        except Exception as e:
            log_and_print(format_message(f"Error executing task {key}: {e}", RED), 'error')

#1 --- // Process_dependency_scan_log:
def process_dep_scan_log(log_file):
    prominent(f"{INFO} Processing dependency scan log...")
    dep_scan_log = "/usr/local/bin/dependency_scan.log"
    if os.path.isfile(dep_scan_log):
        with open(dep_scan_log, "r") as log:
            for line in log:
                if "permission warning" in line:
                    file_path = line.split(": ")[1].strip()
                    if os.path.isfile(file_path):
                        os.chmod(file_path, stat.S_IRUSR | stat.S_IWUSR | stat.S_IRGRP | stat.S_IROTH)
                        prominent(f"{INFO}Fixed permissions for file: {file_path}")
                    elif os.path.isdir(file_path):
                        os.chmod(file_path, stat.S_IRWXU | stat.S_IRGRP | stat.S_IXGRP | stat.S_IROTH | stat.S_IXOTH)
                        prominent(f"{INFO}Fixed permissions for directory: {file_path}")
                if "missing dependency" in line:
                    dependency = line.split(": ")[1].strip()
                    prominent(f"{INFO}Attempting to install missing dependency: {dependency}")
                    result = execute_command(["sudo", "pacman", "-Sy", "--noconfirm", dependency], log_file)
                    if result == 0:
                        prominent(f"{SUCCESS} Successfully installed missing dependency: {dependency}")
                    else:
                        bug(f"{FAILURE} Failed to install missing dependency: {dependency}")
    else:
        bug(f"{FAILURE} Dependency scan log file not found.")
    prominent(f"{SUCCESS} Dependency scan log processing completed.{SUCCESS}")

#2 --- // Manage_Cron_Job_with_Corrected_Grep:
def manage_cron_job(log_file):
    cron_command = f"find {log_dir} -name '*_permissions.log' -mtime +30 -exec rm {{}} \\;"
    cron_entry = f"0 0 * * * {cron_command}"
    try:
        # --- // Deduplicate_cron_jobs_if_exist:
        subprocess.run(["sudo", "crontab", "-l"], check=True, stdout=subprocess.PIPE)
        subprocess.run(["sudo", "crontab", "-l", "|", "grep", "-v", "-F", cron_command], check=True, stdout=subprocess.PIPE)
        # --- // Check_and_add_cron_job:
        result = execute_command(["sudo", "crontab", "-l", "|", "grep", "-F", cron_command], log_file)
        if result != 0:
            bug(f"{FAILURE} Cron job for deleting old logs not found. Setting up...")
            with open(os.path.expanduser("~/.cron_temp"), "w") as temp_file:
                temp_file.write(f"{cron_entry}\n")
                subprocess.run(["sudo", "crontab", os.path.expanduser("~/.cron_temp")], check=True)
                shutil.rmtree(os.path.expanduser("~/.cron_temp"))
            prominent(f"{SUCCESS} Cron job set up to delete old logs.")
        else:
            prominent(f"{INFO} Cron job for deleting old logs already exists.")
    except subprocess.CalledProcessError as e:
        bug(f"{FAILURE} Error: {e.stderr.strip()}")


#3 --- // Remove_Broken_Symlinks:
def remove_broken_symlinks(log_file):
    prominent(f"{INFO} Searching for broken symbolic links...")
    try:
        links_found = subprocess.check_output(["sudo", "find", "/", "-path", "/proc", "-prune", "-o", "-type", "l", "!", "-exec", "test", "-e", "{}", ";", "-print"], text=True)
        links_found = links_found.strip()
        if not links_found:
            prominent(f"{INFO} No broken symbolic links found.")
        else:
            print(links_found)
            choice = input("Do you wish to remove the above broken symbolic links? (y/n): ")
            if choice.lower() == "y":
                try:
                    subprocess.run(["sudo", "find", links_found, "-delete"], check=True)
                    prominent(f"{SUCCESS} Broken symbolic links removed.")
                except subprocess.CalledProcessError as e:
                    bug(f"{FAILURE} Error: {e.stderr.strip()}")
            else:
                prominent(f"{INFO} Skipping removal of broken symbolic links.")
    except subprocess.CalledProcessError as e:
        bug(f"{FAILURE} Error: {e.stderr.strip()}")


#4 --- // Cleanup_Old_Kernel_Images:
def clean_old_kernels(log_file):
    prominent(f"{INFO} Cleaning up old kernel images...")
    try:
        subprocess.run(["sudo", "pacman", "-R", "$(pacman", "-Qdtq)"], check=True)
        prominent(f"{SUCCESS} Old kernel images cleaned up.")
    except subprocess.CalledProcessError as e:
        bug(f"{FAILURE} Error: {e.stderr.strip()}", log_file)


#5 --- // Vacuum_Journalctl:
def vacuum_journalctl(log_file):
    try:
        subprocess.run(["sudo", "journalctl", "--vacuum-time=3d"], check=True)
    except subprocess.CalledProcessError as e:
        bug(f"{FAILURE} Error: Failed to vacuum journalctl", log_file)


#6 --- // Clear_Cache:
def clear_cache(log_file):
    try:
        subprocess.run(["sudo", "find", "~/.cache/", "-type", "f", "-atime", "+3", "-delete"], check=True)
    except subprocess.CalledProcessError as e:
        bug(f"{FAILURE} Error: Failed to clear cache", log_file)


#7 --- // Update_Font_Cache:
def update_font_cache(log_file):
    try:
        subprocess.run(["sudo", "fc-cache", "-fv"], check=True)
    except subprocess.CalledProcessError as e:
        bug(f"{FAILURE} Error: Failed to update font cache", log_file)


#8 --- // Clear_Trash:
def clear_trash(log_file):
    choice = input("Do you want to clear the trash? (y/n): ")
    if choice.lower() == "y":
        try:
            subprocess.run(["sudo", "rm", "-rf", "~/.local/share/Trash/*"], check=True)
        except subprocess.CalledProcessError as e:
            bug(f"{FAILURE} Error: Failed to clear trash", log_file)
    else:
        prominent(f"{INFO} Skipping trash clear.", log_file)


#9 --- // Optimize_Databases:
def optimize_databases(log_file):
    prominent(f"{INFO} Optimizing system databases...")
    try:
        subprocess.run(["sudo", "pacman-optimize"], check=True)
        subprocess.run(["sync"], check=True)
        prominent(f"{SUCCESS} System databases optimized.")
    except subprocess.CalledProcessError as e:
        bug(f"{FAILURE} Error: Failed to optimize databases", log_file)


#10 --- // Clean_Package_Cache:
def clean_package_cache(log_file):
    prominent(f" {INFO}  Cleaning package cache...")
    try:
        subprocess.run(["sudo", "paccache", "-rk2"], check=True)
        prominent(f" {SUCCESS}  Package cache cleaned.")
    except subprocess.CalledProcessError as e:
        bug(f" {FAILURE}  Error: Failed to clean package cache", log_file)


#11 --- // Clean_AUR_dir:
def clean_aur_dir(log_file):
    prominent(f"{INFO} Please enter the path to the AUR directory you want to clean:")
    aur_dir = input("Path: ").strip()  # Prompt the user for the AUR directory path

    if not os.path.isdir(aur_dir):
        bug(f"{FAILURE} The specified path is not a directory.")
        return

    os.chdir(aur_dir)
    files = {}

    # Remove files that don't match pkgname_regex from further processing
    for f in os.listdir():
        if not os.path.isfile(f):
            continue
        match = pkgname_regex.match(f)
        if match:
            # Strip extension for future comparison with expac's output
            files[f] = "{pkgname}-{pkgver}-{arch}".format(**match.groupdict())

    # Get list of installed packages
    try:
        installed = subprocess.check_output(["expac", "-Qs", "%n-%v-%a"], universal_newlines=True).splitlines()
    except subprocess.CalledProcessError as e:
        bug(f"{FAILURE} Error obtaining installed packages list: {e}", log_file)
        return

    for f in sorted(files):
        # Compare with the key instead of the whole filename
        # (drops file extensions like .pkg.tar.{xz,gz,zst}{,.sig})
        ff = files[f]

        if ff not in installed:
            prominent(f"{INFO} Deleted: {f}")
            try:
                os.remove(f)
            except OSError as e:
                bug(f"{FAILURE} Error deleting file {f}: {e}", log_file)
            except Exception as e:
                bug(f"{FAILURE} Unexpected error: {e}", log_file)

    prominent(f"{SUCCESS} AUR directory cleaned.")



#12 --- // Handle_Pacnew_and_Pacsave_Files:
def handle_pacnew_pacsave(log_file):
    pacnew_files = subprocess.check_output(["sudo", "find", "/etc", "-type", "f", "-name", "*.pacnew"], text=True).splitlines()
    pacsave_files = subprocess.check_output(["sudo", "find", "/etc", "-type", "f", "-name", "*.pacsave"], text=True).splitlines()
    if pacnew_files:
        prominent(f" {INFO}  .pacnew files found. Consider merging:")
        for file in pacnew_files:
            print(file)
    else:
        prominent(f" {INFO}  No .pacnew files found.")
    if pacsave_files:
        prominent(f" {INFO}  .pacsave files found. Consider reviewing:")
        for file in pacsave_files:
            print(file)
    else:
        prominent(f" {INFO}  No .pacsave files found.")


#13 --- // Verify_Installed_Packages:
def verify_installed_packages(log_file):
    prominent(f"{INFO} Verifying installed packages...")
    try:
        subprocess.run(["sudo", "pacman", "-Qkk"], check=True)
        prominent(f" {SUCCESS}  All installed packages verified.")
    except subprocess.CalledProcessError as e:
        bug(f" {FAILURE}  Error: Issues found with installed packages", log_file)


#14 --- // Check_failed_cron_jobs:
def check_failed_cron_jobs(log_file):
    prominent(f" {INFO}  Checking for failed cron jobs...")
    try:
        subprocess.run(["grep", "-i", "cron.*error", "/var/log/syslog"], check=True)
        prominent(f" {FAILURE}  Failed cron jobs detected. Review syslog for details.")
    except subprocess.CalledProcessError as e:
        prominent(f" {INFO}  No failed cron jobs detected.", log_file)


#15 --- // Clear_Docker_Images:
def clear_docker_images(log_file):
    if shutil.which("docker"):
        try:
            subprocess.run(["sudo", "docker", "image", "prune", "-f"], check=True)
            subprocess.run(["docker", "image", "prune", "-f"], check=True)
        except subprocess.CalledProcessError as e:
            bug(f" {FAILURE}  Error: Failed to clear Docker images", log_file)
    else:
        print(f" {INFO}  Docker is not installed. Skipping Docker image cleanup.", log_file)


#16 --- // Clear_temp_folder:
def clear_temp_folder(log_file):
    try:
        subprocess.run(["sudo", "find", "/tmp", "-type", "f", "-atime", "+2", "-delete"], check=True)
    except subprocess.CalledProcessError as e:
        bug(f" {FAILURE}  Error: Failed to clear the temporary folder", log_file)


#17 --- Run_rmshit.py:
def check_rmshit_script(log_file):
    if shutil.which("python3") and os.path.isfile("/usr/local/bin/rmshit.py"):
        try:
            subprocess.run(["python3", "/usr/local/bin/rmshit.py"], check=True)
        except subprocess.CalledProcessError as e:
            bug(f" {FAILURE}  Error: Failed to run rmshit.py", log_file)
    else:
        prominent(f" {INFO}  python3 or rmshit.py not found. Skipping.", log_file)


#18 --- // Remove_old_SSH_known_hosts:
def remove_old_ssh_known_hosts(log_file):
    ssh_known_hosts_file = os.path.expanduser("~/.ssh/known_hosts")
    if os.path.isfile(ssh_known_hosts_file):
        try:
            subprocess.run(["sudo", "find", ssh_known_hosts_file, "-mtime", "+14", "-exec", "sed", "-i", "{}d", "{}", ";"], check=True)
            subprocess.run(["find", ssh_known_hosts_file, "-mtime", "+14", "-exec", "sed", "-i", "{}d", "{}", ";"], check=True)
        except subprocess.CalledProcessError as e:
            bug(f" {FAILURE}  Error: Failed to remove old SSH known hosts entries", log_file)
    else:
        prominent(f" {INFO}  No SSH known hosts file found. Skipping.", log_file)


#19 --- Remove_orphan_Vim_undo_files:
def remove_orphan_vim_undo_files(log_file):
    for root, dirs, files in os.walk(".", topdown=False):
        for file in files:
            if file.endswith(".un~"):
                original_file = os.path.splitext(file)[0]
                if not os.path.exists(original_file):
                    try:
                        os.remove(file)
                    except OSError as e:
                        bug(f" {FAILURE}  Error: Failed to remove orphan Vim undo files: {e}", log_file)
    print(f" {SUCCESS}  Orphan Vim undo files removed.", log_file)


#20 --- // Force_log_rotation:
def force_log_rotation(log_file):
    try:
        subprocess.run(["sudo", "logrotate", "-f", "/etc/logrotate.conf"], check=True)
    except subprocess.CalledProcessError as e:
        bug(f" {FAILURE}  Error: Failed to force log rotation", log_file)


#21 --- // Configure_ZRam:
def configure_zram(log_file):
    prominent(f"{INFO} Configuring ZRam for better memory management...")
    if shutil.which("zramctl"):
        try:
            mem_total_cmd = ["awk", '/MemTotal/{printf "%d\\n", $2 * 1024 * 0.25}', "/proc/meminfo"]
            mem_total = int(subprocess.check_output(mem_total_cmd).decode().strip())
            zram_device = subprocess.run(["sudo", "zramctl", "--find", f"--size={mem_total}"], stdout=subprocess.PIPE, text=True, check=True).stdout.strip()
            subprocess.run(["sudo", "mkswap", zram_device], check=True)
            subprocess.run(["sudo", "swapon", zram_device, "-p", "32767"], check=True)
            prominent(f"{SUCCESS} ZRam configured successfully on {zram_device}.")
        except subprocess.CalledProcessError as e:
            bug(f"{FAILURE} Error: {e.stderr.decode().strip()}" if e.stderr else "Error occurred, but no stderr output.")
    else:
        bug(f"{FAILURE} ZRam not available. Consider installing it first.")



#22 --- // Check_ZRam_configuration:
def check_zram_configuration(log_file):
    if not os.path.isfile("/proc/swaps") or "zram" not in open("/proc/swaps").read():
        configure_zram(log_file)
    else:
        print(f" {INFO}  ZRam is already configured.", log_file)


#23 --- // Adjust_swappiness:
def adjust_swappiness(log_file):
    swappiness_value = 10  # Recommended for systems with low RAM
    prominent(f" {INFO}  Adjusting swappiness to {swappiness_value}...")
    try:
        subprocess.run(["echo", str(swappiness_value), "|", "sudo", "tee", "/proc/sys/vm/swappiness"], check=True)
        subprocess.run(["sudo", "sysctl", f"vm.swappiness={swappiness_value}"], check=True)
        prominent(f" {SUCCESS}  Swappiness adjusted to {swappiness_value}.")
    except subprocess.CalledProcessError as e:
        bug(f" {FAILURE}  Error: Failed to adjust swappiness", log_file)


#24 --- // Clear_system_cache:
def clear_system_cache(log_file):
    prominent(f" {INFO}  Clearing PageCache, dentries, and inodes...")
    try:
        subprocess.run(["echo", "1", "|", "sudo", "tee", "/proc/sys/vm/drop_caches"], check=True)
        prominent(f" {SUCCESS}  System caches cleared.")
    except subprocess.CalledProcessError as e:
        bug(f" {FAILURE}  Error: Failed to clear system cache", log_file)


#25 --- // Disable_unused_services:
def disable_unused_services(log_file):
    services_to_disable = ["bluetooth.service", "cups.service"]  # List of services to disable
    for service in services_to_disable:
        try:
            if subprocess.run(["systemctl", "is-enabled", service], stdout=subprocess.PIPE).returncode == 0:
                subprocess.run(["sudo", "systemctl", "disable", service], check=True)
                print(f" {SUCCESS}  Disabled {service}.", log_file)
            else:
                print(f" {INFO}  {service} is already disabled.", log_file)
        except subprocess.CalledProcessError as e:
            bug(f" {FAILURE}  Error:Failed to disable{service}",log_file)


#26 --- // Check_failed_systemd_units:
def check_and_restart_systemd_units(log_file):
        prominent(f" {INFO}  Checking and restarting systemd units...")
        try:
            # Use 'sysz' to check for failed units and restart them
            result = execute_command(["sysz"], log_file)
            if result == 0:
                prominent(f" {SUCCESS}  Systemd units checked and restarted successfully.")
            else:
                bug(f" {FAILURE}  Error checking and restarting systemd units.")
        except subprocess.CalledProcessError as e:
            bug(f" {FAILURE}  Error checking and restarting systemd units: {e.stderr.strip()}")

# --- // Define_menuoptions_with_partial:
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

# --- // MAIN_FUNCTION_DEFINITIONS // ======================================
def main():
    while True:
        os.system('clear')
        print(f"{GREEN}=======================================================================")
        print("VACUUM.PY - a system maintenance script by 4ndr0666")
        print("=======================================================================")
        print(f"{NC}=============== // Vacuum Main Menu // =====================")
        print("1) Process Dependeny Log              14) Check Failed Cron Jobs")
        print("2) Manage Cron Job                    15) Clear Docker Images")
        print("3) Remove Broken Symlinks             16) Clear Temp Folder")
        print("4) Clean Old Kernel Images            17) Run rmshit.py")
        print("5) Vacuum Journalctl                  18) Remove Old SSH Known Hosts")
        print("6) Clear Cache                        19) Remove Orphan Vim Undo Files")
        print("7) Update Font Cache                  20) Force Log Rotation")
        print("8) Clear Trash                        21) Configure ZRam")
        print("9) Optimize Databases                 22) Check ZRam Configuration")
        print("10) Clean Package Cache               23) Adjust Swappiness")
        print("11) Clean AUR Directory               24) Clear System Cache")
        print("12) Handle Pacnew and Pacsave Files   25) Disable Unused Services")
        print("13) Verify Installed Packages         26) Check Failed Systemd Units")
        print("0) Run All Tasks                      Q) Quit")
        print("By your command:")

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
