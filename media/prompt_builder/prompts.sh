#!/usr/bin/env bash
# Author: 4ndr0666
# shellcheck disable=SC2034
set -euo pipefail
IFS=$'\n\t'

# ====================== // PROMPTS.SH //
## Description: Unified prompt generation CLI
## Requires: Python ≥3.9 with promptlib.py and plugin_loader.py
# -----------------------------------------

##  Color & Status Constants

OK="$(tput setaf 2)[OK]$(tput sgr0)"
ERROR="$(tput setaf 1)[ERROR]$(tput sgr0)"
WARN="$(tput setaf 1)[WARN]$(tput sgr0)"
INFO="$(tput setaf 4)[INFO]$(tput sgr0)"
CAT="$(tput setaf 6)[ACTION]$(tput sgr0)" # Cyan primary highlight

## Usage / Help

usage() {
	cat <<EOF
Usage: $(basename "$0") [--interactive] [--deakins] [--plugin <file.md>]

Examples:
  $(basename "$0") --interactive
  $(basename "$0") --interactive --deakins
  $(basename "$0") --plugin plugins/prompts1.md

Options:
  --interactive Launch the interactive prompt builder (recommended).
  --deakins     Apply Deakins-style lighting augmentation to the final prompt.
  --plugin      Load a Markdown prompt-pack plugin (extracts quoted blocks).
  --help        Show this help message and exit.

Note:
  • CLI mode (e.g. --pose <tag> or --desc <text>) is a future TODO.
  • For full parameter autocompletion and ease of use, run --interactive.
EOF
	exit 1
}

## Global Variables & Defaults

PYTHONPATH="${PYTHONPATH:+$PYTHONPATH:}$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
export PYTHONPATH
USE_DEAKINS=0
DRY_RUN=0
INTERACTIVE=0
PLUGIN_FILES=()

## Constants for validation

readonly MAX_DURATION=10
readonly RESO_REGEX='^[0-9]{3,4}p$'
BAD_WORDS_REGEX='(sexual|porn|gore|torture|rape|beheading|extremist|hate|terror|trademark|copyright|defamation|harassment|self-harm|medical_advice)'

## Camera movement tags for validation
readarray -t CAMERA_MOVE_TAGS < <(
	python3 - <<'PY'
from promptlib import CAMERA_MOVE_TAGS
for t in CAMERA_MOVE_TAGS:
    print(t)
PY
)
readonly CAMERA_MOVE_TAGS

## Argument Parsing

