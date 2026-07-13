#!/usr/bin/env bash
set -euo pipefail
                   # === [ MAKE 4M-Pi ISO ] === # by 4ndr0666
# DESCRIPTION: This script will recompile the latest 4m linux
#              distro into a pi flavored vairant.

# CONSTANTS
export LC_ALL=C
export LANG=C
umask 0022
BUILD_START_EPOCH=$(date +%s)
DEFAULT_IMG_SIZE_MB=1024
DEFAULT_BOOT_SIZE_MB=256
DEFAULT_OUTPUT_DIR="$(pwd)/output"
DEFAULT_CACHE_DIR="$(pwd)/source_cache"
DEFAULT_CONTAINER_RUNTIME=""
DEFAULT_REPRODUCIBLE=0
DEFAULT_VERBOSE=0
DEFAULT_GPG_SIGN=0
DEFAULT_LOCAL_LINUX=""
DEFAULT_LOCAL_FIRMWARE=""

# ── Pinned source coordinates ─────────────────────────────────────────────────
# Bump SHAs intentionally when upgrading dependencies.
KERNEL_REPO="https://github.com/raspberrypi/linux.git"
KERNEL_SHA="b10cd73f0d65e83b13f0d10c7b6b6d21d11db0a8"

FIRMWARE_REPO="https://github.com/raspberrypi/firmware.git"
FIRMWARE_SHA="6c5614fbeecf49b7f4a4f61b52a3432b60b7ef71"

BUSYBOX_VERSION="1.36.1"
BUSYBOX_URL="https://www.busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2"
BUSYBOX_SHA256="b8cc24c9574d809e7279c3be349795c5d5ceb6fdf19ca709f80cde50e47de314"

# ── Container ─────────────────────────────────────────────────────────────────
BUILDER_TAG="4mlinux-rpi4-builder"

# ── Logging ───────────────────────────────────────────────────────────────────
log() { printf '[%s] [INFO]  %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2; }
warn() { printf '[%s] [WARN]  %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2; }
die() {
	printf '[%s] [ERROR] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2
	exit 1
}

# ── parse_args ────────────────────────────────────────────────────────────────
parse_args() {
	IMG_SIZE_MB="${DEFAULT_IMG_SIZE_MB}"
	BOOT_SIZE_MB="${DEFAULT_BOOT_SIZE_MB}"
	OUTPUT_DIR="${DEFAULT_OUTPUT_DIR}"
	CACHE_DIR="${DEFAULT_CACHE_DIR}"
	CONTAINER_RUNTIME="${DEFAULT_CONTAINER_RUNTIME}"
	REPRODUCIBLE="${DEFAULT_REPRODUCIBLE}"
	VERBOSE="${DEFAULT_VERBOSE}"
	GPG_SIGN="${DEFAULT_GPG_SIGN}"
	LOCAL_LINUX="${DEFAULT_LOCAL_LINUX}"
	LOCAL_FIRMWARE="${DEFAULT_LOCAL_FIRMWARE}"

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--img-size)
			IMG_SIZE_MB="$2"
			shift 2
			;;
		--boot-size)
			BOOT_SIZE_MB="$2"
			shift 2
			;;
		--output-dir)
			OUTPUT_DIR="$2"
			shift 2
			;;
		--cache-dir)
			CACHE_DIR="$2"
			shift 2
			;;
		--runtime)
			CONTAINER_RUNTIME="$2"
			shift 2
			;;
		--reproducible)
			REPRODUCIBLE=1
			shift
			;;
		--verbose)
			VERBOSE=1
			shift
			;;
		--gpg-sign)
			GPG_SIGN=1
			shift
			;;
		--local-linux)
			LOCAL_LINUX="$2"
			shift 2
			;;
		--local-firmware)
			LOCAL_FIRMWARE="$2"
			shift 2
			;;
		--help | -h)
			cat >&2 <<'USAGE'
Usage: build_rpi4_aarch64.sh [OPTIONS]

  --img-size MB       Total image size in MiB          (default: 1024)
  --boot-size MB      FAT32 boot partition in MiB      (default: 256)
  --output-dir PATH   Directory for outputs             (default: ./output)
  --cache-dir PATH    Source mirrors + ccache dir       (default: ./source_cache)
  --runtime NAME      podman or docker                  (default: auto-detect)
  --reproducible      Pin SOURCE_DATE_EPOCH=0 for bit-exact builds
  --verbose           Stream container logs to this terminal
  --gpg-sign          Sign <img>.sha256 with GPG (requires gpg in PATH)
  --local-linux PATH  Path to a local linux.git bare mirror or checkout.
                      Used as the mirror source; skips network clone entirely.
                      Also tried as a fallback if the network clone fails.
  --local-firmware PATH
                      Same as --local-linux but for the firmware repo.
  --help              This message

Outputs written to OUTPUT_DIR:
  <name>.img              Raw SD-card image (sparse)
  <name>.img.sha256       SHA-256 checksum file
  <name>.img.sha256.asc   GPG detached signature (--gpg-sign only)
  build_manifest.json     JSON build manifest
