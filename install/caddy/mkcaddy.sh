#!/bin/sh
# === MKCADDY === (c) 2026 - 4ndr0666
# Usage: mkcaddy [options] <dir_or_file>
#
# Standalone POSIX-compliant Caddyfile builder & architecture wizard.
# Covers the full gamut of Caddy modules, presets, and directives via an
# interactive #15FFFF-on-black fzf TUI (with POSIX fallback) or CLI flags.

set -eu
set -C

# ---------------------------------------------------------------------------
# Color & Theme Setup (#15FFFF on #000000 black)
# Note: 5-char #15FFF normalized to 6-hex #15FFFF (RGB 21, 255, 255) for TUI.
# ---------------------------------------------------------------------------
HEX_FG="#15ffff"
HEX_BG="#000000"
HEX_HL="#00d7ff"
HEX_BG_ALT="#071a1a"

if [ -t 1 ] || [ -t 2 ]; then
	C_THEME=$(printf '\033[38;2;21;255;255m\033[48;2;0;0;0m')
	C_BOLD=$(printf '\033[1m\033[38;2;21;255;255m\033[48;2;0;0;0m')
	C_DIM=$(printf '\033[38;2;15;165;165m\033[48;2;0;0;0m')
	C_ERR=$(printf '\033[1m\033[38;2;255;85;85m\033[48;2;0;0;0m')
	C_RST=$(printf '\033[0m')
else
	C_THEME=""
	C_BOLD=""
	C_DIM=""
	C_ERR=""
	C_RST=""
fi

FZF_COLORS="bg:${HEX_BG},bg+:${HEX_BG_ALT},fg:${HEX_FG},fg+:${HEX_FG},hl:${HEX_HL},hl+:${HEX_FG},info:${HEX_FG},prompt:${HEX_FG},pointer:${HEX_FG},marker:${HEX_FG},spinner:${HEX_FG},header:${HEX_FG},border:${HEX_FG},gutter:${HEX_BG}"

# ---------------------------------------------------------------------------
# Cleanup & Core Helpers
# ---------------------------------------------------------------------------
TMP_CADDY=""
TMP_SITE=""
cleanup() {
	[ -n "$TMP_CADDY" ] && [ -f "$TMP_CADDY" ] && rm -f -- "$TMP_CADDY"
	[ -n "$TMP_SITE" ] && [ -f "$TMP_SITE" ] && rm -f -- "$TMP_SITE"
	return 0
}
trap cleanup EXIT INT TERM HUP

msg() {
	printf '%s%s%s\n' "$C_THEME" "$*" "$C_RST" >&2
}

bold_msg() {
	printf '%s%s%s\n' "$C_BOLD" "$*" "$C_RST" >&2
}

die() {
	printf '%s[ERROR] %s%s\n' "$C_ERR" "$*" "$C_RST" >&2
	exit 1
}

have_cmd() {
	command -v "$1" >/dev/null 2>&1
}

# Detect the physical LAN IPv4 address, strictly bypassing WireGuard, POINTOPOINT,
# and virtual tunnel interfaces (e.g. `la`, `wg*`, `tun*`) so that running mkcaddy
# while behind a VPN never mistakes the /32 tunnel IP (10.x.x.x) for the LAN IP!
detect_lan_ip() {
	if have_cmd ip; then
		_wg_devs=$(ip -o link show type wireguard 2>/dev/null | awk -F': ' '{print $2}' | cut -d'@' -f1 | tr '\n' ' ' || true)

		# 1. Prefer the default-route physical interface in the main table
		_lan_dev=$(ip -4 route show table main default 2>/dev/null | awk -v wg=" $_wg_devs " '
			{
				for (i = 1; i <= NF; i++) {
					if ($i == "dev") {
						d = $(i+1)
						if (d != "lo" && d !~ /^(tun|tap|wg|ppp|docker|br-|veth|virbr)/ && index(wg, " " d " ") == 0) {
							print d
							exit
						}
					}
				}
			}')
		if [ -n "$_lan_dev" ]; then
			_ip=$(ip -o -4 addr show dev "$_lan_dev" scope global 2>/dev/null | awk '{split($4, a, "/"); print a[1]; exit}')
			if [ -n "$_ip" ]; then
				printf '%s\n' "$_ip"
				return 0
			fi
		fi

		# 2. Fallback: first UP BROADCAST Ethernet/Wi-Fi interface (excludes POINTOPOINT VPN tunnels)
		_bcast_devs=$(ip -o link show up 2>/dev/null | awk -F': ' '/BROADCAST/ && !/POINTOPOINT/ {print $2}' | cut -d'@' -f1 | tr '\n' ' ' || true)
		_ip=$(ip -o -4 addr show up scope global 2>/dev/null | awk -v bcast=" $_bcast_devs " -v wg=" $_wg_devs " '
			{
				d = $2
				if (d == "lo" || d ~ /^(tun|tap|wg|ppp|docker|br-|veth|virbr)/) next
				if (index(wg, " " d " ") > 0) next
				if (bcast != "  " && index(bcast, " " d " ") == 0) next
				split($4, a, "/")
				if (a[2] != "32") {
					print a[1]
					exit
				}
			}')
		if [ -n "$_ip" ]; then
			printf '%s\n' "$_ip"
			return 0
		fi
	fi

	if have_cmd hostname; then
		_ip=$(hostname -I 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i ~ /^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)/) {print $i; exit}}')
		if [ -n "$_ip" ]; then
			printf '%s\n' "$_ip"
			return 0
		fi
	fi
	printf '%s\n' "192.168.1.242"
}

# Detect active WireGuard / POINTOPOINT VPN IPv4 address (if any) so the user can
# optionally bind LAN + VPN + loopback together when behind a tunnel.
detect_vpn_ip() {
	if have_cmd ip; then
		_wg_dev=$(ip -o link show type wireguard 2>/dev/null | awk -F': ' '{print $2; exit}' | cut -d'@' -f1 || true)
		if [ -n "$_wg_dev" ]; then
			_vip=$(ip -o -4 addr show dev "$_wg_dev" scope global 2>/dev/null | awk '{split($4, a, "/"); print a[1]; exit}')
			if [ -n "$_vip" ]; then
				printf '%s\n' "$_vip"
				return 0
			fi
		fi
		_ptp_dev=$(ip -o link show up 2>/dev/null | awk -F': ' '/POINTOPOINT/ {print $2; exit}' | cut -d'@' -f1 || true)
		if [ -n "$_ptp_dev" ]; then
			_vip=$(ip -o -4 addr show dev "$_ptp_dev" scope global 2>/dev/null | awk '{split($4, a, "/"); print a[1]; exit}')
			if [ -n "$_vip" ]; then
				printf '%s\n' "$_vip"
				return 0
			fi
		fi
	fi
	return 1
}

