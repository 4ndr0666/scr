import os
import subprocess
import sys
import shutil
import stat
import time
import logging
import datetime
import re

# --- // Colors_and_symbols:
GREEN = '\033[0;32m'
BOLD = '\033[1m'
RED = '\033[0;31m'
NC = '\033[0m'  # No Color
SUCCESS = "✔️"
FAILURE = "❌"
INFO = "➡️"
EXPLOSION = "💥"

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
log_dir = os.path.join(os.path.expanduser("~"), ".local/share/permissions")
log_file = os.path.join(log_dir, datetime.datetime.now().strftime("%Y%d%m_%H%M%S") + "_permissions.log")
os.makedirs(log_dir, exist_ok=True)

# --- // Run_all_tasks:
def run_all_tasks():
    # This function will sequentially execute all the tasks
    for func in [process_dependency_scan_log, manage_cron_job_with_corrected_grep, remove_broken_symlinks_wSpinner, ...]:  # Add all functions here
        try:
            func(log_file)
        except Exception as e:
            log_and_print(format_message(f"Error executing {func.__name__}: {e}", RED), 'error')


# --- // MAIN_FUNCTION_DEFINITIONS // ======================================
def main():

    menu_options = {
    '1': process_dep_scan_log,
    '2': manage_cron_job,
    '3': remove_broken_symlinks,
    '4': clean_old_kernels,
    '5': vacuum_journalctl,
    '6': clear_cache,
    '7': update_font_cache,
    '8': clear_trash,
    '9': optimize_databases,
    '10': clean_package_cache,
    '11': clean_aur_directory,
    '12': handle_pacnew_pacsave,
    '13': verify_installed_packages,
    '14': check_failed_cron_jobs,
    '15': clear_docker_images,
    '16': clear_temp_folder,
    '17': check_rmshit_script,
    '18': remove_old_ssh_known_hosts,
    '19': remove_orphan_vim_undo_files,
    '20': force_log_rotation,
    '21': configure_zram,
    '22': check_zram_configuration,
    '23': adjust_swappiness,
    '24': clear_system_cache,
    '25': disable_unused_services,
    '26': check_and_restart_systemd_units,
    '0': run_all_tasks
}


    while True:
        os.system('clear')
        print(f"{GREEN}=======================================================================================")
        print("VACUUM.PY")
        print("=======================================================================================")
        print(f"{NC}=============== // Vacuum Main Menu // =====================")
        print("1) Process Dependency Scan Log        14) Check Failed Cron Jobs")
        print("2) Manage Cron Job with Corrected Grep15) Clear Docker Images")
        print("3) Remove Broken Symlinks w/ Spinner  16) Clear Temp Folder")
        print("4) Cleanup Old Kernel Images          17) Run rmshit.py Script")
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
                        prominent(f"Fixed permissions for file: {file_path}")
                    elif os.path.isdir(file_path):
                        os.chmod(file_path, stat.S_IRWXU | stat.S_IRGRP | stat.S_IXGRP | stat.S_IROTH | stat.S_IXOTH)
                        prominent(f"Fixed permissions for directory: {file_path}")
                if "missing dependency" in line:
                    dependency = line.split(": ")[1].strip()
                    prominent(f"{INFO} Attempting to install missing dependency: {dependency}")
                    result = execute_command(["sudo", "pacman", "-Sy", "--noconfirm", dependency], log_file)
                    if result == 0:
                        prominent(f"{SUCCESS} Successfully installed missing dependency: {dependency}")
                    else:
                        bug(f"{FAILURE} Failed to install missing dependency: {dependency}")
    else:
        bug(f"{FAILURE} Dependency scan log file not found.")
    prominent(f"{SUCCESS} Dependency scan log processing completed.")


