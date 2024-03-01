#!/usr/bin/env python3
import itertools
import os
import re
import subprocess
import signal
import sys
import threading
import time

def run_command(command, shell=False, provide_feedback=False):
    global spinner_active
    if provide_feedback:
        start_spinner()
    try:
        result = subprocess.run(command, shell=shell, check=True, capture_output=True, text=True)
        if provide_feedback:
            stop_spinner()
        return result.stdout, result.stderr
    except subprocess.CalledProcessError as e:
        if provide_feedback:
            stop_spinner()
        handle_pacman_output(e.stderr)
        return "", e.stderr

def handle_pacman_output(stderr):
    duplicated_entries = re.findall(r'error: duplicated database entry \'(.+?)\'', stderr)
    conflicting_files = re.findall(r'([^ ]+): /([^ ]+) exists in filesystem', stderr)
    
    if duplicated_entries:
        print("Cleaning duplicated database entries...")
        for entry in duplicated_entries:
            print(f"Attempting to remove duplicated entry: {entry}")
            run_command(["sudo", "pacman", "-Rdd", entry, "--noconfirm"], provide_feedback=True)
    
    if conflicting_files:
        print("Resolving package conflicts...")
        conflicts = " ".join(f"/{path}" for _, path in conflicting_files)
        run_command(["sudo", "pacman", "-Syu", "--overwrite", conflicts, "--noconfirm"], provide_feedback=True)

def remove_pacman_lock():
    lockfile = '/var/lib/pacman/db.lck'
    if os.path.exists(lockfile):
        print("Removing Pacman lock file...")
        os.remove(lockfile)

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
    print("Updating all packages...")
    stdout, stderr = run_command(["sudo", "pacman", "-Syu", "--noconfirm"], provide_feedback=True)
    if "duplicated database entry" in stderr or "exists in filesystem" in stderr:
        print("Attempting to resolve issues...")
        handle_pacman_output(stderr)
    else:
        print(stdout)

if __name__ == "__main__":
    main()