USAGE
			exit 0
			;;
		*) die "Unknown option: $1" ;;
		esac
	done

	IMG_NAME="4mlinux_rpi4_${IMG_SIZE_MB}M.img"
	export IMG_SIZE_MB BOOT_SIZE_MB OUTPUT_DIR CACHE_DIR CONTAINER_RUNTIME \
		REPRODUCIBLE VERBOSE GPG_SIGN IMG_NAME BUILD_START_EPOCH \
		LOCAL_LINUX LOCAL_FIRMWARE
}

# ── detect_runtime ────────────────────────────────────────────────────────────
detect_runtime() {
	if [[ -n "${CONTAINER_RUNTIME}" ]]; then
		command -v "${CONTAINER_RUNTIME}" >/dev/null 2>&1 ||
			die "Requested runtime '${CONTAINER_RUNTIME}' not found in PATH."
		return
	fi
	if command -v podman >/dev/null 2>&1; then
		CONTAINER_RUNTIME="podman"
	elif command -v docker >/dev/null 2>&1; then
		CONTAINER_RUNTIME="docker"
	else
		die "Neither podman nor docker found. Install one or pass --runtime."
	fi
	log "Container runtime: ${CONTAINER_RUNTIME}"
}

# ── build_builder_image ───────────────────────────────────────────────────────
build_builder_image() {
	local existing
	existing=$("${CONTAINER_RUNTIME}" images -q "${BUILDER_TAG}" 2>/dev/null || true)
	if [[ -n "${existing}" ]]; then
		log "Builder image '${BUILDER_TAG}' present — skipping."
		return
	fi
	log "Building builder image '${BUILDER_TAG}'..."
	"${CONTAINER_RUNTIME}" build --tag "${BUILDER_TAG}" - <<'CONTAINERFILE'
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        bc bison bzip2 ca-certificates ccache cpio dosfstools e2fsprogs \
        flex git gnupg kmod libssl-dev make parted rsync \
        gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu \
        util-linux wget xz-utils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
CONTAINERFILE
	log "Builder image built."
}

