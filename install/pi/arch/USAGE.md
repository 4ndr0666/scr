# GUP Pi4 provisioning v2

This single executable builds a **new image file** from a pinned local rootfs and
an offline source bundle. Physical-card flashing is a separate operation. It is
a fresh OS/source foundation, not a restore of your old home/configuration or a
ready-to-use Hyprland desktop. Keep your original recovery image and artifacts.

The script defaults to the previously verified **R6 source baseline**, commit
`8dbe1e8219c45a4bd00c26425e4867da901e88eb`, tree
`ec8e797f4387db48c3c6669ed1d83f2d08b41a0b`. `--baseline r7` is explicit and
requires a full bundle advertising the reviewed candidate
`5f97fdf336142241ebe5641db1c74ce2f907105b`. Neither choice certifies the new
OS/firmware or restores a previous package set. The former R6 runtime evidence
is historical following the reported Pi OS corruption; its cause is unknown.

## Inputs and host requirements

- Linux host (your Arch computer), Bash, Python3.9+ with standard library, Git,
  OpenSSH tools. No dependencies are installed by this script.
- Build additionally needs root, loop-device/partition support, util-linux tools
  (`sfdisk`, `losetup`, `mount`, `umount`, `blkid`), `udevadm`, `dosfstools`,
  `e2fsprogs`, `bsdtar`/libarchive, and coreutils `sync`.
- U-Boot rootfs layouts containing `boot.txt` also need host `mkimage`
  (`uboot-tools`). Rootfs-provided `mkscr` is never executed on the host.
- Flash additionally needs `lsblk`, `swapon`, `wipefs`, `blockdev`, and a TTY.
- Local official Raspberry Pi AArch64 rootfs tarball and an expected SHA256 from
  a trusted source. Hash equality is integrity against your pin, **not vendor
  authenticity by itself**. No HTTP/HTTPS download or implicit `latest` lookup
  occurs. A generic PC/other-board rootfs is not interchangeable.
- Full, self-contained source bundle. The supplied `gup-source-r6.bundle` contains
  R6 main and its complete reachable history; it is not all Pi refs, stash/WIP,
  user files or a complete OS backup. Original full captures remain preserved.
- OpenSSH public key, and a private0600 file containing the alarm password hash.
  SSH uses public-key authentication; local login/sudo uses the chosen password.
  If the rootfs lacks sudo, additionally supply a **different** local root
  password hash for console/`su` recovery. Root SSH stays disabled.

The host and target CPU architectures can differ: there is no target chroot or
QEMU. ELF inspection checks the rootfs Bash is AArch64; that and boot-layout
checks do not prove that firmware/kernel/modules/DTBs work on a Pi4.

## Prepare private credentials

Use existing public-key material. Never supply a private SSH key. To create
password hashes interactively without putting passwords in process arguments:

```bash
umask 077
openssl passwd -6 > alarm.password.hash
openssl passwd -6 > root.password.hash
```

Choose distinct passwords. The second file is optional when sudo is already in
the rootfs. Do not use the old `alarm/alarm` or `root/root` defaults. Wi-Fi is
optional; `--wifi-ssid` and `--wifi-password-file` must be supplied together.
The password file must be0600; plaintext is not placed in argv or build logs.
The generated wpa config uses hexadecimal SSID and a derived/raw PSK, mode0600.
An image still contains credentials and must be stored privately.

## Inspect and plan first

```bash
bash ./provision-gup-pi4.sh --help
mkdir -p /sto2/gup-images
read -r -p 'Expected trusted rootfs SHA256: ' ROOTFS_SHA256
bash ./provision-gup-pi4.sh --plan \
  --rootfs ./ArchLinuxARM-rpi-aarch64-latest.tar.gz \
  --rootfs-sha256 "$ROOTFS_SHA256" \
  --bundle ./gup-source-r6.bundle \
  --ssh-key "$HOME/.ssh/id_ed25519.pub" \
  --password-hash-file ./alarm.password.hash \
  --root-password-hash-file ./root.password.hash \
  --output /sto2/gup-images/gup-pi4-r6.img
```

These are concrete layout examples; input filenames must identify your downloaded
files. The hash must be supplied rather than guessed. `--plan` reads inputs and
runs public-key validation, but creates no images, mounts, partitions or files.
It verifies archive paths/architecture, hash equality, input permissions, full
bundle header/no prerequisites, expected advertised commit, output absence and
capacity. **Bundle object integrity/tree validation occurs during build**, not
merely from its header. Plan success is not build/boot certification.

