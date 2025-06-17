#!/usr/bin/python3

import os
import subprocess
from datetime import datetime

# Constants
SNAPSHOT_DIR = "/.snapshots"
MOUNT_POINTS = {
    "sdd3": "/mnt/dev",
    "sdc3": "/run/media/root/garuda-hypr",
    "sdb5": "/run/media/liveuser/Nas",
}
LOG_FILE = "/var/log/btrfs_management.log"
RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
NC = "\033[0m"  # No Color


def log_message(message):
    with open(LOG_FILE, "a") as log_file:
        log_file.write(f"{datetime.now()}: {message}\n")


#!/usr/bin/python3


# Constants
SNAPSHOT_DIR = "/.snapshots"
MOUNT_POINTS = {
    "sdd3": "/mnt/dev",
    "sdc3": "/run/media/root/garuda-hypr",
    "sdb5": "/run/media/liveuser/Nas",
}
LOG_FILE = "/var/log/btrfs_management.log"
RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
NC = "\033[0m"  # No Color


def log_message(message):
    with open(LOG_FILE, "a") as log_file:
        log_file.write(f"{datetime.now()}: {message}\n")
    print(message)


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
        log_message(
            f"Executed: {' '.join(command) if isinstance(command, list) else command}"
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        log_message(f"{RED}Error executing command: {e.stderr}{NC}")
        return None


def is_btrfs_mount_point(mount_point):
    fs_type = execute_command(["findmnt", "-n", "-o", "FSTYPE", mount_point])
    return fs_type == "btrfs"


def ensure_no_conflicting_operations(mount_point):
    balance_running = "balance is running" in execute_command(
        ["btrfs", "balance", "status", mount_point]
    )
    scrub_running = "scrub status: running" in execute_command(
        ["btrfs", "scrub", "status", mount_point]
    )
    if balance_running or scrub_running:
        raise RuntimeError("Conflicting Btrfs operation in progress.")


def verify_necessary_tools_installed():
    if not execute_command(["command", "-v", "btrfs"]):
        log_message(
            f"{RED}btrfs command not found. Ensure btrfs-progs is installed.{NC}"
        )
        exit(1)
    if not execute_command(["command", "-v", "btrbk"]):
        log_message(f"{RED}btrbk command not found. Ensure btrbk is installed.{NC}")
        exit(1)
    log_message(f"{GREEN}Necessary tools are installed.{NC}")


def prepare_working_directory(path):
    if not os.path.exists(path):
        os.makedirs(path)
        log_message(f"{GREEN}Created directory: {path}{NC}")


def create_snapshot(mount_point, snapshot_type, label=None):
    snapshot_dir = os.path.join(mount_point, SNAPSHOT_DIR)
    prepare_working_directory(snapshot_dir)
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    snapshot_name = (
        f"{snapshot_type}-{timestamp}"
        if not label
        else f"{snapshot_type}-{label}-{timestamp}"
    )
    snapshot_path = os.path.join(snapshot_dir, snapshot_name)
    if not os.path.exists(snapshot_path):  # Ensure idempotency
        execute_command(
            ["btrfs", "subvolume", "snapshot", "-r", mount_point, snapshot_path]
        )
        log_message(f"{GREEN}Snapshot created: {snapshot_path}{NC}")
        return snapshot_name
    else:
        log_message(f"{YELLOW}Snapshot {snapshot_path} already exists.{NC}")
        return None


def delete_snapshot(mount_point, snapshot_name):
    snapshot_path = os.path.join(mount_point, SNAPSHOT_DIR, snapshot_name)
    if os.path.exists(snapshot_path):  # Ensure idempotency
        execute_command(["btrfs", "subvolume", "delete", snapshot_path])
        log_message(f"{GREEN}Snapshot deleted: {snapshot_path}{NC}")
    else:
        log_message(f"{YELLOW}Snapshot {snapshot_path} does not exist.{NC}")


def list_snapshots(mount_point):
    snapshot_dir = os.path.join(mount_point, SNAPSHOT_DIR)
    if not os.path.exists(snapshot_dir):
        log_message(f"{YELLOW}Snapshot directory {snapshot_dir} does not exist.{NC}")
        return
    snapshots = os.listdir(snapshot_dir)
    if not snapshots:
        log_message(f"{YELLOW}No snapshots found in {snapshot_dir}.{NC}")
    for snapshot in snapshots:
        snapshot_path = os.path.join(snapshot_dir, snapshot)
        creation_time = os.path.getctime(snapshot_path)
        creation_date = datetime.fromtimestamp(creation_time).strftime(
            "%Y-%m-%d %H:%M:%S"
        )
        print(f"{snapshot} - Created on {creation_date}")


def restore_snapshot(source_mount, snapshot_name, target_mount):
    snapshot_path = os.path.join(source_mount, SNAPSHOT_DIR, snapshot_name)
    target_path = os.path.join(target_mount, SNAPSHOT_DIR, f"restored_{snapshot_name}")
    if not os.path.exists(snapshot_path):
        log_message(f"{YELLOW}Snapshot {snapshot_path} does not exist.{NC}")
        return
    if not os.path.exists(target_mount):
        log_message(f"{YELLOW}Target mount point {target_mount} does not exist.{NC}")
        return
    execute_command(
        f"sudo btrfs send {snapshot_path} | sudo btrfs receive {target_path}",
        shell=True,
    )
    log_message(f"{GREEN}Snapshot {snapshot_name} restored to {target_path}{NC}")


def transfer_snapshot(source_mount, snapshot_name, target_mount):
    snapshot_path = os.path.join(source_mount, SNAPSHOT_DIR, snapshot_name)
    if not os.path.exists(snapshot_path):
        log_message(f"{YELLOW}Snapshot {snapshot_path} does not exist.{NC}")
        return
    if not is_btrfs_mount_point(target_mount):
        log_message(
            f"{YELLOW}Target mount point {target_mount} is not a Btrfs mount point.{NC}"
        )
        return
    command = f"sudo btrfs send {snapshot_path} | sudo btrfs receive {target_mount}"
    if execute_command(command, shell=True):
        log_message(f"{GREEN}Snapshot transferred: {snapshot_name}{NC}")


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
        log_message(f"{GREEN}fstab updated with new UUIDs.{NC}")


def update_grub_uuid(device):
    root_uuid = execute_command(["blkid", "-o", "value", "-s", "UUID", device])
    if root_uuid:
        execute_command(
            [
                "sed",
                "-i",
                f"s|root=UUID=[a-z0-9-]*|root=UUID={root_uuid}|",
                "/etc/default/grub",
            ],
            shell=True,
        )
        execute_command(["update-grub"], shell=True)
        log_message(f"{GREEN}GRUB updated with new UUIDs.{NC}")


def main():
    print(f"{YELLOW}Welcome to Btrfs Management Script{NC}")
    verify_necessary_tools_installed()

    while True:
        print("\nOptions:")
        print(f"{GREEN}1{NC}) Create Snapshot        {GREEN}2{NC}) Delete Snapshot")
        print(f"{GREEN}3{NC}) List Snapshots         {GREEN}4{NC}) Transfer Snapshot")
        print(f"{GREEN}5{NC}) Restore Snapshot       {GREEN}6{NC}) Update fstab UUID")
        print(f"{GREEN}7{NC}) Update GRUB UUID       {GREEN}Q{NC}) Quit")

        choice = input("Enter your choice: ").strip().upper()

        if choice == "1":
            mount_point = input(
                f"Enter mount point ({', '.join(MOUNT_POINTS.keys())}): "
            )
            if mount_point in MOUNT_POINTS:
                snapshot_type = input("Enter snapshot type (pre/post/custom): ")
                label = input("Enter snapshot label (optional): ")
                create_snapshot(MOUNT_POINTS[mount_point], snapshot_type, label)
            else:
                log_message(f"{YELLOW}Invalid mount point.{NC}")
        elif choice == "2":
            mount_point = input(
                f"Enter mount point ({', '.join(MOUNT_POINTS.keys())}): "
            )
            if mount_point in MOUNT_POINTS:
                snapshot_name = input("Enter snapshot name to delete: ")
                delete_snapshot(MOUNT_POINTS[mount_point], snapshot_name)
            else:
                log_message(f"{YELLOW}Invalid mount point.{NC}")
        elif choice == "3":
            mount_point = input(
                f"Enter mount point ({', '.join(MOUNT_POINTS.keys())}): "
            )
            if mount_point in MOUNT_POINTS:
                list_snapshots(MOUNT_POINTS[mount_point])
            else:
                log_message(f"{YELLOW}Invalid mount point.{NC}")
        elif choice == "4":
            source_mount = input(
                f"Enter source mount point ({', '.join(MOUNT_POINTS.keys())}): "
            )
            if source_mount in MOUNT_POINTS:
                snapshot_name = input("Enter snapshot name to transfer: ")
                target_mount = input(
                    f"Enter target mount point ({', '.join(MOUNT_POINTS.keys())}): "
                )
                if target_mount in MOUNT_POINTS:
                    transfer_snapshot(
                        MOUNT_POINTS[source_mount],
                        snapshot_name,
                        MOUNT_POINTS[target_mount],
                    )
                else:
                    log_message(f"{YELLOW}Invalid target mount point.{NC}")
            else:
                log_message(f"{YELLOW}Invalid source mount point.{NC}")
        elif choice == "5":
            source_mount = input(
                f"Enter source mount point ({', '.join(MOUNT_POINTS.keys())}): "
            )
            if source_mount in MOUNT_POINTS:
                snapshot_name = input("Enter snapshot name to restore: ")
                target_mount = input(
                    f"Enter target mount point ({', '.join(MOUNT_POINTS.keys())}): "
                )
                if target_mount in MOUNT_POINTS:
                    restore_snapshot(
                        MOUNT_POINTS[source_mount],
                        snapshot_name,
                        MOUNT_POINTS[target_mount],
                    )
                else:
                    log_message(f"{YELLOW}Invalid target mount point.{NC}")
            else:
                log_message(f"{YELLOW}Invalid source mount point.{NC}")
        elif choice == "6":
            device = input("Enter device to update UUID for: ")
            update_fstab_uuid(device)
        elif choice == "7":
            device = input("Enter device to update UUID for: ")
            update_grub_uuid(device)
        elif choice == "Q":
            break
        else:
            log_message(f"{YELLOW}Invalid choice. Please try again.{NC}")


if __name__ == "__main__":
    main()
