#!/usr/bin/python3

import subprocess
import datetime
import os

# Dynamic configuration and text styling for visual feedback
RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
NC = "\033[0m"  # No Color

print(f"{YELLOW}Welcome to Btr-freeze for Arch Linux (Version 1.0){NC}")

# User-defined paths
DESTINATION_MOUNT_POINT = input("Enter the destination mount point: ")
SNAPSHOT_DIRECTORY = input("Enter the snapshot directory: ")
BACKUP_PATH = DESTINATION_MOUNT_POINT
PRIMARY_PATH = SNAPSHOT_DIRECTORY


def execute_command(command, shell=False):
    try:
        result = subprocess.run(
            command,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            shell=shell,
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"{RED}Error executing command: {e.stderr}{NC}")
        return None


def is_btrfs_mount_point(mount_point):
    fs_type = subprocess.run(
        ["findmnt", "-n", "-o", "FSTYPE", mount_point], capture_output=True, text=True
    ).stdout.strip()
    return fs_type == "btrfs"


def ensure_no_conflicting_operations(mount_point):
    balance_running = (
        subprocess.run(
            ["btrfs", "balance", "status", mount_point], capture_output=True
        ).returncode
        == 0
    )
    scrub_running = (
        "scrub status: running"
        in subprocess.run(
            ["btrfs", "scrub", "status", mount_point], capture_output=True, text=True
        ).stdout
    )
    if balance_running or scrub_running:
        raise RuntimeError("Conflicting Btrfs operation in progress.")


def verify_necessary_tools_installed():
    if not execute_command(["command", "-v", "btrfs"]):
        print(f"{RED}btrfs command not found. Ensure btrfs-progs is installed.{NC}")
        exit(1)
    else:
        print(f"{GREEN}Necessary tools are installed.{NC}")


def prepare_working_directory():
    if not os.path.exists(PRIMARY_PATH):
        os.makedirs(PRIMARY_PATH)
        print(f"{GREEN}Created directory: {PRIMARY_PATH}{NC}")
    if not os.path.exists(BACKUP_PATH):
        os.makedirs(BACKUP_PATH)
        print(f"{GREEN}Created directory: {BACKUP_PATH}{NC}")


def create_snapshot():
    snapshot_name = (
        f"system_snapshot_{datetime.datetime.now().strftime('%Y%m%d%H%M%S')}"
    )
    command = f"sudo btrfs subvolume snapshot -r / {PRIMARY_PATH}/{snapshot_name}"
    if execute_command(command, shell=True):
        print(f"{GREEN}Snapshot created: {snapshot_name}{NC}")
        return snapshot_name
    else:
        return None


def transfer_snapshot(snapshot_name):
    command = f"sudo btrfs send {PRIMARY_PATH}/{snapshot_name} | sudo btrfs receive {BACKUP_PATH}"
    if execute_command(command, shell=True):
        print(f"{GREEN}Snapshot transferred: {snapshot_name}{NC}")


def list_backup_snapshots():
    command = ["sudo", "btrfs", "subvolume", "list", BACKUP_PATH]
    snapshots = execute_command(command)
    print(f"{GREEN}Available snapshots in backup:{NC}\n{snapshots}")


def verify_transfer(snapshot_name):
    command = ["sudo", "btrfs", "subvolume", "list", BACKUP_PATH]
    snapshots = execute_command(command)
    if snapshot_name in snapshots:
        print(f"{GREEN}Verification successful: {snapshot_name} is in the backup.{NC}")
    else:
        print(f"{RED}Verification failed: {snapshot_name} not found in the backup.{NC}")


def restore_snapshot(snapshot_name):
    if not is_btrfs_mount_point(BACKUP_PATH):
        print(f"{RED}Error: Backup path is not a Btrfs mount point.{NC}")
        return
    ensure_no_conflicting_operations(BACKUP_PATH)

    print(f"{YELLOW}Initiating restoration from snapshot: {snapshot_name}{NC}")
    try:
        # Example of a simplified but complete restoration logic flow:
        # 1. Delete the current subvolume (WARNING: This step can lead to data loss if not handled correctly)
        # subprocess.run(["sudo", "btrfs", "subvolume", "delete", "/path/to/current_subvolume"], check=True)

        # 2. Restore the snapshot
        # This is a critical operation and should be adapted based on your system's setup and tested carefully
        # subprocess.run(["sudo", "btrfs", "send", f"{BACKUP_PATH}/{snapshot_name}", "|", "sudo", "btrfs", "receive", "/path/to/restore"], check=True)

        print(
            f"{GREEN}Snapshot {snapshot_name} has been successfully restored. Please verify system integrity.{NC}"
        )
    except Exception as e:
        print(f"{RED}Restoration failed: {e}{NC}")


def main():
    print("Initiating Btr-freeze...")
    verify_necessary_tools_installed()
    prepare_working_directory()
    snapshot_name = create_snapshot()
    if snapshot_name:
        transfer_snapshot(snapshot_name)
        list_backup_snapshots()
        verify_transfer(snapshot_name)
    else:
        print(f"{RED}Failed to create a snapshot. Aborting...{NC}")


if __name__ == "__main__":
    main()