while [[ $# -gt 0 ]]; do
	case "$1" in
	--deakins)
		USE_DEAKINS=1
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
		[[ $# -lt 2 ]] && {
			echo "${ERROR} --plugin requires a file path"
			exit 1
		}
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

## Step 1: Interactive “Prompt Builder” Mode (enforced)

if [[ $INTERACTIVE -eq 1 ]]; then
	FINAL_OUTPUT="$(
		python3 - "$USE_DEAKINS" <<'PYEOF'
import sys
from promptlib import (
    POSE_TAGS,
    LIGHTING_OPTIONS,
    LENS_OPTIONS,
    CAMERA_OPTIONS,
    ENVIRONMENT_OPTIONS,
    SHADOW_OPTIONS,
    DETAIL_PROMPTS,
    AGE_GROUP_OPTIONS,
    GENDER_OPTIONS,
    ORIENTATION_OPTIONS,
    EXPRESSION_OPTIONS,
    SHOT_FRAMING_OPTIONS,
    ACTION_SEQUENCE_OPTIONS,
    build_pose_block,
    build_lighting_block,
    build_shadow_block,
    build_lens_block,
    build_camera_block,
    build_environment_block,
    build_detail_block,
    build_deakins_block
)

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

# Extract USE_DEAKINS from sys.argv[1]
use_deakins_flag = bool(int(sys.argv[1]))

# Define style for prompt_toolkit
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

    # 1) Age group selection
    age = session.prompt(
        "Age Group: ",
        completer=WordCompleter(AGE_GROUP_OPTIONS, ignore_case=True, match_middle=True),
        style=style,
    )

    # 2) Gender selection
    gender = session.prompt(
        "Gender: ",
        completer=WordCompleter(GENDER_OPTIONS, ignore_case=True, match_middle=True),
        style=style,
    )

    # 3) Orientation selection
    orientation = session.prompt(
        "Orientation: ",
        completer=WordCompleter(ORIENTATION_OPTIONS, ignore_case=True, match_middle=True),
        style=style,
    )

    # 4) Expression selection
    expression = session.prompt(
        "Expression: ",
        completer=WordCompleter(EXPRESSION_OPTIONS, ignore_case=True, match_middle=True),
        style=style,
    )

    # 5) Pose selection
    pose = session.prompt(
        "Pose Tag: ",
        completer=WordCompleter(POSE_TAGS, ignore_case=True, match_middle=True),
        style=style,
    )
    pose_line = build_pose_block(pose).splitlines()[1].strip()

    # 6) Action sequence selection
    action_sequence = session.prompt(
        "Action Sequence: ",
        completer=WordCompleter(ACTION_SEQUENCE_OPTIONS, ignore_case=True, match_middle=True),
        style=style,
    )
    action_line = f"Action Sequence: {action_sequence}"

    # 7) Lighting selection
    lighting = session.prompt(
        "Lighting (choose one): ",
        completer=WordCompleter(LIGHTING_OPTIONS, ignore_case=True, match_middle=True),
        style=style,
    )
    lighting_line = build_lighting_block(lighting)

    # 8) Shadow selection
    shadow = session.prompt(
        "Shadow Quality (choose one): ",
        completer=WordCompleter(SHADOW_OPTIONS, ignore_case=True, match_middle=True),
        style=style,
    )
    shadow_line = build_shadow_block(shadow)

    # 9) Lens selection
    lens = session.prompt(
        "Lens (choose one): ",
        completer=WordCompleter(LENS_OPTIONS, ignore_case=True, match_middle=True),
        style=style,
    )
    lens_line = build_lens_block(lens)

    # 10) Camera movement selection
    camera_move_input = session.prompt(
        "Camera Movement Tags (comma-separated): ",
        completer=WordCompleter(CAMERA_OPTIONS, ignore_case=True, match_middle=True),
        style=style,
    )
    camera_tags = [m.strip() for m in camera_move_input.split(",") if m.strip()]
    camera_line = build_camera_block(camera_tags)

    # 11) Shot framing selection
    shot = session.prompt(
        "Camera Shot/Framing: ",
        completer=WordCompleter(SHOT_FRAMING_OPTIONS, ignore_case=True, match_middle=True),
        style=style,
    )
    shot_line = f"Shot/Framing: {shot}."

    # 12) Environment selection
    environment = session.prompt(
        "Environment (choose one): ",
        completer=WordCompleter(ENVIRONMENT_OPTIONS, ignore_case=True, match_middle=True),
        style=style,
    )
    environment_line = build_environment_block(environment)

    # 13) Detail emphasis selection
    detail = session.prompt(
        "Micro-detail Focus (choose one): ",
        completer=WordCompleter(DETAIL_PROMPTS, ignore_case=True, match_middle=True),
        style=style,
    )
    detail_line = build_detail_block(detail)

    # Assemble the final block
    lines = [
        f"> {{",
        f"    {pose_line}",
        f"    Age: {age}; Gender: {gender}; Orientation: {orientation}; Expression: {expression}.",
        f"    {action_line}",
    ]

    # If Deakins‐mode, insert the Deakins block here; else insert lighting+shadow
    if use_deakins_flag:
        for dl in build_deakins_block():
            if "Deakins lighting augmentation" in dl:
                continue
            lines.append(f"    {dl}")
    else:
        lines.append(f"    {lighting_line}")
        lines.append(f"    {shadow_line}")

    # Common lines
    lines.extend([
        f"    {lens_line}",
        f"    {camera_line}",
        f"    {shot_line}",
        f"    {environment_line}",
        f"    {detail_line}",
        "",
        f"    *Note: cinematic references must be interpreted within each platform’s current capabilities.*",
        f"}}"
    ])

    final = "\n".join(lines)
    print(final)
PYEOF
	)"

	if [[ $USE_DEAKINS -eq 1 ]]; then
		DEAKINS_NOTE="*Note: Deakins lighting augmentation applied for cinematic realism.*"
		FINAL_OUTPUT=$(printf '%s\n' "$FINAL_OUTPUT" | sed '/Deakins lighting augmentation applied for cinematic realism\./d')
	fi

	# Display & auto-copy
	echo "─────────────────────────────────────"
	echo "🎬 Final Prompt:"
	printf '%s\n' "$FINAL_OUTPUT"
	[[ $USE_DEAKINS -eq 1 ]] && echo "$DEAKINS_NOTE"
	echo "─────────────────────────────────────"
	echo "🎛️  Builder Mode: standard"
	if [[ $USE_DEAKINS -eq 1 ]]; then
		echo "🔧 Components Used: pose, deakins_lighting, shadow, lens, camera, framing, environment, detail"
	else
		echo "🔧 Components Used: pose, lighting, shadow, lens, camera, framing, environment, detail"
	fi

	if command -v wl-copy >/dev/null 2>&1; then
		CLEAN_COPY=$(printf '%s\n' "$FINAL_OUTPUT" | sed '1d;$d;s/^\s\{4\}//;s/[[:space:]]*$//')
		printf '%s\n' "$CLEAN_COPY" | wl-copy
		echo "${OK} Prompt copied to clipboard via wl-copy."
	else
		echo "${WARN} wl-copy not installed. Skipping clipboard copy."
	fi

	exit 0
fi

## Step 2: Validate that at least one of --interactive or --plugin is provided

if [[ $INTERACTIVE -eq 0 && ${#PLUGIN_FILES[@]} -eq 0 ]]; then
	usage
fi

## Step 3: Load Prompts via plugin_loader.py if any --plugin flags provided

declare -a PROMPTS=()

for file in "${PLUGIN_FILES[@]}"; do
	if [[ ! -f $file ]]; then
		echo "${ERROR} Plugin file not found: $file" >&2
		exit 1
	fi

	# Legacy loading: grab null-delimited blocks
	while IFS= read -r -d '' block; do
		PROMPTS+=("$block")
	done < <(python3 plugin_loader.py "$file")
	status=${PIPESTATUS[0]}
	if [[ $status -ne 0 ]]; then
		echo "${ERROR} Failed to load plugin: $file" >&2
		exit "$status"
	fi
done
## Step 4: If no plugin-loaded prompts (and interactive already handled), exit

if [[ ${#PROMPTS[@]} -eq 0 ]]; then
	exit 0
fi

## Step 5: fzf‐Based Selection of Loaded Plugin Prompts

mapfile -t TITLES < <(
	for p in "${PROMPTS[@]}"; do
		# Use first non-empty line of each block as a title (strip leading/trailing quotes if present)
		echo "$p" | sed -n '1s/^"\{0,1\}//;s/"$//;p;'
	done
)

sel=$(printf '%s\n' "${TITLES[@]}" | fzf --prompt="${CAT} Select prompt: " --height=40% --border)
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
if ((idx < 0)); then
	echo "${ERROR} Selection error." >&2
	exit 1
fi

prompt="${PROMPTS[$idx]}"

## Step 6: Validation (camera tags, forbidden terms, duration, resolution)

warn() { printf "%s %s\n" "$WARN" "$1" >&2; }

# camera tag presence
tag_ok=0
for tag in "${CAMERA_MOVE_TAGS[@]}"; do
	if grep -qiF "$tag" <<<"$prompt"; then
		tag_ok=1
		break
	fi
done
((tag_ok)) || warn "No [camera movement] tag detected."

# restricted terms
if grep -Eiq "$BAD_WORDS_REGEX" <<<"$prompt"; then
	warn "Policy-violating term detected."
fi

# duration (if present)
dur_line=$(grep -Eo '^Duration:[[:space:]]*[0-9]+' <<<"$prompt" || true)
dur=0
[[ -n $dur_line ]] && dur=${dur_line##*:}
((dur > MAX_DURATION)) && warn "Duration ${dur}s exceeds ${MAX_DURATION}s limit."

# resolution ≤1080p
reso_line=$(grep -Eo '^Resolution:[[:space:]]*[0-9]{3,4}p' <<<"$prompt" || true)
if [[ -z $reso_line ]]; then
	warn "No Resolution: field."
else
	reso=${reso_line##*:}
	[[ ! $reso =~ $RESO_REGEX ]] && warn "Malformed resolution string."
	num=${reso%p}
	((num > 1080)) && warn "Resolution ${reso} exceeds 1080p cap."
fi

## Step 7: Append Standard Notes, Attachments, Post-Generation Operation

# Always append the standard note inside the braces if not already present
if ! grep -q "\*Note: cinematic references must be interpreted within each platform’s current capabilities\.\*" <<<"$prompt"; then
	prompt+=$'\n'"*Note: cinematic references must be interpreted within each platform’s current capabilities.*"
fi

# Attach files if flags used (image/video/storyboard) – placeholder for future
for kv in "${ATTACH[@]:-}"; do
	key=${kv%%=*}
	path=${kv#*=}
	case $key in
	--image) prompt+=$'\n'"INPUT_IMAGE: $path" ;;
	--video) prompt+=$'\n'"INPUT_VIDEO: $path" ;;
	--storyboard) prompt+=$'\n'"STORYBOARD_FILE: $path" ;;
	esac
done

# Post‐generation operation menu
ops=(Re-cut Remix Blend Loop Stabilize ColorGrade Skip)
post=$(printf '%s\n' "${ops[@]}" | fzf --prompt="${CAT} Post-gen op? " --height=12 --border)
[[ $post != Skip && -n $post ]] && prompt+=$'\n'"POST_GEN_OP: $post"

## Step 8: Final Payload Preview & Clipboard Copy

payload="# === // SORA //\n\n$prompt"

if command -v bat >/dev/null 2>&1; then
	# Use bat for syntax‐highlighted Markdown preview
	printf '%b\n' "$payload" | bat --language=md --style=plain --paging=always
else
	printf '%b\n' "$payload" | less -R
fi

if command -v wl-copy >/dev/null 2>&1; then
	printf '%b\n' "$payload" | wl-copy
	echo "${OK} Prompt copied to clipboard via wl-copy."
else
	echo "${WARN} wl-copy not installed; skipping clipboard copy."
fi
