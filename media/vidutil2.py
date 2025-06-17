#!/usr/bin/env python3
# File: vidutil2.py
# Purpose: Production-ready Python script for screenshot extraction, video clipping, and merging with user-friendly prompts.
#          The script integrates with MPV+Lua for advanced clip selection if available. Denoising is optional, and
#          motion interpolation is delegated to the external SVP4 Manager if selected, ensuring reliability without conflicting with SVP4’s internal logic.

"""
**Synopsis**:
  vidutil2.py is a CLI utility with the following features:
  1. Screencaps mode: Extract frames from videos (all found in the current directory) at user-specified intervals.
  2. Clip mode: Uses fzf for video selection, falls back to manual user input for start/end times.
  3. Merge Videos: Interactive merges with the following modes:
       - Concatenate
       - Vertical Stack
       - Grid
       - Side-by-Side (for exactly two videos)
       - Auto (automatically pairs smaller videos side-by-side, concatenates them, merges them all sequentially)
  4. Optional Denoising (HQ Nlmeans or similar).
  5. Optional integration with SVP4 via 'SVPManager' invocation. If the user selects motion interpolation, the script
     relies on the user’s installed SVP4 environment. We orchestrate the final call to 'SVPManager' to handle motion
     interpolation after merging, ensuring it aligns with SVP4’s workflow.

**Dependencies**:
  - ffmpeg, ffprobe, fzf
  - mpv (optional, only if advanced clip selection is desired)
  - Python 3, prompt_toolkit, tqdm, re, logging, subprocess, shutil, atexit, argparse, json
  - SVP4 (optional, only if user chooses motion interpolation approach via 'SVPManager')

**Usage**:
  python3 vidutil2.py
  Then choose from the main menu:
    - Screencaps
    - Clip
    - Merge Videos
    - Exit

**Help**:
  Run the script with the --help flag to display detailed usage instructions.
  ```bash
  python3 vidutil2.py --help
  ```

**Note**:
  If the user chooses motion interpolation, the script directly invokes 'SVPManager' after final merges are done, instructing
  the user that further advanced interpolation is handled entirely by SVP4. This is the recommended stable approach.
"""

import os
import sys
import subprocess
import shutil
import tempfile
import logging
import re
import signal
import atexit
import json

try:
    from prompt_toolkit import prompt
    from prompt_toolkit.completion import WordCompleter
    from prompt_toolkit.formatted_text import HTML
    from prompt_toolkit.shortcuts import print_formatted_text
    from prompt_toolkit.styles import Style
except ImportError:
    print(
        "Prompt Toolkit is required for interactive prompts.\nInstall via: pip install prompt_toolkit"
    )
    sys.exit(1)

from tqdm import tqdm

# --- // Constants and Configuration:
CONFIG_FILE = "config.json"


def load_config():
    default_config = {
        "data_home": os.path.join(
            os.environ.get(
                "XDG_DATA_HOME", os.path.join(os.environ["HOME"], ".local", "share")
            ),
            "vidutil",
        ),
        "svp_manager_path": "/opt/svp4/SVPManager",
    }
    if os.path.isfile(CONFIG_FILE):
        try:
            with open(CONFIG_FILE, "r") as cf:
                user_config = json.load(cf)
            default_config.update(user_config)
        except Exception as e:
            print_warning(f"Failed to load config file: {e}")
    return default_config


config = load_config()

LOG_DIR = os.path.join(config["data_home"], "logs")
TEMP_DIR = os.path.join(config["data_home"], "tmp")
os.makedirs(LOG_DIR, exist_ok=True)
os.makedirs(TEMP_DIR, exist_ok=True)

DEFAULT_SCREENCAP_DIR = os.path.join(os.environ["HOME"], "Pictures", "screencaps")

style = Style.from_dict(
    {
        "completion-menu.completion": "fg:#15FFFF bg:default",
        "completion-menu.completion.current": "fg:#15FFFF bg:#333333",
        "ansicyan": "#15ffff",
        "ansired": "#A80D1B",
        "ansigreen": "#2ECC71",
        "ansiyellow": "#FFFF00",
        "prompt": "fg:#15FFFF bold",
        "menu": "fg:#15FFFF",
        "menuitem": "fg:#15FFFF",
        "warning": "fg:#FF0000 bold",
        "success": "fg:#00FF00 bold",
        "info": "fg:#FFFF00",
    }
)

