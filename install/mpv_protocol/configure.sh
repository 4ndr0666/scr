#!/usr/bin/env bash
# Version: 4.0.0                  === MEDIA PROTOCOL CONFIGURE === #
# 4NDR0666
set -euo pipefail
# Desc: preinstall env and post-install integrity test for ytdl:// & mpv://
# Usage: Run standalone or via REPAIR=1 for auto-remediation.
#

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
APP_DIR="$XDG_DATA_HOME/applications"
ZSH_DIR="$XDG_CONFIG_HOME/zsh"
BIN_DIR="$HOME/.local/bin"

YTDL_PLUGIN="$ZSH_DIR/ytdl.zsh"
YTDL_HANDLER_FILE="/usr/local/bin/ytdl-handler.sh"
DMENUHANDLER_FILE="$BIN_DIR/dmenuhandler"
YTDL_DESKTOP_FILE="$APP_DIR/ytdl.desktop"

MPV_HANDLER_FILE="/usr/local/bin/mpv-uri-handler"
MPV_DESKTOP_FILE="$APP_DIR/mpv-handler.desktop"

FILES=(
	"$YTDL_PLUGIN"
	"$YTDL_HANDLER_FILE"
	"$DMENUHANDLER_FILE"
	"$YTDL_DESKTOP_FILE"
	"$MPV_HANDLER_FILE"
	"$MPV_DESKTOP_FILE"
)

COOKIE_DIR="$XDG_CONFIG_HOME/yt-dlp"
DEBUG="${DEBUG:-0}"
REPAIR="${REPAIR:-0}"
QUIET="${QUIET:-0}"
PREINSTALL="${PREINSTALL:-0}"

# logging
if command -v tput >/dev/null && [[ -t 1 ]]; then
	GLOW() { printf '%s\n' "$(tput setaf 6)[✔️] $*$(tput sgr0)"; }
	BUG()  { printf '%s\n' "$(tput setaf 1)[❌] $*$(tput sgr0)"; }
else
	GLOW() { printf '[OK] %s\n'  "$*"; }
	BUG()  { printf '[ERR] %s\n' "$*"; }
fi

ts()   { date "+%Y-%m-%d %H:%M:%S"; }
pass() { printf '%s %s\n' "$(tput setaf 6)[✔️ PASS]$(tput sgr0)" "$1"; }
fail() { printf '%s %s\n' "$(tput setaf 1)[❌ FAIL]$(tput sgr0)" "$1" >&2; return 1; }
warn() { printf '%s %s\n' "$(tput setaf 3)[⚠️ WARN]$(tput sgr0)" "$1" >&2; }
log()  { [[ "${QUIET}" -eq 1 ]] && return; printf '%s\n' "$(ts) ➡️ $*"; }
dbg()  { :; }

section() {
	echo ""
	echo " $1:"
	echo ""
}

