#!/bin/sh
# === MKCADDY === (c) 2026 - 4ndr0666
# Usage: mkcaddy [options] <dir_or_file>
#
# Standalone POSIX-compliant Caddyfile builder & architecture wizard.
# Nine architecture presets plus native Caddyfile/JSON extension points.
# POSIX shell syntax; requires Linux/coreutils (mktemp and ln -T).
# Caddy 2.8+ is needed for validation and basic_auth. No daemon is started.

set -eu
set -C
set -f
umask 077
LC_ALL=C
export LC_ALL
VERSION="3.0.0"
CADDY_BIN=${CADDY_BIN:-caddy}
PYTHON_BIN=${PYTHON_BIN:-python3}

# ---------------------------------------------------------------------------
# Color & Theme Setup (#15FFFF on #000000 black)
# Note: 5-char #15FFF normalized to 6-hex #15FFFF (RGB 21, 255, 255) for TUI.
# ---------------------------------------------------------------------------
HEX_FG="#15ffff"
HEX_BG="#000000"
HEX_HL="#00d7ff"
HEX_BG_ALT="#071a1a"

if { [ -t 1 ] || [ -t 2 ]; } && [ "${TERM:-}" != "dumb" ] && [ -z "${NO_COLOR:-}" ]; then
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
WORK_DIR=""
TMP_CADDY=""
TMP_SITE=""
cleanup() {
	if [ -n "$WORK_DIR" ]; then
		rm -rf -- "$WORK_DIR"
	fi
	return 0
}
trap cleanup 0
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP

msg() {
	[ "${OPT_QUIET:-0}" -eq 0 ] || return 0
	printf '%s%s%s\n' "$C_THEME" "$*" "$C_RST" >&2
}

