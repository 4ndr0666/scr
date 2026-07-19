#!/usr/bin/env bash
# 4ndr0666
# ==============================================================================
# 4MLinux -> Raspberry Pi 4 (AArch64) Image Builder - Golden Unit v5 (Rootless)
# ==============================================================================
#
# DESIGN CONTRACT
#   Host layer  : parse_args, detect_runtime, build_builder_image,
#                 populate_source_cache, run_build_in_container, main.
#                 Mutates only OUTPUT_DIR (final artifacts) and CACHEDIR
#                 (source mirrors). Never touches host build tools.
#                 Requires zero loop devices, mounts, or root permissions.
#
#   Source cache: git --mirror clones (bare repos, never checked out on host).
#                 SHA-256-verified archives.
#                 --local-linux / --local-firmware seed from a local repo;
#                 network clone is tried first and local path is the fallback.
#
#   Container   : All compilation, staging, and user-space filesystem packaging.
#                 Runs without loop mounts, losetup, or host root privileges.
#                 Inner script injected as a temp file bind-mounted read-only.
#                 Removed on exit (--rm). Only WORKDIR/output persists.
#
#   Staging     : All rootfs/boot content accumulates in staging directories.
#                 Filesystem images are built and populated in user-space
#                 via mtools (for FAT32) and mkfs.ext4 -d (for ext4 rootfs).
#
#   Parallelism : kernel, busybox, and firmware_stage run concurrently;
#                 monitored via a fail-fast wait -n loop.
#
#   ccache      : CACHEDIR/ccache bind-mounted rw; CC/CXX wrapped.
# ==============================================================================
set -Eeuo pipefail
export LC_ALL=C LANG=C
umask 0022

# ── Outer globals ─────────────────────────────────────────────────────────────
readonly SCRIPT_NAME="$(basename "$0")"
readonly BUILD_START_EPOCH="$(date +%s)"
readonly BUILDER_TAG="4mlinux-pi-builder:latest"

# ── Pinned source coordinates ─────────────────────────────────────────────────
# Replace "HEAD" with full commit SHAs for reproducible builds.
readonly KERNEL_SHA="HEAD"
readonly FIRMWARE_SHA="HEAD"
readonly BUSYBOX_VERSION="1.36.1"
readonly BUSYBOX_SHA256="b8cc24c9574d809e7279c3be349795c5d5ceb6fdf19ca709f80cde50e47de314"

# ── 4MLinux ISO URLs (x86_64 reference — not used in RPi4 AArch64 build) ──────
readonly FOURM_LIVECD_URL="https://sourceforge.net/projects/linux4m/files/52.0/livecd/4MLinux-52.0-64bit.iso/download"
readonly FOURM_NETINSTALL_URL="https://sourceforge.net/projects/linux4m/files/net-install/net-install.iso/download"

# ── Paths ─────────────────────────────────────────────────────────────────────
WORKDIR="$(pwd)/build_workspace"
CACHEDIR="${WORKDIR}/cache"
OUTPUT_DIR="${WORKDIR}/output"

# ── Kernel / firmware remotes ─────────────────────────────────────────────────
KERNEL_BRANCH="rpi-6.1.y"
FIRMWARE_BRANCH="stable"
KERNEL_REPO="https://github.com/raspberrypi/linux.git"
FIRMWARE_REPO="https://github.com/raspberrypi/firmware.git"

# ── CLI options ───────────────────────────────────────────────────────────────
LOCAL_LINUX=""
LOCAL_FIRMWARE=""
SIGN_ARTIFACTS=0
CORES="$(nproc)"
CONTAINER_RT=""
_outer_done=0
DOWNLOAD_4M_LIVECD=0     # --fetch-4mlinux-iso: also download the 4MLinux livecd
DOWNLOAD_4M_NETINSTALL=0 # --fetch-net-install: also download the net-install ISO

# ── Shared utilities ──────────────────────────────────────────────────────────
log() { printf '[*] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }
fatal() {
  printf '[X] %s\n' "$*" >&2
  exit 1
}

# run SECONDS CMD [ARGS…] — hard wall-clock timeout on every external call
run() {
  local seconds="$1"
  shift
  timeout --foreground "$seconds" "$@"
}

# ── _outer_cleanup ────────────────────────────────────────────────────────────
# Outer trap handles only the temp inner-script file.
# Container is --rm; loop devices are not used at all in v5.
# Captures $? BEFORE 'local' to avoid the bash local-rc=0 trap.
_outer_cleanup() {
  local rc=$? # must be first line; 'local' itself would overwrite $?
  set +e
  [[ "${_outer_done}" -eq 1 ]] && exit "$rc"
  _outer_done=1
  [[ -n "${_INNER_SCRIPT:-}" ]] && rm -f "${_INNER_SCRIPT}"
  exit "$rc"
}
trap _outer_cleanup EXIT INT TERM

# ── parse_args ────────────────────────────────────────────────────────────────
# No LBYL validation of local paths here — _mirror_git_repo handles that
# with EAFP semantics and a clear fatal message.
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --local-linux)
        LOCAL_LINUX="$2"
        shift 2
        ;;
      --local-firmware)
        LOCAL_FIRMWARE="$2"
        shift 2
        ;;
      --sign)
        SIGN_ARTIFACTS=1
        shift
        ;;
      --jobs)
        CORES="$2"
        shift 2
        ;;
      --workdir)
        WORKDIR="$2"
        shift 2
        ;;
      --fetch-4mlinux-iso)
        DOWNLOAD_4M_LIVECD=1
        shift
        ;;
      --fetch-net-install)
        DOWNLOAD_4M_NETINSTALL=1
        shift
        ;;
      --help | -h)
        cat <<USAGE
