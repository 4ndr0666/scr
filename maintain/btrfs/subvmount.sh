#!/bin/bash
# shellcheck disable=all

btrfsmount() {
    echo "Mounting subvolumes to /mnt/dev..."
    sudo mount -o defaults,subvol=@ /dev/sdc3 /mnt/dev/
    sudo mount -o defaults,subvol=@root /dev/sdc3 /mnt/dev/root
    sudo mount -o defaults,subvol=@cache /dev/sdc3 /mnt/dev/var/cache
    sudo mount -o defaults,subvol=@tmp /dev/sdc3 /mnt/dev/var/tmp
    sudo mount -o defaults,subvol=@log /dev/sdc3 /mnt/dev/var/log
    sudo mount -o defaults,subvol=@srv /dev/sdc3 /mnt/dev/srv
    sleep 2
#    echo "Mounting boot partition /boot/efi..."
#    sudo mount /dev/sdc1 /boot/efi
#    sleep 2
    echo "Complete!"
}

shopt -s extglob

# generated from util-linux source: libmount/src/utils.c
declare -A pseudofs_types=([anon_inodefs]=1
                           [apparmorfs]=1
                           [autofs]=1
                           [bdev]=1
                           [binder]=1
                           [binfmt_misc]=1
                           [bpf]=1
                           [cgroup]=1
                           [cgroup2]=1
                           [configfs]=1
                           [cpuset]=1
                           [debugfs]=1
                           [devfs]=1
                           [devpts]=1
                           [devtmpfs]=1
                           [dlmfs]=1
                           [dmabuf]=1
                           [drm]=1
                           [efivarfs]=1
                           [fuse]=1
                           [fuse.archivemount]=1
                           [fuse.avfsd]=1
                           [fuse.dumpfs]=1
                           [fuse.encfs]=1
                           [fuse.gvfs-fuse-daemon]=1
                           [fuse.gvfsd-fuse]=1
                           [fuse.lxcfs]=1
                           [fuse.rofiles-fuse]=1
                           [fuse.vmware-vmblock]=1
                           [fuse.xwmfs]=1
                           [fusectl]=1
                           [hugetlbfs]=1
                           [ipathfs]=1
                           [mqueue]=1
                           [nfsd]=1
                           [none]=1
                           [nsfs]=1
                           [overlay]=1
                           [pipefs]=1
                           [proc]=1
                           [pstore]=1
                           [ramfs]=1
                           [resctrl]=1
                           [rootfs]=1
                           [rpc_pipefs]=1
                           [securityfs]=1
                           [selinuxfs]=1
                           [smackfs]=1
                           [sockfs]=1
                           [spufs]=1
                           [sysfs]=1
                           [tmpfs]=1
                           [tracefs]=1
                           [vboxsf]=1
                           [virtiofs]=1)

# generated from: pkgfile -vbr '/fsck\..+' | awk -F. '{ print $NF }' | sort
declare -A fsck_types=([btrfs]=0    # btrfs doesn't need a regular fsck utility
                       [cramfs]=1
                       [erofs]=1
                       [exfat]=1
                       [ext2]=1
                       [ext3]=1
                       [ext4]=1
                       [f2fs]=1
                       [fat]=1
                       [jfs]=1
                       [minix]=1
                       [msdos]=1
                       [reiserfs]=1
                       [vfat]=1
                       [xfs]=1)

out() { printf "$1 $2\n" "${@:3}"; }
error() { out "==> ERROR:" "$@"; } >&2
warning() { out "==> WARNING:" "$@"; } >&2
msg() { out "==>" "$@"; }
msg2() { out "  ->" "$@";}
die() { error "$@"; exit 1; }

ignore_error() {
  "$@" 2>/dev/null
  return 0
}

in_array() {
  local i
  for i in "${@:2}"; do
    [[ $1 = "$i" ]] && return 0
  done
  return 1
}

chroot_add_mount() {
  mount "$@" && CHROOT_ACTIVE_MOUNTS=("$2" "${CHROOT_ACTIVE_MOUNTS[@]}")
}

chroot_maybe_add_mount() {
  local cond=$1; shift
  if eval "$cond"; then
    chroot_add_mount "$@"
  fi
}

