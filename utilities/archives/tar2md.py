#!/usr/bin/env python3
import tarfile, hashlib

with tarfile.open("TAR_FILE.tar.gz", "r:gz") as t, open("UNPACKED_FILE.md", "w") as out:
    for m in t.getmembers():
        if m.isfile():
            raw = t.extractfile(m).read()
            sha = hashlib.sha256(raw).hexdigest()
            out.write(f"\n\n=== FILE: {m.name} | {m.size} B | sha256: {sha} ===\n\n")
            out.write(raw.decode("utf-8", errors="replace"))
