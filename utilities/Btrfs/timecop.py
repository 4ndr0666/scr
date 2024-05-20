#!/usr/bin/python3

import os
import subprocess
import argparse
from datetime import datetime, timedelta

# Constants
FSTYPE = "btrfs"
SNAPSHOT_DIR = "/.snapshots"
SPACE_LIMIT = 0.5
FREE_LIMIT = 0.2

# Color constants for the menu
GREEN = '\033[0;32m'
NC = '\033[0m'  # No Color

def execute_command(command, shell=False):
    try:
        result = subprocess.run(command, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, shell=shell)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Error executing command: {e.stderr}")
        return None

def is_btrfs_mount_point(mount_point):
    fs_type = execute_command(["findmnt", "-n", "-o", "FSTYPE", mount_point])
    return fs_type == "btrfs"

def ensure_no_conflicting_operations(mount_point):
    balance_running = "balance is running" in execute_command(["btrfs", "balance", "status", mount_point])
    scrub_running = "scrub status: running" in execute_command(["btrfs", "scrub", "status", mount_point])
    if balance_running or scrub_running:
        raise RuntimeError("Conflicting Btrfs operation in progress.")

def verify_necessary_tools_installed():
    if not execute_command(["command", "-v", "btrfs"]):
        print("btrfs command not found. Ensure btrfs-progs is installed.")
        exit(1)
    else:
        print("Necessary tools are installed.")

def create_snapshot(subvolume, snapshot_type, label=None):
    if not os.path.exists(SNAPSHOT_DIR):
        os.makedirs(SNAPSHOT_DIR)
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    snapshot_name = f"{snapshot_type}-{timestamp}" if not label else f"{snapshot_type}-{label}-{timestamp}"
    snapshot_path = os.path.join(SNAPSHOT_DIR, snapshot_name)
    if not os.path.exists(snapshot_path):  # Ensure idempotency
        execute_command(["btrfs", "subvolume", "snapshot", subvolume, snapshot_path])
        print(f"Snapshot created: {snapshot_path}")
    else:
        print(f"Snapshot {snapshot_path} already exists.")

def delete_snapshot(snapshot_name):
    snapshot_path = os.path.join(SNAPSHOT_DIR, snapshot_name)
    if os.path.exists(snapshot_path):  # Ensure idempotency
        execute_command(["btrfs", "subvolume", "delete", snapshot_path])
        print(f"Snapshot deleted: {snapshot_path}")
    else:
        print(f"Snapshot {snapshot_path} does not exist.")

def list_snapshots():
    if not os.path.exists(SNAPSHOT_DIR):
        print(f"Snapshot directory {SNAPSHOT_DIR} does not exist.")
        return
    snapshots = os.listdir(SNAPSHOT_DIR)
    if not snapshots:
        print(f"No snapshots found in {SNAPSHOT_DIR}.")
    for snapshot in snapshots:
        snapshot_path = os.path.join(SNAPSHOT_DIR, snapshot)
        creation_time = os.path.getctime(snapshot_path)
        creation_date = datetime.fromtimestamp(creation_time).strftime("%Y-%m-%d %H:%M:%S")
        print(f"{snapshot} - Created on {creation_date}")

def cleanup_snapshots(min_age_days):
    if not os.path.exists(SNAPSHOT_DIR):
        print(f"Snapshot directory {SNAPSHOT_DIR} does not exist.")
        return
    now = datetime.now()
    snapshots = os.listdir(SNAPSHOT_DIR)
    for snapshot in snapshots:
        snapshot_path = os.path.join(SNAPSHOT_DIR, snapshot)
        creation_time = os.path.getctime(snapshot_path)
        creation_date = datetime.fromtimestamp(creation_time)
        if (now - creation_date).days >= min_age_days:
            delete_snapshot(snapshot)

def update_fstab_uuid(device):
    current_uuid = execute_command(["blkid", "-o", "value", "-s", "UUID", device])
    if current_uuid:
        with open("/etc/fstab", "r") as fstab:
            lines = fstab.readlines()
        with open("/etc/fstab", "w") as fstab:
            for line in lines:
                if "subvol=" in line:
                    line = line.replace("UUID=", f"UUID={current_uuid}")
                fstab.write(line)
        print("fstab updated with new UUIDs.")

def update_grub_uuid(device):
    root_uuid = execute_command(["blkid", "-o", "value", "-s", "UUID", device])
    if root_uuid:
        execute_command(["sed", "-i", f"s|root=UUID=[a-z0-9-]*|root=UUID={root_uuid}|", "/etc/default/grub"], shell=True)
        execute_command(["update-grub"], shell=True)
        print("GRUB updated with new UUIDs.")

def freeze_operations(mount_point):
    execute_command(["btrfs", "property", "set", "-ts", mount_point, "ro", "true"])
    print(f"Btrfs operations frozen on {mount_point}.")

def thaw_operations(mount_point):
    execute_command(["btrfs", "property", "set", "-ts", mount_point, "ro", "false"])
    print(f"Btrfs operations thawed on {mount_point}.")

def schedule_task(cron_expression, command):
    cron_job = f"{cron_expression} {command}"
    execute_command(f'(crontab -l ; echo "{cron_job}") | sort - | uniq - | crontab -', shell=True)
    print(f"Scheduled task: {cron_job}")

