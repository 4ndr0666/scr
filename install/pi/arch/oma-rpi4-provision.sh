#!/usr/bin/env bash
set -Eeuo pipefail

###############################################################################
# GUP / O.M.A. Raspberry Pi 4 Recovery-Machine Provisioner
#
# PURPOSE
#   Build a disposable Arch Linux ARM AArch64 Raspberry Pi 4 machine suitable
#   for O.M.A.-2 recovery/lifecycle/concurrency testing.
#
# HOST
#   Arch Linux / compatible Linux workstation.
#
# TARGET
#   Raspberry Pi 4 + dedicated microSD card + Ethernet.
#
# SAFETY
#   The supplied block device is COMPLETELY DESTROYED.
#   The script requires exact device-path confirmation.
#
# IMPORTANT
#   This script does NOT perform destructive O.M.A.-2 fault injection.
#   It provisions and certifies the recovery machine so the later O.M.A.-2
#   destructive tranche can be run against the disposable target.
###############################################################################

readonly SCRIPT_NAME="${0##*/}"
readonly ROOTFS_URL="https://os.archlinuxarm.org/os/ArchLinuxARM-rpi-aarch64-latest.tar.gz"
readonly ROOTFS_SIG_URL="${ROOTFS_URL}.sig"
readonly WORK_ROOT="/var/tmp/gup-oma-rpi4"
readonly ROOTFS_ARCHIVE="${WORK_ROOT}/ArchLinuxARM-rpi-aarch64-latest.tar.gz"
readonly ROOTFS_SIG="${ROOTFS_ARCHIVE}.sig"
readonly ROOT_MNT="${WORK_ROOT}/root"
readonly BOOT_MNT="${WORK_ROOT}/boot"

readonly TEST_USER="oma"
readonly TEST_HOSTNAME="oma-rpi4"
readonly TEST_PASSWORD="oma"

REPO_URL="https://github.com/4ndr0666/4ndr0666_hyprland.git"
REPO_DIR="/opt/4ndr0666_hyprland"

DEVICE=""
REAL_DEVICE=""
BOOT_DEV=""
ROOT_DEV=""
PI_IP=""

log() {
    printf '[OMA-RPI4] %s\n' "$*"
}

fail() {
    printf '[OMA-RPI4][FATAL] %s\n' "$*" >&2
    exit 1
}

cleanup() {
    set +e

    sync

    mountpoint -q "${BOOT_MNT}" && umount "${BOOT_MNT}"
    mountpoint -q "${ROOT_MNT}" && umount "${ROOT_MNT}"

    rm -rf -- "${WORK_ROOT}"
}

trap cleanup EXIT
trap 'fail "command failed at line ${LINENO}: ${BASH_COMMAND}"' ERR

usage() {
    cat <<EOF
Usage:
  sudo ${SCRIPT_NAME} /dev/<sd-card>

Example:
  sudo ${SCRIPT_NAME} /dev/sdb

Prefer a stable /dev/disk/by-id path when available:

  sudo ${SCRIPT_NAME} /dev/disk/by-id/usb-...

WARNING:
  The target device will be completely erased.
EOF
    exit 2
}

require_root() {
    [[ $EUID -eq 0 ]] || fail "run this script as root"
}