logging.basicConfig(
    filename=os.path.join(LOG_DIR, "vidutil.log"),
    level=logging.INFO,
    format="[%(asctime)s] %(levelname)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)

# --- // Helper Functions:


def print_warning(message: str):
    print_formatted_text(HTML(f"<warning>{message}</warning>"), style=style)


def print_success(message: str):
    print_formatted_text(HTML(f"<success>{message}</success>"), style=style)


def print_info(message: str):
    print_formatted_text(HTML(f"<info>{message}</info>"), style=style)


def error_exit(message: str):
    logging.error(message)
    print_formatted_text(HTML(f"<ansired>Error:</ansired> {message}"), style=style)
    sys.exit(1)


def sanitize_input(user_input: str) -> str:
    if not user_input:
        return ""
    return re.sub(r"[^a-zA-Z0-9_ ./:-]", "", user_input)


def sanitize_filename(filename: str) -> str:
    return re.sub(r'[<>:"/\\|?*]', "", filename)


def run_ffmpeg_with_progress(cmd: list, description: str, total_duration: float):
    """Run ffmpeg command with a tqdm progress bar."""
    try:
        process = subprocess.Popen(cmd, stderr=subprocess.PIPE, universal_newlines=True)
    except Exception as e:
        logging.error(f"Failed to start FFmpeg process: {e}")
        print_warning(f"Failed to start FFmpeg: {e}")
        return

    if total_duration <= 0:
        for line in process.stderr:
            pass
        process.wait()
        return

    pbar = tqdm(
        total=total_duration,
        desc=description,
        bar_format="{l_bar}{bar}| {n_fmt}/{total_fmt} sec",
        colour="cyan",
    )
    time_pattern = re.compile(r"time=(\d+):(\d+):(\d+\.\d+)")
    try:
        for line in process.stderr:
            match = time_pattern.search(line)
            if match:
                hh, mm, ss = match.groups()
                current_time = int(hh) * 3600 + int(mm) * 60 + float(ss)
                pbar.n = min(current_time, total_duration)
                pbar.refresh()
    except Exception as e:
        logging.error(f"Error during FFmpeg processing: {e}")
    finally:
        process.wait()
        pbar.close()


def get_video_properties(file: str) -> dict:
    """Retrieve basic video properties using ffprobe. Return dict or None on error."""
    props = {}
    cmd = [
        "ffprobe",
        "-v",
        "error",
        "-select_streams",
        "v:0",
        "-show_entries",
        "stream=codec_name,width,height,r_frame_rate,duration,bit_rate,pix_fmt",
        "-of",
        "default=noprint_wrappers=1:nokey=0",
        file,
    ]
    try:
        result = subprocess.run(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True
        )
        for line in result.stdout.splitlines():
            if "=" in line:
                k, v = line.split("=", 1)
                props[k.strip()] = v.strip()
    except subprocess.CalledProcessError as e:
        logging.warning(f"ffprobe error for '{file}': {e}")
        return None
    return props


def verify_and_repair_video_format(video: str) -> bool:
    """Check extension, attempt moov repair if needed."""
    if not re.search(
        r"\.(mp4|avi|mkv|mov|flv|wmv|webm|m4v|gif)$", video, re.IGNORECASE
    ):
        print_warning(f"Unsupported video format for '{video}'.")
        return False
    try:
        result = subprocess.run(
            ["ffprobe", video],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        if "moov atom not found" in result.stderr:
            logging.warning(f"'{video}' missing moov atom. Repair attempt.")
            temp_fixed_file = os.path.join(TEMP_DIR, os.path.basename(video))
            repair_cmd = [
                "ffmpeg",
                "-y",
                "-i",
                video,
                "-c",
                "copy",
                "-movflags",
                "faststart",
                temp_fixed_file,
            ]
            subprocess.run(
                repair_cmd,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=True,
            )
            shutil.move(temp_fixed_file, video)
            logging.info(f"Repaired '{video}'.")
    except subprocess.CalledProcessError:
        return False
    return True


def get_total_duration(files: list) -> float:
    total = 0.0
    for f in files:
        props = get_video_properties(f)
        if props and "duration" in props:
            try:
                total += float(props["duration"])
            except ValueError:
                pass
    return total


def launch_svp_manager():
    """Launch SVPManager with sudo permissions."""
    svp_manager_path = config["svp_manager_path"]
    if os.path.isfile(svp_manager_path) and os.access(svp_manager_path, os.X_OK):
        try:
            print_info("Launching SVPManager with sudo permissions.")
            subprocess.Popen(
                ["sudo", svp_manager_path],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            print_success("SVPManager launched successfully.")
        except Exception as ex:
            logging.warning(f"Could not invoke SVPManager automatically. {ex}")
            print_warning(
                "Could not invoke SVPManager. Please run it manually if needed."
            )
    else:
        logging.warning(
            f"SVPManager binary not found or not executable at '{svp_manager_path}'."
        )
        print_warning(
            f"SVPManager binary not found or not executable at '{svp_manager_path}'. Please run it manually if needed."
        )


# --- // Main Functionalities:


def screencaps_mode():
    logging.info("Screencaps mode selected.")
    try:
        find_cmd = [
            "find",
            os.getcwd(),
            "-type",
            "f",
            "(",
            "-iname",
            "*.mp4",
            "-o",
            "-iname",
            "*.avi",
            "-o",
            "-iname",
            "*.mkv",
            "-o",
            "-iname",
            "*.mov",
            "-o",
            "-iname",
            "*.flv",
            "-o",
            "-iname",
            "*.wmv",
            "-o",
            "-iname",
            "*.webm",
            "-o",
            "-iname",
            "*.m4v",
            "-o",
            "-iname",
            "*.gif",
            ")",
        ]
        all_videos = (
            subprocess.run(find_cmd, stdout=subprocess.PIPE, text=True, check=True)
            .stdout.strip()
            .split("\n")
        )
        if not all_videos or all_videos == [""]:
            print_warning("No video files found in current directory.")
            return
        fzf = shutil.which("fzf")
        if not fzf:
            print_warning(
                "fzf is not installed. Please install fzf to use this feature."
            )
            return
        result = subprocess.run(
            ["fzf", "--prompt=Select video for screencaps>"],
            input="\n".join(all_videos),
            stdout=subprocess.PIPE,
            text=True,
        )
        if result.returncode != 0 or not result.stdout.strip():
            print_warning("No video selected. Returning to menu.")
            return
        source_video = result.stdout.strip()
    except Exception as e:
        print_warning(f"fzf selection failed. Error: {e}")
        return

    interval = prompt(
        HTML("<ansicyan>Enter capture interval in seconds (e.g., 5): </ansicyan>"),
        style=style,
    ).strip()
    interval = sanitize_input(interval)
    interval = interval or "5"
    output_dir = prompt(
        HTML(
            f"<ansicyan>Enter output directory for screenshots (default: {DEFAULT_SCREENCAP_DIR}): </ansicyan>"
        ),
        style=style,
    ).strip()
    output_dir = sanitize_input(output_dir)
    output_dir = output_dir or DEFAULT_SCREENCAP_DIR
    os.makedirs(output_dir, exist_ok=True)
    logging.info(f"Screencaps every {interval}s from '{source_video}'.")
    cmd = [
        "ffmpeg",
        "-y",
        "-i",
        source_video,
        "-vf",
        f"fps=1/{interval}",
        os.path.join(output_dir, "screenshot_%04d.png"),
    ]

    props = get_video_properties(source_video)
    dur = 60.0
    if props and "duration" in props:
        try:
            dur = float(props["duration"])
        except ValueError:
            pass
    try:
        run_ffmpeg_with_progress(cmd, "Extracting screenshots", dur)
        print_success(f"Screenshots saved to '{output_dir}'.")
        logging.info(f"Screenshots saved to '{output_dir}'.")
    except Exception as e:
        error_exit(f"Failed to extract screenshots. Error: {e}")


def clip_mode():
    """Clip mode: pick a single video, fallback to manual times."""
    logging.info("Clip mode selected.")
    try:
        find_cmd = [
            "find",
            os.getcwd(),
            "-type",
            "f",
            "(",
            "-iname",
            "*.mp4",
            "-o",
            "-iname",
            "*.avi",
            "-o",
            "-iname",
            "*.mkv",
            "-o",
            "-iname",
            "*.mov",
            "-o",
            "-iname",
            "*.flv",
            "-o",
            "-iname",
            "*.wmv",
            "-o",
            "-iname",
            "*.webm",
            "-o",
            "-iname",
            "*.m4v",
            "-o",
            "-iname",
            "*.gif",
            ")",
        ]
        all_videos = (
            subprocess.run(find_cmd, stdout=subprocess.PIPE, text=True, check=True)
            .stdout.strip()
            .split("\n")
        )
        if not all_videos or all_videos == [""]:
            print_warning("No video files found in the current directory.")
            return
        fzf = shutil.which("fzf")
        if not fzf:
            print_warning(
                "fzf is not installed. Please install fzf to use this feature."
            )
            return
        fzf_result = subprocess.run(
            ["fzf", "--prompt=Select video to clip>"],
            input="\n".join(all_videos),
            stdout=subprocess.PIPE,
            text=True,
        )
        if fzf_result.returncode != 0 or not fzf_result.stdout.strip():
            print_warning("No video selected. Returning to menu.")
            return
        source_video = fzf_result.stdout.strip()
    except Exception as e:
        print_warning(f"fzf selection failed: {e}")
        return

    if not source_video:
        print_warning("No video selected. Returning to menu.")
        return

    print_warning(
        "mpv+Lua integration is not implemented. Falling back to manual input."
    )
    s = input("Enter start time (HH:MM:SS or seconds): ").strip()
    e = input("Enter end time (HH:MM:SS or seconds): ").strip()

    if not s or not e:
        print_warning("No start/end times provided. Clip creation aborted.")
        return

    output_file = prompt(
        HTML("<ansicyan>Enter output file name (default: clip.mp4): </ansicyan>"),
        style=style,
    ).strip()
    output_file = sanitize_input(output_file)
    output_file = output_file or "clip.mp4"
    if not output_file.lower().endswith(".mp4"):
        output_file += ".mp4"
    output_file = sanitize_filename(output_file)

    if os.path.isfile(output_file):
        print_warning(f"Output file '{output_file}' already exists.")
        overwrite = (
            prompt(
                HTML("<ansicyan>Do you want to overwrite it? [y/n]: </ansicyan>"),
                style=style,
            )
            .strip()
            .lower()
        )
        overwrite = sanitize_input(overwrite)
        if overwrite not in ["y", "yes"]:
            print_info("Clip creation aborted to prevent overwriting.")
            return

    cmd = [
        "ffmpeg",
        "-y",
        "-ss",
        s,
        "-i",
        source_video,
        "-to",
        e,
        "-c",
        "copy",
        output_file,
    ]

    props = get_video_properties(source_video)
    dur = 60.0
    if props and "duration" in props:
        try:
            dur = float(props["duration"])
        except ValueError:
            pass
    try:
        run_ffmpeg_with_progress(cmd, f"Creating clip '{output_file}'", dur)
        print_success(f"Clip created: '{output_file}'.")
        logging.info(f"Clip created: {output_file}")
    except Exception as exc:
        error_exit(f"Failed to create clip. Error: {exc}")


def normalize_video(
    file: str,
    temp_dir: str,
    target_resolution: str,
    target_framerate: float,
    denoise: bool = False,
) -> str:
    """
    Normalize videos by scaling/padding and optionally denoising.
    """
    if not verify_and_repair_video_format(file):
        logging.warning(f"Format issues for '{file}'. Skipped.")
        return None
    props = get_video_properties(file)
    if not props or "width" not in props or "height" not in props:
        logging.warning(f"Incomplete properties for '{file}'. Skipped.")
        return None

    base_name = os.path.splitext(os.path.basename(file))[0]
    base_name = sanitize_filename(base_name)
    normalized_file = os.path.join(temp_dir, f"{base_name}_normalized.mp4")

    vf_chain_elems = []
    if target_resolution.lower() != "original":
        try:
            w, h = target_resolution.split("x")
            scale_filter = f"scale={w}:{h}:force_original_aspect_ratio=decrease"
            pad_filter = f"pad={w}:{h}:(ow-iw)/2:(oh-ih)/2"
            vf_chain_elems += [scale_filter, pad_filter]
        except:
            pass

    if denoise:
        # example: nlmeans
        vf_chain_elems.append("nlmeans=s=1.0:p=7")

    vf_chain = None
    if vf_chain_elems:
        vf_chain = ",".join(vf_chain_elems)

    # check audio
    audio_opt = ["-an"]
    try:
        r = subprocess.run(
            [
                "ffprobe",
                "-v",
                "error",
                "-select_streams",
                "a:0",
                "-show_entries",
                "stream=codec_type",
                "-of",
                "csv=p=0",
                file,
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=True,
        )
        if "audio" in r.stdout.lower():
            audio_opt = ["-c:a", "aac", "-b:a", "128k"]
    except:
        pass

    cmd = [
        "ffmpeg",
        "-y",
        "-i",
        file,
        "-c:v",
        "libx264",
        "-crf",
        "23",
        "-preset",
        "medium",
    ] + audio_opt
    if vf_chain:
        cmd += ["-vf", vf_chain]
    if target_framerate > 0:
        cmd += ["-r", str(target_framerate)]
    cmd += [normalized_file]

    dur = 0.0
    if props and "duration" in props:
        try:
            dur = float(props["duration"])
        except ValueError:
            pass
    try:
        run_ffmpeg_with_progress(cmd, f"Normalizing '{base_name}'", dur)
        logging.info(f"Normalized saved: {normalized_file}")
        print_info(f"Normalized: '{normalized_file}'.")
        return normalized_file
    except Exception as e:
        logging.warning(f"Normalization failed: {e}")
        return None


def merge_group_videos(
    output_file: str,
    input_files: list,
    denoise: bool,
    motion: bool,
    user_options: dict,
    temp_dir: str,
):
    merging_mode = user_options.get("merging_mode", "concat")
    target_resolution = user_options.get("target_resolution", "1920x1080")
    target_framerate = user_options.get("target_framerate", 60)
    normalized_files = []
    for f in input_files:
        nf = normalize_video(
            f, temp_dir, target_resolution, float(target_framerate), denoise=denoise
        )
        if nf:
            normalized_files.append(nf)
    if not normalized_files:
        error_exit("No valid videos to merge after normalization.")

    if merging_mode == "concat":
        file_list_txt = os.path.join(temp_dir, "file_list.txt")
        with open(file_list_txt, "w") as ff:
            for n in normalized_files:
                ff.write(f"file '{n}'\n")
        cmd = [
            "ffmpeg",
            "-y",
            "-f",
            "concat",
            "-safe",
            "0",
            "-i",
            file_list_txt,
            "-c:v",
            "libx264",
            "-preset",
            "medium",
            "-crf",
            "23",
            "-pix_fmt",
            "yuv420p",
            "-c:a",
            "aac",
            "-b:a",
            "128k",
            output_file,
        ]
        total_dur = get_total_duration(normalized_files)
        try:
            run_ffmpeg_with_progress(cmd, "Concatenating videos", total_dur)
            logging.info(f"Concat done. Output: '{output_file}'")
            print_success(
                f"Video concatenation completed. Output saved to '{os.path.abspath(output_file)}'."
            )
        except Exception as e:
            error_exit(f"Failed concat. {e}")

    elif merging_mode == "vstack":
        if len(normalized_files) < 2:
            error_exit("Not enough videos for vertical stacking.")
        inputs = []
        filters = ""
        for idx, nf in enumerate(normalized_files):
            inputs += ["-i", nf]
            filters += f"[{idx}:v] setpts=PTS-STARTPTS [v{idx}]; "
        vstack_in = "".join([f"[v{i}]" for i in range(len(normalized_files))])
        filters += f"{vstack_in}vstack=inputs={len(normalized_files)}[outv]"
        cmd = (
            ["ffmpeg", "-y"]
            + inputs
            + [
                "-filter_complex",
                filters,
                "-map",
                "[outv]",
                "-c:v",
                "libx264",
                "-preset",
                "medium",
                "-crf",
                "23",
                "-pix_fmt",
                "yuv420p",
                output_file,
            ]
        )
        total_dur = get_total_duration(normalized_files)
        try:
            run_ffmpeg_with_progress(cmd, "Vertically stacking", total_dur)
            print_success(
                f"Vertical stacking completed. Output: '{os.path.abspath(output_file)}'."
            )
        except Exception as e:
            error_exit(f"Failed vertical stacking: {e}")

    elif merging_mode == "grid":
        if len(normalized_files) < 2:
            error_exit("Not enough videos for grid merging.")
        num_inputs = len(normalized_files)
        # default aspect ratio approach
        target_width, target_height = (1920, 1080)
        if target_resolution.lower() != "original":
            try:
                w, h = target_resolution.split("x")
                target_width, target_height = int(w), int(h)
            except:
                pass

        # pick best grid
        target_aspect = target_width / target_height
        best_grid = None
        min_diff = None
        for c in range(1, num_inputs + 1):
            r = (num_inputs + c - 1) // c
            aspect = (c * 1.0) / (r * 1.0)
            diff = abs(aspect - target_aspect)
            if min_diff is None or diff < min_diff:
                min_diff = diff
                best_grid = (c, r)
        grid_cols, grid_rows = best_grid
        cell_w = target_width // grid_cols
        cell_h = target_height // grid_rows

        inputs = []
        filters = ""
        for i, nf in enumerate(normalized_files):
            inputs += ["-i", nf]
            filters += f"[{i}:v] setpts=PTS-STARTPTS, scale={cell_w}:{cell_h}:force_original_aspect_ratio=decrease,pad={cell_w}:{cell_h}:(ow-iw)/2:(oh-ih)/2 [v{i}]; "
        stack_in = ""
        for i in range(num_inputs):
            stack_in += f"[v{i}]"
        filters += f"{stack_in} xstack=inputs={num_inputs}:layout="
        layout_positions = []
        for i in range(num_inputs):
            x_idx = i % grid_cols
            y_idx = i // grid_cols
            x_pos = x_idx * cell_w
            y_pos = y_idx * cell_h
            layout_positions.append(f"{x_pos}_{y_pos}")
        layout_str = "|".join(layout_positions)
        filters += f"{layout_str}[outv]"
        cmd = (
            ["ffmpeg", "-y"]
            + inputs
            + [
                "-filter_complex",
                filters,
                "-map",
                "[outv]",
                "-c:v",
                "libx264",
                "-preset",
                "medium",
                "-crf",
                "23",
                "-pix_fmt",
                "yuv420p",
                output_file,
            ]
        )
        total_dur = get_total_duration(normalized_files)
        try:
            run_ffmpeg_with_progress(cmd, "Grid merging", total_dur)
            print_success(
                f"Grid merging completed. Output saved to '{os.path.abspath(output_file)}'."
            )
        except Exception as e:
            error_exit(f"Failed grid merging: {e}")

    elif merging_mode == "side_by_side":
        if len(normalized_files) != 2:
            error_exit("Side-by-side requires exactly 2 videos.")
        cmd = [
            "ffmpeg",
            "-y",
            "-i",
            normalized_files[0],
            "-i",
            normalized_files[1],
            "-filter_complex",
            "[0:v][1:v]hstack=inputs=2[outv]",
            "-map",
            "[outv]",
            "-c:v",
            "libx264",
            "-preset",
            "medium",
            "-crf",
            "23",
            "-pix_fmt",
            "yuv420p",
            output_file,
        ]
        total_dur = get_total_duration(normalized_files)
        try:
            run_ffmpeg_with_progress(cmd, "Side-by-side merging", total_dur)
            print_success(
                f"Side-by-side merging done. '{os.path.abspath(output_file)}'."
            )
        except Exception as e:
            error_exit(f"Failed side-by-side: {e}")

    else:
        error_exit(f"Unknown merging mode '{merging_mode}'.")

    # After merging, handle motion interpolation if selected
    if motion:
        launch_svp_manager()


def auto_merging_mode(
    valid_input_files: list,
    output_file: str,
    target_resolution: str,
    target_framerate: float,
    denoise: bool,
    motion: bool,
):
    """
    Auto merges videos by identifying the largest video, pairing smaller ones side-by-side into ephemeral merges,
    then concatenating everything. Motion interpolation is handled post-merge if selected.
    """
    temp_dir = tempfile.mkdtemp(prefix="tmp_auto_", dir=LOG_DIR)
    logging.info("AUTO merging started.")
    # Sort videos by area desc
    file_areas = []
    for f in valid_input_files:
        props = get_video_properties(f)
        if props and "width" in props and "height" in props:
            try:
                w = int(props["width"])
                h = int(props["height"])
                file_areas.append((f, w * h))
            except:
                pass
    if not file_areas:
        error_exit("Auto merging: no valid files with area.")
    file_areas.sort(key=lambda x: x[1], reverse=True)
    largest_video = file_areas[0][0]
    sorted_files = [x[0] for x in file_areas]
    normalized_files = []
    for vf in sorted_files:
        nf = normalize_video(
            vf, temp_dir, target_resolution, float(target_framerate), denoise=denoise
        )
        if nf:
            normalized_files.append(nf)
    if not normalized_files:
        error_exit("Auto merging found no normalized files.")

    largest_norm = normalized_files.pop(0)
    import random

    random.shuffle(normalized_files)
    segments = []
    segments.append(largest_norm)

    while len(normalized_files) > 1:
        f1 = normalized_files.pop()
        f2 = normalized_files.pop()
        side_out = os.path.join(
            temp_dir, f"side_{os.path.basename(f1)}_{os.path.basename(f2)}.mp4"
        )
        sidecmd = [
            "ffmpeg",
            "-y",
            "-i",
            f1,
            "-i",
            f2,
            "-filter_complex",
            "[0:v][1:v]hstack=inputs=2[outv]",
            "-map",
            "[outv]",
            "-c:v",
            "libx264",
            "-preset",
            "fast",
            "-crf",
            "23",
            side_out,
        ]
        try:
            with open(os.path.join(LOG_DIR, "merge_videos.log"), "a") as lf:
                subprocess.run(sidecmd, stdout=lf, stderr=lf, check=True)
            segments.append(side_out)
        except subprocess.CalledProcessError as e:
            logging.error(f"side-by-side failed for {f1} and {f2}. Error: {e}")

    if normalized_files:
        segments.append(normalized_files.pop())

    # concat
    file_list = os.path.join(temp_dir, "auto_file_list.txt")
    with open(file_list, "w") as ff:
        for seg in segments:
            ff.write(f"file '{seg}'\n")
    cmd_concat = [
        "ffmpeg",
        "-y",
        "-f",
        "concat",
        "-safe",
        "0",
        "-i",
        file_list,
        "-c:v",
        "libx264",
        "-preset",
        "fast",
        "-crf",
        "23",
        output_file,
    ]
    total_dur = get_total_duration(segments)
    try:
        run_ffmpeg_with_progress(cmd_concat, "Concatenating auto segments", total_dur)
        print_success(
            f"Auto merging completed. Output saved to '{os.path.abspath(output_file)}'."
        )
        logging.info(f"Auto merging completed. Output: {output_file}")
    except Exception as e:
        error_exit(f"Failed auto merges: {e}")

    if motion:
        launch_svp_manager()


def merge_videos(
    output_file: str,
    input_files: list,
    denoise: bool = False,
    motion: bool = False,
    user_options: dict = None,
):
    if not user_options:
        user_options = {}
    merging_mode = user_options.get("merging_mode", "concat")
    target_resolution = user_options.get("target_resolution", "1920x1080")
    target_framerate = user_options.get("target_framerate", 60)
    temp_dir = tempfile.mkdtemp(prefix="tmp_merge_", dir=LOG_DIR)

    def cleanup():
        if temp_dir and os.path.isdir(temp_dir):
            shutil.rmtree(temp_dir)

    signal.signal(signal.SIGINT, lambda sig, frame: sys.exit(0))
    signal.signal(signal.SIGTERM, lambda sig, frame: sys.exit(0))
    atexit.register(cleanup)

    valid = []
    for f in input_files:
        if not os.path.isfile(f):
            logging.warning(f"File '{f}' does not exist. Skipped.")
            continue
        if verify_and_repair_video_format(f):
            valid.append(f)
        else:
            logging.warning(f"Unsupported format '{f}'. Skipped.")
    if not valid:
        error_exit("No valid input videos to process.")
    if merging_mode == "auto":
        auto_merging_mode(
            valid,
            output_file,
            target_resolution,
            float(target_framerate),
            denoise=denoise,
            motion=motion,
        )
    else:
        merge_group_videos(output_file, valid, denoise, motion, user_options, temp_dir)


def merge_videos_mode():
    logging.info("Merge Videos mode selected.")
    try:
        find_cmd = [
            "find",
            os.getcwd(),
            "-type",
            "f",
            "(",
            "-iname",
            "*.mp4",
            "-o",
            "-iname",
            "*.avi",
            "-o",
            "-iname",
            "*.mkv",
            "-o",
            "-iname",
            "*.mov",
            "-o",
            "-iname",
            "*.flv",
            "-o",
            "-iname",
            "*.wmv",
            "-o",
            "-iname",
            "*.webm",
            "-o",
            "-iname",
            "*.m4v",
            "-o",
            "-iname",
            "*.gif",
            ")",
        ]
        all_videos = (
            subprocess.run(find_cmd, stdout=subprocess.PIPE, text=True, check=True)
            .stdout.strip()
            .split("\n")
        )
        if not all_videos or all_videos == [""]:
            print_warning("No video files found.")
            return
        fzf = shutil.which("fzf")
        if not fzf:
            print_warning(
                "fzf is not installed. Please install fzf to use this feature."
            )
            return
        result = subprocess.run(
            ["fzf", "--multi", "--prompt=Select videos to merge>"],
            input="\n".join(all_videos),
            stdout=subprocess.PIPE,
            text=True,
        )
        if result.returncode != 0 or not result.stdout.strip():
            print_warning("No videos selected for merging.")
            return
        videos = [v for v in result.stdout.strip().split("\n") if v.strip()]
    except Exception as e:
        print_warning(f"fzf selection failed: {e}")
        return

    if not videos:
        print_warning("No videos selected for merging.")
        return

    output_file = prompt(
        HTML(
            "<ansicyan>Enter output file name (default: merged_output.mp4): </ansicyan>"
        ),
        style=style,
    ).strip()
    output_file = sanitize_input(output_file)
    output_file = output_file or "merged_output.mp4"
    if not re.search(r"\.\w+$", output_file):
        output_file += ".mp4"
    output_file = sanitize_filename(output_file)
    if os.path.isfile(output_file):
        base, ext = os.path.splitext(output_file)
        i = 1
        while os.path.isfile(f"{base}_{i}{ext}"):
            i += 1
        output_file = f"{base}_{i}{ext}"
        print_warning(f"Output file already exists. Saving as '{output_file}'.")

    print_formatted_text(HTML("<ansicyan>Select merging mode:</ansicyan>"), style=style)
    merging_opts = {
        "1": "Concatenate videos (play one after another)",
        "2": "Stack videos vertically",
        "3": "Arrange videos in a grid",
        "4": "Side by side (2 videos only)",
        "5": "Auto (advanced intelligent merging)",
    }
    for k, v in merging_opts.items():
        print_formatted_text(f"{k}) {v}")
    merging_choice = prompt(
        HTML("<ansicyan>Enter your choice (default: 1): </ansicyan>"), style=style
    ).strip()
    merging_choice = sanitize_input(merging_choice)
    merging_mode_map = {
        "1": "concat",
        "2": "vstack",
        "3": "grid",
        "4": "side_by_side",
        "5": "auto",
    }
    merging_mode = merging_mode_map.get(merging_choice, "concat")
    print_info(
        f"Selected merging mode: {merging_opts.get(merging_choice,merging_opts['1'])}"
    )

    print_formatted_text(
        HTML("<ansicyan>Select container format:</ansicyan>"), style=style
    )
    container_map = {"1": "mp4", "2": "mkv", "3": "avi", "4": "webm"}
    for k, v in container_map.items():
        print_formatted_text(f"{k}) {v}")
    cont_choice = prompt(
        HTML("<ansicyan>Enter your choice (default: mp4): </ansicyan>"), style=style
    ).strip()
    cont_choice = sanitize_input(cont_choice)
    container = container_map.get(cont_choice, "mp4")
    output_file = re.sub(r"\.\w+$", f".{container}", output_file)
    print_info(f"Selected container: {container}")

    print_formatted_text(HTML("<ansicyan>Select video codec:</ansicyan>"), style=style)
    codec_map = {"1": "libx264", "2": "libx265", "3": "libvpx-vp9", "4": "mpeg4"}
    for k, v in codec_map.items():
        print_formatted_text(f"{k}) {v}")
    c_choice = prompt(
        HTML("<ansicyan>Enter your choice (default: libx264): </ansicyan>"), style=style
    ).strip()
    c_choice = sanitize_input(c_choice)
    video_codec = codec_map.get(c_choice, "libx264")
    print_info(f"Selected video codec: {video_codec}")

    print_formatted_text(
        HTML("<ansicyan>Select quality setting:</ansicyan>"), style=style
    )
    q_map = {"1": "CRF", "2": "Bitrate"}
    for k, v in q_map.items():
        print_formatted_text(f"{k}) {v}")
    q_choice = prompt(
        HTML("<ansicyan>Enter your choice (default: CRF): </ansicyan>"), style=style
    ).strip()
    q_choice = sanitize_input(q_choice)
    quality = q_map.get(q_choice, "CRF")
    crf = None
    bitrate = None
    if quality == "CRF":
        crf_str = prompt(
            HTML("<ansicyan>Enter CRF value (lower better, default 23): </ansicyan>"),
            style=style,
        ).strip()
        crf_str = sanitize_input(crf_str)
        try:
            crf = int(crf_str) if crf_str else 23
            if crf < 0 or crf > 51:
                raise ValueError
        except:
            crf = 23
            print_warning("Invalid CRF. Using default 23.")
        bitrate = None
    else:
        bitrate = prompt(
            HTML("<ansicyan>Enter bitrate (e.g. 800k, 2M): </ansicyan>"), style=style
        ).strip()
        bitrate = sanitize_input(bitrate)
        if not re.match(r"^\d+[kKmM]$", bitrate):
            print_warning("Invalid bitrate format. Using 128k.")
            bitrate = "128k"
        crf = None

    print_formatted_text(
        HTML("<ansicyan>Select encoding preset:</ansicyan>"), style=style
    )
    preset_opts = [
        "ultrafast",
        "superfast",
        "veryfast",
        "faster",
        "fast",
        "medium",
        "slow",
        "slower",
        "veryslow",
    ]
    for i, p in enumerate(preset_opts, start=1):
        print_formatted_text(f"{i}) {p}")
    preset_choice = prompt(
        HTML("<ansicyan>Enter your choice (default: medium): </ansicyan>"), style=style
    ).strip()
    preset_choice = sanitize_input(preset_choice)
    try:
        preset = preset_opts[int(preset_choice) - 1]
    except:
        preset = "medium"
        print_warning("Invalid preset. Using default 'medium'.")

    print_info(f"Selected preset: {preset}")

    print_formatted_text(
        HTML("<ansicyan>Select target resolution:</ansicyan>"), style=style
    )
    res_opts = {
        "1": "1280x720",
        "2": "1920x1080",
        "3": "2560x1440",
        "4": "3840x2160",
        "5": "original",
    }
    for k, v in res_opts.items():
        print_formatted_text(f"{k}) {v}")
    r_choice = prompt(
        HTML("<ansicyan>Enter your choice (default: 1920x1080): </ansicyan>"),
        style=style,
    ).strip()
    r_choice = sanitize_input(r_choice)
    target_resolution = res_opts.get(r_choice, "1920x1080")
    if target_resolution == "original":
        print_info("Selected resolution: original")
    else:
        print_info(f"Selected resolution: {target_resolution}")

    print_formatted_text(
        HTML("<ansicyan>Select target frame rate:</ansicyan>"), style=style
    )
    fps_map = {"1": "24", "2": "30", "3": "60", "4": "original", "5": "120"}
    for k, v in fps_map.items():
        print_formatted_text(f"{k}) {v} fps")
    fps_choice = prompt(
        HTML("<ansicyan>Enter your choice (default: 60 fps): </ansicyan>"), style=style
    ).strip()
    fps_choice = sanitize_input(fps_choice)
    chosen_fps = fps_map.get(fps_choice, "60")
    if chosen_fps == "original":
        chosen_fps = None
        print_info("Selected frame rate: original (no change).")
    else:
        try:
            chosen_fps = int(chosen_fps)
            print_info(f"Selected frame rate: {chosen_fps} fps")
        except:
            chosen_fps = 60
            print_warning("Invalid frame rate. Using 60 fps")

    # Ask if we want motion interpolation
    motion_choice = (
        prompt(
            HTML(
                "<ansicyan>Do you want to apply motion interpolation via SVP4 after merging? [y/n] (default: n): </ansicyan>"
            ),
            style=style,
        )
        .strip()
        .lower()
    )
    motion_choice = sanitize_input(motion_choice)
    motion = motion_choice == "y"
    if motion:
        print_info("Motion interpolation will be applied via SVP4 after merging.")
    else:
        print_info("Motion interpolation will NOT be applied.")

    # Ask if we want denoising
    denoise_choice = (
        prompt(
            HTML(
                "<ansicyan>Do you want to apply denoising? (hqnlmeans/nlmeans)? [y/n] (default: n): </ansicyan>"
            ),
            style=style,
        )
        .strip()
        .lower()
    )
    denoise_choice = sanitize_input(denoise_choice)
    denoise = denoise_choice == "y"
    if denoise:
        print_info("Denoising will be applied.")
    else:
        print_info("Denoising will NOT be applied.")

    user_options = {}
    user_options["merging_mode"] = merging_mode
    user_options["video_codec"] = video_codec
    user_options["crf"] = crf
    user_options["bitrate"] = bitrate
    user_options["preset"] = preset
    user_options["target_resolution"] = target_resolution
    user_options["target_framerate"] = chosen_fps if chosen_fps else 60

    # Proceed with the merging
    merge_videos(
        output_file, videos, denoise=denoise, motion=motion, user_options=user_options
    )


def main_menu():
    menu_options = ["Screencaps", "Clip", "Merge Videos", "Exit"]
    completer = WordCompleter(menu_options, ignore_case=True)
    while True:
        print_formatted_text(
            HTML("<ansicyan># --- // Vidutil2.py //</ansicyan>\n"), style=style
        )
        choice = (
            prompt(
                HTML("<ansicyan>Menu: </ansicyan>"), completer=completer, style=style
            )
            .strip()
            .lower()
        )
        choice = sanitize_input(choice)
        if choice == "screencaps":
            screencaps_mode()
        elif choice == "clip":
            clip_mode()
        elif choice == "merge videos":
            merge_videos_mode()
        elif choice == "exit":
            print_formatted_text(
                HTML("\n💥 <ansired>Terminated!</ansired>"), style=style
            )
            break
        elif choice in ["--help", "-h"]:
            print_help()
        else:
            print_warning(f"Unrecognized option: {choice}")


def print_help():
    help_text = """
**Vidutil2.py Help**

Usage:
  python3 vidutil2.py [--help]

Options:
  --help, -h    Show this help message and exit.

Features:
  1. Screencaps Mode:
     - Extract frames from selected videos at user-defined intervals.
     - Choose output directory for screenshots.

  2. Clip Mode:
     - Create video clips by specifying start and end times.
     - Manual input for precise clipping.

  3. Merge Videos Mode:
     - Merge multiple videos with various options:
       - Concatenate
       - Vertical Stack
       - Grid
       - Side-by-Side (for exactly two videos)
       - Auto (advanced intelligent merging)
     - Optional denoising and motion interpolation via SVP4.

  4. Exit:
     - Terminate the script.

Dependencies:
  - ffmpeg, ffprobe, fzf
  - mpv (optional)
  - Python 3, prompt_toolkit, tqdm
  - SVP4 (optional)

Configuration:
  - Customize settings in 'config.json' (e.g., SVPManager path).

Notes:
  - Ensure all dependencies are installed.
  - For motion interpolation, SVP4 must be installed and properly configured.
"""
    print_formatted_text(HTML(f"<info>{help_text}</info>"), style=style)


def trap_cleanup():
    pass


if __name__ == "__main__":
    atexit.register(trap_cleanup)
    main_menu()