bold_msg() {
	[ "${OPT_QUIET:-0}" -eq 0 ] || return 0
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
		_bcast_devs=$(ip -o link show up 2>/dev/null | awk -F': ' '/BROADCAST/ && !/POINTOPOINT/ {print $2}' | cut -d'@' -f1 | tr '\n' ' ' || true)

		# 1. Prefer the default-route physical broadcast interface in the main table
		_lan_dev=$(ip -4 route show table main default 2>/dev/null | awk -v bcast=" $_bcast_devs " -v wg=" $_wg_devs " '
			{
				for (i = 1; i <= NF; i++) {
					if ($i == "dev") {
						d = $(i+1)
						if ($0 !~ /linkdown/ && d != "lo" && d !~ /^(tun|tap|wg|ppp|docker|br-|veth|virbr)/ && index(wg, " " d " ") == 0 && index(bcast, " " d " ") > 0) {
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
		_ip=$(ip -o -4 addr show up scope global 2>/dev/null | awk -v bcast=" $_bcast_devs " -v wg=" $_wg_devs " '
			{
				d = $2
				if (d == "lo" || d ~ /^(tun|tap|wg|ppp|docker|br-|veth|virbr)/) next
				if (index(wg, " " d " ") > 0) next
				if (index(bcast, " " d " ") == 0) next
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

	return 1
}

# Detect active WireGuard / POINTOPOINT VPN IPv4 address (if any) so the user can
# optionally bind LAN + VPN + loopback together when behind a tunnel.
detect_vpn_ip() {
	if have_cmd ip; then
		for _wg_dev in $(ip -o link show up type wireguard 2>/dev/null | awk -F': ' '{print $2}' | cut -d'@' -f1 || true); do
			_vip=$(ip -o -4 addr show dev "$_wg_dev" scope global 2>/dev/null | awk '{split($4, a, "/"); print a[1]; exit}')
			if [ -n "$_vip" ]; then
				printf '%s\n' "$_vip"
				return 0
			fi
		done
		for _ptp_dev in $(ip -o link show up 2>/dev/null | awk -F': ' '/POINTOPOINT/ {print $2}' | cut -d'@' -f1 || true); do
			_vip=$(ip -o -4 addr show dev "$_ptp_dev" scope global 2>/dev/null | awk '{split($4, a, "/"); print a[1]; exit}')
			if [ -n "$_vip" ]; then
				printf '%s\n' "$_vip"
				return 0
			fi
		done
	fi
	return 1
}

require_line() {
	case $2 in
		''|*'
'*|*"$(printf '\r')"*|*[[:cntrl:]]*) die "$1 must be a nonempty single line without control characters" ;;
	esac
}

# Restrict lists of grammar tokens; use -c/-g for intentional native syntax.
require_tokens() {
	require_line "$1" "$2"
	case $2 in
		*[!a-zA-Z0-9_./:@%+*=,?\[\]\ -]*) die "Invalid characters in $1; use a native fragment for advanced syntax" ;;
	esac
}

require_literal() {
	require_line "$1" "$2"
	case $2 in *'{$'*) die "$1 cannot contain Caddyfile environment substitutions; use a trusted fragment" ;; esac
}

# Escape a literal Caddyfile argument. Never use printf %b on operator input.
caddy_quote() {
	require_literal "Literal argument" "$1"
	printf '"'
	printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
	printf '"'
}

absolute_file() (
	require_literal "File path" "$1"
	case $1 in /*) _af=$1 ;; *) _af=$PWD/$1 ;; esac
	require_literal "Absolute file path" "$_af"
	[ -f "$_af" ] && [ -r "$_af" ] || die "Cannot read regular file: $_af"
	_resolved="$(cd -- "$(dirname -- "$_af")" && pwd -P)/$(basename -- "$_af")"
	require_literal "Resolved file path" "$_resolved"
	printf '%s\n' "$_resolved"
)

absolute_path() (
	require_literal "File system path" "$1"
	case $1 in /*) _ap=$1 ;; *) _ap=$PWD/$1 ;; esac
	require_literal "Absolute file system path" "$_ap"
	printf '%s\n' "$_ap"
)

require_port() {
	case $2 in ''|*[!0-9]*) die "$1 must be a port from 1 to 65535" ;; esac
	_port_number=$(printf '%s' "$2" | sed 's/^0*//')
	_port_number=${_port_number:-0}
	[ "${#_port_number}" -le 5 ] && [ "$_port_number" -ge 1 ] && [ "$_port_number" -le 65535 ] ||
		die "$1 must be a port from 1 to 65535"
}

hide_config_paths() {
	# file_server treats hide arguments as globs even when they are quoted.
	_hidden_config=$(printf '%s' "$TARGET_BASE" | sed 's/[][?*\\]/\\&/g')
	_q_cfg=$(caddy_quote "$_hidden_config")
	_q_cfg_glob=$(caddy_quote "$_hidden_config.*")
	printf '%s %s' "$_q_cfg" "$_q_cfg_glob"
}

require_module() {
	[ "${OPT_VALIDATE:-auto}" != "skip" ] || return 0
	if have_cmd "$CADDY_BIN"; then
		"$CADDY_BIN" list-modules | awk -v wanted="$1" '$0 == wanted {found=1} END {exit !found}' ||
			die "Caddy build lacks required module: $1"
	fi
}

validate_config() {
	if [ "$OPT_VALIDATE" = "skip" ]; then
		msg "[UNVALIDATED] Validation explicitly disabled (-V)."
		return 0
	fi
	if ! have_cmd "$CADDY_BIN"; then
		[ "$OPT_VALIDATE" != "required" ] || die "Caddy is required for -v validation"
		msg "[UNVALIDATED] Caddy unavailable; run caddy validate before deployment (or use -v to require it)."
		return 0
	fi
	have_cmd timeout || die "GNU coreutils timeout is required for validation"
	if [ -n "$OPT_JSON" ]; then
		timeout --foreground 60 "$CADDY_BIN" validate --config "$TMP_CADDY" >&2 || die "Native JSON validation failed or timed out; nothing committed"
	else
		timeout --foreground 60 "$CADDY_BIN" adapt --config "$TMP_CADDY" --adapter caddyfile --validate >/dev/null ||
			die "Caddyfile validation failed or timed out; nothing committed"
	fi
	msg "[VALIDATED] Caddy accepted the generated configuration."
}

# Root-owning terminal handlers cannot be flattened into the same site.
# Scoped combinations remain available via native handle/route fragments.
claim_content() {
	if [ -n "$SITE_CONTENT" ]; then
		[ "$OPT_NONINTERACTIVE" -eq 0 ] || die "Conflicting content modules: $SITE_CONTENT and $1"
		msg "[SKIPPED] $SITE_CONTENT already owns this site's root; use scoped native routes to combine handlers."
		return 1
	fi
	SITE_CONTENT=$1
}

mod_native_fragment() {
	_native=$(tui_input "Native site fragment file (trusted Caddyfile directives)" "${OPT_SITE_FRAGMENT:-}")
	_native=$(absolute_file "$_native")
	_q_native=$(caddy_quote "$_native")
	emit_line "	import $_q_native"
}

# ---------------------------------------------------------------------------
# Dedicated & Comprehensive Help Menu
# ---------------------------------------------------------------------------
show_help() {
	prog=${0##*/}
	cat <<EOF
${C_BOLD}=== MKCADDY === (c) 2026 - 4ndr0666${C_RST}
${C_THEME}MKCADDY ${VERSION} | POSIX-shell Caddyfile Architecture & Module Builder${C_RST}
${C_DIM}Theme: #15FFFF (#15FFF) on Black (#000000) | Idempotent & Non-Overwriting${C_RST}

${C_BOLD}USAGE:${C_RST}
  ${C_THEME}${prog} <target_dir_or_file>${C_RST}
  ${C_THEME}${prog} [options] <target_dir_or_file>${C_RST}
  ${C_THEME}${prog} -m | --version${C_RST}

${C_BOLD}DESCRIPTION:${C_RST}
  ${C_THEME}Interactive fzf-driven TUI (with POSIX /dev/tty fallback) and CLI generator
  for Caddyfiles (validate before deployment). Supports both popular turnkey architecture
  presets and a full composable module-by-module builder that prompts for every
  required parameter per feature. Running with no arguments displays this help.${C_RST}

${C_BOLD}POPULAR ARCHITECTURE PRESETS (-p <preset>):${C_RST}
  ${C_THEME}file-browser   Static File Server & Interactive Directory Browser (file_server browse,
                 hidden file filters, precompressed sidecars, zstd/gzip encoding)
  m3u-streamer   Recursive M3U Media Streaming Server (native templates + file_server;
                 video/audio/images, metadata sorting and complete shuffling)
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
  5. Dynamic Templates      templates mime, recursive M3U responder (videos/images/both)
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
  -s <field>   M3U order: date | size | name | shuffle (default: date)
  -o <order>   M3U order direction: desc | asc (default: desc)
  -d <depth>   M3U maximum file depth: 0=all, 1=root (default: 0; max: 255)
  -B           Enable interactive file browser (file_server browse)
  -E           Enable zstd + gzip compression (encode zstd gzip)
  -S           Enable hardened HTTP security headers preset
  -n           Non-interactive mode (use flags and sensible defaults without prompts)
  -c <file>    Import trusted native HTTP handler directives (inside protected routing)
  -g <file>    Import trusted native global options (storage, PKI, events, servers...)
  -J <file>    Commit native JSON configuration verbatim (any installed Caddy app)
  -P <list>    Global server protocols (e.g. "h1 h2 h3")
  -T <mode>    TLS: auto | internal (certificate/DNS wizard; full TLS/PKI via -J)
  -e <email>   ACME registration email
  -A <addr>    Admin API: off or listen address
  -H <file>    Required bcrypt hash file for noninteractive secure-gateway
  -U <user>    Basic authentication username (default: admin)
  -L <dest>    Access log: stdout | stderr | absolute file path
  -k <CIDRs>   Allow only these remote IP ranges
  -D <CIDRs>   Deny these remote IP ranges (mutually exclusive with -k)
  -C <origin>  CORS origin (* or one explicit origin)
  -i <names>   File-server index filenames
  -w <globs>   File-server hide patterns (default: .git .env *.bak .DS_Store)
  -z <list>    Precompressed sidecars (zstd br gzip; br sidecars need no plugin)
  -v           Require successful Caddy validation before committing
  -V           Explicitly skip Caddy validation (generate only)
  -m           List modules in the selected CADDY_BIN, then exit
  -q           Suppress progress messages (errors remain visible)
  -h           Display this comprehensive help menu${C_RST}

${C_BOLD}EXAMPLES:${C_RST}
  ${C_THEME}${prog} .                                    # Launch interactive TUI in current dir
  ${C_THEME}${prog} -p file-browser -a :8080 -B /srv/pub # Browser preset setup
  ${C_THEME}${prog} -n -p reverse-proxy -a app.local -u 127.0.0.1:5000 ./Caddyfile
  ${C_THEME}${prog} -n -p m3u-streamer -a :3000 -t videos /s4/s4Downloads${C_RST}

Validation defaults to using Caddy when available; -v makes it mandatory.
CADDY_BIN selects a specific binary. Third-party modules must already be installed.
Native handler/global fragments remain external dependencies; their imports resolve
relative to that fragment. Site options such as tls/log/bind do not belong in -c;
use the built-in controls or full native JSON (-J). -J accepts all native apps (including layer4 with a custom build).
Recursive media generation additionally requires Python 3.9+ (PYTHON_BIN) at
build time. The generated server uses Caddy native templates on Linux local disk,
without a helper process. It skips symlinks, deduplicates hard links by inode,
and aborts requests on unreadable directories or recursion beyond 256 levels.
The media sort/filter/depth is baked into the config; shuffle permutes all files
on every request. Formats are selected by extension, not decoded by this tool.
Deploy the printed output path; when an existing config differs it is preserved.
Generated configurations are mode 0600; grant the Caddy service read access before
reload. This builder never installs, starts, stops or reloads a service.
GTK/Cairo glass effects require a separate graphical application; this is a TUI.
EOF
}

# ---------------------------------------------------------------------------
# TUI Helpers (fzf with #15FFFF on black + POSIX TTY fallback)
# ---------------------------------------------------------------------------
tui_select() {
	_prompt=$1
	shift

	if [ "${OPT_NONINTERACTIVE:-0}" -eq 1 ]; then
		printf '%s\n' "$1"
		return 0
	fi

	if have_cmd fzf && [ -t 0 ] && [ -t 2 ]; then
		_rc=0
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
				--color="$FZF_COLORS"
		) || _rc=$?
		if [ "$_rc" -eq 0 ] && [ -n "$_choice" ]; then
			printf '%s\n' "$_choice"
			return 0
		elif [ "$_rc" -eq 1 ] || [ "$_rc" -eq 130 ]; then
			printf '%s\n' "$1"
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
		IFS= read -r _ans || _ans=""
		case $_ans in
			''|*[!0-9]*) _ans=1 ;;
		esac
		_ans=$(printf '%s' "$_ans" | sed 's/^0*//')
		[ -n "$_ans" ] || _ans=1
		_cur=1
		for _item in "$@"; do
			if [ "$_cur" = "$_ans" ]; then
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
	_val=""
	if [ "${OPT_NONINTERACTIVE:-0}" -eq 0 ] && [ -t 0 ] && [ -t 2 ]; then
		printf '%s%s [%s]: %s' "$C_BOLD" "$_label" "$_def" "$C_RST" >&2
		IFS= read -r _val || _val=""
	fi
	_val=${_val:-$_def}
	if [ -n "$_val" ]; then
		require_literal "$_label" "$_val"
	fi
	printf '%s\n' "$_val"
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
commit_file() (
	_commit_tmp=$1
	_commit_base=$2
	_commit_ext=$3
	if [ ! -L "${_commit_base}${_commit_ext}" ] && [ -f "${_commit_base}${_commit_ext}" ] && cmp -s -- "$_commit_tmp" "${_commit_base}${_commit_ext}"; then
		msg "[IDEMPOTENT] Unchanged: ${_commit_base}${_commit_ext}"
		printf '%s\n' "${_commit_base}${_commit_ext}"
		return 0
	fi
	set +f
	for _commit_existing in "$_commit_base".[0-9]*"$_commit_ext"; do
		_commit_suffix=${_commit_existing#"$_commit_base".}
		_commit_suffix=${_commit_suffix%"$_commit_ext"}
		case $_commit_suffix in ''|0*|*[!0-9]*) continue ;; esac
		if [ ! -L "$_commit_existing" ] && [ -f "$_commit_existing" ] && cmp -s -- "$_commit_tmp" "$_commit_existing"; then
			msg "[IDEMPOTENT] Unchanged: $_commit_existing"
			printf '%s\n' "$_commit_existing"
			return 0
		fi
	done
	set -f
	_commit_n=0
	while [ "$_commit_n" -le 9999 ]; do
		if [ "$_commit_n" -eq 0 ]; then
			_commit_dest=${_commit_base}${_commit_ext}
		else
			_commit_dest=${_commit_base}.${_commit_n}${_commit_ext}
		fi
		# -T treats even a directory as the destination itself. A hard link
		# publishes the already-complete file atomically and cannot overwrite.
		if ln -T -- "$_commit_tmp" "$_commit_dest" 2>/dev/null; then
			msg "[CREATED] $_commit_dest"
			printf '%s\n' "$_commit_dest"
			return 0
		fi
		if [ ! -L "$_commit_dest" ] && [ -f "$_commit_dest" ] &&
			cmp -s -- "$_commit_tmp" "$_commit_dest"; then
			msg "[IDEMPOTENT] Unchanged: $_commit_dest"
			printf '%s\n' "$_commit_dest"
			return 0
		fi
		if [ ! -e "$_commit_dest" ] && [ ! -L "$_commit_dest" ]; then
			die "Cannot atomically publish $_commit_dest (check permissions and ln -T support)"
		fi
		_commit_n=$((_commit_n + 1))
	done
	die "Unable to allocate non-colliding filename for ${_commit_base}${_commit_ext}"
)

# ---------------------------------------------------------------------------
# Feature Module Prompts & Snippet Generators
# Appends indented directives to $TMP_SITE
# ---------------------------------------------------------------------------
emit_line() {
	printf '%s\n' "$*" >> "$TMP_SITE"
}

# Shared static-serving policy used by SPA, PHP, media and subpath routes.
emit_static_handler() {
	_static_indent=$1
	_static_browse=$2
	_static_hide=$3
	_hide_cfg=$(hide_config_paths)
	emit_line "${_static_indent}file_server {"
	[ "$_static_browse" != "yes" ] || emit_line "${_static_indent}	browse"
	emit_line "${_static_indent}	hide ${_static_hide:+$_static_hide }$_hide_cfg .mkcaddy.* .mkplaylist.*"
	[ -z "$OPT_INDEX" ] || emit_line "${_static_indent}	index $OPT_INDEX"
	[ -z "$OPT_PRECOMP" ] || emit_line "${_static_indent}	precompressed $OPT_PRECOMP"
	emit_line "${_static_indent}}"
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
			_q_adm=$(caddy_quote "$_adm_addr")
			_admin_line="	admin $_q_adm"
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
			_q_email=$(caddy_quote "$_email")
			_https_lines="	email $_q_email"
			;;
		local_certs*)
			_https_lines="	local_certs"
			;;
		staging*)
			_email=$(tui_input "ACME Registration Email" "admin@example.com")
			_q_email=$(caddy_quote "$_email")
			_https_lines="	email $_q_email
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
		require_port "Global HTTP port" "$_hp"
		require_port "Global HTTPS port" "$_sp"
		_ports_line="	http_port ${_hp}
	https_port ${_sp}"
	fi

	if tui_yesno "Customize HTTP server protocols?" "no"; then
		OPT_PROTOCOLS=$(tui_input "Protocols (h1 h2 h2c h3)" "h1 h2 h3")
		for _protocol in $OPT_PROTOCOLS; do
			case $_protocol in h1|h2|h2c|h3) ;; *) die "Invalid HTTP protocol: $_protocol" ;; esac
		done
	fi
	_q_opt_email=""
	_q_opt_admin=""
	_q_opt_gfrag=""
	[ -z "$OPT_EMAIL" ] || _q_opt_email=$(caddy_quote "$OPT_EMAIL")
	[ -z "$OPT_ADMIN" ] || _q_opt_admin=$(caddy_quote "$OPT_ADMIN")
	[ -z "$OPT_GLOBAL_FRAGMENT" ] || _q_opt_gfrag=$(caddy_quote "$OPT_GLOBAL_FRAGMENT")
	{
		printf '{\n'
		[ -n "$_admin_line" ] && printf '%s\n' "$_admin_line"
		[ -n "$_https_lines" ] && printf '%s\n' "$_https_lines"
		[ -n "$_ports_line" ] && printf '%s\n' "$_ports_line"
		if [ -n "$OPT_PROTOCOLS" ]; then
			printf '\tservers {\n\t\tprotocols %s\n\t}\n' "$OPT_PROTOCOLS"
		fi
		[ -z "$_q_opt_email" ] || printf '\temail %s\n' "$_q_opt_email"
		[ -z "$_q_opt_admin" ] || printf '\tadmin %s\n' "$_q_opt_admin"
		[ -z "$_q_opt_gfrag" ] || printf '\timport %s\n' "$_q_opt_gfrag"
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
	_lan_ip=$(detect_lan_ip || true)
	_vpn_ip=$(detect_vpn_ip || true)
	_def_bind="127.0.0.1"
	[ -z "$_lan_ip" ] || [ "$_lan_ip" = "127.0.0.1" ] || _def_bind="${_lan_ip} 127.0.0.1"
	if [ -n "${OPT_BIND:-}" ]; then
		case $OPT_BIND in all) SITE_BIND="" ;; *) SITE_BIND=$OPT_BIND ;; esac
	elif [ "$OPT_NONINTERACTIVE" -eq 1 ]; then
		SITE_BIND="127.0.0.1"
	else
		set --
		if [ -n "$_lan_ip" ] && [ "$_lan_ip" != "127.0.0.1" ]; then
			if [ -n "$_vpn_ip" ] && [ "$_vpn_ip" != "127.0.0.1" ] && [ "$_vpn_ip" != "$_lan_ip" ]; then
				set -- "$@" "${_lan_ip} 127.0.0.1 (auto-detected physical LAN + loopback — bypasses VPN)"
				set -- "$@" "${_lan_ip} ${_vpn_ip} 127.0.0.1 (physical LAN + active WireGuard VPN + loopback)"
			else
				set -- "$@" "${_lan_ip} 127.0.0.1 (auto-detected physical LAN + loopback)"
			fi
		fi
		set -- "$@" "all (omit bind directive / listen on all interfaces)"
		set -- "$@" "0.0.0.0 (explicit IPv4 all interfaces)"
		set -- "$@" "127.0.0.1 (loopback / localhost only)"
		if [ -n "$_vpn_ip" ] && [ "$_vpn_ip" != "127.0.0.1" ] && [ "$_vpn_ip" != "$_lan_ip" ]; then
			set -- "$@" "${_vpn_ip} 127.0.0.1 (VPN tunnel + loopback only)"
		fi
		set -- "$@" "Custom bind IP address(es)..."
		_bind_sel=$(tui_select "Network Interface Binding (bind directive)" "$@")
		case $_bind_sel in
			"all"*)    SITE_BIND="" ;;
			"Custom"*) SITE_BIND=$(tui_input "Enter space-separated bind IPs" "$_def_bind") ;;
			*)         SITE_BIND=${_bind_sel%% (*} ;;
		esac
	fi

	require_tokens "Site address" "$SITE_ADDR"
	[ -z "$SITE_BIND" ] || require_tokens "Bind addresses" "$SITE_BIND"
	SITE_BIND=$(printf '%s\n' "$SITE_BIND" | awk '{for (i=1; i<=NF; i++) if (!seen[$i]++) {printf "%s%s", sep, $i; sep=" "}} END {print ""}')
	[ -n "$SITE_BIND" ] && emit_line "	bind ${SITE_BIND}"

	if [ "$OPT_TLS" = "internal" ]; then
		case $SITE_ADDR in http://*|*:80|:80) die "tls internal conflicts with an explicit HTTP site" ;; esac
		emit_line "	tls internal"
		return 0
	fi
	# TLS configuration if interactive and non-HTTP port
	case $SITE_ADDR in
		:*|http://*|*:80)
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
						_q_cert=$(caddy_quote "$_cert")
						_q_key=$(caddy_quote "$_key")
						emit_line "	tls $_q_cert $_q_key"
						;;
					dns*)
						_prov=$(tui_select "DNS-01 Provider Module" \
							"cloudflare" "route53" "duckdns" "digitalocean" "hetzner")
						if [ "$_prov" != "route53" ]; then
							_tok_env=$(tui_input "Environment variable name for API token" "DNS_API_TOKEN")
							case $_tok_env in ''|[0-9]*|*[!A-Za-z0-9_]*) die "Invalid DNS token environment variable name" ;; esac
						fi
						require_module "dns.providers.${_prov}"
						emit_line "	tls {"
						if [ "$_prov" = "route53" ]; then
							emit_line "		dns route53"
						else
							emit_line "		dns ${_prov} {env.${_tok_env}}"
						fi
						emit_line "	}"
						;;
				esac
			fi
			;;
	esac
}

