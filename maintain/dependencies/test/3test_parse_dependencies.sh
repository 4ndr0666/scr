#!/usr/bin/env bash
# File: test_parse_dependencies.sh
# Purpose: Test the parsing of dependency strings to remove version constraints.

# Sample dependency string from a pacman -Si output (simulate "Depends On" field)
sample_deps="gcc-libs  glibc  libgit2  oniguruma  zlib  libgit2.so=1.9-64"

echo "Original dependency string:"
echo "$sample_deps"

echo ""
echo "Parsed dependency names (version constraints removed):"
# For each word, remove any version specifiers (anything starting with '=', '<', or '>')
for dep in $sample_deps; do
    clean_dep=$(echo "$dep" | sed -E 's/[<>=].*$//')
    echo "$clean_dep"
done
