#!/usr/bin/env python3

import os
import sys
import re
import subprocess

def usage():
    print("Usage: {} PATH".format(sys.argv[0]))
    print("Cleans directories from old Arch's package files, keeping only those currently installed.")
    sys.exit(1)

def main():
    if len(sys.argv) != 2:
        usage()

    path = sys.argv[1]
    if not os.path.isdir(path):
        print("Error: '{}' is not a valid directory.".format(path))
        usage()

    os.chdir(path)
    pkgname_regex = re.compile(r"^(?P<pkgname>[a-z0-9@._+-]+)-(?P<pkgver>[a-z0-9._:-]+)-(?P<arch>any|x86_64|i686)\.pkg\.tar(\.xz)?(\.sig)?$", re.IGNORECASE)
    files = {f: "{pkgname}-{pkgver}-{arch}".format(**re.match(pkgname_regex, f).groupdict()) for f in os.listdir() if re.match(pkgname_regex, f)}

    # Retrieve list of installed packages
    try:
        installed = subprocess.check_output("expac -Qs '%n-%v-%a'", shell=True, universal_newlines=True).splitlines()
    except subprocess.CalledProcessError as e:
        print("Error executing expac: {}".format(e))
        sys.exit(1)

    for f, ff in sorted(files.items()):
        if ff in installed:
            print("Kept:    {}".format(f))
        else:
            print("Deleted: {}".format(f))
            os.remove(f)

if __name__ == "__main__":
    main()