# ---------------------------------------------------------------------------
# Dedicated & Comprehensive Help Menu
# ---------------------------------------------------------------------------
show_help() {
	prog=${0##*/}
	cat <<EOF
${C_BOLD}=== MKCADDY === (c) 2026 - 4ndr0666${C_RST}
${C_THEME}Standalone POSIX-Compliant Caddyfile Architecture & Module Builder${C_RST}
${C_DIM}Theme: #15FFFF (#15FFF) on Black (#000000) | Idempotent & Non-Overwriting${C_RST}

${C_BOLD}USAGE:${C_RST}
  ${C_THEME}${prog} <target_dir_or_file>${C_RST}
  ${C_THEME}${prog} [options] <target_dir_or_file>${C_RST}

${C_BOLD}DESCRIPTION:${C_RST}
  ${C_THEME}Interactive fzf-driven TUI (with POSIX /dev/tty fallback) and CLI generator
  for production-ready Caddyfiles. Supports both popular turnkey architecture
  presets and a full composable module-by-module builder that prompts for every
  required parameter per feature. Running with no arguments displays this help.${C_RST}

${C_BOLD}POPULAR ARCHITECTURE PRESETS (-p <preset>):${C_RST}
  ${C_THEME}file-browser   Static File Server & Interactive Directory Browser (file_server browse,
                 hidden file filters, precompressed sidecars, zstd/gzip encoding)
  m3u-streamer   Dynamic M3U Media Streaming Server (templates + listFiles URL-safe
                 responder for videos/images/both + file_server)
  reverse-proxy  Single or Load-Balanced Reverse Proxy (upstreams, lb_policy, active &
                 passive health checks, WebSocket/streaming flush, header_up rules)
  spa-api        Single-Page Application (try_files -> /index.html) + split /api/*
                 reverse_proxy + immutable static asset Cache-Control headers
  php-webapp     PHP-FPM / FastCGI Server (php_fastcgi unix socket or TCP, file_server,
                 zstd/gzip compression, dotfile protection for WordPress/Laravel/Nextcloud)
  secure-gateway Hardened Reverse Proxy Gateway (basic_auth or forward_auth via
                 Authelia/Authentik/OAuth2-Proxy + HSTS/CSP security headers + logging)
  multi-service  Path-Routed Multi-Service Gateway (handle_path / handle routing across
                 multiple backend microservices and static roots)
  redirect-canon Domain Canonicalization & Redirection (www <-> apex 308 redirects,
                 HTTPS enforcement, custom URI rewrites)
  custom         Full Composable Module Builder (interactively mix & match any combination
                 of Caddy modules, global options, and multiple site blocks)${C_RST}

${C_BOLD}SUPPORTED CADDY MODULES & CAPABILITIES (COMPOSABLE IN TUI):${C_RST}
  ${C_THEME}1. Global Options Block   admin (off/addr), email, acme_ca (LetsEncrypt/ZeroSSL/staging),
                            auto_https, local_certs, http_port, https_port, servers protocols
  2. Site & Bindings        Hostnames, ports (:3000, :80, :443), bind IPs (LAN, loopback, 0.0.0.0)
  3. TLS & PKI (tls)        Auto ACME, tls internal (local CA), custom cert/key, DNS-01 challenge
                            (cloudflare, route53, duckdns, digitalocean, hetzner)
  4. File Server            root, file_server, browse (with optional custom template), hide
                            patterns, index files, precompressed (zstd, br, gzip)
  5. Dynamic Templates      templates mime, dynamic M3U playlist responder (videos/images/both)
  6. Reverse Proxy          Single/multi upstreams, lb_policy (round_robin, least_conn, random,
                            first, ip_hash, uri_hash), health_uri/interval/timeout/status,
                            fail_duration/max_fails, header_up/header_down, flush_interval, HTTPS
                            backend tls_insecure_skip_verify
  7. PHP FastCGI            php_fastcgi (unix//run/php/php-fpm.sock or TCP host:port), split/index
  8. SPA & Static Routing   try_files {path} {path}/ /index.html, immutable asset caching matchers
  9. Authentication         basic_auth (bcrypt user/hash) & forward_auth (Authelia/Authentik/OAuth2
                            with uri and copy_headers)
  10. Headers & CORS        Security headers (HSTS, X-Frame-Options, X-Content-Type-Options,
                            Referrer-Policy, CSP, -Server) + full CORS preflight & origin rules
  11. Compression (encode)  zstd, br (Brotli), gzip content encoding
  12. Rewrites & Redirects  redir (301/302/307/308), rewrite, uri strip_prefix, handle_path
  13. Access Control & Err  @blocked remote_ip matchers (private_ranges / CIDR allow or deny),
                            handle_errors custom status pages or JSON error responders
  14. Structured Logging    log output file (with roll_size, roll_keep, roll_keep_for) or stdout,
                            format (json / console), level (INFO / DEBUG / WARN / ERROR)${C_RST}

${C_BOLD}CLI OPTIONS:${C_RST}
  ${C_THEME}-p <preset>  Select architecture preset (see list above)
  -a <addr>    Site address / port (e.g. :3000, example.com, http://localhost:8080)
  -b <ips>     Bind address(es) (e.g. "192.168.1.242 127.0.0.1" or "0.0.0.0")
  -r <path>    Root directory for file_server / templates / SPA / PHP
  -u <upstr>   Upstream address(es) for reverse_proxy or php_fastcgi
  -t <media>   Media filter for m3u-streamer preset: both | videos | images
  -B           Enable interactive file browser (file_server browse)
  -E           Enable zstd + gzip compression (encode zstd gzip)
  -S           Enable hardened HTTP security headers preset
  -n           Non-interactive mode (use flags and sensible defaults without prompts)
  -h           Display this comprehensive help menu${C_RST}

${C_BOLD}EXAMPLES:${C_RST}
  ${C_THEME}${prog} .                                    # Launch interactive TUI in current dir
  ${C_THEME}${prog} -p file-browser -a :8080 -B /srv/pub # Non-interactive file browser setup
  ${C_THEME}${prog} -n -p reverse-proxy -a app.local -u 127.0.0.1:5000 ./Caddyfile
  ${C_THEME}${prog} -n -p m3u-streamer -a :3000 -t videos /s4/s4Downloads${C_RST}
EOF
}

# ---------------------------------------------------------------------------
# TUI Helpers (fzf with #15FFFF on black + POSIX /dev/tty fallback)
# ---------------------------------------------------------------------------
tui_select() {
	_prompt=$1
	shift

	if [ "${OPT_NONINTERACTIVE:-0}" -eq 1 ]; then
		printf '%s\n' "$1"
		return 0
	fi

	if have_cmd fzf && [ -t 0 ] && [ -t 2 ]; then
		_choice=$(
			for _item in "$@"; do
				printf '%s\n' "$_item"
			done | fzf \
				--ansi \
				--no-multi \
				--height=50% \
				--layout=reverse \
				--border=rounded \
				--prompt="${_prompt} > " \
				--header="=== MKCADDY === (Enter: select | Esc: default)" \
				--color="$FZF_COLORS" \
				2>/dev/tty || true
		)
		if [ -n "$_choice" ]; then
			printf '%s\n' "$_choice"
			return 0
		fi
	fi

	if [ -t 0 ] && [ -t 2 ]; then
		bold_msg "=== ${_prompt} ==="
		_idx=1
		for _item in "$@"; do
			printf '%s  [%d] %s%s\n' "$C_THEME" "$_idx" "$_item" "$C_RST" >&2
			_idx=$((_idx + 1))
		done
		printf '%sSelect [1-%d] (default: 1): %s' "$C_BOLD" "$#" "$C_RST" >&2
		IFS= read -r _ans </dev/tty || _ans=""
		case $_ans in
			''|*[!0-9]*) _ans=1 ;;
		esac
		if [ "$_ans" -lt 1 ] || [ "$_ans" -gt "$#" ]; then
			_ans=1
		fi
		_cur=1
		for _item in "$@"; do
			if [ "$_cur" -eq "$_ans" ]; then
				printf '%s\n' "$_item"
				return 0
			fi
			_cur=$((_cur + 1))
		done
	fi

	printf '%s\n' "$1"
}

tui_input() {
	_label=$1
	_def=$2
	if [ "${OPT_NONINTERACTIVE:-0}" -eq 0 ] && [ -t 0 ] && [ -t 2 ]; then
		printf '%s%s [%s]: %s' "$C_BOLD" "$_label" "$_def" "$C_RST" >&2
		IFS= read -r _val </dev/tty || _val=""
		if [ -n "$_val" ]; then
			printf '%s\n' "$_val"
		else
			printf '%s\n' "$_def"
		fi
	else
		printf '%s\n' "$_def"
	fi
}

tui_yesno() {
	_question=$1
	_default=${2:-no}
	if [ "$_default" = "yes" ]; then
		_sel=$(tui_select "$_question" "yes - Enable" "no  - Skip")
	else
		_sel=$(tui_select "$_question" "no  - Skip" "yes - Enable")
	fi
	case $_sel in
		yes*) return 0 ;;
		*)    return 1 ;;
	esac
}

# ---------------------------------------------------------------------------
# Idempotent, Non-Overwriting File Commit
# ---------------------------------------------------------------------------
commit_file() {
	_tmp=$1
	_base=$2
	_ext=$3

	_primary="${_base}${_ext}"
	if [ -f "$_primary" ]; then
		if cmp -s -- "$_tmp" "$_primary"; then
			msg "[IDEMPOTENT] Unchanged: $_primary already matches generated Caddyfile."
			printf '%s\n' "$_primary"
			return 0
		fi
	else
		cat -- "$_tmp" > "$_primary"
		msg "[CREATED] $_primary"
		printf '%s\n' "$_primary"
		return 0
	fi

	_n=1
	while [ "$_n" -le 9999 ]; do
		_cand="${_base}.${_n}${_ext}"
		if [ -f "$_cand" ]; then
			if cmp -s -- "$_tmp" "$_cand"; then
				msg "[IDEMPOTENT] Unchanged: $_cand already matches generated Caddyfile."
				printf '%s\n' "$_cand"
				return 0
			fi
		else
			cat -- "$_tmp" > "$_cand"
			msg "[PROTECTED] Existing $_primary preserved; wrote new Caddyfile to $_cand"
			printf '%s\n' "$_cand"
			return 0
		fi
		_n=$((_n + 1))
	done

	die "Unable to allocate non-colliding filename for ${_primary}"
}

# ---------------------------------------------------------------------------
# Feature Module Prompts & Snippet Generators
# Appends indented directives to $TMP_SITE
# ---------------------------------------------------------------------------
emit_line() {
	printf '%s\n' "$*" >> "$TMP_SITE"
}

# 1. Global Options Block
prompt_global_options() {
	bold_msg "--- [Module: Global Options Block] ---"
	_admin_sel=$(tui_select "Admin API Configuration" \
		"default          - Keep Caddy default (localhost:2019)" \
		"off              - Disable Admin API (admin off)" \
		"custom           - Custom Admin API listen address")
	_admin_line=""
	case $_admin_sel in
		off*)    _admin_line="	admin off" ;;
		custom*)
			_adm_addr=$(tui_input "Admin API listen address" "127.0.0.1:2019")
			_admin_line="	admin ${_adm_addr}"
			;;
	esac

	_https_sel=$(tui_select "Global Automatic HTTPS / PKI Mode" \
		"default          - Automatic HTTPS via Let's Encrypt / ZeroSSL" \
		"email            - Specify ACME account email for certificate notices" \
		"local_certs      - Use internal local CA for all sites (local_certs)" \
		"staging          - Use Let's Encrypt Staging CA (testing)" \
		"auto_https_off   - Disable Automatic HTTPS globally (auto_https off)")
	_https_lines=""
	case $_https_sel in
		email*)
			_email=$(tui_input "ACME Registration Email" "admin@example.com")
			_https_lines="	email ${_email}"
			;;
		local_certs*)
			_https_lines="	local_certs"
			;;
		staging*)
			_email=$(tui_input "ACME Registration Email" "admin@example.com")
			_https_lines="	email ${_email}
	acme_ca https://acme-staging-v02.api.letsencrypt.org/directory"
			;;
		auto_https_off*)
			_https_lines="	auto_https off"
			;;
	esac

	_ports_line=""
	if tui_yesno "Customize global default HTTP/HTTPS ports (80/443)?" "no"; then
		_hp=$(tui_input "Global HTTP port" "80")
		_sp=$(tui_input "Global HTTPS port" "443")
		_ports_line="	http_port ${_hp}
	https_port ${_sp}"
	fi

	{
		printf '{\n'
		[ -n "$_admin_line" ] && printf '%s\n' "$_admin_line"
		[ -n "$_https_lines" ] && printf '%s\n' "$_https_lines"
		[ -n "$_ports_line" ] && printf '%s\n' "$_ports_line"
		printf '}\n\n'
	} >> "$TMP_CADDY"
}

# 2. Site Address, Bind & TLS
prompt_site_header() {
	_def_addr=${OPT_ADDR:-":3000"}
	if [ -n "${OPT_ADDR:-}" ]; then
		SITE_ADDR=$OPT_ADDR
	else
		_addr_sel=$(tui_select "Site Listen Address / Hostname" \
			":3000            - Port 3000 HTTP (media / dev server default)" \
			":8080            - Port 8080 HTTP (alternate web port)" \
			":80              - Standard HTTP port 80" \
			"localhost:8443   - Localhost HTTPS on port 8443" \
			"Custom domain or port (e.g. example.com, *.example.com, :4000)...")
		case $_addr_sel in
			":3000"*)          SITE_ADDR=":3000" ;;
			":8080"*)          SITE_ADDR=":8080" ;;
			":80"*)            SITE_ADDR=":80" ;;
			"localhost:8443"*) SITE_ADDR="localhost:8443" ;;
			*)                 SITE_ADDR=$(tui_input "Enter site address (domain, host:port, or :port)" "$_def_addr") ;;
		esac
	fi

	# Bind interface configuration (VPN-aware physical LAN detection)
	_lan_ip=$(detect_lan_ip)
	_vpn_ip=$(detect_vpn_ip || true)
	if [ -n "${OPT_BIND:-}" ]; then
		SITE_BIND=$OPT_BIND
	else
		if [ -n "$_vpn_ip" ] && [ "$_vpn_ip" != "$_lan_ip" ]; then
			_bind_sel=$(tui_select "Network Interface Binding (bind directive)" \
				"${_lan_ip} 127.0.0.1 (auto-detected physical LAN + loopback — bypasses VPN)" \
				"${_lan_ip} ${_vpn_ip} 127.0.0.1 (physical LAN + active WireGuard VPN + loopback)" \
				"all (omit bind directive / listen on all interfaces)" \
				"0.0.0.0 (explicit IPv4 all interfaces)" \
				"127.0.0.1 (loopback / localhost only)" \
				"${_vpn_ip} 127.0.0.1 (VPN tunnel + loopback only)" \
				"Custom bind IP address(es)...")
		else
			_bind_sel=$(tui_select "Network Interface Binding (bind directive)" \
				"${_lan_ip} 127.0.0.1 (auto-detected physical LAN + loopback)" \
				"all (omit bind directive / listen on all interfaces)" \
				"0.0.0.0 (explicit IPv4 all interfaces)" \
				"127.0.0.1 (loopback / localhost only)" \
				"Custom bind IP address(es)...")
		fi
		case $_bind_sel in
			"${_lan_ip} 127.0.0.1"*)             SITE_BIND="${_lan_ip} 127.0.0.1" ;;
			"${_lan_ip} ${_vpn_ip} 127.0.0.1"*)  SITE_BIND="${_lan_ip} ${_vpn_ip} 127.0.0.1" ;;
			"all"*)                              SITE_BIND="" ;;
			"0.0.0.0"*)                          SITE_BIND="0.0.0.0" ;;
			"127.0.0.1"*)                        SITE_BIND="127.0.0.1" ;;
			"${_vpn_ip} 127.0.0.1"*)             SITE_BIND="${_vpn_ip} 127.0.0.1" ;;
			*)                                   SITE_BIND=$(tui_input "Enter space-separated bind IPs" "${_lan_ip} 127.0.0.1") ;;
		esac
	fi

	[ -n "$SITE_BIND" ] && emit_line "	bind ${SITE_BIND}"

	# TLS configuration if interactive and non-HTTP port
	case $SITE_ADDR in
		:*|http://*)
			# Port-only or explicit HTTP typically doesn't need a tls block unless requested
			;;
		*)
			if [ "${OPT_NONINTERACTIVE:-0}" -eq 0 ]; then
				_tls_sel=$(tui_select "TLS Certificate Mode for ${SITE_ADDR}" \
					"auto     - Automatic ACME (Let's Encrypt / ZeroSSL)" \
					"internal - Self-signed local CA (tls internal)" \
					"custom   - Custom PEM certificate & private key files" \
					"dns      - ACME DNS-01 Challenge (Cloudflare, Route53, DuckDNS, etc.)")
				case $_tls_sel in
					internal*)
						emit_line "	tls internal"
						;;
					custom*)
						_cert=$(tui_input "Path to certificate PEM" "/etc/caddy/certs/fullchain.pem")
						_key=$(tui_input "Path to private key PEM" "/etc/caddy/certs/privkey.pem")
						emit_line "	tls ${_cert} ${_key}"
						;;
					dns*)
						_prov=$(tui_select "DNS-01 Provider Module" \
							"cloudflare" "route53" "duckdns" "digitalocean" "hetzner")
						_tok_env=$(tui_input "Environment variable name for API token" "DNS_API_TOKEN")
						emit_line "	tls {"
						emit_line "		dns ${_prov} {env.${_tok_env}}"
						emit_line "	}"
						;;
				esac
			fi
			;;
	esac
}

# 3. File Server & Interactive File Browser Module
mod_file_server() {
	_default_root=${OPT_ROOT:-"$ TARGET_DIR"}
	_default_root=${OPT_ROOT:-"$TARGET_DIR"}
	bold_msg "--- [Module: File Server & File Browser] ---"

	if [ -n "${OPT_ROOT:-}" ] && [ "${OPT_NONINTERACTIVE:-0}" -eq 1 ]; then
		_fs_root=$OPT_ROOT
	else
		_root_sel=$(tui_select "File Server Document Root (root *)" \
			"${_default_root} (target directory)" \
			"/s4/s4Downloads (media preset root)" \
			"/srv/http (system web root)" \
			"/var/www/html (standard web root)" \
			"Custom root path...")
		case $_root_sel in
			"${_default_root}"*) _fs_root=$_default_root ;;
			"/s4/s4Downloads"*)  _fs_root="/s4/s4Downloads" ;;
			"/srv/http"*)        _fs_root="/srv/http" ;;
			"/var/www/html"*)    _fs_root="/var/www/html" ;;
			*)                   _fs_root=$(tui_input "Enter document root path" "$_default_root") ;;
		esac
	fi

	_browse=$OPT_BROWSE
	if [ -z "$_browse" ]; then
		if tui_yesno "Enable interactive directory File Browser UI (file_server browse)?" "yes"; then
			_browse="yes"
		else
			_browse="no"
		fi
	fi

	_tpl_path=""
	if [ "$_browse" = "yes" ] && [ "${OPT_NONINTERACTIVE:-0}" -eq 0 ]; then
		if tui_yesno "Use a custom HTML template for the file browser?" "no"; then
			_tpl_path=$(tui_input "Path to custom browse template HTML" "/etc/caddy/browse.html")
		fi
	fi

	_hide_pat=""
	if [ "${OPT_NONINTERACTIVE:-0}" -eq 0 ]; then
		_hide_sel=$(tui_select "Hide Sensitive Dotfiles / Patterns" \
			"standard - Hide .git, .env, *.bak, .DS_Store" \
			"none     - Do not add hide directive" \
			"custom   - Enter custom space-separated hide patterns")
		case $_hide_sel in
			standard*) _hide_pat=".git .env *.bak .DS_Store" ;;
			custom*)   _hide_pat=$(tui_input "Space-separated hide patterns" ".git .env *.bak") ;;
		esac
	fi

	_precomp=""
	if [ "${OPT_NONINTERACTIVE:-0}" -eq 0 ]; then
		if tui_yesno "Serve precompressed sidecar files (.zst, .br, .gz)?" "no"; then
			_precomp="zstd br gzip"
		fi
	fi

	emit_line "	root * ${_fs_root}"
	if [ "$_browse" = "no" ] && [ -z "$_hide_pat" ] && [ -z "$_precomp" ]; then
		emit_line "	file_server"
	elif [ "$_browse" = "yes" ] && [ -z "$_tpl_path" ] && [ -z "$_hide_pat" ] && [ -z "$_precomp" ]; then
		emit_line "	file_server browse"
	else
		emit_line "	file_server {"
		if [ "$_browse" = "yes" ]; then
			if [ -n "$_tpl_path" ]; then
				emit_line "		browse ${_tpl_path}"
			else
				emit_line "		browse"
			fi
		fi
		[ -n "$_hide_pat" ] && emit_line "		hide ${_hide_pat}"
		[ -n "$_precomp" ] && emit_line "		precompressed ${_precomp}"
		emit_line "	}"
	fi
}

# 4. Dynamic M3U Playlist Responder Module
caddy_suffix_expr() {
	_type=$1
	case $_type in
		videos)
			set -- .mp4 .wmv .mkv .mp3 .flac .ts .avi .webm .m4v .mov .mpeg .mpg .flv .ogv .3gp
			;;
		images)
			set -- .jpg .jpeg .png .gif .webp .bmp .tiff .tif .svg .avif .heic
			;;
		both|*)
			set -- .mp4 .wmv .mkv .mp3 .flac .ts .avi .webm .m4v .mov .mpeg .mpg .flv .ogv .3gp .gif .jpg .jpeg .png .webp .bmp .tiff .tif .svg .avif .heic
			;;
	esac
	_out=""
	for _ext in "$@"; do
		if [ -z "$_out" ]; then
			_out="(hasSuffix \\\"${_ext}\\\" \$lower)"
		else
			_out="${_out} (hasSuffix \\\"${_ext}\\\" \$lower)"
		fi
	done
	printf '%s' "$_out"
}

mod_m3u_streamer() {
	bold_msg "--- [Module: Dynamic M3U Playlist & Media Streamer] ---"
	_def_root=${OPT_ROOT:-"/s4/s4Downloads"}
	if [ -n "${OPT_ROOT:-}" ] && [ "${OPT_NONINTERACTIVE:-0}" -eq 1 ]; then
		_m3u_root=$OPT_ROOT
	else
		_root_sel=$(tui_select "Media Root Directory" \
			"/s4/s4Downloads (preset media root)" \
			"${TARGET_DIR} (current target directory)" \
			"Custom media root path...")
		case $_root_sel in
			"/s4/s4Downloads"*) _m3u_root="/s4/s4Downloads" ;;
			"${TARGET_DIR}"*)   _m3u_root=$TARGET_DIR ;;
			*)                  _m3u_root=$(tui_input "Media root directory" "$_def_root") ;;
		esac
	fi

	_mtype=${OPT_MEDIA_TYPE:-""}
	if [ -z "$_mtype" ]; then
		_tsel=$(tui_select "Dynamic Playlist Media Filter" \
			"videos - Video & audio streams (.mp4, .mkv, .mp3, .flac, .ts, .avi, .webm, .m4v, .mov)" \
			"both   - Videos/audio + images (.jpg, .png, .gif, .webp, ...)" \
			"images - Images only (.jpg, .jpeg, .png, .gif, .webp, .bmp, .svg, .avif)")
		case $_tsel in
			both*)   _mtype="both" ;;
			images*) _mtype="images" ;;
			*)       _mtype="videos" ;;
		esac
	fi

	_m3u_route=$(tui_input "Playlist endpoint path" "/playlist.m3u")
	case $_m3u_route in
		/*) ;;
		*)  _m3u_route="/${_m3u_route}" ;;
	esac

	_browse_Static="no"
	if [ "${OPT_BROWSE:-}" = "yes" ]; then
		_browse_Static="yes"
	elif [ "${OPT_NONINTERACTIVE:-0}" -eq 0 ]; then
		if tui_yesno "Also enable interactive directory browsing on the fallback file_server?" "no"; then
			_browse_Static="yes"
		fi
	fi

	_suffix_cond=$(caddy_suffix_expr "$_mtype")
	cat >> "$TMP_SITE" <<EOF
	root * ${_m3u_root}

	handle ${_m3u_route} {
		header Content-Type "audio/x-mpegurl; charset=utf-8"
		header Cache-Control "no-cache, no-store, must-revalidate"
		templates {
			mime audio/x-mpegurl
		}
		respond "#EXTM3U
{{- range listFiles \"/\" }}
{{- \$lower := lower . }}
{{- if or ${_suffix_cond} }}
{{- \$safe := replace \"%\" \"%25\" . }}
{{- \$safe = replace \" \" \"%20\" \$safe }}
{{- \$safe = replace \"\x23\" \"%23\" \$safe }}
{{- \$safe = replace \"?\" \"%3F\" \$safe }}
{{- \$safe = replace \"[\" \"%5B\" \$safe }}
{{- \$safe = replace \"]\" \"%5D\" \$safe }}
http://{{ \$.Req.Host }}/{{ \$safe }}
{{- end }}
{{- end }}
" 200
	}

	handle {
EOF
	if [ "$_browse_Static" = "yes" ]; then
		emit_line "		file_server browse"
	else
		emit_line "		file_server"
	fi
	emit_line "	}"
}

# 5. Reverse Proxy & Load Balancer Module
mod_reverse_proxy() {
	bold_msg "--- [Module: Reverse Proxy & Load Balancer] ---"
	_matcher=$(tui_select "Reverse Proxy Request Matcher" \
		"*        - Proxy all requests" \
		"/api/*   - Proxy /api/* requests" \
		"/ws/*    - Proxy WebSocket /ws/* requests" \
		"Custom path matcher...")
	case $_matcher in
		"*"*)      _rp_match="" ;;
		"/api/*"*) _rp_match="/api/*" ;;
		"/ws/*"*)  _rp_match="/ws/*" ;;
		*)         _rp_match=$(tui_input "Enter path matcher (e.g. /v1/*)" "/api/*") ;;
	esac

	_def_up=${OPT_UPSTREAM:-"127.0.0.1:8080"}
	if [ -n "${OPT_UPSTREAM:-}" ] && [ "${OPT_NONINTERACTIVE:-0}" -eq 1 ]; then
		_upstreams=$OPT_UPSTREAM
	else
		_upstreams=$(tui_input "Backend upstream(s) (space-separated, e.g. 127.0.0.1:8080 127.0.0.1:8081)" "$_def_up")
	fi

	# Determine if multiple upstreams or advanced options requested
	_lb_policy=""
	_hc_uri=""
	_hc_int=""
	_hc_to=""
	_flush=""
	_hdr_up="no"
	_https_skip="no"

	if [ "${OPT_NONINTERACTIVE:-0}" -eq 0 ]; then
		_lb_sel=$(tui_select "Load Balancing Policy (lb_policy)" \
			"default     - Caddy default (random)" \
			"round_robin - Cycle through upstreams in order" \
			"least_conn  - Pick upstream with fewest active requests" \
			"ip_hash     - Stickiness by client IP hash" \
			"first       - Use first available upstream (active/passive failover)" \
			"uri_hash    - Consistent hashing by request URI")
		case $_lb_sel in
			round_robin*) _lb_policy="round_robin" ;;
			least_conn*)  _lb_policy="least_conn" ;;
			ip_hash*)     _lb_policy="ip_hash" ;;
			first*)       _lb_policy="first" ;;
			uri_hash*)    _lb_policy="uri_hash" ;;
		esac

		if tui_yesno "Configure active HTTP health checks (health_uri)?" "no"; then
			_hc_uri=$(tui_input "Health check endpoint path" "/healthz")
			_hc_int=$(tui_input "Health check interval" "10s")
			_hc_to=$(tui_input "Health check timeout" "5s")
		fi

		if tui_yesno "Add explicit upstream forwarding headers (X-Real-IP, X-Forwarded-Proto)?" "no"; then
			_hdr_up="yes"
		fi

		if tui_yesno "Enable low-latency streaming / SSE / WebSocket flush (flush_interval -1)?" "no"; then
			_flush="-1"
		fi

		if tui_yesno "Does upstream use self-signed HTTPS requiring tls_insecure_skip_verify?" "no"; then
			_https_skip="yes"
		fi
	fi

	_rp_head="	reverse_proxy"
	[ -n "$_rp_match" ] && _rp_head="${_rp_head} ${_rp_match}"
	_rp_head="${_rp_head} ${_upstreams}"

	if [ -z "$_lb_policy" ] && [ -z "$_hc_uri" ] && [ -z "$_flush" ] && [ "$_hdr_up" = "no" ] && [ "$_https_skip" = "no" ]; then
		emit_line "$_rp_head"
	else
		emit_line "${_rp_head} {"
		[ -n "$_lb_policy" ] && emit_line "		lb_policy ${_lb_policy}"
		if [ -n "$_hc_uri" ]; then
			emit_line "		health_uri ${_hc_uri}"
			emit_line "		health_interval ${_hc_int}"
			emit_line "		health_timeout ${_hc_to}"
		fi
		[ -n "$_flush" ] && emit_line "		flush_interval ${_flush}"
		if [ "$_hdr_up" = "yes" ]; then
			emit_line "		header_up Host {host}"
			emit_line "		header_up X-Real-IP {remote_host}"
			emit_line "		header_up X-Forwarded-Proto {scheme}"
		fi
		if [ "$_https_skip" = "yes" ]; then
			emit_line "		transport http {"
			emit_line "			tls_insecure_skip_verify"
			emit_line "		}"
		fi
		emit_line "	}"
	fi
}

# 6. Single-Page Application (SPA) + Optional API Backend Module
mod_spa_router() {
	bold_msg "--- [Module: Single-Page Application (SPA) Router] ---"
	_def_root=${OPT_ROOT:-"/var/www/app/dist"}
	_spa_root=$(tui_input "SPA build output root directory" "$_def_root")
	_spa_index=$(tui_input "SPA fallback entry file" "/index.html")

	emit_line "	root * ${_spa_root}"
	emit_line "	encode zstd gzip"

	if tui_yesno "Add split /api/* reverse_proxy to a backend service?" "yes"; then
		_api_path=$(tui_input "API route prefix" "/api/*")
		_api_up=$(tui_input "API backend upstream" "${OPT_UPSTREAM:-127.0.0.1:8080}")
		emit_line ""
		emit_line "	handle ${_api_path} {"
		emit_line "		reverse_proxy ${_api_up}"
		emit_line "	}"
	fi

	if tui_yesno "Add immutable Cache-Control headers for static hashed assets (*.js, *.css, *.woff2)?" "yes"; then
		emit_line ""
		emit_line "	@static path *.js *.css *.png *.jpg *.jpeg *.gif *.webp *.svg *.ico *.woff *.woff2"
		emit_line "	header @static Cache-Control \"public, max-age=31536000, immutable\""
	fi

	emit_line ""
	emit_line "	handle {"
	emit_line "		try_files {path} {path}/ ${_spa_index}"
	emit_line "		file_server"
	emit_line "	}"
}

# 7. PHP-FPM / FastCGI Application Server Module
mod_php_fastcgi() {
	bold_msg "--- [Module: PHP-FPM / FastCGI Application Server] ---"
	_php_root=$(tui_input "PHP application document root" "${OPT_ROOT:-/var/www/html}")
	_fpm_sel=$(tui_select "PHP-FPM Upstream Socket / Address" \
		"unix//run/php/php-fpm.sock     - Debian/Ubuntu/Arch default Unix socket" \
		"unix//var/run/php-fpm/www.sock - RHEL/Fedora Unix socket" \
		"127.0.0.1:9000                 - TCP localhost port 9000 (Docker / standard)" \
		"Custom PHP-FPM upstream...")
	case $_fpm_sel in
		"unix//run/php/php-fpm.sock"*)     _fpm_up="unix//run/php/php-fpm.sock" ;;
		"unix//var/run/php-fpm/www.sock"*) _fpm_up="unix//var/run/php-fpm/www.sock" ;;
		"127.0.0.1:9000"*)                 _fpm_up="127.0.0.1:9000" ;;
		*)                                 _fpm_up=$(tui_input "Enter PHP-FPM socket or host:port" "${OPT_UPSTREAM:-127.0.0.1:9000}") ;;
	esac

	emit_line "	root * ${_php_root}"
	emit_line "	encode zstd gzip"
	emit_line "	php_fastcgi ${_fpm_up}"
	emit_line "	file_server {"
	emit_line "		hide .git .env *.bak .ht*"
	emit_line "	}"
}

# 8. Authentication Module (basic_auth / forward_auth)
mod_authentication() {
	bold_msg "--- [Module: Authentication (Basic Auth / Forward Auth)] ---"
	_auth_sel=$(tui_select "Authentication Method" \
		"basic_auth   - HTTP Basic Authentication (username + bcrypt password hash)" \
		"forward_auth - External Auth Portal (Authelia, Authentik, OAuth2-Proxy, Tailscale)")
	case $_auth_sel in
		basic_auth*)
			_match=$(tui_input "Path matcher to protect (* for entire site)" "*")
			_user=$(tui_input "Username" "admin")
			_hash=$(tui_input "Bcrypt password hash (generate via 'caddy hash-password')" "\$2a\$14\$Zkx19XLiW6VYouLHR5NmfOFU0z2GTNmpkT/5qqR7hx4IjWJPDhjvG")
			if [ "$_match" = "*" ]; then
				emit_line "	basic_auth {"
			else
				emit_line "	basic_auth ${_match} {"
			fi
			emit_line "		${_user} ${_hash}"
			emit_line "	}"
			;;
		forward_auth*)
			_fa_up=$(tui_input "Auth portal upstream (e.g. 127.0.0.1:9091 for Authelia)" "127.0.0.1:9091")
			_fa_uri=$(tui_input "Auth verification URI" "/api/verify?rd=https://auth.example.com/")
			_fa_hdrs=$(tui_input "Identity headers to copy" "Remote-User Remote-Groups Remote-Name Remote-Email")
			emit_line "	forward_auth ${_fa_up} {"
			emit_line "		uri ${_fa_uri}"
			emit_line "		copy_headers ${_fa_hdrs}"
			emit_line "	}"
			;;
	esac
}

# 9. Security Headers & CORS Module
mod_headers_cors() {
	bold_msg "--- [Module: Security Headers & CORS] ---"
	if [ "${OPT_SEC_HEADERS:-}" = "yes" ] || tui_yesno "Add hardened HTTP security headers (HSTS, X-Frame-Options, nosniff, Referrer-Policy, -Server)?" "yes"; then
		cat >> "$TMP_SITE" <<'EOF'
	header {
		Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
		X-Content-Type-Options "nosniff"
		X-Frame-Options "SAMEORIGIN"
		Referrer-Policy "strict-origin-when-cross-origin"
		Permissions-Policy "accelerometer=(), camera=(), geolocation=(), microphone=(), payment=(), usb=()"
		-Server
	}
EOF
	fi

	if [ "${OPT_NONINTERACTIVE:-0}" -eq 0 ] && tui_yesno "Configure Cross-Origin Resource Sharing (CORS) headers & preflight responder?" "no"; then
		_origin=$(tui_input "Allowed Origin (e.g. * or https://app.example.com)" "*")
		_methods=$(tui_input "Allowed HTTP Methods" "GET, POST, PUT, PATCH, DELETE, OPTIONS")
		_headers=$(tui_input "Allowed Request Headers" "Content-Type, Authorization, X-Requested-With")
		cat >> "$TMP_SITE" <<EOF
	@cors_preflight method OPTIONS
	handle @cors_preflight {
		header Access-Control-Allow-Origin "${_origin}"
		header Access-Control-Allow-Methods "${_methods}"
		header Access-Control-Allow-Headers "${_headers}"
		header Access-Control-Max-Age "86400"
		respond "" 204
	}
	header Access-Control-Allow-Origin "${_origin}"
EOF
	fi
}

# 10. Compression Module (encode)
mod_compression() {
	bold_msg "--- [Module: Response Compression (encode)] ---"
	if [ "${OPT_NONINTERACTIVE:-0}" -eq 1 ]; then
		emit_line "	encode zstd gzip"
		return 0
	fi
	_enc_sel=$(tui_select "Compression Algorithms" \
		"zstd gzip    - Zstandard + Gzip (Caddy recommended default)" \
		"br zstd gzip - Brotli + Zstandard + Gzip")
	case $_enc_sel in
		"br"*) emit_line "	encode br zstd gzip" ;;
		*)     emit_line "	encode zstd gzip" ;;
	esac
}

# 11. Redirects, Rewrites & Path Stripping Module
mod_redirects_rewrites() {
	bold_msg "--- [Module: Redirects, Rewrites & Subpath Routing] ---"
	_rw_sel=$(tui_select "Redirect / Rewrite Rule Type" \
		"www-to-apex  - Permanent 308 redirect from www.<domain> to <domain>" \
		"redir        - Custom URL redirect (redir <from> <to> <code>)" \
		"handle_path  - Strip path prefix and route to upstream or root" \
		"rewrite      - Internal URI rewrite (rewrite <from> <to>)")
	case $_rw_sel in
		www-to-apex*)
			_dom=$(tui_input "Apex domain name" "example.com")
			emit_line "	@www host www.${_dom}"
			emit_line "	redir @www https://${_dom}{uri} 308"
			;;
		redir*)
			_from=$(tui_input "Match path (e.g. /old-path or *)" "/old")
			_to=$(tui_input "Target URL or path" "/new")
			_code=$(tui_select "Redirect HTTP Status" "308 (Permanent Redirect)" "301 (Moved Permanently)" "302 (Found / Temporary)" "307 (Temporary Redirect)")
			_code_num=${_code%% *}
			emit_line "	redir ${_from} ${_to} ${_code_num}"
			;;
		handle_path*)
			_pfx=$(tui_input "Path prefix to match & strip (e.g. /service/*)" "/service/*")
			_up=$(tui_input "Upstream host:port for stripped route" "127.0.0.1:9001")
			emit_line "	handle_path ${_pfx} {"
			emit_line "		reverse_proxy ${_up}"
			emit_line "	}"
			;;
		rewrite*)
			_from=$(tui_input "Match path pattern" "/legacy/*")
			_to=$(tui_input "Rewrite target URI" "/v2{uri}")
			emit_line "	rewrite ${_from} ${_to}"
			;;
	esac
}

# 12. IP Access Control & Custom Error Pages
mod_access_errors() {
	bold_msg "--- [Module: IP Access Control & Custom Error Handling] ---"
	if tui_yesno "Restrict access by client IP / CIDR ranges (remote_ip)?" "yes"; then
		_ip_mode=$(tui_select "IP Filter Policy" \
			"allow-private - Allow only RFC1918 LAN & loopback (private_ranges), block others" \
			"allow-custom  - Allow only specific CIDR/IP list, block others" \
			"block-custom  - Block specific CIDR/IP list")
		case $_ip_mode in
			allow-private*)
				emit_line "	@denied not remote_ip private_ranges 127.0.0.1 ::1"
				emit_line "	respond @denied \"403 Forbidden\" 403"
				;;
			allow-custom*)
				_cidrs=$(tui_input "Space-separated allowed IPs/CIDRs" "192.168.1.0/24 127.0.0.1")
				emit_line "	@denied not remote_ip ${_cidrs}"
				emit_line "	respond @denied \"403 Forbidden\" 403"
				;;
			block-custom*)
				_cidrs=$(tui_input "Space-separated blocked IPs/CIDRs" "203.0.113.0/24")
				emit_line "	@blocked remote_ip ${_cidrs}"
				emit_line "	respond @blocked \"403 Forbidden\" 403"
				;;
		esac
	fi

	if tui_yesno "Add a custom error handler block (handle_errors)?" "no"; then
		_err_mode=$(tui_select "Error Response Style" \
			"json - Structured JSON error response" \
			"page - Static custom error page (e.g. /50x.html, /404.html)")
		case $_err_mode in
			json*)
				cat >> "$TMP_SITE" <<'EOF'
	handle_errors {
		header Content-Type "application/json"
		respond `{"error": "{err.status_code} {err.status_text}"}` {err.status_code}
	}
EOF
				;;
			page*)
				_eroot=$(tui_input "Error pages directory" "/var/www/errors")
				cat >> "$TMP_SITE" <<EOF
	handle_errors {
		root * ${_eroot}
		rewrite * /{err.status_code}.html
		file_server
	}
EOF
				;;
		esac
	fi
}

# 13. Structured Access Logging Module
mod_logging() {
	bold_msg "--- [Module: Structured Access Logging (log)] ---"
	_log_dest=$(tui_select "Access Log Output Destination" \
		"file   - Rotating log file (/var/log/caddy/access.log)" \
		"stdout - Standard output (Docker / systemd journal)" \
		"stderr - Standard error")
	case $_log_dest in
		file*)
			_lpath=$(tui_input "Log file path" "/var/log/caddy/access.log")
			_rsize=$(tui_input "Max log file size before rotation" "100mb")
			_rkeep=$(tui_input "Number of rotated files to keep" "5")
			_fmt=$(tui_select "Log Format" "json (structured JSON)" "console (human-readable)")
			_fmt_word=${_fmt%% *}
			cat >> "$TMP_SITE" <<EOF
	log {
		output file ${_lpath} {
			roll_size ${_rsize}
			roll_keep ${_rkeep}
			roll_keep_for 720h
		}
		format ${_fmt_word}
	}
EOF
			;;
		stdout*|stderr*)
			_out_word=${_log_dest%% *}
			emit_line "	log {"
			emit_line "		output ${_out_word}"
			emit_line "	}"
			;;
	esac
}

# 14. Multi-Service Subpath Gateway Preset Helper
mod_multi_service() {
	bold_msg "--- [Module: Multi-Service Subpath Gateway] ---"
	_count=1
	while :; do
		bold_msg "--- Service Route #${_count} ---"
		_stype=$(tui_select "Route #${_count} Handler Type" \
			"handle_path (strip prefix & reverse_proxy)" \
			"handle (keep prefix & reverse_proxy)" \
			"static (serve static directory at path)")
		_spath=$(tui_input "Route path matcher (e.g. /api/*, /app/*, /media/*)" "/service${_count}/*")
		case $_stype in
			"handle_path"*)
				_sup=$(tui_input "Backend upstream (host:port)" "127.0.0.1:800${_count}")
				emit_line "	handle_path ${_spath} {"
				emit_line "		reverse_proxy ${_sup}"
				emit_line "	}"
				;;
			"handle "*)
				_sup=$(tui_input "Backend upstream (host:port)" "127.0.0.1:800${_count}")
				emit_line "	handle ${_spath} {"
				emit_line "		reverse_proxy ${_sup}"
				emit_line "	}"
				;;
			"static"*)
				_sroot=$(tui_input "Static directory root" "/srv/service${_count}")
				emit_line "	handle_path ${_spath} {"
				emit_line "		root * ${_sroot}"
				emit_line "		file_server browse"
				emit_line "	}"
				;;
		esac
		_count=$((_count + 1))
		if ! tui_yesno "Add another service route to this site?" "no"; then
			break
		fi
	done
}

# ---------------------------------------------------------------------------
# Site Block Orchestrator
# ---------------------------------------------------------------------------
build_site_block() {
	_preset=$1
	TMP_SITE=$(mktemp "${TMPDIR:-/tmp}/mkcaddy_site.XXXXXX")

	prompt_site_header

	[ "${OPT_ENCODE:-}" = "yes" ] && mod_compression
	[ "${OPT_SEC_HEADERS:-}" = "yes" ] && mod_headers_cors

	case $_preset in
		file-browser)
			[ -z "${OPT_BROWSE:-}" ] && OPT_BROWSE="yes"
			[ "${OPT_ENCODE:-}" != "yes" ] && mod_compression
			mod_file_server
			;;
		m3u-streamer)
			mod_m3u_streamer
			;;
		reverse-proxy)
			mod_reverse_proxy
			;;
		spa-api)
			mod_spa_router
			;;
		php-webapp)
			mod_php_fastcgi
			;;
		secure-gateway)
			mod_authentication
			[ "${OPT_SEC_HEADERS:-}" != "yes" ] && mod_headers_cors
			mod_reverse_proxy
			if [ "${OPT_NONINTERACTIVE:-0}" -eq 0 ] && tui_yesno "Add structured access logging?" "yes"; then
				mod_logging
			fi
			;;
		multi-service)
			mod_multi_service
			;;
		redirect-canon)
			mod_redirects_rewrites
			;;
		custom)
			while :; do
				_mod=$(tui_select "Add / Configure Module for ${SITE_ADDR}" \
					"DONE            - Finish this site block & write Caddyfile" \
					"1. file_server  - Static File Server & Interactive File Browser" \
					"2. m3u_streamer - Dynamic M3U Playlist & Media Streaming Responder" \
					"3. reverse_proxy- Reverse Proxy, Load Balancing & Health Checks" \
					"4. spa_router   - Single-Page App (try_files) & Asset Caching" \
					"5. php_fastcgi  - PHP-FPM / FastCGI Application Server" \
					"6. auth         - Basic Auth (bcrypt) or Forward Auth (Authelia/OAuth2)" \
					"7. headers_cors - Hardened Security Headers & CORS Preflight" \
					"8. encode       - Response Compression (zstd, br, gzip)" \
					"9. redirects    - Redirects (301/308), Rewrites & handle_path" \
					"10. access_err  - IP Allow/Block Filtering & Custom Error Pages" \
					"11. logging     - Structured Rotating Access Logs (JSON/Console)")
				case $_mod in
					DONE*)   break ;;
					"1."*)   mod_file_server ;;
					"2."*)   mod_m3u_streamer ;;
					"3."*)   mod_reverse_proxy ;;
					"4."*)   mod_spa_router ;;
					"5."*)   mod_php_fastcgi ;;
					"6."*)   mod_authentication ;;
					"7."*)   mod_headers_cors ;;
					"8."*)   mod_compression ;;
					"9."*)   mod_redirects_rewrites ;;
					"10."*)  mod_access_errors ;;
					"11."*)  mod_logging ;;
					*)       break ;;
				esac
			done
			;;
		*)
			die "Unknown preset '$_preset'. Run '${0##*/}' with no args for help."
			;;
	esac

	{
		printf '%s {\n' "$SITE_ADDR"
		cat -- "$TMP_SITE"
		printf '}\n'
	} >> "$TMP_CADDY"

	rm -f -- "$TMP_SITE"
	TMP_SITE=""
}