Usage: ${SCRIPT_NAME} [OPTIONS]

--local-linux PATH    Local linux.git bare mirror, checkout, or source directory
                      (fallback if network clone fails; tried first if provided).
--local-firmware PATH Same for the firmware repo or source directory.
--sign                GPG-sign the image and manifest after build.
--jobs N              Parallel make jobs (default: nproc).
--workdir PATH        Build workspace root (default: ./build_workspace).
--fetch-4mlinux-iso   Also download 4MLinux 52.0 live ISO (x86_64) to CACHEDIR.
                      URL: https://sourceforge.net/projects/linux4m/files/52.0/livecd/
--fetch-net-install   Also download 4MLinux net-install ISO (x86_64) to CACHEDIR.
                      Boot from it on x86 hardware to install over Ethernet.
                      URL: https://sourceforge.net/projects/linux4m/files/net-install/
--help                This message.

Outputs (in WORKDIR/output/):
  4mlinux_rpi4.img          Raw SD-card image (sparse)
  4mlinux_rpi4.img.sha256   SHA-256 checksum
  4mlinux_rpi4.img.asc      GPG signature (--sign only)
  manifest.json             JSON build manifest
  manifest.json.asc         GPG signature (--sign only)
USAGE
        exit 0
        ;;
      *) fatal "Unknown option: $1" ;;
    esac
  done

  # Re-derive dependent paths if --workdir was given
  CACHEDIR="${WORKDIR}/cache"
  OUTPUT_DIR="${WORKDIR}/output"
}

# ── detect_runtime ────────────────────────────────────────────────────────────
detect_runtime() {
  if command -v podman >/dev/null 2>&1; then
    CONTAINER_RT="podman"
  elif command -v docker >/dev/null 2>&1; then
    CONTAINER_RT="docker"
  else
    fatal "Neither podman nor docker found."
  fi
  log "Container runtime: ${CONTAINER_RT}"
}

# ── build_builder_image ───────────────────────────────────────────────────────
# Inline Containerfile piped to stdin; build context is empty ('-').
# Idempotent: skips if the image tag already exists.
# Stages mtools for user-space FAT32 copying/packaging.
build_builder_image() {
  local existing
  existing=$("${CONTAINER_RT}" images -q "${BUILDER_TAG}" 2>/dev/null || true)
  if [[ -n "${existing}" ]]; then
    log "Builder image '${BUILDER_TAG}' present — skipping."
    return
  fi
  log "Building isolated build environment (${BUILDER_TAG})..."
  "${CONTAINER_RT}" build -t "${BUILDER_TAG}" - <<'CONTAINERFILE'
FROM docker.io/library/debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential crossbuild-essential-arm64 \
    bc bison flex libssl-dev make libc6-dev libncurses5-dev \
    git wget kmod ccache rsync dosfstools e2fsprogs parted mtools \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /workspace
CONTAINERFILE
}

# ── _seed_from_local_source ───────────────────────────────────────────────────
_seed_from_local_source() {
  local source="$1" target="$2"
  if [[ -f "${source}/HEAD" && -d "${source}/objects" ]]; then
    log "Seeding from local bare repo: ${source}"
    run 300 git clone --mirror "${source}" "${target}"
  elif [[ -d "${source}/.git" ]]; then
    log "Seeding from local checkout: ${source}"
    run 300 git clone --mirror "${source}" "${target}"
  elif [[ -d "${source}" ]]; then
    log "Seeding from plain source directory snapshot: ${source}"
    local tmpwork
    tmpwork="$(mktemp -d /tmp/seed_work_XXXXXX)"
    run 10  git -C "${tmpwork}" init >/dev/null
    run 10  git -C "${tmpwork}" config user.name  "Builder"
    run 10  git -C "${tmpwork}" config user.email "build@local"
    run 300 git -C "${tmpwork}" --work-tree="${source}" add -A >/dev/null
    run 60  git -C "${tmpwork}" --work-tree="${source}" commit -m "Local source snapshot" >/dev/null
    run 300 git clone --mirror "${tmpwork}" "${target}"
    rm -rf "${tmpwork}"
  else
    warn "Local path '${source}' does not exist or is not a directory."
    return 1
  fi
}

