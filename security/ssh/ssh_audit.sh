#!/usr/bin/env bash
# ssh_audit.sh — Deterministic SSH audit + alignment for Kali/Linux hosts
# Version: 3.0.2  |  Author: 4ndr0666

set -Eeuo pipefail
export LC_ALL=C

# ===== Canonical defaults =====
DEFAULT_USER="kali"
DEFAULT_GITHUB_USER="4ndr0666"
DEFAULT_HOSTS=("192.168.1.92")
DEFAULT_MODE="enforce" # enforce | report | strict

# ===== Dirs/paths =====
SSH_DIR="$HOME/.ssh"
CONF="$SSH_DIR/config"
KNOWN="$SSH_DIR/known_hosts"
SOCK_DIR="$SSH_DIR/sockets"
BASE_DIR="$HOME/.ssh_align"
LOG_DIR="$BASE_DIR/logs"
REP_DIR="$BASE_DIR/reports"

# ===== UX helpers =====
say() { printf "%s\n" "$*"; }
ok() { printf "[OK] %s\n" "$*"; }
fail() {
	printf "[!!] %s\n" "$*" >&2
	exit 1
}
ts() { date +"%Y-%m-%d %H:%M:%S"; }
retry() {
	local n=0 max=5 d=1
	until "$@"; do
		n=$((n + 1))
		[[ $n -ge $max ]] && return 1
		sleep "$d"
		d=$((d * 2))
	done
}

show_help() {
	cat <<'EOF'
SSH Audit & Alignment Tool
==========================

Purpose:
  Pin ED25519 host keys, install authorized_keys from GitHub and optional sources,
  harden sshd, verify handshake, and write per-host reports.

Usage:
  ssh_audit.sh [--hosts "ip1 ip2"] [--user USER] [--github USER]
               [--key-url URL] [--key-file PATH]
               [--mode enforce|report|strict]
               [--allow-forwarding yes|no] [--allow-x11 yes|no] [--no-allowusers]
               [--version] [-h|--help]

Defaults:
  user=kali  github=4ndr0666  hosts=192.168.1.92  mode=enforce
  reports in ~/.ssh_align/reports, logs in ~/.ssh_align/logs
EOF
	exit 0
}

show_version() {
	echo "ssh_audit.sh 3.0.2"
	exit 0
}

# ===== Args (initialized from canonical defaults) =====
MODE="$DEFAULT_MODE"
GITHUB_USER="$DEFAULT_GITHUB_USER"
USER="$DEFAULT_USER"
KEY_URL=""
KEY_FILE=""
HOSTS=("${DEFAULT_HOSTS[@]}")
ALLOW_FORWARDING="no"
ALLOW_X11="no"
ENFORCE_ALLOWUSERS="yes"

while [[ $# -gt 0 ]]; do
	case "$1" in
	--mode)
		MODE="${2:?}"
		shift 2
		;;
	--github)
		GITHUB_USER="${2:?}"
		shift 2
		;;
	--user)
		USER="${2:?}"
		shift 2
		;;
	--key-url)
		KEY_URL="${2:?}"
		shift 2
		;;
	--key-file)
		KEY_FILE="${2:?}"
		shift 2
		;;
	--hosts)
		IFS=' ' read -r -a HOSTS <<<"${2:?}"
		shift 2
		;;
	--allow-forwarding)
		ALLOW_FORWARDING="${2:?}"
		shift 2
		;;
	--allow-x11)
		ALLOW_X11="${2:?}"
		shift 2
		;;
	--no-allowusers)
		ENFORCE_ALLOWUSERS="no"
		shift 1
		;;
	--version) show_version ;;
	-h | --help) show_help ;;
	*)
		echo "Unknown arg: $1" >&2
		show_help
		;;
	esac
done

# ===== Pre-flight =====
is_private_ip() {
	local ip="$1"
	[[ "$ip" =~ ^10\.([0-9]{1,3}\.){2}[0-9]{1,3}$ ]] ||
		[[ "$ip" =~ ^192\.168\.([0-9]{1,3})\.[0-9]{1,3}$ ]] ||
		[[ "$ip" =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\.([0-9]{1,3})\.[0-9]{1,3}$ ]]
}

pm_install() {
	if command -v apt-get >/dev/null 2>&1; then
		sudo apt-get update -y >/dev/null
		sudo apt-get install -y openssh-client curl netcat-openbsd >/dev/null
	elif command -v dnf >/dev/null 2>&1; then
		sudo dnf install -y openssh-clients curl nmap-ncat >/dev/null
	elif command -v pacman >/dev/null 2>&1; then
		sudo pacman -Sy --noconfirm openssh curl ncat >/dev/null
	else
		fail "No supported package manager found."
	fi
}

