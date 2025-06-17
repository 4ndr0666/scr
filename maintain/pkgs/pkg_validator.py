#!/usr/bin/env python3

import os
import re
import glob
import subprocess


def read_pacman_conf():
    """Reads and returns pacman configuration."""
    with open("/etc/pacman.conf") as f:
        return f.read()


def get_pkgcache(pacman_conf):
    """Extracts PKGCACHE directory from pacman configuration."""
    match = re.search(r"^CacheDir\s*=\s*(.+)", pacman_conf, re.MULTILINE)
    return match.group(1) if match else "/var/cache/pacman/pkg"


def get_installed_packages(log_files):
    """Extracts installed package names from log files."""
    packages = []
    for log_file in log_files:
        if os.path.isfile(log_file):
            with open(log_file) as f:
                installed_packages = re.findall(
                    r"(?<=installed )[a-zA-Z0-9-]+(?=\s\()", f.read()
                )
                packages += installed_packages
    return packages


def find_package_path(package, pkgdirs):
    """Finds the path of the given package in pkgdirs."""
    package_name, package_version = package.split("-")[:2]
    for pkgdir in pkgdirs:
        package_files = glob.glob(
            f"{pkgdir}/{package_name}-{package_version}-*.pkg.tar.*"
        )
        if package_files:
            return package_files[0]
    return ""


def main():
    pacman_conf = read_pacman_conf()
    pkgcache = get_pkgcache(pacman_conf)
    pkgdirs = [pkgcache]

    log_files = ["/var/log/pacman.log", "/var/log/yay.log", "/var/log/paru.log"]
    packages = get_installed_packages(log_files)

    for package in packages:
        package_path = find_package_path(package, pkgdirs)
        if not package_path:
            print(f"{package} not found, downloading...")
            subprocess.run(["sudo", "pacman", "-S", "--needed", "--noconfirm", package])
        else:
            print(f"{package} found at {package_path}")


if __name__ == "__main__":
    main()
