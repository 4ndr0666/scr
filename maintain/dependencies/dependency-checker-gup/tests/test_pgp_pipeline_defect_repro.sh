#!/usr/bin/env bash
source ./deps240_lib.sh > /dev/null 2>&1 || true
LOGFILE=/tmp/fake_pipeline.log
cat > "$LOGFILE" << 'LOGEOF'
error: failed to commit transaction (conflicting files)
peerflix: /usr/lib/node_modules/peerflix/node_modules/x/index.js exists in filesystem
Errors occurred, no packages were upgraded.
LOGEOF
log_line_start=0
echo "=== Same pipeline as rebuild_aur_packages, conflict-only output (no 'required by:' lines) ==="
found=0
while IFS= read -r parsed_line; do
	[[ -z "$parsed_line" ]] && continue
	found=$((found+1))
done < <(bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" sed -n "$((log_line_start + 1)),\$p" "${LOGFILE}" 2>/dev/null |
	bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" grep -E 'required by:' 2>/dev/null |
	bounded_exec "${SHORT_EXTERNAL_TIMEOUT_SECONDS}" sed -n 's/^.*>[[:space:]]*\([0-9A-F]\{16,\}\),[[:space:]]*required by:[[:space:]]*\(.\{1,\}\)$/\1 \2/p')
echo "parsed keys: $found"
echo "main flow continued past the pipeline: yes"
