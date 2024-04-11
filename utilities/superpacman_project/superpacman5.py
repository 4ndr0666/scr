#!/usr/bin/env python3
import itertools
import os
import re
import subprocess
import signal
import sys
import threading
import time

def check_privileges():
    if os.geteuid() != 0:
        print("This script requires root privileges. Please rerun it with 'sudo'.")
        sys.exit(1)

def run_command(command):
    try:
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        while True:
            output = process.stdout.readline()
            if output == '' and process.poll() is not None:
                break
            if output:
                print(output.strip())
        stderr = process.stderr.read()
        if process.returncode != 0:
            print(stderr.strip())
            return "", stderr
        return "Command executed successfully", ""
    except subprocess.CalledProcessError as e:
        print(f"Command failed with error: {e.stderr}")
        return "", e.stderr

def handle_pacman_output(stderr):
    duplicated_entries = re.findall(r'error: duplicated database entry \'(.+?)\'', stderr)
    conflicting_files = re.findall(r'([^ ]+): /([^ ]+) exists in filesystem', stderr)

    if duplicated_entries:
        for entry in duplicated_entries:
            subprocess.run(["sudo", "pacman", "-Rdd", entry, "--noconfirm"], check=True)

    if conflicting_files:
        conflicts = " ".join(f"/{path}" for _, path in conflicting_files)
        subprocess.run(["sudo", "pacman", "-Syu", "--overwrite", conflicts, "--noconfirm"], check=True)

def remove_pacman_lock():
    lockfile = '/var/lib/pacman/db.lck'
    if os.path.exists(lockfile):
        os.remove(lockfile)

def spinner():
    for c in itertools.cycle(['|', '/', '-', '\\']):
        if not spinner_active: break
        sys.stdout.write(f'\r{c}')
        sys.stdout.flush()
        time.sleep(0.1)
    sys.stdout.write('\r     \r')

def start_spinner():
    global spinner_active
    spinner_active = True
    threading.Thread(target=spinner, daemon=True).start()

def stop_spinner():
    global spinner_active
    spinner_active = False
    time.sleep(0.2)

def graceful_exit(signum, frame):
    if signum == signal.SIGQUIT:
        stop_spinner()
        remove_pacman_lock()
        print("Exiting gracefully...")
        sys.exit(1)

spinner_active = False

def main():
    signal.signal(signal.SIGQUIT, graceful_exit)
    remove_pacman_lock()
    stdout, stderr = run_command(["sudo", "pacman", "-Syu", "--noconfirm"])
    if "duplicated database entry" in stderr or "exists in filesystem" in stderr:
        handle_pacman_output(stderr)

if __name__ == "__main__":
    check_privileges()
    print("Its a bird... its a plane... its Superpacman!")
    main()
    print("Was that Superpacman? -pacman")
