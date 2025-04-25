#!/usr/bin/env bash
# Version: 2.0.0
# Built: 2025-04-25
# Author: 4ndr0666
set -euo pipefail

# ========== Configuration ==========
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

# ========== Styled Visual Feedback ==========
GLOW() { printf '%s\n' "$(tput setaf 6)[✔️] $*$(tput sgr0)"; }
BUG() { printf '%s\n' "$(tput setaf 1)[❌] $*$(tput sgr0)"; }

# ============= Helpers ==================
# Color-coding follows the installer theme:
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
dbg() { :; } # placeholder until set in main()
section() {
	echo
	echo " $1:"
	echo ""
}

# ========== Path Alignment Validation ==========
verify_path_alignment() {
	section "Verifying Environment Path Alignment"
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
		pass "Environment paths aligned"
	else
		warn "Environment paths invalid. Run \`$RECONFIGURE\`?"
		read -rp "Run configure now? [y/N]: " choice
		[[ "${choice,,}" == "y" ]] && exec "$RECONFIGURE"
		return 1
	fi
}

# ========== Test Modules ==========

test_files_exist() {
	section "Testing Required Files Exist"
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

test_shebangs() {
	section "Testing Shebang Headers"
	for file in "${FILES[@]}"; do
		[[ $file == *.desktop ]] && {
			dbg "Skipped shebang check (not a script): $file"
			continue
		}
		head=$(head -n1 "$file" || true)
		[[ "$head" == "#!"* ]] || fail "Missing/invalid shebang in $file"
		dbg "Shebang OK: $file"
	done
	pass "All shebangs validated"
}

test_version_tags() {
	section "Testing Version Tags"
	for file in "${FILES[@]}"; do
		[[ $file == *.desktop ]] && {
			dbg "Skipped version tag check (not a script): $file"
			continue
		}
		grep -qE "^# Version: 1\.0\.0" "$file" || fail "Missing version tag: $file"
	done
	pass "Version tags are consistent"
}

test_file_immutability() {
	section "Testing Immutability"
	for file in "${FILES[@]}"; do
		if lsattr "$file" 2>/dev/null | grep -q '\-i\-' >/dev/null 2>&1; then
			dbg "Immutable: $file"
		else
			warn "$file not immutable"
			((REPAIR)) && sudo chattr +i "$file" && log "Locked: $file"
		fi
	done
	pass "File immutability verified"

}

test_cookie_store() {
	section "Validating Cookie Store"
	[[ -d $COOKIE_DIR ]] || fail "Missing cookie dir: $COOKIE_DIR"
	local count
	count=$(find "$COOKIE_DIR" -type f | wc -l)
	((count >= 9)) || fail "Expected >=9 cookies, found $count"
	pass "Cookie store is initialized"
}

test_desktop_mime() {
	section "Testing xdg-mime Handler"
	local handler
	handler=$(xdg-mime query default x-scheme-handler/ytdl || true)
	[[ "$handler" == "ytdl.desktop" ]] || fail "xdg-mime handler not registered"
	pass "xdg-mime handler registered"
}

# ========== Help Section ==========
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

# ========== Main Entry ==========
main() {
	case "${1:-}" in
	-h | --help) show_help ;;
	-d | --debug) DEBUG=1 ;;
	-r | --repair) REPAIR=1 ;;
	--preinstall)
		REPAIR=1
		DEBUG=0
		QUIET=1
		;; # Run as part of install.sh to verify and repair before proceeding
	*) ;;
	esac

	if [[ "$DEBUG" -eq 1 ]]; then
		dbg() { printf '%s\n' "$(ts) [DEBUG] $*"; }
	else
		dbg() { :; }
	fi

	log "Running YTDLC Integrity Test Suite..."
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