# ── populate_source_cache ─────────────────────────────────────────────────────
# git --mirror produces a bare repo that is NEVER checked out on the host.
# The container uses 'git worktree add' to get a working tree from the mirror
# without duplicating objects.  Each mirror is pruned (not replaced) on update.
populate_source_cache() {
	mkdir -p "${CACHE_DIR}/mirrors" "${CACHE_DIR}/archives" "${CACHE_DIR}/ccache"

	# _mirror_git_repo NAME REMOTE_URL SHA [LOCAL_PATH]
	#
	# Resolution order for the mirror at CACHE_DIR/mirrors/NAME.git:
	#
	#   1. Already stamped at this SHA → return immediately (idempotent).
	#   2. Mirror dir already exists   → git fetch --prune to update it.
	#   3. LOCAL_PATH provided and is a valid git repo
	#                                  → clone --mirror from it (fast, offline).
	#   4. Network clone from REMOTE_URL succeeds → use it.
	#   5. Network clone failed AND LOCAL_PATH was provided
	#                                  → retry clone --mirror from LOCAL_PATH.
	#   6. All options exhausted       → die with a clear message.
	#
	# LOCAL_PATH may be a bare mirror (.git dir), a normal checkout, or an
	# ISO/unpacked source tree that contains a .git directory at its root.
	_mirror_git_repo() {
		local name="$1" repo="$2" sha="$3" local_path="${4:-}"
		local dest="${CACHE_DIR}/mirrors/${name}.git"
		local stamp="${dest}/STAMP_${sha}"

		# ── 1. Already done ───────────────────────────────────────────────────
		if [[ -f "${stamp}" ]]; then
			log "Mirror cache: ${name} @ ${sha} already current."
			return
		fi

		# ── 2. Mirror exists; refresh it ─────────────────────────────────────
		if [[ -d "${dest}" ]]; then
			log "Updating existing mirror: ${name}..."
			if ! timeout 600 git --git-dir="${dest}" fetch --prune origin 2>&1; then
				warn "Network fetch failed for mirror ${name}; continuing with cached objects."
			fi
			# Even if fetch failed, the cached objects may still contain the SHA.
		else
			# ── 3. Local path provided and looks like a git repo ──────────────
			local cloned=0
			if [[ -n "${local_path}" ]]; then
				# Accept bare repos (local_path itself is the git dir),
				# normal checkouts (local_path/.git exists),
				# or unpacked source trees with a .git dir.
				local git_src=""
				if [[ -f "${local_path}/HEAD" && -d "${local_path}/objects" ]]; then
					# Bare repo
					git_src="${local_path}"
				elif [[ -d "${local_path}/.git" ]]; then
					# Normal checkout — git clone can still use it as a source
					git_src="${local_path}"
				fi

				if [[ -n "${git_src}" ]]; then
					log "Seeding mirror '${name}' from local path: ${git_src}"
					if timeout 300 git clone --mirror "${git_src}" "${dest}" 2>&1; then
						cloned=1
						log "Local seed successful for ${name}."
					else
						warn "Local seed failed for ${name}; will try network."
						rm -rf "${dest}"
					fi
				else
					warn "Local path '${local_path}' for ${name} does not appear to be a git repo; skipping local seed."
				fi
			fi

			# ── 4. Network clone ──────────────────────────────────────────────
			if [[ "${cloned}" == "0" ]]; then
				log "Cloning mirror '${name}' from network: ${repo}"
				if ! timeout 600 git clone --mirror "${repo}" "${dest}" 2>&1; then
					# ── 5. Network failed; retry from local path if available ─
					if [[ -n "${local_path}" ]]; then
						warn "Network clone failed for ${name}; retrying from local path: ${local_path}"
						rm -rf "${dest}"
						local git_src_fb=""
						if [[ -f "${local_path}/HEAD" && -d "${local_path}/objects" ]]; then
							git_src_fb="${local_path}"
						elif [[ -d "${local_path}/.git" ]]; then
							git_src_fb="${local_path}"
						fi
						[[ -n "${git_src_fb}" ]] ||
							die "Fallback local path '${local_path}' for ${name} is not a git repo."
						timeout 300 git clone --mirror "${git_src_fb}" "${dest}" ||
							die "Both network and local-fallback clone failed for ${name}."
						log "Fallback local seed succeeded for ${name}."
					else
						# ── 6. No fallback available ──────────────────────────
						die "git clone --mirror failed for ${name} and no --local-${name} path was provided."
					fi
				fi
			fi
		fi

		# Verify the pinned SHA is present in whichever mirror we ended up with.
		git --git-dir="${dest}" cat-file -e "${sha}^{commit}" ||
			die "Pinned SHA ${sha} not reachable in mirror '${name}'. \
The local source may be missing this commit; try updating it or removing --local-${name}."
		touch "${stamp}"
		log "Mirror ready: ${name} @ ${sha}."
	}

	_cache_archive() {
		local name="$1" url="$2" expected_sha256="$3"
		local dest="${CACHE_DIR}/archives/${name}"
		local stamp="${dest}.stamp_${expected_sha256}"
		if [[ -f "${stamp}" ]]; then
			log "Archive cache: ${name} already verified."
			return
		fi
		log "Downloading ${name}..."
		timeout 300 wget -q --show-progress -O "${dest}" "${url}" ||
			die "Download failed for ${name}"
		local actual
		actual=$(sha256sum "${dest}" | awk '{print $1}')
		[[ "${actual}" == "${expected_sha256}" ]] ||
			{
				rm -f "${dest}"
				die "SHA-256 mismatch for ${name}: got ${actual}"
			}
		touch "${stamp}"
		log "Verified ${name} (sha256: ${actual})."
	}

	_mirror_git_repo "linux" "${KERNEL_REPO}" "${KERNEL_SHA}" "${LOCAL_LINUX:-}"
	_mirror_git_repo "firmware" "${FIRMWARE_REPO}" "${FIRMWARE_SHA}" "${LOCAL_FIRMWARE:-}"
	_cache_archive "busybox-${BUSYBOX_VERSION}.tar.bz2" \
		"${BUSYBOX_URL}" "${BUSYBOX_SHA256}"
}

