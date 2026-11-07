#!/usr/bin/env bash
# GUP Pi4 image builder v3. Python3 orchestration is embedded: one runtime file.
# Default: guided TUI. --plan is read-only. --build creates a NEW image file only.
# --flash is a separate, destructive operation with target checks and a TTY prompt.
# No target chroot, downloaded-code execution, default passwords or auto-upgrades.
if [[ ${BASH_SOURCE[0]} != "$0" ]]; then
    printf '%s\n' 'Run this file; do not source it.' >&2
    return 2
fi
export GUP_PROVISION_SCRIPT
GUP_PROVISION_SCRIPT=$(readlink -f -- "${BASH_SOURCE[0]}") || exit 1
exec python3 -B - "$@" <<'PY'
import argparse
import fcntl
import getpass
import hashlib
import json
import os
import pwd
from pathlib import Path, PurePosixPath
import re
import signal
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
import time

VERSION = '3.1.1'
SCRIPT_PATH = Path(os.environ.get('GUP_PROVISION_SCRIPT', 'provision-gup-pi4.sh')).absolute()
ROOTFS_NAME = 'ArchLinuxARM-rpi-aarch64-latest.tar.gz'
# Direct project mirror hostnames have usable HTTPS endpoints; the os.* alias
# is deliberately excluded because its certificate does not cover that name.
ROOTFS_URLS = (
    'https://ca.us.mirror.archlinuxarm.org/os/' + ROOTFS_NAME,
    'https://de3.mirror.archlinuxarm.org/os/' + ROOTFS_NAME,
)
R6 = ('8dbe1e8219c45a4bd00c26425e4867da901e88eb', 'ec8e797f4387db48c3c6669ed1d83f2d08b41a0b')
R7 = ('5f97fdf336142241ebe5641db1c74ce2f907105b', 'ef92e2c255b74a0ddde2cb293b4c0a1f7dc3bcdb')
REPO = '/home/alarm/git/4ndr0666_hyprland'
ENV = dict(os.environ, LC_ALL='C', GIT_CONFIG_NOSYSTEM='1',
           GIT_CONFIG_GLOBAL='/dev/null', GIT_TERMINAL_PROMPT='0',
           GIT_OPTIONAL_LOCKS='0', GIT_NO_LAZY_FETCH='1', PYTHONDONTWRITEBYTECODE='1')

class Refusal(Exception):
    pass

def require(condition, message):
    if not condition:
        raise Refusal(message)

def digest(path):
    h = hashlib.sha256()
    with open(path, 'rb') as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()

def run(argv, *, data=None, timeout=120, records=None):
    try:
        result = subprocess.run([str(x) for x in argv], input=data,
                                capture_output=True, timeout=timeout, env=ENV)
        status, stdout, stderr = result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired as exc:
        status, stdout, stderr = 124, exc.stdout or b'', exc.stderr or b''
    except OSError as exc:
        status, stdout, stderr = 127, b'', str(exc).encode()
    if records is not None:
        records.append({'argv': [str(x) for x in argv], 'exit_status': status,
                        'stdin': data.decode() if data is not None else None,
                        'stdout': stdout.decode(errors='replace'), 'stdout_sha256': hashlib.sha256(stdout).hexdigest(),
                        'stderr': stderr.decode(errors='replace'), 'stderr_sha256': hashlib.sha256(stderr).hexdigest()})
    require(status == 0,
            'Command failed (exit ' + str(status) + '): ' + ' '.join(str(x) for x in argv) + '\n' + stderr.decode(errors='replace'))
    return stdout.decode().strip()

def executable_tools(names):
    missing = [name for name in names if not shutil.which(name)]
    require(not missing, 'Missing host tools (not installed automatically): ' + ', '.join(missing))

def private_text(path):
    path = Path(path)
    require(path.is_file() and not path.is_symlink(), 'Secret input must be a regular, non-symlink file.')
    require(stat.S_IMODE(path.stat().st_mode) & 0o077 == 0, 'Secret input needs mode0600 or stricter: ' + str(path))
    return path.read_text().rstrip('\n')

def valid_password_hash(value):
    sha512 = r'\$6\$(?:rounds=([0-9]{4,9})\$)?[./0-9A-Za-z]{1,16}\$[./0-9A-Za-z]{86}'
    match = re.fullmatch(sha512, value)
    if match:
        return match[1] is None or 1000 <= int(match[1]) <= 999999999
    return bool(re.fullmatch(r'\$y\$[./0-9A-Za-z]+\$[./0-9A-Za-z]{1,86}\$[./0-9A-Za-z]{43}', value))

def wifi_config(ssid, password):
    raw = ssid.encode()
    require(1 <= len(raw) <= 32 and not any(ord(c) < 32 or ord(c) == 127 for c in ssid), 'SSID must be1–32 UTF-8 bytes without control characters.')
    if re.fullmatch('[0-9a-fA-F]{64}', password):
        psk = password.lower()
    else:
        secret = password.encode()
        require(8 <= len(secret) <= 63 and not any(ord(c) < 32 or ord(c) == 127 for c in password), 'Wi-Fi passphrase must be8–63 bytes, or a64-digit hexadecimal PSK.')
        psk = hashlib.pbkdf2_hmac('sha1', secret, raw, 4096, 32).hex()
    return 'ctrl_interface=DIR=/run/wpa_supplicant GROUP=wheel\nupdate_config=0\nnetwork={\n    ssid=' + raw.hex() + '\n    psk=' + psk + '\n}\n'

def archive_inventory(path):
    """Reject traversal, duplicate entries, devices and hard links outside archive."""
    entries = {}
    total = 0
    arch_ok = False
    with tarfile.open(path, 'r:*') as archive:
        for member in archive:
            name = member.name
            while name.startswith('./'):
                name = name[2:]
            if name in {'', '.'}:
                continue
            normalized = PurePosixPath(name)
            require(not normalized.is_absolute() and '..' not in normalized.parts,
                    'Unsafe archive path: ' + name)
            name = str(normalized)
            require(name not in entries, 'Duplicate archive path: ' + name)
            require(member.isfile() or member.isdir() or member.issym() or member.islnk(),
                    'Unsupported special archive entry: ' + name)
            if member.islnk():
                target = PurePosixPath(member.linkname)
                require(not target.is_absolute() and '..' not in target.parts, 'Unsafe hard link: ' + name)
            entries[name] = {'type': 'symlink' if member.issym() else 'hardlink' if member.islnk() else 'file' if member.isfile() else 'dir',
                             'link': member.linkname, 'size': member.size}
            if member.isfile():
                total += member.size
                if name == 'usr/bin/bash':
                    header = archive.extractfile(member).read(20)
                    arch_ok = header[:4] == b'\x7fELF' and header[4:6] == b'\x02\x01' and header[18:20] == b'\xb7\x00'
    # bsdtar's secure default rejects traversal through symlinks; reject it here too.
    for name in entries:
        for parent in PurePosixPath(name).parents:
            if str(parent) in entries:
                require(entries[str(parent)]['type'] == 'dir', 'Archive writes through a non-directory: ' + name)
    for name in ['etc/passwd', 'etc/shadow', 'etc/group', 'etc/os-release', 'usr/bin/bash', 'usr/bin/pacman']:
        require(name in entries, 'Not a recognized Arch ARM rootfs: missing ' + name)
    require(any(name.startswith('boot/') for name in entries), 'Rootfs has no boot payload.')
    require(arch_ok, 'Rootfs bash is not a little-endian AArch64 ELF binary.')
    for name, entry in entries.items():
        if entry['type'] == 'hardlink':
            target = str(PurePosixPath(entry['link']))
            require(target in entries and entries[target]['type'] == 'file', 'Hard link needs a regular in-archive target: ' + name)
    return {'entries': len(entries), 'regular_file_bytes': total,
            'boot_txt': 'boot/boot.txt' in entries, 'cmdline': 'boot/cmdline.txt' in entries,
            'sudo_present': 'usr/bin/sudo' in entries}

