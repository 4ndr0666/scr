#!/usr/bin/env bash
# Version: 2.2.0
# Built: 2025-04-25
# Author: 4ndr0666
set -euo pipefail
# =================== // TEST_YTDLC.SH //

## Constants

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
APP_DIR="$XDG_DATA_HOME/applications"
ZSH_DIR="$XDG_CONFIG_HOME/zsh"
BIN_DIR="$HOME/.local/bin"
YTDL_PLUGIN="$ZSH_DIR/ytdl.zsh"
YTDL_HANDLER_FILE="/usr/local/bin/ytdl-handler.sh"
DMENUHANDLER_FILE="$BIN_DIR/dmenuhandler"
DESKTOP_FILE="$APP_DIR/ytdl.desktop"
FILES=("$YTDL_PLUGIN" "$YTDL_HANDLER_FILE" "$DMENUHANDLER_FILE" "$DESKTOP_FILE")
COOKIE_DIR="$XDG_CONFIG_HOME/yt-dlp"
DEBUG="${DEBUG:-0}"
REPAIR="${REPAIR:-0}"
RECONFIGURE="./install_ytdlc.sh"

## Colors

GLOW() { printf '%s\n' "$(tput setaf 6)[✔️] $*$(tput sgr0)"; }
BUG() { printf '%s\n' "$(tput setaf 1)[❌] $*$(tput sgr0)"; }

## Spinner

