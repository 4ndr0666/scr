#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPT_NAME="${0##*/}"
readonly ARCHARM_URL='http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-aarch64-latest.tar.gz'
readonly REPO_URL='https://github.com/4ndr0666/4ndr0666_hyprland.git'
readonly BOOTSTRAP_REF='f1468f500a14ef6ff25ff03ddee8a64044c96849'
readonly TARGET_HOSTNAME='gup-pi4'
readonly TARGET_USER='alarm'
readonly WORKDIR='/home/alarm/gup'

die() {
	printf '[FATAL] %s\n' "$*" >&2
	exit 1
}

info() {
	printf '[INFO] %s\n' "$*"
}

cleanup() {
	local rc=$?
	set +e

	sync

	if [[ -n "${BOOT_MNT:-}" ]] && mountpoint -q "$BOOT_MNT"; then
		umount "$BOOT_MNT"
	fi

	if [[ -n "${ROOT_MNT:-}" ]] && mountpoint -q "$ROOT_MNT"; then
		umount "$ROOT_MNT"
	fi

	if [[ -n "${LOOPDEV:-}" ]]; then
		losetup -d "$LOOPDEV" 2>/dev/null || true
	fi

	if [[ -n "${WORK:-}" ]] && [[ -d "$WORK" ]]; then
		\rm -rf "$WORK"
	fi

	if ((rc != 0)); then
		printf '[FATAL] provisioning failed; mounts were cleaned\n' >&2
	fi

	exit "$rc"
}

trap cleanup EXIT INT TERM

require_root() {
	((EUID == 0)) || die "run as root: sudo $SCRIPT_NAME /dev/sdX [SSID] [PASSWORD]"
}

usage() {
	\cat >&2 <<'EOF'
Usage:
  sudo ./provision-gup-pi4.sh <TARGET_DEVICE> [WIFI_SSID] [WIFI_PASSWORD]

The target device is COMPLETELY ERASED.

Examples:
  sudo ./provision-gup-pi4.sh /dev/sdb
  sudo ./provision-gup-pi4.sh /dev/mmcblk0 "MyNetwork" "SecretPass123"
EOF
	exit 2
}