# ── _write_inner_script ───────────────────────────────────────────────────────
_write_inner_script() {
	local dest="$1"
	cat >"${dest}" <<'INNER_EOF'
#!/usr/bin/env bash
# ============================================================================
# Inner build script — executes inside the builder container.
# /cache          read-only: mirrors/ archives/ (ccache is rw)
# /build/work     ephemeral: all intermediate build artefacts
# /build/output   bound to host OUTPUT_DIR: final outputs only
# ============================================================================
set -euo pipefail
export LC_ALL=C LANG=C
umask 0022

log()  { printf '[%s] [BUILD] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2; }
warn() { printf '[%s] [WARN]  %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2; }
die()  { printf '[%s] [ERROR] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >&2; exit 1; }

# ── Injected configuration ────────────────────────────────────────────────────
IMG_NAME="${IMG_NAME:-4mlinux_rpi4.img}"
IMG_SIZE_MB="${IMG_SIZE_MB:-1024}"
BOOT_SIZE_MB="${BOOT_SIZE_MB:-256}"
BUSYBOX_VERSION="${BUSYBOX_VERSION:-1.36.1}"
BUSYBOX_SHA256="${BUSYBOX_SHA256:-}"
KERNEL_REPO="${KERNEL_REPO:-}"
FIRMWARE_REPO="${FIRMWARE_REPO:-}"
KERNEL_SHA="${KERNEL_SHA:-}"
FIRMWARE_SHA="${FIRMWARE_SHA:-}"
REPRODUCIBLE="${REPRODUCIBLE:-0}"
BUILD_START_EPOCH="${BUILD_START_EPOCH:-$(date +%s)}"

ARCH=arm64
CROSS_BASE=aarch64-linux-gnu-
CORES=$(nproc)

# ccache: /cache/ccache is mounted rw; all cross-compile calls go through it.
export CCACHE_DIR=/cache/ccache
export CCACHE_COMPRESS=1
CC="ccache ${CROSS_BASE}gcc"
CXX="ccache ${CROSS_BASE}g++"
export CC CXX
CROSS_COMPILE="${CROSS_BASE}"

if [[ "${REPRODUCIBLE}" == "1" ]]; then
    export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-0}"
    log "Reproducible mode: SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH}"
fi

# ── Paths ─────────────────────────────────────────────────────────────────────
MIRRORDIR="/cache/mirrors"
ARCHIVEDIR="/cache/archives"
WORKDIR="/build/work"
SRCDIR="${WORKDIR}/src"
KBUILD="${WORKDIR}/kbuild"
BBSRC="${SRCDIR}/busybox-${BUSYBOX_VERSION}"
# STAGING: all rootfs content accumulates here before being rsync'd into the
# mounted ext4.  Never mounted over; always inspectable.
STAGING="${WORKDIR}/staging"
# ROOTFS: the mounted ext4 partition (only populated by stage_install_staging)
ROOTFS="${WORKDIR}/rootfs"
# BOOTFS: the mounted FAT32 partition
BOOTFS="${WORKDIR}/bootfs"
IMGDIR="/build/output"

mkdir -p "${SRCDIR}" "${KBUILD}" "${STAGING}" "${ROOTFS}" "${BOOTFS}" "${IMGDIR}"

# ── Stage DAG ─────────────────────────────────────────────────────────────────
STAMPDIR="${WORKDIR}/stamps"
mkdir -p "${STAMPDIR}"
stamped()   { [[ -f "${STAMPDIR}/$1" ]]; }
mark_done() { touch "${STAMPDIR}/$1"; }

declare -A STAGE_PREREQS
STAGE_PREREQS=(
    # Parallel group 1: all depend only on sources (or nothing)
    [sources]=""
    [kernel]="sources"
    [busybox]="sources"
    [firmware_stage]="sources"
    # Image creation is independent
    [image_file]=""
    # format depends on image_file
    [format]="image_file"
    # staging assembly: kernel + busybox + firmware must be built first
    [rootfs_staging]="kernel busybox firmware_stage"
    # install: staging must be assembled, filesystem must be formatted
    [install_staging]="rootfs_staging format"
    # depmod runs after modules are installed (part of install_staging)
    [depmod]="install_staging"
    # final manifest after everything is committed
    [manifest]="depmod"
)

_stages_visited=()
run_stage() {
    local stage="$1"
    local v
    for v in "${_stages_visited[@]+"${_stages_visited[@]}"}"; do
        [[ "${v}" == "${stage}" ]] && die "Cycle detected at stage: ${stage}"
    done
    _stages_visited+=("${stage}")

    local prereq
    for prereq in ${STAGE_PREREQS["${stage}"]:-}; do
        stamped "${prereq}" || run_stage "${prereq}"
    done

    if stamped "${stage}"; then
        log "Stage '${stage}' already complete — skipping."
        return
    fi

    log "▶ Stage: ${stage}"
    "stage_${stage}"
    mark_done "${stage}"
    log "✓ Stage: ${stage}"
}

# ── Stage: sources ────────────────────────────────────────────────────────────
# Creates worktrees inside the container's ephemeral SRCDIR.
# The mirror bare repos remain untouched.
stage_sources() {
    if [[ ! -d "${SRCDIR}/linux" ]]; then
        log "  Creating kernel worktree @ ${KERNEL_SHA}..."
        timeout 120 git --git-dir="${MIRRORDIR}/linux.git" \
            worktree add "${SRCDIR}/linux" "${KERNEL_SHA}" \
            || die "kernel worktree add failed"
    fi

    if [[ ! -d "${SRCDIR}/firmware" ]]; then
        log "  Creating firmware worktree @ ${FIRMWARE_SHA}..."
        timeout 120 git --git-dir="${MIRRORDIR}/firmware.git" \
            worktree add "${SRCDIR}/firmware" "${FIRMWARE_SHA}" \
            || die "firmware worktree add failed"
    fi

    if [[ ! -d "${BBSRC}" ]]; then
        log "  Extracting BusyBox ${BUSYBOX_VERSION}..."
        local archive="${ARCHIVEDIR}/busybox-${BUSYBOX_VERSION}.tar.bz2"
        local actual
        actual=$(sha256sum "${archive}" | awk '{print $1}')
        [[ "${actual}" == "${BUSYBOX_SHA256}" ]] \
            || die "BusyBox SHA-256 mismatch inside container: ${actual}"
        timeout 120 tar xjf "${archive}" -C "${SRCDIR}"
    fi
}

# ── Stage: kernel ─────────────────────────────────────────────────────────────
stage_kernel() {
    log "  Configuring kernel (bcm2711_defconfig)..."
    timeout 300 make -C "${SRCDIR}/linux" \
        ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" \
        CC="${CC}" \
        O="${KBUILD}" bcm2711_defconfig

    log "  Building kernel on ${CORES} cores (Image + modules + DTBs)..."
    timeout 7200 make -C "${SRCDIR}/linux" \
        ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" \
        CC="${CC}" \
        O="${KBUILD}" \
        -j"${CORES}" Image modules dtbs
}

# ── Stage: busybox ────────────────────────────────────────────────────────────
# Installs into STAGING, not ROOTFS — safe to run before or after format.
stage_busybox() {
    log "  Configuring BusyBox..."
    timeout 120 make -C "${BBSRC}" \
        ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" \
        CC="${CC}" defconfig

    # scripts/config is BusyBox's own tool; no regex fragility.
    timeout 10 "${BBSRC}/scripts/config" --file "${BBSRC}/.config" \
        --enable  STATIC \
        --disable BUILD_LIBC_MAIN

    # oldconfig resolves symbol dependencies after our changes.
    timeout 60 make -C "${BBSRC}" \
        ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" \
        CC="${CC}" oldconfig < /dev/null

    log "  Building BusyBox on ${CORES} cores..."
    timeout 1800 make -C "${BBSRC}" \
        ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" \
        CC="${CC}" -j"${CORES}"

    log "  Installing BusyBox into staging..."
    timeout 120 make -C "${BBSRC}" \
        ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" \
        CC="${CC}" install CONFIG_PREFIX="${STAGING}"
}

# ── Stage: firmware_stage ─────────────────────────────────────────────────────
# Copies firmware blobs and overlays into a staging sub-tree.
# Exact file list — no wildcards.  Add entries here when bumping FIRMWARE_SHA.
BOOT_MANIFEST=(
    "bootcode.bin"
    "start4.elf"
    "start4cd.elf"
    "start4db.elf"
    "start4x.elf"
    "fixup4.dat"
    "fixup4cd.dat"
    "fixup4db.dat"
    "fixup4x.dat"
)

stage_firmware_stage() {
    local fw_boot="${SRCDIR}/firmware/boot"
    local fw_staging="${WORKDIR}/fw_staging"
    mkdir -p "${fw_staging}/overlays"

    log "  Staging firmware blobs..."
    local f
    for f in "${BOOT_MANIFEST[@]}"; do
        if [[ -f "${fw_boot}/${f}" ]]; then
            cp "${fw_boot}/${f}" "${fw_staging}/${f}"
        else
            warn "  Firmware blob not present in this commit: ${f}"
        fi
    done

    if [[ -d "${fw_boot}/overlays" ]]; then
        cp -r "${fw_boot}/overlays/." "${fw_staging}/overlays/"
        log "  Overlays staged."
    else
        warn "  No overlays directory in firmware source."
    fi
}

# ── Stage: image_file ─────────────────────────────────────────────────────────
stage_image_file() {
    log "  Creating sparse image: ${IMG_SIZE_MB} MiB..."
    truncate -s "${IMG_SIZE_MB}M" "${IMGDIR}/${IMG_NAME}"

    timeout 60 parted -s "${IMGDIR}/${IMG_NAME}" mktable msdos
    timeout 60 parted -s "${IMGDIR}/${IMG_NAME}" \
        mkpart primary fat32 4MiB "$((BOOT_SIZE_MB + 4))MiB"
    timeout 60 parted -s "${IMGDIR}/${IMG_NAME}" \
        mkpart primary ext4 "$((BOOT_SIZE_MB + 4))MiB" 100%
    log "  Partition table written."
}

# ── Loop-device lifecycle ─────────────────────────────────────────────────────
LOOP_DEV=""

cleanup_loop() {
    set +e
    sync 2>/dev/null || true
    [[ -n "${LOOP_DEV}" ]] || return
    umount "${BOOTFS}" 2>/dev/null || true
    umount "${ROOTFS}" 2>/dev/null || true
    losetup -d "${LOOP_DEV}" 2>/dev/null || true
    LOOP_DEV=""
}
trap cleanup_loop EXIT INT TERM

# Deterministic filesystem identifiers for reproducibility.
BOOT_VOL_ID="4D4C3200"
ROOT_UUID="4d4c2d52-6f6f-4654-4653-000000000002"
# Deterministic ext4 hash seed (must be exactly 16 bytes / 32 hex chars)
ROOT_HASH_SEED="4d4c4c696e757861617263683634303"

# ── Stage: format ─────────────────────────────────────────────────────────────
stage_format() {
    log "  Attaching loop device..."
    LOOP_DEV=$(losetup -P -f --show "${IMGDIR}/${IMG_NAME}")
    local boot_dev="${LOOP_DEV}p1"
    local root_dev="${LOOP_DEV}p2"

    log "  Formatting BOOTFS (FAT32, vol-id ${BOOT_VOL_ID})..."
    timeout 120 mkfs.vfat \
        -F 32 \
        -n BOOTFS \
        -i "${BOOT_VOL_ID}" \
        "${boot_dev}"

    log "  Formatting ROOTFS (ext4, UUID ${ROOT_UUID})..."
    # Feature flags:
    #   ^has_journal        — no journal; reduces SD writes
    #   ^huge_file          — not needed for this workload
    #   ^metadata_csum_seed — older e2fsck may not support it
    #   ^orphan_file        — kernel <5.15 compatibility
    # -T minimal            — tune2fs minimal time-stamp granularity
    timeout 120 mkfs.ext4 \
        -L ROOTFS \
        -U "${ROOT_UUID}" \
        -O "^has_journal,^huge_file,^metadata_csum_seed,^orphan_file" \
        -E "lazy_itable_init=0,lazy_journal_init=0,hash_seed=${ROOT_HASH_SEED}" \
        -T minimal \
        "${root_dev}"

    mount "${boot_dev}" "${BOOTFS}"
    mount "${root_dev}" "${ROOTFS}"
    log "  Filesystems mounted (boot=${BOOTFS}, root=${ROOTFS})."
}

# ── Stage: rootfs_staging ────────────────────────────────────────────────────
# Assembles the complete rootfs tree in STAGING.  Does not touch the mounted
# filesystem at all.  Safe to run in parallel with image_file / format.
stage_rootfs_staging() {
    log "  Building staging directory tree..."

    # Directory skeleton
    local dirs=(
        dev etc etc/init.d proc sys tmp var/log var/run var/tmp
        lib lib64 usr/bin usr/sbin usr/lib
        mnt media home root boot
    )
    local d
    for d in "${dirs[@]}"; do
        mkdir -p "${STAGING}/${d}"
    done
    chmod 1777 "${STAGING}/tmp" "${STAGING}/var/tmp"
    chmod 0750 "${STAGING}/root"

    # Static device nodes — required before devtmpfs is available at early init.
    if [[ ! -e "${STAGING}/dev/console" ]]; then
        mknod -m 600 "${STAGING}/dev/console" c 5 1
    fi
    if [[ ! -e "${STAGING}/dev/null" ]]; then
        mknod -m 666 "${STAGING}/dev/null" c 1 3
    fi

    # /etc/inittab
    cat > "${STAGING}/etc/inittab" <<'INITTAB'
::sysinit:/etc/init.d/rcS
::askfirst:-/bin/sh
::ctrlaltdel:/sbin/reboot
::shutdown:/bin/umount -a -r
INITTAB

    # /etc/init.d/rcS
    cat > "${STAGING}/etc/init.d/rcS" <<'RCS'
#!/bin/sh
mount -t proc     none /proc
mount -t sysfs    none /sys
mount -t devtmpfs none /dev
echo "4MLinux ARM64 Port Initialized"
RCS
    chmod +x "${STAGING}/etc/init.d/rcS"

    # /etc/hostname and /etc/hosts
    printf '4mlinux-rpi4\n' > "${STAGING}/etc/hostname"
    cat > "${STAGING}/etc/hosts" <<'HOSTS'
127.0.0.1   localhost
127.0.1.1   4mlinux-rpi4
HOSTS

    # Kernel modules into staging (safe; staging is just a directory)
    log "  Installing kernel modules into staging..."
    timeout 300 make -C "${SRCDIR}/linux" \
        ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" \
        O="${KBUILD}" \
        INSTALL_MOD_PATH="${STAGING}" modules_install

    # Kernel image and DTBs into a boot staging sub-tree
    local boot_staging="${WORKDIR}/boot_staging"
    mkdir -p "${boot_staging}"

    log "  Staging kernel image..."
    cp "${KBUILD}/arch/arm64/boot/Image" "${boot_staging}/kernel8.img"

    log "  Staging DTBs (find all .dtb under broadcom/)..."
    # Use find rather than a hard-coded list so new board DTBs are included
    # automatically when the kernel source adds them.
    find "${KBUILD}/arch/arm64/boot/dts/broadcom" \
        -maxdepth 1 -name 'bcm2711-*.dtb' \
        -exec cp {} "${boot_staging}/" \;
    local dtb_count
    dtb_count=$(find "${boot_staging}" -name '*.dtb' | wc -l)
    log "  ${dtb_count} DTB(s) staged."

    # config.txt
    cat > "${boot_staging}/config.txt" <<'CONFIG'
[pi4]
arm_64bit=1
kernel=kernel8.img
enable_uart=1
dtoverlay=disable-bt

[all]
# Uncomment to enable camera or display:
# dtoverlay=vc4-kms-v3d
CONFIG

    # Firmware blobs from fw_staging
    local fw_staging="${WORKDIR}/fw_staging"
    cp -r "${fw_staging}/." "${boot_staging}/"

    log "  Boot staging complete."
}

# ── Stage: install_staging ────────────────────────────────────────────────────
# Commits the staging trees into the mounted filesystems via rsync.
# STAGING → ROOTFS (ext4 mount)
# boot_staging → BOOTFS (FAT32 mount)
# cmdline.txt and fstab are generated here because they need UUIDs from blkid.
stage_install_staging() {
    local root_uuid boot_uuid
    root_uuid=$(blkid -s UUID -o value "${LOOP_DEV}p2")
    boot_uuid=$(blkid -s UUID -o value "${LOOP_DEV}p1")

    # /etc/fstab — written into STAGING before rsync so it lands in ROOTFS
    cat > "${STAGING}/etc/fstab" <<FSTAB
# /etc/fstab — generated by 4MLinux AArch64 builder
proc                  /proc  proc     defaults             0 0
sysfs                 /sys   sysfs    defaults             0 0
devtmpfs              /dev   devtmpfs defaults             0 0
UUID=${root_uuid}     /      ext4     defaults,noatime     0 1
UUID=${boot_uuid}     /boot  vfat     defaults,umask=0022  0 2
FSTAB
    log "  fstab written (root=${root_uuid}, boot=${boot_uuid})."

    # cmdline.txt — boot partition, references root UUID
    local boot_staging="${WORKDIR}/boot_staging"
    printf 'console=serial0,115200 console=tty1 root=UUID=%s rootfstype=ext4 fsck.repair=yes rootwait quiet\n' \
        "${root_uuid}" > "${boot_staging}/cmdline.txt"

    log "  rsyncing staging → ROOTFS..."
    timeout 300 rsync -aHAX --delete "${STAGING}/" "${ROOTFS}/"

    log "  rsyncing boot_staging → BOOTFS..."
    timeout 120 rsync -aH --delete "${boot_staging}/" "${BOOTFS}/"

    log "  Staging committed."
}

# ── Stage: depmod ─────────────────────────────────────────────────────────────
stage_depmod() {
    local kver
    kver=$(ls "${ROOTFS}/lib/modules/" | head -1)
    [[ -n "${kver}" ]] || die "No modules found under ${ROOTFS}/lib/modules/"
    log "  Running depmod for ${kver}..."
    timeout 60 depmod \
        --basedir="${ROOTFS}" \
        --errsyms \
        "${kver}" >/dev/null
    log "  depmod complete."
}

# ── Stage: manifest ───────────────────────────────────────────────────────────
stage_manifest() {
    log "  Syncing before checksum..."
    sync

    local img_sha256
    img_sha256=$(sha256sum "${IMGDIR}/${IMG_NAME}" | awk '{print $1}')
    printf '%s  %s\n' "${img_sha256}" "${IMG_NAME}" \
        > "${IMGDIR}/${IMG_NAME}.sha256"
    log "  Image SHA-256: ${img_sha256}"

    local kernel_sha firmware_sha gcc_ver ld_ver make_ver build_end duration
    kernel_sha=$(git --git-dir="/cache/mirrors/linux.git" \
        rev-parse "${KERNEL_SHA}" 2>/dev/null || echo "unknown")
    firmware_sha=$(git --git-dir="/cache/mirrors/firmware.git" \
        rev-parse "${FIRMWARE_SHA}" 2>/dev/null || echo "unknown")
    gcc_ver=$(${CROSS_BASE}gcc   --version 2>/dev/null | head -1 || echo "unknown")
    ld_ver=$(${CROSS_BASE}ld     --version 2>/dev/null | head -1 || echo "unknown")
    make_ver=$(make              --version 2>/dev/null | head -1 || echo "unknown")
    build_end=$(date +%s)
    duration=$(( build_end - BUILD_START_EPOCH ))

    cat > "${IMGDIR}/build_manifest.json" <<JSON
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
      "repo": "${KERNEL_REPO}",
      "pinned_sha": "${KERNEL_SHA}",
      "resolved_sha": "${kernel_sha}"
    },
    "firmware": {
      "repo": "${FIRMWARE_REPO}",
      "pinned_sha": "${FIRMWARE_SHA}",
      "resolved_sha": "${firmware_sha}"
    },
    "busybox": {
      "version": "${BUSYBOX_VERSION}",
      "sha256": "${BUSYBOX_SHA256}"
    }
  },
  "toolchain": {
    "gcc": "${gcc_ver}",
    "ld": "${ld_ver}",
    "make": "${make_ver}"
  },
  "reproducibility": {
    "source_date_epoch": "${SOURCE_DATE_EPOCH:-not-set}",
    "lc_all": "${LC_ALL}",
    "umask": "$(umask)"
  }
}
JSON
    log "  Manifest written: build_manifest.json"
}