#2 --- // Manage_Cron_Job_with_Corrected_Grep:
def manage_cron_job(log_file):
    cron_command = f"find {log_dir} -name '*_permissions.log' -mtime +30 -exec rm {{}} \\;"
    cron_entry = f"0 0 * * * {cron_command}"
    try:
    # --- // Deduplicate_cron_jobs_if_exist:
        subprocess.run(["crontab", "-l"], check=True, stdout=subprocess.PIPE)
        subprocess.run(["crontab", "-l", "|", "grep", "-v", "-F", cron_command], check=True, stdout=subprocess.PIPE)
    # --- // Check_and_add_cron_job:
        result = execute_command(["crontab", "-l", "|", "grep", "-F", cron_command], log_file)
        if result != 0:
            bug(f"{FAILURE} Cron job for deleting old logs not found. Setting up...")
            with open(os.path.expanduser("~/.cron_temp"), "w") as temp_file:
                temp_file.write(f"{cron_entry}\n")
                subprocess.run(["crontab", os.path.expanduser("~/.cron_temp")], check=True)
                shutil.rmtree(os.path.expanduser("~/.cron_temp"))
            prominent(f"{SUCCESS} Cron job set up to delete old logs.")
        else:
            prominent(f"{INFO} Cron job for deleting old logs already exists.")
    except subprocess.CalledProcessError as e:
        bug(f"{FAILURE} Error: {e.stderr.strip()}")


#3 --- // Remove_Broken_Symlinks_wSpinner:
def remove_broken_symlinks(log_file):
    prominent(f"{INFO} Searching for broken symbolic links...")
    try:
        links_found = subprocess.check_output(["find", "/", "-path", "/proc", "-prune", "-o", "-type", "l", "!", "-exec", "test", "-e", "{}", ";", "-print"], text=True)
        links_found = links_found.strip()
        if not links_found:
            prominent(f"{INFO} No broken symbolic links found.")
        else:
            print(links_found)
            choice = input("Do you wish to remove the above broken symbolic links? (y/n): ")
            if choice.lower() == "y":
                try:
                    subprocess.run(["find", links_found, "-delete"], check=True)
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
        subprocess.run(["journalctl", "--vacuum-time=3d"], check=True)
    except subprocess.CalledProcessError as e:
        bug(f"{FAILURE} Error: Failed to vacuum journalctl", log_file)


#6 --- // Clear_Cache:
def clear_cache(log_file):
    try:
        subprocess.run(["find", "~/.cache/", "-type", "f", "-atime", "+3", "-delete"], check=True)
    except subprocess.CalledProcessError as e:
        bug(f"{FAILURE} Error: Failed to clear cache", log_file)


#7 --- // Update_Font_Cache:
def update_font_cache(log_file):
    try:
        subprocess.run(["fc-cache", "-fv"], check=True)
    except subprocess.CalledProcessError as e:
        bug(f"{FAILURE} Error: Failed to update font cache", log_file)


#8 --- // Clear_Trash:
def clear_trash(log_file):
    choice = input("Do you want to clear the trash? (y/n): ")
    if choice.lower() == "y":
        try:
            subprocess.run(["rm", "-rf", "~/.local/share/Trash/*"], check=True)
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
    prominent(f"{INFO} Cleaning package cache...")
    try:
        subprocess.run(["sudo", "paccache", "-rk2"], check=True)
        prominent(f"{SUCCESS} Package cache cleaned.")
    except subprocess.CalledProcessError as e:
        bug(f"{FAILURE} Error: Failed to clean package cache", log_file)


#11 --- // Clean_AUR_dir:
def clean_aur_directory(log_file):
    aur_dir = "/var/cache/pacman/pkg"  # Adjust this path according to your setup
    if os.path.isfile("/usr/local/bin/clean-aur-dir.py"):
        prominent(f"{INFO} Cleaning AUR directory...")
        try:
            subprocess.run(["python3", "/usr/local/bin/clean-aur-dir.py", aur_dir], check=True)
            prominent(f"{SUCCESS} AUR directory cleaned.")
        except subprocess.CalledProcessError as e:
            bug(f"{FAILURE} Error: Failed to clean AUR directory", log_file)
    else:
        bug(f"{FAILURE} clean-aur-dir.py script not found.", log_file)