def run_all_tasks():
    subvolume = input("Enter the subvolume to snapshot: ")
    device = input("Enter the device to update UUID for: ")
    min_age_days = int(input("Enter the minimum age of snapshots to delete (in days): "))

    verify_necessary_tools_installed()
    
    # Ensure no conflicting operations before proceeding
    ensure_no_conflicting_operations(subvolume)
    
    # Create pre-backup and post-backup snapshots
    create_snapshot(subvolume, "pre", "pre-backup")
    create_snapshot(subvolume, "post", "post-backup")
    
    # List all snapshots
    list_snapshots()
    
    # Cleanup old snapshots
    cleanup_snapshots(min_age_days)
    
    # Update UUIDs in fstab and GRUB
    update_fstab_uuid(device)
    update_grub_uuid(device)

def show_help():
    print("Usage Instructions:")
    print(f"{GREEN}1{NC}) Create Snapshot        - Create a snapshot of a specified subvolume")
    print(f"{GREEN}2{NC}) Delete Snapshot        - Delete a specified snapshot")
    print(f"{GREEN}3{NC}) List Snapshots         - List all snapshots")
    print(f"{GREEN}4{NC}) Cleanup Snapshots      - Cleanup old snapshots based on specified age")
    print(f"{GREEN}5{NC}) Update fstab UUID      - Update the UUID in /etc/fstab for a specified device")
    print(f"{GREEN}6{NC}) Update GRUB UUID       - Update the UUID in GRUB configuration for a specified device")
    print(f"{GREEN}7{NC}) Freeze Operations      - Freeze Btrfs operations on a specified mount point")
    print(f"{GREEN}8{NC}) Thaw Operations        - Thaw Btrfs operations on a specified mount point")
    print(f"{GREEN}9{NC}) Schedule Task          - Schedule an automated task using cron")
    print(f"{GREEN}0{NC}) Run All Tasks          - Run all tasks interactively")
    print(f"{GREEN}Q{NC}) Quit                  - Exit the program")

def main():
    parser = argparse.ArgumentParser(description="Manage Btrfs Snapshots with Extended Features")
    parser.add_argument('-h', '--help', action='store_true', help='Show help message')
    args, unknown = parser.parse_known_args()

    if args.help:
        show_help()
        return

    while True:
        os.system('clear')
        print(f"===================================================================")
        print(f"    ================= {GREEN}// Timecop //{NC} =======================")
        print("===================================================================")
        print(f"{GREEN}1{NC}) Create Snapshot        {GREEN}2{NC}) Delete Snapshot")
        print(f"{GREEN}3{NC}) List Snapshots         {GREEN}4{NC}) Cleanup Snapshots")
        print(f"{GREEN}5{NC}) Update fstab UUID      {GREEN}6{NC}) Update GRUB UUID")
        print(f"{GREEN}7{NC}) Freeze Operations      {GREEN}8{NC}) Thaw Operations")
        print(f"{GREEN}9{NC}) Schedule Task")
        print(f"{GREEN}0{NC}) Run All Tasks           {GREEN}Q{NC}) Quit")

        print(f"{GREEN}By your command:{NC}")

        command = input().strip().upper()

        if command == '1':
            subvolume = input("Enter subvolume: ")
            snapshot_type = input("Enter snapshot type (pre/post/custom): ")
            label = input("Enter snapshot label (optional): ")
            create_snapshot(subvolume, snapshot_type, label)
        elif command == '2':
            snapshot_name = input("Enter snapshot name to delete: ")
            delete_snapshot(snapshot_name)
        elif command == '3':
            list_snapshots()
        elif command == '4':
            min_age_days = int(input("Enter minimum age of snapshots to delete (in days): "))
            cleanup_snapshots(min_age_days)
        elif command == '5':
            device = input("Enter device to update UUID for: ")
            update_fstab_uuid(device)
        elif command == '6':
            device = input("Enter device to update UUID for: ")
            update_grub_uuid(device)
        elif command == '7':
            mount_point = input("Enter mount point to freeze operations: ")
            freeze_operations(mount_point)
        elif command == '8':
            mount_point = input("Enter mount point to thaw operations: ")
            thaw_operations(mount_point)
        elif command == '9':
            cron_expression = input("Enter cron expression (e.g., '0 * * * *'): ")
            task = input("Enter task to automate (create-snapshot/cleanup-snapshots/update-fstab/update-grub): ")
            if task == "create-snapshot":
                subvolume = input("Enter subvolume to snapshot: ")
                snapshot_type = input("Enter snapshot type (pre/post/custom): ")
                label = input("Enter snapshot label (optional): ")
                command = f"python3 manage_snapshots.py create-snapshot {subvolume} {snapshot_type} --label {label}" if label else f"python3 manage_snapshots.py create-snapshot {subvolume} {snapshot_type}"
            elif task == "cleanup-snapshots":
                min_age_days = int(input("Enter minimum age of snapshots to delete (in days): "))
                command = f"python3 manage_snapshots.py cleanup-snapshots {min_age_days}"
            elif task == "update-fstab":
                device = input("Enter device to update UUID for: ")
                command = f"python3 manage_snapshots.py update-fstab {device}"
            elif task == "update-grub":
                device = input("Enter device to update UUID for: ")
                command = f"python3 manage_snapshots.py update-grub {device}"
            schedule_task(cron_expression, command)
        elif command == '0':
            run_all_tasks()
        elif command == 'Q':
            break
        else:
            show_help()

        input("Press Enter to continue...")

if __name__ == "__main__":
    main()