The default image is16GiB, with1GiB FAT boot and the remainder ext4, using a DOS
partition table for conventional Pi firmware compatibility. Change `--size-gib`
explicitly if needed. The destination must have capacity for the full logical
image plus512MiB headroom even though the file starts sparse. Existing image
files are refused. Fresh filesystem creation, timestamps and UUIDs mean repeated
builds are **not byte-reproducible**; each successful artifact gets its own hash.

## Build, then inspect the image

After reviewing the plan, repeat the same invocation with `sudo bash` and
`--build` in place of `--plan`. Expand the public-key path as your normal user
before sudo; do not accidentally substitute root's key. Build only on a host
where you intend to authorize loop-device and mount operations.

Only the new sparse image receives partitioning/formatting. The builder does not
accept a physical block target in build mode. It extracts boot files directly
into the mounted boot partition, writes PARTUUID fstab/root arguments, clones to
a new target checkout, checks out the exact commit, verifies its tree and runs
strict full Git fsck. It does not fetch the moving public branch or delete an
existing checkout. New SSH host keys and machine identity are generated on boot.

A private `.gup-pi4-build.*` directory next to the output retains command argv,
stdin where used, exits, stdout/stderr with hashes, image manifest and checksum.
Successful publication refuses concurrent existing output. On failures, partial
images/evidence remain for diagnosis. Cleanup unmounts boot then root and detaches
only a loop with no remaining mounts. Failed cleanup is an error; it does not
delete an underlying mounted tree or report success. Inspect recorded resources
before any manual cleanup. SIGINT/TERM/HUP unwind; SIGKILL/power loss cannot.

No real build/loop/filesystem integration test has run in the current workspace;
see `AUDIT.md` for validation limits. First build/test a spare card and retain
your existing recovery image. Do not replace your only known-good image/card.

## Physical flashing is explicit and destructive

After verifying the image manifest and identifying a spare card on the host,
invoke `--flash IMAGE --image-sha256 HASH --device DEVICE` with sudo. Never copy
the Pi's old `/dev/mmcblk0` name onto another computer without identifying it.
No generic device-name example is supplied for automatic copy/paste.

The script refuses partitions, loops/mappers, read-only or undersized disks,
mounted descendants, active mapped consumers, and active swap. It displays the
device inventory/serial/model and requires `ERASE /actual/device` through the
controlling TTY. It checks state again, wipes stale signatures, writes the image,
flushes/invalidates Linux block cache, and hashes an exact-length device readback.
It records a private flash report. It never force-unmounts, discards, retries
failed writes or bypasses signature/dependency checks. Close automounters/other
programs touching the card; physical hotplug/namespace races are not fully
testable here. An interrupted/failed flash leaves that card unaccepted.

Readback equality is not proof of bootability or long-term card health. On a
larger card, root remains the image-sized partition; automatic expansion is not
enabled. Resize only through a separately reviewed operation. Card health,
adequate power and actual Pi boot must be tested on hardware.

## First boot and GUP acceptance

Default first boot performs local keyring initialization and package/OS inventory
only. It records failures under `/var/lib/gup-firstboot`, and marks success only
after all local steps complete. It does **not** auto-upgrade, run the desktop
installer, run graphical OMA in a headless service, or claim GUP certification.
TTY autologin is off unless `--autologin` was explicitly chosen.

Ethernet uses `en* eth*`; optional Wi-Fi uses `wlan0` with wpa_supplicant.
networkd/resolved are enabled in the new image. There is no NetworkManager
service switch. Existing vendor network configuration/hardware naming must be
checked on the Pi; the NetworkManager launcher still needs a separately approved
backend integration design. No claim of functional network-launcher readiness.

After successful boot, inspect:

```bash
systemctl status gup-firstboot.service --no-pager
journalctl -u gup-firstboot.service --no-pager
cat /etc/gup-provisioning.json
```

When an upgrade is explicitly approved, `gup-upgrade-base --apply` as root
performs one interactive full `pacman -Syu --needed` transaction including base
GUP tools, Python, GI/libnm and sudo. Without `--apply` it refuses. With sudo
available: `sudo gup-upgrade-base --apply`; otherwise use the configured local
root password through `su -`. It saves the real pacman exit/log checksum and
never reboots, retries a failed transaction or substitutes a partial upgrade.
This is base tooling, **not all62 canonical desktop packages**, a package-version
lock or a remedy for the unknown cause of the previous OS failure. Review the
refreshed package proposal before confirming.

Run `gup-validate-source` as alarm for the actual
`tests/unit/run-golden-units.sh` gate after dependencies are ready. Deployment of
Hyprland/user configuration remains separately authorized. Only in the resulting
live user graphical session run `gup-runtime-check`; it uses the repository's
graphical certification packet and records blocked/failing readiness as such.
OMA safe success alone is not whole-project certification. Preserve all logs,
actual installed versions, visible behavior and source pins for GUP closure.
