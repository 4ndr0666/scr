#!/usr/bin/env bash
# Author: 4ndr0666
# shellcheck disable=SC2034
set -euo pipefail
IFS=$'\n\t'

# ====================== // SORA PROMPT BUILDER //
## Description: Unified prompt generation CLI
## Requires: Python ≥3.9 with functions loaded via promptlib.py
# -----------------------------------------

usage() {
    printf '%s\n' "Usage: $0 --pose <pose_tag> | --desc <description> [--deakins] [--plugin <file.md>] [--copy] [--dry-run] [--interactive]"
    printf '%s\n' "Examples:"
    printf '%s\n' "  $0 --pose leaning_forward"
    printf '%s\n' "  $0 --desc 'editorial fashion crouch under golden sunlight'"
    printf '%s\n' "  $0 --pose crouching --desc 'moody alley scene' --deakins"
    printf '%s\n' "  $0 --plugin plugins/prompts1.md"
    printf '%s\n' "Options:"
    printf '%s\n' "  --plugin     Load a Markdown prompt-pack plugin (adds all quoted blocks)"
    printf '%s\n' "  --copy        Copy final prompt to clipboard if wl-copy exists"
    printf '%s\n' "  --dry-run     Print the Python command but do not execute"
    printf '%s\n' "  --interactive Launch interactive mode (requires TTY and prompt_toolkit)"
    printf '%s\n' "  --help        Show this help message"
    exit 1
}

