#!/usr/bin/env python3
"""
Author: 4ndr0666
Desc: Removes specified directories and files below.
"""

import os
import shutil

trash = [
    "~/.adobe",
    "~/.macromedia",
    "~/.FRD/log/app.log",
    "~/.FRD/links.txt",
    "~/.objectdb",
    "~/.gstreamer-0.10",
    "~/.pulse",
    "~/.esd_auth",
    "~/.config/enchant",
    "~/.spicec",
    "~/.dropbox-dist",
    "~/.parallel",
    "~/.dbus",
    "~/.distlib/",
    "~/.bazaar/",
    "~/.bzr.log",
    "~/.nv/",
    "~/.viminfo",
    "~/.npm/",
    "~/.java/",
    "~/.swt/",
    "~/.oracle_jre_usage/",
    "~/.jssc/",
    "~/.tox/",
    "~/.pylint.d/",
    "~/.qute_test/",
    "~/.QtWebEngineProcess/",
    "~/.qutebrowser/",
    "~/.asy/",
    "~/.cmake/",
    "~/.cache/thumbnails" "~/.cache/mozilla/",
    "~/.cache/mesa_shader_cache",
    "~/.cache/mesa_shader_cache_db",
    "~/.cache/go-build",
    "~/.cache/go",
    "~/.cache/qtshadercache-x86_64-little_endian-lp64",
    "~/.cache/yarn",
    "~/.local/share/Trash/info",
    "~/.local/share/Trash/files",
    "~/.cache/electron",
    "~/.cache/fontconfig"
    "~/.cache/mesa_shader_cache_db"
    "~/.cache/mozilla"
    "~/.cache/gstreamer-1.0/",
    "~/.cache/fontconfig/",
    "~/.cache/mesa_shader_cache/",
    "~/.cache/chromium/",
    "~/.cache/google-chrome/",
    "~/.cache/spotify/",
    "~/.cache/steam/",
    "~/.zoom/",
    "~/.Skype/",
    "~/.minecraft/logs/",
    "~/.local/share/Trash/" "~/.vim/.swp",
    "~/.vim/.backup",
    "~/.vim/.undo",
    "~/.emacs.d/auto-save-list/",
    "~/.cache/JetBrains/",
    "~/.vscode/extensions/",
    "~/.npm/_logs/",
    "~/.npm/_cacache/",
    "~/.composer/cache/",
    "~/.gem/cache/",
    "~/.cache/pip/",
    "~/.wget-hsts",
    "~/.docker/",
    "~/.local/share/baloo/",
    "~/.kde/share/apps/okular/docdata/",
    "~/.local/share/akonadi/",
    "~/.xsession-errors",
    "~/.nv/ComputeCache/",
]


def yesno(question, default="n"):
    """
    Asks the user for YES or NO, always case insensitive.
    Returns True for YES and False for NO.
    """
    prompt = f"{question} (y/[n]) "

    answer = input(prompt).strip().lower()

    if not answer:
        answer = default

    return answer == "y"


def remove_trash():
    """
    Removes the files and directories listed in 'shittyfiles'.
    """
    print("Found trash files:")
    found_files = [
        os.path.expanduser(file_path)
        for file_path in trash
        if os.path.exists(os.path.expanduser(file_path))
    ]

    if not found_files:
        print("No trash files found :)")
        return

    if yesno("Remove all?", default="n"):
        for file_path in found_files:
            if os.path.isfile(file_path):
                os.remove(file_path)
            else:
                shutil.rmtree(file_path, ignore_errors=True)
        print("All cleaned")
    else:
        print("No file removed")


if __name__ == "__main__":
    remove_trash()
