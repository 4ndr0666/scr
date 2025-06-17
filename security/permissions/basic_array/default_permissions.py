#!/usr/bin/env python3
import os
import subprocess
import logging

logging.basicConfig(
    filename="permissions_fix.log", level=logging.INFO, format="%(asctime)s %(message)s"
)


def run_command(command):
    try:
        return subprocess.run(command, capture_output=True, text=True, check=True)
    except subprocess.CalledProcessError as e:
        logging.error(f"Command '{e.cmd}' failed with error: {e.stderr.strip()}")
        raise


def main():
    if os.geteuid() != 0:
        logging.error("This script must be run as root.")
        print("This script must be run as root.")
        return

    directories = [
        ("/bin", "755", "root:root"),
        ("/boot", "755", "root:root"),
        ("/dev", "755", "root:root"),
        ("/etc", "755", "root:root"),
        ("/home", "755", "root:root"),
        ("/lib", "755", "root:root"),
        ("/lib64", "755", "root:root"),
        ("/opt", "755", "root:root"),
        ("/proc", "755", "root:root"),
        ("/root", "700", "root:root"),
        ("/run", "755", "root:root"),
        ("/sbin", "755", "root:root"),
        ("/srv", "755", "root:root"),
        ("/sys", "755", "root:root"),
        ("/tmp", "1777", "root:root"),
        ("/usr", "755", "root:root"),
        ("/usr/local/bin", "755", "root:root"),
        ("/var", "755", "root:root"),
        ("/usr/lib/python3.10/site-packages", "755", "root:root"),
    ]

    for directory, expected_permissions, expected_ownership in directories:
        if not os.path.exists(directory):
            logging.warning(f"Directory {directory} does not exist.")
            continue

        process = run_command(["stat", "-c", "%a", directory])
        if process and process.stdout.strip() != expected_permissions:
            run_command(["chmod", expected_permissions, directory])
            logging.info(f"Permissions fixed for directory: {directory}")

        process = run_command(["stat", "-c", "%U:%G", directory])
        if process and process.stdout.strip() != expected_ownership:
            run_command(["chown", expected_ownership, directory])
            logging.info(f"Ownership fixed for directory: {directory}")

    print("Directory permissions and ownership check and fix complete.")


if __name__ == "__main__":
    main()