# ── _mirror_git_repo ──────────────────────────────────────────────────────────
_mirror_git_repo() {
  local name="$1" remote="$2" branch="$3" sha="$4" local_fallback="${5:-}"
  local target="${CACHEDIR}/${name}.git"
  local stamp="${CACHEDIR}/.${name}_mirror.stamp"

  if [[ -f "${stamp}" ]]; then
    log "Cache hit: ${name} mirror"
    return
  fi

  if [[ -d "${target}" ]]; then
    log "Refreshing ${name} mirror..."
    if ! run 600 git --git-dir="${target}" fetch --prune origin 2>&1; then
      warn "Network fetch failed for ${name}; verifying cached objects."
    fi
  else
    local cloned=0
    if [[ -n "${local_fallback}" ]]; then
      if _seed_from_local_source "${local_fallback}" "${target}"; then
        cloned=1
        log "Local seed succeeded for ${name}."
      else
        warn "Local seed failed for ${name}; trying network."
        rm -rf "${target}"
      fi
    fi

    if [[ "${cloned}" -eq 0 ]]; then
      log "Cloning ${name} mirror from network..."
      if ! run 600 git clone --mirror "${remote}" "${target}" 2>&1; then
        if [[ -n "${local_fallback}" ]]; then
          warn "Network clone failed for ${name}; retrying from local path."
          rm -rf "${target}"
          _seed_from_local_source "${local_fallback}" "${target}" || \
            fatal "Both network and local-fallback clone failed for ${name}."
          log "Local fallback clone succeeded for ${name}."
        else
          if [[ -t 0 ]]; then
            warn "Network clone failed for '${name}' and no --local-${name} path was provided."
            local prompted_path=""
            while true; do
              printf '[?] Enter path to a local %s source (bare repo, checkout, or source directory), or Enter to abort: ' "${name}" >&2
              read -r prompted_path
              [[ -n "${prompted_path}" ]] || fatal "Aborted — no local path supplied for '${name}'."
              rm -rf "${target}"
              if _seed_from_local_source "${prompted_path}" "${target}"; then
                log "Interactively-supplied clone succeeded for '${name}'."
                break
              fi
              warn "'${prompted_path}' is not an accepted source format; try again."
            done
          else
            fatal "git clone --mirror failed for '${name}' and no --local-${name} path was provided. Accepted local formats: bare repo, checkout, or source directory."
          fi
        fi
      fi
    fi
  fi

  if [[ "${sha}" != "HEAD" ]]; then
    run 30 git --git-dir="${target}" cat-file -e "${sha}^{commit}" || \
      fatal "Pinned SHA ${sha} not reachable in '${name}' mirror."
  fi
  touch "${stamp}"
  log "Mirror ready: ${name}."
}

# ── _cache_archive ────────────────────────────────────────────────────────────
_cache_archive() {
  local name="$1" url="$2" expected_sha="$3"
  local target="${CACHEDIR}/${name}"
  local stamp="${CACHEDIR}/.${name}.stamp"

  if [[ -f "${stamp}" ]]; then
    log "Cache hit: ${name}"
    return
  fi

  log "Downloading ${name}..."
  run 300 wget -q --show-progress -O "${target}.tmp" "${url}" || \
    fatal "Download failed for ${name}"

  local actual_sha
  actual_sha="$(sha256sum "${target}.tmp" | awk '{print $1}')"
  [[ "${actual_sha}" == "${expected_sha}" ]] || {
    rm -f "${target}.tmp"
    fatal "SHA-256 mismatch for ${name}. Expected: ${expected_sha}, Got: ${actual_sha}"
  }

  mv "${target}.tmp" "${target}"
  touch "${stamp}"
  log "Verified ${name} (sha256: ${actual_sha})."
}