#12 --- // Handle_Pacnew_and_Pacsave_Files:
def handle_pacnew_pacsave(log_file):
    pacnew_files = subprocess.check_output(["find", "/etc", "-type", "f", "-name", "*.pacnew"], text=True).splitlines()
    pacsave_files = subprocess.check_output(["find", "/etc", "-type", "f", "-name", "*.pacsave"], text=True).splitlines()
    if pacnew_files:
        prominent(f"{INFO} .pacnew files found. Consider merging:")
        for file in pacnew_files:
            print(file)
    else:
        prominent(f"{INFO} No .pacnew files found.")
    if pacsave_files:
        prominent(f"{INFO} .pacsave files found. Consider reviewing:")
        for file in pacsave_files:
            print(file)
    else:
        prominent(f"{INFO} No .pacsave files found.")


#13 --- // Verify_Installed_Packages:
def verify_installed_packages(log_file):
    prominent(f"{INFO} Verifying installed packages...")
    try:
        subprocess.run(["sudo", "pacman", "-Qkk"], check=True)
        prominent(f"{SUCCESS} All installed packages verified.")
    except subprocess.CalledProcessError as e:
        bug(f"{FAILURE} Error: Issues found with installed packages", log_file)


#14 --- // Check_failed_cron_jobs:
def check_failed_cron_jobs(log_file):
    prominent(f"{INFO} Checking for failed cron jobs...")
    try:
        subprocess.run(["grep", "-i", "cron.*error", "/var/log/syslog"], check=True)
        prominent(f"{FAILURE} Failed cron jobs detected. Review syslog for details.")
    except subprocess.CalledProcessError as e:
        prominent(f"{INFO} No failed cron jobs detected.", log_file)


#15 --- // Clear_Docker_Images:
def clear_docker_images(log_file):
    if shutil.which("docker"):
        try:
            subprocess.run(["docker", "image", "prune", "-f"], check=True)
        except subprocess.CalledProcessError as e:
            bug(f"{FAILURE} Error: Failed to clear Docker images", log_file)
    else:
        prominent(f"{INFO} Docker is not installed. Skipping Docker image cleanup.", log_file)


#16 --- // Clear_temp_folder:
def clear_temp_folder(log_file):
    try:
        subprocess.run(["find", "/tmp", "-type", "f", "-atime", "+2", "-delete"], check=True)
    except subprocess.CalledProcessError as e:
        bug(f"{FAILURE} Error: Failed to clear the temporary folder", log_file)


#17 --- Run_rmshit.py:
def check_rmshit_script(log_file):
    if shutil.which("python3") and os.path.isfile("/usr/local/bin/rmshit.py"):
        try:
            subprocess.run(["python3", "/usr/local/bin/rmshit.py"], check=True)
        except subprocess.CalledProcessError as e:
            bug(f"{FAILURE} Error: Failed to run rmshit.py", log_file)
    else:
        prominent(f"{INFO} python3 or rmshit.py not found. Skipping.", log_file)


#18 --- // Remove_old_SSH_known_hosts:
def remove_old_ssh_known_hosts(log_file):
    ssh_known_hosts_file = os.path.expanduser("~/.ssh/known_hosts")
    if os.path.isfile(ssh_known_hosts_file):
        try:
            subprocess.run(["find", ssh_known_hosts_file, "-mtime", "+14", "-exec", "sed", "-i", "{}d", "{}", ";"], check=True)
        except subprocess.CalledProcessError as e:
            bug(f"{FAILURE} Error: Failed to remove old SSH known hosts entries", log_file)
    else:
        prominent(f"{INFO} No SSH known hosts file found. Skipping.", log_file)


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
                        bug(f"{FAILURE} Error: Failed to remove orphan Vim undo files: {e}", log_file)
    prominent(f"{SUCCESS} Orphan Vim undo files removed.", log_file)