# ── Parallel fan-out: kernel + busybox + firmware_stage ──────────────────────
# These three stages share no mutable state; they write to disjoint directories.
# Each worker's failure propagates: the wait loop catches non-zero exit codes
# and kills remaining workers before dying.
run_parallel_compilation() {
    if stamped kernel && stamped busybox && stamped firmware_stage; then
        log "All compilation stages already stamped — skipping parallel run."
        return
    fi

    # Prerequisite for all three
    run_stage sources

    log "Starting parallel compilation (kernel + busybox + firmware_stage)..."

    local kernel_pid="" busybox_pid="" fw_pid=""

    if ! stamped kernel; then
        ( stage_kernel && mark_done kernel ) &
        kernel_pid=$!
    fi

    if ! stamped busybox; then
        ( stage_busybox && mark_done busybox ) &
        busybox_pid=$!
    fi

    if ! stamped firmware_stage; then
        ( stage_firmware_stage && mark_done firmware_stage ) &
        fw_pid=$!
    fi

    # Wait for each worker; on any failure, kill siblings and propagate.
    local failed=0
    for worker_var in kernel_pid busybox_pid fw_pid; do
        local pid="${!worker_var}"
        [[ -z "${pid}" ]] && continue
        if ! wait "${pid}"; then
            warn "Worker ${worker_var%_pid} failed (pid ${pid})."
            failed=1
            # Kill remaining workers
            for sibling_var in kernel_pid busybox_pid fw_pid; do
                local spid="${!sibling_var}"
                [[ -z "${spid}" || "${spid}" == "${pid}" ]] && continue
                kill "${spid}" 2>/dev/null || true
            done
            break
        fi
    done

    [[ "${failed}" == "0" ]] || die "Parallel compilation failed — see above."
    log "Parallel compilation complete."
}

