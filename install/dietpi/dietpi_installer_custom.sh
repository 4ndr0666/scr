#!/usr/bin/env bash
# 4ndr0666
# ==============================================================================
#                    === DietPi RPi4 Automated Rice Script ===
#
#  Phase 1 (host)  : Download + verify DietPi image, flash to SD card,
#                    write dietpi.txt / dietpi-wifi.txt / custom scripts.
#  Phase 2 (Pi)    : Automation_Custom_Script.sh runs on first boot —
#                    reads progs.csv, installs software, deploys dotfiles,
#                    configures DietPi tools, hardens sudoers, builds kernel.
#
#  Usage:
#    sudo ./dietpi_rpi4_install.sh [OPTIONS]
#    sudo ./dietpi_rpi4_install.sh --noninteractive --device /dev/sdb \
#         --hostname mypi --password s3cr3t --timezone America/Matamoros
#    ./dietpi_rpi4_install.sh --dry-run   # generate config files only
# ==============================================================================

set -Eeuo pipefail
export LC_ALL=C LANG=C
umask 0022

SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_NAME
readonly SCRIPT_VERSION="2.1.1"

# ── DietPi image ──────────────────────────────────────────────────────────────
readonly DIETPI_IMAGE_URL="https://dietpi.com/downloads/images/DietPi_RPi-ARMv8-Bookworm.img.xz"
readonly DIETPI_SHA256_URL="${DIETPI_IMAGE_URL}.sha256"

# ── Host-side defaults ────────────────────────────────────────────────────────
TARGET_DEVICE=""
WORK_DIR="$(pwd)/dietpi_build"
KEEP_IMAGE=0
NONINTERACTIVE=0
DRY_RUN=0
KERNEL_CONFIG=""

# ── dietpi.txt knobs ──────────────────────────────────────────────────────────
CFG_HOSTNAME="DietPi"
CFG_PASSWORD="dietpi"
CFG_LOCALE="en_US.UTF-8"
CFG_TIMEZONE="America/Matamoros"
CFG_KEYBOARD="us"
CFG_SSH_INDEX="-1" # -2=OpenSSH  0=Dropbear  -1=none
CFG_WIFI_ENABLED=0
CFG_WIFI_SSID=""
CFG_WIFI_PASS=""
CFG_WIFI_COUNTRY="US"
CFG_STATIC_IP=0
CFG_STATIC_ADDR=""
CFG_STATIC_MASK="255.255.255.0"
CFG_STATIC_GW=""
CFG_STATIC_DNS="9.9.9.9 149.112.112.112"
CFG_AUTO_UPDATE=1 # 1=check  2=check+install
CFG_APT_UPDATE=2
CFG_AUTOSTART_INDEX=0 # 0=console  16=LXDE  7=Kodi  etc.
CFG_AUTOSTART_USER="root"
CFG_SURVEY_OPT=0    # SURVEY_OPTED_IN: 0=opt-out  1=opt-in
CFG_SOFTWARE_IDS="" # space-separated dietpi-software IDs
CFG_APT_PACKAGES="" # extra APT packages for AUTO_SETUP_APT_INSTALLS
CFG_NET_ETH_FORCE_SPEED=0
CFG_BOOT_WAIT_FOR_NETWORK=1
CFG_SWAPFILE_SIZE=0

# ── Post-boot rice settings ────────────────────────────────────────────────────
DOTFILES_REPO="" # git repo to clone and rsync into /root (or user home)
DOTFILES_BRANCH="master"
PROGS_CSV_URL="" # URL or local path to progs.csv (optional)
RICE_USER="root" # non-root user to create and rice (empty = root only)
RICE_USER_PASS=""