def parse(argv=None):
    p = argparse.ArgumentParser(
        prog=SCRIPT_PATH.name,
        usage='%(prog)s [--plan | --build | --flash IMAGE] [options]',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description='''Arch Pi — customized Arch Linux ARM images and SD-card writing.

COMMON COMMANDS
  Open the menu (normal workflow):
    sudo bash ./{script_name}

  Open the menu as your normal user; ask sudo only when needed:
    bash ./{script_name}

  Show this guide:
    bash ./{script_name} -h

WHAT THE MENU DOES
  Create image -> locate/download rootfs -> prepare
  SSH access/password hashes -> validate -> build -> optionally pick/write card.
  Existing inputs/settings are reused. Choose Settings for Wi-Fi, storage,
  image size or optional GUP source profile. Downloads enforce HTTPS. Card writes still require
  typing the exact erase confirmation; mounted system/data disks are excluded.
  fzf provides search/navigation when installed; a numbered menu works without it.

PROFILES AND SAVED WI-FI
  Plain Arch Linux ARM is the default; it needs no Git bundle.
  Settings offers optional GUP R6/R7 profiles. Previously saved profile
  selections persist; choose plain Arch in Settings to switch.
  Settings -> Wi-Fi saves credentials privately for subsequent burns.
  A blank password keeps the saved password for the same SSID.
  Supported inputs remain compatible Raspberry Pi AArch64 rootfs/boot
  layouts; support for every Pi model or 32-bit images is not established.

ADVANCED / SCRIPTED USE (optional)
  Check conventional input files without changes:
    bash ./{script_name} --plan
  Build from those files without the menu:
    sudo bash ./{script_name} --build
  The flags below override inputs for scripted workflows. They are not required
  for the guided menu.'''.replace('{script_name}', SCRIPT_PATH.name))
    mode = p.add_mutually_exclusive_group()
    mode.add_argument('-i', '--interactive', action='store_true', help='guided menu (default with no operation); fzf when available, numbered menu otherwise')
    mode.add_argument('--plan', action='store_true', help='validate inputs and print proposal; no filesystem writes')
    mode.add_argument('--build', action='store_true', help='create a new sparse image file; requires root/loop support')
    mode.add_argument('--flash', metavar='IMAGE', help='separately write an existing image to a checked physical disk')
    p.add_argument('--device', help='whole-disk target for --flash only; erased after TTY confirmation')
    p.add_argument('--image-sha256', help='required external expected hash for --flash')
    p.add_argument('--output', help='new image filename in an existing directory; never overwritten')
    p.add_argument('--size-gib', type=int, default=16, help='image size, default 16 GiB; root is not automatically expanded')
    p.add_argument('--rootfs', help='local official Pi aarch64 rootfs tarball')
    p.add_argument('--rootfs-sha256', help='expected 64-digit hash obtained through a trusted channel')
    p.add_argument('--bundle', help='self-contained Git bundle containing the requested full source history')
    p.add_argument('--baseline', choices=['arch', 'r6', 'r7'], default='arch', help='plain Arch ARM by default; optional GUP R6/R7 source profiles')
    p.add_argument('--ssh-key', help='existing OpenSSH public key; password SSH is disabled')
    p.add_argument('--password-hash-file', help='private file holding the alarm password hash; used for local login/sudo')
    p.add_argument('--root-password-hash-file', help='optional separate root hash for local recovery/su; required if rootfs lacks sudo; root SSH stays disabled')
    p.add_argument('--wifi-ssid', default='', help='optional SSID; Wi-Fi password comes from a file, never argv')
    p.add_argument('--wifi-password-file', help='private file containing the Wi-Fi password or raw PSK')
    p.add_argument('--autologin', action='store_true', help='explicitly opt into local tty1 alarm autologin')
    p.add_argument('--version', action='version', version='provision-gup-pi4 ' + VERSION)
    a = p.parse_args(argv)
    if not (a.plan or a.build or a.flash):
        a.interactive = True
        return a
    if a.flash:
        require(a.device and a.image_sha256, '--flash requires --device and --image-sha256.')
    else:
        require(not a.device and not a.image_sha256, '--device/--image-sha256 are only for --flash.')
        discover_inputs(a)
    return a

def discover_inputs(a):
    """Conventional local files only; no downloads, key generation or secret writes."""
    defaults = {'rootfs': 'ArchLinuxARM-rpi-aarch64-latest.tar.gz',
                'bundle': 'gup-source-' + a.baseline + '.bundle',
                'ssh_key': 'alarm.pub', 'password_hash_file': 'alarm.password.hash',
                'root_password_hash_file': 'root.password.hash'}
    for name, filename in defaults.items():
        if getattr(a, name) is None and Path(filename).is_file():
            setattr(a, name, filename)
    if a.output is None:
        a.output = './arch-pi-' + a.baseline + '.img'
    if a.rootfs_sha256 is None and a.rootfs and Path('rootfs.sha256').is_file():
        matches = []
        for line in Path('rootfs.sha256').read_text().splitlines():
            if not line.strip() or line.lstrip().startswith('#'):
                continue
            match = re.fullmatch(r'([a-fA-F0-9]{64})(?:[ \t]+\*?(.+))?', line.strip())
            require(match is not None, 'rootfs.sha256 has an invalid entry; use a trusted64-digit hash or sha256sum format.')
            if match[2] is None or Path(match[2]).name == Path(a.rootfs).name:
                matches.append(match[1])
        require(len(matches) == 1, 'rootfs.sha256 must contain exactly one matching rootfs checksum.')
        a.rootfs_sha256 = matches[0]
    missing = [filename + ' (or ' + flag + ')' for name, filename, flag in [
        ('rootfs', defaults['rootfs'], '--rootfs FILE'),
        ('rootfs_sha256', 'rootfs.sha256', '--rootfs-sha256 HASH'),
        ('bundle', defaults['bundle'], '--bundle FILE'),
        ('ssh_key', defaults['ssh_key'], '--ssh-key FILE'),
        ('password_hash_file', defaults['password_hash_file'], '--password-hash-file FILE')]
        if not getattr(a, name) and (name != 'bundle' or a.baseline != 'arch')]
    require(not missing, 'Missing setup files:\n  - ' + '\n  - '.join(missing) +
            '\nRun bash ./provision-gup-pi4.sh --help for the common commands and one-time setup.')

def checked_rootfs(a):
    """Reuse a scan within one workflow; invalidate it if the archive changes."""
    require(re.fullmatch('[0-9a-fA-F]{64}', a.rootfs_sha256 or ''), 'Invalid rootfs SHA256.')
    path = Path(a.rootfs).resolve(strict=True)
    info = path.stat()
    key = (str(path), a.rootfs_sha256.lower(), info.st_dev, info.st_ino,
           info.st_size, info.st_mtime_ns, info.st_ctime_ns)
    cached = getattr(a, '_rootfs_validation', None)
    if cached and cached[0] == key:
        return path, cached[1]
    require(digest(path) == a.rootfs_sha256.lower(), 'Rootfs hash mismatch; no image created.')
    inventory = archive_inventory(path)
    a._rootfs_validation = key, inventory
    return path, inventory

def plan(a):
    require(8 <= a.size_gib <= 512, '--size-gib must be8–512.')
    archive, inventory = checked_rootfs(a)
    bundle = Path(a.bundle).resolve(strict=True) if a.baseline != 'arch' else None
    output = Path(a.output).absolute()
    require(not any(ord(c) < 32 or ord(c) == 127 for c in str(output)), 'Control characters are not allowed in the image path.')
    require(not output.exists() and not output.is_symlink(), 'Refusing existing output: ' + str(output))
    require(output.parent.is_dir(), 'Output parent must already exist.')
    require(inventory['regular_file_bytes'] * 1.3 + 2 * 1024**3 < a.size_gib * 1024**3,
            'Requested image too small for rootfs and working headroom.')
    require(inventory['boot_txt'] or inventory['cmdline'], 'Unrecognized boot layout: no boot.txt or cmdline.txt.')
    key = Path(a.ssh_key).read_text().strip()
    require('\n' not in key and '\r' not in key and re.match(r'^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp\d+|sk-ssh-ed25519@openssh.com|sk-ecdsa-sha2-nistp256@openssh.com) [A-Za-z0-9+/=]+(?: .*)?$', key), 'Expected one OpenSSH public key, not a private key or authorized_keys options.')
    executable_tools(['git', 'ssh-keygen'])
    run(['ssh-keygen', '-lf', a.ssh_key])
    pw = private_text(a.password_hash_file)
    require(valid_password_hash(pw), 'Expected a complete SHA512-crypt or yescrypt password hash, not plaintext.')
    if a.root_password_hash_file:
        root_pw = private_text(a.root_password_hash_file)
        require(valid_password_hash(root_pw), 'Invalid/incomplete root password hash.')
        require(root_pw != pw, 'Use a distinct local root recovery password.')
    require(inventory['sudo_present'] or a.root_password_hash_file,
            'This rootfs lacks sudo. Supply a distinct --root-password-hash-file for local root/su recovery.')
    require(bool(a.wifi_ssid) == bool(a.wifi_password_file), 'Provide both --wifi-ssid and --wifi-password-file, or neither.')
    if a.wifi_password_file:
        wifi_config(a.wifi_ssid, private_text(a.wifi_password_file))
    commit = tree = None
    if bundle is not None:
        commit, tree = R6 if a.baseline == 'r6' else R7
        # A full, cloneable bundle must have no prerequisite object lines.
        with bundle.open('rb') as f:
            require(f.readline().rstrip() == b'# v2 git bundle', 'Expected a v2 full Git bundle.')
            refs = []
            while True:
                line = f.readline(8192)
                require(line, 'Truncated bundle header.')
                if line == b'\n':
                    break
                require(not line.startswith(b'-'), 'Incremental bundle needs external objects; supply a self-contained full bundle.')
                refs.append(line.decode().strip())
        require(any(line.startswith(commit + ' ') for line in refs), 'Requested exact commit must be advertised by the bundle.')
    image_bytes = a.size_gib * 1024**3
    # Reserve real capacity despite initially creating a sparse file.
    require(shutil.disk_usage(output.parent).free >= image_bytes + 512 * 1024**2,
            'Destination lacks full image capacity plus512MiB headroom.')
    return {'version': VERSION, 'mode': 'plan', 'output': str(output), 'image_bytes': image_bytes,
            'rootfs': str(archive), 'rootfs_sha256': a.rootfs_sha256.lower(),
            'rootfs_authenticity': 'Hash-pinned input (operator pin or guided first-use pin); not independent vendor signature verification.',
            'bundle': str(bundle) if bundle else None, 'bundle_sha256': digest(bundle) if bundle else None,
            'bundle_plan_validation': 'Header and prerequisites only; clone, exact commit/tree and full fsck are required before publishing an image.',
            'baseline': a.baseline, 'commit': commit, 'tree': tree,
            'hostname': 'archpi' if a.baseline == 'arch' else 'gup-pi4', 'user': 'alarm', 'repo': REPO if bundle else None,
            'network_backend': 'networkd/resolved, optional wpa_supplicant@wlan0; no NetworkManager',
            'auto_upgrade': False, 'autologin': a.autologin, 'wifi_configured': bool(a.wifi_ssid),
            'certification': 'NOT_CERTIFIED: image boot, package providers and graphical runtime require target evidence.',
            'archive': inventory}

