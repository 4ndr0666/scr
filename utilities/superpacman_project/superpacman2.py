#!/usr/bin/env python3
import itertools
import os
import re
import subprocess
import signal
import sys
import threading
import time
import logging

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# AUTO_ESCALATE: Check if running as root, else rerun with sudo
if os.geteuid() != 0:
    try:
        print("Attempting to escalate privileges...")
        subprocess.check_call(['sudo', sys.executable] + sys.argv)
        sys.exit()
    except subprocess.CalledProcessError as e:
        print(f"Error escalating privileges: {e}")
        sys.exit(e.returncode)

# Define helper functions
def run_command(command, provide_feedback=False):
    global spinner_active
    if provide_feedback:
        start_spinner()
    try:
        result = subprocess.run(command, check=True, capture_output=True, text=True)
        if provide_feedback:
            stop_spinner()
        logging.info(result.stdout)
        return result.stdout, result.stderr
    except subprocess.CalledProcessError as e:
        if provide_feedback:
            stop_spinner()
        logging.error("Command failed: %s", e.stderr)
        handle_pacman_output(e.stderr)
        return "", e.stderr

def handle_pacman_output(stderr):
    duplicated_entries = re.findall(r'error: duplicated database entry \'(.+?)\'', stderr)
    conflicting_files = re.findall(r'([^ ]+): /([^ ]+) exists in filesystem', stderr)

    if duplicated_entries:
        logging.info("Cleaning duplicated database entries...")
        for entry in duplicated_entries:
            logging.info("Removing duplicated entry: %s", entry)
            subprocess.run(["sudo", "pacman", "-Rdd", entry, "--noconfirm"], check=True)
    
    if conflicting_files:
        logging.info("Resolving package conflicts...")
        conflicts = " ".join(f"/{path}" for _, path in conflicting_files)
        subprocess.run(["sudo", "pacman", "-Syu", "--overwrite", conflicts, "--noconfirm"], check=True)

def remove_pacman_lock():
    lockfile = '/var/lib/pacman/db.lck'
    if os.path.exists(lockfile):
        logging.info("Removing Pacman lock file...")
        os.remove(lockfile)

# Dynamic Visual Feedback (Spinner)
spinner_active = False

def spinner():
    for c in itertools.cycle(['|', '/', '-', '\\']):
        if not spinner_active: break
        sys.stdout.write(f'\r{c}')
        sys.stdout.flush()
        time.sleep(0.1)
    sys.stdout.write('\r')

def start_spinner():
    global spinner_active
    spinner_active = True
    threading.Thread(target=spinner, daemon=True).start()

def stop_spinner():
    global spinner_active
    spinner_active = False
    time.sleep(0.2)

def main():
    signal.signal(signal.SIGINT, lambda sig, frame: sys.exit(0))
    remove_pacman_lock()
    logging.info("Updating all packages...")
    stdout, stderr = run_command(["sudo", "pacman", "-Syu", "--noconfirm"], provide_feedback=True)
    if "duplicated database entry" in stderr or "exists in filesystem" in stderr:
        logging.info("Attempting to resolve issues...")
        handle_pacman_output(stderr)
    else:
        logging.info(stdout)

if __name__ == "__main__":
    main()