# 3. File Server & Interactive File Browser Module
mod_file_server() {
	claim_content mod_file_server || return 0
	_default_root=${OPT_ROOT:-"$TARGET_DIR"}
	bold_msg "--- [Module: File Server & File Browser] ---"

	if [ -n "${OPT_ROOT:-}" ]; then
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
			_tpl_path=$(absolute_path "$_tpl_path")
		fi
	fi

	_hide_pat=$OPT_HIDE
	if [ "${OPT_NONINTERACTIVE:-0}" -eq 0 ] && [ "${SET_HIDE:-0}" -eq 0 ]; then
		_hide_sel=$(tui_select "Hide Sensitive Dotfiles / Patterns" \
			"standard - Hide .git, .env, *.bak, .DS_Store" \
			"none     - Do not add hide directive" \
			"custom   - Enter custom space-separated hide patterns")
		case $_hide_sel in
			standard*) _hide_pat=".git .env *.bak .DS_Store" ;;
			none*)     _hide_pat="" ;;
			custom*)   _hide_pat=$(tui_input "Space-separated hide patterns" ".git .env *.bak") ;;
		esac
	fi

	_precomp=$OPT_PRECOMP
	if [ "${OPT_NONINTERACTIVE:-0}" -eq 0 ] && [ -z "$_precomp" ]; then
		if tui_yesno "Serve precompressed sidecar files (.zst, .br, .gz)?" "no"; then
			_precomp="zstd br gzip"
		fi
	fi

	_fs_root=$(absolute_path "$_fs_root")
	[ -z "$_hide_pat" ] || require_tokens "Hide patterns" "$_hide_pat"
	_q_fs_root=$(caddy_quote "$_fs_root")
	_hide_cfg=$(hide_config_paths)
	emit_line "	root * $_q_fs_root"
	{
		emit_line "	file_server {"
		if [ "$_browse" = "yes" ]; then
			if [ -n "$_tpl_path" ]; then
				_q_tpl=$(caddy_quote "$_tpl_path")
				emit_line "		browse $_q_tpl"
			else
				emit_line "		browse"
			fi
		fi
		[ -z "$OPT_INDEX" ] || emit_line "		index $OPT_INDEX"
		emit_line "		hide ${_hide_pat:+$_hide_pat }$_hide_cfg .mkcaddy.* .mkplaylist.*"
		[ -n "$_precomp" ] && emit_line "		precompressed ${_precomp}"
		emit_line "	}"
	}
}

# 4. Dynamic M3U Playlist Responder Module
media_extensions() {
	_videos="mp4 wmv mkv avi mov mpeg mpg mpe m4v webm ts flv ogv 3gp 3g2 m2ts mts m2v vob vro mxf asf divx f4v mp3 flac aac m4a m4b ogg oga opus wav wave aif aiff aifc au snd wma ac3 eac3 dts amr ape alac tak wv caf mka"
	_images="jpg jpeg jpe png gif webp bmp dib tiff tif svg avif heic heif apng jxl ico"
	case $1 in
		videos) printf '%s\n' "$_videos" ;;
		images) printf '%s\n' "$_images" ;;
		both) printf '%s %s\n' "$_videos" "$_images" ;;
		*) die "Invalid media kind: $1" ;;
	esac
}

