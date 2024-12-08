#!/usr/bin/env python3
import os
import subprocess
import logging
import json

logging.basicConfig(filename='permissions_fix.log', level=logging.INFO, format='%(asctime)s %(message)s')

def run_command(command):
    """
    Run a command and capture its output.

    Args:
        command (list): List containing the command and its arguments.

    Returns:
        CompletedProcess: CompletedProcess object with the result of the command.
    """
    try:
        return subprocess.run(command, capture_output=True, text=True, check=True)
    except subprocess.CalledProcessError as e:
        logging.error(f"Command '{e.cmd}' failed with error: {e.stderr.strip()}")
        raise

def parse_acl_file(filename):
    """
    Parse an ACL file and extract permissions entries.

    Args:
        filename (str): Path to the ACL file.

    Returns:
        list: List of dictionaries representing ACL entries.
    """
    try:
        with open(filename) as f:
            lines = f.readlines()
    except FileNotFoundError:
        logging.error(f"ACL file '{filename}' not found.")
        return []

    entries = []
    entry = {}

    for line in lines:
        if line.startswith("# file:"):
            entry = {}  # Start a new entry
            entry["filepath"] = line.split(": ", 1)[1].strip()
        elif line.startswith("# owner:"):
            entry["owner"] = line.split(": ", 1)[1].strip()
        elif line.startswith("# group:"):
            entry["group"] = line.split(": ", 1)[1].strip()
        elif line.startswith("user::") or line.startswith("group::") or line.startswith("other::"):
            if not entry:
                logging.warning("ACL entry missing file information.")
                continue
            parts = line.split("::", 1)
            if len(parts) == 2:
                key, value = parts
                entry[key] = value.strip()
            else:
                logging.warning(f"Invalid ACL entry: {line}")
        elif line.strip() == "":
            if entry:
                entries.append(entry)
                entry = {}

    return entries

def backup_permissions(acl_entries, backup_file):
    """
    Backup permissions to a JSON file.

    Args:
        acl_entries (list): List of dictionaries representing ACL entries.
        backup_file (str): Path to the backup JSON file.
    """
    with open(backup_file, 'w') as f:
        json.dump(acl_entries, f)

    print(f"Permissions backed up to {backup_file}.")

def restore_permissions(acl_entries):
    """
    Restore permissions based on ACL entries.

    Args:
        acl_entries (list): List of dictionaries representing ACL entries.
    """
    for entry in acl_entries:
        filepath = entry["filepath"]
        filepath = sanitize_path(filepath)  # Sanitize the file path

        if not os.path.exists(filepath):
            logging.warning(f"{filepath} does not exist.")
            continue

        # Check and fix owner
        try:
            process = run_command(["stat", "-c", "%U", filepath])
            if process and process.stdout.strip() != entry["owner"]:
                run_command(["chown", entry["owner"], filepath])
                logging.info(f"Owner fixed for {filepath}")
        except Exception as e:
            logging.error(f"Failed to change owner for {filepath}. Error: {e}")

        # Check and fix group
        try:
            process = run_command(["stat", "-c", "%G", filepath])
            if process and process.stdout.strip() != entry["group"]:
                run_command(["chgrp", entry["group"], filepath])
                logging.info(f"Group fixed for {filepath}")
        except Exception as e:
            logging.error(f"Failed to change group for {filepath}. Error: {e}")

        # Check and fix user permissions
        try:
            process = run_command(["stat", "-c", "%A", filepath])
            if process:
                current_permissions = process.stdout.strip()
                expected_permissions = entry["user_permissions"] + entry["group_permissions"] + entry["other_permissions"]
                if current_permissions != expected_permissions:
                    run_command(["chmod", expected_permissions, filepath])
                    logging.info(f"Permissions fixed for {filepath}")
        except Exception as e:
            logging.error(f"Failed to change permissions for {filepath}. Error: {e}")

    print("Permissions and ownership check and fix complete.")

def audit_permissions(acl_entries):
    """
    Audit permissions based on ACL entries and report discrepancies.

    Args:
        acl_entries (list): List of dictionaries representing ACL entries.
    """
    discrepancies = []

    for entry in acl_entries:
        filepath = entry["filepath"]
        filepath = sanitize_path(filepath)  # Sanitize the file path

        if not os.path.exists(filepath):
            discrepancies.append(f"{filepath} does not exist.")
            continue

        # Check owner
        try:
            process = run_command(["stat", "-c", "%U", filepath])
            process = run_command(["stat", "-c", "%U", filepath])
            if process and process.stdout.strip() != entry["owner"]:
                discrepancies.append(f"Owner of {filepath} is incorrect.")
        except Exception as e:
            logging.error(f"Error while checking owner for {filepath}. Error: {e}")

        # Check group
        try:
            process = run_command(["stat", "-c", "%G", filepath])
            if process and process.stdout.strip() != entry["group"]:
                discrepancies.append(f"Group of {filepath} is incorrect.")
        except Exception as e:
            logging.error(f"Error while checking group for {filepath}. Error: {e}")

        # Check user permissions
        try:
            process = run_command(["stat", "-c", "%A", filepath])
            if process:
                current_permissions = process.stdout.strip()
                expected_permissions = entry["user_permissions"] + entry["group_permissions"] + entry["other_permissions"]
                if current_permissions != expected_permissions:
                    discrepancies.append(f"Permissions for {filepath} are incorrect.")
        except Exception as e:
            logging.error(f"Error while checking permissions for {filepath}. Error: {e}")

    print("Audit complete.")
    if discrepancies:
        print("Discrepancies found:")
        for discrepancy in discrepancies:
            print(f"- {discrepancy}")
    else:
        print("No discrepancies found.")

def pacman_fix_permissions():
    """
    Run pacman-fix-permissions command.
    """
    run_command(["sudo", "pacman-fix-permissions"])

def sanitize_path(path):
    """
    Sanitize a file path by removing unnecessary characters.

    Args:
        path (str): The input file path.

    Returns:
        The sanitized file path.
    """
    return os.path.normpath(path)

if __name__ == "__main__":
    acl_file = input("Enter the path to the ACL file (e.g., standardpermissions.acl): ")

    if not os.path.exists(acl_file):
        print("The specified ACL file does not exist.")
    else:
        acl_entries = parse_acl_file(acl_file)

        while True:
            print("\nSTANDARDPERMISSIONS.PY")
            print("=" * 80)
            print("\nMain Menu")
            print("1) Backup Permissions")
            print("2) Restore Permissions")
            print("3) Audit Permissions")
            print("4) Run pacman-fix-permissions")
            print("5) Exit")
            choice = input("By your command: ")

            if choice.lower() in ["1", "backup permissions"]:
                backup_file = input("Enter the name of the backup file (permissions will be saved in JSON format): ")
                backup_permissions(acl_entries, backup_file)
            elif choice.lower() in ["2", "restore permissions"]:
                restore_permissions(acl_entries)
            elif choice.lower() in ["3", "audit permissions"]:
                audit_permissions(acl_entries)
            elif choice.lower() in ["4", "run pacman-fix-permissions"]:
                pacman_fix_permissions()
            elif choice.lower() in ["5", "exit"]:
                break
            else:
                print("Invalid choice. Please choose a valid option from the menu.")
