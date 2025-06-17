#!/usr/bin/python3

import subprocess
import logging
import sys
import os
import signal
from prompt_toolkit import prompt
from apscheduler.schedulers.background import BackgroundScheduler
import shutil
import datetime
import gzip

# Ensure running as root
if os.geteuid() != 0:
    print("This script requires root privileges to perform system modifications.")
    try:
        subprocess.check_call(["sudo", sys.executable] + sys.argv)
        sys.exit(0)
    except subprocess.CalledProcessError as e:
        print("Failed to elevate privileges. Please run the script as root.")
        logging.error(f"Privilege escalation failed: {e}")
        sys.exit(1)


# Setup logging
LOG_FILENAME = "system_management.log"
logging.basicConfig(
    filename=LOG_FILENAME,
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
)

# Define the directory for systemd state snapshots
STATE_DIR = "/etc/systemd/state_snapshots"
os.makedirs(STATE_DIR, exist_ok=True)


def handle_sigquit(signum, frame):
    logging.info("SIGQUIT received, exiting gracefully.")
    print("Interrupt received, exiting...")
    sys.exit(0)


# Set the signal handler for SIGQUIT
signal.signal(signal.SIGQUIT, handle_sigquit)


def install_dependencies():
    """Checks and installs required Python packages."""
    required_packages = ["prompt_toolkit", "pytz", "tzlocal", "apscheduler"]
    missing_packages = [pkg for pkg in required_packages if not package_installed(pkg)]
    if missing_packages:
        command = ["sudo", "pacman", "-S", "--noconfirm"] + missing_packages
        subprocess.check_call(command)
        logging.info("All required packages have been successfully installed.")


def package_installed(pkg_name):
    """Check if a Python package is installed."""
    try:
        __import__(pkg_name)
        return True
    except ImportError:
        return False


def run_command(command):
    """Executes a system command and returns the output, error, and status."""
    process = subprocess.Popen(
        command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True
    )
    output, error = process.communicate()
    status = process.returncode  # Get the status code from the process return code
    if status != 0:
        logging.error(f"Command failed: {error.decode().strip()}")
    return output.decode().strip(), error.decode().strip(), status


def scheduler_setup():
    """Configures and starts the scheduler for regular operations."""
    scheduler = BackgroundScheduler()
    scheduler.add_job(snapshot_state, "interval", hours=24)
    scheduler.start()
    logging.info("Scheduler has been set up to take system snapshots every 24 hours.")


def snapshot_state():
    """Takes a snapshot of the current state of systemd units with a human-readable timestamp."""
    # New human-readable format: 05:30 PM Wednesday | Jan 01, 2024
    current_time = datetime.datetime.now()
    formatted_time = current_time.strftime("%I:%M %p %A | %b %d, %G")
    snapshot_name = f"SystemSnapshot_{formatted_time}.conf"
    snapshot_path = os.path.join(STATE_DIR, snapshot_name)

    output, error, status = run_command("systemctl list-unit-files")
    if status == 0:
        with open(snapshot_path, "w") as f:
            f.write(output)
        logging.info(f"Snapshot saved successfully at {snapshot_path}")
    else:
        logging.error(f"Failed to take snapshot: {error}")


DEFAULT_UNITS = [
    "wireplumber.service",
    "psd.service",
    "xdg-user-dirs-update.service",
    "p11-kit-server.socket",
    "gcr-ssh-agent.socket",
    "pipewire.socket",
    "gnome-keyring-daemon.socket",
    "pipewire-pulse.socket",
    "libinput-gestures.service",
    "pipewire-session-manager.service",
    "getty@tty1.service",
    "linux-modules-cleanup.service",
    "NetworkManager-wait-online.service",
    "btrfs-balance.timer",
    "btrfs-defrag.timer",
    "btrfs-scrub.timer",
    "btrfs-trim.timer",
    "snapper-cleanup.timer",
    "snapper-timeline.timer",
    "remote-fs.target",
    "garuda-pacman-lock.service",
    "garuda-pacman-snapshot-reject.service",
    "grub-btrfs-snapper.path",
    "ModemManager.service",
    "NetworkManager.service",
    "expressvpn.service",
    "ufw.service",
    "systemd-oomd.service",
    "cronie.service",
    "earlyoom.service",
    "avahi-daemon.service",
    "systemd-oomd.socket",
    "avahi-daemon.socket",
    "systemd-timesyncd.service",
    "haveged.service",
    "systemd-boot-check-no-failures.service",
    "dbus-org.freedesktop.ModemManager1.service",
    "dbus-org.freedesktop.nm-dispatcher.service",
    "dbus-org.freedesktop.timesync1.service",
    "display-manager.service",
    "default.target",
    "dbus-org.freedesktop.oom1.service",
    "earlyoom.service",
    "dbus-org.bluez.service",
    "dbus-org.freedesktop.Avahi.service",
    "proc-sys-fs-binfmt_misc.automount",
]