def safe_path(root, name):
    require(not PurePosixPath(name).is_absolute() and '..' not in PurePosixPath(name).parts, 'Unsafe configuration path.')
    target = root / name
    require(not target.is_symlink(), 'Refusing configuration symlink: ' + name)
    require(target.parent.resolve().is_relative_to(root.resolve()), 'Configuration parent escapes image: ' + name)
    target.parent.mkdir(parents=True, exist_ok=True)
    return target

def write(root, name, content, mode=0o644):
    target = safe_path(root, name)
    target.write_text(content)
    target.chmod(mode)
    return target

def symlink(root, name, target):
    path = root / name
    require(path.parent.resolve().is_relative_to(root.resolve()), 'Symlink parent escapes image.')
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.is_symlink() or path.is_file():
        path.unlink()
    require(not path.exists(), 'Unexpected non-file at symlink location.')
    path.symlink_to(target)

def enable(root, unit, target='multi-user.target'):
    require((root / 'usr/lib/systemd/system' / unit).is_file() or (root / 'etc/systemd/system' / unit).is_file(), 'Missing target unit: ' + unit)
    location = '/etc/systemd/system/' + unit if (root / 'etc/systemd/system' / unit).is_file() else '/usr/lib/systemd/system/' + unit
    symlink(root, 'etc/systemd/system/' + target + '.wants/' + unit, location)

FIRSTBOOT = r'''#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
state=/var/lib/gup-firstboot
install -d -m0700 "$state"
[[ ! -f $state/complete ]] || exit 0
log=$(mktemp "$state/firstboot.XXXXXX.log")
exec >>"$log" 2>&1
trap 'rc=$?; printf "firstboot_exit=%s\n" "$rc"; exit "$rc"' EXIT
printf '%s\n' 'Local first-boot setup only; no package refresh/install or graphical certification.'
pacman-key --init
pacman-key --populate archlinuxarm
pacman -Q > "$state/packages.initial.txt"
uname -a > "$state/uname.initial.txt"
printf '%s\n' 'PENDING: approved full upgrade, source tests, deployment and live graphical evidence.' > "$state/runtime-status.txt"
printf '%s\n' 'local initialization complete' > "$state/complete.tmp"
mv -T "$state/complete.tmp" "$state/complete"
'''

UPGRADE = r'''#!/usr/bin/env bash
set -Eeuo pipefail
(( EUID == 0 )) || { printf 'Run with sudo after reviewing the transaction.\n' >&2; exit 2; }
[[ ${1:-} == --apply && $# == 1 ]] || { printf 'Usage: sudo gup-upgrade-base --apply\nNo upgrade executed.\n'; exit 2; }
[[ $(uname -m) == aarch64 ]] || { printf 'Requires aarch64 target.\n' >&2; exit 2; }
umask 077
install -d -m0700 /var/log/gup
log=$(mktemp /var/log/gup/upgrade.XXXXXX.log)
printf 'Evidence log: %s\n' "$log"
set +e
pacman -Syu --needed -- bash gawk curl findutils git grep iproute2 pciutils util-linux systemd procps-ng coreutils python python-gobject libnm sudo |& tee "$log"
statuses=("${PIPESTATUS[@]}")
set -e
rc=${statuses[0]}
(( ${statuses[1]} == 0 )) || { printf 'Evidence logging failed; stop and inspect package state.\n' >&2; exit 1; }
printf 'upgrade_exit=%s\n' "$rc" | tee -a "$log"
sha256sum "$log"
(( rc == 0 )) || exit "$rc"
printf '%s\n' 'Upgrade returned0. Reboot readiness and actual package/runtime checks remain pending.'
printf '%s\n' 'No network backend switch or graphical certification was performed.'
'''

SOURCE_CHECK = r'''#!/usr/bin/env bash
set -Eeuo pipefail
(( EUID != 0 )) || { printf 'Run as alarm, without sudo.\n' >&2; exit 2; }
cd /home/alarm/git/4ndr0666_hyprland
export PYTHONDONTWRITEBYTECODE=1 GIT_OPTIONAL_LOCKS=0 GIT_NO_LAZY_FETCH=1
[[ $(git rev-parse HEAD) == EXPECTED_COMMIT ]] || { printf 'Source pin mismatch.\n' >&2; exit 1; }
[[ $(git rev-parse 'HEAD^{tree}') == EXPECTED_TREE ]] || { printf 'Tree pin mismatch.\n' >&2; exit 1; }
[[ -z $(git status --porcelain --untracked-files=all) ]] || { printf 'Source worktree changed; preserve and reconcile it.\n' >&2; exit 1; }
exec bash tests/unit/run-golden-units.sh
'''

RUNTIME_CHECK = r'''#!/usr/bin/env bash
set -Eeuo pipefail
(( EUID != 0 )) || { printf 'Run as the live graphical-session user.\n' >&2; exit 2; }
[[ -n ${WAYLAND_DISPLAY:-} && -n ${DBUS_SESSION_BUS_ADDRESS:-} ]] || { printf 'BLOCKED: live Wayland/D-Bus session required.\n' >&2; exit 20; }
cd /home/alarm/git/4ndr0666_hyprland
[[ $(git rev-parse HEAD) == EXPECTED_COMMIT ]] || { printf 'Source pin mismatch.\n' >&2; exit 1; }
[[ $(git rev-parse 'HEAD^{tree}') == EXPECTED_TREE ]] || { printf 'Tree pin mismatch.\n' >&2; exit 1; }
exec bash tests/oma/run-graphical-certification-packet.sh
'''