# ── Colours ───────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
	R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m' C='\033[0;36m' B='\033[1m' Z='\033[0m'
else
	R='' G='' Y='' C='' B='' Z=''
fi
log() { printf "${G}[*]${Z} %s\n" "$*"; }
warn() { printf "${Y}[!]${Z} %s\n" "$*" >&2; }
fatal() {
	printf "${R}[X]${Z} %s\n" "$*" >&2
	exit 1
}
info() { printf "${C}[i]${Z} %s\n" "$*"; }
ask() { printf "${C}[?]${Z} %s" "$*"; }

# ── run — bounded subprocess ──────────────────────────────────────────────────
run() {
	local s="$1"
	shift
	timeout --foreground "$s" "$@"
}

# ── Cleanup ───────────────────────────────────────────────────────────────────
_MOUNT_POINT=""
_cleanup_done=0
_cleanup() {
	local rc=$?
	[[ "${_cleanup_done}" -eq 1 ]] && exit "$rc"
	_cleanup_done=1
	set +e
	[[ -n "${_MOUNT_POINT}" ]] && {
		sync
		umount "${_MOUNT_POINT}" 2>/dev/null
		rmdir "${_MOUNT_POINT}" 2>/dev/null
	}
	exit "$rc"
}
trap _cleanup EXIT INT TERM

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
	cat <<USAGE
${B}${SCRIPT_NAME} v${SCRIPT_VERSION}${Z} — DietPi RPi4 automated rice script

${B}Usage:${Z}
  sudo ${SCRIPT_NAME} [OPTIONS]

${B}Target:${Z}
  --device DEV            Block device to flash (e.g. /dev/sdb, /dev/mmcblk0)
                          ALL DATA ON THE DEVICE WILL BE ERASED.

${B}System:${Z}
  --hostname NAME         Hostname                        (default: ${CFG_HOSTNAME})
  --password PASS         Root / global password          (default: ${CFG_PASSWORD})
  --locale LOCALE         Locale                          (default: ${CFG_LOCALE})
  --timezone TZ           Timezone                        (default: ${CFG_TIMEZONE})
  --keyboard LAYOUT       Keyboard layout                 (default: ${CFG_KEYBOARD})
  --ssh-server N          -2=OpenSSH 0=Dropbear -1=none   (default: ${CFG_SSH_INDEX})
  --survey N              0=opt-out 1=opt-in DietPi survey (default: ${CFG_SURVEY_OPT})
  --swapfile-size MB      AUTO_SETUP_SWAPFILE_SIZE        (default: ${CFG_SWAPFILE_SIZE})

${B}Network:${Z}
  --wifi-ssid SSID        WiFi SSID (enables WiFi)
  --wifi-pass PASS        WiFi passphrase
  --wifi-country CC       Country code                    (default: ${CFG_WIFI_COUNTRY})
  --static-ip ADDR        Static IP address (enables static config)
  --static-mask MASK      Subnet mask                     (default: ${CFG_STATIC_MASK})
  --static-gw GW          Default gateway
  --static-dns DNS        DNS server                      (default: "${CFG_STATIC_DNS}")
  --eth-force-speed N     AUTO_SETUP_NET_ETH_FORCE_SPEED  (default: ${CFG_NET_ETH_FORCE_SPEED})
  --boot-wait-network N   AUTO_SETUP_BOOT_WAIT_FOR_NETWORK(default: ${CFG_BOOT_WAIT_FOR_NETWORK})

${B}Software:${Z}
  --software-ids "N N"    dietpi-software IDs to auto-install (space-separated)
  --apt-packages "p p"    Extra APT packages
  --autostart N           Autostart index (0=console 16=LXDE 7=Kodi)
  --autostart-user USER   User for autostart              (default: ${CFG_AUTOSTART_USER})

${B}Rice / post-boot:${Z}
  --rice-user USER        Create this non-root user and rice their home
  --rice-user-pass PASS   Password for the rice user
  --dotfiles-repo URL     Git repo to deploy as dotfiles
  --dotfiles-branch B     Branch                          (default: ${DOTFILES_BRANCH})
  --progs-csv URL|PATH    progs.csv defining packages to install on first boot
                          Format: TAG,NAME/URL,DESCRIPTION
                          Tags: D=dietpi-software-id  A=apt  G=git+make  P=pip3
  --kernel-config PATH    Inject custom .config for unattended Pi compilation

${B}Misc:${Z}
  --workdir PATH          Image download directory        (default: ./dietpi_build)
  --keep-image            Keep downloaded .img.xz after flash
  --noninteractive        No prompts; fail on missing required config
  --dry-run               Generate config files only, no flashing
  --help                  This message
USAGE
}

# ── parse_args ────────────────────────────────────────────────────────────────
parse_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--device)
			TARGET_DEVICE="$2"
			shift 2
			;;
		--hostname)
			CFG_HOSTNAME="$2"
			shift 2
			;;
		--password)
			CFG_PASSWORD="$2"
			shift 2
			;;
		--locale)
			CFG_LOCALE="$2"
			shift 2
			;;
		--timezone)
			CFG_TIMEZONE="$2"
			shift 2
			;;
		--keyboard)
			CFG_KEYBOARD="$2"
			shift 2
			;;
		--ssh-server)
			CFG_SSH_INDEX="$2"
			shift 2
			;;
		--survey)
			CFG_SURVEY_OPT="$2"
			shift 2
			;;
		--swapfile-size)
			CFG_SWAPFILE_SIZE="$2"
			shift 2
			;;
		--wifi-ssid)
			CFG_WIFI_SSID="$2"
			CFG_WIFI_ENABLED=1
			shift 2
			;;
		--wifi-pass)
			CFG_WIFI_PASS="$2"
			shift 2
			;;
		--wifi-country)
			CFG_WIFI_COUNTRY="$2"
			shift 2
			;;
		--static-ip)
			CFG_STATIC_ADDR="$2"
			CFG_STATIC_IP=1
			shift 2
			;;
		--static-mask)
			CFG_STATIC_MASK="$2"
			shift 2
			;;
		--static-gw)
			CFG_STATIC_GW="$2"
			shift 2
			;;
		--static-dns)
			CFG_STATIC_DNS="$2"
			shift 2
			;;
		--eth-force-speed)
			CFG_NET_ETH_FORCE_SPEED="$2"
			shift 2
			;;
		--boot-wait-network)
			CFG_BOOT_WAIT_FOR_NETWORK="$2"
			shift 2
			;;
		--software-ids)
			CFG_SOFTWARE_IDS="$2"
			shift 2
			;;
		--apt-packages)
			CFG_APT_PACKAGES="$2"
			shift 2
			;;
		--autostart)
			CFG_AUTOSTART_INDEX="$2"
			shift 2
			;;
		--autostart-user)
			CFG_AUTOSTART_USER="$2"
			shift 2
			;;
		--rice-user)
			RICE_USER="$2"
			shift 2
			;;
		--rice-user-pass)
			RICE_USER_PASS="$2"
			shift 2
			;;
		--dotfiles-repo)
			DOTFILES_REPO="$2"
			shift 2
			;;
		--dotfiles-branch)
			DOTFILES_BRANCH="$2"
			shift 2
			;;
		--progs-csv)
			PROGS_CSV_URL="$2"
			shift 2
			;;
		--kernel-config)
			KERNEL_CONFIG="$2"
			shift 2
			;;
		--workdir)
			WORK_DIR="$2"
			shift 2
			;;
		--keep-image)
			KEEP_IMAGE=1
			shift
			;;
		--noninteractive)
			NONINTERACTIVE=1
			shift
			;;
		--dry-run)
			DRY_RUN=1
			shift
			;;
		--help | -h)
			usage
			exit 0
			;;
		*) fatal "Unknown option: $1  (try --help)" ;;
		esac
	done
}

# ── whiptail TUI wizard ───────────────────────────────────────────────────────
_wt_available() { command -v whiptail >/dev/null 2>&1; }