def reset_to_factory_defaults():
    """Resets the system to factory settings using predefined systemd units."""
    for unit in DEFAULT_UNITS:
        output, error, status = run_command(f"systemctl enable --now {unit}")
        if status == 0:
            logging.info(f"{unit} enabled and started.")
        else:
            logging.error(f"Failed to enable/start {unit}: {error}")


def compare_snapshot_with_current(snapshot_name, tool="diffuse"):
    """Compares the snapshot with the current state using a specified tool."""
    current_state_path = os.path.join(STATE_DIR, "current_system_state.conf")
    snapshot_path = os.path.join(STATE_DIR, snapshot_name)

    # Generate current state snapshot
    output, error, status = run_command("systemctl list-unit-files")
    if status == 0:
        with open(current_state_path, "w") as f:
            f.write(output)
    else:
        logging.error(f"Failed to generate current system state: {error}")
        print("Failed to generate current system state for comparison.")
        return

    # Check if the tool is available
    if shutil.which(tool) is None:
        print(f"{tool} is not installed. Please install {tool} to use this feature.")
        return

    # Launch the comparison tool
    try:
        subprocess.run([tool, snapshot_path, current_state_path])
    except Exception as e:
        logging.error(f"Failed to launch {tool}: {e}")
        print(f"Error: Failed to launch comparison tool {tool}.")


def duplicate_snapshot(snapshot_name):
    """Duplicates a specified snapshot for backup purposes."""
    original_path = os.path.join(STATE_DIR, snapshot_name)
    duplicate_name = f"{snapshot_name}_backup_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.conf"
    duplicate_path = os.path.join(STATE_DIR, duplicate_name)
    if os.path.exists(original_path):
        shutil.copy2(original_path, duplicate_path)
        logging.info(f"Duplicated snapshot: {duplicate_name}")
        print(f"Duplicated snapshot: {duplicate_name}")
    else:
        print("Original snapshot not found.")
        logging.error(
            "Attempted to duplicate a non-existent snapshot: " + snapshot_name
        )


def delete_snapshot(snapshot_name):
    """Deletes a specified snapshot."""
    snapshot_path = os.path.join(STATE_DIR, snapshot_name)
    if os.path.exists(snapshot_path):
        os.remove(snapshot_path)
        logging.info(f"Deleted snapshot: {snapshot_name}")
        print(f"Deleted snapshot: {snapshot_name}")
    else:
        print("Snapshot not found.")
        logging.error("Attempted to delete a non-existent snapshot: " + snapshot_name)


def compress_snapshot(snapshot_name):
    """Compresses a specified snapshot."""
    snapshot_path = os.path.join(STATE_DIR, snapshot_name)
    compressed_path = snapshot_path + ".gz"
    if os.path.exists(snapshot_path):
        try:
            with open(snapshot_path, "rb") as f_in:
                with gzip.open(compressed_path, "wb") as f_out:
                    shutil.copyfileobj(f_in, f_out)
            logging.info(f"Compressed snapshot: {compressed_path}")
            print(f"Compressed snapshot saved as {compressed_path}")
        except Exception as e:
            logging.error(f"Failed to compress {snapshot_name}: {e}")
            print(f"Error: Failed to compress snapshot {snapshot_name}.")
    else:
        print("Snapshot not found.")
        logging.error("Attempted to compress a non-existent snapshot: " + snapshot_name)


