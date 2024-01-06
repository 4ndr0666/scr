import os
import shutil

shittyfiles = [
    '~/.adobe',
    '~/.macromedia',
    '~/.thumbnails',
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
    '~/.cache/mozilla/',
    '~/.cache/chromium/',
    '~/.cache/google-chrome/',
    '~/.cache/spotify/',
    '~/.cache/steam/',
    '~/.zoom/',
    '~/.Skype/',
    '~/.minecraft/logs/',
    '~/.cache/thumbnails/',  # Redundant with '~/.thumbnails', consider keeping only one
    '~/.local/share/Trash/',  # Trash directory, safe to empty if confirmed with the user
#    '/var/tmp/',  # System temporary files, can be cleaned but might affect currently running processes
    # Be cautious with system-wide directories like '/tmp/', which may contain files needed by other users or system services
    '~/.vim/.swp',
    '~/.vim/.backup',
    '~/.vim/.undo',
    '~/.emacs.d/auto-save-list/',
    '~/.cache/JetBrains/',
    '~/.vscode/extensions/',
    '~/.npm/_logs/',
    '~/.npm/_cacache/',
    '~/.composer/cache/',
    '~/.gem/cache/',
    '~/.cache/pip/',
    '~/.gnupg/',
    '~/.wget-hsts',
    '~/.docker/',
    '~/.local/share/baloo/',
    '~/.kde/share/apps/okular/docdata/',
    '~/.local/share/akonadi/',
    '~/.xsession-errors',
    '~/.cache/gstreamer-1.0/',
    '~/.cache/fontconfig/',
    '~/.cache/mesa/',
    '~/.nv/ComputeCache/',
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
    print("Found shitty files:")
    found = [os.path.expanduser(f) for f in shittyfiles if os.path.exists(os.path.expanduser(f))]

    if not found:
        print("No shitty files found :)")
        return

    if yesno("Remove all?", default="n"):
        for f in found:
            if os.path.isfile(f):
                os.remove(f)
            else:
                shutil.rmtree(f, ignore_errors=True)
        print("All cleaned")
    else:
        print("No file removed")