_wt_input() {
	local var="$1" prompt="$2" default="$3"
	local val
	if _wt_available; then
		val=$(whiptail --inputbox "${prompt}" 10 60 "${default}" 3>&1 1>&2 2>&3) || return 1
	else
		ask "${prompt} [${default}]: "
		read -r val
		val="${val:-${default}}"
	fi
	printf -v "${var}" '%s' "${val}"
}

_wt_pass() {
	local var="$1" prompt="$2"
	local p1 p2
	while true; do
		if _wt_available; then
			p1=$(whiptail --passwordbox "${prompt}" 10 60 3>&1 1>&2 2>&3) || return 1
			p2=$(whiptail --passwordbox "Confirm password." 10 60 3>&1 1>&2 2>&3) || return 1
		else
			ask "${prompt}: "
			read -rs p1
			echo
			ask "Confirm: "
			read -rs p2
			echo
		fi
		[[ "${p1}" == "${p2}" ]] && break
		if _wt_available; then
			whiptail --msgbox "Passwords do not match. Try again." 8 50
		else
			warn "Passwords do not match. Try again."
		fi
	done
	printf -v "${var}" '%s' "${p1}"
}

_wt_yesno() {
	local prompt="$1"
	if _wt_available; then
		whiptail --yesno "${prompt}" 10 60 3>&1 1>&2 2>&3
	else
		ask "${prompt} [y/N]: "
		local a
		read -r a
		[[ "${a,,}" == "y" ]]
	fi
}

_wt_msg() {
	if _wt_available; then
		whiptail --title "${1}" --msgbox "${2}" 12 70
	else
		info "${2}"
	fi
}

run_wizard() {
	[[ "${NONINTERACTIVE}" -eq 1 ]] && return

	_wt_msg "DietPi RPi4 Rice Script v${SCRIPT_VERSION}" \
		"This script will:\n\n  1. Flash DietPi to your SD card\n  2. Configure unattended first-boot\n  3. Deploy a post-boot rice script\n\nEnsure the target SD card is inserted."

	if [[ -z "${TARGET_DEVICE}" && "${DRY_RUN}" -eq 0 ]]; then
		local dev_list
		dev_list=$(lsblk -dpno NAME,SIZE,MODEL 2>/dev/null | grep -v "loop" | awk '{printf "%s\t%s %s\n", $1, $2, $3}' || printf "/dev/sdb\tUnknown\n")
		if _wt_available; then
			local dev_array=()
			while IFS=$'\t' read -r dev desc; do
				[[ -n "$dev" ]] && dev_array+=("$dev" "$desc")
			done <<<"$dev_list"

			TARGET_DEVICE=$(whiptail --title "Select Target Device" \
				--menu "Choose the SD card to flash.\nWARNING: ALL DATA WILL BE ERASED." \
				20 70 10 \
				"${dev_array[@]}" \
				3>&1 1>&2 2>&3) || fatal "Aborted."
		else
			info "Available block devices:"
			while IFS=$'\t' read -r dev desc; do
				[[ -n "$dev" ]] && echo "  $dev  $desc"
			done <<<"$dev_list"
			ask "Target device (e.g. /dev/sdb): "
			read -r TARGET_DEVICE
		fi
	fi

	_wt_input CFG_HOSTNAME "Hostname for the Pi:" "${CFG_HOSTNAME}"
	_wt_pass CFG_PASSWORD "Root / global password:"
	_wt_input CFG_TIMEZONE "Timezone (tz database, e.g. America/Matamoros):" "${CFG_TIMEZONE}"
	_wt_input CFG_LOCALE "Locale (e.g. en_US.UTF-8):" "${CFG_LOCALE}"
	_wt_input CFG_KEYBOARD "Keyboard layout (e.g. us, gb, de):" "${CFG_KEYBOARD}"

	if _wt_available; then
		CFG_SSH_INDEX=$(whiptail --title "SSH Server" \
			--menu "Select SSH server:" 12 50 3 \
			"-2" "OpenSSH" \
			"0" "Dropbear" \
			"-1" "None" \
			3>&1 1>&2 2>&3) || CFG_SSH_INDEX="-1"
	fi

	if _wt_yesno "Enable WiFi?"; then
		CFG_WIFI_ENABLED=1
		_wt_input CFG_WIFI_SSID "WiFi SSID:" "${CFG_WIFI_SSID}"
		_wt_pass CFG_WIFI_PASS "WiFi passphrase:"
		_wt_input CFG_WIFI_COUNTRY "WiFi country code (ISO 3166-1 alpha-2, e.g. US, GB):" "${CFG_WIFI_COUNTRY}"
	fi

	if _wt_yesno "Use a static IP address? (No = DHCP)"; then
		CFG_STATIC_IP=1
		_wt_input CFG_STATIC_ADDR "Static IP address:" "${CFG_STATIC_ADDR}"
		_wt_input CFG_STATIC_GW "Default gateway:" "${CFG_STATIC_GW}"
		_wt_input CFG_STATIC_DNS "DNS server:" "${CFG_STATIC_DNS}"
		_wt_input CFG_STATIC_MASK "Subnet mask:" "${CFG_STATIC_MASK}"
	fi

	if _wt_available; then
		local sw_choices
		sw_choices=$(whiptail --title "dietpi-software packages" \
			--checklist "Select software to auto-install (Space=toggle):" \
			25 70 15 \
			"93" "Pi-hole (ad blocker)" OFF \
			"114" "Nextcloud (personal cloud)" OFF \
			"42" "Plex Media Server" OFF \
			"76" "Jellyfin (media server)" OFF \
			"111" "Home Assistant" OFF \
			"83" "OpenVPN" OFF \
			"84" "WireGuard" OFF \
			"32" "Grafana (dashboards)" OFF \
			"72" "InfluxDB (time-series DB)" OFF \
			"185" "Node-RED (automation)" OFF \
			"99" "Transmission (torrent)" OFF \
			"37" "Samba (Windows file share)" OFF \
			"152" "DietPi-Dashboard (web panel)" OFF \
			"103" "DietPi-RAMlog (minimal logging)" ON \
			3>&1 1>&2 2>&3) || sw_choices=""
		CFG_SOFTWARE_IDS=$(echo "${sw_choices}" | tr -d '"' | tr ' ' '\n' | tr '\n' ' ' | xargs)
	else
		ask "dietpi-software IDs to install (space-separated, Enter to skip): "
		read -r CFG_SOFTWARE_IDS
	fi

	_wt_input CFG_APT_PACKAGES \
		"Extra APT packages to install (space-separated, Enter to skip):" \
		"${CFG_APT_PACKAGES}"

	if _wt_yesno "Create a non-root user for daily use?"; then
		_wt_input RICE_USER "Username:" "${RICE_USER}"
		_wt_pass RICE_USER_PASS "Password for ${RICE_USER}:"
	else
		RICE_USER="root"
	fi

	if _wt_yesno "Deploy dotfiles from a git repository?"; then
		_wt_input DOTFILES_REPO "Dotfiles git URL:" "${DOTFILES_REPO}"
		_wt_input DOTFILES_BRANCH "Branch:" "${DOTFILES_BRANCH}"
	fi

	if _wt_yesno "Install packages from a progs.csv file?"; then
		_wt_input PROGS_CSV_URL \
			"URL or absolute path to progs.csv:" \
			"${PROGS_CSV_URL}"
	fi

	if _wt_yesno "Opt IN to the DietPi anonymous usage survey?\n(Helps the project; no private data sent)"; then
		CFG_SURVEY_OPT=1
	else
		CFG_SURVEY_OPT=0
	fi

	if [[ "${DRY_RUN}" -eq 0 ]]; then
		_wt_yesno "Flash to ${TARGET_DEVICE} and configure?\nALL DATA ON ${TARGET_DEVICE} WILL BE DESTROYED." ||
			fatal "Aborted by user."
	fi
}