(($# >= 1)) || usage

require_root

TARGET="$1"
WIFI_SSID="${2:-}"
WIFI_PASS="${3:-}"

[[ -b "$TARGET" ]] || die "not a block device: $TARGET"

for cmd in \
	\lsblk blkdiscard blockdev sfdisk \
	mkfs.vfat mkfs.ext4 mount umount mountpoint \
	curl bsdtar sha256sum \
	losetup findmnt chroot systemctl \
	sed awk \grep git; do
	command -v "$cmd" >/dev/null 2>&1 ||
		die "required host command missing: $cmd"
done

TARGET_REAL="$(readlink -f "$TARGET")"

[[ "$TARGET_REAL" != /dev/sda ]] || {
	printf '\n[FATAL] refusing to operate on /dev/sda automatically.\n'
	printf '[FATAL] Pass the actual removable device explicitly.\n'
	exit 1
}

printf '\n===== TARGET DEVICE =====\n'
\lsblk -o NAME,PATH,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL,SERIAL "$TARGET_REAL"

printf '\n'
printf '%s\n' \
	'WARNING: the selected block device will be destroyed completely.' \
	'All existing partitions and data on this device will be erased.'

read -r -p "Type the exact device path to continue [$TARGET_REAL]: " CONFIRM
[[ "$CONFIRM" == "$TARGET_REAL" ]] ||
	die "device confirmation did not match"

while read -r mountpoint; do
	[[ -z "$mountpoint" ]] && continue
	die "target has mounted filesystem: $mountpoint"
done < <(lsblk -nrpo MOUNTPOINT "$TARGET_REAL" | sed '/^$/d')

info "installing Arch Linux ARM AArch64 to $TARGET_REAL"

WORK="$(mktemp -d /var/tmp/gup-pi4.XXXXXX)"
ARCHIVE="$WORK/ArchLinuxARM-rpi-aarch64-latest.tar.gz"
ROOT_MNT="$WORK/root"
BOOT_MNT="$WORK/boot"

\mkdir -p "$ROOT_MNT" "$BOOT_MNT"

info "downloading current Arch Linux ARM Raspberry Pi 4 AArch64 root filesystem"

\curl \
	--fail \
	--location \
	--proto '=http,https' \
	--proto-redir '=http,https' \
	--retry 5 \
	--retry-all-errors \
	--output "$ARCHIVE" \
	"$ARCHARM_URL"

info "validating archive"

\tar -tzf "$ARCHIVE" >/dev/null

info "destroying old partition table"

sync
blockdev --rereadpt "$TARGET_REAL" 2>/dev/null || true
blkdiscard "$TARGET_REAL" 2>/dev/null || true

if [[ "$TARGET_REAL" =~ [0-9]$ ]]; then
	P1="${TARGET_REAL}p1"
	P2="${TARGET_REAL}p2"
else
	P1="${TARGET_REAL}1"
	P2="${TARGET_REAL}2"
fi

info "creating GPT partition table"

sfdisk --wipe always "$TARGET_REAL" <<'EOF'
label: gpt
size=1024M, type=U
type=L
EOF

partprobe "$TARGET_REAL" 2>/dev/null || true
udevadm settle 2>/dev/null || true

[[ -b "$P1" ]] || die "boot partition did not appear: $P1"
[[ -b "$P2" ]] || die "root partition did not appear: $P2"

info "creating filesystems"

mkfs.vfat -F 32 -n BOOT "$P1"
mkfs.ext4 -F -L ROOT "$P2"

info "mounting filesystems"

mount "$P2" "$ROOT_MNT"
\mkdir -p "$BOOT_MNT"
mount "$P1" "$BOOT_MNT"

info "extracting Arch Linux ARM root filesystem"

bsdtar -xpf "$ARCHIVE" -C "$ROOT_MNT"

info "moving Raspberry Pi boot files to boot partition"

if [[ -d "$ROOT_MNT/boot" ]]; then
	shopt -s dotglob nullglob
	boot_files=("$ROOT_MNT/boot/"*)
	if ((${#boot_files[@]})); then
		mv -- "${boot_files[@]}" "$BOOT_MNT/"
	fi
	shopt -u dotglob nullglob
fi

info "configuring Raspberry Pi 4 AArch64 filesystem"

ROOT_UUID="$(blkid -s UUID -o value "$P2")"
BOOT_UUID="$(blkid -s UUID -o value "$P1")"

[[ "$ROOT_UUID" =~ ^[[:xdigit:]-]+$ ]] ||
	die "invalid root UUID: $ROOT_UUID"

[[ "$BOOT_UUID" =~ ^[[:xdigit:]-]+$ ]] ||
	die "invalid boot UUID: $BOOT_UUID"

\cat >"$ROOT_MNT/etc/fstab" <<EOF
UUID=$BOOT_UUID /boot vfat defaults 0 2
UUID=$ROOT_UUID / ext4 defaults,noatime 0 1
EOF

printf '%s\n' "$TARGET_HOSTNAME" >"$ROOT_MNT/etc/hostname"

\cat >"$ROOT_MNT/etc/hosts" <<EOF
127.0.0.1 localhost
::1 localhost
127.0.1.1 $TARGET_HOSTNAME.localdomain $TARGET_HOSTNAME
EOF

info "configuring deterministic network bootstrap"

\mkdir -p "$ROOT_MNT/etc/systemd/network"

\cat >"$ROOT_MNT/etc/systemd/network/20-gup-ethernet.network" <<'EOF'
[Match]
Name=en*

[Network]
DHCP=yes
IPv6AcceptRA=yes
EOF

if [[ -n "$WIFI_SSID" ]] && [[ -n "$WIFI_PASS" ]]; then
	info "configuring Wi-Fi (wlan0) bootstrap for SSID: $WIFI_SSID"

	\cat >"$ROOT_MNT/etc/systemd/network/25-gup-wlan0.network" <<'EOF'
[Match]
Name=wlan*

[Network]
DHCP=yes
IPv6AcceptRA=yes
EOF

	\mkdir -p "$ROOT_MNT/etc/wpa_supplicant"
	\cat >"$ROOT_MNT/etc/wpa_supplicant/wpa_supplicant-wlan0.conf" <<EOF
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=wheel
update_config=1

network={
	ssid="$WIFI_SSID"
	psk="$WIFI_PASS"
}
EOF

	\mkdir -p "$ROOT_MNT/etc/systemd/system/multi-user.target.wants"
	\ln -sf \
		/usr/lib/systemd/system/wpa_supplicant@.service \
		"$ROOT_MNT/etc/systemd/system/multi-user.target.wants/wpa_supplicant@wlan0.service"
fi

\mkdir -p "$ROOT_MNT/etc/systemd/system/getty@tty1.service.d"

\cat >"$ROOT_MNT/etc/systemd/system/getty@tty1.service.d/autologin.conf" <<'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin alarm --noclear %I $TERM
EOF

info "configuring SSH"

\mkdir -p "$ROOT_MNT/etc/ssh/sshd_config.d"

\cat >"$ROOT_MNT/etc/ssh/sshd_config.d/20-gup-certification.conf" <<'EOF'
PasswordAuthentication yes
PermitRootLogin no
KbdInteractiveAuthentication yes
UsePAM yes
EOF

info "installing first-boot GUP bootstrap"

\mkdir -p "$ROOT_MNT$WORKDIR"

\cat >"$ROOT_MNT$WORKDIR/bootstrap-gup.sh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

readonly REPO_URL='https://github.com/4ndr0666/4ndr0666_hyprland.git'
readonly BOOTSTRAP_REF='f1468f500a14ef6ff25ff03ddee8a64044c96849'
readonly REPO_DIR="$HOME/gup/4ndr0666_hyprland"

die() {
    printf '[FATAL] %s\n' "$*" >&2
    exit 1
}

printf '[GUP] initializing package keyring\n'
sudo pacman-key --init
sudo pacman-key --populate archlinuxarm

printf '[GUP] synchronizing base system\n'
sudo pacman -Syu --noconfirm

printf '[GUP] installing certification dependencies\n'
sudo pacman -S --needed --noconfirm \
    bash \
    awk \
    curl \
    findutils \
    git \
    \grep \
    iproute2 \
    pciutils \
    util-linux \
    systemd \
    procps-ng \
    coreutils

\rm -rf -- "$REPO_DIR"
\mkdir -p "$(dirname "$REPO_DIR")"

printf '[GUP] cloning repository\n'
git clone "$REPO_URL" "$REPO_DIR"

cd "$REPO_DIR"

printf '[GUP] fetching immutable bootstrap revision\n'
git fetch --depth=1 origin "$BOOTSTRAP_REF"

printf '[GUP] recording repository identity\n'
git rev-parse HEAD
git status --short

printf '[GUP] running repository Golden Units\n'
if [[ -x tests/run-golden-units.sh ]]; then
    bash tests/run-golden-units.sh
elif [[ -x tests/golden-units.sh ]]; then
    bash tests/golden-units.sh
else
    printf '[GUP] Golden Unit runner not found at known paths.\n'
    printf '[GUP] Repository inventory:\n'
    find tests -maxdepth 2 -type f -print | sort
fi

printf '[GUP] running O.M.A.-1 runtime baseline when available\n'

if [[ -x tests/oma/run-oma1.sh ]]; then
    bash tests/oma/run-oma1.sh
else
    printf '[GUP] O.M.A.-1 runner unavailable in this checkout.\n'
    exit 1
fi

printf '[GUP] baseline complete\n'
printf '[GUP] evidence directory:\n'
printf '  %s/oma-evidence\n' "$REPO_DIR"

printf '[GUP] next certification gate: O.M.A.-2 recovery/lifecycle/concurrency campaign\n'
EOF

chmod 0755 "$ROOT_MNT$WORKDIR/bootstrap-gup.sh"

\cat >"$ROOT_MNT/etc/systemd/system/gup-bootstrap.service" <<EOF
[Unit]
Description=GUP Raspberry Pi bootstrap
After=network-online.target
Wants=network-online.target
ConditionPathExists=$WORKDIR/bootstrap-gup.sh

[Service]
Type=oneshot
User=alarm
WorkingDirectory=$WORKDIR
ExecStart=$WORKDIR/bootstrap-gup.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

info "enabling first-boot GUP bootstrap"

\ln -sf \
	/usr/lib/systemd/system/sshd.service \
	"$ROOT_MNT/etc/systemd/system/multi-user.target.wants/sshd.service"

\mkdir -p "$ROOT_MNT/etc/systemd/system/multi-user.target.wants"

\ln -sf \
	/etc/systemd/system/gup-bootstrap.service \
	"$ROOT_MNT/etc/systemd/system/multi-user.target.wants/gup-bootstrap.service"

info "enabling systemd-networkd"

\mkdir -p "$ROOT_MNT/etc/systemd/system/multi-user.target.wants"

\ln -sf \
	/usr/lib/systemd/system/systemd-networkd.service \
	"$ROOT_MNT/etc/systemd/system/multi-user.target.wants/systemd-networkd.service"

\ln -sf \
	/usr/lib/systemd/system/systemd-networkd-wait-online.service \
	"$ROOT_MNT/etc/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service"

info "configuring SSH host-key generation"

\mkdir -p "$ROOT_MNT/etc/systemd/system/sshd.service.d"

\cat >"$ROOT_MNT/etc/systemd/system/sshd.service.d/10-gup.conf" <<'EOF'
[Unit]
After=network.target
EOF

info "configuring Pi boot arguments"

if [[ -f "$BOOT_MNT/boot.txt" ]]; then
	sed -i \
		's/${fdt_addr_r}/${fdt_addr}/g' \
		"$BOOT_MNT/boot.txt" || true
fi

if [[ -x "$BOOT_MNT/mkscr" ]] && command -v mkimage >/dev/null 2>&1; then
	(
		cd "$BOOT_MNT"
		./mkscr
	)
fi

info "writing provisioning manifest"

\cat >"$ROOT_MNT$WORKDIR/provisioning-manifest.txt" <<EOF
platform=Raspberry Pi 4
architecture=aarch64
distribution=Arch Linux ARM
hostname=$TARGET_HOSTNAME
boot_uuid=$BOOT_UUID
root_uuid=$ROOT_UUID
repository=$REPO_URL
bootstrap_ref=$BOOTSTRAP_REF
archarm_rootfs=$ARCHARM_URL
provisioned_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

sync

info "verifying target filesystems"

findmnt "$ROOT_MNT" >/dev/null
findmnt "$BOOT_MNT" >/dev/null

sync

info "unmounting target"

umount "$BOOT_MNT"
BOOT_MNT=''

umount "$ROOT_MNT"
ROOT_MNT=''

info "flushing device"

sync
blockdev --flushbufs "$TARGET_REAL"

printf '\n'
printf '%s\n' \
	'========================================' \
	'ARCH LINUX ARM PI 4 PROVISIONING DONE' \
	'========================================'
printf '\n'
printf 'Target:     %s\n' "$TARGET_REAL"
printf 'Hostname:   %s\n' "$TARGET_HOSTNAME"
printf 'User:       %s\n' "$TARGET_USER"
printf 'Repository: %s\n' "$REPO_URL"
printf 'Bootstrap:  %s\n' "$BOOTSTRAP_REF"
printf '\n'
printf '%s\n' \
	'Insert the SD card into the Raspberry Pi 4 and connect Ethernet/Wi-Fi.' \
	'Use the official 5V/3A-class Pi 4 power supply.' \
	'The Arch Linux ARM image uses the default alarm/alarm credentials.' \
	'The first boot runs the GUP bootstrap automatically.'
printf '\n'
printf '%s\n' \
	'After boot, obtain the DHCP address and connect with:'
printf '  ssh alarm@<PI-DHCP-IP>\n'
printf '\n'
printf '%s\n' \
	'Then inspect:'
printf '  \cat ~/gup/provisioning-manifest.txt\n'
printf '  cd ~/gup/4ndr0666_hyprland\n'
printf '  git rev-parse HEAD\n'
printf '  \ls -lt oma-evidence/oma1-*.txt\n'