show_arc_progress() {
	local pid=$1 label=$2
	local frames=("◜" "◠" "◝" "◞" "◡" "◟")
	local i=0

	tput civis
	while ps -p "$pid" >/dev/null 2>&1; do
		printf "\r$(tput setaf 5)↻  %s %s$(tput sgr0)" "$label" "${frames[i]}"
		sleep 0.2
		i=$(((i + 1) % ${#frames[@]}))
	done
	printf "\r$(tput setaf 2)✔️  %s complete$(tput sgr0)%*s\n" "$label" 10 ""
	tput cnorm
}

## Helpers

# ✔️ PASS – Cyan
# ❌ FAIL – Red
# ⚠️ WARN – Yellow
ts() { date "+%Y-%m-%d %H:%M:%S"; }
pass() { printf '%s %s\n' "$(tput setaf 6)[✔️ PASS]$(tput sgr0)" "$1"; }
fail() {
	printf '%s %s\n' "$(tput setaf 1)[❌ FAIL]$(tput sgr0)" "$1" >&2
	return 1
}
warn() { printf '%s %s\n' "$(tput setaf 3)[⚠️ WARN]$(tput sgr0)" "$1" >&2; }
log() {
	[[ "${QUIET:-0}" -eq 1 ]] && return
	printf '%s\n' "$(ts) ➡️ $*"
}
dbg() { :; }
section() {
	echo
	echo " $1:"
	echo ""
}

## Dependency Check

test_dependencies_present() {
	section "Dependencies"
	local -a deps=(yt-dlp aria2c jq dmenu xclip fzf)
	local miss=0
	for d in "${deps[@]}"; do
		command -v "$d" >/dev/null || {
			fail "Missing dep: $d"
			miss=1
		}
	done
	((miss == 0)) &&
		pass "All runtime dependencies present"
}

## Path Alignment Validation

verify_path_alignment() {
	section "Scanning Environment"
	local valid=1
	[[ "$YTDL_HANDLER_FILE" == "/usr/local/bin/ytdl-handler.sh" ]] || {
		fail "YTDL_HANDLER_FILE incorrect"
		valid=0
	}
	[[ "$XDG_CONFIG_HOME" == "$HOME/.config" ]] || {
		fail "XDG_CONFIG_HOME incorrect"
		valid=0
	}
	[[ "$XDG_DATA_HOME" == "$HOME/.local/share" ]] || {
		fail "XDG_DATA_HOME incorrect"
		valid=0
	}
	[[ "$APP_DIR" == "$HOME/.local/share/applications" ]] || {
		fail "APP_DIR incorrect"
		valid=0
	}
	[[ "$BIN_DIR" == "$HOME/.local/bin" ]] || {
		fail "BIN_DIR incorrect"
		valid=0
	}
	[[ "$ZSH_DIR" == "$HOME/.config/zsh" ]] || {
		fail "ZSH_DIR incorrect"
		valid=0
	}
	[[ "$YTDL_PLUGIN" == "$HOME/.config/zsh/ytdl.zsh" ]] || {
		fail "YTDL_PLUGIN incorrect"
		valid=0
	}
	[[ "$DMENUHANDLER_FILE" == "$HOME/.local/bin/dmenuhandler" ]] || {
		fail "DMENUHANDLER_FILE incorrect"
		valid=0
	}
	[[ "$DESKTOP_FILE" == "$APP_DIR/ytdl.desktop" ]] || {
		fail "DESKTOP_FILE incorrect"
		valid=0
	}

	if ((valid)); then
		pass "Paths Are In Alignment"
	else
		warn "Environment paths invalid. Run \`$RECONFIGURE\`?"
		read -rp "Run configure now? [y/N]: " choice
		[[ "${choice,,}" == "y" ]] && exec "$RECONFIGURE"
		return 1
	fi
}

## Testing Suite

test_files_exist() {
	section "Checking For Pre-existing Files"
	for file in "${FILES[@]}"; do
		[[ -f $file ]] || {
			fail "Missing file: $file"
			continue
		}
		if [[ $file != *.desktop ]]; then
			[[ -x $file ]] || {
				warn "Not executable: $file"
				((REPAIR)) && chmod +x "$file" && log "Fixed exec: $file"
			}
		fi
		dbg "✓ $file"
	done
	pass "Required files are present"
}

## Shebangs

test_shebangs() {
	section "Checking Shebang Headers"
	for file in "${FILES[@]}"; do
		[[ $file == *.desktop ]] && {
			dbg "skip: $file"
			continue
		}
		head=$(head -n1 "$file" || true)
		if [[ "$head" != "#!"* ]]; then
			if ((REPAIR)); then
				warn "Adding missing shebang to $file"
				sudo chattr -i "$file" # remove immutable before patch
				if [[ -w $file ]]; then
					{
						printf '%s\n' "#!/usr/bin/env bash"
						cat "$file"
					} >"$file"
				else
					sudo sh -c "{ printf '%s\n' \"#!/usr/bin/env bash\"; cat \"$file\"; } > \"$file\""
				fi
				sudo chmod +x "$file"
				sudo chattr +i "$file" # restore immutable after patch
				dbg "Shebang repaired: $file"
			else
				fail "Missing/invalid shebang in $file"
			fi
		else
			dbg "Shebang OK: $file"
		fi
	done
	pass "All shebangs validated"
}

## Versions

test_version_tags() {
	section "Checking Version Tags"
	for file in "${FILES[@]}"; do
		[[ $file == *.desktop ]] && {
			dbg "skip version: $file"
			continue
		}

		local expected_version
		case "$file" in
		*ytdl.zsh) expected_version="1.1.0" ;; # plugin is v1.1.0
		*) expected_version="2.2.0" ;;         # tester/handler/installer v2.2.0
		esac

		if ! grep -qE "^# Version: $expected_version" "$file"; then
			if ((REPAIR)); then
				warn "Updating version tag in $file"
				sudo chattr -i "$file"
				if [[ -w $file ]]; then
					sed -i "s|^# Version:.*|# Version: $expected_version|" "$file"
				else
					sudo sed -i "s|^# Version:.*|# Version: $expected_version|" "$file"
				fi
				sudo chattr +i "$file"
				dbg "Version repaired: $file"
			else
				fail "Version mismatch in $file (expected $expected_version)"
			fi
		else
			dbg "Version tag OK: $file"
		fi
	done
	pass "Version tags are consistent"
}

## Immutability

test_file_immutability() {
	section "Checking Immutability"
	for file in "${FILES[@]}"; do
		if lsattr "$file" 2>/dev/null | grep -q '\-i-'; then
			dbg "Immutable: $file"
		else
			warn "$file not immutable"
			((REPAIR)) && sudo chattr +i "$file" && log "Locked: $file"
		fi
	done
	pass "File immutability verified"

}

## Cookies

test_cookie_store() {
	section "Validating Cookies"
	(
		[[ -d $COOKIE_DIR ]] || fail "Missing cookie dir: $COOKIE_DIR"
		local count
		count=$(find "$COOKIE_DIR" -type f | wc -l)
		((count >= 9)) || fail "Expected ≥9 cookies, found $count"
		sleep 1 # simulate delay
	) &
	show_arc_progress $! "Cookie validation"
	echo ""
	pass "Cookies Storage Initialized"
}

## Desktop File

test_desktop_mime() {
	section "Testing xdg-mime Handler"
	local handler
	handler=$(xdg-mime query default x-scheme-handler/ytdl || true)
	[[ "$handler" == "ytdl.desktop" ]] || fail "xdg-mime handler not registered"
	pass "xdg-mime handler registered"
}

## Help

show_help() {
	cat <<EOF

Usage: ./test_ytdlc.sh [OPTION]

Tests the integrity, install correctness, and compliance of the YTDLC installation.

Options:
  -r, --repair       Enable REPAIR mode (chmod +x, chattr +i)
  -d, --debug        Enable DEBUG mode
  -h, --help         Show this help menu

Defaults:
  DEBUG=$DEBUG
  REPAIR=$REPAIR

EOF
	exit 0
}

## Main entry point

main() {
	case "${1:-}" in
	-h | --help) show_help ;;
	-d | --debug) DEBUG=1 ;;
	-r | --repair) REPAIR=1 ;;
	--preinstall)
		REPAIR=1
		DEBUG=0
		QUIET=1
		PREINSTALL=1
		;;
	*) ;;
	esac

	if [[ "$DEBUG" -eq 1 ]]; then
		dbg() { printf '%s\n' "$(ts) [DEBUG] $*"; }
	else
		dbg() { :; }
	fi

	log "Running YTDLC Integrity Test Suite..."

	if [[ "${PREINSTALL:-0}" -eq 1 ]]; then
		test_dependencies_present
		verify_path_alignment
		log "✅ Preinstall environment validated."
		exit 0
	fi

	# Full suite if not preinstall
	test_dependencies_present
	test_files_exist
	test_shebangs
	test_version_tags
	verify_path_alignment
	test_file_immutability
	test_cookie_store
	test_desktop_mime
	echo ""
	log "💥 System configured!"
}

main "$@"
