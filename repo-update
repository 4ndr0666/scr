#!/usr/bin/env python

import os
import re
import subprocess
from pyalpm import vercmp

DB_PATH = "jlk.db.tar.xz"
PKGNAME_REGEX = re.compile("^(?P<pkgname>[a-z0-9@._+-]+)-(?P<pkgver>[a-z0-9._:+]+)-(?P<pkgrel>[a-z0-9._:+]+)-(?P<arch>any|x86_64|i686)\.pkg\.tar(\.xz|\.zst)?$", re.IGNORECASE)


def main():
    path = os.path.expanduser(path)
    assert os.path.isdir(path)
    os.chdir(path)

    current_packages = {}
    old_pkgnames = set()
    old_files = set()

    for f in os.listdir():
        if not os.path.isfile(f):
            continue
        match = re.match(PKGNAME_REGEX, f)
        if not match:
            continue

        pkgname = match.groupdict()["pkgname"]
        pkgver = match.groupdict()["pkgver"]
        pkgrel = match.groupdict()["pkgrel"]
        fname = match.groupdict()["fname"] = f

        data = {"pkgname": pkgname, "pkgver": pkgver, "pkgrel": pkgrel, "fname": fname}
        current_packages.setdefault(pkgname, data)

        cur_pkgver = current_packages[pkgname]["pkgver"]
        cur_pkgrel = current_packages[pkgname]["pkgrel"]
        comp = vercmp(pkgver + "-" + pkgrel, cur_pkgver + "-" + cur_pkgrel)
        if comp < 0:
            old_pkgnames.add(pkgname)
            old_files.add(f)
        elif comp > 0:
            old_pkgnames.add(current_packages[pkgname]["pkgname"])
            old_files.add(current_packages[pkgname]["fname"])
            current_packages[pkgname] = data

    to_update = set()
    for pkgname, data in current_packages.items():
        if pkgname in old_pkgnames:
            to_update.add(data["fname"])
    if to_update:
        subprocess.run(["repo-add", "-n", "-s", DB_PATH, *sorted(to_update)], check=True)
    else:
        print("No packages to update.")

    for f in sorted(old_files):
        os.remove(f)
        if os.path.isfile(f + ".sig"):
            os.remove(f + ".sig")
        print(f"Deleted: {f}")


if __name__ == "__main__":
    main()