# ── inner_main ────────────────────────────────────────────────────────────────
inner_main() {
    # Run parallel compilation first (kernel + busybox + firmware_stage).
    run_parallel_compilation

    # Then run the terminal stage; DAG resolves remaining prerequisites.
    run_stage manifest

    log "Inner build complete."
    sync
    # cleanup_loop fires via EXIT trap
}

inner_main
INNER_EOF
	chmod +x "${dest}"
}

# ── run_build_in_container ────────────────────────────────────────────────────
run_build_in_container() {
	local inner_script
	inner_script=$(mktemp /tmp/inner_build_XXXXXX.sh)
	trap 'rm -f "${inner_script}"' EXIT INT TERM

	_write_inner_script "${inner_script}"
	mkdir -p "${OUTPUT_DIR}"

	local verbose_flags=()
	[[ "${VERBOSE}" != "1" ]] && verbose_flags=(--log-level error)

	local repro_env=()
	[[ "${REPRODUCIBLE}" == "1" ]] &&
		repro_env=(-e "SOURCE_DATE_EPOCH=0" -e "REPRODUCIBLE=1")

	log "Launching builder container (${CONTAINER_RUNTIME})..."
	log "  Cache  : ${CACHE_DIR} (mirrors+archives ro, ccache rw)"
	log "  Output : ${OUTPUT_DIR}"

	# Capabilities required:
	#   SYS_ADMIN — losetup + mount inside container
	#   /dev/loop-control + /dev/loop{0..7} — loop device access
	# --privileged is NOT used.
	timeout 14400 "${CONTAINER_RUNTIME}" run \
		--rm \
		--cap-add SYS_ADMIN \
		--device /dev/loop-control \
		$(for i in $(seq 0 7); do printf -- '--device /dev/loop%d ' "$i"; done) \
		"${verbose_flags[@]}" \
		-v "${CACHE_DIR}/mirrors:/cache/mirrors:ro" \
		-v "${CACHE_DIR}/archives:/cache/archives:ro" \
		-v "${CACHE_DIR}/ccache:/cache/ccache:rw" \
		-v "${OUTPUT_DIR}:/build/output:rw" \
		-v "${inner_script}:/build/inner.sh:ro" \
		-e "IMG_NAME=${IMG_NAME}" \
		-e "IMG_SIZE_MB=${IMG_SIZE_MB}" \
		-e "BOOT_SIZE_MB=${BOOT_SIZE_MB}" \
		-e "BUSYBOX_VERSION=${BUSYBOX_VERSION}" \
		-e "BUSYBOX_SHA256=${BUSYBOX_SHA256}" \
		-e "KERNEL_REPO=${KERNEL_REPO}" \
		-e "FIRMWARE_REPO=${FIRMWARE_REPO}" \
		-e "KERNEL_SHA=${KERNEL_SHA}" \
		-e "FIRMWARE_SHA=${FIRMWARE_SHA}" \
		-e "BUILD_START_EPOCH=${BUILD_START_EPOCH}" \
		"${repro_env[@]}" \
		"${BUILDER_TAG}" \
		bash /build/inner.sh

	rm -f "${inner_script}"
	trap - EXIT INT TERM
}