def view_snapshot_contents(snapshot_name):
    """Displays the contents of a specified snapshot with an option to compare."""
    print(f"Selected snapshot: {snapshot_name}")
    print("1. View Contents")
    print("2. Compare with Current System State using Diffuse")
    print("3. Compare with Current System State using Meld")
    action = input("Choose an action (1-3): ").strip()

    if action == "1":
        snapshot_path = os.path.join(STATE_DIR, snapshot_name)
        if os.path.exists(snapshot_path):
            print(f"Contents of {snapshot_name}:")
            with open(snapshot_path, "r") as file:
                contents = file.read()
                print(contents)
        else:
            print("Snapshot not found.")
            logging.error("Attempted to view a non-existent snapshot: " + snapshot_name)
    elif action == "2":
        compare_snapshot_with_current(snapshot_name, "diffuse")
    elif action == "3":
        compare_snapshot_with_current(snapshot_name, "meld")
    else:
        print("Invalid action.")


def print_menu():
    """Prints the interactive menu options with colored '911'."""
    print("\n\n")
    print(" ___ _  _ ___ __   ")
    print("[__  \\_/ [__ |  \\ ")
    print(
        " ___] |  ___]|__/\033[92m911\033[0m"
    )  # Corrected ANSI code for lime green '911'
    print("1. Snapshot System State")
    print("2. View and Manage Snapshots")
    print("3. Delete Snapshot")
    print("4. Compress Snapshot System State")
    print("5. Reset System to Factory Defaults")
    print("6. Exit")
    print("\n")


def menu():
    """Displays the main menu and handles user input for actions."""
    while True:
        print_menu()  # Print the main menu at the beginning of each loop iteration
        user_input = input("Select command (1-6): ").strip()
        if user_input == "1":
            snapshot_state()
        elif user_input == "2":
            view_and_manage_snapshots()
        elif user_input == "3":
            snapshot_name = prompt("Enter the snapshot name to delete: ")
            delete_snapshot(snapshot_name)
        elif user_input == "4":
            snapshot_name = prompt("Enter the snapshot name to compress: ")
            compress_snapshot(snapshot_name)
        elif user_input == "5":
            reset_to_factory_defaults()
        elif user_input == "6":
            print("Exiting...")
            break
        else:
            print("Invalid command. Please enter a number from 1 to 6.")
        print(
            "\n"
        )  # Optional: add a newline for better separation between command executions


def view_and_manage_snapshots():
    """Displays existing snapshots and allows further management actions."""
    snapshots = os.listdir(STATE_DIR)
    if not snapshots:
        print("No snapshots found.")
        return
    for i, snapshot in enumerate(snapshots, start=1):
        print(f"{i}. {snapshot}")
    choice = input(
        "Select a snapshot to manage (type number) or 'R' to return: "
    ).strip()
    if choice.lower() == "r":
        return
    elif choice.isdigit() and int(choice) in range(1, len(snapshots) + 1):
        snapshot_name = snapshots[int(choice) - 1]
        manage_snapshot(snapshot_name)
    else:
        print("Invalid selection.")


def manage_snapshot(snapshot_name):
    """Provides options to manage a selected snapshot."""
    print(f"\nManaging Snapshot: {snapshot_name}")
    print("1. Delete")
    print("2. Compress")
    print("3. Rename")
    print("4. View Contents")
    print("5. Duplicate")
    print("6. Return to Main Menu")
    action = input("Choose an action (1-6): ")
    if action == "1":
        delete_snapshot(snapshot_name)
    elif action == "2":
        compress_snapshot(snapshot_name)
    elif action == "3":
        rename_snapshot(snapshot_name)
    elif action == "4":
        view_snapshot_contents(snapshot_name)
    elif action == "5":
        duplicate_snapshot(snapshot_name)
    elif action == "6":
        return  # Return to main menu
    else:
        print("Invalid action. Please select a valid option.")


if __name__ == "__main__":
    install_dependencies()
    scheduler_setup()
    menu()