require_args() {
    [[ $# -eq 1 ]] || usage
    DEVICE="$1"

    [[ -b "${DEVICE}" ]] ||
        fail "target is not a block device: ${DEVICE}"

    REAL_DEVICE="$(readlink -f -- "${DEVICE}")"

    [[ -b "${REAL_DEVICE}" ]] ||
        fail "resolved target is not a block device: ${REAL_DEVICE}"
}

show_target() {
    printf '\n'
    printf '============================================================\n'
    printf ' DESTRUCTIVE TARGET VERIFICATION\n'
    printf '============================================================\n'
    printf 'Requested: %s\n' "${DEVICE}"
    printf 'Resolved:  %s\n' "${REAL_DEVICE}"
    printf '\n'

    lsblk -o \
        NAME,PATH,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS,MODEL,SERIAL \
        "${REAL_DEVICE}"

    printf '\n'
    printf 'ALL DATA ON THIS DEVICE WILL BE DESTROYED.\n'
    printf '\n'
    printf 'Type the EXACT resolved device path to continue:\n'
    printf '> '

    local confirmation
    read -r confirmation

    [[ "${confirmation}" == "${REAL_DEVICE}" ]] ||
        fail "target confirmation mismatch"

    printf '\n'
    printf 'Type ERASE-OMA-RPI4 to authorize the destructive provisioning:\n'
    printf '> '

    read -r confirmation

    [[ "${confirmation}" == "ERASE-OMA-RPI4" ]] ||
        fail "destructive-operation authorization mismatch"
}

install_host_dependencies() {
    log "installing host dependencies"

    pacman -S --needed --noconfirm \
        arch-install-scripts \
        bsdtar \
        curl \
        dosfstools \
        e2fsprogs \
        gawk \
        git \
        gptfdisk \
        iproute2 \
        openssh \
        parted \
        rsync \
        util-linux
}

prepare_workspace() {
    log "creating clean workspace"

    rm -rf -- "${WORK_ROOT}"

    mkdir -p \
        "${ROOT_MNT}" \
        "${BOOT_MNT}"
}

download_rootfs() {
    log "downloading official Arch Linux ARM RPi3/RPi4 AArch64 rootfs"

    curl \
        --fail \
        --location \
        --retry 5 \
        --retry-delay 2 \
        --output "${ROOTFS_ARCHIVE}" \
        "${ROOTFS_URL}"

    curl \
        --fail \
        --location \
        --retry 5 \
        --retry-delay 2 \
        --output "${ROOTFS_SIG}" \
        "${ROOTFS_SIG_URL}" || {
            log "detached signature unavailable from current mirror; continuing"
        }
}

unmount_target_partitions() {
    log "unmounting existing target partitions"

    while read -r partition; do
        [[ -n "${partition}" ]] || continue
        umount "${partition}" 2>/dev/null || true
    done < <(
        lsblk -nrpo NAME,TYPE "${REAL_DEVICE}" |
            awk '$2 == "part" { print $1 }'
    )
}

partition_target() {
    log "destroying existing partition table"

    wipefs --all --force "${REAL_DEVICE}"

    log "creating Raspberry Pi boot/root partitions"

    parted --script "${REAL_DEVICE}" \
        mklabel msdos \
        mkpart primary fat32 1MiB 1025MiB \
        set 1 boot on \
        mkpart primary ext4 1025MiB 100%

    partprobe "${REAL_DEVICE}"
    udevadm settle

    case "${REAL_DEVICE}" in
        /dev/nvme*|/dev/mmcblk*)
            BOOT_DEV="${REAL_DEVICE}p1"
            ROOT_DEV="${REAL_DEVICE}p2"
            ;;
        *)
            BOOT_DEV="${REAL_DEVICE}1"
            ROOT_DEV="${REAL_DEVICE}2"
            ;;
    esac

    [[ -b "${BOOT_DEV}" ]] ||
        fail "boot partition missing: ${BOOT_DEV}"

    [[ -b "${ROOT_DEV}" ]] ||
        fail "root partition missing: ${ROOT_DEV}"
}

format_target() {
    log "formatting boot partition"

    mkfs.vfat \
        -F 32 \
        -n BOOT \
        "${BOOT_DEV}"

    log "formatting root partition"

    mkfs.ext4 \
        -F \
        -L ARCHROOT \
        "${ROOT_DEV}"
}

mount_target() {
    log "mounting target filesystems"

    mount "${ROOT_DEV}" "${ROOT_MNT}"

    mkdir -p "${ROOT_MNT}/boot"

    mount "${BOOT_DEV}" "${BOOT_MNT}"
}

install_rootfs() {
    log "extracting Arch Linux ARM root filesystem"

    bsdtar \
        -xpf "${ROOTFS_ARCHIVE}" \
        -C "${ROOT_MNT}"

    sync
}

install_boot_files() {
    log "moving boot files onto FAT boot partition"

    find "${ROOT_MNT}/boot" \
        -mindepth 1 \
        -maxdepth 1 \
        -exec mv -t "${BOOT_MNT}" -- {} +

    sync
}

