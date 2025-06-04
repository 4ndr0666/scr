## Gap Mitigations

It is critical that all of the following functionalities are fully-fleshed out, integrated and 100% functional.

**Required Functionalites**

### 1. **Full interactive "advanced" prompting**

### 2. **Fully automated composite layout**: Basically this function analyzed the sizes of all selected files and designated the "lead" aspect ratio by the largest among the group. Example: I select one 16x9 file, two 4x3 files and a 9x16 file--The aspect ratio for the rendering will be 16x9 as its the biggest and the smaller files are able to symmetrically fit inside. The placement for such files can be random as long as they remian symmetrical. For instance, the two 4x3 files can fit side-by-side in a 16x9 aspect ratio and the 9x16 can fit centered inside of the 16x9 aspect ratio designated by the leader (becuase its the biggest). There are many examples in my code to gain insight from. 
 
### 3. **Two-pass & move atom logic (full flexibility) with bitrate control.**

### 4. **Merge sub-command (full composite integration)**: See 2.

### 5. **XDG Compliance**

### 6. **Strict and robust idempotency**

---

## Reintegration Plan

**Integration Outline**

### 1. XDG Compliance

$XDG_CONFIG_HOME/ffx4/config for advanced defaults (container, CRF, etc.).

$XDG_CACHE_HOME/ffx4/ for temporary concat files.

$XDG_RUNTIME_DIR/ffx4/ for frame dumps.

Fallback to ~/.config/ffx4, ~/.cache/ffx4, TMPDIR/ffx4 if vars unset.

### 2. Interactive “Advanced” (advanced_prompt)

Load/save defaults from config file.

Prompt for container, resolution, FPS, codec, pix_fmt, CRF, BR, multi-pass.

Validate input (e.g. resolution matches ^[0-9]+x[0-9]+$).

### 3. Composite Layout Algorithm

Collect heights/widths of all inputs.

Determine “leader” aspect ratio = max(width/height).

Compute grid (rows×cols) to place all videos symmetrically within leader canvas.

Generate -filter_complex xstack=…:layout=…:fill=black.

### 4. Two-Pass Encoding & Faststart

Expose ADV_MULTIPASS, ADV_CRF, ADV_BR from interactive or defaults.

If multi-pass: run pass-1 (-pass 1 -b:v $ADV_BR -an -f mp4 /dev/null), then pass-2 with audio + -movflags +faststart.

If single-pass: -crf $ADV_CRF -movflags +faststart.

### 5. Merge Sub-Command

Parse -s|--fps, -o|--output, --composite.

If --composite, invoke composite layout logic; else simple concat.

Ensure idempotent: existing output is overwritten only if -y given or prompt.

### 6. Idempotency & Robust Error Handling

Every cmd_* validates its arguments ([ $# -ge N ], [ -f "$file" ]).

On missing args, print usage snippet for that sub-command.

All temp files/dirs created under $XDG_RUNTIME_DIR/ffx4 and cleaned on EXIT via trap.

---

## Flags

```bash
 
 	-A) set -- "--advanced" "${@:2}" ;;
 	-v) set -- "--verbose" "${@:2}" ;;
 	-b) set -- "--bulk" "${@:2}" ;;
 	-an) set -- "--remove-audio" "${@:2}" ;;
 	-C) set -- "--composite" "${@:2}" ;;
 	-P) set -- "--max-1080" "${@:2}" ;;
 	-f) set -- "--fps" "${@:2}" ;;
 	-p) set -- "--pts" "${@:2}" ;;
 	-i) set -- "--interpolate" "${@:2}" ;;
 	esac
 
 	case "$1" in
 	--advanced) ADVANCED_MODE=true ;;
 	--verbose) VERBOSE_MODE=true ;;
 	--bulk) BULK_MODE=true ;;
 	--remove-audio) REMOVE_AUDIO=true ;;
 	--composite) COMPOSITE_MODE=true ;;
 	--max-1080) MAX_1080=true ;;
 	--interpolate) INTERPOLATE=true ;;
 	--output-dir)
 		OUTPUT_DIR="$2"
 		shift
 		;;
 	--fps)
 		SPECIFIC_FPS="$2"
 		shift
 		;;
 	--pts)
 		PTS_FACTOR="$2"
 		shift
 		;;
 	--container)
 		ADV_CONTAINER="$2"
 		shift
 		;;
 	--resolution)
 		ADV_RES="$2"
 		shift
 		;;
 	--codec)
 		ADV_CODEC="$2"
 		shift
 		;;
 	*)
```