emit_m3u_response() {
	have_cmd "$PYTHON_BIN" || die "Python 3.9+ is required for recursive media generation"
	"$PYTHON_BIN" -c 'import sys; sys.exit(sys.version_info < (3, 9))' || die "Python 3.9+ is required"
	_m_exts=$(media_extensions "$_mtype")
	"$PYTHON_BIN" - "$_m_exts" "$OPT_MEDIA_SORT" "$OPT_MEDIA_ORDER" "$OPT_MEDIA_DEPTH" "$OPT_HIDE .mkplaylist.* .mkcaddy.*" "$_m3u_root" "$TARGET_BASE" <<'PYTHON_TEMPLATE'
"""Generate a native Caddy template; no runtime helper or extra service is needed."""
import fnmatch
import json
import os
import re
import sys

extensions, field, direction, depth, hides, root, configuration = [
    os.fsencode(arg).decode('utf-8', 'surrogateescape') for arg in sys.argv[1:]
]
if field not in ('date', 'size', 'name', 'shuffle') or direction not in ('asc', 'desc'):
    raise SystemExit('Invalid media sort or order')
try:
    depth = int(depth)
except ValueError:
    raise SystemExit('Media depth must be a nonnegative integer')
if not 0 <= depth <= 255:
    raise SystemExit('Media depth must be 0..255 (0=unlimited)')

def go_string(value):
    return json.dumps(value, ensure_ascii=True).replace('`', r'\u0060')

# Match the same basename/path globs used by file_server hide. Relative paths
# containing a slash are relative to Caddy's working directory, as in Caddy.
patterns = []
for pattern in hides.split():
    if '/' in pattern:
        absolute = os.path.abspath(pattern)
        relative = os.path.relpath(absolute, root)
        if relative == '..' or relative.startswith('../'):
            continue
        subject = '$relative'
        pattern = relative
    else:
        subject = '.Name'
    expression = '^' + fnmatch.translate(pattern).replace(r'\Z', r'\z')
    # Python's translation uses atomic groups for some multi-star globs. RE2
    # does not implement atomic groups; their backtracking optimization is not
    # needed here. Retain their matching semantics with ordinary groups.
    expression = expression.replace('(?>', '(?:')
    patterns.append(f'(regexMatch {go_string(expression)} {subject})')
relative_config = os.path.relpath(configuration, root)
if relative_config != '..' and not relative_config.startswith('../'):
    patterns.append(f'(eq $relative {go_string(relative_config)})')
    patterns.append(f'(hasPrefix {go_string(relative_config + ".")} $relative)')
hidden = '(or ' + ' '.join(patterns) + ')' if patterns else 'false'
suffix = '(or ' + ' '.join(f'(hasSuffix {go_string("." + ext)} $lower)' for ext in extensions.split()) + ')'

if field == 'shuffle':
    sort_key = 'printf "%s\\t%s" (randAlphaNum 32) $relative'
elif field == 'size':
    numeric = '(sub 9223372036854775807 .Size)' if direction == 'desc' else '.Size'
    sort_key = f'printf "%020d\\t%s" {numeric} $relative'
elif field == 'date':
    seconds = '(sub 253402300800 .ModTime.Unix)' if direction == 'desc' else '(add .ModTime.Unix 62135596800)'
    fraction = '(sub 999999999 .ModTime.Nanosecond)' if direction == 'desc' else '.ModTime.Nanosecond'
    sort_key = f'printf "%020d.%09d\\t%s" {seconds} {fraction} $relative'
else:
    sort_key = '$relative'
ordering = 'keys $state.paths | sortAlpha' + (' | reverse' if field == 'name' and direction == 'desc' else '')

# Readdir returns FileInfo from lstat, so symlinks are excluded without ever
# opening their targets. Directory handles close before recursion. FileInfo.Sys
# provides Linux device/inode identity, including for hard links.
body = r'''{{- define "mkplaylist_walk" -}}
{{- $directory := .ctx.Root.Open .path -}}
{{- $info := $directory.Stat -}}
{{- $_ := set .state.dirs (printf "%v:%v" $info.Sys.Dev $info.Sys.Ino) true -}}
{{- $entries := $directory.Readdir -1 -}}
{{- $ignored := $directory.Close -}}
{{- $scope := . -}}
{{- range $entries -}}
  {{- $relative := trimPrefix "/" (printf "%s/%s" (trimSuffix "/" $scope.path) .Name) -}}
  {{- if not HIDDEN -}}
    {{- $identity := printf "%v:%v" .Sys.Dev .Sys.Ino -}}
    {{- if .IsDir -}}
      {{- if and (or (eq MAXDEPTH 0) (lt (add $scope.depth 1) MAXDEPTH)) (not (hasKey $scope.state.dirs $identity)) -}}
        {{- if ge $scope.depth 255 -}}{{ httpError 500 }}{{- end -}}
        {{- $_ := set $scope.state.dirs $identity true -}}
        {{- template "mkplaylist_walk" (dict "ctx" $scope.ctx "path" (printf "/%s" $relative) "depth" (add $scope.depth 1) "state" $scope.state) -}}
      {{- end -}}
    {{- else if .Mode.IsRegular -}}
      {{- $lower := lower .Name -}}
      {{- if SUFFIX -}}
        {{- $key := SORTKEY -}}
        {{- $oldkey := get $scope.state.files $identity -}}
        {{- if or (not $oldkey) (lt $relative (get $scope.state.paths $oldkey)) -}}
          {{- if $oldkey -}}{{- $_ := unset $scope.state.paths $oldkey -}}{{- end -}}
          {{- $_ := set $scope.state.files $identity $key -}}
          {{- $_ := set $scope.state.paths $key $relative -}}
        {{- end -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}
{{- $state := dict "paths" (dict) "dirs" (dict) "files" (dict) -}}
{{- template "mkplaylist_walk" (dict "ctx" $ "path" "/" "depth" 0 "state" $state) -}}
{{- printf "#EXTM3U\n" -}}
{{- range $key := ORDERING -}}
  {{- $relative := index $state.paths $key -}}
  {{- $uri := replace "%2F" "/" (pathEscape $relative) -}}
  {{- printf "%s://%s/%s\n" (ternary "https" "http" (ne $.Req.TLS nil)) $.Req.Host $uri -}}
{{- end -}}'''
values = dict(HIDDEN=hidden, MAXDEPTH=str(depth), SUFFIX=suffix, SORTKEY=sort_key, ORDERING=ordering)
body = re.sub(r'\b(HIDDEN|MAXDEPTH|SUFFIX|SORTKEY|ORDERING)\b', lambda match: values[match[0]], body)
print('\t\trespond `' + body + '` 200')
PYTHON_TEMPLATE
}