POSE=""
DESC=""
USE_DEAKINS=0
COPY_FLAG=0
DRY_RUN=0
INTERACTIVE=0
PLUGIN_FILES=()

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
        --plugin)
            [[ $# -lt 2 ]] && { echo "Error: --plugin requires a file path"; exit 1; }
            PLUGIN_FILES+=("$2")
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            usage
            ;;
    esac
done

# =============================================================================
# Step 1: Start interactive mode if requested
# =============================================================================
if [[ $INTERACTIVE -eq 1 ]]; then
    FINAL_OUTPUT=$(
        python3 - "$USE_DEAKINS" <<'PYEOF'
import sys

try:
    from prompt_toolkit import PromptSession
    from prompt_toolkit.completion import WordCompleter
    from prompt_toolkit.styles import Style
    from prompt_toolkit.input import create_input
    from prompt_toolkit.output import create_output
except ModuleNotFoundError:
    print("prompt_toolkit is required for interactive mode.", file=sys.stderr)
    raise SystemExit(1)

try:
    tty_in = open("/dev/tty")
    tty_out = open("/dev/tty", "w")
except OSError:
    print("Interactive mode requires a TTY.", file=sys.stderr)
    raise SystemExit(1)

from promptlib import prompt_orchestrator, POSE_TAGS

style = Style.from_dict({
    "prompt": "fg:#00f7ff",
    "": "fg:#005b69 bg:#151515",
    "completion-menu.completion": "fg:#005b69 bg:#151515",
    "completion-menu.completion.current": "fg:#15FFFF bg:#262626",
})

with tty_in, tty_out:
    session = PromptSession(
        input=create_input(tty_in),
        output=create_output(tty_out),
    )

    pose = session.prompt(
        "Pose Tag: ",
        completer=WordCompleter(POSE_TAGS, ignore_case=True),
        style=style,
    )
    desc = session.prompt("Description (optional): ", style=style)
    use_deakins = bool(int(sys.argv[1]))

result = prompt_orchestrator(
    pose_tag=pose or None,
    subject_description=desc or None,
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
    exit 0
fi

# =============================================================================
# Step 2: Ensure at least one of --pose or --desc or --plugin is provided
# =============================================================================
if [[ -z "$POSE" && -z "$DESC" && ${#PLUGIN_FILES[@]} -eq 0 ]]; then
    usage
fi

# =============================================================================
# Step 3: Collate default and plugin-loaded prompts into PROMPTS[]
# =============================================================================
declare -a PROMPTS=()

# (A) If user specified plugin files, load them via plugin_loader.py
for file in "${PLUGIN_FILES[@]}"; do
    if [[ ! -f $file ]]; then
        echo "Error: plugin file not found: $file" >&2
        exit 1
    fi

    # Use plugin_loader.py to extract null-delimited blocks
    while IFS= read -r -d '' block; do
        PROMPTS+=("$block")
    done < <(python3 plugin_loader.py "$file")
done

# (B) If user provided a pose/desc but no plugin, we leave PROMPTS empty—
#     selection will be handled by prompt_orchestrator instead of pre-built library.

# =============================================================================
# Step 4: If not in library mode (PROMPTS empty), dispatch to Python directly
# =============================================================================
if [[ ${#PROMPTS[@]} -eq 0 ]]; then
    # Either --pose and/or --desc was provided, so call prompt_orchestrator directly.
    if [[ -z "$POSE" && -z "$DESC" ]]; then
        # Neither description nor pose → no work to do
        exit 0
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
    if [[ $COPY_FLAG -eq 1 && -n "$FINAL_OUTPUT" ]]; then
        if command -v wl-copy >/dev/null 2>&1; then
            printf '%s\n' "$FINAL_OUTPUT" | wl-copy
            printf '%s\n' "📋 Prompt copied to clipboard via wl-copy."
        else
            printf '%s\n' "⚠️  wl-copy not installed. Skipping clipboard copy."
        fi
    fi
    exit 0
fi

# =============================================================================
# Step 5: Otherwise, present fzf library-based selection of loaded plugin prompts
# =============================================================================
mapfile -t TITLES < <(
    for p in "${PROMPTS[@]}"; do
        # Extract the first non-empty line as the “title”
        echo "$p" | sed -n '1s/^"\{0,1\}//;s/"$//;p;'
    done
)

sel=$(printf '%s\n' "${TITLES[@]}" | fzf --prompt="🎞  Select prompt: " --height=40% --border)
if [[ -z $sel ]]; then
    echo "No selection." >&2
    exit 130
fi

# Find the index of the selected title
idx=-1
for i in "${!TITLES[@]}"; do
    if [[ "${TITLES[$i]}" == "$sel" ]]; then
        idx=$i
        break
    fi
done
if (( idx < 0 )); then
    echo "Selection error" >&2
    exit 1
fi

prompt="${PROMPTS[$idx]}"

# =============================================================================
# Step 6: Validation (camera tags, forbidden terms, duration, resolution)
# =============================================================================
warn() { printf "⚠️  %s\n" "$1" >&2; }

# camera tag presence
tag_ok=0
for tag in "${CAMERA_TAGS[@]}"; do
    if grep -qiF "$tag" <<< "$prompt"; then
        tag_ok=1
        break
    fi
done
(( tag_ok )) || warn "No [camera movement] tag detected."

# restricted terms
grep -Eiq "$BAD_WORDS_REGEX" <<<"$prompt" && warn "Policy-violating term detected."

# duration
dur_line=$(grep -Eo '^Duration:[[:space:]]*[0-9]+' <<<"$prompt" || true)
dur=0
[[ -n $dur_line ]] && dur=${dur_line##*:}
(( dur > MAX_DURATION )) && warn "Duration ${dur}s exceeds ${MAX_DURATION}s limit."

# resolution ≤ 1080p
reso_line=$(grep -Eo '^Resolution:[[:space:]]*[0-9]{3,4}p' <<<"$prompt" || true)
if [[ -z $reso_line ]]; then
    warn "No Resolution: field."
else
    reso=${reso_line##*:}
    [[ ! $reso =~ $RESO_REGEX ]] && warn "Malformed resolution string."
    num=${reso%p}
    (( num > 1080 )) && warn "Resolution ${reso} exceeds 1080p cap."
fi

# =============================================================================
# Step 7: Append standard notes, attachments, post-gen-op
# =============================================================================
prompt+=$'\n'"$PRO_DISCLAIMER"$'\n'"$SAFETY_NOTE"$'\n'"$TECH_LIMITS"

# Attach files if flags used
for kv in "${ATTACH[@]:-}"; do
    key=${kv%%=*}
    path=${kv#*=}
    case $key in
        --image)      prompt+=$'\n'"INPUT_IMAGE: $path" ;;
        --video)      prompt+=$'\n'"INPUT_VIDEO: $path" ;;
        --storyboard) prompt+=$'\n'"STORYBOARD_FILE: $path" ;;
    esac
done

# Post-generation op
ops=(Re-cut Remix Blend Loop Stabilize ColorGrade Skip)
post=$(printf '%s\n' "${ops[@]}" | fzf --prompt="🎛  Post-gen op? " --height=12 --border)
[[ $post != Skip && -n $post ]] && prompt+=$'\n'"POST_GEN_OP: $post"

# =============================================================================
# Step 8: Final payload preview + optional clipboard copy
# =============================================================================
payload="# === // SORA //\n\n$prompt"

if [[ -n $BAT ]]; then
    printf '%b\n' "$payload" | "$BAT" --language=md --style=plain --paging=always
else
    printf '%b\n' "$payload" | less -R
fi

if [[ $COPY_FLAG -eq 1 ]]; then
    if command -v wl-copy >/dev/null 2>&1; then
        printf '%b\n' "$payload" | wl-copy
        printf '%s\n' "📋 Prompt copied to clipboard via wl-copy."
    else
        printf '%s\n' "⚠️  wl-copy not installed; skipping clipboard copy."
    fi
fi