ensure_client_prereqs() {
	mkdir -p "$SSH_DIR" "$SOCK_DIR" "$LOG_DIR" "$REP_DIR"
	chmod 700 "$SSH_DIR" "$SOCK_DIR"
	pm_install
	echo 'net.ipv4.ping_group_range=0 2147483647' | sudo tee /etc/sysctl.d/99-ping.conf >/dev/null
	sudo sysctl --system >/dev/null || true
	if [[ ! -f "$SSH_DIR/id_ed25519" ]]; then
		ssh-keygen -t ed25519 -a 100 -f "$SSH_DIR/id_ed25519" -C "$(whoami)@$(hostname -s)" -N "" >/dev/null
	fi
	chmod 600 "$SSH_DIR/id_ed25519"
	chmod 644 "$SSH_DIR/id_ed25519.pub"
	touch "$KNOWN"
	chmod 600 "$KNOWN"
}

pin_hostkey() {
	local host="$1"
	ssh-keygen -R "$host" >/dev/null 2>&1 || true
	retry ssh-keyscan -t ed25519 -T 5 "$host" >>"$KNOWN" 2>/dev/null || fail "ssh-keyscan failed for $host"
	ssh-keygen -H -f "$KNOWN" >/dev/null || true
	local fpr
	fpr="$(ssh-keyscan -t ed25519 -T 5 "$host" 2>/dev/null | ssh-keygen -lf - | awk '{print $2}')"
	[[ -n "$fpr" ]] || fail "Cannot compute ED25519 fingerprint for $host"
	printf "%s" "$fpr"
}

merge_keys_source() {
	local tmp
	tmp="$(mktemp)"
	: >"$tmp"
	if [[ -n "$KEY_FILE" ]]; then awk 'NF' "$KEY_FILE" >>"$tmp"; fi
	if [[ -n "$KEY_URL" ]]; then curl -fsSL "$KEY_URL" | awk 'NF' >>"$tmp"; fi
	curl -fsSL "https://github.com/${GITHUB_USER}.keys" | awk 'NF' >>"$tmp"
	sort -u "$tmp"
	rm -f "$tmp"
}

write_client_host_block() {
	local host="$1"
	touch "$CONF"
	chmod 600 "$CONF"
	awk '
    BEGIN{skip=0}
    /^Host[[:space:]]+kali$/ {skip=1; next}
    skip==1 && /^Host[[:space:]]+/ {skip=0}
    skip==0 {print}
  ' "$CONF" >"$CONF.new" && mv "$CONF.new" "$CONF"
	cat >>"$CONF" <<EOF
Host kali
    HostName $host
    User $USER
    IdentityFile $SSH_DIR/id_ed25519
    IdentitiesOnly yes
    StrictHostKeyChecking yes
    HashKnownHosts yes
    HostKeyAlgorithms ssh-ed25519
    ControlMaster auto
    ControlPath $SOCK_DIR/%r@%h-%p
    ControlPersist 600
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF
	chmod 600 "$CONF"
}

remote_push_keys() {
	local target="$1"
	local ak_tmp
	ak_tmp="$(mktemp)"
	merge_keys_source >"$ak_tmp"

	local remote_tmp
	remote_tmp="$(ssh "$target" mktemp)"
	scp -q "$ak_tmp" "$target":"$remote_tmp"
	rm -f "$ak_tmp"

	ssh "$target" bash -se <<'EOF'
set -euo pipefail
umask 077
mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
touch "$HOME/.ssh/authorized_keys"; chmod 600 "$HOME/.ssh/authorized_keys"
awk 'NF' "$HOME/.ssh/authorized_keys" "$remote_tmp" | sort -u > "$HOME/.ssh/authorized_keys.new"
mv "$HOME/.ssh/authorized_keys.new" "$HOME/.ssh/authorized_keys"
rm -f "$remote_tmp"
EOF
}

remote_enforce() {
	local target="$1"
	remote_push_keys "$target"
	ssh "$target" \
		ALLOW_FORWARDING="$ALLOW_FORWARDING" \
		ALLOW_X11="$ALLOW_X11" \
		ENFORCE_ALLOWUSERS="$ENFORCE_ALLOWUSERS" \
		USER_REMOTE="$USER" bash -se <<'EOF'
set -euo pipefail
CFG="/etc/ssh/sshd_config"

ensure_kv() {
  local k="$1" v="$2"
  sudo -n sed -i -E "/^[# ]*${k}[[:space:]]/d" "$CFG"
  printf "%s %s\n" "$k" "$v" | sudo -n tee -a "$CFG" >/dev/null
}

ensure_kv "PasswordAuthentication" "no"
ensure_kv "KbdInteractiveAuthentication" "no"
ensure_kv "PubkeyAuthentication" "yes"
ensure_kv "PermitRootLogin" "no"
ensure_kv "X11Forwarding" "${ALLOW_X11}"
ensure_kv "AllowTcpForwarding" "${ALLOW_FORWARDING}"

if [ -f /etc/ssh/ssh_host_ed25519_key ]; then
  sudo -n sed -i -E '/^[# ]*HostKey[[:space:]]/d' "$CFG"
  echo "HostKey /etc/ssh/ssh_host_ed25519_key" | sudo -n tee -a "$CFG" >/dev/null
fi

if [ "${ENFORCE_ALLOWUSERS}" = "yes" ]; then
  sudo -n sed -i -E '/^[# ]*AllowUsers[[:space:]]/d' "$CFG"
  echo "AllowUsers ${USER_REMOTE}" | sudo -n tee -a "$CFG" >/dev/null
fi

sudo -n /usr/sbin/sshd -t
sudo -n /bin/systemctl restart ssh || sudo -n /bin/systemctl restart sshd
EOF
}