mod_m3u_streamer() {
	claim_content mod_m3u_streamer || return 0
	bold_msg "--- [Module: Dynamic M3U Playlist & Media Streamer] ---"
	_def_root=${OPT_ROOT:-"$TARGET_DIR"}
	if [ -n "${OPT_ROOT:-}" ]; then
		_m3u_root=$OPT_ROOT
	else
		_root_sel=$(tui_select "Media Root Directory" \
			"${_def_root} (selected target directory)" \
			"/s4/s4Downloads (preset media root)" \
			"Custom media root path...")
		case $_root_sel in
			"/s4/s4Downloads"*) _m3u_root="/s4/s4Downloads" ;;
			"${_def_root}"*)    _m3u_root=$_def_root ;;
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

	_m3u_root=$(absolute_path "$_m3u_root")
	[ -d "$_m3u_root" ] && [ -r "$_m3u_root" ] && [ -x "$_m3u_root" ] || die "Cannot read media root: $_m3u_root"
	require_tokens "Playlist endpoint" "$_m3u_route"
	_q_m3u_root=$(caddy_quote "$_m3u_root")

	{
		printf '\troot * %s\n\n' "$_q_m3u_root"
		printf '\thandle %s {\n' "$_m3u_route"
		printf '\t\theader Content-Type "audio/x-mpegurl; charset=utf-8"\n'
		printf '\t\theader Cache-Control "no-cache, no-store, must-revalidate"\n'
		printf '\t\ttemplates {\n\t\t\tmime audio/x-mpegurl\n\t\t}\n'
		emit_m3u_response || die "Cannot generate recursive media template"
		printf '\t}\n\n\thandle {\n'
	} >> "$TMP_SITE"

	emit_static_handler "		" "$_browse_Static" "$OPT_HIDE"
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
	if [ -n "${OPT_UPSTREAM:-}" ]; then
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
	_passive=""
	_max_fails=""
	_health_status=""
	_hdr_down=""

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
			require_tokens "Health check URI" "$_hc_uri"
			require_tokens "Health check interval" "$_hc_int"
			require_tokens "Health check timeout" "$_hc_to"
		fi

		if [ -n "$_hc_uri" ]; then
			_health_status=$(tui_input "Expected health status" "200")
			require_tokens "Expected health status" "$_health_status"
		fi
		if tui_yesno "Enable passive health checks?" "no"; then
			_passive=$(tui_input "Passive failure duration" "30s")
			_max_fails=$(tui_input "Maximum failures before marking down" "3")
			require_tokens "Passive failure duration" "$_passive"
			case $_max_fails in ''|0*|*[!0-9]*) die "Maximum failures must be a positive integer" ;; esac
		fi
		if tui_yesno "Remove a response header from the upstream?" "no"; then
			_hdr_down=$(tui_input "Response header to remove" "Server")
			require_tokens "Response header name" "$_hdr_down"
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

	require_tokens "Reverse proxy upstreams" "$_upstreams"
	_rp_head="	reverse_proxy"
	[ -z "$_rp_match" ] || require_tokens "Reverse proxy matcher" "$_rp_match"
	[ -n "$_rp_match" ] && _rp_head="${_rp_head} ${_rp_match}"
	_rp_head="${_rp_head} ${_upstreams}"

	if [ -z "$_lb_policy" ] && [ -z "$_hc_uri" ] && [ -z "$_flush" ] && [ "$_hdr_up" = "no" ] && [ "$_https_skip" = "no" ] && [ -z "$_passive" ] && [ -z "$_hdr_down" ]; then
		emit_line "$_rp_head"
	else
		emit_line "${_rp_head} {"
		[ -n "$_lb_policy" ] && emit_line "		lb_policy ${_lb_policy}"
		if [ -n "$_hc_uri" ]; then
			emit_line "		health_uri ${_hc_uri}"
			emit_line "		health_interval ${_hc_int}"
			emit_line "		health_timeout ${_hc_to}"
		fi
		[ -z "$_health_status" ] || emit_line "		health_status $_health_status"
		if [ -n "$_passive" ]; then
			emit_line "		fail_duration $_passive"
			emit_line "		max_fails $_max_fails"
		fi
		[ -z "$_hdr_down" ] || emit_line "		header_down -$_hdr_down"
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
	claim_content mod_spa_router || return 0
	bold_msg "--- [Module: Single-Page Application (SPA) Router] ---"
	_def_root=${OPT_ROOT:-"/var/www/app/dist"}
	if [ -n "${OPT_ROOT:-}" ]; then
		_spa_root=$OPT_ROOT
	else
		_spa_root=$(tui_input "SPA build output root directory" "$_def_root")
	fi
	_spa_root=$(absolute_path "$_spa_root")
	_q_spa_root=$(caddy_quote "$_spa_root")
	_spa_index=$(tui_input "SPA fallback entry file" "/index.html")
	require_tokens "SPA fallback path" "$_spa_index"

	emit_line "	root * $_q_spa_root"
	mod_compression

	if tui_yesno "Add split /api/* reverse_proxy to a backend service?" "yes"; then
		_api_path=$(tui_input "API route prefix" "/api/*")
		if [ -n "${OPT_UPSTREAM:-}" ]; then
			_api_up=$OPT_UPSTREAM
		else
			_api_up=$(tui_input "API backend upstream" "127.0.0.1:8080")
		fi
		require_tokens "API path" "$_api_path"
		require_tokens "API upstream" "$_api_up"
		emit_line ""
		emit_line "	handle ${_api_path} {"
		emit_line "		reverse_proxy ${_api_up}"
		emit_line "	}"
	fi

	if tui_yesno "Add immutable Cache-Control headers for static hashed assets (*.js, *.css, *.woff2)?" "yes"; then
		emit_line ""
		emit_line "	@static path_regexp fingerprint \"[.-][a-fA-F0-9]{8,}[.](js|css|png|jpe?g|gif|webp|svg|ico|woff2?)$\""
		emit_line "	header @static Cache-Control \"public, max-age=31536000, immutable\""
	fi

	emit_line ""
	emit_line "	handle {"
	emit_line "		try_files {path} {path}/ ${_spa_index}"
	emit_static_handler "		" no "$OPT_HIDE"
	emit_line "	}"
}

# 7. PHP-FPM / FastCGI Application Server Module
mod_php_fastcgi() {
	claim_content mod_php_fastcgi || return 0
	# Protect private paths before the PHP rewrite/proxy, not just file_server.
	cat >> "$SITE_ACCESS" <<'EOF'
	@php_sensitive path_regexp php_sensitive "(^|/)[.](git|env|ht)"
	respond @php_sensitive "404 Not Found" 404
EOF
	bold_msg "--- [Module: PHP-FPM / FastCGI Application Server] ---"
	if [ -n "${OPT_ROOT:-}" ]; then
		_php_root=$OPT_ROOT
	else
		_php_root=$(tui_input "PHP application document root" "/var/www/html")
	fi
	_php_root=$(absolute_path "$_php_root")
	_q_php_root=$(caddy_quote "$_php_root")
	if [ -n "$OPT_UPSTREAM" ]; then
		_fpm_up=$OPT_UPSTREAM
	else
		_fpm_sel=$(tui_select "PHP-FPM Upstream Socket / Address" \
			"unix//run/php/php-fpm.sock     - Debian/Ubuntu/Arch default Unix socket" \
			"unix//var/run/php-fpm/www.sock - RHEL/Fedora Unix socket" \
			"127.0.0.1:9000                 - TCP localhost port 9000 (Docker / standard)" \
			"Custom PHP-FPM upstream...")
		case $_fpm_sel in
			"unix//run/php/php-fpm.sock"*)     _fpm_up="unix//run/php/php-fpm.sock" ;;
			"unix//var/run/php-fpm/www.sock"*) _fpm_up="unix//var/run/php-fpm/www.sock" ;;
			"127.0.0.1:9000"*)                 _fpm_up="127.0.0.1:9000" ;;
			*)                                 _fpm_up=$(tui_input "Enter PHP-FPM socket or host:port" "127.0.0.1:9000") ;;
		esac
	fi
	emit_line "	root * $_q_php_root"
	mod_compression
	require_tokens "PHP-FPM upstream" "$_fpm_up"
	_php_index=$(tui_input "PHP index filename" "index.php")
	_php_split=$(tui_input "FastCGI split suffix" ".php")
	require_tokens "PHP index" "$_php_index"
	require_tokens "FastCGI split suffix" "$_php_split"
	emit_line "	php_fastcgi ${_fpm_up} {"
	emit_line "		index $_php_index"
	emit_line "		split $_php_split"
	emit_line "	}"
	emit_static_handler "	" no "${OPT_HIDE:+$OPT_HIDE }.ht*"
}

# 8. Authentication Module (basic_auth / forward_auth)
mod_authentication() {
	_auth_target=$TMP_SITE
	TMP_SITE=$SITE_AUTH
	bold_msg "--- [Module: Authentication (Basic Auth / Forward Auth)] ---"
	_auth_sel=$(tui_select "Authentication Method" \
		"basic_auth   - HTTP Basic Authentication (username + bcrypt password hash)" \
		"forward_auth - External Auth Portal (Authelia, Authentik, OAuth2-Proxy, Tailscale)")
	emit_line "	route {"
	case $_auth_sel in
		basic_auth*)
			_match=$(tui_input "Path matcher to protect (* for entire site)" "*")
			require_tokens "Authentication matcher" "$_match"
			case $_match in *' '*) die "Authentication matcher must be a single matcher token" ;; esac
			if [ -n "$OPT_AUTH_USER" ]; then
				_user=$OPT_AUTH_USER
			else
				_user=$(tui_input "Username" "admin")
			fi
			if [ -n "$OPT_HASH_FILE" ]; then
				_hash=$(cat -- "$OPT_HASH_FILE") || die "Cannot read bcrypt hash file"
			else
				_hash=$(tui_input "Bcrypt hash (generate with caddy hash-password; required)" "")
			fi
			require_line "Bcrypt hash" "$_hash"
			printf '%s\n' "$_hash" | awk 'length($0)==60 && substr($0,5,2)+0 >= 4 && substr($0,5,2)+0 <= 31 && $0 ~ /^\$2[aby]\$[0-9][0-9]\$[.\/A-Za-z0-9]+$/ {ok=1} END {exit !ok}' || die "A valid bcrypt hash is required; no shared default credential is supplied"
			require_literal "Authentication username" "$_user"
			_q_user=$(caddy_quote "$_user")
			_q_hash=$(caddy_quote "$_hash")
			if [ "$_match" = "*" ]; then
				emit_line "	basic_auth {"
			else
				emit_line "	basic_auth ${_match} {"
			fi
			emit_line "		$_q_user $_q_hash"
			emit_line "	}"
			;;
		forward_auth*)
			_fa_up=$(tui_input "Auth portal upstream (e.g. 127.0.0.1:9091 for Authelia)" "127.0.0.1:9091")
			_fa_uri=$(tui_input "Auth verification URI" "/api/verify?rd=https://auth.example.com/")
			_fa_hdrs=$(tui_input "Identity headers to copy" "Remote-User Remote-Groups Remote-Name Remote-Email")
			require_tokens "Authentication upstream" "$_fa_up"
			require_tokens "Identity headers" "$_fa_hdrs"
			_q_fa_uri=$(caddy_quote "$_fa_uri")
			emit_line "	forward_auth ${_fa_up} {"
			emit_line "		uri $_q_fa_uri"
			emit_line "		copy_headers ${_fa_hdrs}"
			emit_line "	}"
			;;
	esac
	emit_line "	}"
	TMP_SITE=$_auth_target
}

