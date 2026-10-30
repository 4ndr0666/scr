#!/usr/bin/env bash
source ./deps242_lib.sh > /dev/null 2>&1 || true
LOGFILE=/tmp/fake_hooks.log; : > "$LOGFILE"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/hooks" "$T/scripts"

# hook whose Exec delegates to a script containing the path (the Archcraft shape)
cat > "$T/hooks/zz-pixmaps.hook" << EOF
[Trigger]
Operation = Install
Type = Package
Target = filesystem
[Action]
Description = Updating Distro Pixmaps...
When = PostTransaction
Exec = $T/scripts/update-pixmaps.sh
EOF
printf '#!/bin/sh\nrm -f /usr/share/pixmaps/archlinux-logo.png\n' > "$T/scripts/update-pixmaps.sh"
# hook that mentions the basename directly
cat > "$T/hooks/direct.hook" << 'EOF'
[Action]
Exec = /usr/bin/sh -c 'rm -f /usr/share/pixmaps/archlinux-logo.svg'
EOF
# unrelated hook
cat > "$T/hooks/unrelated.hook" << 'EOF'
[Action]
Description = Updating fonts
Exec = /usr/bin/fc-cache
EOF
# script that only mentions /usr/lib generically
printf '#!/bin/sh\nls /usr/lib\n' > "$T/scripts/generic.sh"
cat > "$T/hooks/generic.hook" << EOF
[Action]
Exec = $T/scripts/generic.sh
EOF

HOOK_DIRS=("$T/hooks")
ok=0; bad=0
chk() { if [[ "$2" == "$3" ]]; then echo "PASS: $1"; ok=$((ok+1)); else echo "FAIL: $1 (got: $2 | want: $3)"; bad=$((bad+1)); fi; }

out="$(find_referencing_hooks /usr/share/pixmaps/archlinux-logo.png 2>&1)"
chk "script-delegating hook found via parent dir" "$({ grep -c 'update-pixmaps.sh (via' <<<"$out" || true; })" "1"
chk "no spurious FATAL from the search" "$({ grep -c FATAL <<<"$out" || true; })" "0"
chk "unrelated hook not reported" "$({ grep -c unrelated <<<"$out" || true; })" "0"

out="$(find_referencing_hooks /usr/share/pixmaps/archlinux-logo.svg 2>&1)"
chk "hook naming the basename directly is found" "$({ grep -c 'direct.hook' <<<"$out" || true; })" "1"

out="$(find_referencing_hooks /usr/lib/foo.so 2>&1)"
chk "shallow parent (/usr/lib) does NOT match a script that merely mentions it" "$({ grep -c generic <<<"$out" || true; })" "0"

HOOK_DIRS=(/nonexistent-a /nonexistent-b)
out="$(find_referencing_hooks /usr/share/pixmaps/archlinux-logo.png 2>&1)"; rc=$?
chk "missing hook dirs: no output, no FATAL, rc 0" "${out:-<empty>}|$rc" "<empty>|0"
echo "passed=$ok failed=$bad"