configure_fstab() {
    log "applying Raspberry Pi 4 AArch64 fstab device correction"

    sed -i \
        's/mmcblk0/mmcblk1/g' \
        "${ROOT_MNT}/etc/fstab"
}

configure_identity() {
    log "configuring machine identity"

    printf '%s\n' "${TEST_HOSTNAME}" \
        > "${ROOT_MNT}/etc/hostname"

    cat > "${ROOT_MNT}/etc/hosts" <<EOF
127.0.0.1 localhost
::1       localhost
127.0.1.1 ${TEST_HOSTNAME}.localdomain ${TEST_HOSTNAME}
EOF

    rm -f \
        "${ROOT_MNT}/etc/machine-id" \
        "${ROOT_MNT}/etc/ssh/ssh_host_"*
}

configure_network() {
    log "configuring DHCP networking"

    mkdir -p "${ROOT_MNT}/etc/systemd/network"

    cat > "${ROOT_MNT}/etc/systemd/network/20-oma-ethernet.network" <<'EOF'
[Match]
Name=end* eth*

[Network]
DHCP=yes
IPv6AcceptRA=yes
EOF

    mkdir -p "${ROOT_MNT}/etc/systemd/system/multi-user.target.wants"

    ln -sf \
        /usr/lib/systemd/system/systemd-networkd.service \
        "${ROOT_MNT}/etc/systemd/system/multi-user.target.wants/systemd-networkd.service"

    ln -sf \
        /usr/lib/systemd/system/systemd-resolved.service \
        "${ROOT_MNT}/etc/systemd/system/multi-user.target.wants/systemd-resolved.service"

    rm -f "${ROOT_MNT}/etc/resolv.conf"

    ln -sf \
        /run/systemd/resolve/stub-resolv.conf \
        "${ROOT_MNT}/etc/resolv.conf"
}

configure_ssh() {
    log "enabling SSH"

    mkdir -p \
        "${ROOT_MNT}/etc/systemd/system/multi-user.target.wants"

    ln -sf \
        /usr/lib/systemd/system/sshd.service \
        "${ROOT_MNT}/etc/systemd/system/multi-user.target.wants/sshd.service"

    mkdir -p "${ROOT_MNT}/etc/ssh"

    rm -f "${ROOT_MNT}/etc/ssh/ssh_host_"*
}

configure_test_account() {
    log "creating disposable O.M.A. operator account in target rootfs"

    arch-chroot "${ROOT_MNT}" /bin/bash -s -- \
        "${TEST_USER}" \
        "${TEST_PASSWORD}" <<'CHROOT_SCRIPT'
set -Eeuo pipefail

user="$1"
password="$2"

if ! id "${user}" >/dev/null 2>&1; then
    useradd \
        --create-home \
        --shell /bin/bash \
        "${user}"
fi

printf '%s:%s\n' "${user}" "${password}" | chpasswd

usermod -aG wheel "${user}"

if ! grep -Eq '^[[:space:]]*%wheel[[:space:]]+ALL=\(ALL:ALL\)[[:space:]]+ALL' /etc/sudoers; then
    printf '%%wheel ALL=(ALL:ALL) ALL\n' > /etc/sudoers.d/99-oma-wheel
    chmod 0440 /etc/sudoers.d/99-oma-wheel
fi
CHROOT_SCRIPT
}

configure_pacman() {
    log "preparing pacman configuration"

    mkdir -p "${ROOT_MNT}/etc/pacman.d"

    if grep -q '^#Color' "${ROOT_MNT}/etc/pacman.conf"; then
        sed -i 's/^#Color/Color/' "${ROOT_MNT}/etc/pacman.conf"
    fi
}

create_boot_marker() {
    cat > "${ROOT_MNT}/etc/oma-provisioned" <<EOF
provisioner=gup-oma-rpi4
target=${REAL_DEVICE}
hostname=${TEST_HOSTNAME}
architecture=aarch64
rootfs=${ROOTFS_URL}
repository=${REPO_URL}
repository_path=${REPO_DIR}
oma_role=disposable-recovery-machine
destructive_fault_injection=operator-gated
EOF
}

sync_target() {
    log "syncing target"

    sync
}

