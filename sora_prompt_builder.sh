#!/usr/bin/env bash
# sora_prompt_builder.sh — Unified prompt generation CLI
# Requires: Python ≥3.9 with functions loaded via promptlib.py
# shellcheck disable=SC2034

set -euo pipefail
IFS=$'\n\t'

usage() {
  printf '%s\n' "Usage: $0 --pose <pose_tag> | --desc <description> [--deakins] [--copy] [--dry-run]"
  printf '%s\n' "Usage: $0 --pose <pose_tag> | --desc <description> [--deakins] [--dry-run]"
  printf '%s\n' "  --dry-run    Print the Python command instead of executing"
  printf '%s\n' "Examples:"
  printf '%s\n' "  $0 --pose leaning_forward"
  printf '%s\n' "  $0 --desc 'editorial fashion crouch under golden sunlight'"
  printf '%s\n' "  $0 --pose crouching --desc 'moody alley scene' --deakins"
  printf '%s\n' "Options:"
  printf '%s\n' "  --copy      Copy final prompt to clipboard if wl-copy exists"
  printf '%s\n' "  --dry-run   Print the python command but do not execute"
  printf '%s\n' "  --help      Show this help message"
  exit 1
}

POSE=""
DESC=""
USE_DEAKINS=0
COPY_FLAG=0
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pose)
      POSE="$2"
      shift 2
      ;;
    --desc)
      DESC="$2"
      shift 2
      ;;
    --deakins)
      USE_DEAKINS=1
      shift
      ;;
    --copy)
      COPY_FLAG=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --help)
      usage
      ;;
    *)
      usage
      ;;
    --pose) POSE="$2"; shift 2 ;;
    --desc) DESC="$2"; shift 2 ;;
    --deakins) USE_DEAKINS=1; shift ;;
  esac
done

if [[ -z "$POSE" && -z "$DESC" ]]; then
  usage
fi

cmd=(python3 - "$POSE" "$DESC" "$USE_DEAKINS")

if [[ $DRY_RUN -eq 1 ]]; then
  printf '%s ' "${cmd[@]}" "<<'PYEOF'"
  printf '\n%s\n' "# python code omitted for brevity" "PYEOF"
  exit 0
fi

FINAL_OUTPUT=$(python3 - "$POSE" "$DESC" "$USE_DEAKINS" <<'PYEOF'
import sys
from promptlib import prompt_orchestrator

pose = sys.argv[1] or None
desc = sys.argv[2] or None
use_deakins = bool(int(sys.argv[3]))

result = prompt_orchestrator(
    pose_tag=pose,
    subject_description=desc,
    use_deakins=use_deakins,
)

print("─────────────────────────────────────")
print("🎬 Final Prompt:")
print(result["final_prompt"])
print("─────────────────────────────────────")
print(f"🎛️  Base Mode: {result['base_mode']}")
print(f"🔧 Components Used: {', '.join(result['components_used'])}")
PYEOF
)

printf '%s\n' "$FINAL_OUTPUT"

if [[ $COPY_FLAG -eq 1 ]]; then
  if command -v wl-copy >/dev/null 2>&1; then
    printf '%s\n' "$FINAL_OUTPUT" | wl-copy
    printf '%s\n' "📋 Prompt copied to clipboard via wl-copy."
  else
    printf '%s\n' "⚠️  wl-copy not installed. Skipping clipboard copy."
  fi
  exit 1
fi

from promptlib import prompt_orchestrator

pose = os.getenv("POSE", "")
desc = os.getenv("DESC", "")
use_deakins = os.getenv("USE_DEAKINS", "0") == "1"

result = prompt_orchestrator(
    pose_tag=pose or None,
    subject_description=desc or None,
    use_deakins=use_deakins,
)

print("\u2500" * 37)
print("🎬 Final Prompt:")
print(result["final_prompt"])
print("\u2500" * 37)
print(f"🎛️  Base Mode: {result['base_mode']}")
print(f"🔧 Components Used: {', '.join(result['components_used'])}")
PYCODE
)

if [[ $DRY_RUN -eq 1 ]]; then
  printf '%s\n%s\n%s\n' "python3 - <<'PYEOF'" "$python_script" "PYEOF"
else
  python3 - <<PYEOF
$python_script
PYEOF
fi