# ── populate_source_cache ─────────────────────────────────────────────────────
populate_source_cache() {
  mkdir -p "${CACHEDIR}/ccache"
  _mirror_git_repo "linux" "${KERNEL_REPO}" "${KERNEL_BRANCH}" "${KERNEL_SHA}" "${LOCAL_LINUX:-}"
  _mirror_git_repo "firmware" "${FIRMWARE_REPO}" "${FIRMWARE_BRANCH}" "${FIRMWARE_SHA}" "${LOCAL_FIRMWARE:-}"
  _cache_archive "busybox-${BUSYBOX_VERSION}.tar.bz2" \
    "https://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2" \
    "${BUSYBOX_SHA256}"

  # Optional ISO downloads
  _fetch_iso() {
    local dest="$1" url="$2" label="$3"
    [[ -f "${dest}" ]] && { log "Cache hit: ${label}"; return; }
    log "Downloading ${label}..."
    if command -v wget >/dev/null 2>&1; then
      run 600 wget -q --show-progress -L -O "${dest}" "${url}" \
        || { rm -f "${dest}"; fatal "${label} download failed."; }
    else
      run 600 curl -fsSL --progress-bar -L -o "${dest}" "${url}" \
        || { rm -f "${dest}"; fatal "${label} download failed."; }
    fi
    log "${label} cached → ${dest}"
  }

  [[ "${DOWNLOAD_4M_LIVECD}"     -eq 1 ]] && \
    _fetch_iso "${CACHEDIR}/4MLinux-52.0-64bit.iso"  "${FOURM_LIVECD_URL}"     "4MLinux 52.0 live ISO"
  [[ "${DOWNLOAD_4M_NETINSTALL}" -eq 1 ]] && \
    _fetch_iso "${CACHEDIR}/4MLinux-net-install.iso" "${FOURM_NETINSTALL_URL}" "4MLinux net-install ISO"
}