#20 --- // Force_log_rotation:
def force_log_rotation(log_file):
    try:
        subprocess.run(["logrotate", "-f", "/etc/logrotate.conf"], check=True)
    except subprocess.CalledProcessError as e:
        bug(f"{FAILURE} Error: Failed to force log rotation", log_file)


#21 --- // Configure_ZRam:
def configure_zram(log_file):
    prominent(f"{INFO} Configuring ZRam for better memory management...")
    if shutil.which("zramctl"):
        try:
            mem_total = int(subprocess.check_output(["awk", "/MemTotal/{printf \"%d\n\", $2 * 1024 * 0.25}", "/proc/meminfo"]).decode().strip())
            subprocess.run(["sudo", "zramctl", "--find", f"--size={mem_total}"], check=True)
            subprocess.run(["sudo", "mkswap", "/dev/zram0"], check=True)
            subprocess.run(["sudo", "swapon", "/dev/zram0", "-p", "32767"], check=True)
            prominent(f"{SUCCESS} ZRam configured successfully.")
        except subprocess.CalledProcessError as e:
            bug(f"{FAILURE} Error: {e.stderr.strip()}", log_file)
    else:
        bug(f"{FAILURE} ZRam not available. Consider installing it first.", log_file)


#22 --- // Check_ZRam_configuration:
def check_zram_configuration(log_file):
    if not os.path.isfile("/proc/swaps") or "zram" not in open("/proc/swaps").read():
        configure_zram(log_file)
    else:
        prominent(f"{INFO} ZRam is already configured.", log_file)


#23 --- // Adjust_swappiness:
def adjust_swappiness(log_file):
    swappiness_value = 10  # Recommended for systems with low RAM
    prominent(f"{INFO} Adjusting swappiness to {swappiness_value}...")
    try:
        subprocess.run(["echo", str(swappiness_value), "|", "sudo", "tee", "/proc/sys/vm/swappiness"], check=True)
        subprocess.run(["sudo", "sysctl", f"vm.swappiness={swappiness_value}"], check=True)
        prominent(f"{SUCCESS} Swappiness adjusted to {swappiness_value}.")
    except subprocess.CalledProcessError as e:
        bug(f"{FAILURE} Error: Failed to adjust swappiness", log_file)


#24 --- // Clear_system_cache:
def clear_system_cache(log_file):
    prominent(f"{INFO} Clearing PageCache, dentries, and inodes...")
    try:
        subprocess.run(["echo", "1", "|", "sudo", "tee", "/proc/sys/vm/drop_caches"], check=True)
        prominent(f"{SUCCESS} System caches cleared.")
    except subprocess.CalledProcessError as e:
        bug(f"{FAILURE} Error: Failed to clear system cache", log_file)


#25 --- // Disable_unused_services:
def disable_unused_services(log_file):
    services_to_disable = ["bluetooth.service", "cups.service"]  # List of services to disable
    for service in services_to_disable:
        try:
            if subprocess.run(["systemctl", "is-enabled", service], stdout=subprocess.PIPE).returncode == 0:
                subprocess.run(["sudo", "systemctl", "disable", service], check=True)
                prominent(f"{SUCCESS} Disabled {service}.", log_file)
            else:
                prominent(f"{INFO} {service} is already disabled.", log_file)
        except subprocess.CalledProcessError as e:
            bug(f"{FAILURE}Error:Failed to disable{service}",log_file)


#26 --- // Check_failed_systemd_units:
def check_and_restart_systemd_units(log_file):
        prominent(f"{INFO} Checking and restarting systemd units...")
        try:
            # Use 'sysz' to check for failed units and restart them
            result = execute_command(["sysz"], log_file)
            if result == 0:
                prominent(f"{SUCCESS} Systemd units checked and restarted successfully.")
            else:
                bug(f"{FAILURE} Error checking and restarting systemd units.")
        except subprocess.CalledProcessError as e:
            bug(f"{FAILURE} Error checking and restarting systemd units: {e.stderr.strip()}")

if __name__ == "__main__":
    main()
