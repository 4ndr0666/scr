import os
import sys
import re
import subprocess

pkgname_regex = re.compile(
    r"^(?P<pkgname>[a-z0-9@._+-]+)-(?P<pkgver>[a-z0-9._:-]+)-(?P<arch>any|x86_64|i686)\.pkg\.tar(\.xz|\.zst|\.gz)?(\.sig)?$",
    re.IGNORECASE
)

def usage():
    print("Simple utility to clean directories from old Arch's package files, keeping only those currently installed.")
    print(f"usage: {sys.argv[0]} PATH")
    sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        usage()

    path = sys.argv[1]
    if not os.path.isdir(path):
        usage()

    os.chdir(path)
    files = {}

    # remove files that don't match pkgname_regex from further processing
    for f in os.listdir():
        if not os.path.isfile(f):
            continue
        match = pkgname_regex.match(f)
        if match:
            # strip extension for future comparison with expac's output
            files[f] = "{pkgname}-{pkgver}-{arch}".format(**match.groupdict())

    # get list of installed packages
    try:
        installed = subprocess.check_output(["expac", "-Qs", "%n-%v-%a"], universal_newlines=True).splitlines()
    except subprocess.CalledProcessError as e:
        print(f"Error obtaining installed packages list: {e}", file=sys.stderr)
        sys.exit(1)

    for f in sorted(files):
        # compare with the key instead of the whole filename
        # (drops file extensions like .pkg.tar.{xz,gz,zst}{,.sig})
        ff = files[f]

        if ff in installed:
            print(f"Kept:    {f}")
        else:
            print(f"Deleted: {f}")
            try:
                os.remove(f)
            except OSError as e:
                print(f"Error deleting file {f: {e}", file=sys.stderr)