# 9. Security Headers & CORS Module
mod_headers_cors() {
	_headers_target=$TMP_SITE
	TMP_SITE=$SITE_CORS
	bold_msg "--- [Module: Security Headers & CORS] ---"
	if [ "$SITE_HAS_HEADERS" -eq 0 ] && { [ "${OPT_SEC_HEADERS:-}" = "yes" ] || tui_yesno "Add hardened HTTP security headers (HSTS, X-Frame-Options, nosniff, Referrer-Policy, -Server)?" "yes"; }; then
		SITE_HAS_HEADERS=1
		cat >> "$TMP_SITE" <<'EOF'
	header {
		Strict-Transport-Security "max-age=31536000"
		X-Content-Type-Options "nosniff"
		X-Frame-Options "SAMEORIGIN"
		Referrer-Policy "strict-origin-when-cross-origin"
		Permissions-Policy "accelerometer=(), camera=(), geolocation=(), microphone=(), payment=(), usb=()"
		-Server
	}
EOF
		if tui_yesno "Add a Content-Security-Policy header (review for your application)?" "no"; then
			_csp=$(tui_input "CSP policy" "default-src 'self'; object-src 'none'; base-uri 'self'")
			_q_csp=$(caddy_quote "$_csp")
			emit_line "	header Content-Security-Policy $_q_csp"
		fi
	fi

	if [ "$SITE_HAS_CORS" -eq 0 ] && { [ -n "$OPT_CORS" ] || { [ "$OPT_NONINTERACTIVE" -eq 0 ] && tui_yesno "Configure CORS headers & preflight?" "no"; }; }; then
		SITE_HAS_CORS=1
		if [ -n "$OPT_CORS" ]; then
			_origin=$OPT_CORS
		else
			_origin=$(tui_input "Allowed Origin (one origin or *)" "*")
		fi
		require_literal "CORS origin" "$_origin"
		_methods=$(tui_input "Allowed HTTP Methods" "GET, POST, PUT, PATCH, DELETE, OPTIONS")
		_headers=$(tui_input "Allowed Request Headers" "Content-Type, Authorization, X-Requested-With")
		_q_origin=$(caddy_quote "$_origin")
		_q_methods=$(caddy_quote "$_methods")
		_q_headers=$(caddy_quote "$_headers")
		cat >> "$TMP_SITE" <<EOF
	header Access-Control-Allow-Origin $_q_origin
	header +Vary Origin
	header Access-Control-Allow-Methods $_q_methods
	header Access-Control-Allow-Headers $_q_headers
	header Access-Control-Max-Age "86400"
	route {
		@cors_preflight {
			method OPTIONS
			header Origin *
			header Access-Control-Request-Method *
		}
		respond @cors_preflight "" 204
	}
EOF
	fi
	TMP_SITE=$_headers_target
}

# 10. Compression Module (encode)
mod_compression() {
	[ "$SITE_HAS_ENCODE" -eq 0 ] || return 0
	bold_msg "--- [Module: Response Compression (encode)] ---"
	_enc_sel=$(tui_select "Compression Algorithms" \
		"zstd gzip    - Zstandard + Gzip" "br zstd gzip - Brotli + Zstandard + Gzip (plugin)")
	case $_enc_sel in
		br*) require_module http.encoders.br; emit_line "	encode br zstd gzip" ;;
		*) emit_line "	encode zstd gzip" ;;
	esac
	SITE_HAS_ENCODE=1
}

# 11. Redirects, Rewrites & Path Stripping Module
mod_redirects_rewrites() {
	bold_msg "--- [Module: Redirects, Rewrites & Subpath Routing] ---"
	_rw_sel=$(tui_select "Redirect / Rewrite Rule Type" \
		"www-to-apex  - Permanent 308 redirect from www.<domain> to <domain>" \
		"apex-to-www  - Permanent 308 redirect from apex to www" \
		"strip-prefix - Strip a URI path prefix" \
		"redir        - Custom URL redirect (redir <from> <to> <code>)" \
		"handle_path  - Strip path prefix and route to upstream or root" \
		"rewrite      - Internal URI rewrite (rewrite <from> <to>)")
	case $_rw_sel in
		www-to-apex*|apex-to-www*)
			_dom=${SITE_ADDR#http://}
			_dom=${_dom#https://}
			_dom=${_dom#www.}
			case $_dom in
				''|:*|*[!a-zA-Z0-9.-]*)
					[ "${OPT_NONINTERACTIVE:-0}" -eq 0 ] || die "Canonical redirects require a domain in -a (e.g. example.com)"
					_dom="example.com"
					;;
			esac
			_dom=$(tui_input "Apex domain name" "$_dom")
			case $_dom in ''|.*|*.|-*|*-|*[!a-zA-Z0-9.-]*) die "Canonical redirects require an apex domain name" ;; esac
			case $_rw_sel in
				apex-to-www*)
					SITE_ADDR=$_dom
					emit_line "	@canonical host ${_dom}"
					emit_line "	redir @canonical https://www.${_dom}{uri} 308" ;;
				*)
					SITE_ADDR=www.${_dom}
					emit_line "	@canonical host www.${_dom}"
					emit_line "	redir @canonical https://${_dom}{uri} 308" ;;
			esac
			;;
		strip-prefix*)
			_prefix=$(tui_input "URI prefix to strip" "/prefix")
			require_tokens "URI prefix" "$_prefix"
			emit_line "	uri strip_prefix $_prefix"
			;;
		redir*)
			_from=$(tui_input "Match path (e.g. /old-path or *)" "/old")
			_to=$(tui_input "Target URL or path" "/new")
			require_tokens "Redirect matcher" "$_from"
			_code=$(tui_select "Redirect HTTP Status" "308 (Permanent Redirect)" "301 (Moved Permanently)" "302 (Found / Temporary)" "307 (Temporary Redirect)")
			_code_num=${_code%% *}
			_q_to=$(caddy_quote "$_to")
			emit_line "	redir ${_from} $_q_to ${_code_num}"
			;;
		handle_path*)
			_pfx=$(tui_input "Path prefix to match & strip (e.g. /service/*)" "/service/*")
			_up=$(tui_input "Upstream host:port for stripped route" "127.0.0.1:9001")
			require_tokens "Path matcher" "$_pfx"
			require_tokens "Route upstream" "$_up"
			emit_line "	handle_path ${_pfx} {"
			emit_line "		reverse_proxy ${_up}"
			emit_line "	}"
			;;
		rewrite*)
			_from=$(tui_input "Match path pattern" "/legacy/*")
			_to=$(tui_input "Rewrite target URI" "/v2{uri}")
			require_tokens "Rewrite matcher" "$_from"
			_q_to=$(caddy_quote "$_to")
			emit_line "	rewrite ${_from} $_q_to"
			;;
	esac
}

# 12. IP Access Control & Custom Error Pages
mod_access_errors() {
	_access_target=$TMP_SITE
	TMP_SITE=$SITE_ACCESS
	bold_msg "--- [Module: IP Access Control & Custom Error Handling] ---"
	if [ -n "$OPT_ALLOW" ] || [ -n "$OPT_DENY" ] || tui_yesno "Restrict access by client IP / CIDR ranges (remote_ip)?" "yes"; then
		emit_line "	route {"
		if [ -n "$OPT_ALLOW" ]; then
			_ip_mode="allow-custom"
		elif [ -n "$OPT_DENY" ]; then
			_ip_mode="block-custom"
		else
			_ip_mode=$(tui_select "IP Filter Policy" \
				"allow-private - Allow only RFC1918 LAN & loopback (private_ranges), block others" \
				"allow-custom  - Allow only specific CIDR/IP list, block others" \
				"block-custom  - Block specific CIDR/IP list")
		fi
		case $_ip_mode in
			allow-private*)
				emit_line "	@denied not remote_ip private_ranges 127.0.0.1 ::1"
				emit_line "	respond @denied \"403 Forbidden\" 403"
				;;
			allow-custom*)
				if [ -n "$OPT_ALLOW" ]; then
					_cidrs=$OPT_ALLOW
				else
					_cidrs=$(tui_input "Space-separated allowed IPs/CIDRs" "192.168.1.0/24 127.0.0.1")
				fi
				require_tokens "Allowed ranges" "$_cidrs"
				emit_line "	@denied not remote_ip ${_cidrs}"
				emit_line "	respond @denied \"403 Forbidden\" 403"
				;;
			block-custom*)
				if [ -n "$OPT_DENY" ]; then
					_cidrs=$OPT_DENY
				else
					_cidrs=$(tui_input "Space-separated blocked IPs/CIDRs" "203.0.113.0/24")
				fi
				require_tokens "Blocked ranges" "$_cidrs"
				emit_line "	@blocked remote_ip ${_cidrs}"
				emit_line "	respond @blocked \"403 Forbidden\" 403"
				;;
		esac
		emit_line "	}"
	fi

	TMP_SITE=$SITE_META
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
				_eroot=$(absolute_path "$_eroot")
				_q_eroot=$(caddy_quote "$_eroot")
				cat >> "$TMP_SITE" <<EOF
	handle_errors {
		root * $_q_eroot
		rewrite * /{err.status_code}.html
		file_server
	}
EOF
				;;
		esac
	fi
	TMP_SITE=$_access_target
}