# ── Validate ──────────────────────────────────────────────────────────────────
validate_config() {
	if [[ "${DRY_RUN}" -eq 0 ]]; then
		[[ -n "${TARGET_DEVICE}" ]] || fatal "No target device. Use --device or run the wizard."
		[[ -b "${TARGET_DEVICE}" ]] || fatal "Not a block device: ${TARGET_DEVICE}"
		local root_dev
		root_dev="$(df / --output=source 2>/dev/null | tail -1 || echo '')"
		[[ "${root_dev}" == "${TARGET_DEVICE}"* ]] &&
			fatal "Refusing: ${TARGET_DEVICE} contains the running root filesystem."
	fi
	[[ "${CFG_WIFI_ENABLED}" -eq 1 && -z "${CFG_WIFI_SSID}" ]] &&
		fatal "WiFi enabled but --wifi-ssid not set."
	[[ "${CFG_STATIC_IP}" -eq 1 && -z "${CFG_STATIC_ADDR}" ]] &&
		fatal "Static IP requested but --static-ip not set."
	[[ "${CFG_STATIC_IP}" -eq 1 && -z "${CFG_STATIC_GW}" ]] &&
		fatal "Static IP requested but --static-gw not set."
	[[ -n "${KERNEL_CONFIG}" && ! -f "${KERNEL_CONFIG}" ]] &&
		fatal "Kernel config file not found: ${KERNEL_CONFIG}"
}

check_deps() {
	local miss=()
	for c in sha256sum dd lsblk mount umount xz; do
		command -v "$c" >/dev/null 2>&1 || miss+=("$c")
	done
	command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || miss+=("curl or wget")
	[[ "${#miss[@]}" -eq 0 ]] || fatal "Missing host tools: ${miss[*]}"
}

# ── Download helpers ──────────────────────────────────────────────────────────
_dl() {
	local url="$1" out="$2"
	if command -v curl >/dev/null 2>&1; then
		curl -fsSL --progress-bar -o "${out}" "${url}"
	else
		wget -q --show-progress -O "${out}" "${url}"
	fi
}

fetch_image() {
	mkdir -p "${WORK_DIR}"
	local xz="${WORK_DIR}/DietPi_RPi4.img.xz"
	local img="${WORK_DIR}/DietPi_RPi4.img"
	local sha="${WORK_DIR}/DietPi_RPi4.img.xz.sha256"

	if [[ ! -f "${img}" ]]; then
		[[ -f "${xz}" ]] || {
			log "Downloading DietPi image..."
			_dl "${DIETPI_IMAGE_URL}" "${xz}"
		}
		log "Verifying checksum..."
		_dl "${DIETPI_SHA256_URL}" "${sha}"
		local exp act
		exp="$(awk '{print $1}' "${sha}")"
		act="$(sha256sum "${xz}" | awk '{print $1}')"
		[[ "${act}" == "${exp}" ]] || fatal "SHA-256 mismatch! exp=${exp} got=${act}"
		log "Checksum OK. Decompressing..."
		xz -d --keep "${xz}"
		[[ "${KEEP_IMAGE}" -eq 0 ]] && rm -f "${xz}"
	else
		log "Using existing image: ${img}"
	fi
	echo "${img}"
}

flash_image() {
	local img="$1" dev="$2"
	info "Flashing ${img} → ${dev}  (this takes a few minutes)..."
	run 600 dd if="${img}" of="${dev}" bs=4M conv=fsync status=progress
	sync
	partprobe "${dev}" 2>/dev/null || true
	sleep 2
	log "Flash complete."
}

mount_boot() {
	local dev="$1"
	_MOUNT_POINT="$(mktemp -d /tmp/dietpi_boot_XXXXXX)"
	local part
	if [[ "${dev}" =~ mmcblk[0-9]+$ || "${dev}" =~ loop[0-9]+$ ]]; then
		part="${dev}p1"
	else
		part="${dev}1"
	fi
	log "Mounting ${part} → ${_MOUNT_POINT}..."
	mount "${part}" "${_MOUNT_POINT}" ||
		fatal "Cannot mount ${part}. Did the flash succeed?"
}

