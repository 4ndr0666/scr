#!/bin/sh
# split3.sh — channel-safe delivery
# usage: sh split3.sh hdl_studio.html
set -eu
f="${1:?usage: sh split3.sh <file>}"
total=$(wc -l < "$f")
a=$((total / 3))
b=$((2 * total / 3))

sed -n "1,${a}p"        "$f" > studio.part1
sed -n "$((a+1)),${b}p" "$f" > studio.part2
sed -n "$((b+1)),${total}p" "$f" > studio.part3

echo "== MANIFEST =="
sha256sum "$f" studio.part1 studio.part2 studio.part3
for p in "$f" studio.part1 studio.part2 studio.part3; do
  printf '%-12s lines=%-5s bytes=%-7s first=[%s] last=[%s]\n' \
    "$p" "$(wc -l < "$p")" "$(wc -c < "$p")" \
    "$(head -n1 "$p" | cut -c1-48)" "$(tail -n1 "$p" | cut -c1-48)"
done
echo "local check: cat studio.part1 studio.part2 studio.part3 | sha256sum"