unmount_target() {
    log "unmounting target"

    sync

    umount "${BOOT_MNT}"
    umount "${ROOT_MNT}"

    sync

    blockdev --flushbufs "${REAL_DEVICE}" 2>/dev/null || true
}

wait_for_pi() {
    log "waiting for Raspberry Pi DHCP lease"

    printf '\n'
    printf 'Insert the SD card into the Raspberry Pi 4.\n'
    printf 'Connect Ethernet.\n'
    printf 'Use a proper 5V/3A Raspberry Pi power supply.\n'
    printf 'Power the Pi on.\n'
    printf '\n'
    printf 'The script will inspect the local ARP/neighbour table.\n'
    printf 'If automatic discovery fails, enter the Pi IP manually.\n'
    printf '\n'

    for _ in {1..30}; do
        ip neigh show 2>/dev/null |
            awk '$NF == "REACHABLE" || $NF == "STALE" || $NF == "DELAY" {
                print $1
            }' |
            while read -r candidate; do
                [[ -n "${candidate}" ]] || continue

                if timeout 1 bash -c \
                    "printf '' >/dev/tcp/${candidate}/22" \
                    2>/dev/null; then
                    printf '%s\n' "${candidate}"
                fi
            done |
            head -n1 > "${WORK_ROOT}/pi-ip" || true

        if [[ -s "${WORK_ROOT}/pi-ip" ]]; then
            PI_IP="$(cat "${WORK_ROOT}/pi-ip")"
            break
        fi

        sleep 2
    done

    if [[ -z "${PI_IP}" ]]; then
        printf 'Enter the Raspberry Pi IP address: '
        read -r PI_IP
    fi

    [[ "${PI_IP}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
        fail "invalid Raspberry Pi IPv4 address: ${PI_IP}"

    log "Pi candidate address: ${PI_IP}"
}

wait_for_ssh() {
    log "waiting for SSH on ${PI_IP}"

    for _ in {1..60}; do
        if timeout 2 bash -c \
            "printf '' >/dev/tcp/${PI_IP}/22" \
            2>/dev/null; then
            return 0
        fi

        sleep 2
    done

    fail "SSH did not become reachable at ${PI_IP}:22"
}

ssh_pi() {
    ssh \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=10 \
        "${TEST_USER}@${PI_IP}" \
        "$@"
}

bootstrap_pi() {
    log "performing first-boot Arch Linux ARM initialization"

    ssh_pi /bin/bash -s <<EOF
set -Eeuo pipefail

printf '%s\n' '${TEST_PASSWORD}' | sudo -S true

sudo -S /bin/bash -c '
set -Eeuo pipefail

pacman-key --init
pacman-key --populate archlinuxarm

pacman -Syu --noconfirm

pacman -S --needed --noconfirm \
    archlinuxarm-keyring \
    base-devel \
    git \
    openssh \
    rsync \
    sudo \
    tmux

systemctl enable sshd.service
systemctl restart sshd.service

passwd -l root

install -d -m 0755 /opt

if [[ ! -d "${REPO_DIR}/.git" ]]; then
    git clone "${REPO_URL}" "${REPO_DIR}"
else
    git -C "${REPO_DIR}" fetch --all --prune
    git -C "${REPO_DIR}" checkout main
    git -C "${REPO_DIR}" pull --ff-only
fi

chown -R root:root "${REPO_DIR}"

printf "%s\n" "FIRST_BOOT_COMPLETE" > /etc/oma-first-boot-complete
'
EOF
}

run_gup_suite() {
    log "running GUP Golden Units"

    ssh_pi /bin/bash -s <<EOF
set -Eeuo pipefail

cd "${REPO_DIR}"

printf '\n===== GIT STATE =====\n'
git status --short
git log -5 --oneline --decorate

printf '\n===== GOLDEN UNITS =====\n'
bash tests/unit/run-golden-units.sh

printf '\n===== O.M.A. INVENTORY =====\n'
bash tests/oma/run-oma.sh --inventory

printf '\n===== INSTALLER VERIFICATION =====\n'
bash tests/oma/run-oma.sh --verify

printf '\n===== O.M.A.-1 =====\n'
bash tests/oma/run-oma1.sh
EOF
}

capture_pi_state() {
    log "capturing recovery-machine baseline"

    local evidence_dir="${WORK_ROOT}/evidence"

    mkdir -p "${evidence_dir}"

    ssh_pi /bin/bash -s > "${evidence_dir}/pi-baseline.txt" <<EOF
set -Eeuo pipefail

printf '%s\n' '===== MACHINE ====='
hostnamectl || true
uname -a
cat /etc/os-release

printf '%s\n' '===== ARCHITECTURE ====='
uname -m
lscpu

printf '%s\n' '===== STORAGE ====='
lsblk -f
findmnt

printf '%s\n' '===== NETWORK ====='
ip -br addr
ip route

printf '%s\n' '===== SYSTEMD ====='
systemctl is-system-running
systemctl --failed --no-pager || true

printf '%s\n' '===== SSH ====='
systemctl status sshd.service --no-pager -l

printf '%s\n' '===== REPOSITORY ====='
cd "${REPO_DIR}"
git rev-parse HEAD
git status --short

printf '%s\n' '===== GOLDEN UNITS ====='
bash tests/unit/run-golden-units.sh

printf '%s\n' '===== OMA-1 ====='
bash tests/oma/run-oma1.sh

printf '%s\n' '===== OMA-2 STATUS ====='
printf '%s\n' 'RECOVERY_MACHINE_PROVISIONED=PASS'
printf '%s\n' 'DESTRUCTIVE_FAULT_INJECTION=NOT_RUN'
EOF

    sha256sum \
        "${evidence_dir}/pi-baseline.txt" \
        > "${evidence_dir}/pi-baseline.txt.sha256"

    log "local recovery-machine evidence:"
    printf '%s\n' "${evidence_dir}/pi-baseline.txt"
    printf '%s\n' "${evidence_dir}/pi-baseline.txt.sha256"
}

print_final_state() {
    printf '\n'
    printf '================================================================\n'
    printf ' O.M.A.-2 RECOVERY MACHINE PROVISIONING COMPLETE\n'
    printf '================================================================\n'
    printf '\n'
    printf 'Machine:       %s\n' "${TEST_HOSTNAME}"
    printf 'Architecture:  AArch64\n'
    printf 'IP address:    %s\n' "${PI_IP}"
    printf 'SSH user:      %s\n' "${TEST_USER}"
    printf 'Repository:    %s\n' "${REPO_DIR}"
    printf '\n'
    printf 'Completed:\n'
    printf '  [PASS] Arch Linux ARM installation\n'
    printf '  [PASS] Raspberry Pi 4 AArch64 configuration\n'
    printf '  [PASS] Ethernet/SSH provisioning\n'
    printf '  [PASS] GUP repository checkout\n'
    printf '  [PASS] Golden Unit suite\n'
    printf '  [PASS] O.M.A. inventory/verification\n'
    printf '  [PASS] O.M.A.-1 baseline\n'
    printf '  [PASS] recovery-machine evidence\n'
    printf '\n'
    printf 'NOT EXECUTED:\n'
    printf '  [GATED] destructive fault injection\n'
    printf '  [GATED] package transaction interruption\n'
    printf '  [GATED] filesystem interruption\n'
    printf '  [GATED] power-loss testing\n'
    printf '  [GATED] rollback/destructive recovery\n'
    printf '\n'
    printf 'Pi SSH endpoint:\n'
    printf '  ssh %s@%s\n' "${TEST_USER}" "${PI_IP}"
    printf '\n'
    printf 'The Pi is now the disposable O.M.A.-2 recovery target.\n'
}

main() {
    require_root
    require_args "$@"
    show_target

    install_host_dependencies
    prepare_workspace
    download_rootfs
    unmount_target_partitions
    partition_target
    format_target
    mount_target
    install_rootfs
    install_boot_files
    configure_fstab
    configure_identity
    configure_network
    configure_ssh
    configure_test_account
    configure_pacman
    create_boot_marker
    sync_target
    unmount_target

    wait_for_pi
    wait_for_ssh
    bootstrap_pi
    run_gup_suite
    capture_pi_state

    print_final_state
}

main "$@"
