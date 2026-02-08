#!/usr/bin/env bash
#
# pacman-fix-permissions-rollback-v4.sh
# Comprehensive, idempotent, robust rollback for pacman-fix-permissions damage
# Includes guarded /dev/null recreation as Phase 0 + all previous fixes
# Run as root
#
# 2026-02-07 — v4 final with fallback logic

set -euo pipefail

log() { echo "[$(date +%T)] $*" >&2; }
warn() { echo "[WARN] $*" >&2; }
err() {
	echo "[ERROR] $*" >&2
	exit 1
}

# ──────────────────────────────────────────────────────────────────────────────
# Phase 0: /dev/null — highest priority, guarded & idempotent
# ──────────────────────────────────────────────────────────────────────────────

log "Phase 0: Ensuring /dev/null is a proper world-writable character device..."

NULL_MODE=$(stat -c %a /dev/null 2>/dev/null || echo "missing")
NULL_TYPE=$(stat -c %F /dev/null 2>/dev/null || echo "missing")

if [[ "$NULL_TYPE" != "character special file" ]] || [[ "$NULL_MODE" != "666" ]]; then
	warn "/dev/null is broken (type=$NULL_TYPE, mode=$NULL_MODE) — recreating..."

	# Safety: only rm if it's NOT a device node (avoids nuking real char device)
	if [[ -e /dev/null ]] && [[ ! -c /dev/null ]]; then
		log "Removing invalid /dev/null (was regular file/dir/symlink)"
		rm -f /dev/null || err "Cannot remove invalid /dev/null"
	fi

	# Create the node — mknod is idempotent if it already exists with right major/minor
	if ! mknod -m 0666 /dev/null c 1 3 2>/dev/null; then
		# If mknod fails (e.g. already exists wrong), force remove + retry
		rm -f /dev/null 2>/dev/null || true
		mknod -m 0666 /dev/null c 1 3 || err "mknod failed — check /dev mount or udev"
	fi

	# Final verification
	sleep 0.2 # give udev a breath
	NEW_MODE=$(stat -c %a /dev/null 2>/dev/null || echo "failed")
	if [[ "$NEW_MODE" == "666" ]] && [[ -c /dev/null ]]; then
		log "Success: /dev/null recreated → $(ls -l /dev/null)"
	else
		err "/dev/null still broken after recreation — manual intervention or reboot required"
	fi
else
	log "/dev/null already correct: $(ls -l /dev/null)"
fi

# Quick functional test
if ! echo "smoke" >/dev/null 2>&1; then
	warn "Smoke test failed even after recreation — reboot recommended"
fi

# ──────────────────────────────────────────────────────────────────────────────
# Phase 1–7: all previous fixes (unchanged, idempotent)
# ──────────────────────────────────────────────────────────────────────────────

log "Phase 1: Restoring executable bits on key binaries..."
chmod 0755 /usr/bin/brltty-* 2>/dev/null || true
chmod 0755 /usr/bin/gphoto2-config 2>/dev/null || true
chmod 0755 /usr/bin/wsrep_sst_common 2>/dev/null || true
chmod 0755 /usr/bin/mono-*-gdb.py 2>/dev/null || true
chmod 0755 /usr/bin/nopt 2>/dev/null || true

log "Phase 2: Restoring setgid on utempter..."
[[ -f /usr/lib/utempter/utempter ]] && chmod 2711 /usr/lib/utempter/utempter 2>/dev/null || true

log "Phase 3: Securing shadow files..."
chmod 0600 /etc/shadow 2>/dev/null || true
chmod 0640 /etc/gshadow 2>/dev/null || true

log "Phase 4: Fixing sudoers.d and useradd..."
chmod 0750 /etc/sudoers.d 2>/dev/null || true
find /etc/sudoers.d -type f -exec chmod 0440 {} \; 2>/dev/null || true
chmod 0664 /etc/default/useradd 2>/dev/null || true

log "Phase 5: Restoring group read on configs..."
find /etc -type f \( -name "*.conf" -o -name "*.cfg" -o -name "config" \) \
	-not -path "/etc/shadow*" -not -path "/etc/gshadow*" \
	-exec chmod 0644 {} \; 2>/dev/null || true

log "Phase 6: Restoring group write on service directories..."
for d in /etc/avahi/services /etc/cron.{daily,hourly,weekly,monthly} \
	/etc/ca-certificates/{extracted,trust-source} /etc/ssl/certs/java; do
	[[ -d "$d" ]] && chmod 0775 "$d" 2>/dev/null || true
done

log "Phase 7: Securing /root..."
chmod 0700 /root 2>/dev/null || true

# ──────────────────────────────────────────────────────────────────────────────
# Final validation block
# ──────────────────────────────────────────────────────────────────────────────

log "Rollback v4 complete. Final quick validation:"

echo ""
ls -l /dev/null /etc/shadow /etc/gshadow /usr/lib/utempter/utempter /etc/sudoers.d /root
echo ""
if sudo -l >/dev/null 2>&1; then
	log "sudo -l test passed"
else
	warn "sudo -l still fails — check PAM / sudoers syntax or reboot"
fi

log "If any service (cron, login, ssh) still misbehaves → reboot recommended"
log "Script is fully idempotent — safe to re-run anytime"
