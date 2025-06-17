#!/bin/zsh
# Utility timing module for benchmarking operations
timer_start() {
  date +%s.%N
}
timer_end() {
  local start_time="$1"
  local end_time
  end_time=$(date +%s.%N)
  echo $(echo "$end_time - $start_time" | bc)
}