# 13. Structured Access Logging Module
mod_logging() {
	[ "$SITE_HAS_LOG" -eq 0 ] || return 0
	SITE_HAS_LOG=1
	_log_target=$TMP_SITE
	TMP_SITE=$SITE_META
	if [ -n "$OPT_LOG" ]; then
		_log_dest=$OPT_LOG
	else
		_log_dest=$(tui_select "Access Log Output Destination" \
			"stdout - systemd / container logs" "stderr - Standard error" "file - Rotating file")
	fi
	_fmt=$(tui_select "Log Format" "json (structured JSON)" "console (human-readable)")
	_level=$(tui_select "Log Level" "INFO" "DEBUG" "WARN" "ERROR")
	emit_line "	log {"
	case $_log_dest in
		stdout*|stderr*) emit_line "		output ${_log_dest%% *}" ;;
		*)
			case $_log_dest in /*) _lpath=$_log_dest ;; *) _lpath=$(tui_input "Log file path" "/var/log/caddy/access.log") ;; esac
			_lpath=$(absolute_path "$_lpath")
			_q_lpath=$(caddy_quote "$_lpath")
			_rsize=$(tui_input "Rotation size" "100MiB")
			_rkeep=$(tui_input "Rotated files to keep" "5")
			_rkeep_for=$(tui_input "Retention duration" "720h")
			require_tokens "Log rotation size" "$_rsize"
			case $_rkeep in ''|*[!0-9]*) die "Rotated files to keep must be a nonnegative integer" ;; esac
			require_tokens "Log retention duration" "$_rkeep_for"
			emit_line "		output file $_q_lpath {"
			emit_line "			roll_size $_rsize"
			emit_line "			roll_keep $_rkeep"
			emit_line "			roll_keep_for $_rkeep_for"
			emit_line "		}"
			;;
	esac
	emit_line "		format ${_fmt%% *}"
	emit_line "		level $_level"
	emit_line "	}"
	TMP_SITE=$_log_target
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
		require_tokens "Service path" "$_spath"
		[ "$_count" -le 57535 ] || die "Too many service routes for automatic backend ports"
		case $_stype in
			"handle_path"*)
				_sup=$(tui_input "Backend upstream (host:port)" "${OPT_UPSTREAM:-127.0.0.1:$((8000 + _count))}")
				require_tokens "Service upstream" "$_sup"
				emit_line "	handle_path ${_spath} {"
				emit_line "		reverse_proxy ${_sup}"
				emit_line "	}"
				;;
			"handle "*)
				_sup=$(tui_input "Backend upstream (host:port)" "${OPT_UPSTREAM:-127.0.0.1:$((8000 + _count))}")
				require_tokens "Service upstream" "$_sup"
				emit_line "	handle ${_spath} {"
				emit_line "		reverse_proxy ${_sup}"
				emit_line "	}"
				;;
			"static"*)
				_sroot=$(tui_input "Static directory root" "/srv/service${_count}")
				_sroot=$(absolute_path "$_sroot")
				_q_sroot=$(caddy_quote "$_sroot")
				emit_line "	handle_path ${_spath} {"
				emit_line "		root * $_q_sroot"
				emit_static_handler "		" yes "$OPT_HIDE"
				emit_line "	}"
				;;
		esac
		_count=$((_count + 1))
		if ! tui_yesno "Add another service route to this site?" "no"; then
			break
		fi
	done
	emit_line '	handle {'
	emit_line '		respond "404 Not Found" 404'
	emit_line '	}'
}

# ---------------------------------------------------------------------------
# Site Block Orchestrator
# ---------------------------------------------------------------------------
build_site_block() {
	_preset=$1
	SITE_META=$(mktemp "$WORK_DIR/meta.XXXXXX")
	SITE_BODY=$(mktemp "$WORK_DIR/body.XXXXXX")
	SITE_ACCESS=$(mktemp "$WORK_DIR/access.XXXXXX")
	SITE_CORS=$(mktemp "$WORK_DIR/cors.XXXXXX")
	SITE_AUTH=$(mktemp "$WORK_DIR/auth.XXXXXX")
	TMP_SITE=$SITE_META
	SITE_HAS_ENCODE=0
	SITE_HAS_HEADERS=0
	SITE_HAS_CORS=0
	SITE_HAS_LOG=0
	SITE_CONTENT=""
	_saved_browse=$OPT_BROWSE

	prompt_site_header
	TMP_SITE=$SITE_BODY

	[ "${OPT_ENCODE:-}" = "yes" ] && mod_compression
	if [ -n "$OPT_ALLOW" ] || [ -n "$OPT_DENY" ]; then
		mod_access_errors
	fi
	if [ "${OPT_SEC_HEADERS:-}" = "yes" ] || [ -n "$OPT_CORS" ]; then
		mod_headers_cors
	fi

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
			case $SITE_ADDR in :*|http://*|*:80)
				[ "$OPT_TLS" = "internal" ] || die "secure-gateway requires an HTTPS hostname or -T internal" ;;
			esac
			mod_authentication
			[ "${OPT_SEC_HEADERS:-}" != "yes" ] && mod_headers_cors
			mod_reverse_proxy
			if tui_yesno "Add structured access logging?" "yes"; then
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
			if [ "$OPT_NONINTERACTIVE" -eq 1 ] && [ -z "$OPT_SITE_FRAGMENT" ]; then
				die "Noninteractive custom mode requires -c native site directives"
			fi
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
					"11. logging     - Structured Rotating Access Logs (JSON/Console)" \
					"12. native      - Import any installed native directive or module")
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
					"12."*)  mod_native_fragment ;;
					*)       break ;;
				esac
			done
			;;
		*)
			die "Unknown preset '$_preset'. Run '${0##*/}' with no args for help."
			;;
	esac

	if [ -n "$OPT_SITE_FRAGMENT" ]; then
		_q_sfrag=$(caddy_quote "$OPT_SITE_FRAGMENT")
		emit_line "	import $_q_sfrag"
	fi
	[ -z "$OPT_LOG" ] || mod_logging
	{
		printf '%s {\n' "$SITE_ADDR"
		cat -- "$SITE_META"
		# Literal outer route: policy always precedes terminal content handlers.
		printf '\troute {\n'
		cat -- "$SITE_ACCESS" "$SITE_CORS" "$SITE_AUTH"
		# handle applies Caddy's ordinary directive sorting inside the content
		# scope, preserving rewrites, middleware and exclusive path dispatch.
		printf '\t\thandle {\n'
		cat -- "$SITE_BODY"
		printf '\t\t}\n\t}\n}\n'
	} >> "$TMP_CADDY"

	rm -f -- "$SITE_META" "$SITE_ACCESS" "$SITE_CORS" "$SITE_AUTH" "$SITE_BODY"
	TMP_SITE=""
	OPT_BROWSE=$_saved_browse
}

# ---------------------------------------------------------------------------
# Argument Parsing
# ---------------------------------------------------------------------------
if [ "$#" -eq 0 ]; then
	show_help
	exit 0
fi

case ${1:-} in
	--help) show_help; exit 0 ;;
	--version) printf '%s\n' "$VERSION"; exit 0 ;;
esac

OPT_PRESET=""
OPT_ADDR=""
OPT_BIND=""
OPT_ROOT=""
OPT_UPSTREAM=""
OPT_MEDIA_TYPE=""
OPT_MEDIA_SORT=date
OPT_MEDIA_ORDER=desc
OPT_MEDIA_DEPTH=0
OPT_BROWSE=""
OPT_ENCODE=""
OPT_SEC_HEADERS=""
OPT_NONINTERACTIVE=0
OPT_SITE_FRAGMENT=""
OPT_GLOBAL_FRAGMENT=""
OPT_JSON=""
OPT_PROTOCOLS=""
OPT_TLS="auto"
OPT_EMAIL=""
OPT_ADMIN=""
OPT_HASH_FILE=""
OPT_AUTH_USER=""
OPT_LOG=""
OPT_ALLOW=""
OPT_DENY=""
OPT_CORS=""
OPT_INDEX=""
OPT_HIDE=".git .env *.bak .DS_Store"
SET_HIDE=0
OPT_PRECOMP=""
OPT_VALIDATE="auto"
OPT_MODULES=0
OPT_QUIET=0

while getopts ":p:a:b:r:u:t:s:o:d:BESnhc:g:J:P:T:e:A:H:U:L:k:D:C:i:w:z:vVmq" opt; do
	case $opt in
		p) OPT_PRESET=$OPTARG ;;
		a) OPT_ADDR=$OPTARG ;;
		b) OPT_BIND=$OPTARG ;;
		r) OPT_ROOT=$OPTARG ;;
		u) OPT_UPSTREAM=$OPTARG ;;
		t) OPT_MEDIA_TYPE=$OPTARG ;;
		s) OPT_MEDIA_SORT=$OPTARG ;;
		o) OPT_MEDIA_ORDER=$OPTARG ;;
		d) OPT_MEDIA_DEPTH=$OPTARG ;;
		B) OPT_BROWSE="yes" ;;
		E) OPT_ENCODE="yes" ;;
		S) OPT_SEC_HEADERS="yes" ;;
		n) OPT_NONINTERACTIVE=1 ;;
		c) OPT_SITE_FRAGMENT=$(absolute_file "$OPTARG") ;;
		g) OPT_GLOBAL_FRAGMENT=$(absolute_file "$OPTARG") ;;
		J) OPT_JSON=$(absolute_file "$OPTARG") ;;
		P) OPT_PROTOCOLS=$OPTARG ;;
		T) OPT_TLS=$OPTARG ;;
		e) OPT_EMAIL=$OPTARG ;;
		A) OPT_ADMIN=$OPTARG ;;
		H) OPT_HASH_FILE=$(absolute_file "$OPTARG") ;;
		U) OPT_AUTH_USER=$OPTARG ;;
		L) OPT_LOG=$OPTARG ;;
		k) OPT_ALLOW=$OPTARG ;;
		D) OPT_DENY=$OPTARG ;;
		C) OPT_CORS=$OPTARG ;;
		i) OPT_INDEX=$OPTARG ;;
		w) OPT_HIDE=$OPTARG; SET_HIDE=1 ;;
		z) OPT_PRECOMP=$OPTARG ;;
		v) OPT_VALIDATE="required" ;;
		V) OPT_VALIDATE="skip" ;;
		m) OPT_MODULES=1 ;;
		q) OPT_QUIET=1 ;;
		h) show_help; exit 0 ;;
		:) die "Option -$OPTARG requires an argument" ;;
		\?) die "Invalid option: -$OPTARG" ;;
	esac
