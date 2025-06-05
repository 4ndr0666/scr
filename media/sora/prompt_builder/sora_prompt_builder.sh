#!/usr/bin/env bash
# Author: 4ndr0666
# shellcheck disable=SC2034
set -euo pipefail
IFS=$'\n\t'

# ====================== // SORA PROMPT BUILDER //
## Description: Unified prompt generation CLI
## Requires: Python ≥3.9 with promptlib.py and plugin_loader.py
# -----------------------------------------

# ────────────────────────────────────────────────────────────────────────────
#  Color & Status Constants
# ────────────────────────────────────────────────────────────────────────────
OK="$(tput setaf 2)[OK]$(tput sgr0)"
ERROR="$(tput setaf 1)[ERROR]$(tput sgr0)"
WARN="$(tput setaf 1)[WARN]$(tput sgr0)"
INFO="$(tput setaf 4)[INFO]$(tput sgr0)"
CAT="$(tput setaf 6)[ACTION]$(tput sgr0)"   # Cyan primary highlight

# ────────────────────────────────────────────────────────────────────────────
# Usage / Help
# ────────────────────────────────────────────────────────────────────────────
usage() {
    cat <<EOF
Usage: $(basename "$0") --pose <pose_tag> | --desc <description> [--deakins] [--plugin <file.md>] [--copy] [--dry-run] [--interactive]

Examples:
  $(basename "$0") --pose leaning_forward
  $(basename "$0") --desc "editorial fashion crouch under golden sunlight"
  $(basename "$0") --pose crouching --desc "moody alley scene" --deakins
  $(basename "$0") --plugin plugins/prompts1.md
  $(basename "$0") --interactive

Options:
  --plugin     Load a Markdown prompt-pack plugin (extracts all quoted blocks)
  --copy       Copy final prompt to clipboard if wl-copy exists
  --dry-run    Show Python command(s) without executing
  --interactive Launch interactive builder (requires TTY and prompt_toolkit)
  --deakins    Apply Deakins-style lighting augmentation
  --help       Show this help message and exit
EOF
    exit 1
}

# ────────────────────────────────────────────────────────────────────────────
# Global Variables & Defaults
# ────────────────────────────────────────────────────────────────────────────
POSE=""
DESC=""
USE_DEAKINS=0
COPY_FLAG=0
DRY_RUN=0
INTERACTIVE=0
PLUGIN_FILES=()

# Constants reused from promptlib for validation
readonly MAX_DURATION=10
readonly RESO_REGEX='^[0-9]{3,4}p$'
BAD_WORDS_REGEX='(sexual|porn|gore|torture|rape|beheading|extremist|hate|terror|celebrity|trademark|copyright|defamation|harassment|self-harm|medical_advice)'

