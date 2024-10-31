#!/bin/zsh

# Define base path
base_path="/Nas/Build/git/syncing/scr/"

# Enable extended globbing
setopt extended_glob

# Glob pattern excluding .git directories
globignore='.git'

# Benchmark Zsh Globbing
start_zsh=$(date +%s.%N)
dirs_zsh=(/Nas/Build/git/syncing/scr/**/*(/))
end_zsh=$(date +%s.%N)
elapsed_zsh=$(echo "$end_zsh - $start_zsh" | bc)

# Benchmark find
start_find=$(date +%s.%N)
dirs_find=()
while read -r dir; do
    dirs_find+=("$dir")
done < <(find "$base_path" -type d -not -path '*/.git/*')
end_find=$(date +%s.%N)
elapsed_find=$(echo "$end_find - $start_find" | bc)

# Output results
echo "Zsh Globbing elapsed time: $elapsed_zsh seconds"
echo "Find elapsed time: $elapsed_find seconds"
echo "Total directories (Zsh): ${#dirs_zsh[@]}"
echo "Total directories (Find): ${#dirs_find[@]}"