# ── main ──────────────────────────────────────────────────────────────────────
main() {
	parse_args "$@"
	detect_runtime
	build_builder_image
	populate_source_cache
	run_build_in_container

	local final_img="${OUTPUT_DIR}/${IMG_NAME}"
	local final_sum="${OUTPUT_DIR}/${IMG_NAME}.sha256"
	local final_manifest="${OUTPUT_DIR}/build_manifest.json"

	[[ -f "${final_img}" ]] || die "Image not found after build: ${final_img}"
	[[ -f "${final_sum}" ]] || die "Checksum not found after build: ${final_sum}"
	[[ -f "${final_manifest}" ]] || die "Manifest not found after build: ${final_manifest}"

	if [[ "${GPG_SIGN}" == "1" ]]; then
		log "Signing checksum with GPG..."
		command -v gpg >/dev/null 2>&1 || die "--gpg-sign: gpg not in PATH."
		gpg --batch --yes --detach-sign --armor "${final_sum}"
		log "Signature: ${final_sum}.asc"
	fi

	local build_end duration
	build_end=$(date +%s)
	duration=$((build_end - BUILD_START_EPOCH))

	log "=== BUILD SUCCESSFUL (${duration}s) ==="
	log "Image    : ${final_img}"
	log "Checksum : ${final_sum}"
	log "Manifest : ${final_manifest}"
	printf '%s\n' "${final_img}"
}

main "$@"
