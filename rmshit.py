#! /usr/bin/env python3

import os
import sys
import shutil


shittyfiles = [
    '~/.adobe',
    '~/.macromedia',
#    '~/.recently-used',
#    '~/.local/share/recently-used.xbel',
#    '~/Desktop',
    '~/.thumbnails',
    '~/.gconfd',
    '~/.gconf',
    '~/.local/share/gegl-0.2',
    '~/.FRD/log/app.log',
    '~/.FRD/links.txt',
    '~/.objectdb',
    '~/.gstreamer-0.10',
    '~/.pulse',
    '~/.esd_auth',
    '~/.config/enchant',
    '~/.spicec',
    '~/.dropbox-dist',
    '~/.parallel',
    '~/.dbus',
    '~/ca2',
    '~/ca2~',
    '~/.distlib/',
    '~/.bazaar/',
    '~/.bzr.log',
    '~/.nv/',
    '~/.viminfo',
    '~/.npm/',
    '~/.java/',
    '~/.swt/',
    '~/.oracle_jre_usage/',
    '~/.jssc/',
    '~/.tox/',
    '~/.pylint.d/',
    '~/.qute_test/',
    '~/.QtWebEngineProcess/',
    '~/.qutebrowser/',
    '~/.asy/',
    '~/.cmake/',
    '~/.gnome/',
    '~/unison.log',
    '~/.texlive/',
    '~/.w3m/',
    '~/.subversion/',
    '~/nvvp_workspace/',
    '~/.ansible/',
    '~/.fltk/',
    '~/.vnc/',
    '~/.mozilla/',
]


def yesno(question, default="n"):
    """ Asks the user for YES or NO, always case insensitive.
        Returns True for YES and False for NO.
    """
    prompt = "%s (y/[n]) " % question

    ans = input(prompt).strip().lower()

    if not ans:
        ans = default

    if ans == "y":
        return True
    return False


def rmshit():
    found = [os.path.expanduser(f) for f in shittyfiles if os.path.exists(os.path.expanduser(f))]
    if not found:
        print("No unnecessary files found :)")
        return 0 # Success code

    for item in found:
        remove_item(item)

    print("Cleanup complete")
    return 0 # Success code

if __name__ == '__main__':
    sys.exit(rmshit())
