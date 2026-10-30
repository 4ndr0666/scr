import json, sys, copy
import os
HERE = os.path.dirname(os.path.abspath(__file__))
w = json.load(open(os.path.join(HERE, 'world_clean.json')))
def add(n, **kw):
    d = {"repo": "extra", "version": "1.0-1", "files": [f"/usr/bin/{n}"], "deps": [], "required_by": []}; d.update(kw); w["pkgs"][n] = d
name = sys.argv[1]
if name == "asar":
    add("electron-app", deps=["asar"])
    add("asar", installed=False, files=[], conflict_paths=["/usr/lib/node_modules/asar/node_modules/glob/index.js","/usr/lib/node_modules/asar/node_modules/minimatch/lib.js"])
if name == "blocker":
    # python-thefuzz-style: an installed package pins a retired runtime and blocks the new dep
    add("newm", deps=["python-newdep", "python-thefuzz", "glibc"])
    add("python-thefuzz", deps=["python"], required_by=["newm"])
    add("python-newdep", installed=False, files=[], blocked_by_installed="python-thefuzz", breaks="python<3.14")
    add("python", files=["/usr/bin/python"]); w["groups"]["base"].append("python")
if name == "basesafe":
    add("python-newdep", installed=False, files=[], blocked_by_installed="bash", breaks="bash<5")
    add("needs-newdep", deps=["python-newdep"])
if name == "field":
    w["pkgs"]["filesystem"]["missing"] = ["/usr/share/pixmaps/archlinux-logo.png"]
    w["pkgs"]["filesystem"]["files"] = ["/etc/fstab"]
    w["pkgs"]["filesystem"]["hook_removes"] = True
    w["ignorepkg"] = ["filesystem"]
    ac = "/usr/lib/node_modules/%s/node_modules/%s"
    for n in ("electron-builder", "peerflix", "textlint"):
        add(n, repo="aur", aur_mode="conflict", missing=[f"/usr/lib/node_modules/{n}/lib/index.js"], files=[], conflict_paths=[ac % (n, "a/x.js"), ac % (n, "b/y.js")])
    add("kirigami2", repo="aur", aur_mode="pgp", aur_key="53E6B47B45CEA3E0D5B7457758D0EE648A48B3BB", missing=["/usr/lib/libkirigami2.so"], files=[])
    add("python-pywal", repo="aur", aur_mode="pgp", aur_key="155DC67DC25496572CDD608FF635E931C2834999", missing=["/usr/bin/wal"], files=[])
    add("pacaur", repo="aur", aur_mode="build", missing=["/usr/bin/pacaur"], files=[])
    add("sortphotos", repo="aur", aur_mode="build", missing=["/usr/bin/sortphotos"], files=[])
json.dump(w, open(os.path.join(os.environ.get('SIM_WORLD_DIR', HERE), f'world_{name}.json'), 'w'), indent=1)