# ---------------------------------------------------------------------------
# Argument Parsing
# ---------------------------------------------------------------------------
if [ "$#" -eq 0 ]; then
	show_help
	exit 0
fi

case ${1:-} in
	--help)
		show_help
		exit 0
		;;
esac

OPT_PRESET=""
OPT_ADDR=""
OPT_BIND=""
OPT_ROOT=""
OPT_UPSTREAM=""
OPT_MEDIA_TYPE=""
OPT_BROWSE=""
OPT_ENCODE=""
OPT_SEC_HEADERS=""
OPT_NONINTERACTIVE=0

while getopts ":p:a:b:r:u:t:BESnh" opt; do
	case $opt in
		p) OPT_PRESET=$OPTARG ;;
		a) OPT_ADDR=$OPTARG ;;
		b) OPT_BIND=$OPTARG ;;
		r) OPT_ROOT=$OPTARG ;;
		u) OPT_UPSTREAM=$OPTARG ;;
		t) OPT_MEDIA_TYPE=$OPTARG ;;
		B) OPT_BROWSE="yes" ;;
		E) OPT_ENCODE="yes" ;;
		S) OPT_SEC_HEADERS="yes" ;;
		n) OPT_NONINTERACTIVE=1 ;;
		h)
			show_help
			exit 0
			;;
		:)
			die "Option -$OPTARG requires an argument. Run '${0##*/}' with no args for help."
			;;
		\?)
			die "Invalid option: -$OPTARG. Run '${0##*/}' with no args for help."
			;;
	esac