done
shift $((OPTIND - 1))

if [ "$OPT_MODULES" -eq 1 ]; then
	have_cmd "$CADDY_BIN" || die "Caddy unavailable: $CADDY_BIN"
	"$CADDY_BIN" list-modules
	exit
fi
case $OPT_PRESET in
	''|file-browser|m3u-streamer|reverse-proxy|spa-api|php-webapp|secure-gateway|multi-service|redirect-canon|custom) ;;
	*) die "Unknown preset '$OPT_PRESET'. Run '${0##*/}' with no args for help." ;;
esac
case $OPT_MEDIA_SORT in
	date|time|mtime|d) OPT_MEDIA_SORT=date ;;
	size|bytes|s) OPT_MEDIA_SORT=size ;;
	name|alpha|n) OPT_MEDIA_SORT=name ;;
	shuffle|random|rand|shuf|r) OPT_MEDIA_SORT=shuffle ;;
	*) die "Invalid media sort field: $OPT_MEDIA_SORT" ;;
esac
case $OPT_MEDIA_ORDER in
	asc|ascending|a) OPT_MEDIA_ORDER=asc ;;
	desc|descending|r) OPT_MEDIA_ORDER=desc ;;
	*) die "Invalid media sort order: $OPT_MEDIA_ORDER" ;;
esac
case $OPT_MEDIA_DEPTH in ''|*[!0-9]*) die "Media depth must be 0..255 (0=unlimited)" ;; esac
OPT_MEDIA_DEPTH=$(printf '%s' "$OPT_MEDIA_DEPTH" | sed 's/^0*//')
OPT_MEDIA_DEPTH=${OPT_MEDIA_DEPTH:-0}
[ "${#OPT_MEDIA_DEPTH}" -le 3 ] && [ "$OPT_MEDIA_DEPTH" -le 255 ] || die "Media depth must be 0..255 (0=unlimited)"
case $OPT_MEDIA_TYPE in ''|both|videos|images) ;; *) die "Invalid media filter: $OPT_MEDIA_TYPE" ;; esac
case $OPT_TLS in auto|internal) ;; *) die "Invalid TLS mode: $OPT_TLS" ;; esac
case $OPT_LOG in ''|stdout|stderr|/*) ;; *) die "Log destination must be stdout, stderr, or an absolute path" ;; esac
[ -z "$OPT_ALLOW" ] || [ -z "$OPT_DENY" ] || die "Use either -k allow or -D deny"
if [ -n "$OPT_ROOT" ]; then
	OPT_ROOT=$(absolute_path "$OPT_ROOT")
fi
[ -z "$OPT_EMAIL" ] || require_literal "ACME email" "$OPT_EMAIL"
[ -z "$OPT_ADMIN" ] || require_literal "Admin address" "$OPT_ADMIN"
[ -z "$OPT_CORS" ] || require_literal "CORS origin" "$OPT_CORS"
[ -z "$OPT_AUTH_USER" ] || require_literal "Auth username" "$OPT_AUTH_USER"
[ -z "$OPT_LOG" ] || require_literal "Log destination" "$OPT_LOG"
[ -z "$OPT_ALLOW" ] || require_tokens "Allowed ranges" "$OPT_ALLOW"
[ -z "$OPT_DENY" ] || require_tokens "Denied ranges" "$OPT_DENY"
[ -z "$OPT_ADDR" ] || require_tokens "Site address" "$OPT_ADDR"
[ -z "$OPT_BIND" ] || require_tokens "Bind addresses" "$OPT_BIND"
[ -z "$OPT_UPSTREAM" ] || require_tokens "Upstream addresses" "$OPT_UPSTREAM"
[ -z "$OPT_INDEX" ] || require_tokens "Index names" "$OPT_INDEX"
[ -z "$OPT_HIDE" ] || require_tokens "Hide patterns" "$OPT_HIDE"
for _protocol in $OPT_PROTOCOLS; do
	case $_protocol in h1|h2|h2c|h3) ;; *) die "Invalid HTTP protocol: $_protocol" ;; esac
done
for _sidecar in $OPT_PRECOMP; do
	case $_sidecar in zstd|br|gzip) ;; *) die "Invalid precompressed format: $_sidecar" ;; esac
done
if [ -n "$OPT_JSON" ]; then
	[ -z "$OPT_PRESET$OPT_ADDR$OPT_BIND$OPT_ROOT$OPT_UPSTREAM$OPT_MEDIA_TYPE$OPT_BROWSE$OPT_ENCODE$OPT_SEC_HEADERS$OPT_SITE_FRAGMENT$OPT_GLOBAL_FRAGMENT$OPT_PROTOCOLS$OPT_EMAIL$OPT_ADMIN$OPT_HASH_FILE$OPT_AUTH_USER$OPT_LOG$OPT_ALLOW$OPT_DENY$OPT_CORS$OPT_INDEX$OPT_PRECOMP" ] &&
		[ "$OPT_MEDIA_SORT:$OPT_MEDIA_ORDER:$OPT_MEDIA_DEPTH" = "date:desc:0" ] && [ "$OPT_TLS" = "auto" ] && [ "$SET_HIDE" -eq 0 ] && [ "$OPT_HIDE" = ".git .env *.bak .DS_Store" ] || die "-J cannot be combined with generation options"
fi

[ "$#" -ge 1 ] || {
	show_help
	exit 1
}
[ "$#" -le 1 ] || die "Expected a single <target_dir_or_file> argument, got $#."

TARGET_RAW=$1
TARGET_ARG=$1
require_literal "Target" "$TARGET_ARG"
case $TARGET_ARG in /*) ;; *) TARGET_ARG=$PWD/$TARGET_ARG ;; esac
require_literal "Absolute target" "$TARGET_ARG"
if [ -d "$TARGET_ARG" ]; then
	TARGET_DIR=$(cd -- "$TARGET_ARG" && pwd)
	TARGET_BASE="${TARGET_DIR}/Caddyfile"
else
	case $TARGET_RAW in */) die "${0##*/}: $TARGET_RAW: directory does not exist" ;; esac
	if [ -e "$TARGET_ARG" ] || [ -L "$TARGET_ARG" ]; then
		[ -f "$TARGET_ARG" ] || die "Target must be a directory or a regular file: $TARGET_RAW"
	fi
	_parent=$(dirname -- "$TARGET_ARG")
	[ -d "$_parent" ] || die "${0##*/}: $_parent: parent directory does not exist"
	TARGET_DIR=$(cd -- "$_parent" && pwd)
	_base_name=$(basename -- "$TARGET_ARG")
	TARGET_BASE="${TARGET_DIR}/${_base_name}"
fi
require_literal "Resolved target base" "$TARGET_BASE"

# ---------------------------------------------------------------------------
# Main Interactive / Preset Dispatch
# ---------------------------------------------------------------------------
WORK_DIR=$(mktemp -d "$TARGET_DIR/.mkcaddy.XXXXXX") || die "Cannot create staging directory in $TARGET_DIR"
TMP_CADDY=$WORK_DIR/config
: > "$TMP_CADDY"
if [ -n "$OPT_JSON" ]; then
	cat -- "$OPT_JSON" >> "$TMP_CADDY" || die "Cannot read native JSON"
	validate_config
	OUT_FILE=$(commit_file "$TMP_CADDY" "$TARGET_BASE" "")
	printf '%s\n' "$OUT_FILE"
	exit 0
fi
# With no terminal, all modules take the documented noninteractive defaults.
if [ ! -t 0 ] || [ ! -t 2 ]; then
	OPT_NONINTERACTIVE=1
fi

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

# Explicit global flags bypass prompts; native global fragments cover all options.
if [ -n "$OPT_PROTOCOLS$OPT_EMAIL$OPT_ADMIN$OPT_GLOBAL_FRAGMENT" ]; then
	_q_opt_email=""
	_q_opt_admin=""
	_q_opt_gfrag=""
	[ -z "$OPT_EMAIL" ] || _q_opt_email=$(caddy_quote "$OPT_EMAIL")
	[ -z "$OPT_ADMIN" ] || _q_opt_admin=$(caddy_quote "$OPT_ADMIN")
	[ -z "$OPT_GLOBAL_FRAGMENT" ] || _q_opt_gfrag=$(caddy_quote "$OPT_GLOBAL_FRAGMENT")
	{
		printf '{\n'
		[ -z "$OPT_PROTOCOLS" ] || printf '\tservers {\n\t\tprotocols %s\n\t}\n' "$OPT_PROTOCOLS"
		[ -z "$_q_opt_email" ] || printf '\temail %s\n' "$_q_opt_email"
		[ -z "$_q_opt_admin" ] || printf '\tadmin %s\n' "$_q_opt_admin"
		[ -z "$_q_opt_gfrag" ] || printf '\timport %s\n' "$_q_opt_gfrag"
		printf '}\n\n'
	} >> "$TMP_CADDY"
# Optional Global Options Block in Interactive Mode
elif [ "$OPT_NONINTERACTIVE" -eq 0 ] && [ -t 0 ] && [ -t 2 ]; then
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
			"multi-service  - Path-Routed Services" \
			"secure-gateway - Authenticated Gateway" \
			"redirect-canon - Redirect / Canonicalization" \
			"custom         - Composable Module Builder")
		build_site_block "${_next_psel%% *}"
	done
fi

validate_config
OUT_FILE=$(commit_file "$TMP_CADDY" "$TARGET_BASE" "")
printf '%s\n' "$OUT_FILE"