# ── Generate dietpi.txt ───────────────────────────────────────────────────────
generate_dietpi_txt() {
	local dir="$1"
	local txt="${dir}/dietpi.txt"

	if [[ ! -f "${txt}" ]]; then
		log "Fetching canonical dietpi.txt for dry-run/missing file..."
		curl -fsSL "https://raw.githubusercontent.com/MichaIng/DietPi/master/dietpi.txt" >"${txt}" || touch "${txt}"
	fi

	log "Targeting and aligning Config_Knobs in dietpi.txt..."

	sed -i "s|^#*AUTO_SETUP_GLOBAL_PASSWORD=.*|AUTO_SETUP_GLOBAL_PASSWORD=${CFG_PASSWORD}|" "${txt}"
	sed -i "s|^#*AUTO_SETUP_LOCALE=.*|AUTO_SETUP_LOCALE=${CFG_LOCALE}|" "${txt}"
	sed -i "s|^#*AUTO_SETUP_KEYBOARD_LAYOUT=.*|AUTO_SETUP_KEYBOARD_LAYOUT=${CFG_KEYBOARD}|" "${txt}"
	sed -i "s|^#*AUTO_SETUP_TIMEZONE=.*|AUTO_SETUP_TIMEZONE=${CFG_TIMEZONE}|" "${txt}"
	sed -i "s|^#*AUTO_SETUP_NET_HOSTNAME=.*|AUTO_SETUP_NET_HOSTNAME=${CFG_HOSTNAME}|" "${txt}"
	sed -i "s|^#*AUTO_SETUP_SSH_SERVER_INDEX=.*|AUTO_SETUP_SSH_SERVER_INDEX=${CFG_SSH_INDEX}|" "${txt}"
	sed -i "s|^#*AUTO_SETUP_NET_WIFI_ENABLED=.*|AUTO_SETUP_NET_WIFI_ENABLED=${CFG_WIFI_ENABLED}|" "${txt}"
	sed -i "s|^#*AUTO_SETUP_NET_WIFI_COUNTRY_CODE=.*|AUTO_SETUP_NET_WIFI_COUNTRY_CODE=${CFG_WIFI_COUNTRY}|" "${txt}"
	sed -i "s|^#*AUTO_SETUP_NET_USESTATIC=.*|AUTO_SETUP_NET_USESTATIC=${CFG_STATIC_IP}|" "${txt}"
	sed -i "s|^#*AUTO_SETUP_NET_STATIC_IP=.*|AUTO_SETUP_NET_STATIC_IP=${CFG_STATIC_ADDR}|" "${txt}"
	sed -i "s|^#*AUTO_SETUP_NET_STATIC_MASK=.*|AUTO_SETUP_NET_STATIC_MASK=${CFG_STATIC_MASK}|" "${txt}"
	sed -i "s|^#*AUTO_SETUP_NET_STATIC_GATEWAY=.*|AUTO_SETUP_NET_STATIC_GATEWAY=${CFG_STATIC_GW}|" "${txt}"
	sed -i "s|^#*AUTO_SETUP_NET_STATIC_DNS=.*|AUTO_SETUP_NET_STATIC_DNS=${CFG_STATIC_DNS}|" "${txt}"
	sed -i "s|^#*CONFIG_CHECK_DIETPI_UPDATES=.*|CONFIG_CHECK_DIETPI_UPDATES=${CFG_AUTO_UPDATE}|" "${txt}"
	sed -i "s|^#*CONFIG_CHECK_APT_UPDATES=.*|CONFIG_CHECK_APT_UPDATES=${CFG_APT_UPDATE}|" "${txt}"
	sed -i "s|^#*AUTO_SETUP_AUTOSTART_TARGET_INDEX=.*|AUTO_SETUP_AUTOSTART_TARGET_INDEX=${CFG_AUTOSTART_INDEX}|" "${txt}"
	sed -i "s|^#*AUTO_SETUP_AUTOSTART_LOGIN_USER=.*|AUTO_SETUP_AUTOSTART_LOGIN_USER=${CFG_AUTOSTART_USER}|" "${txt}"
	sed -i "s|^#*SURVEY_OPTED_IN=.*|SURVEY_OPTED_IN=${CFG_SURVEY_OPT}|" "${txt}"
	sed -i "s|^#*AUTO_SETUP_CUSTOM_SCRIPT_EXEC=.*|AUTO_SETUP_CUSTOM_SCRIPT_EXEC=1|" "${txt}"
	sed -i "s|^#*AUTO_SETUP_NET_ETH_FORCE_SPEED=.*|AUTO_SETUP_NET_ETH_FORCE_SPEED=${CFG_NET_ETH_FORCE_SPEED}|" "${txt}"
	sed -i "s|^#*AUTO_SETUP_BOOT_WAIT_FOR_NETWORK=.*|AUTO_SETUP_BOOT_WAIT_FOR_NETWORK=${CFG_BOOT_WAIT_FOR_NETWORK}|" "${txt}"
	sed -i "s|^#*AUTO_SETUP_SWAPFILE_SIZE=.*|AUTO_SETUP_SWAPFILE_SIZE=${CFG_SWAPFILE_SIZE}|" "${txt}"

	if [[ -n "${CFG_SOFTWARE_IDS}" ]]; then
		for id in ${CFG_SOFTWARE_IDS}; do
			echo "AUTO_SETUP_INSTALL_SOFTWARE_ID=${id}" >>"${txt}"
		done
	fi
	if [[ -n "${CFG_APT_PACKAGES}" ]]; then
		sed -i "s|^#*AUTO_SETUP_APT_INSTALLS=.*|AUTO_SETUP_APT_INSTALLS=${CFG_APT_PACKAGES}|" "${txt}"
	fi

	log "dietpi.txt aligned → ${txt}"
}