done
shift $((OPTIND - 1))

[ "$#" -ge 1 ] || {
	show_help
	exit 1
}
[ "$#" -le 1 ] || die "Expected a single <target_dir_or_file> argument, got $#."

TARGET_ARG=$1
if [ -d "$TARGET_ARG" ]; then
	TARGET_DIR=$(cd -- "$TARGET_ARG" && pwd)
	TARGET_BASE="${TARGET_DIR}/Caddyfile"
else
	_parent=$(dirname -- "$TARGET_ARG")
	[ -d "$_parent" ] || die "${0##*/}: $_parent: parent directory does not exist"
	TARGET_DIR=$(cd -- "$_parent" && pwd)
	_base_name=$(basename -- "$TARGET_ARG")
	TARGET_BASE="${TARGET_DIR}/${_base_name}"
fi

# ---------------------------------------------------------------------------
# Main Interactive / Preset Dispatch
# ---------------------------------------------------------------------------
TMP_CADDY=$(mktemp "${TMPDIR:-/tmp}/mkcaddy_out.XXXXXX")

if [ -z "$OPT_PRESET" ]; then
	if [ "$OPT_NONINTERACTIVE" -eq 1 ]; then
		OPT_PRESET="file-browser"
	else
		_psel=$(tui_select "Select Caddy Setup Preset or Custom Module Builder" \
			"file-browser   - Static File Server & Interactive Directory Browser" \
			"m3u-streamer   - Dynamic M3U Playlist & Media Streaming Server (:3000)" \
			"reverse-proxy  - Reverse Proxy with Load Balancing & Health Checks" \
			"spa-api        - Single-Page App (try_files) + /api/* Reverse Proxy" \
			"php-webapp     - PHP-FPM / FastCGI Web Application Server" \
			"secure-gateway - Authenticated Reverse Proxy (Basic/Forward Auth + Security Headers)" \
			"multi-service  - Path-Routed Multi-Service Subpath Gateway" \
			"redirect-canon - Domain Canonicalization (www -> apex) & Redirects" \
			"custom         - Full Composable Module-by-Module Builder")
		OPT_PRESET=${_psel%% *}
	fi
