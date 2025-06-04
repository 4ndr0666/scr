## Systematic Adjustments

1. According to the usage display, I see details for using the advanced option and verbose option. Ensure these are callable via `-A` `-v` or `--advanced` `--verbose`. 

2.  Previously we had the following global options:

```shell
Global Options:
  --advanced, -A        Enable advanced interactive prompts
  -v, --verbose         Verbose logging (shows FFmpeg progress bar)
  -b                    Bulk mode for process, fix, clean
  -an                   Remove audio
  -d                    Debug mode
  -C, --composite       Force composite fallback in merges
  -P, --max1080         Enforce maximum height of 1080p
```

Explain how you have refactored this into the recent revision. If you have not, try again and do not break or omit any code. Ensure all of these flags can be used for every command applicable. The following must be true of all global options:

```shell
-a, --advanced    Enable advanced options 
-v, --verbose       Enable verbose output to stdout 
-b, --bulk             Enable bulk process, fix and clean
-an, --noaudio    Remove audio
-c, --composite  Enable composite mode
-m, --max            Enable max height of 1080p
-o, --output         Output directory
-f, --fps                 Enable specific framerate
-p, --pts                Enable slow factor 1,2,..
-i, --interpolate   Enable motion interpolation
```

3. Previously we had the following commands:

```shell
Commands:
  process    <input> [output] [fps]
             Downscale video to 1080p with true lossless encoding (using -qp 0) and enforce FPS.
  merge      [-s fps] [-o output] [files...]
             Merge multiple videos losslessly. Re-encodes if resolutions differ.
  looperang  <file1> [file2 ... fileN] [output]
             Create a boomerang effect by concatenating forward and reversed segments.
  slowmo     <input> [output] [slow_factor] [target_fps] [-i]
             Apply slow motion effect; optionally use motion interpolation with -i.
  fixdur     <input> <output> [-a]
             Re-mux a file to fix duration/timestamp errors; audio dropped unless -a specified.
  help       Display this usage information.
```

Explain how you refactored this into the recent revision. If you have not, try again and do not break or omit any code. Ensure the following is true of the available commands:

- **process** <input> [output]:  Downscales a video to 1080p with true lossless encoding (using -qp 0). All global options are accepted.

- **merge** [-o output] [files...]: Merges multiple videos losslessly. Re-encodes only if necessary, opting for direct copy. All global options are accepted.

- **looperang** <file1> [file2 ... fileN]: Create a boomerang effect by concatenating forward and reversed segments. All global options accepted.

- **slowmo** <input> [output] [pts]: Apply specific pts factor of 1,2,etc. All global options accepted.

- **fix** <input> <output>: Re-mux a file to fix duration/timestamp errors. All global options accepted.

- **clean** <input> <output>: Removes all but essential metadata. All global options accepted.

- **probe** [<file>]: Provides video files details to stdout.

- **help**: Display this usage information.
```

## Command Details

Ensure the following is true of each respective command:

- **process**: If passed with no argument or just a flag, call fzf for multiple file selection. Then process the flags (-a, -b, -an, -c, -m, -f, -p, -i) that were passed after the selected files. The default output file is idempotently named (basename)_processed.mp4. The default output directory is the $PWD.

- **merge**: If passed with no arg or just a flag, call fzf for file selections. Then process the flags (-a, -an, -c, -m, -f, -p, -i). The default output file is idempotently named (basename)_merged.mp4. The default output directory is the $PWD.

- **looperang**: If passed with no arg or just a flag, call fzf for file selection. Then process the flags (-a, -an, -m, -f, -p, -i). The default output file is idempotently named (basename)_looperang.mp4. The default output directory is the $PWD.

- **slowmo**: If passed with no arg or just a flag, call fzf for file selection. Then process the flags (-a, -b, -an, -c, -m, -f, -p, -i). The default output file is idempotently named (basename)_slowmo.mp4. The default output directory is the $PWD. 

- **fix**: If passed with no arg or just a flag, call fzf for file selection. Then process the flags (-b, -an, -m, -f, -p, -i). The default output file is idempotently named (basename)_fixed.mp4. The default output directory is the $PWD. 

- **clean**: If passed with no arg or just a flag, call fzf for file selection. Then process the flags (-b). The default output file is idempotently named (basename)_cleaned.mp4. The default output directory is the $PWD.

- **probe**: If passed with no arg or just a flag, call fzf for file selection. The output goes straight to stdout. If the file is over 1080p, offer to process the video file. 

## Command Intentions

The following is my explanation of what I intended each function to do when I wrote them:

1. **process**: Downscale any video file with true lossless quality, opting for direct copy if applicable. 

2. **merge**: Advanced logic to ensure successful concatenation of various video files with different codecs, resolutions, size, fps, etc. 

3. **looperang**: Create a boomerang effect by concatenating forward and reversed segments.

4. **slowmo**: Apply high frame rate, smooth interpolated slow motions effects. 

5. **fix**: Fix duration/timestamp, monotonic DTS, moov atom missing, and other playback errors. 
 
6. **clean**: Removes all but only the essential metadata for working with the file.

7. **probe**: Provides video file details to stdout like this:

```shell
  echo -e "${CYAN}# === // Ffx Probe //${RESET}"
  echo
  echo -e "${CYAN}File:${RESET} $input"
  echo -e "${CYAN}Size:${RESET} $hsz"
  local fps_head
  fps_head="$(echo "$fps" | cut -d'/' -f1)"
  if [ "$fps_head" -gt 60 ] 2>/dev/null; then
    echo "➡️ High FPS detected; consider processing."
  fi
  echo -e "${CYAN}--------------------------------${RESET}"
  echo -e "${CYAN}Resolution:${RESET}   $resolution"
  echo -e "${CYAN}FPS:${RESET}          $fps"
  echo -e "${CYAN}Duration:${RESET}     ${duration}s"
}
```

## Summary

You now have a detailed set of instructions to perform on the codebase. The tasks should be clear, if not please ask me to clarify anything. Finally, here are some snippets to consider when crafting functionality for the aforementioned features:

**Deinterlace Detection**

```shell
is_interlaced() {
  local file="$1"
  if [ ! -f "$file" ]; then
    return 1
  fi
  local f_order
  f_order="$(ffprobe -v error -select_streams v:0 -show_entries stream=field_order -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null || echo "")"
  if [ "$f_order" != "progressive" ] && [ -n "$f_order" ]; then
    return 0
  else
    return 1
  fi
}