def configure(root, a, report, root_id, boot_id):
    uid = gid = None
    for line in (root / 'etc/passwd').read_text().splitlines():
        fields = line.split(':')
        if fields[0] == 'alarm':
            require(len(fields) == 7 and fields[5] == '/home/alarm', 'Unexpected alarm account layout.')
            uid, gid = int(fields[2]), int(fields[3])
    require(uid is not None and uid != 0, 'Rootfs needs a non-root alarm account.')
    require('ID=archarm' in (root / 'etc/os-release').read_text() or 'ID=arch' in (root / 'etc/os-release').read_text(), 'Unexpected OS rootfs.')
    write(root, 'etc/fstab', f'PARTUUID={boot_id} /boot vfat defaults 0 2\nPARTUUID={root_id} / ext4 defaults,noatime 0 1\n')
    hostname = report.get('hostname', 'gup-pi4')
    write(root, 'etc/hostname', hostname + '\n')
    write(root, 'etc/hosts', '127.0.0.1 localhost\n::1 localhost\n127.0.1.1 ' + hostname + '.localdomain ' + hostname + '\n')
    password_hash = private_text(a.password_hash_file)
    root_hash = private_text(a.root_password_hash_file) if a.root_password_hash_file else '!'
    shadow = []
    changed = set()
    for line in (root / 'etc/shadow').read_text().splitlines():
        fields = line.split(':')
        if fields[0] in {'root', 'alarm'}:
            require(len(fields) == 9, 'Invalid shadow entry.')
            fields[1] = root_hash if fields[0] == 'root' else password_hash
            fields[2] = str(int(time.time()) // 86400)
            changed.add(fields[0])
        shadow.append(':'.join(fields))
    require(changed == {'root', 'alarm'}, 'Root/alarm shadow entries required.')
    write(root, 'etc/shadow', '\n'.join(shadow) + '\n', 0o600)
    groups = []
    wheel = False
    for line in (root / 'etc/group').read_text().splitlines():
        fields = line.split(':')
        if fields[0] == 'wheel':
            require(len(fields) == 4, 'Invalid wheel group.')
            fields[3] = ','.join(dict.fromkeys([x for x in fields[3].split(',') if x] + ['alarm']))
            wheel = True
        groups.append(':'.join(fields))
    require(wheel, 'Rootfs lacks wheel group.')
    write(root, 'etc/group', '\n'.join(groups) + '\n')
    require((root / 'usr/bin/sudo').is_file() or a.root_password_hash_file, 'No usable sudo or local root recovery route.')
    write(root, 'etc/sudoers.d/20-gup-wheel', '%wheel ALL=(ALL:ALL) ALL\n', 0o440)
    auth = write(root, 'home/alarm/.ssh/authorized_keys', Path(a.ssh_key).read_text().strip() + '\n', 0o600)
    auth.parent.chmod(0o700)
    os.chown(auth.parent, uid, gid); os.chown(auth, uid, gid)
    # Put explicit auth policy first: OpenSSH usually uses the first obtained value.
    ssh = root / 'etc/ssh/sshd_config'
    require(ssh.is_file(), 'Rootfs lacks sshd_config.')
    require(not re.search(r'^\s*Match\s', ssh.read_text(), re.M), 'Rootfs SSH Match policy needs review before customization.')
    policy = 'PermitRootLogin no\nPubkeyAuthentication yes\nPasswordAuthentication no\nKbdInteractiveAuthentication no\nPermitEmptyPasswords no\nAuthenticationMethods publickey\nAllowUsers alarm\nUsePAM yes\n'
    write(root, 'etc/ssh/sshd_config', policy + ssh.read_text())
    for key in (root / 'etc/ssh').glob('ssh_host_*'):
        require(not key.is_dir(), 'Unexpected SSH host-key directory.')
        key.unlink()
    write(root, 'etc/systemd/system/gup-hostkeys.service', '[Unit]\nDescription=Generate unique SSH host keys\nBefore=sshd.service\n[Service]\nType=oneshot\nExecStart=/usr/bin/ssh-keygen -A\nRemainAfterExit=yes\n')
    write(root, 'etc/systemd/system/sshd.service.d/20-gup-hostkeys.conf', '[Unit]\nRequires=gup-hostkeys.service\nAfter=gup-hostkeys.service\n')
    write(root, 'etc/machine-id', '')
    if (root / 'var/lib/dbus/machine-id').exists() or (root / 'var/lib/dbus/machine-id').is_symlink():
        symlink(root, 'var/lib/dbus/machine-id', '/etc/machine-id')
    write(root, 'etc/systemd/network/20-gup-ethernet.network', '[Match]\nName=en* eth*\n[Network]\nDHCP=yes\nIPv6AcceptRA=yes\n')
    enable(root, 'systemd-networkd.service'); enable(root, 'systemd-resolved.service')
    symlink(root, 'etc/resolv.conf', '/run/systemd/resolve/stub-resolv.conf')
    if a.wifi_ssid:
        require((root / 'usr/lib/systemd/system/wpa_supplicant@.service').is_file(), 'Rootfs lacks wpa_supplicant template; use Ethernet or another rootfs.')
        write(root, 'etc/systemd/network/25-gup-wlan0.network', '[Match]\nName=wlan0\n[Network]\nDHCP=yes\nIPv6AcceptRA=yes\n')
        write(root, 'etc/wpa_supplicant/wpa_supplicant-wlan0.conf', wifi_config(a.wifi_ssid, private_text(a.wifi_password_file)), 0o600)
        symlink(root, 'etc/systemd/system/multi-user.target.wants/wpa_supplicant@wlan0.service', '/usr/lib/systemd/system/wpa_supplicant@.service')
    auto = root / 'etc/systemd/system/getty@tty1.service.d/autologin.conf'
    if auto.exists() or auto.is_symlink():
        require(not auto.is_dir(), 'Unexpected autologin path.'); auto.unlink()
    if a.autologin:
        write(root, 'etc/systemd/system/getty@tty1.service.d/autologin.conf', '[Service]\nExecStart=\nExecStart=-/sbin/agetty --autologin alarm --noclear %I $TERM\n')
    write(root, 'usr/local/lib/gup/firstboot.sh', FIRSTBOOT, 0o755)
    write(root, 'usr/local/sbin/gup-upgrade-base', UPGRADE, 0o755)
    for name, payload in ([] if a.baseline == 'arch' else [('gup-validate-source', SOURCE_CHECK), ('gup-runtime-check', RUNTIME_CHECK)]):
        write(root, 'usr/local/bin/' + name, payload.replace('EXPECTED_COMMIT', report['commit']).replace('EXPECTED_TREE', report['tree']), 0o755)
    write(root, 'etc/systemd/system/gup-firstboot.service', '[Unit]\nDescription=Local GUP first-boot initialization (no upgrade)\nAfter=local-fs.target\nConditionPathExists=!/var/lib/gup-firstboot/complete\n[Service]\nType=oneshot\nExecStart=/usr/local/lib/gup/firstboot.sh\nRemainAfterExit=yes\n[Install]\nWantedBy=multi-user.target\n')
    enable(root, 'gup-firstboot.service'); enable(root, 'sshd.service')
    write(root, 'etc/gup-provisioning.json', json.dumps(report, indent=2) + '\n')
    return uid, gid

def patch_boot(root, root_id, records):
    found = 0
    for name in ['boot/cmdline.txt', 'boot/boot.txt']:
        path = safe_path(root, name)
        if not path.is_file():
            continue
        text = path.read_text()
        patched, count = re.subn(r'(?<!\S)root=[^\s"\';]+', 'root=PARTUUID=' + root_id, text)
        require(count == 1, 'Expected exactly one root= argument in ' + name + '; boot layout needs explicit review.')
        write(root, name, patched)
        found += count
        if name.endswith('boot.txt'):
            # Never execute a rootfs-supplied mkscr program on the host.
            executable_tools(['mkimage'])
            run(['mkimage', '-A', 'arm', '-O', 'linux', '-T', 'script', '-C', 'none',
                 '-n', 'GUP Pi4 boot', '-d', path, safe_path(root, 'boot/boot.scr')], records=records)
    require(found > 0, 'No recognized boot root argument; image NOT boot-certified.')

def build(a, *, guided=False):
    require(os.geteuid() == 0, '--build needs root for loop devices and mounts; --plan does not.')
    executable_tools(['git', 'ssh-keygen', 'bsdtar', 'losetup', 'sfdisk', 'udevadm',
                      'mkfs.vfat', 'mkfs.ext4', 'mount', 'umount', 'blkid', 'sync'])
    report = plan(a)
    output = Path(report['output'])
    previous_umask = os.umask(0o022)
    work = Path(tempfile.mkdtemp(prefix='.gup-pi4-build.', dir=output.parent))
    work.chmod(0o700)
    image = work / 'image.partial'
    journal = work / 'build-commands.json'
    records = []
    mounts = []
    loop = None
    completed = False
    cleanup_errors = []
    print('Private build/evidence directory: ' + str(work), flush=True)
    try:
        print('Preparing the new image and its filesystems…', flush=True)
        with image.open('xb') as f:
            f.truncate(report['image_bytes'])
        image.chmod(0o600)
        loop = run(['losetup', '--find', '--show', '--partscan', '--', image], records=records)
        require(re.fullmatch('/dev/loop[0-9]+', loop), 'Unexpected loop device.')
        run(['sfdisk', '--wipe', 'always', loop], data=b'label: dos\nunit: sectors\n\nstart=2048,size=2097152,type=c,bootable\ntype=83\n', records=records)
        run(['udevadm', 'settle', '--timeout=30'], records=records)
        boot, rootdev = loop + 'p1', loop + 'p2'
        for _ in range(50):
            if Path(boot).is_block_device() and Path(rootdev).is_block_device():
                break
            time.sleep(0.1)
        require(Path(boot).is_block_device() and Path(rootdev).is_block_device(), 'Loop partitions did not appear.')
        run(['mkfs.vfat', '-F', '32', '-n', 'GUP_BOOT', boot], records=records)
        run(['mkfs.ext4', '-F', '-L', 'GUP_ROOT', rootdev], records=records)
        root = work / 'root'; root.mkdir()
        run(['mount', rootdev, root], records=records); mounts.append(root)
        (root / 'boot').mkdir()
        run(['mount', boot, root / 'boot'], records=records); mounts.append(root / 'boot')
        print('Extracting the root filesystem…', flush=True)
        run(['bsdtar', '-xpf', report['rootfs'], '--numeric-owner', '-C', root], timeout=1800, records=records)
        root_id = run(['blkid', '-s', 'PARTUUID', '-o', 'value', rootdev], records=records)
        boot_id = run(['blkid', '-s', 'PARTUUID', '-o', 'value', boot], records=records)
        require(re.fullmatch('[0-9a-fA-F]{8}-02', root_id) and re.fullmatch('[0-9a-fA-F]{8}-01', boot_id), 'Unexpected DOS partition identities.')
        report.update(root_partuuid=root_id, boot_partuuid=boot_id, mode='built-not-boot-tested')
        print('Setting up sign-in, networking and first boot…', flush=True)
        uid, gid = configure(root, a, report, root_id, boot_id)
        if report.get('bundle'):
            repo = safe_path(root, REPO.lstrip('/'))
            require(not repo.exists(), 'Vendor archive already contains the GUP checkout; refuse overwrite.')
            print('Installing and checking the pinned source…', flush=True)
            run(['git', '-c', 'core.hooksPath=/dev/null', 'clone', '--no-checkout', '--', report['bundle'], repo], timeout=600, records=records)
            run(['git', '-C', repo, '-c', 'core.hooksPath=/dev/null', 'checkout', '--detach', report['commit']], records=records)
            require(run(['git', '-C', repo, 'rev-parse', 'HEAD'], records=records) == report['commit'], 'Checkout commit mismatch.')
            require(run(['git', '-C', repo, 'rev-parse', 'HEAD^{tree}'], records=records) == report['tree'], 'Checkout tree mismatch.')
            run(['git', '-C', repo, 'fsck', '--full', '--strict'], timeout=600, records=records)
            run(['git', '-C', repo, 'remote', 'set-url', 'origin', 'https://github.com/4ndr0666/4ndr0666_hyprland.git'], records=records)
        # Host-generated parent dirs must also belong to the target account.
        for directory, dirs, files in os.walk(root / 'home/alarm', followlinks=False):
            os.chown(directory, uid, gid)
            for name in dirs + files:
                os.lchown(Path(directory) / name, uid, gid)
        patch_boot(root, root_id, records)
        run(['sync', '-f', root], records=records)
        for mounted in list(reversed(mounts)):
            run(['umount', mounted], records=records); mounts.remove(mounted)
        run(['losetup', '--detach', loop], records=records); loop = None
        # Recheck immutable inputs to catch accidental changes during a long build.
        require(digest(report['rootfs']) == report['rootfs_sha256'] and (not report.get('bundle') or digest(report['bundle']) == report['bundle_sha256']), 'Input changed during build.')
        print('Finalizing and hashing the image…', flush=True)
        image_hash = digest(image)
        with image.open('rb') as f:
            os.fsync(f.fileno())
        # Hard-link publication fails if output was created concurrently; no overwrite.
        os.link(image, output); image.unlink()
        if os.geteuid() == 0 and os.environ.get('SUDO_UID', '').isdecimal() and os.environ.get('SUDO_GID', '').isdecimal():
            os.chown(output, int(os.environ['SUDO_UID']), int(os.environ['SUDO_GID']))
        report.update(image_sha256=image_hash, output=str(output))
        write_path = work / 'image-manifest.json'
        write_path.write_text(json.dumps(report, indent=2) + '\n')
        (work / 'SHA256SUMS').write_text(image_hash + '  ' + str(output) + '\n')
        completed = True
        if not guided:
            print(json.dumps(report, indent=2))
        print('Image saved: ' + str(output), flush=True)
        print('Image created; NOT flashed, boot-tested or GUP certified. Keep the evidence directory private.')
        if not guided or os.environ.get('GUP_INTERFACE') == 'guided':
            print('GUP_IMAGE_RESULT=' + json.dumps({'output': str(output), 'image_sha256': image_hash}), flush=True)
        return report
    finally:
        for mounted in list(reversed(mounts)):
            try:
                run(['umount', mounted], records=records); mounts.remove(mounted)
            except Exception as exc:
                cleanup_errors.append(str(exc))
        # Never detach a still-mounted loop, and never delete its underlying tree.
        if loop and not mounts:
            try:
                run(['losetup', '--detach', loop], records=records); loop = None
            except Exception as exc:
                cleanup_errors.append(str(exc))
        journal.write_text(json.dumps({'commands': records, 'completed': completed,
                                       'remaining_mounts': [str(x) for x in mounts],
                                       'remaining_loop': loop, 'cleanup_errors': cleanup_errors}, indent=2) + '\n')
        if not mounts and loop is None and os.geteuid() == 0 and os.environ.get('SUDO_UID', '').isdecimal() and os.environ.get('SUDO_GID', '').isdecimal():
            owner = int(os.environ['SUDO_UID']), int(os.environ['SUDO_GID'])
            for directory, dirs, files in os.walk(work, followlinks=False):
                os.chown(directory, *owner)
                for name in dirs + files:
                    os.lchown(Path(directory) / name, *owner)
        os.umask(previous_umask)
        if cleanup_errors:
            print('CLEANUP INCOMPLETE: preserve ' + str(work) + '\n' + '\n'.join(cleanup_errors), file=sys.stderr)
            raise Refusal('Cleanup incomplete; image is not accepted.')

def flatten_devices(items):
    for item in items:
        yield item
        yield from flatten_devices(item.get('children', []))

def validate_target(device, image_bytes, inventory, swaps):
    roots = inventory['blockdevices']
    require(len(roots) == 1, 'Expected one target device tree.')
    disk = roots[0]
    require(disk['path'] == device and disk['type'] == 'disk', 'Target must be a physical whole disk, not a partition/loop/mapper.')
    require(not disk.get('ro'), 'Target is read-only.')
    require(int(disk['size']) >= image_bytes, 'Image is larger than target.')
    for node in flatten_devices(roots):
        require(node['path'] not in swaps, 'Target contains active swap.')
        require(not any(node.get('mountpoints') or []), 'Target has a mounted filesystem: ' + node['path'])
        require(node['type'] in {'disk', 'part'}, 'Target has an active mapped/RAID/encrypted consumer.')
    return disk

def flash(a):
    require(os.geteuid() == 0, '--flash requires root.')
    executable_tools(['lsblk', 'swapon', 'udevadm', 'wipefs', 'blockdev'])
    image = Path(a.flash).resolve(strict=True)
    require(image.is_file() and image.stat().st_size > 1024**3, 'Expected a regular full image file larger than1GiB.')
    require(re.fullmatch('[a-fA-F0-9]{64}', a.image_sha256 or ''), 'Expected external image SHA256.')
    require(digest(image) == a.image_sha256.lower(), 'Image hash mismatch; no target opened for writing.')
    device = str(Path(a.device).resolve(strict=True))
    require(stat.S_ISBLK(os.stat(device).st_mode), 'Not a block device.')
    def inspect():
        inventory = json.loads(run(['lsblk', '--json', '--bytes', '--paths', '--output', 'PATH,TYPE,SIZE,RO,MOUNTPOINTS,MODEL,SERIAL', device]))
        swaps = set(run(['swapon', '--show', '--noheadings', '--raw', '--output', 'NAME']).splitlines())
        disk = validate_target(device, image.stat().st_size, inventory, swaps)
        return inventory, disk
    inventory, disk = inspect()
    print(json.dumps(inventory, indent=2), flush=True)
    print('DESTRUCTIVE FLASH: all existing partitions/data on ' + device + ' will be replaced.', flush=True)
    print('Input image: ' + str(image) + '\nExpected hash: ' + a.image_sha256, flush=True)
    with ControlTerminal() as tty:
        tty.write('Type ERASE ' + device + ' to authorize this exact disk: '); tty.flush()
        require(tty.readline().strip() == 'ERASE ' + device, 'Confirmation did not match; target unchanged.')
    inventory2, disk2 = inspect()
    require(disk == disk2, 'Target identity/state changed after confirmation.')
    flash_work = Path(tempfile.mkdtemp(prefix='.gup-flash.', dir=image.parent))
    flash_work.chmod(0o700)
    print('Flash evidence: ' + str(flash_work), flush=True)
    flash_report = {'image': str(image), 'expected_sha256': a.image_sha256.lower(),
                    'device': device, 'inventory': inventory2, 'completed': False, 'commands': []}
    try:
        flash_copy(image, device, a.image_sha256.lower(), flash_report)
        flash_report['completed'] = True
    finally:
        (flash_work / 'flash-report.json').write_text(json.dumps(flash_report, indent=2) + '\n')
        (flash_work / 'SHA256SUMS').write_text(digest(flash_work / 'flash-report.json') + '  flash-report.json\n')
    print('Root partition retains the image size; no automatic expansion or reboot was performed.')

def flash_copy(image, device, expected_hash, report):
    # Wipe stale backup GPT/RAID signatures only AFTER explicit erase authorization.
    # Otherwise a DOS image on a larger old GPT disk can leave conflicting headers.
    run(['wipefs', '--all', device], records=report['commands'])
    expected_rdev = os.stat(device).st_rdev
    # No discard, signature bypass, forced unmount or automatic retries.
    total = image.stat().st_size
    target_fd = os.open(device, os.O_RDWR | os.O_EXCL | os.O_CLOEXEC)
    with image.open('rb') as source, os.fdopen(target_fd, 'r+b', buffering=0) as target:
        require(stat.S_ISBLK(os.fstat(target.fileno()).st_mode) and os.fstat(target.fileno()).st_rdev == expected_rdev, 'Target changed before open.')
        done = 0
        while True:
            chunk = source.read(8 * 1024**2)
            if not chunk:
                break
            view = memoryview(chunk)
            while view:
                written = target.write(view)
                require(written and written > 0, 'Short/failed device write.')
                view = view[written:]
            done += len(chunk)
            print(f'\rWritten {done}/{total} bytes', end='', flush=True)
        os.fsync(target.fileno())
        # Linux BLKFLSBUF: invalidate block cache after flushing before readback.
        # This is not a power-cycle test or proof the card will boot.
        fcntl.ioctl(target.fileno(), 0x1261)
        target.seek(0)
        h = hashlib.sha256(); remaining = total
        while remaining:
            chunk = target.read(min(8 * 1024**2, remaining))
            require(chunk, 'Truncated device readback.')
            h.update(chunk); remaining -= len(chunk)
        report.update(written_bytes=done, readback_bytes=total, readback_sha256=h.hexdigest())
        require(h.hexdigest() == expected_hash, 'Device readback hash mismatch; do not boot/accept this card.')
    print('\nFlash/readback matches image bytes. Partition/filesystem/boot checks still pending.')
    run(['blockdev', '--rereadpt', device], records=report['commands'])
    run(['udevadm', 'settle', '--timeout=30'], records=report['commands'])

class Cancelled(Exception):
    pass

class ControlTerminal:
    """Separate streams: /dev/tty cannot be opened as a seekable r+ stream."""
    def __init__(self):
        self.reader = open('/dev/tty', 'r')
        try:
            self.writer = open('/dev/tty', 'w')
        except BaseException:
            self.reader.close(); raise
    def write(self, text):
        return self.writer.write(text)
    def flush(self):
        self.writer.flush()
    def readline(self):
        return self.reader.readline()
    def fileno(self):
        return self.writer.fileno()
    def __enter__(self):
        return self
    def __exit__(self, *exc):
        self.reader.close(); self.writer.close()

def display_text(text):
    # Device labels, filenames and saved settings must not inject terminal controls.
    return ''.join(c if c.isprintable() else '?' for c in str(text))

class TerminalUI:
    def __init__(self, tty):
        self.tty = tty
        name = os.environ.get('SUDO_USER') if os.geteuid() == 0 else None
        user = pwd.getpwnam(name) if name else pwd.getpwuid(os.getuid())
        self.home, self.uid, self.gid = Path(user.pw_dir), user.pw_uid, user.pw_gid
        base = Path(os.environ.get('XDG_STATE_HOME') or self.home / '.local/state') if not name else self.home / '.local/state'
        self.folder = base / 'gup-pi4'
        self.use_fzf = bool(shutil.which('fzf'))
        # Change ownership only on newly created application directories/files.
        missing = []; parent = self.folder
        while not parent.exists():
            missing.append(parent); parent = parent.parent
        for directory in reversed(missing):
            directory.mkdir(mode=0o700)
            if os.geteuid() == 0:
                os.chown(directory, self.uid, self.gid)
        require(self.folder.is_dir() and not self.folder.is_symlink(), 'Invalid application state directory.')
        self.profile = self.folder / 'session.json'
        require(not self.profile.is_symlink(), 'Saved session must not be a symlink.')
        self.saved = {}
        if self.profile.is_file():
            try:
                loaded = json.loads(self.profile.read_text())
                require(isinstance(loaded, dict), 'Invalid session structure.')
                require(loaded.get('baseline', 'r6') in {'arch', 'r6', 'r7'}, 'Invalid saved baseline.')
                require(type(loaded.get('size_gib', 16)) is int and 8 <= loaded.get('size_gib', 16) <= 512, 'Invalid saved image size.')
                require(type(loaded.get('autologin', False)) is bool, 'Invalid saved autologin setting.')
                for field in ['rootfs', 'rootfs_sha256', 'bundle', 'ssh_key', 'password_hash_file',
                              'root_password_hash_file', 'wifi_ssid', 'wifi_password_file', 'image_directory']:
                    require(loaded.get(field) is None or isinstance(loaded[field], str), 'Invalid saved field: ' + field)
                if loaded.get('last_image'):
                    receipt = loaded['last_image']
                    require(isinstance(receipt, dict) and isinstance(receipt.get('output'), str)
                            and re.fullmatch('[a-fA-F0-9]{64}', receipt.get('image_sha256', '')), 'Invalid saved image receipt.')
                self.saved = loaded
            except (ValueError, TypeError, Refusal):
                fd, backup = tempfile.mkstemp(prefix='session-unreadable.', suffix='.json', dir=self.folder)
                os.close(fd); os.replace(self.profile, backup)
                self.say('Saved setup was unreadable; preserved at ' + backup + '. Starting fresh.')

    def say(self, message=''):
        self.tty.write(display_text(message) + '\n'); self.tty.flush()

    def ask(self, prompt, default=''):
        self.tty.write(display_text(prompt) + (' [' + display_text(default) + ']' if default else '') + ': ')
        self.tty.flush()
        line = self.tty.readline()
        if not line:
            raise Cancelled()
        return line.strip() or default

    def choose(self, title, options):
        require(bool(options), 'No menu choices available.')
        self.say(title)
        if self.use_fzf:
            rows = [str(i) + '\t' + display_text(label) for i, (_, label) in enumerate(options)]
            env = dict(ENV, FZF_DEFAULT_OPTS='', FZF_DEFAULT_OPTS_FILE='/dev/null', FZF_DEFAULT_COMMAND='')
            color = '--no-color' if 'NO_COLOR' in os.environ else '--color=fg:#00e5ff,hl:#67e8f9,fg+:#ffffff,bg+:#0a131a,pointer:#ff0055'
            result = subprocess.run(['fzf', '--delimiter=\t', '--with-nth=2..', '--no-multi',
                '--layout=reverse', '--height=80%', '--prompt=GUP > ',
                '--header=' + display_text(title), color],
                input='\n'.join(rows) + '\n', text=True, stdout=subprocess.PIPE, stderr=self.tty, env=env)
            if result.returncode in {1, 130}:
                raise Cancelled()
            if result.returncode != 0:
                self.say('fzf is unavailable in this terminal; switching to the numbered menu.')
                self.use_fzf = False
                return self.choose(title, options)
            index = result.stdout.split('\t', 1)[0]
            require(re.fullmatch(r'[0-9]+', index) and '\n' not in result.stdout.rstrip('\n'), 'Invalid picker result.')
            require(int(index) < len(options), 'Picker returned an unknown choice.')
            return options[int(index)][0]
        for i, (_, label) in enumerate(options, 1):
            self.say(f'  {i}. {label}')
        while True:
            answer = self.ask('Choose a number (q cancels)')
            if answer.lower() in {'q', 'quit', 'esc'}:
                raise Cancelled()
            if answer.isdecimal() and 1 <= int(answer) <= len(options):
                return options[int(answer) - 1][0]
            self.say('Choose one of the listed numbers.')

    def save(self):
        fd, name = tempfile.mkstemp(prefix='.session.', dir=self.folder)
        with os.fdopen(fd, 'w') as stream:
            json.dump(self.saved, stream, indent=2); stream.write('\n')
        if os.geteuid() == 0:
            os.chown(name, self.uid, self.gid)
        os.replace(name, self.profile)

    def private_file(self, label, text):
        fd, name = tempfile.mkstemp(prefix=label + '.', dir=self.folder)
        with os.fdopen(fd, 'w') as stream:
            stream.write(text.rstrip('\n') + '\n')
        if os.geteuid() == 0:
            os.chown(name, self.uid, self.gid)
        return name

    def password_hash(self, label):
        executable_tools(['openssl'])
        while True:
            first = getpass.getpass(label + ': ', stream=self.tty)
            second = getpass.getpass('Repeat password: ', stream=self.tty)
            if first and first == second and '\n' not in first:
                value = run(['openssl', 'passwd', '-6', '-stdin'], data=(first + '\n').encode())
                require(valid_password_hash(value), 'Password hashing failed.')
                return self.private_file('password-hash', value)
            self.say('Passwords must be nonempty and match. Try again.')

    def roots(self):
        return list(dict.fromkeys([Path.cwd(), SCRIPT_PATH.parent, self.home / 'Downloads', self.folder]))

    def find_files(self, patterns):
        found = []
        for root in self.roots():
            if root.is_dir():
                for pattern in patterns:
                    found.extend(p.resolve() for p in list(root.glob(pattern))[:200] if p.is_file())
        return sorted(set(found), key=str)

    def file_picker(self, title, patterns):
        choices = self.find_files(patterns)
        if len(choices) == 1:
            self.say(title + ': ' + str(choices[0])); return str(choices[0])
        options = [(str(path), str(path)) for path in choices] + [('other', 'Choose another file by path')]
        value = self.choose(title, options)
        if value == 'other':
            value = self.ask('File path')
        path = Path(value).expanduser().resolve(strict=True)
        require(path.is_file(), 'Expected a file: ' + str(path))
        return str(path)

def download_rootfs(ui):
    executable_tools(['curl'])
    require(shutil.disk_usage(ui.folder).free >= 2 * 1024**3, 'At least2GiB download space is needed in the application cache.')
    attempts = []
    temporary = None
    for url in ROOTFS_URLS:
        fd, temporary = tempfile.mkstemp(prefix='rootfs.', suffix='.partial', dir=ui.folder); os.close(fd)
        host = url.split('/')[2]
        ui.say('Downloading from ' + host + ' over verified HTTPS…')
        command = ['curl', '--fail', '--location', '--proto', '=https', '--proto-redir', '=https',
            '--connect-timeout', '20', '--max-time', '3600', '--retry', '2', '--max-filesize', '4294967296',
            '--output', temporary, url]
        result = subprocess.run(command, stdin=subprocess.DEVNULL, stdout=ui.tty, stderr=ui.tty)
        attempt = {'argv': command, 'exit_status': result.returncode, 'partial_path': temporary,
                   'url': url, 'archive_verified': False}
        if result.returncode == 0:
            ui.say('Checking the downloaded archive before accepting it…')
            try:
                attempt['archive_inventory'] = archive_inventory(temporary)
                attempt['archive_verified'] = True
            except (Refusal, OSError, ValueError, tarfile.TarError) as exc:
                attempt['validation_error'] = str(exc)
        attempts.append(attempt)
        ui.saved['last_download_evidence'] = ui.private_file('download', json.dumps({
            'attempts': attempts, 'exit_status': result.returncode,
            'archive_verified': attempt['archive_verified'],
            'authentication': 'TLS certificate/hostname verification enabled on every mirror and redirect; no independent vendor signature.'}, indent=2))
        ui.save()
        if result.returncode == 0 and attempt['archive_verified']:
            break
        if result.returncode == 0:
            if url != ROOTFS_URLS[-1]:
                ui.say('The mirror returned an invalid archive; trying the next HTTPS mirror.')
            continue
        # Only remote/transport errors justify another mirror. Disk/write/memory
        # failures must stop rather than consuming more space or hiding the cause.
        if result.returncode not in {5, 6, 7, 18, 22, 28, 35, 51, 52, 55, 56, 60, 92}:
            raise Refusal('Download stopped (curl ' + str(result.returncode) + '); partial file retained: ' + temporary)
        if url != ROOTFS_URLS[-1]:
            reason = 'Certificate verification failed' if result.returncode in {51, 60} else 'Mirror transfer failed'
            ui.say(reason + '; automatically trying the next HTTPS mirror.')
    else:
        raise Refusal('No HTTPS mirror succeeded. TLS verification was not bypassed; attempts/partial files are retained in ' + str(ui.folder))
    checksum = digest(temporary)
    path = ui.folder / ('ArchLinuxARM-rpi-aarch64-' + checksum[:16] + '.tar.gz')
    if path.exists():
        require(digest(path) == checksum, 'Cached rootfs has a different hash. Retained both files for review.')
        Path(temporary).unlink()
    else:
        os.replace(temporary, path)
    if os.geteuid() == 0:
        os.chown(path, ui.uid, ui.gid)
    return str(path), checksum, 'Official HTTPS first-download pin; no independent signature verification.'

def select_rootfs(ui):
    local = ui.find_files(['ArchLinuxARM*rpi*aarch64*.tar*', '*rootfs*.tar*'])
    choices = [(str(path), 'Use ' + str(path)) for path in local]
    choices += [('download', 'Download Arch Linux ARM for the Pi (HTTPS)'),
                ('other', 'Select a different local rootfs')]
    selected = ui.choose('Root filesystem', choices)
    if selected == 'download':
        return download_rootfs(ui)
    path = ui.file_picker('Rootfs archive', ['*.tar.gz', '*.tar.xz']) if selected == 'other' else selected
    actual = digest(path)
    # Reuse a trusted sibling checksum if supplied; no checksum chores for downloads.
    for sidecar in [Path(path + '.sha256'), Path(path).parent / 'rootfs.sha256']:
        if not sidecar.is_file():
            continue
        found = []
        for line in sidecar.read_text().splitlines():
            match = re.fullmatch(r'([a-fA-F0-9]{64})(?:[ \t]+\*?(.+))?', line.strip())
            if match and (match[2] is None or Path(match[2]).name == Path(path).name):
                found.append(match[1].lower())
        require(len(found) == 1 and found[0] == actual, 'Supplied rootfs checksum does not match; choose a different archive.')
        return path, actual, 'Matched operator-supplied sibling checksum.'
    ui.say('Local archive SHA256: ' + actual)
    decision = ui.choose('This local archive has no independent checksum.', [
        ('pin', 'Trust this local archive and remember its checksum'),
        ('download', 'Use the official HTTPS download instead'), ('cancel', 'Back')])
    if decision == 'cancel':
        raise Cancelled()
    if decision == 'download':
        return download_rootfs(ui)
    return path, actual, 'Operator-approved local first-use pin; no independent vendor verification.'

def choose_ssh_key(ui):
    candidates = ui.find_files(['alarm.pub', '*.pub'])
    if (ui.home / '.ssh').is_dir():
        candidates += sorted((ui.home / '.ssh').glob('*.pub'))
    candidates = list(dict.fromkeys(candidates))
    if len(candidates) == 1:
        ui.say('Using existing public key: ' + str(candidates[0])); return str(candidates[0])
    options = [(str(p), 'Use public key ' + str(p)) for p in candidates]
    options.append(('generate', 'Create a dedicated Pi SSH key automatically'))
    choice = ui.choose('SSH access', options) if candidates else 'generate'
    if choice != 'generate':
        return choice
    executable_tools(['ssh-keygen'])
    folder = Path(tempfile.mkdtemp(prefix='ssh-key.', dir=ui.folder)); folder.chmod(0o700)
    key = folder / 'gup_pi4_ed25519'
    run(['ssh-keygen', '-q', '-t', 'ed25519', '-N', '', '-f', key])
    if os.geteuid() == 0:
        for item in [folder, key, Path(str(key) + '.pub')]:
            os.chown(item, ui.uid, ui.gid)
    ui.say('Created dedicated SSH key. Keep this private key: ' + str(key))
    return str(key) + '.pub'

def default_image_directory(ui, size_gib):
    for base in [Path('/sto2'), Path('/Nas'), ui.home]:
        if base.is_dir() and (base == ui.home or base.is_mount()) and shutil.disk_usage(base).free > (size_gib + 1) * 1024**3:
            return base / 'gup-images'
    return ui.home / 'gup-images'

def prepared_args(ui):
    a = parse(['--interactive'])
    for name in ['baseline', 'size_gib', 'rootfs', 'rootfs_sha256', 'bundle', 'ssh_key',
                 'password_hash_file', 'root_password_hash_file', 'wifi_ssid', 'wifi_password_file', 'autologin']:
        if name in ui.saved:
            setattr(a, name, ui.saved[name])
    if not a.rootfs or not Path(a.rootfs).is_file():
        a.rootfs, a.rootfs_sha256, trust = select_rootfs(ui)
        ui.saved.update(rootfs=a.rootfs, rootfs_sha256=a.rootfs_sha256, rootfs_trust=trust); ui.save()
    ui.say('Checking rootfs integrity and architecture…')
    _, inventory = checked_rootfs(a)
    if a.baseline != 'arch' and (not a.bundle or not Path(a.bundle).is_file()):
        a.bundle = ui.file_picker('Source bundle for ' + a.baseline.upper(), ['gup-source-' + a.baseline + '.bundle'])
        ui.saved['bundle'] = a.bundle; ui.save()
    if not a.ssh_key or not Path(a.ssh_key).is_file():
        a.ssh_key = choose_ssh_key(ui); ui.saved['ssh_key'] = a.ssh_key; ui.save()
    if not a.password_hash_file or not Path(a.password_hash_file).is_file():
        ui.say('Choose the Pi local-login password; the script creates the hash file for you.')
        a.password_hash_file = ui.password_hash('Pi user password')
        ui.saved['password_hash_file'] = a.password_hash_file; ui.save()
    if not inventory['sudo_present'] and (not a.root_password_hash_file or not Path(a.root_password_hash_file).is_file()):
        ui.say('This rootfs lacks sudo. Choose a distinct local root recovery password (root SSH remains off).')
        a.root_password_hash_file = ui.password_hash('Local root recovery password')
        ui.saved['root_password_hash_file'] = a.root_password_hash_file; ui.save()
    directory = Path(ui.saved.get('image_directory') or default_image_directory(ui, a.size_gib)).expanduser()
    directory.mkdir(parents=True, exist_ok=True)
    a.output = str(directory / ('arch-pi-' + a.baseline + '-' + time.strftime('%Y%m%d-%H%M%S') + '.img'))
    return a

def build_arguments(a):
    args = ['--build', '--output', a.output, '--size-gib', str(a.size_gib), '--baseline', a.baseline]
    for name in ['rootfs', 'rootfs_sha256', 'bundle', 'ssh_key', 'password_hash_file',
                 'root_password_hash_file', 'wifi_ssid', 'wifi_password_file']:
        value = getattr(a, name)
        if value:
            args += ['--' + name.replace('_', '-'), str(value)]
    if a.autologin:
        args.append('--autologin')
    return args

def privileged_script(ui, args):
    executable_tools(['sudo'])
    require(SCRIPT_PATH.is_file(), 'Cannot locate this script for privilege escalation.')
    result = None
    child = subprocess.Popen(['sudo', '--', 'env', 'GUP_INTERFACE=guided', 'bash', str(SCRIPT_PATH), *args],
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    try:
        for line in child.stdout:
            if line.startswith('GUP_IMAGE_RESULT='):
                result = json.loads(line.split('=', 1)[1])
            else:
                ui.say(line.rstrip('\n'))
        status = child.wait()
    except BaseException:
        child.terminate(); child.wait(); raise
    finally:
        child.stdout.close()
    require(status == 0, 'Operation failed (exit ' + str(status) + '); evidence/partial files retained. No automatic retry.')
    return result

def target_picker(ui, image_size):
    while True:
        inventory = json.loads(run(['lsblk', '--json', '--bytes', '--paths', '--output',
            'PATH,TYPE,SIZE,RO,MOUNTPOINTS,MODEL,SERIAL,TRAN,RM']))
        swaps = set(run(['swapon', '--show', '--noheadings', '--raw', '--output', 'NAME']).splitlines())
        options = []; devices = {}
        for disk in inventory['blockdevices']:
            tree = {'blockdevices': [disk]}
            mounts = [(node['path'], mount) for node in flatten_devices([disk]) for mount in node.get('mountpoints') or [] if mount]
            # Offer a graceful unmount only for removable-media mount locations.
            can_unmount = bool(mounts) and all(m.startswith(('/run/media/', '/media/')) for _, m in mounts)
            try:
                if mounts and can_unmount:
                    copy = json.loads(json.dumps(tree))
                    for node in flatten_devices(copy['blockdevices']):
                        node['mountpoints'] = []
                    validate_target(disk['path'], image_size, copy, swaps)
                else:
                    validate_target(disk['path'], image_size, tree, swaps)
            except Refusal:
                continue
            value = disk['path']; devices[value] = mounts
            label = f"{value} | {int(disk['size']) / 1024**3:.1f} GiB | {disk.get('model') or '?'} | serial {disk.get('serial') or '?'}"
            if mounts:
                label += ' | will ask to unmount'
            options.append((value, label))
        options += [('rescan', 'Rescan after inserting a card'), ('back', 'Back without flashing')]
        choice = ui.choose('Select SD card — system/data mounts are excluded; nothing erased yet', options)
        if choice == 'back':
            raise Cancelled()
        if choice == 'rescan':
            continue
        if devices[choice]:
            if ui.choose('Unmount selected removable-media partitions?', [('yes', 'Unmount normally and continue'), ('no', 'Back')]) != 'yes':
                continue
            for partition in dict.fromkeys(path for path, _ in devices[choice]):
                command = ['umount', '--', partition]
                if os.geteuid() != 0:
                    command = ['sudo', '--', *command]
                run(command)
        return choice

def guided_flash(ui, receipt):
    image = Path(receipt['output'])
    require(image.is_file(), 'Saved image is missing.')
    device = target_picker(ui, image.stat().st_size)
    a = argparse.Namespace(flash=str(image), device=device, image_sha256=receipt['image_sha256'])
    if os.geteuid() == 0:
        flash(a)
    else:
        privileged_script(ui, ['--flash', str(image), '--device', device, '--image-sha256', a.image_sha256])
    ui.say('Card bytes verified. Actual Pi boot and desktop checks remain next.')

def settings_menu(ui):
    choice = ui.choose('Settings (saved for later runs)', [
        ('wifi', 'Configure or remove Wi-Fi'), ('directory', 'Change image storage folder'),
        ('size', 'Change image size'), ('source', 'Image profile: plain Arch / optional GUP'),
        ('inputs', 'Choose rootfs and source bundle again'), ('back', 'Back')])
    if choice == 'wifi':
        action = ui.choose('Networking', [('ethernet', 'Ethernet only'), ('wifi', 'Ethernet plus Wi-Fi')])
        if action == 'ethernet':
            ui.saved.update(wifi_ssid='', wifi_password_file=None)
        else:
            ssid = ui.ask('Wi-Fi name (SSID)', ui.saved.get('wifi_ssid', ''))
            password = getpass.getpass('Wi-Fi password (blank keeps saved password for this SSID): ', stream=ui.tty)
            if not password and ssid == ui.saved.get('wifi_ssid') and ui.saved.get('wifi_password_file'):
                password = private_text(ui.saved['wifi_password_file'])
            wifi_config(ssid, password)
            ui.saved.update(wifi_ssid=ssid, wifi_password_file=ui.private_file('wifi', password))
    elif choice == 'directory':
        ui.saved['image_directory'] = ui.ask('Image folder', str(default_image_directory(ui, ui.saved.get('size_gib', 16))))
    elif choice == 'size':
        ui.saved['size_gib'] = ui.choose('Image size', [(n, f'{n} GiB') for n in [16, 32, 64]])
    elif choice == 'source':
        baseline = ui.choose('Source baseline', [('arch', 'Arch Linux ARM — customized OS, no GUP source required'), ('r6', 'GUP R6 — recovery source baseline'), ('r7', 'GUP R7 — source-tested candidate; runtime still open')])
        if baseline != ui.saved.get('baseline', 'arch'):
            ui.saved.update(baseline=baseline, bundle=None)
    elif choice == 'inputs':
        ui.saved.update(rootfs=None, rootfs_sha256=None, bundle=None)
    ui.save()

def interactive():
    try:
        tty = ControlTerminal()
    except OSError:
        print('Interactive setup needs a terminal. Run the script from a terminal.')
        print('For scripting and advanced options, use --help.')
        return 0
    with tty:
        ui = TerminalUI(tty)
        while True:
            action = None
            try:
                baseline = ui.saved.get('baseline', 'arch').upper()
                options = [('build', 'Create a Pi image — ' + baseline + ' (find inputs, prepare credentials, build)'),
                    ('settings', 'Settings — Wi-Fi, storage, image size, source'), ('quit', 'Exit')]
                if ui.saved.get('last_image'):
                    options.insert(1, ('flash', 'Write the last built image to an SD card'))
                action = ui.choose('ARCH PI / 3LECTRIC GLASS — select an action; Esc cancels', options)
                if action == 'quit':
                    return 0
                if action == 'settings':
                    settings_menu(ui); continue
                if action == 'flash':
                    guided_flash(ui, ui.saved['last_image']); continue
                a = prepared_args(ui)
                ui.say('Validating the build…')
                report = plan(a)
                ui.say(f"New image: {a.output} | {a.size_gib} GiB | {a.baseline.upper()} | Wi-Fi {'on' if a.wifi_ssid else 'off'}")
                ui.say(ui.saved.get('rootfs_trust', 'Rootfs matches its saved pin.'))
                if ui.choose('Ready to create this new image?', [('build', 'Build image'), ('back', 'Back')]) != 'build':
                    continue
                receipt = build(a, guided=True) if os.geteuid() == 0 else privileged_script(ui, build_arguments(a))
                require(receipt and receipt.get('image_sha256'), 'Build returned no accepted image receipt; do not flash.')
                ui.saved['last_image'] = {'output': receipt['output'], 'image_sha256': receipt['image_sha256']}; ui.save()
                ui.say('Image saved. Credentials/settings and checksum are remembered; no commands to assemble.')
                if ui.choose('Next', [('flash', 'Write this image to an SD card'), ('done', 'Keep image file and finish')]) == 'flash':
                    guided_flash(ui, ui.saved['last_image'])
                return 0
            except Cancelled:
                ui.say('Cancelled. Saved setup is retained; no automatic retry.')
                if action is None:
                    return 0
            except (Refusal, OSError, ValueError, tarfile.TarError, subprocess.SubprocessError) as exc:
                ui.say('Stopped: ' + str(exc))
                ui.say('Partial files/evidence are retained. Return to the menu to choose the next action.')

def main(argv=None):
    a = parse(argv)
    if a is None:
        return 0
    if a.interactive:
        return interactive()
    if a.flash:
        flash(a)
    elif a.plan:
        print(json.dumps(plan(a), indent=2))
    else:
        build(a, guided=os.environ.get('GUP_INTERFACE') == 'guided')
    return 0

if __name__ == '__main__':
    try:
        def interrupted(signum, frame):
            raise KeyboardInterrupt()
        signal.signal(signal.SIGTERM, interrupted)
        signal.signal(signal.SIGHUP, interrupted)
        sys.exit(main())
    except KeyboardInterrupt:
        print('\nInterrupted; inspect retained build evidence/device state. No automatic retry.', file=sys.stderr)
        sys.exit(130)
    except (Refusal, OSError, ValueError, tarfile.TarError, subprocess.SubprocessError) as exc:
        print('[REFUSED/FAILED] ' + str(exc), file=sys.stderr)
        sys.exit(1)
PY