# ── Generate dietpi-wifi.txt ──────────────────────────────────────────────────
generate_wifi_txt() {
	local dir="$1"
	[[ "${CFG_WIFI_ENABLED}" -eq 0 ]] && return
	local txt="${dir}/dietpi-wifi.txt"

	if [[ ! -f "${txt}" ]]; then
		log "Fetching canonical dietpi-wifi.txt for dry-run/missing file..."
		curl -fsSL "https://raw.githubusercontent.com/MichaIng/DietPi/master/dietpi-wifi.txt" >"${txt}" || touch "${txt}"
	fi

	log "Targeting and aligning WiFi_Injector arrays..."

	# Sanitize single quotes to escape strictly per baseline requirements
	local safe_pass="${CFG_WIFI_PASS//\'/\\\\\'}"

	sed -i "s|^#*aWIFI_SSID\[0\]=.*|aWIFI_SSID[0]='${CFG_WIFI_SSID}'|" "${txt}"
	sed -i "s|^#*aWIFI_KEY\[0\]=.*|aWIFI_KEY[0]='${safe_pass}'|" "${txt}"
	sed -i "s|^#*aWIFI_KEYMGR\[0\]=.*|aWIFI_KEYMGR[0]='WPA-PSK'|" "${txt}"

	log "dietpi-wifi.txt aligned → ${txt}"
}

# ── Generate Automation_Custom_Script.sh ──────────────────────────────────────
# This runs ON THE PI after DietPi's own first-boot automation completes.
# It is the equivalent of 4ndr0666.sh's main body but for DietPi/Debian.
generate_post_script() {
	local dir="$1"
	local dest="${dir}/Automation_Custom_Script.sh"

	local progs_csv_content=""
	if [[ -n "${PROGS_CSV_URL}" && -f "${PROGS_CSV_URL}" ]]; then
		progs_csv_content="$(cat "${PROGS_CSV_URL}")"
	fi

	cat >"${dest}" <<POST_SCRIPT
#!/bin/bash
# ============================================================================
# DietPi post-install rice script — runs on the Pi after first-boot setup.
# Triggered by: AUTO_SETUP_CUSTOM_SCRIPT_EXEC=1 → /boot/Automation_Custom_Script.sh
# Log: /var/tmp/dietpi/logs/dietpi-firstrun-setup.log (appended)
# ============================================================================
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C LANG=C

# ── Logging ───────────────────────────────────────────────────────────────────
RICE_LOG="/var/log/dietpi_rice.log"
exec > >(tee -a "\${RICE_LOG}") 2>&1
log()  { printf '[rice][*] %s\n' "\$*"; }
warn() { printf '[rice][!] %s\n' "\$*" >&2; }
die()  { printf '[rice][X] %s\n' "\$*" >&2; exit 1; }

log "=== DietPi rice script starting at \$(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
log "Running as: \$(id)"

_source_dietpi_funcs() {
    local func_lib="/boot/dietpi/func/dietpi-globals"
    if [[ -f "\${func_lib}" ]]; then
        # shellcheck source=/dev/null
        . "\${func_lib}"
        export -f G_AGI G_AGP G_AGUP G_AGUG G_AGA 2>/dev/null || true
        log "DietPi shell functions loaded."
    else
        warn "DietPi globals not found; falling back to plain apt-get."
        G_AGI() { apt-get install -y --no-install-recommends "\$@"; }
        G_AGUP() { apt-get update; }
        G_AGUG() { apt-get upgrade -y; }
        G_AGP()  { apt-get purge -y "\$@"; }
        G_AGA()  { apt-get autoremove --purge -y; }
    fi
}
_source_dietpi_funcs

# ── Rice user ────────────────────────────────────────────────────────────────
RICE_USER="${RICE_USER}"
RICE_USER_PASS="${RICE_USER_PASS}"

setup_user() {
    [[ "\${RICE_USER}" == "root" ]] && return
    log "Creating user \${RICE_USER}..."
    if id "\${RICE_USER}" >/dev/null 2>&1; then
        warn "User \${RICE_USER} already exists; skipping creation."
    else
        useradd -m -G sudo,users -s /bin/bash "\${RICE_USER}"
    fi
    [[ -n "\${RICE_USER_PASS}" ]] && echo "\${RICE_USER}:\${RICE_USER_PASS}" | chpasswd
    cat > /etc/sudoers.d/00-riceuser <<SUDOERS
\${RICE_USER} ALL=(ALL:ALL) ALL
\${RICE_USER} ALL=(ALL:ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,\\
/usr/bin/systemctl suspend,/usr/bin/mount,/usr/bin/umount,\\
/usr/bin/apt-get update,/usr/bin/apt-get upgrade
SUDOERS
    chmod 0440 /etc/sudoers.d/00-riceuser
    log "User \${RICE_USER} configured."
}

rice_home() {
    [[ "\${RICE_USER}" == "root" ]] && echo "/root" || echo "/home/\${RICE_USER}"
}

# ── progs.csv installation loop ───────────────────────────────────────────────
PROGS_CSV_URL="${PROGS_CSV_URL}"
PROGS_CSV_INLINE='${progs_csv_content}'

fetch_progs_csv() {
    local out="/tmp/progs.csv"
    if [[ -n "\${PROGS_CSV_INLINE}" ]]; then
        printf '%s\n' "\${PROGS_CSV_INLINE}" > "\${out}"
        log "Using embedded progs.csv."
    elif [[ -n "\${PROGS_CSV_URL}" ]]; then
        log "Downloading progs.csv from \${PROGS_CSV_URL}..."
        curl -fsSL "\${PROGS_CSV_URL}" | grep -v '^#' > "\${out}" \
            || { warn "Failed to download progs.csv; skipping package loop."; return 1; }
    else
        log "No progs.csv specified; skipping package loop."
        return 1
    fi
    sed -i '/^#/d;/^[[:space:]]*$/d' "\${out}"
}

install_dietpi_software() {
    local id="\$1" name="\$2"
    log "  [D] dietpi-software install \${id}  # \${name}"
    /boot/dietpi/dietpi-software install "\${id}" \
        || warn "  dietpi-software \${id} failed (non-fatal)."
}

install_apt() {
    local pkg="\$1" desc="\$2"
    log "  [A] apt install \${pkg}  # \${desc}"
    G_AGI "\${pkg}" || warn "  apt install \${pkg} failed (non-fatal)."
}

install_git_make() {
    local url="\$1" desc="\$2"
    local name
    name="\$(basename "\${url}" .git)"
    local dir="/tmp/rice_src/\${name}"
    log "  [G] git+make \${name}  # \${desc}"
    mkdir -p "\${dir}"
    git clone --depth 1 --single-branch -q "\${url}" "\${dir}" 2>/dev/null \
        || { cd "\${dir}"; git pull --force origin HEAD; }
    cd "\${dir}"
    make -j"\$(nproc)" >/dev/null 2>&1 && make install >/dev/null 2>&1 \
        || warn "  git+make \${name} failed (non-fatal)."
    cd /tmp
}

install_pip() {
    local pkg="\$1" desc="\$2"
    log "  [P] pip3 install \${pkg}  # \${desc}"
    command -v pip3 >/dev/null 2>&1 || G_AGI python3-pip
    pip3 install --quiet "\${pkg}" || warn "  pip3 \${pkg} failed (non-fatal)."
}

run_progs_loop() {
    fetch_progs_csv || return 0
    local total n=0
    total="\$(wc -l < /tmp/progs.csv)"
    log "Installing \${total} package(s) from progs.csv..."
    while IFS=, read -r tag name desc; do
        n=\$((n+1))
        desc="\$(echo "\${desc}" | sed -E 's/^"|"$//g')"
        log "[\${n}/\${total}] \${tag} \${name}"
        case "\${tag}" in
            D) install_dietpi_software "\${name}" "\${desc}" ;;
            A) install_apt             "\${name}" "\${desc}" ;;
            G) install_git_make        "\${name}" "\${desc}" ;;
            P) install_pip             "\${name}" "\${desc}" ;;
            *) warn "Unknown tag '\${tag}' for \${name}; skipping." ;;
        esac
    done < /tmp/progs.csv
    log "Package loop complete."
}

