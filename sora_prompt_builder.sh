#!/usr/bin/env bash
# Author: 4ndr0666
# shellcheck disable=SC2034
set -euo pipefail
IFS=$'\n\t'
# ====================== // SORA PROMPT BUILDER //
## Description:Unified prompt generation CLI
## Requires: Python ≥3.9 with functions loaded via promptlib.py
# -----------------------------------------

## Help

usage() {
	printf '%s\n' "Usage: $0 --pose <pose_tag> | --desc <description> [--deakins] [--copy] [--dry-run]"
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

## Global Constants

POSE=""
DESC=""
USE_DEAKINS=0
COPY_FLAG=0
DRY_RUN=0
INTERACTIVE=0

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
	--interactive)
		INTERACTIVE=1
		shift
		;;
	--help)
		usage
		;;
	*)
		usage
		;;
	esac
done

if [[ $INTERACTIVE -eq 0 && -z "$POSE" && -z "$DESC" ]]; then
	usage
fi

if [[ $INTERACTIVE -eq 1 ]]; then
	FINAL_OUTPUT=$(
		python3 - "$USE_DEAKINS" <<'PYEOF'
from prompt_toolkit import PromptSession
from prompt_toolkit.completion import WordCompleter
from prompt_toolkit.styles import Style
from promptlib import prompt_orchestrator, POSE_TAGS
import sys

style = Style.from_dict({
    "prompt": "fg:#00f7ff",
    "": "fg:#005b69 bg:#151515",
    "completion-menu.completion": "fg:#005b69 bg:#151515",
    "completion-menu.completion.current": "fg:#15FFFF bg:#262626",
})

session = PromptSession()

pose = session.prompt('Pose Tag: ', completer=WordCompleter(POSE_TAGS, ignore_case=True), style=style)
desc = session.prompt('Description (optional): ', style=style)
use_deakins = bool(int(sys.argv[1]))

result = prompt_orchestrator(
    pose_tag=pose or None,
    subject_description=desc or None,
    use_deakins=use_deakins,
)

print('─────────────────────────────────────')
print('🎬 Final Prompt:')
print(result['final_prompt'])
print('─────────────────────────────────────')
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
	fi
fi
exit 0

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

FINAL_OUTPUT=$(
	python3 - "$POSE" "$DESC" "$USE_DEAKINS" <<'PYEOF'
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
fi