get_deinterlace_filter() {
  local file="$1"
  if is_interlaced "$file"; then
    echo ",yadif"
  else
    echo ""
  fi
}
```

**Fixing DTS issues**

```shell
check_dts_for_file() {
  local file="$1"
  local prev=0
  local prob=0
  ffprobe -v error -select_streams v -show_entries frame=pkt_dts_time -of csv=p=0 "$file" 2>/dev/null | while read -r line; do
    line="$(echo "$line" | tr -d ',' | xargs)"
    if ! echo "$line" | grep -Eq '^[0-9]+(\.[0-9]+)?$'; then
      continue
    fi
    if awk "BEGIN {if ($line < $prev) exit 0; else exit 1}" >/dev/null 2>&1; then
      echo "Non-monotonic DTS detected in $file (prev: $prev, curr: $line)" >&2
      prob=1
      break
    fi
    prev="$line"
  done
  return $prob
}

fix_dts() {
  local file="$1"
  local audio_opts_arr
  read -r -a audio_opts_arr <<< "$(get_audio_opts)"
  local tmpf
  tmpf="$(mktemp --suffix=.mp4)"
  if ! run_ffmpeg -y -fflags +genpts -i "$file" -c:v copy "${audio_opts_arr[@]}" -movflags +faststart "$tmpf" >/dev/null 2>&1 || [ ! -f "$tmpf" ]; then
    if ! run_ffmpeg -y -fflags +genpts -i "$file" -c:v "$ADV_CODEC" -crf "$ADV_CRF" -preset medium "${audio_opts_arr[@]}" "$tmpf" >/dev/null 2>&1 || [ ! -f "$tmpf" ]; then
      echo "❌ fix_dts: Could not fix DTS for $file" >&2
      rm -f "$tmpf"
      return 1
    fi
  fi
  echo "$tmpf"
}

ensure_dts_correct() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "❌ ensure_dts_correct: File not found: $file" >&2
    return 1
  fi
  if ! check_dts_for_file "$file"; then
    local fixed
    fixed="$(fix_dts "$file")"
    if [ ! -f "$fixed" ]; then
      echo "❌ ensure_dts_correct: DTS fix failed for $file" >&2
      return 1
    fi
    echo "$fixed"
  else
    echo "$file"
  fi
}
```

**Autocleaning Metadata**

```shell
auto_clean() {
  local file="$1"
  if [ -z "$file" ]; then
    return 0
  fi
  if [ "$CLEAN_META_DEFAULT" = true ] && [ -f "$file" ]; then
    local tmpf
    tmpf="$(mktemp --suffix=.mp4)"
    register_temp_file "$tmpf"
    if run_ffmpeg -y -i "$file" -map_metadata -1 -c copy "$tmpf" >/dev/null 2>&1 && [ -f "$tmpf" ]; then
      mv "$tmpf" "$file"
      verbose_log "Auto-cleaned metadata for $file"
    else
      rm -f "$tmpf" 2>/dev/null || true
      verbose_log "Auto-clean failed for $file; original retained."
    fi
  fi
}
```

Proceed to precisely parse your complete, fully-functional, error-free and production ready revision in manageable segments. Ensure your revision is inclusive of all logic and has no more than 4000 lines of code to be accepted/valid. Padding for inflated line numbers is not authorized.