# ── Dotfiles ──────────────────────────────────────────────────────────────────
DOTFILES_REPO="${DOTFILES_REPO}"
DOTFILES_BRANCH="${DOTFILES_BRANCH}"

deploy_dotfiles() {
    [[ -z "\${DOTFILES_REPO}" ]] && return
    local home
    home="\$(rice_home)"
    local tmpdir
    tmpdir="\$(mktemp -d)"
    log "Deploying dotfiles from \${DOTFILES_REPO} (\${DOTFILES_BRANCH}) → \${home}..."
    git clone --depth 1 --single-branch --no-tags -q \
        -b "\${DOTFILES_BRANCH}" "\${DOTFILES_REPO}" "\${tmpdir}" \
        || die "Dotfiles clone failed."
    rsync -a --exclude='.git' --exclude='README*' --exclude='LICENSE*' \
        "\${tmpdir}/" "\${home}/"
    chown -R "\${RICE_USER}:\${RICE_USER}" "\${home}" 2>/dev/null || true
    rm -rf "\${tmpdir}"
    log "Dotfiles deployed."
}

# ── System hardening / quality-of-life ───────────────────────────────────────
harden_system() {
    log "Applying system hardening and QoL settings..."
    rmmod pcspkr 2>/dev/null || true
    echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf

    mkdir -p /etc/sysctl.d
    echo "kernel.dmesg_restrict = 0" > /etc/sysctl.d/dmesg.conf
    sysctl -p /etc/sysctl.d/dmesg.conf >/dev/null 2>&1 || true

    cat > /etc/profile.d/dietpi_rice.sh <<'PROFILE'
alias ll='ls -lAh --color=auto'
alias la='ls -A --color=auto'
alias df='df -h'
alias free='free -h'
alias update='apt-get update && apt-get upgrade -y'
alias cpuinfo='cpu'
alias benchmark='dietpi-benchmark'
PROFILE
    log "Hardening complete."
}

configure_dietpi_tools() {
    log "Configuring DietPi misc tools..."
    if command -v dietpi-survey >/dev/null 2>&1; then
        dietpi-survey 1 >/dev/null 2>&1 || true
    fi

    for app in sonarr radarr lidarr prowlarr; do
        if systemctl list-units --type=service 2>/dev/null | grep -q "\${app}"; then
            log "  Enabling \${app} DB-to-RAM on boot..."
            dietpi-servarr_to_ram enable 2>/dev/null || true
            break
        fi
    done

    if command -v dietpi-benchmark >/dev/null 2>&1; then
        log "  Running full benchmark suite (background)..."
        nohup dietpi-benchmark 2 > /var/log/dietpi_benchmark.log 2>&1 &
    fi
    log "DietPi tools configured."
}