chroot_setup() {
  CHROOT_ACTIVE_MOUNTS=()
  [[ $(trap -p EXIT) ]] && die '(BUG): attempting to overwrite existing EXIT trap'
  trap 'chroot_teardown' EXIT

  chroot_add_mount proc "$1/proc" -t proc -o nosuid,noexec,nodev &&
  chroot_add_mount sys "$1/sys" -t sysfs -o nosuid,noexec,nodev,ro &&
  ignore_error chroot_maybe_add_mount "[[ -d '$1/sys/firmware/efi/efivars' ]]" \
      efivarfs "$1/sys/firmware/efi/efivars" -t efivarfs -o nosuid,noexec,nodev &&
  chroot_add_mount udev "$1/dev" -t devtmpfs -o mode=0755,nosuid &&
  chroot_add_mount devpts "$1/dev/pts" -t devpts -o mode=0620,gid=5,nosuid,noexec &&
  chroot_add_mount shm "$1/dev/shm" -t tmpfs -o mode=1777,nosuid,nodev &&
  chroot_add_mount run "$1/run" -t tmpfs -o nosuid,nodev,mode=0755 &&
  chroot_add_mount tmp "$1/tmp" -t tmpfs -o mode=1777,strictatime,nodev,nosuid
}

chroot_teardown() {
  if (( ${#CHROOT_ACTIVE_MOUNTS[@]} )); then
    umount "${CHROOT_ACTIVE_MOUNTS[@]}"
  fi
  unset CHROOT_ACTIVE_MOUNTS
}

chroot_add_mount_lazy() {
  mount "$@" && CHROOT_ACTIVE_LAZY=("$2" "${CHROOT_ACTIVE_LAZY[@]}")
}

chroot_bind_device() {
  touch "$2" && CHROOT_ACTIVE_FILES=("$2" "${CHROOT_ACTIVE_FILES[@]}")
  chroot_add_mount $1 "$2" --bind
}

chroot_add_link() {
  ln -sf "$1" "$2" && CHROOT_ACTIVE_FILES=("$2" "${CHROOT_ACTIVE_FILES[@]}")
}

unshare_setup() {
  CHROOT_ACTIVE_MOUNTS=()
  CHROOT_ACTIVE_LAZY=()
  CHROOT_ACTIVE_FILES=()
  [[ $(trap -p EXIT) ]] && die '(BUG): attempting to overwrite existing EXIT trap'
  trap 'unshare_teardown' EXIT

  chroot_add_mount_lazy "$1" "$1" --bind &&
  chroot_add_mount proc "$1/proc" -t proc -o nosuid,noexec,nodev &&
  chroot_add_mount_lazy /sys "$1/sys" --rbind &&
  chroot_add_link "$1/proc/self/fd" "$1/dev/fd" &&
  chroot_add_link "$1/proc/self/fd/0" "$1/dev/stdin" &&
  chroot_add_link "$1/proc/self/fd/1" "$1/dev/stdout" &&
  chroot_add_link "$1/proc/self/fd/2" "$1/dev/stderr" &&
  chroot_bind_device /dev/full "$1/dev/full" &&
  chroot_bind_device /dev/null "$1/dev/null" &&
  chroot_bind_device /dev/random "$1/dev/random" &&
  chroot_bind_device /dev/tty "$1/dev/tty" &&
  chroot_bind_device /dev/urandom "$1/dev/urandom" &&
  chroot_bind_device /dev/zero "$1/dev/zero" &&
  chroot_add_mount run "$1/run" -t tmpfs -o nosuid,nodev,mode=0755 &&
  chroot_add_mount tmp "$1/tmp" -t tmpfs -o mode=1777,strictatime,nodev,nosuid
}

unshare_teardown() {
  chroot_teardown

  if (( ${#CHROOT_ACTIVE_LAZY[@]} )); then
    umount --lazy "${CHROOT_ACTIVE_LAZY[@]}"
  fi
  unset CHROOT_ACTIVE_LAZY

  if (( ${#CHROOT_ACTIVE_FILES[@]} )); then
    rm "${CHROOT_ACTIVE_FILES[@]}"
  fi
  unset CHROOT_ACTIVE_FILES
}

pid_unshare="unshare --fork --pid"
mount_unshare="$pid_unshare --mount --map-auto --map-root-user --setuid 0 --setgid 0"

# This outputs code for declaring all variables to stdout. For example, if
# FOO=BAR, then running
#     declare -p FOO
# will result in the output
#     declare -- FOO="bar"
# This function may be used to re-declare all currently used variables and
# functions in a new shell.
declare_all() {
  # Remove read-only variables to avoid warnings. Unfortunately, declare +r -p
  # doesn't work like it looks like it should (declaring only read-write
  # variables). However, declare -rp will print out read-only variables, which
  # we can then use to remove those definitions.
  declare -p | grep -Fvf <(declare -rp)
  # Then declare functions
  declare -pf
}

try_cast() (
  _=$(( $1#$2 ))
) 2>/dev/null

valid_number_of_base() {
  local base=$1 len=${#2} i=

  for (( i = 0; i < len; i++ )); do
    try_cast "$base" "${2:i:1}" || return 1
  done

  return 0
}

mangle() {
  local i= chr= out=
  local {a..f}= {A..F}=

  for (( i = 0; i < ${#1}; i++ )); do
    chr=${1:i:1}
    case $chr in
      [[:space:]\\])
        printf -v chr '%03o' "'$chr"
        out+=\\
        ;;
    esac
    out+=$chr
  done

  printf '%s' "$out"
}

unmangle() {
  local i= chr= out= len=$(( ${#1} - 4 ))
  local {a..f}= {A..F}=

  for (( i = 0; i < len; i++ )); do
    chr=${1:i:1}
    case $chr in
      \\)
        if valid_number_of_base 8 "${1:i+1:3}" ||
            valid_number_of_base 16 "${1:i+1:3}"; then
          printf -v chr '%b' "${1:i:4}"
          (( i += 3 ))
        fi
        ;;
    esac
    out+=$chr
  done

  printf '%s' "$out${1:i}"
}

optstring_match_option() {
  local candidate pat patterns

  IFS=, read -ra patterns <<<"$1"
  for pat in "${patterns[@]}"; do
    if [[ $pat = *=* ]]; then
      # "key=val" will only ever match "key=val"
      candidate=$2
    else
      # "key" will match "key", but also "key=anyval"
      candidate=${2%%=*}
    fi

    [[ $pat = "$candidate" ]] && return 0
  done

  return 1
}

optstring_remove_option() {
  local o options_ remove=$2 IFS=,

  read -ra options_ <<<"${!1}"

  for o in "${!options_[@]}"; do
    optstring_match_option "$remove" "${options_[o]}" && unset 'options_[o]'
  done

  declare -g "$1=${options_[*]}"
}

optstring_normalize() {
  local o options_ norm IFS=,

  read -ra options_ <<<"${!1}"

  # remove empty fields
  for o in "${options_[@]}"; do
    [[ $o ]] && norm+=("$o")
  done

  # avoid empty strings, reset to "defaults"
  declare -g "$1=${norm[*]:-defaults}"
}

optstring_append_option() {
  if ! optstring_has_option "$1" "$2"; then
    declare -g "$1=${!1},$2"
  fi

  optstring_normalize "$1"
}

optstring_prepend_option() {
  local options_=$1

  if ! optstring_has_option "$1" "$2"; then
    declare -g "$1=$2,${!1}"
  fi

  optstring_normalize "$1"
}

optstring_get_option() {
  local opts o

  IFS=, read -ra opts <<<"${!1}"
  for o in "${opts[@]}"; do
    if optstring_match_option "$2" "$o"; then
      declare -g "$o"
      return 0
    fi
  done

  return 1
}

optstring_has_option() {
  local "${2%%=*}"

  optstring_get_option "$1" "$2"
}

dm_name_for_devnode() {
  read dm_name <"/sys/class/block/${1#/dev/}/dm/name"
  if [[ $dm_name ]]; then
    printf '/dev/mapper/%s' "$dm_name"
  else
    # don't leave the caller hanging, just print the original name
    # along with the failure.
    error 'Failed to resolve device mapper name for: %s' "$1"
  fi
}

fstype_is_pseudofs() {
  (( pseudofs_types["$1"] ))
}

fstype_has_fsck() {
  (( fsck_types["$1"] ))
}


setup=chroot_setup
unshare=0

usage() {
  cat <<EOF
usage: ${0##*/} chroot-dir [command] [arguments...]

    -h                  Print this help message
    -N                  Run in unshare mode as a regular user
    -u <user>[:group]   Specify non-root user and optional group to use

If 'command' is unspecified, ${0##*/} will launch /bin/bash.

Note that when using arch-chroot, the target chroot directory *should* be a
mountpoint. This ensures that tools such as pacman(8) or findmnt(8) have an
accurate hierarchy of the mounted filesystems within the chroot.

If your chroot target is not a mountpoint, you can bind mount the directory on
itself to make it a mountpoint, i.e. 'mount --bind /your/chroot /your/chroot'.

EOF
}

resolve_link() {
  local target=$1
  local root=$2

  # If a root was given, make sure it ends in a slash.
  [[ -n $root && $root != */ ]] && root=$root/

  while [[ -L $target ]]; do
    target=$(readlink -m "$target")
    # If a root was given, make sure the target is under it.
    # Make sure to strip any leading slash from target first.
    [[ -n $root && $target != $root* ]] && target=$root${target#/}
  done

  printf %s "$target"
}

chroot_add_resolv_conf() {
  local chrootdir=$1
  local src=$(resolve_link /etc/resolv.conf)
  local dest=$(resolve_link "$chrootdir/etc/resolv.conf" "$chrootdir")

  # If we don't have a source resolv.conf file, there's nothing useful we can do.
  [[ -e $src ]] || return 0

  if [[ ! -e $dest ]]; then
    # There are two reasons the destination might not exist:
    #
    #   1. There may be no resolv.conf in the chroot.  In this case, $dest won't exist,
    #      and it will be equal to $1/etc/resolv.conf.  In this case, we'll just exit.
    #      The chroot environment must not be concerned with DNS resolution.
    #
    #   2. $1/etc/resolv.conf is (or resolves to) a broken link.  The environment
    #      clearly intends to handle DNS resolution, but something's wrong.  Maybe it
    #      normally creates the target at boot time.  We'll (try to) take care of it by
    #      creating a dummy file at the target, so that we have something to bind to.

    # Case 1.
    [[ $dest = $chrootdir/etc/resolv.conf ]] && return 0

    # Case 2.
    install -Dm644 /dev/null "$dest" || return 1
  fi

  chroot_add_mount "$src" "$dest" --bind
}

while getopts ':hNu:' flag; do
  case $flag in
    h)
      usage
      exit 0
      ;;
    N)
      setup=unshare_setup
      unshare=1
      ;;
    u)
      userspec=$OPTARG
      ;;
    :)
      die '%s: option requires an argument -- '\''%s'\' "${0##*/}" "$OPTARG"
      ;;
    ?)
      die '%s: invalid option -- '\''%s'\' "${0##*/}" "$OPTARG"
      ;;
  esac
done
shift $(( OPTIND - 1 ))

(( $# )) || die 'No chroot directory specified'
chrootdir=$1
shift

arch-chroot() {
  (( EUID == 0 )) || die 'This script must be run with root privileges'

  [[ -d $chrootdir ]] || die "Can't create chroot on non-directory %s" "$chrootdir"

  $setup "$chrootdir" || die "failed to setup chroot %s" "$chrootdir"
  chroot_add_resolv_conf "$chrootdir" || die "failed to setup resolv.conf"

  if ! mountpoint -q "$chrootdir"; then
    warning "$chrootdir is not a mountpoint. This may have undesirable side effects."
  fi

  chroot_args=()
  [[ $userspec ]] && chroot_args+=(--userspec "$userspec")

  SHELL=/bin/bash $pid_unshare chroot "${chroot_args[@]}" -- "$chrootdir" "${args[@]}"
}

args=("$@")
if (( unshare )); then
  $mount_unshare bash -c "$(declare_all); arch-chroot"
else
  arch-chroot
fi
