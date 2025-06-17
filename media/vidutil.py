#!/usr/bin/env python3
# File: vidutil.py
# Author: 4ndr0666
# Purpose: Video utility for merging, clipping, and screen capturing videos.

# ========================== // Vidutil //

import os
import sys
import subprocess
import shutil
import tempfile
import logging
import re
import signal
import atexit
import random
from prompt_toolkit import prompt
from prompt_toolkit.completion import WordCompleter
from prompt_toolkit.formatted_text import HTML
from prompt_toolkit.shortcuts import print_formatted_text
from prompt_toolkit.styles import Style
from tqdm import tqdm

# --- // Constants:
DATA_HOME = os.environ.get(
    "XDG_DATA_HOME", os.path.join(os.environ["HOME"], ".local", "share")
)
DATA_HOME = os.path.join(DATA_HOME, "vidutil")
LOG_DIR = os.path.join(DATA_HOME, "logs")
TEMP_DIR = os.path.join(DATA_HOME, "tmp")
os.makedirs(LOG_DIR, exist_ok=True)
os.makedirs(TEMP_DIR, exist_ok=True)

# --- // Colors and Styles:
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

# --- // Logging:
logging.basicConfig(
    filename=os.path.join(LOG_DIR, "vidutil.log"),
    level=logging.INFO,
    format="[%(asctime)s] %(levelname)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)


# --- // Input Sanitization Function
def sanitize_input(user_input):
    if user_input is None:
        return ""
    return re.sub(r"[^a-zA-Z0-9_ ./:-]", "", user_input)


# --- // Error Handler:
def error_exit(message):
    logging.error(message)
    print_formatted_text(HTML(f"<ansired>Error:</ansired> {message}"), style=style)
    sys.exit(1)


def print_warning(message):
    print_formatted_text(HTML(f"<warning>{message}</warning>"), style=style)


def print_success(message):
    print_formatted_text(HTML(f"<success>{message}</success>"), style=style)


def print_info(message):
    print_formatted_text(HTML(f"<info>{message}</info>"), style=style)


# --- // Helper Function to Get Error Output Safely
def get_error_output(e):
    if hasattr(e, "stderr") and e.stderr:
        return e.stderr.strip()
    elif hasattr(e, "stdout") and e.stdout:
        return e.stdout.strip()
    else:
        return "No error output available."


# --- // Get Video Properties Function
def get_video_properties(file):
    try:
        result = subprocess.run(
            [
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
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=True,
        )
        return result.stdout
    except subprocess.CalledProcessError as e:
        logging.warning(
            f"Failed to get properties for '{file}'. Error: {get_error_output(e)}"
        )
        return None


# --- // Format Verification and Repair:
def verify_and_repair_video_format(video):
    if not re.search(
        r"\.(mp4|avi|mkv|mov|flv|wmv|webm|m4v|gif)$", video, re.IGNORECASE
    ):
        print_warning(f"Unsupported video format for '{video}'.")
        return False

    try:
        result = subprocess.run(
            ["ffprobe", video],
            stderr=subprocess.PIPE,
            stdout=subprocess.PIPE,
            text=True,
        )
        if "moov atom not found" in result.stderr:
            logging.warning(
                f"File '{video}' is missing 'moov' atom. Attempting to fix."
            )
            temp_fixed_file = os.path.join(TEMP_DIR, os.path.basename(video))
            subprocess.run(
                [
                    "ffmpeg",
                    "-y",
                    "-i",
                    video,
                    "-c",
                    "copy",
                    "-movflags",
                    "faststart",
                    temp_fixed_file,
                ],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=True,
            )
            shutil.move(temp_fixed_file, video)
            logging.info(f"Successfully fixed '{video}'.")
    except subprocess.CalledProcessError as e:
        logging.warning(f"Failed to fix '{video}'. Error: {get_error_output(e)}")
        return False

    return True


# --- // Clean:
def sanitize_filename(filename):
    return re.sub(r'[<>:"/\\|?*]', "", filename)


# --- // Run FFmpeg with Progress Bar
def run_ffmpeg_with_progress(cmd, description, total_duration):
    """
    Runs an ffmpeg command and displays a tqdm progress bar.

    Args:
        cmd (list): The ffmpeg command as a list.
        description (str): Description for the progress bar.
        total_duration (float): Total duration of the video in seconds.
    """
    process = subprocess.Popen(cmd, stderr=subprocess.PIPE, universal_newlines=True)
    pbar = tqdm(
        total=total_duration,
        desc=description,
        bar_format="{l_bar}{bar}| {n_fmt}/{total_fmt} sec",
        colour="cyan",
    )
    time_pattern = re.compile(r"time=(\d+):(\d+):(\d+\.\d+)")
    current_time = 0.0

    try:
        for line in process.stderr:
            match = time_pattern.search(line)
            if match:
                hours, minutes, seconds = match.groups()
                current_time = int(hours) * 3600 + int(minutes) * 60 + float(seconds)
                if current_time > pbar.n:
                    pbar.n = current_time
                    pbar.refresh()
    except Exception as e:
        logging.error(f"Error while parsing ffmpeg output: {e}")
    finally:
        process.wait()
        pbar.close()


# --- // Normalize Video Function
def normalize_video(
    file,
    temp_dir,
    target_resolution,
    target_framerate=None,
    codec="libx264",
    crf=23,
    preset="medium",
    tune=None,
    denoise=False,
    motion_interpolation=False,
):
    if not verify_and_repair_video_format(file):
        logging.warning(f"Unsupported video format for '{file}'. Skipping.")
        return None

    properties = get_video_properties(file)
    if properties is None:
        logging.warning(
            f"Failed to get properties for '{file}'. Skipping normalization."
        )
        return None

    width_match = re.search(r"^width=(\d+)", properties, re.MULTILINE)
    height_match = re.search(r"^height=(\d+)", properties, re.MULTILINE)
    r_frame_rate_match = re.search(
        r"^r_frame_rate=(\d+)/(\d+)", properties, re.MULTILINE
    )

    if not width_match or not height_match or not r_frame_rate_match:
        logging.warning(f"Incomplete properties for '{file}'. Skipping.")
        return None

    width = int(width_match.group(1))
    height = int(height_match.group(1))
    r_frame_rate_num = int(r_frame_rate_match.group(1))
    r_frame_rate_den = int(r_frame_rate_match.group(2))
    frame_rate_decimal = r_frame_rate_num / (r_frame_rate_den or 1)

    if target_framerate is None or frame_rate_decimal < target_framerate:
        logging.info(
            f"Using target frame rate: {target_framerate if target_framerate else frame_rate_decimal} fps"
        )
    else:
        target_framerate = frame_rate_decimal
        logging.info(
            f"Source frame rate ({frame_rate_decimal} fps) is higher than target. Using source frame rate."
        )

    vf_chain_elements = []

    if target_resolution:
        target_width, target_height = map(int, target_resolution.split("x"))
        scale_filter = (
            f"scale={target_width}:{target_height}:force_original_aspect_ratio=decrease"
        )
        pad_filter = f"pad={target_width}:{target_height}:(ow-iw)/2:(oh-ih)/2"
        vf_chain_elements.extend([scale_filter, pad_filter])

    if denoise:
        denoise_filter = "hqdn3d"
        vf_chain_elements.append(denoise_filter)

    if motion_interpolation:
        interpolation_filter = (
            "minterpolate='fps=120:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1'"
        )
        vf_chain_elements.append(interpolation_filter)

    vf_chain = ",".join(vf_chain_elements) if vf_chain_elements else None

    pix_fmt = "yuv420p"

    base_filename = os.path.basename(os.path.splitext(file)[0])
    base_filename = sanitize_filename(base_filename)
    normalized_file = os.path.join(temp_dir, f"{base_filename}_normalized.mp4")

    cmd = ["ffmpeg", "-y", "-i", file, "-c:v", codec]

    if crf is not None:
        cmd.extend(["-crf", str(crf)])
    if preset:
        cmd.extend(["-preset", preset])
    if tune:
        cmd.extend(["-tune", tune])
    if target_framerate:
        cmd.extend(["-r", str(target_framerate)])
    if vf_chain:
        cmd.extend(["-vf", vf_chain])
    cmd.extend(["-pix_fmt", pix_fmt, "-c:a", "aac", "-b:a", "128k", normalized_file])

    total_duration = get_total_duration([file])
    if total_duration == 0.0:
        logging.warning(
            f"Could not determine duration for '{file}'. Proceeding without progress bar."
        )
        try:
            subprocess.run(
                cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True
            )
            logging.info(f"Normalized file saved: {normalized_file}")
            print_info(f"Normalized file saved: '{normalized_file}'.")
            return normalized_file
        except subprocess.CalledProcessError as e:
            logging.warning(
                f"Failed to normalize '{file}'. Skipping. Error: {get_error_output(e)}"
            )
            return None

    try:
        run_ffmpeg_with_progress(cmd, f"Normalizing '{base_filename}'", total_duration)
        logging.info(f"Normalized file saved: {normalized_file}")
        print_info(f"Normalized file saved: '{normalized_file}'.")
        return normalized_file
    except Exception as e:
        logging.warning(f"Failed to normalize '{file}'. Skipping. Error: {e}")
        return None


# --- // Get Total Duration Function
def get_total_duration(input_files):
    total_duration = 0.0
    for file in input_files:
        properties = get_video_properties(file)
        if properties:
            duration_match = re.search(
                r"^duration=(\d+\.\d+)", properties, re.MULTILINE
            )
            if duration_match:
                duration = float(duration_match.group(1))
                total_duration += duration
    return total_duration


# --- // Merge Videos Function
def merge_videos(output_file, input_files, denoise=False, user_options=None):
    temp_dir = None

    def cleanup_temp_dir():
        if temp_dir and os.path.isdir(temp_dir):
            shutil.rmtree(temp_dir)

    signal.signal(signal.SIGINT, lambda sig, frame: sys.exit(0))
    signal.signal(signal.SIGTERM, lambda sig, frame: sys.exit(0))
    atexit.register(cleanup_temp_dir)

    if not input_files:
        error_exit("No input files provided for merging.")

    valid_input_files = []
    for file in input_files:
        if not os.path.isfile(file):
            logging.warning(f"Input file '{file}' does not exist. Skipping.")
            continue
        if verify_and_repair_video_format(file):
            valid_input_files.append(file)
        else:
            logging.warning(f"Unsupported video format for '{file}'. Skipping.")

    if not valid_input_files:
        error_exit("No valid input files to process.")

    # Unpack user options
    container_format = user_options.get("container_format", "mp4")
    video_codec = user_options.get("video_codec", "libx264")
    crf = user_options.get("crf")
    bitrate = user_options.get("bitrate")
    preset = user_options.get("preset", "medium")
    target_resolution = user_options.get("target_resolution")
    target_framerate = user_options.get("target_framerate")
    motion_interpolation = user_options.get("motion_interpolation", False)
    merging_mode = user_options.get(
        "merging_mode", "concat"
    )  # Default to 'concat' if not specified

    if merging_mode == "auto":
        temp_dir = tempfile.mkdtemp(prefix="tmp_auto_", dir=LOG_DIR)
        logging.info("Starting auto merging mode...")
        segment_videos = []

        # Copy the list to avoid modifying the original
        files_to_process = valid_input_files.copy()

        while files_to_process:
            # Randomly decide the group size (1 to 4)
            group_size = random.randint(1, min(4, len(files_to_process)))
            group_files = []
            for _ in range(group_size):
                group_files.append(files_to_process.pop(0))

            # Randomly select a merging method
            merging_methods = ["concat", "vstack", "grid", "side_by_side"]
            method = random.choice(merging_methods)

            # Adjust method if group size doesn't fit
            if method == "side_by_side" and len(group_files) != 2:
                method = "concat"
            elif method == "vstack" and len(group_files) < 2:
                method = "concat"
            elif method == "grid" and len(group_files) < 2:
                method = "concat"

            logging.info(f"Merging {len(group_files)} videos using '{method}' method.")

            # Prepare user options for the group
            group_user_options = user_options.copy()
            group_user_options["merging_mode"] = method

            # Merge the group videos
            group_output = os.path.join(temp_dir, f"segment_{len(segment_videos)}.mp4")
            merge_group_videos(
                group_output, group_files, denoise, group_user_options, temp_dir
            )
            segment_videos.append(group_output)

        # Now concatenate all the segment videos
        if len(segment_videos) == 1:
            shutil.move(segment_videos[0], output_file)
            logging.info(
                f"Auto merging completed successfully. Output file: '{output_file}'."
            )
            print_success(
                f"Auto merging completed successfully. Output file: '{output_file}'."
            )
        else:
            file_list_path = os.path.join(temp_dir, "segment_file_list.txt")
            with open(file_list_path, "w") as f:
                for seg_file in segment_videos:
                    f.write(f"file '{seg_file}'\n")

            cmd = [
                "ffmpeg",
                "-y",
                "-f",
                "concat",
                "-safe",
                "0",
                "-i",
                file_list_path,
                "-c",
                "copy",
                output_file,
            ]

            total_duration = get_total_duration(segment_videos)
            description = "Concatenating segments"
            try:
                run_ffmpeg_with_progress(cmd, description, total_duration)
                logging.info(
                    f"Auto merging completed successfully. Output file: '{output_file}'."
                )
                print_success(
                    f"Auto merging completed successfully. Output file: '{output_file}'."
                )
            except Exception as e:
                error_exit(f"Failed to concatenate segments. Error: {e}")

    else:
        # For other merging modes, use the existing logic
        merge_group_videos(output_file, valid_input_files, denoise, user_options)


def merge_group_videos(output_file, input_files, denoise, user_options, temp_dir=None):
    # This function handles merging a group of videos using the specified merging mode
    merging_mode = user_options.get("merging_mode", "concat")
    container_format = user_options.get("container_format", "mp4")
    video_codec = user_options.get("video_codec", "libx264")
    crf = user_options.get("crf")
    bitrate = user_options.get("bitrate")
    preset = user_options.get("preset", "medium")
    target_resolution = user_options.get("target_resolution")
    target_framerate = user_options.get("target_framerate")
    motion_interpolation = user_options.get("motion_interpolation", False)

    if temp_dir is None:
        temp_dir = tempfile.mkdtemp(prefix="tmp_merge_", dir=LOG_DIR)
        atexit.register(lambda: shutil.rmtree(temp_dir))

    if merging_mode == "concat":
        logging.info("Starting video normalization for concatenation...")
        normalized_files = []
        for input_file in input_files:
            normalized_file = normalize_video(
                input_file,
                temp_dir,
                target_resolution=target_resolution,
                target_framerate=target_framerate,
                codec=video_codec,
                crf=crf,
                preset=preset,
                denoise=denoise,
                motion_interpolation=motion_interpolation,
            )
            if normalized_file:
                normalized_files.append(normalized_file)

        if not normalized_files:
            error_exit("No valid videos to merge after normalization.")

        file_list_path = os.path.join(temp_dir, "file_list.txt")
        with open(file_list_path, "w") as f:
            for norm_file in normalized_files:
                f.write(f"file '{norm_file}'\n")

        cmd = [
            "ffmpeg",
            "-y",
            "-f",
            "concat",
            "-safe",
            "0",
            "-i",
            file_list_path,
            "-c:v",
            video_codec,
            "-preset",
            preset,
        ]

        if crf is not None:
            cmd.extend(["-crf", str(crf)])
        elif bitrate:
            cmd.extend(["-b:v", bitrate])

        cmd.extend(["-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "128k", output_file])

        total_duration = get_total_duration(normalized_files)
        description = "Concatenating videos"
        try:
            run_ffmpeg_with_progress(cmd, description, total_duration)
            logging.info(
                f"Video concatenation completed successfully. Output file: '{output_file}'."
            )
            print_success(
                f"Video concatenation completed successfully. Output file: '{output_file}'."
            )
        except Exception as e:
            error_exit(f"Failed to concatenate videos. Error: {e}")

    elif merging_mode == "vstack":
        logging.info("Starting video normalization for vertical stacking...")
        normalized_files = []
        for input_file in input_files:
            normalized_file = normalize_video(
                input_file,
                temp_dir,
                target_resolution=target_resolution,
                target_framerate=target_framerate,
                codec=video_codec,
                crf=crf,
                preset=preset,
                denoise=denoise,
                motion_interpolation=motion_interpolation,
            )
            if normalized_file:
                normalized_files.append(normalized_file)

        if len(normalized_files) < 2:
            error_exit("Not enough valid videos for vertical stacking.")

        inputs = []
        filters = ""
        for idx, norm_file in enumerate(normalized_files):
            inputs.extend(["-i", norm_file])
            filters += f"[{idx}:v] setpts=PTS-STARTPTS [v{idx}]; "

        vstack_inputs = "".join([f"[v{idx}]" for idx in range(len(normalized_files))])
        filters += f"{vstack_inputs} vstack=inputs={len(normalized_files)} [outv]"

        cmd = [
            "ffmpeg",
            "-y",
            *inputs,
            "-filter_complex",
            filters,
            "-map",
            "[outv]",
            "-c:v",
            video_codec,
            "-preset",
            preset,
        ]

        if crf is not None:
            cmd.extend(["-crf", str(crf)])
        elif bitrate:
            cmd.extend(["-b:v", bitrate])

        cmd.extend(["-pix_fmt", "yuv420p", output_file])

        total_duration = get_total_duration(normalized_files)
        description = "Vertically stacking videos"
        try:
            run_ffmpeg_with_progress(cmd, description, total_duration)
            logging.info(
                f"Vertical stacking completed successfully. Output file: '{output_file}'."
            )
            print_success(
                f"Vertical stacking completed successfully. Output file: '{output_file}'."
            )
        except Exception as e:
            error_exit(f"Failed to vertically stack videos. Error: {e}")

    elif merging_mode == "grid":
        logging.info("Starting video normalization for grid merging...")
        normalized_files = []
        for input_file in input_files:
            normalized_file = normalize_video(
                input_file,
                temp_dir,
                target_resolution=None,  # We will scale in filter_complex
                target_framerate=target_framerate,
                codec=video_codec,
                crf=crf,
                preset=preset,
                denoise=denoise,
                motion_interpolation=motion_interpolation,
            )
            if normalized_file:
                normalized_files.append(normalized_file)

        if len(normalized_files) < 2:
            error_exit("Not enough valid videos for grid merging.")

        num_inputs = len(normalized_files)

        target_width, target_height = (1920, 1080)  # Default resolution
        if target_resolution:
            target_width, target_height = map(int, target_resolution.split("x"))
        target_aspect_ratio = target_width / target_height

        # Find grid dimensions that best fit the target aspect ratio
        best_grid = None
        min_aspect_ratio_diff = None
        for cols in range(1, num_inputs + 1):
            rows = (num_inputs + cols - 1) // cols
            grid_width = cols * 1  # Each cell is considered to have width 1
            grid_height = rows * 1  # Each cell is considered to have height 1
            grid_aspect_ratio = grid_width / grid_height
            aspect_ratio_diff = abs(grid_aspect_ratio - target_aspect_ratio)
            if (
                min_aspect_ratio_diff is None
                or aspect_ratio_diff < min_aspect_ratio_diff
            ):
                min_aspect_ratio_diff = aspect_ratio_diff
                best_grid = (cols, rows)
        grid_cols, grid_rows = best_grid

        width = target_width // grid_cols
        height = target_height // grid_rows

        inputs = []
        filters = ""
        for idx, norm_file in enumerate(normalized_files):
            inputs.extend(["-i", norm_file])
            filters += f"[{idx}:v] setpts=PTS-STARTPTS, scale={width}:{height}:force_original_aspect_ratio=decrease,pad={width}:{height}:(ow-iw)/2:(oh-ih)/2 [v{idx}]; "

        # Create layout string for xstack
        xstack_inputs = "".join([f"[v{idx}]" for idx in range(num_inputs)])
        filters += f"{xstack_inputs} xstack=inputs={num_inputs}:layout="

        layout_positions = []
        for i in range(num_inputs):
            x_idx = i % grid_cols
            y_idx = i // grid_cols
            x_pos = x_idx * width
            y_pos = y_idx * height
            layout_positions.append(f"{x_pos}_{y_pos}")
        layout_str = "|".join(layout_positions)
        filters += f"{layout_str}[outv]"

        cmd = [
            "ffmpeg",
            "-y",
            *inputs,
            "-filter_complex",
            filters,
            "-map",
            "[outv]",
            "-c:v",
            video_codec,
            "-preset",
            preset,
        ]

        if crf is not None:
            cmd.extend(["-crf", str(crf)])
        elif bitrate:
            cmd.extend(["-b:v", bitrate])

        cmd.extend(["-pix_fmt", "yuv420p", output_file])

        total_duration = max(get_total_duration(normalized_files), 0)
        description = "Grid merging videos"
        try:
            run_ffmpeg_with_progress(cmd, description, total_duration)
            logging.info(
                f"Grid merging completed successfully. Output file: '{output_file}'."
            )
            print_success(
                f"Grid merging completed successfully. Output file: '{output_file}'."
            )
        except Exception as e:
            error_exit(f"Failed to merge videos in a grid. Error: {e}")

    elif merging_mode == "side_by_side":
        logging.info("Starting video normalization for side-by-side merging...")
        normalized_files = []
        for input_file in input_files:
            normalized_file = normalize_video(
                input_file,
                temp_dir,
                target_resolution=None,
                target_framerate=target_framerate,
                codec=video_codec,
                crf=crf,
                preset=preset,
                denoise=denoise,
                motion_interpolation=motion_interpolation,
            )
            if normalized_file:
                normalized_files.append(normalized_file)

        if len(normalized_files) != 2:
            error_exit("Side-by-side merging requires exactly 2 videos.")

        inputs = []
        filters = ""
        for idx, norm_file in enumerate(normalized_files):
            inputs.extend(["-i", norm_file])

        # Determine the maximum height to scale videos proportionally
        heights = []
        for norm_file in normalized_files:
            properties = get_video_properties(norm_file)
            if properties:
                height_match = re.search(r"^height=(\d+)", properties, re.MULTILINE)
                if height_match:
                    heights.append(int(height_match.group(1)))
        max_height = max(heights) if heights else None

        if max_height:
            for idx in range(2):
                filters += (
                    f"[{idx}:v] setpts=PTS-STARTPTS, scale=-1:{max_height} [v{idx}]; "
                )
        else:
            for idx in range(2):
                filters += f"[{idx}:v] setpts=PTS-STARTPTS [v{idx}]; "

        filters += "[v0][v1] hstack=inputs=2 [outv]"

        cmd = [
            "ffmpeg",
            "-y",
            *inputs,
            "-filter_complex",
            filters,
            "-map",
            "[outv]",
            "-c:v",
            video_codec,
            "-preset",
            preset,
        ]

        if crf is not None:
            cmd.extend(["-crf", str(crf)])
        elif bitrate:
            cmd.extend(["-b:v", bitrate])

        cmd.extend(["-pix_fmt", "yuv420p", output_file])

        total_duration = max(get_total_duration(normalized_files), 0)
        description = "Side-by-side merging videos"
        try:
            run_ffmpeg_with_progress(cmd, description, total_duration)
            logging.info(
                f"Side-by-side merging completed successfully. Output file: '{output_file}'."
            )
            print_success(
                f"Side-by-side merging completed successfully. Output file: '{output_file}'."
            )
        except Exception as e:
            error_exit(f"Failed to merge videos side by side. Error: {e}")

    elif merging_mode == "single":
        logging.info("Only one valid video provided. Copying to output file.")
        try:
            shutil.copy(input_files[0], output_file)
            logging.info(f"Single video copied successfully to '{output_file}'.")
            print_success(f"Single video copied successfully to '{output_file}'.")
        except Exception as e:
            error_exit(f"Failed to copy video to output file. Error: {e}")
    else:
        error_exit(f"Unknown merging mode '{merging_mode}'.")


# --- // Merge Videos Mode Function
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
            print_warning("No video files found in the current directory.")
            return

        result = subprocess.run(
            ["fzf", "--multi", "--prompt=Select videos to merge>"],
            input="\n".join(all_videos),
            stdout=subprocess.PIPE,
            text=True,
        )

        if result.returncode != 0 or not result.stdout:
            print_warning("No videos selected for merging.")
            return

        videos = result.stdout.strip().split("\n")

    except Exception as e:
        print_warning(f"fzf selection failed. Error: {e}")
        return

    # Remove any empty strings resulting from split
    videos = [video for video in videos if video.strip()]

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
        logging.warning(f"Output file already exists. Saving as '{output_file}'.")
        print_warning(f"Output file already exists. Saving as '{output_file}'.")

    # Collect user options
    user_options = {}

    # Select merging mode
    print_formatted_text(HTML("<ansicyan>Select merging mode:</ansicyan>"), style=style)
    merging_options = {
        "1": "Concatenate videos (play one after another)",
        "2": "Stack videos vertically",
        "3": "Arrange videos in a grid",
        "4": "Side by side (only for two videos)",
        "5": "Auto",
    }
    for key, value in merging_options.items():
        print_formatted_text(f"{key}) {value}")
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
    user_options["merging_mode"] = merging_mode
    print_info(
        f"Selected merging mode: {merging_options.get(merging_choice, merging_options['1'])}"
    )

    # The rest of the code remains the same as previous merge_videos_mode function,
    # collecting container format, video codec, quality settings, etc.

    # Select container format
    print_formatted_text(
        HTML("<ansicyan>Select container format:</ansicyan>"), style=style
    )
    container_options = {"1": "mp4", "2": "mkv", "3": "avi", "4": "webm"}
    for key, value in container_options.items():
        print_formatted_text(f"{key}) {value}")
    container_choice = prompt(
        HTML("<ansicyan>Enter your choice (default: mp4): </ansicyan>"), style=style
    ).strip()
    container_choice = sanitize_input(container_choice)
    container_format = container_options.get(container_choice, "mp4")
    output_file = re.sub(r"\.\w+$", f".{container_format}", output_file)
    user_options["container_format"] = container_format
    print_info(f"Selected container format: {container_format}")

    # Select video codec
    print_formatted_text(HTML("<ansicyan>Select video codec:</ansicyan>"), style=style)
    codec_options = {"1": "libx264", "2": "libx265", "3": "libvpx-vp9", "4": "mpeg4"}
    for key, value in codec_options.items():
        print_formatted_text(f"{key}) {value}")
    codec_choice = prompt(
        HTML("<ansicyan>Enter your choice (default: libx264): </ansicyan>"), style=style
    ).strip()
    codec_choice = sanitize_input(codec_choice)
    video_codec = codec_options.get(codec_choice, "libx264")
    user_options["video_codec"] = video_codec
    print_info(f"Selected video codec: {video_codec}")

    # Select CRF or Bitrate
    print_formatted_text(
        HTML("<ansicyan>Select quality setting:</ansicyan>"), style=style
    )
    quality_options = {"1": "CRF", "2": "Bitrate"}
    for key, value in quality_options.items():
        print_formatted_text(f"{key}) {value}")
    quality_choice = prompt(
        HTML("<ansicyan>Enter your choice (default: CRF): </ansicyan>"), style=style
    ).strip()
    quality_choice = sanitize_input(quality_choice)
    quality_setting = quality_options.get(quality_choice, "CRF")

    if quality_setting == "CRF":
        crf = prompt(
            HTML(
                "<ansicyan>Enter CRF value (lower is better quality, default 23): </ansicyan>"
            ),
            style=style,
        ).strip()
        crf = sanitize_input(crf)
        try:
            crf = int(crf) if crf else 23
            if not (0 <= crf <= 51):
                raise ValueError
        except ValueError:
            crf = 23
            print_warning("Invalid CRF value. Using default 23.")
        bitrate = None
    else:
        bitrate = prompt(
            HTML("<ansicyan>Enter bitrate (e.g., 800k, 2M): </ansicyan>"), style=style
        ).strip()
        bitrate = sanitize_input(bitrate)
        if not re.match(r"^\d+[kKmM]$", bitrate):
            print_warning("Invalid bitrate format. Using default 128k.")
            bitrate = "128k"
        crf = None

    user_options["crf"] = crf
    user_options["bitrate"] = bitrate

    # Select encoding preset
    print_formatted_text(
        HTML("<ansicyan>Select encoding preset:</ansicyan>"), style=style
    )
    preset_options = [
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
    for idx, value in enumerate(preset_options, start=1):
        print_formatted_text(f"{idx}) {value}")
    preset_choice = prompt(
        HTML("<ansicyan>Enter your choice (default: medium): </ansicyan>"), style=style
    ).strip()
    preset_choice = sanitize_input(preset_choice)
    try:
        preset = preset_options[int(preset_choice) - 1]
    except (IndexError, ValueError):
        preset = "medium"
        print_warning("Invalid preset choice. Using default 'medium'.")
    user_options["preset"] = preset
    print_info(f"Selected preset: {preset}")

    # Select target resolution
    print_formatted_text(
        HTML("<ansicyan>Select target resolution:</ansicyan>"), style=style
    )
    resolution_options = {
        "1": "1280x720",
        "2": "1920x1080",
        "3": "2560x1440",
        "4": "3840x2160",
        "5": "Original",
    }
    for key, value in resolution_options.items():
        print_formatted_text(f"{key}) {value}")
    resolution_choice = prompt(
        HTML("<ansicyan>Enter your choice (default: 1920x1080): </ansicyan>"),
        style=style,
    ).strip()
    resolution_choice = sanitize_input(resolution_choice)
    target_resolution = resolution_options.get(resolution_choice, "1920x1080")
    if target_resolution == "Original":
        target_resolution = None
        print_info("Selected resolution: Original")
    else:
        print_info(f"Selected resolution: {target_resolution}")
    user_options["target_resolution"] = target_resolution

    # Select target frame rate
    print_formatted_text(
        HTML("<ansicyan>Select target frame rate:</ansicyan>"), style=style
    )
    options_fps = {"1": "24", "2": "30", "3": "60", "4": "Original", "5": "120"}
    for key, value in options_fps.items():
        print_formatted_text(f"{key}) {value} fps")
    fps_choice = prompt(
        HTML("<ansicyan>Enter your choice (default: 60 fps): </ansicyan>"), style=style
    ).strip()
    fps_choice = sanitize_input(fps_choice)
    target_framerate = options_fps.get(fps_choice, "60")
    if target_framerate == "Original":
        target_framerate = None
        print_info("Selected frame rate: Original")
    else:
        try:
            target_framerate = int(target_framerate)
            print_info(f"Selected frame rate: {target_framerate} fps")
        except ValueError:
            target_framerate = None
            print_warning("Invalid frame rate choice. Using default frame rate.")
    user_options["target_framerate"] = target_framerate

    # Check if motion interpolation is needed
    motion_interpolation = False
    if target_framerate == 120:
        motion_choice = (
            prompt(
                HTML(
                    "<ansicyan>Do you want to apply motion interpolation for smoother playback? (y/n): </ansicyan>"
                ),
                style=style,
            )
            .strip()
            .lower()
        )
        motion_choice = sanitize_input(motion_choice)
        motion_interpolation = motion_choice == "y"
        if motion_interpolation:
            print_info(
                "Motion interpolation will be applied to achieve smooth 120 fps playback."
            )
        else:
            print_info("Motion interpolation will not be applied.")
    user_options["motion_interpolation"] = motion_interpolation

    # Prompt for denoising
    denoise_choice = (
        prompt(
            HTML("<ansicyan>Do you want to apply denoising? (y/n): </ansicyan>"),
            style=style,
        )
        .strip()
        .lower()
    )
    denoise_choice = sanitize_input(denoise_choice)
    denoise = denoise_choice == "y"
    if denoise:
        print_info("Denoising will be applied to the videos.")
    else:
        print_info("Denoising will not be applied.")

    # Proceed to merge videos based on selected mode
    merge_videos(output_file, videos, denoise=denoise, user_options=user_options)


# --- // Screencaps Mode Function
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
            print_warning("No video files found in the current directory.")
            return

        result = subprocess.run(
            ["fzf", "--prompt=Select video for screencaps>"],
            input="\n".join(all_videos),
            stdout=subprocess.PIPE,
            text=True,
        )

        if result.returncode != 0 or not result.stdout:
            print_warning("No video selected. Returning to menu.")
            return

        source_video = result.stdout.strip()

    except Exception as e:
        print_warning(f"fzf selection failed. Error: {e}")
        return

    if not source_video:
        print_warning("No video selected. Returning to menu.")
        return

    interval = prompt(
        HTML("<ansicyan>Enter capture interval in seconds (e.g., 5): </ansicyan>"),
        style=style,
    ).strip()
    interval = sanitize_input(interval)
    interval = interval or "5"

    output_dir = prompt(
        HTML(
            "<ansicyan>Enter output directory for screenshots (default: ./screenshots): </ansicyan>"
        ),
        style=style,
    ).strip()
    output_dir = sanitize_input(output_dir)
    output_dir = output_dir or "./screenshots"
    os.makedirs(output_dir, exist_ok=True)

    logging.info(
        f"Starting screenshot extraction every {interval} seconds from '{source_video}'."
    )

    cmd = [
        "ffmpeg",
        "-y",
        "-i",
        source_video,
        "-vf",
        f"fps=1/{interval}",
        os.path.join(output_dir, "screenshot_%04d.png"),
    ]

    try:
        description = "Extracting screenshots"
        # Estimate total duration
        properties = get_video_properties(source_video)
        duration_match = (
            re.search(r"^duration=(\d+\.\d+)", properties, re.MULTILINE)
            if properties
            else None
        )
        if duration_match:
            duration = float(duration_match.group(1))
        else:
            duration = 60.0  # Default to 60 seconds if duration is unknown

        run_ffmpeg_with_progress(cmd, description, duration)
        logging.info(f"Screenshots saved to '{output_dir}'.")
        print_success(f"Screenshots saved to '{output_dir}'.")
    except Exception as e:
        error_exit(f"Failed to extract screenshots. Error: {e}")


# --- // Clip Mode Function
def clip_mode():
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

        result = subprocess.run(
            ["fzf", "--prompt=Select video to clip>"],
            input="\n".join(all_videos),
            stdout=subprocess.PIPE,
            text=True,
        )

        if result.returncode != 0 or not result.stdout:
            print_warning("No video selected. Returning to menu.")
            return

        source_video = result.stdout.strip()

    except Exception as e:
        print_warning(f"fzf selection failed. Error: {e}")
        return

    if not source_video:
        print_warning("No video selected. Returning to menu.")
        return

    start_time = prompt(
        HTML("<ansicyan>Enter start time (format: HH:MM:SS or seconds): </ansicyan>"),
        style=style,
    ).strip()
    start_time = sanitize_input(start_time)
    if not start_time:
        print_warning("Start time not provided. Aborting clip creation.")
        return

    duration = prompt(
        HTML(
            "<ansicyan>Enter duration of the clip (format: HH:MM:SS or seconds): </ansicyan>"
        ),
        style=style,
    ).strip()
    duration = sanitize_input(duration)
    if not duration:
        print_warning("Duration not provided. Aborting clip creation.")
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

    cmd = [
        "ffmpeg",
        "-y",
        "-ss",
        start_time,
        "-i",
        source_video,
        "-t",
        duration,
        "-c",
        "copy",
        output_file,
    ]

    try:
        description = f"Creating clip '{output_file}'"
        # Estimate duration
        properties = get_video_properties(source_video)
        duration_match = (
            re.search(r"^duration=(\d+\.\d+)", properties, re.MULTILINE)
            if properties
            else None
        )
        if duration_match:
            total_duration = float(duration_match.group(1))
        else:
            total_duration = 60.0  # Default to 60 seconds if duration is unknown

        run_ffmpeg_with_progress(cmd, description, total_duration)
        logging.info(f"Clip created successfully as '{output_file}'.")
        print_success(f"Clip created successfully as '{output_file}'.")
    except Exception as e:
        error_exit(f"Failed to create clip. Error: {e}")


# --- // Main Menu
def main_menu():
    menu_options = ["Screencaps", "Clip", "Merge Videos", "Exit"]
    completer = WordCompleter(menu_options, ignore_case=True)

    while True:
        print_formatted_text(
            HTML("<ansicyan># --- // Vidutil.py //</ansicyan>\n"), style=style
        )
        choice_input = prompt(
            HTML("<ansicyan>Menu: </ansicyan>"), completer=completer, style=style
        )
        if choice_input is None:
            print_warning("No input provided. Please try again.")
            continue
        choice = sanitize_input(choice_input).lower()
        if not choice:
            print_warning("No input provided. Please try again.")
            continue
        try:
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
            else:
                print_warning(f"Unrecognized option: {choice}")
        except KeyboardInterrupt:
            print_warning("Operation cancelled by user.")
            logging.info("Operation cancelled by user.")
        except Exception as e:
            logging.error(f"Error: {e}")
            print_warning(f"An error occurred: {e}")


# --- // Entry Point
if __name__ == "__main__":
    main_menu()
