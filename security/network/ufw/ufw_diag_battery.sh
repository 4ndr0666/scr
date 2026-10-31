#!/usr/bin/env bash
# Author: 4ndr0666
# ufw_diag_battery.sh — Read-Only Diagnostic Battery for ufw.sh + WireGuard (la)
# Collects all sysctl, routing, policy-rule, fwmark, rp_filter, UFW, and NM
# state required for surgical root-cause verification. Makes ZERO changes.

set -u

OUT_FILE="${1:-/tmp/ufw_diag_report.txt}"

run_probe() {
	local title="$1"
	shift
	printf '\n================================================================================\n'
	printf '### %s\n' "$title"
	printf '### CMD: %s\n' "$*"
	printf '================================================================================\n'
	"$@" 2>&1 || printf '[EXIT STATUS: %d]\n' "$?"
}

{
	printf '# UFW & WIREGUARD SURGICAL DIAGNOSTIC BATTERY\n'
	printf 'Timestamp : %s\n' "$(date -Is)"
	printf 'Host      : %s\n' "$(uname -a)"

	# 1. Sysctl load order & all active sysctl.d files
	run_probe "1. SYSCTL.D FILE INVENTORY & CONTENTS" \
		sh -c 'head -n 100 /etc/sysctl.d/*.conf /run/sysctl.d/*.conf /usr/local/lib/sysctl.d/*.conf /usr/lib/sysctl.d/*.conf /etc/sysctl.conf 2>/dev/null'

	# 2. Live rp_filter, src_valid_mark, ip_forward, disable_ipv6, mptcp values
	run_probe "2. LIVE KERNEL SYSCTL STATE (rp_filter, src_valid_mark, ipv6, mptcp)" \
		sh -c 'sysctl -a 2>/dev/null | grep -E "rp_filter|src_valid_mark|ip_forward|disable_ipv6|accept_ra|net\.mptcp\." | sort'

	# 3. NetworkManager active connections & WireGuard profile configuration (redacting private keys)
	run_probe "3. NETWORKMANAGER CONNECTIONS & WIREGUARD PROFILE SETTINGS" \
		sh -c 'nmcli -f NAME,UUID,TYPE,DEVICE,STATE connection show; echo "---"; for c in $(nmcli -t -f NAME,TYPE connection show | awk -F: "\$2==\"wireguard\"{print \$1}"); do echo "=== Profile: $c ==="; nmcli connection show "$c" | grep -E "connection\.|ipv4\.|ipv6\.|wireguard\." | grep -v "private-key"; done'

	# 4. WireGuard runtime interface state (endpoints, fwmark, allowed-ips, handshakes)
	run_probe "4. WIREGUARD RUNTIME STATE (wg show)" \
		sh -c 'if [ "$(id -u)" -eq 0 ]; then wg show all; else sudo wg show all; fi'

	# 5. IPv4 & IPv6 addresses, routing tables (all tables), and policy routing rules (ip rule)
	run_probe "5. IP ADDRESSES, POLICY RULES (ip rule), AND ALL ROUTING TABLES" \
		sh -c 'ip -d addr show; echo "--- IPv4 RULES ---"; ip -4 rule show; echo "--- IPv6 RULES ---"; ip -6 rule show; echo "--- IPv4 ROUTES (table all) ---"; ip -4 route show table all; echo "--- IPv6 ROUTES (table all) ---"; ip -6 route show table all'

	# 6. Exact route resolution to 1.1.1.1
	run_probe "6. KERNEL ROUTE LOOKUP FOR 1.1.1.1" \
		sh -c 'ip route get 1.1.1.1; ip route get 1.1.1.1 mark 0xca6c 2>/dev/null || true'

	# 7. UFW configuration & active rules
	run_probe "7. UFW DEFAULTS (/etc/default/ufw) & ACTIVE STATUS" \
		sh -c 'cat /etc/default/ufw 2>/dev/null; echo "---"; if [ "$(id -u)" -eq 0 ]; then ufw status numbered; echo "---"; ufw status verbose; else sudo ufw status numbered; echo "---"; sudo ufw status verbose; fi'

	# 8. Underlying Netfilter tables (iptables-save / nft list ruleset)
	run_probe "8. NETFILTER UNDERLYING RULESET (ufw-before-output / mangle / wg)" \
		sh -c 'if [ "$(id -u)" -eq 0 ]; then iptables -S; echo "--- MANGLE ---"; iptables -t mangle -S; echo "--- RAW ---"; iptables -t raw -S; else sudo iptables -S; echo "--- MANGLE ---"; sudo iptables -t mangle -S; echo "--- RAW ---"; sudo iptables -t raw -S; fi'

	# 9. DNS resolver state
	run_probe "9. DNS RESOLVER STATE (/etc/resolv.conf, resolvconf, resolvectl)" \
		sh -c 'ls -la /etc/resolv.conf /etc/resolv.conf.ufw-orig 2>/dev/null; head -n 50 /etc/resolv.conf 2>/dev/null; command -v resolvconf >/dev/null && resolvconf -l 2>/dev/null; command -v resolvectl >/dev/null && resolvectl status 2>/dev/null'

	# 10. Kernel martian / rp_filter / UFW block logs from current boot
	run_probe "10. RECENT KERNEL / UFW / NETWORKMANAGER LOGS (LAST 60 LINES)" \
		sh -c 'journalctl -b -n 60 --no-pager -u NetworkManager -u systemd-networkd -k 2>/dev/null | grep -iE "ufw|martian|rp_filter|wireguard|la:|enp3s0|ipv6" || true'

	# 11. Recent ufw.sh execution log
	run_probe "11. TAIL OF ~/.local/share/logs/ufw.log" \
		sh -c 'tail -n 80 "${XDG_DATA_HOME:-$HOME/.local/share}/logs/ufw.log" 2>/dev/null || true'

} | tee "$OUT_FILE"

printf '\n[+] Diagnostic battery saved to: %s\n' "$OUT_FILE"