#!/bin/zsh

# Define base path
base_path="/Nas/Build/git/syncing/scr/"

# Initialize counters
total_dirs=0
max_depth=0

# Start timing
start_time=$(date +%s.%N)

# Traverse directories using find, excluding .git
find "$base_path" -type d -not -path '*/.git/*' | while read -r dir; do
    ((total_dirs++))
    
    # Calculate depth
    relative_path="${dir#$base_path}"
    relative_path="${relative_path%/}"
    
    if [[ -z "$relative_path" ]]; then
        current_depth=0
    else
        slashes="${relative_path//[^\/]/}"
        num_slashes=${#slashes}
        current_depth=$(( num_slashes + 1 ))
    fi
    
    # Update max_depth
    if (( current_depth > max_depth )); then
        max_depth=$current_depth
    fi
done

# End timing
end_time=$(date +%s.%N)

# Calculate elapsed time
elapsed=$(echo "$end_time - $start_time" | bc)

# Output results
echo "Total directories traversed: $total_dirs"
echo "Maximum recursion depth: $max_depth"
echo "Elapsed time: $elapsed seconds"
