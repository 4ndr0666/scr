#!/usr/bin/env bash
# sora_prompt_builder.sh — Unified prompt generation CLI
# Requires: Python ≥3.9 with functions loaded via promptlib.py
# shellcheck disable=SC2034

set -euo pipefail
IFS=$'\n\t'

usage() {
  printf '%s\n' "Usage: $0 --pose <pose_tag> | --desc <description> [--deakins]"
  printf '%s\n' "Examples:"
  printf '%s\n' "  $0 --pose leaning_forward"
  printf '%s\n' "  $0 --desc 'editorial fashion crouch under golden sunlight'"
  printf '%s\n' "  $0 --pose crouching --desc 'moody alley scene' --deakins"
  exit 1
}

POSE=""
DESC=""
USE_DEAKINS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pose) POSE="$2"; shift 2 ;;
    --desc) DESC="$2"; shift 2 ;;
    --deakins) USE_DEAKINS=1; shift ;;
    *) usage ;;
  esac
done

if [[ -z "$POSE" && -z "$DESC" ]]; then
  usage
fi

python3 - <<'PYEOF'
from promptlib import prompt_orchestrator

result = prompt_orchestrator(
    pose_tag=${POSE:+"${POSE}"},
    subject_description=${DESC:+"${DESC}"},
    use_deakins=bool(${USE_DEAKINS})
)

print("─────────────────────────────────────")
print("🎬 Final Prompt:")
print(result["final_prompt"])
print("─────────────────────────────────────")
print(f"🎛️  Base Mode: {result['base_mode']}")
print(f"🔧 Components Used: {', '.join(result['components_used'])}")
PYEOF
