#!/bin/python
import sys
import subprocess

from pathlib import Path

cmd = ["paccache"]
for pkgdir in (Path.home() / '.cache' / "yay").glob("*"):
    if pkgdir.is_dir():
        cmd.extend(("-c", str(pkgdir)))

for pkgdir in (Path.home() / '.cache' / "paru" / "clone").glob("*"):
    if pkgdir.is_dir():
        cmd.extend(("-c", str(pkgdir)))

cmd.extend(sys.argv[1:])
subprocess.run(cmd)