# =============================================================================
# Argument Parsing
# =============================================================================
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
            [[ $# -lt 2 ]] && { echo "${ERROR} --plugin requires a file path"; exit 1; }
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
# Step 1: Interactive “Prompt Builder” Mode
# =============================================================================
if [[ $INTERACTIVE -eq 1 ]]; then
    # Run the Python builder, capture only FINAL_RESULT (no duplicate prints)
    FINAL_OUTPUT="$(python3 - "$USE_DEAKINS" <<'PYEOF'
import sys
from pathlib import Path

# prompt_toolkit imports
try:
    from prompt_toolkit import PromptSession
    from prompt_toolkit.completion import WordCompleter
    from prompt_toolkit.styles import Style
    from prompt_toolkit.input import create_input
    from prompt_toolkit.output import create_output
except ModuleNotFoundError:
    print("prompt_toolkit is required for interactive mode.", file=sys.stderr)
    raise SystemExit(1)

# TTY validation
try:
    tty_in = open("/dev/tty")
    tty_out = open("/dev/tty", "w")
except OSError:
    print("Interactive mode requires a TTY.", file=sys.stderr)
    raise SystemExit(1)

from promptlib import generate_pose_prompt, POSE_TAGS

# Pre-defined option lists
LIGHTING_OPTIONS = [
    "natural golden-hour (35° camera-left)",
    "softbox key (45° camera-right) + bounce fill (135° camera-left)",
    "ring light frontal, minimal shadows",
    "beauty dish 30° right + rim light 120° left",
    "practical car headlight back-rim + LED key 60° right",
    "diffused skylight + bounce fill 45°"
]
LENS_OPTIONS = [
    "85mm f/1.4, shallow DoF",
    "50mm f/2.0, moderate DoF",
    "35mm f/2.8, deep focus",
    "100mm macro f/2.8",
    "40mm anamorphic T2.2",
    "100mm macro f/5.6"
]
CAMERA_OPTIONS = [
    "push in",
    "static shot",
    "tracking shot",
    "arc, dolly left",
    "handheld sway",
    "pedestal down",
    "tilt up"
]
ENVIRONMENT_OPTIONS = [
    "neutral seamless studio backdrop",
    "sunlit alley with textured walls",
    "outdoor field with subtle wind",
    "night road with reflective puddles",
    "white cyclorama studio",
    "loft studio with wooden floor"
]
SHADOW_OPTIONS = [
    "soft, gradual edges",
    "hard edge falloff",
    "feathered, low-intensity",
    "layered directional with ambient falloff",
    "minimal shadows, very soft",
    "moody hard rim"
]
DETAIL_PROMPTS = [
    "Preserve skin pore texture and catchlights",
    "Emphasize fabric weave and motion creases",
    "Highlight microexpression shifts and eyelash detail",
    "Focus on jewelry sparkle and specular highlights",
    "Capture hair strand movement in wind",
    "Reveal muscle tension and subtle shadows"
]

# Style for prompt_toolkit
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

    # 1) Pose selection
    pose = session.prompt(
        "Pose Tag: ",
        completer=WordCompleter(POSE_TAGS, ignore_case=True),
        style=style,
    )

    # 2) Lighting selection
    lighting = session.prompt(
        "Lighting (choose one): ",
        completer=WordCompleter(LIGHTING_OPTIONS, ignore_case=True),
        style=style,
    )

    # 3) Lens selection
    lens = session.prompt(
        "Lens (choose one): ",
        completer=WordCompleter(LENS_OPTIONS, ignore_case=True),
        style=style,
    )

    # 4) Camera movement selection
    camera_move = session.prompt(
        "Camera Movement Tags (comma-separated): ",
        completer=WordCompleter(CAMERA_OPTIONS, ignore_case=True),
        style=style,
    )

    # 5) Environment selection
    environment = session.prompt(
        "Environment (choose one): ",
        completer=WordCompleter(ENVIRONMENT_OPTIONS, ignore_case=True),
        style=style,
    )

    # 6) Shadow quality selection
    shadow = session.prompt(
        "Shadow Quality (choose one): ",
        completer=WordCompleter(SHADOW_OPTIONS, ignore_case=True),
        style=style,
    )

    # 7) Detail emphasis selection
    detail = session.prompt(
        "Micro-detail Focus (choose one): ",
        completer=WordCompleter(DETAIL_PROMPTS, ignore_case=True),
        style=style,
    )

    # Build prompt components
    pose_block = generate_pose_prompt(pose)
    pose_lines = pose_block.splitlines()
    description_line = pose_lines[1].strip()  # second line holds the description

    movements = ", ".join([m.strip() for m in camera_move.split(",")])

    final = (
        f"> {{\n"
        f"    {description_line}\n"
        f"    Lighting: {lighting}.\n"
        f"    Lens: {lens}.\n"
        f"    Camera: [{movements}].\n"
        f"    Environment: {environment}.\n"
        f"    Shadow Quality: {shadow}.\n"
        f"    Detail: {detail}.\n"
        f"    *Note: cinematic references must be interpreted within each platform’s current capabilities.*\n"
        f"}}"
    )

    # Output only the final prompt block
    print(final)

PYEOF
)"

    # Display & auto-copy
    echo "─────────────────────────────────────"
    echo "🎬 Final Prompt:"
    printf '%s\n' "$FINAL_OUTPUT"
    echo "─────────────────────────────────────"
    echo "🎛️  Builder Mode: standard"
    echo "🔧 Components Used: pose, lighting, lens, camera, environment, shadow, detail"

    # Auto-copy if requested
    if [[ $COPY_FLAG -eq 1 ]]; then
        if command -v wl-copy >/dev/null 2>&1; then
            printf '%s\n' "$FINAL_OUTPUT" | wl-copy
            echo "${OK} Prompt copied to clipboard via wl-copy."
        else
            echo "${WARN} wl-copy not installed. Skipping clipboard copy."
        fi
    fi

    exit 0
fi

# =============================================================================
# Step 2: Validate that at least one of --pose, --desc, or --plugin is provided
# =============================================================================
if [[ -z "$POSE" && -z "$DESC" && ${#PLUGIN_FILES[@]} -eq 0 ]]; then
    usage
fi

# =============================================================================
# Step 3: Load Prompts via plugin_loader.py if any --plugin flags provided
# =============================================================================
declare -a PROMPTS=()

for file in "${PLUGIN_FILES[@]}"; do
    if [[ ! -f $file ]]; then
        echo "${ERROR} Plugin file not found: $file" >&2
        exit 1
    fi

    # Read null-delimited prompt blocks from Python loader
    while IFS= read -r -d '' block; do
        PROMPTS+=("$block")
    done < <(python3 plugin_loader.py "$file")
done

# =============================================================================
# Step 4: If no plugin-loaded prompts, directly call Python orchestrator
# =============================================================================
if [[ ${#PROMPTS[@]} -eq 0 ]]; then
    if [[ -z "$POSE" && -z "$DESC" ]]; then
        exit 0
    fi

    CMD=(python3 - "$POSE" "$DESC" "$USE_DEAKINS")
    if [[ $DRY_RUN -eq 1 ]]; then
        printf '%s ' "${CMD[@]}" "<<'PYEOF'"
        printf '\n%s\n' "# python code omitted for brevity" "PYEOF"
        exit 0
    fi

    FINAL_OUTPUT="$(
        python3 - "$POSE" "$DESC" "$USE_DEAKINS" <<'PYEOF'
import sys
from promptlib import prompt_orchestrator, policy_filter

pose = sys.argv[1] or None
desc = sys.argv[2] or None
use_deakins = bool(int(sys.argv[3]))

result = prompt_orchestrator(
    pose_tag=pose,
    subject_description=desc,
    use_deakins=use_deakins,
)

# Policy check (lenient by default)
policy_filter(result["final_prompt"], strict=False)

print("─────────────────────────────────────")
print("🎬 Final Prompt:")
print(result["final_prompt"])
print("─────────────────────────────────────")
print(f"🎛️  Base Mode: {result['base_mode']}")
print(f"🔧 Components Used: {', '.join(result['components_used'])}")
PYEOF
    )"

    printf '%s\n' "$FINAL_OUTPUT"
    if [[ $COPY_FLAG -eq 1 ]]; then
        if command -v wl-copy >/dev/null 2>&1; then
            printf '%s\n' "$FINAL_OUTPUT" | wl-copy
            echo "${OK} Prompt copied to clipboard via wl-copy."
        else
            echo "${WARN} wl-copy not installed. Skipping clipboard copy."
        fi
    fi

    exit 0
fi

# =============================================================================
# Step 5: fzf-Based Selection of Loaded Plugin Prompts
# =============================================================================
mapfile -t TITLES < <(
    for p in "${PROMPTS[@]}"; do
        # Extract first line as title, remove leading/trailing quotes
        echo "$p" | sed -n '1s/^"\{0,1\}//;s/"$//;p;'
    done
)

sel=$(printf '%s\n' "${TITLES[@]}" | fzf --prompt="🎞  Select prompt: " --height=40% --border)
if [[ -z $sel ]]; then
    echo "${INFO} No selection." >&2
    exit 130
fi

idx=-1
for i in "${!TITLES[@]}"; do
    if [[ "${TITLES[$i]}" == "$sel" ]]; then
        idx=$i
        break
    fi
done
if (( idx < 0 )); then
    echo "${ERROR} Selection error." >&2
    exit 1
fi

prompt="${PROMPTS[$idx]}"

# =============================================================================
# Step 6: Validation (camera tags, forbidden terms, duration, resolution)
# =============================================================================
warn() { printf "%s %s\n" "$WARN" "$1" >&2; }

# camera tag presence
tag_ok=0
for tag in "${CAMERA_MOVE_TAGS[@]}"; do
    if grep -qiF "$tag" <<< "$prompt"; then
        tag_ok=1
        break
    fi
done
(( tag_ok )) || warn "No [camera movement] tag detected."

# restricted terms
if grep -Eiq "$BAD_WORDS_REGEX" <<< "$prompt"; then
    warn "Policy-violating term detected."
fi

# duration (if present)
dur_line=$(grep -Eo '^Duration:[[:space:]]*[0-9]+' <<< "$prompt" || true)
dur=0
[[ -n $dur_line ]] && dur=${dur_line##*:}
(( dur > MAX_DURATION )) && warn "Duration ${dur}s exceeds ${MAX_DURATION}s limit."

# resolution ≤ 1080p
reso_line=$(grep -Eo '^Resolution:[[:space:]]*[0-9]{3,4}p' <<< "$prompt" || true)
if [[ -z $reso_line ]]; then
    warn "No Resolution: field."
else
    reso=${reso_line##*:}
    [[ ! $reso =~ $RESO_REGEX ]] && warn "Malformed resolution string."
    num=${reso%p}
    (( num > 1080 )) && warn "Resolution ${reso} exceeds 1080p cap."
fi

# =============================================================================
# Step 7: Append Standard Notes, Attachments, Post-Generation Operation
# =============================================================================
prompt+=$'\n'"*Note: cinematic references must be interpreted within each platform’s current capabilities.*"

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

# Post-generation operation menu
ops=(Re-cut Remix Blend Loop Stabilize ColorGrade Skip)
post=$(printf '%s\n' "${ops[@]}" | fzf --prompt="🎛  Post-gen op? " --height=12 --border)
[[ $post != Skip && -n $post ]] && prompt+=$'\n'"POST_GEN_OP: $post"

# =============================================================================
# Step 8: Final Payload Preview & Clipboard Copy
# =============================================================================
payload="# === // SORA //\n\n$prompt"

if command -v bat >/dev/null 2>&1; then
    printf '%b\n' "$payload" | bat --language=md --style=plain --paging=always
else
    printf '%b\n' "$payload" | less -R
fi

if [[ $COPY_FLAG -eq 1 ]]; then
    if command -v wl-copy >/dev/null 2>&1; then
        printf '%b\n' "$payload" | wl-copy
        echo "${OK} Prompt copied to clipboard via wl-copy."
    else
        echo "${WARN} wl-copy not installed; skipping clipboard copy."
    fi
fi