# ── _write_inner_script ───────────────────────────────────────────────────────
# The inner script is written to a temp file and bind-mounted read-only into
# the container. This avoids the bash-quoting chimera.
_write_inner_script() {
  local dest="$1"
  cat >"${dest}" <<'INNER_EOF'
#!/usr/bin/env bash
# ============================================================================
# Inner build script — runs inside the builder container.
#
#   /workspace/cache/     ro  mirrors + archives + ccache(rw)
#   /workspace/           rw  ephemeral build intermediates
#   /workspace/output/    rw  final outputs (bound to host OUTPUT_DIR)
# ============================================================================
set -Eeuo pipefail
export LC_ALL=C LANG=C
umask 0022

# ── Inner utilities ───────────────────────────────────────────────────────────
log()  { printf '[*] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }
fatal(){ printf '[X] %s\n' "$*" >&2; exit 1; }
run()  { local sec="$1"; shift; timeout --foreground "$sec" "$@"; }

# ── Injected configuration ────────────────────────────────────────────────────
ARCH="arm64"
CROSS_COMPILE="aarch64-linux-gnu-"
IMG_NAME="${IMG_NAME:-4mlinux_rpi4.img}"
IMG_SIZE_MB="${IMG_SIZE_MB:-1024}"
BOOT_SIZE_MB="${BOOT_SIZE_MB:-256}"
BUSYBOX_VERSION="${BUSYBOX_VERSION:-1.36.1}"
BUSYBOX_SHA256="${BUSYBOX_SHA256:-}"
KERNEL_SHA="${KERNEL_SHA:-HEAD}"
FIRMWARE_SHA="${FIRMWARE_SHA:-HEAD}"
CORES="${CORES:-$(nproc)}"
BUILD_START_EPOCH="${BUILD_START_EPOCH:-$(date +%s)}"

# ccache: bind-mounted rw at /workspace/cache/ccache
export CCACHE_DIR="/workspace/cache/ccache"
export CCACHE_COMPRESS=1

# Set CC/CXX before any make call — including the config step
export CC="ccache ${CROSS_COMPILE}gcc"
export CXX="ccache ${CROSS_COMPILE}g++"

# Reproducibility exports
export SOURCE_DATE_EPOCH="${BUILD_START_EPOCH}"

# ── Paths ─────────────────────────────────────────────────────────────────────
CACHEDIR="/workspace/cache"
SRCDIR="/workspace/src"
KBUILD="/workspace/kbuild"
STAGING_ROOT="/workspace/staging/rootfs"
STAGING_BOOT="/workspace/staging/bootfs"
FW_STAGING="/workspace/staging/firmware"
IMGDIR="/workspace/output"

mkdir -p "${SRCDIR}" "${KBUILD}" "${STAGING_ROOT}" "${STAGING_BOOT}" \
  "${FW_STAGING}/overlays" "${IMGDIR}"

# ── Stage stamping ────────────────────────────────────────────────────────────
STAMPDIR="/workspace/stamps"
mkdir -p "${STAMPDIR}"
stamped()   { [[ -f "${STAMPDIR}/$1" ]]; }
mark_done() { touch "${STAMPDIR}/$1"; }

# ── stage_sources ─────────────────────────────────────────────────────────────
# Creates worktrees from the bare mirrors; no full object-store copies.
stage_sources() {
  stamped sources && return
  log "Staging sources (worktrees + extraction)..."
  if [[ ! -d "${SRCDIR}/linux" ]]; then
    local linux_ref="${KERNEL_SHA}"
    [[ "${linux_ref}" == "HEAD" ]] && linux_ref="$(git --git-dir="${CACHEDIR}/linux.git" rev-parse HEAD)"
    run 120 git --git-dir="${CACHEDIR}/linux.git" worktree add "${SRCDIR}/linux" "${linux_ref}" \
      || fatal "linux worktree add failed"
  fi
  if [[ ! -d "${SRCDIR}/firmware" ]]; then
    local fw_ref="${FIRMWARE_SHA}"
    [[ "${fw_ref}" == "HEAD" ]] && fw_ref="$(git --git-dir="${CACHEDIR}/firmware.git" rev-parse HEAD)"
    run 120 git --git-dir="${CACHEDIR}/firmware.git" worktree add "${SRCDIR}/firmware" "${fw_ref}" \
      || fatal "firmware worktree add failed"
  fi
  if [[ ! -d "${SRCDIR}/busybox-${BUSYBOX_VERSION}" ]]; then
    local archive="${CACHEDIR}/busybox-${BUSYBOX_VERSION}.tar.bz2"
    local actual
    actual="$(sha256sum "${archive}" | awk '{print $1}')"
    [[ "${actual}" == "${BUSYBOX_SHA256}" ]] \
      || fatal "BusyBox SHA-256 mismatch inside container: ${actual}"
    run 120 tar -xjf "${archive}" -C "${SRCDIR}"
  fi
  mark_done sources
}

# ── stage_kernel ──────────────────────────────────────────────────────────────
stage_kernel() {
  stamped kernel && return
  log "Compiling kernel (O=kbuild)..."
  run 300  make -C "${SRCDIR}/linux" O="${KBUILD}" \
    ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" CC="${CC}" \
    bcm2711_defconfig
  run 7200 make -C "${KBUILD}" -j"${CORES}" \
    ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" CC="${CC}" \
    Image modules dtbs
  mark_done kernel
}

# ── stage_busybox ─────────────────────────────────────────────────────────────
stage_busybox() {
  stamped busybox && return
  log "Compiling BusyBox..."
  local bb_dir="${SRCDIR}/busybox-${BUSYBOX_VERSION}"
  run 180  make -C "${bb_dir}" ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" CC="${CC}" defconfig
  run 10   "${bb_dir}/scripts/config" --file "${bb_dir}/.config" \
    --enable  STATIC \
    --disable BUILD_LIBC_MAIN
  run 60   make -C "${bb_dir}" ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" CC="${CC}" \
    oldconfig < /dev/null
  run 3600 make -C "${bb_dir}" -j"${CORES}" ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" CC="${CC}"
  run 300  make -C "${bb_dir}" ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" CC="${CC}" \
    CONFIG_PREFIX="${STAGING_ROOT}" install
  mark_done busybox
}

# ── stage_firmware_stage ──────────────────────────────────────────────────────
# Explicit file list — no wildcards.
BOOT_MANIFEST=(
  "bootcode.bin"
  "fixup4.dat"   "fixup4cd.dat"  "fixup4db.dat"  "fixup4x.dat"
  "start4.elf"   "start4cd.elf"  "start4db.elf"  "start4x.elf"
  "LICENCE.broadcom"
)
stage_firmware_stage() {
  stamped firmware_stage && return
  log "Staging boot firmware..."
  local fw_boot="${SRCDIR}/firmware/boot"
  local f

  mkdir -p "${STAGING_BOOT}/overlays"
  for f in "${BOOT_MANIFEST[@]}"; do
    [[ -f "${fw_boot}/${f}" ]] && cp "${fw_boot}/${f}" "${STAGING_BOOT}/" \
      || warn "Firmware blob not present in this commit: ${f}"
  done

  # Stage baseline firmware overlays
  [[ -d "${fw_boot}/overlays" ]] && cp -r "${fw_boot}/overlays/." "${STAGING_BOOT}/overlays/"
  
  # Stage newly compiled custom kernel overlays (*.dtbo)
  log "Staging newly compiled custom Device Tree Overlays..."
  find "${KBUILD}/arch/arm64/boot/dts/broadcom/overlays" "${KBUILD}/arch/arm64/boot/dts/overlays" -maxdepth 1 -name "*.dtbo" -exec cp {} "${STAGING_BOOT}/overlays/" \; 2>/dev/null || true

  cp "${KBUILD}/arch/arm64/boot/Image" "${STAGING_BOOT}/kernel8.img"
  find "${KBUILD}/arch/arm64/boot/dts/broadcom" -maxdepth 1 -name "bcm2711-*.dtb" \
    -exec cp {} "${STAGING_BOOT}/" \;

  cat > "${STAGING_BOOT}/config.txt" <<'CONFIG'
[pi4]
arm_64bit=1
kernel=kernel8.img
enable_uart=1
disable_overscan=1
dtoverlay=disable-bt
[all]
# Uncomment to enable camera/display:
# dtoverlay=vc4-kms-v3d
CONFIG

  mark_done firmware_stage
}

# ── stage_rootfs_staging ──────────────────────────────────────────────────────
stage_rootfs_staging() {
  stamped rootfs_staging && return
  log "Staging rootfs skeleton and modules..."
  local dirs=(
    dev etc etc/init.d proc sys tmp
    var/log var/run var/tmp
    lib lib64 usr/bin usr/sbin usr/lib
    mnt media home root boot
  )
  local d
  for d in "${dirs[@]}"; do mkdir -p "${STAGING_ROOT}/${d}"; dmd=; done
  chmod 1777 "${STAGING_ROOT}/tmp" "${STAGING_ROOT}/var/tmp"
  chmod 0750 "${STAGING_ROOT}/root"

  # Static device nodes — required before devtmpfs is mounted by rcS
  [[ -e "${STAGING_ROOT}/dev/console" ]] || mknod -m 600 "${STAGING_ROOT}/dev/console" c 5 1
  [[ -e "${STAGING_ROOT}/dev/null"    ]] || mknod -m 666 "${STAGING_ROOT}/dev/null"    c 1 3

  run 1800 make -C "${KBUILD}" \
    ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" \
    INSTALL_MOD_PATH="${STAGING_ROOT}" modules_install

  cat > "${STAGING_ROOT}/etc/inittab" <<'INITTAB'
::sysinit:/etc/init.d/rcS
::askfirst:-/bin/sh
::ctrlaltdel:/sbin/reboot
::shutdown:/bin/umount -a -r
INITTAB

  cat > "${STAGING_ROOT}/etc/init.d/rcS" <<'RCS'
#!/bin/sh
mount -t proc     proc     /proc
mount -t sysfs    sysfs    /sys
mount -t devtmpfs devtmpfs /dev
hostname -F /etc/hostname
echo
echo "===================================="
echo "4MLinux ARM64 boot completed"
echo "===================================="
RCS
  chmod +x "${STAGING_ROOT}/etc/init.d/rcS"

  printf '4mlinux-pi\n' > "${STAGING_ROOT}/etc/hostname"
  cat > "${STAGING_ROOT}/etc/hosts" <<'HOSTS'
127.0.0.1   localhost
127.0.1.1   4mlinux-pi
HOSTS

  mark_done rootfs_staging
}

# ── stage_depmod ──────────────────────────────────────────────────────────────
stage_depmod() {
  stamped depmod && return
  log "Generating kernel module dependencies inside staging..."
  local kver
  kver="$(ls -1 "${STAGING_ROOT}/lib/modules" | head -n1)"
  [[ -n "${kver}" ]] || fatal "No kernel modules found in ${STAGING_ROOT}/lib/modules"
  run 120 depmod -a -b "${STAGING_ROOT}" "${kver}"
  log "depmod complete (${kver})."
  mark_done depmod
}

# ── stage_install_staging ─────────────────────────────────────────────────────
# Writes config files directly inside the staging root using deterministic static UUIDs.
stage_install_staging() {
  stamped install_staging && return
  log "Generating cmdline.txt and /etc/fstab in staging (using static deterministic PARTUUIDs)..."

  # cmdline.txt uses PARTUUID (robust across USB/NVMe/SD)
  printf 'console=serial0,115200 console=tty1 root=PARTUUID=4d4c696e-02 rootfstype=ext4 rootwait fsck.repair=yes init=/sbin/init\n' \
    > "${STAGING_BOOT}/cmdline.txt"

  # fstab uses PARTUUID for consistency with cmdline.txt
  cat > "${STAGING_ROOT}/etc/fstab" <<FSTAB
# /etc/fstab — generated by 4MLinux AArch64 builder
proc                                /proc  proc  defaults            0 0
sysfs                               /sys   sysfs defaults            0 0
devtmpfs                            /dev   devtmpfs defaults         0 0
PARTUUID=4d4c696e-01                /boot  vfat  defaults,umask=0022 0 2
PARTUUID=4d4c696e-02                /      ext4  defaults,noatime    0 1
FSTAB

  mark_done install_staging
}

# Deterministic filesystem identifiers
readonly FAT_VOL_ID="4D4C494E"
readonly EXT4_UUID="4d4c2d52-6f6f-4654-4653-000000000002"
readonly EXT4_HASH_SEED="4d4c4c696e757861617263683634303"

# ── stage_format (User-Space Packaging) ───────────────────────────────────────
stage_format() {
  stamped format && return
  log "Building filesystem images in user-space (rootless/loopless)..."

  # 1. Build and populate the FAT32 boot partition image
  local boot_img="/workspace/boot.img"
  truncate -s "${BOOT_SIZE_MB}M" "${boot_img}"
  mkfs.vfat -F 32 -i "${FAT_VOL_ID}" -n BOOTFS "${boot_img}"

  log "Preserving staging directory modification times (mtimes) for reproducible builds..."
  find "${STAGING_BOOT}" -exec touch -h -d "@${BUILD_START_EPOCH}" {} + 2>/dev/null || true
  find "${STAGING_ROOT}" -exec touch -h -d "@${BUILD_START_EPOCH}" {} + 2>/dev/null || true

  log "Populating boot filesystem using mcopy..."
  mcopy -s -p -i "${boot_img}" "${STAGING_BOOT}"/* ::/

  # 2. Build and populate the ext4 root partition image
  local root_img="/workspace/root.img"
  local root_size_mb=$(( IMG_SIZE_MB - BOOT_SIZE_MB - 4 ))
  truncate -s "${root_size_mb}M" "${root_img}"

  log "Formatting and populating ext4 root filesystem using mkfs.ext4 -d..."
  mkfs.ext4 \
    -F \
    -L ROOTFS \
    -U "${EXT4_UUID}" \
    -O "^has_journal,^huge_file,^metadata_csum_seed,^orphan_file" \
    -E "lazy_itable_init=0,lazy_journal_init=0,hash_seed=${EXT4_HASH_SEED}" \
    -d "${STAGING_ROOT}" \
    -T minimal \
    "${root_img}"

  # 3. Create the final disk image and partition it
  log "Assembling final disk image..."
  truncate -s "${IMG_SIZE_MB}M" "${IMGDIR}/${IMG_NAME}"
  parted -s "${IMGDIR}/${IMG_NAME}" mktable msdos
  parted -s "${IMGDIR}/${IMG_NAME}" mkpart primary fat32 4MiB "$((BOOT_SIZE_MB + 4))MiB"
  parted -s "${IMGDIR}/${IMG_NAME}" mkpart primary ext4 "$((BOOT_SIZE_MB + 4))MiB" 100%

  # 4. Write partition images directly into seek offsets
  log "Writing boot partition image into sector offset 8192 (4MiB)..."
  dd if="${boot_img}" of="${IMGDIR}/${IMG_NAME}" seek=8192 bs=512 conv=notrunc status=none

  log "Writing root partition image into sector offset $(( (BOOT_SIZE_MB + 4) * 2048 )) ($((BOOT_SIZE_MB + 4))MiB)..."
  dd if="${root_img}" of="${IMGDIR}/${IMG_NAME}" seek=$(( (BOOT_SIZE_MB + 4) * 2048 )) bs=512 conv=notrunc status=none

  # 5. Write the static MBR disk signature for 100% deterministic partition PARTUUIDs
  log "Applying static MBR disk signature '4d4c696e'..."
  printf '\x6e\x69\x4c\x4d' | dd of="${IMGDIR}/${IMG_NAME}" bs=1 seek=440 conv=notrunc status=none

  # Clean up ephemeral partition filesystems
  rm -f "${boot_img}" "${root_img}"

  mark_done format
}

# ── stage_manifest ────────────────────────────────────────────────────────────
stage_manifest() {
  stamped manifest && return
  log "Generating build artifact manifests..."
  sync

  local img_sha256 gcc_ver ld_ver make_ver build_end duration
  img_sha256="$(sha256sum "${IMGDIR}/${IMG_NAME}" | awk '{print $1}')"
  printf '%s  %s\n' "${img_sha256}" "${IMG_NAME}" > "${IMGDIR}/${IMG_NAME}.sha256"

  local kernel_resolved firmware_resolved
  kernel_resolved="$(git --git-dir="/workspace/cache/linux.git" rev-parse HEAD 2>/dev/null || echo "${KERNEL_SHA}")"
  firmware_resolved="$(git --git-dir="/workspace/cache/firmware.git" rev-parse HEAD 2>/dev/null || echo "${FIRMWARE_SHA}")"

  gcc_ver="$(${CROSS_COMPILE}gcc  --version 2>/dev/null | head -1 || echo unknown)"
  ld_ver="$( ${CROSS_COMPILE}ld   --version 2>/dev/null | head -1 || echo unknown)"
  make_ver="$(make                --version 2>/dev/null | head -1 || echo unknown)"
  build_end="$(date +%s)"
  duration=$(( build_end - BUILD_START_EPOCH ))

  cat > "${IMGDIR}/manifest.json" <<JSON
{
  "generated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "duration_seconds": ${duration},
  "image": {
    "name": "${IMG_NAME}",
    "size_mb": ${IMG_SIZE_MB},
    "boot_mb": ${BOOT_SIZE_MB},
    "sha256": "${img_sha256}"
  },
  "sources": {
    "kernel": {
      "repo": "https://github.com/raspberrypi/linux.git",
      "pinned_sha": "${KERNEL_SHA}",
      "resolved_sha": "${kernel_resolved}"
    },
    "firmware": {
      "repo": "https://github.com/raspberrypi/firmware.git",
      "pinned_sha": "${FIRMWARE_SHA}",
      "resolved_sha": "${firmware_resolved}"
    },
    "busybox": {
      "version": "${BUSYBOX_VERSION}",
      "sha256": "${BUSYBOX_SHA256}"
    }
  },
  "toolchain": {
    "gcc":  "${gcc_ver}",
    "ld":   "${ld_ver}",
    "make": "${make_ver}"
  },
  "build": {
    "arch": "${ARCH}",
    "cores": "${CORES}",
    "build_epoch": ${build_end}
  }
}
JSON

  log "Manifest written: ${IMGDIR}/manifest.json"
  mark_done manifest
}

# ── Parallel fan-out ──────────────────────────────────────────────────────────
run_parallel_compilation() {
  if stamped kernel && stamped busybox && stamped firmware_stage; then
    log "All compilation stages already stamped — skipping."
    return
  fi

  stage_sources; mark_done sources 2>/dev/null || true
  log "Starting parallel compilation (kernel + busybox + firmware)..."
  local kpid="" bpid="" fpid=""

  stamped kernel         || { ( stage_kernel         && mark_done kernel )         & kpid=$!; }
  stamped busybox        || { ( stage_busybox        && mark_done busybox )        & bpid=$!; }
  stamped firmware_stage || { ( stage_firmware_stage && mark_done firmware_stage ) & fpid=$!; }

  local pids=()
  [[ -n "${kpid}" ]] && pids+=("${kpid}")
  [[ -n "${bpid}" ]] && pids+=("${bpid}")
  [[ -n "${fpid}" ]] && pids+=("${fpid}")

  local num_jobs="${#pids[@]}"
  local failed=0

  # Monitor running jobs in a fail-fast wait loop
  while [[ "${num_jobs}" -gt 0 ]]; do
    if ! wait -n; then
      warn "A compilation worker failed. Halting siblings immediately..."
      failed=1
      for pid in "${pids[@]}"; do
        kill "${pid}" 2>/dev/null || true
      done
      break
    fi
    num_jobs=$((num_jobs - 1))
  done

  [[ "${failed}" -eq 0 ]] || fatal "Parallel compilation failed — see log above."
  log "Parallel compilation complete."
}

# ── inner_main ────────────────────────────────────────────────────────────────
inner_main() {
  run_parallel_compilation
  stage_rootfs_staging
  stage_depmod
  stage_install_staging
  stage_format
  stage_manifest
  log "Inner build complete."
  sync
}

inner_main
INNER_EOF
  chmod +x "${dest}"
}

# ── run_build_in_container ────────────────────────────────────────────────────
run_build_in_container() {
  _INNER_SCRIPT="$(mktemp /tmp/4mlinux_inner_XXXXXX.sh)"
  _write_inner_script "${_INNER_SCRIPT}"
  mkdir -p "${OUTPUT_DIR}"

  log "Dispatching build DAG to container..."
  # Fully rootless / standard runtime command without mounts or loop devices!
  run 14400 "${CONTAINER_RT}" run --rm \
    -v "${WORKDIR}:/workspace:rw" \
    -v "${OUTPUT_DIR}:/workspace/output:rw" \
    -v "${_INNER_SCRIPT}:/build/inner.sh:ro" \
    -e "CORES=${CORES}" \
    -e "KERNEL_SHA=${KERNEL_SHA}" \
    -e "FIRMWARE_SHA=${FIRMWARE_SHA}" \
    -e "BUSYBOX_VERSION=${BUSYBOX_VERSION}" \
    -e "BUSYBOX_SHA256=${BUSYBOX_SHA256}" \
    -e "BUILD_START_EPOCH=${BUILD_START_EPOCH}" \
    "${BUILDER_TAG}" bash /build/inner.sh
}

# ── main ──────────────────────────────────────────────────────────────────────
main() {
  log "Initializing 4MLinux Pi Builder..."
  parse_args "$@"
  detect_runtime
  build_builder_image
  populate_source_cache
  run_build_in_container

  # Post-build artifact verification
  local final_img="${OUTPUT_DIR}/${IMG_NAME}"
  local final_sum="${OUTPUT_DIR}/${IMG_NAME}.sha256"
  local final_manifest="${OUTPUT_DIR}/manifest.json"

  [[ -f "${final_img}" && -f "${final_sum}" && -f "${final_manifest}" ]] || \
    fatal "Build pipeline completed but expected artifacts are missing."

  # Optional GPG signing
  if [[ "${SIGN_ARTIFACTS}" -eq 1 ]]; then
    log "Signing artifacts..."
    command -v gpg >/dev/null 2>&1 || fatal "--sign: gpg not found in PATH."
    gpg --batch --yes --detach-sign --armor "${final_img}"
    gpg --batch --yes --detach-sign --armor "${final_manifest}"
  fi

  local end_epoch duration
  end_epoch="$(date +%s)"
  duration=$((end_epoch - BUILD_START_EPOCH))
  log "Build duration: ${duration} seconds"
  log "Image successfully created."
  printf '\nImage location:\n  %s\n\n' "${final_img}"
}

main "$@"