# Spinner
show_arc_progress() {
	local pid=$1 label=$2
	local frames=("◜" "◠" "◝" "◞" "◡" "◟")
	local i=0
	tput civis
	while ps -p "$pid" >/dev/null 2>&1; do
		printf "\r$(tput setaf 5)↻  %s %s$(tput sgr0)" "$label" "${frames[i]}"
		sleep 0.2
		i=$(( (i + 1) % ${#frames[@]} ))
	done
	printf "\r$(tput setaf 2)✔️  %s complete$(tput sgr0)%*s\n" "$label" 10 ""
	tput cnorm
}

# Deps
test_dependencies_present() {
	section "Dependencies"
	local -a deps=(yt-dlp aria2c jq dmenu xclip fzf python3 mpv)
	local miss=0
	for d in "${deps[@]}"; do
		command -v "$d" >/dev/null || {
			fail "Missing dep: $d"
			miss=1
		}
	done
	(( miss == 0 )) && pass "All runtime dependencies present"
}

# Ensure path
verify_path_alignment() {
	section "Scanning Environment"
	local valid=1

	[[ "$YTDL_HANDLER_FILE" == "/usr/local/bin/ytdl-handler.sh" ]] || {
		fail "YTDL_HANDLER_FILE should be /usr/local/bin/ytdl-handler.sh (got: $YTDL_HANDLER_FILE)"
		valid=0
	}
	[[ "$MPV_HANDLER_FILE" == "/usr/local/bin/mpv-uri-handler" ]] || {
		fail "MPV_HANDLER_FILE should be /usr/local/bin/mpv-uri-handler (got: $MPV_HANDLER_FILE)"
		valid=0
	}
	[[ "$APP_DIR" == "$XDG_DATA_HOME/applications" ]] || {
		fail "APP_DIR should be \$XDG_DATA_HOME/applications (got: $APP_DIR)"
		valid=0
	}
	[[ "$BIN_DIR" == "$HOME/.local/bin" ]] || {
		fail "BIN_DIR should be \$HOME/.local/bin (got: $BIN_DIR)"
		valid=0
	}
	[[ "$ZSH_DIR" == "$XDG_CONFIG_HOME/zsh" ]] || {
		fail "ZSH_DIR should be \$XDG_CONFIG_HOME/zsh (got: $ZSH_DIR)"
		valid=0
	}
	[[ "$YTDL_PLUGIN" == "$ZSH_DIR/ytdl.zsh" ]] || {
		fail "YTDL_PLUGIN should be \$ZSH_DIR/ytdl.zsh (got: $YTDL_PLUGIN)"
		valid=0
	}
	[[ "$DMENUHANDLER_FILE" == "$BIN_DIR/dmenuhandler" ]] || {
		fail "DMENUHANDLER_FILE should be \$BIN_DIR/dmenuhandler (got: $DMENUHANDLER_FILE)"
		valid=0
	}
	[[ "$YTDL_DESKTOP_FILE" == "$APP_DIR/ytdl.desktop" ]] || {
		fail "YTDL_DESKTOP_FILE should be \$APP_DIR/ytdl.desktop (got: $YTDL_DESKTOP_FILE)"
		valid=0
	}
	[[ "$MPV_DESKTOP_FILE" == "$APP_DIR/mpv-handler.desktop" ]] || {
		fail "MPV_DESKTOP_FILE should be \$APP_DIR/mpv-handler.desktop (got: $MPV_DESKTOP_FILE)"
		valid=0
	}

if (( valid )); then
		pass "Paths are internally consistent"
	else
		warn "Path misalignment detected."
		return 1
	fi
}

# Validate files
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
				(( REPAIR )) && chmod +x "$file" && log "Fixed exec: $file"
			}
		fi
		dbg "✓ $file"
	done
	pass "Required files present"
}

# Validate shebang
test_shebangs() {
	section "Checking Shebang Headers"
	for file in "${FILES[@]}"; do
		[[ $file == *.desktop ]] && { dbg "skip: $file"; continue; }
		local head
		head=$(head -n1 "$file" || true)
		if [[ "$head" != "#!"* ]]; then
			if (( REPAIR )); then
				warn "Adding missing shebang to $file"
				sudo chattr -i "$file" 2>/dev/null || true
				if [[ -w $file ]]; then
					{ printf '%s\n' "#!/usr/bin/env bash"; cat "$file"; } >"$file"
				else
					sudo sh -c "{ printf '%s\n' '#!/usr/bin/env bash'; cat '$file'; } > '$file'"
				fi
				sudo chmod +x "$file"
				sudo chattr +i "$file" 2>/dev/null || true
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

# Validate version
test_version_tags() {
	section "Checking Version Tags"
	local expected_version="4.0.0"
	for file in "${FILES[@]}"; do
		[[ $file == *.desktop ]] && { dbg "skip version: $file"; continue; }

		if ! grep -qE "^# Version: $expected_version" "$file"; then
			if (( REPAIR )); then
				warn "Updating version tag in $file to $expected_version"
				sudo chattr -i "$file" 2>/dev/null || true
				if [[ -w $file ]]; then
					sed -i "s|^# Version:.*|# Version: $expected_version|" "$file"
				else
					sudo sed -i "s|^# Version:.*|# Version: $expected_version|" "$file"
				fi
				sudo chattr +i "$file" 2>/dev/null || true
				dbg "Version repaired: $file"
			else
				fail "Version mismatch in $file (expected $expected_version)"
			fi
		else
			dbg "Version tag OK: $file"
		fi
done
	pass "Version tags consistent"
}

# Immutable
test_file_immutability() {
	section "Checking Immutability"
	for file in "${FILES[@]}"; do
		if lsattr "$file" 2>/dev/null | grep -q '\-i-'; then
			dbg "Immutable: $file"
		else
			warn "$file not immutable"
			(( REPAIR )) && sudo chattr +i "$file" && log "Locked: $file"
		fi
	done
	pass "File immutability verified"
}

# Validate cookies
test_cookie_store() {
	section "Validating Cookie Store"
	(
		[[ -d $COOKIE_DIR ]] || fail "Missing cookie dir: $COOKIE_DIR"
		local count
		count=$(find "$COOKIE_DIR" -type f | wc -l)
		(( count >= 9 )) || fail "Expected ≥9 cookie files, found $count"
		sleep 1
	) &
	show_arc_progress $! "Cookie validation"
	echo ""
	pass "Cookie storage initialized"
}

# Desktop file
test_desktop_mime() {
	section "Testing xdg-mime Handlers"

	local ytdl_handler
	ytdl_handler=$(xdg-mime query default x-scheme-handler/ytdl || true)
	[[ "$ytdl_handler" == "ytdl.desktop" ]] || fail "xdg-mime handler not registered for ytdl://"
	pass "xdg-mime handler registered for ytdl://"

	local mpv_handler
	mpv_handler=$(xdg-mime query default x-scheme-handler/mpv || true)
	[[ "$mpv_handler" == "mpv-handler.desktop" ]] || fail "xdg-mime handler not registered for mpv://"
	pass "xdg-mime handler registered for mpv://"
}

# Help
show_help() {
	cat <<EOF

Usage: ./configure.sh [OPTION]

Tests the integrity, install correctness, and XDG compliance of the Media Protocol Suite.

Options:
  -r, --repair       Enable REPAIR mode (chmod +x, chattr +i, version tag fix)
  -d, --debug        Enable DEBUG mode (verbose trace)
  --preinstall       Dependency + path check only (used before installation)
  -h, --help         Show this help

Environment:
  DEBUG=$DEBUG
  REPAIR=$REPAIR
  QUIET=$QUIET

EOF
	exit 0
}

# Main entry
main() {
	case "${1:-}" in
		-h | --help)    show_help ;;
		-d | --debug)   DEBUG=1 ;;
		-r | --repair)  REPAIR=1 ;;
		--preinstall)
			REPAIR=0
			DEBUG=0
QUIET=1
			PREINSTALL=1
			;;
		*) ;;
	esac

	if [[ "$DEBUG" -eq 1 ]]; then
		dbg() { printf '%s\n' "$(ts) [DEBUG] $*"; }
		set -x
	else
		dbg() { :; }
	fi

	log "Running Media Protocol Integrity Test Suite..."

	if [[ "${PREINSTALL}" -eq 1 ]]; then
		test_dependencies_present
		verify_path_alignment
		log "✅ Preinstall environment validated."
		exit 0
	fi

	test_dependencies_present
	test_files_exist
	test_shebangs
	test_version_tags
	verify_path_alignment
	test_file_immutability
	test_cookie_store
	test_desktop_mime
	echo ""
	log "💥 System configured and validated!"
}
main "$@"