# ── Kernel Compilation (Path B) ───────────────────────────────────────────────
build_custom_kernel() {
    local cfg="/boot/config-6.18.34+rpt-rpi-v8"
    if [[ ! -f "\${cfg}" ]]; then
        return 0
    fi
    log "Custom kernel configuration found. Initiating native compile (this will take time)..."
    G_AGI git bc bison flex libssl-dev make libc6-dev libncurses5-dev build-essential
    
    local src_dir="/usr/src/linux"
    if [[ ! -d "\${src_dir}" ]]; then
        log "Cloning Raspberry Pi Linux tree..."
        git clone --depth=1 -b rpi-6.1.y https://github.com/raspberrypi/linux.git "\${src_dir}"
    fi
    
    cd "\${src_dir}"
    cp "\${cfg}" .config
    log "Configuring kernel..."
    make olddefconfig
    
    log "Compiling kernel..."
    make -j"\$(nproc)" Image.gz modules dtbs
    
    log "Installing modules..."
    make modules_install
    
    log "Deploying kernel to /boot..."
    cp arch/arm64/boot/Image.gz /boot/kernel8.img
    cp arch/arm64/boot/dts/broadcom/*.dtb /boot/
    mkdir -p /boot/overlays
    cp arch/arm64/boot/dts/overlays/*.dtb* /boot/overlays/
    cp arch/arm64/boot/dts/overlays/README /boot/overlays/
    
    log "Kernel compilation and deployment complete."
}

# ── Finalize ──────────────────────────────────────────────────────────────────
finalize() {
    log "Cleaning up..."
    G_AGA 2>/dev/null || apt-get autoremove --purge -y 2>/dev/null || true
    apt-get clean 2>/dev/null || true
    log ""
    log "╔══════════════════════════════════════════════╗"
    log "║      DietPi rice complete!                   ║"
    log "╠══════════════════════════════════════════════╣"
    log "║  Hostname  : \$(hostname)                       "
    log "║  Rice log  : \${RICE_LOG}                       "
    log "║  Benchmark : /var/log/dietpi_benchmark.log    "
    log "║  CPU info  : run 'cpu' at any time            "
    log "╚══════════════════════════════════════════════╝"
    log ""
    log "=== DietPi rice script finished at \$(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
}

main() {
    setup_user
    G_AGUP
    run_progs_loop
    deploy_dotfiles
    harden_system
    configure_dietpi_tools
    build_custom_kernel
    finalize
}

main
POST_SCRIPT

	chmod +x "${dest}"
	log "Automation_Custom_Script.sh → ${dest}"
}

# ── Summary ───────────────────────────────────────────────────────────────────
print_summary() {
	echo
	info "══════════════════════════════════════════════════"
	info " Configuration summary"
	info "══════════════════════════════════════════════════"
	info " Target     : ${TARGET_DEVICE:-<dry-run>}"
	info " Hostname   : ${CFG_HOSTNAME}"
	info " Timezone   : ${CFG_TIMEZONE}  Locale: ${CFG_LOCALE}"
	info " Keyboard   : ${CFG_KEYBOARD}  SSH: ${CFG_SSH_INDEX}"
	info " WiFi       : $([[ "${CFG_WIFI_ENABLED}" -eq 1 ]] && echo "SSID=${CFG_WIFI_SSID} (${CFG_WIFI_COUNTRY})" || echo "Ethernet/DHCP")"
	info " IP         : $([[ "${CFG_STATIC_IP}" -eq 1 ]] && echo "static ${CFG_STATIC_ADDR} gw ${CFG_STATIC_GW}" || echo "DHCP")"
	info " Survey     : $([[ "${CFG_SURVEY_OPT}" -eq 1 ]] && echo "opt-in" || echo "opt-out")"
	info " SW IDs     : ${CFG_SOFTWARE_IDS:-none}"
	info " APT pkgs   : ${CFG_APT_PACKAGES:-none}"
	info " Rice user  : ${RICE_USER}"
	info " Dotfiles   : ${DOTFILES_REPO:-none}"
	info " progs.csv  : ${PROGS_CSV_URL:-none (skip)}"
	info " Kernel Cfg : ${KERNEL_CONFIG:-none}"
	info "══════════════════════════════════════════════════"
	echo
}

# ── main ──────────────────────────────────────────────────────────────────────
main() {
	log "${SCRIPT_NAME} v${SCRIPT_VERSION}"
	parse_args "$@"

	if [[ "${DRY_RUN}" -eq 1 ]]; then
		info "Dry-run: generating config files only → ${WORK_DIR}/"
		mkdir -p "${WORK_DIR}"
		validate_config
		print_summary
		generate_dietpi_txt "${WORK_DIR}"
		generate_wifi_txt "${WORK_DIR}"
		generate_post_script "${WORK_DIR}"
		info "Files written:"
		for f in dietpi.txt dietpi-wifi.txt Automation_Custom_Script.sh; do
			[[ -f "${WORK_DIR}/${f}" ]] && info "  ${WORK_DIR}/${f}"
		done
		info "Copy them to the FAT boot partition of a flashed DietPi SD card."
		exit 0
	fi

	[[ "${EUID}" -eq 0 ]] || fatal "Must run as root: sudo ${SCRIPT_NAME} $*"

	_wt_available || warn "whiptail not found — using plain text prompts."
	run_wizard
	validate_config
	check_deps
	print_summary

	local img
	img="$(fetch_image)"
	flash_image "${img}" "${TARGET_DEVICE}"
	mount_boot "${TARGET_DEVICE}"

	generate_dietpi_txt "${_MOUNT_POINT}"
	generate_wifi_txt "${_MOUNT_POINT}"
	generate_post_script "${_MOUNT_POINT}"

	if [[ -n "${KERNEL_CONFIG}" && -f "${KERNEL_CONFIG}" ]]; then
		cp "${KERNEL_CONFIG}" "${_MOUNT_POINT}/config-6.18.34+rpt-rpi-v8"
		log "Injected custom kernel config → ${_MOUNT_POINT}/config-6.18.34+rpt-rpi-v8"
	fi

	sync
	# _cleanup unmounts via EXIT trap

	echo
	log "══════════════════════════════════════════════════"
	log " SD card ready. Insert into your Raspberry Pi 4."
	log "══════════════════════════════════════════════════"
	info " First boot is fully automated — no monitor needed."
	info " SSH access: ssh root@${CFG_HOSTNAME}  (may take 5–30 min)"
	info " Watch log : /var/tmp/dietpi/logs/dietpi-firstrun-setup.log"
	info " Rice log  : /var/log/dietpi_rice.log"
	info " CPU info  : run 'cpu' on the Pi at any time"
	echo
}

main "$@"