remote_report() {
	local target="$1"
	ssh -o BatchMode=yes -o PasswordAuthentication=no -o PubkeyAuthentication=yes "$target" bash -se <<'EOF'
set -euo pipefail
echo "WHOAMI=$(whoami)"
stat -c "SSH_DIR=%a" ~/.ssh 2>/dev/null || echo "SSH_DIR=NONE"
stat -c "AUTH_KEYS=%a" ~/.ssh/authorized_keys 2>/dev/null || echo "AUTH_KEYS=NONE"
sshd -T 2>/dev/null | awk '
/^(passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication|permitrootlogin|x11forwarding|allowtcpforwarding|allowusers)$/ {print toupper($0)}'
ssh-keygen -l -f /etc/ssh/ssh_host_ed25519_key.pub 2>/dev/null || true
systemctl is-active ssh 2>/dev/null || systemctl is-active sshd 2>/dev/null || true
EOF
}

final_verify() {
	local target="$1" host="$2"
	local out
	out="$(ssh -vvv -o ControlMaster=no -o ControlPath=none "$target" 2>&1 || true)"
	echo "$out" | grep -q 'Server host key: ssh-ed25519' || fail "[$host] server host key is not ED25519."
	echo "$out" | grep -q 'Authenticated to .* using "publickey"' || fail "[$host] auth did not use publickey."
}

write_report() {
	local host="$1" fpr="$2" out="$3"
	local rep="$REP_DIR/${host}.md"
	{
		echo "# SSH Alignment Report — ${host}"
		echo "- Timestamp: $(ts)"
		echo "- Host ED25519 FPR: ${fpr}"
		echo "- Mode: ${MODE}"
		echo
		echo "## Effective Server Policy (excerpt)"
		echo '```'
		echo "$out"
		echo '```'
	} >"$rep"
	ok "Report: $rep"
}

logwrap() {
	local host="$1"
	shift
	local lf
	lf="$LOG_DIR/${host}_$(date +%Y%m%dT%H%M%S).log"
	("$@") >"$lf" 2>&1 || {
		echo "See log: $lf" >&2
		return 1
	}
}

# ===== Main =====
ensure_client_prereqs

for host in "${HOSTS[@]}"; do
	is_private_ip "$host" || fail "Non-RFC1918 IP rejected: $host"
	nc -w2 -z "$host" 22 >/dev/null || fail "TCP/22 closed on $host"

	say "[..] ($host) Pinning ED25519 host key"
	fpr="$(pin_hostkey "$host")"
	ok "($host) Pinned fingerprint: $fpr"

	say "[..] ($host) Writing client Host block (alias: kali)"
	write_client_host_block "$host"

	target="${USER}@${host}"

	if ! ssh -o BatchMode=yes -o PasswordAuthentication=no -o PubkeyAuthentication=yes -o ConnectTimeout=5 "$target" true 2>/dev/null; then
		[[ "$MODE" = "report" ]] && fail "($host) Key auth not available in report mode."
		say "[..] ($host) Installing keys and hardening"
		logwrap "$host" remote_enforce "$target"
	elif [[ "$MODE" = "enforce" || "$MODE" = "strict" ]]; then
		say "[..] ($host) Hardening sshd"
		logwrap "$host" remote_enforce "$target"
	fi

	say "[..] ($host) Reporting effective state"
	out="$(remote_report "$target" || true)"

	if [[ "$MODE" = "strict" ]]; then
		echo "$out" | grep -qi '^PUBKEYAUTHENTICATION YES' || fail "($host) PubkeyAuthentication not YES"
		echo "$out" | grep -qi '^PASSWORDAUTHENTICATION NO' || fail "($host) PasswordAuthentication not NO"
		echo "$out" | grep -qi '^KBDINTERACTIVEAUTHENTICATION NO' || fail "($host) KbdInteractiveAuthentication not NO"
		echo "$out" | grep -qi '^PERMITROOTLOGIN NO' || fail "($host) PermitRootLogin not NO"
	fi

	say "[..] ($host) Final handshake verification"
	final_verify "$target" "$host"

	write_report "$host" "$fpr" "$out"
	ok "($host) Alignment complete"
done

ok "All hosts processed successfully."