fi

# Optional Global Options Block in Interactive Mode
if [ "$OPT_NONINTERACTIVE" -eq 0 ] && [ -t 0 ] && [ -t 2 ]; then
	if tui_yesno "Configure a Global Options Block { ... } (admin API, ACME email/CA, ports)?" "no"; then
		prompt_global_options
	fi
fi

# Build Primary Site Block
build_site_block "$OPT_PRESET"

# Allow adding additional site blocks in interactive mode
if [ "$OPT_NONINTERACTIVE" -eq 0 ] && [ -t 0 ] && [ -t 2 ]; then
	while tui_yesno "Add another site block (virtual host / port) to this Caddyfile?" "no"; do
		printf '\n' >> "$TMP_CADDY"
		OPT_ADDR=""
		OPT_BIND=""
		_next_psel=$(tui_select "Select Preset for Additional Site Block" \
			"reverse-proxy  - Reverse Proxy" \
			"file-browser   - Static File Server & Browser" \
			"m3u-streamer   - Dynamic M3U Streamer" \
			"spa-api        - Single-Page App + API" \
			"php-webapp     - PHP-FPM Server" \
			"secure-gateway - Authenticated Gateway" \
			"redirect-canon - Redirect / Canonicalization" \
			"custom         - Composable Module Builder")
		build_site_block "${_next_psel%% *}"
	done
fi

OUT_FILE=$(commit_file "$TMP_CADDY" "$TARGET_BASE" "")
printf '%s\n' "$OUT_FILE"