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
from contextlib import contextmanager
from prompt_toolkit import prompt
from prompt_toolkit.completion import WordCompleter
from prompt_toolkit.formatted_text import HTML
from prompt_toolkit.shortcuts import print_formatted_text
from prompt_toolkit.styles import Style
from tqdm import tqdm

# --- // Constants:
DATA_HOME = os.environ.get('XDG_DATA_HOME', os.path.join(os.environ['HOME'], '.local', 'share'))
DATA_HOME = os.path.join(DATA_HOME, 'vidutil')
LOG_DIR = os.path.join(DATA_HOME, 'logs')
TEMP_DIR = os.path.join(DATA_HOME, 'tmp')
os.makedirs(LOG_DIR, exist_ok=True)
os.makedirs(TEMP_DIR, exist_ok=True)

# --- // Colors and Styles:
style = Style.from_dict({
    'completion-menu.completion': 'fg:#15FFFF bg:default',
    'completion-menu.completion.current': 'fg:#15FFFF bg:#333333',
    'ansicyan': '#15ffff',
    'ansired': '#A80D1B',
    'ansigreen': '#2ECC71',
    'ansiyellow': '#222221',
    'prompt': 'fg:#15FFFF bold',
    'menu': 'fg:#15FFFF',
    'menuitem': 'fg:#15FFFF',
    'warning': 'fg:#FF0000 bold',
    'success': 'fg:#00FF00 bold',
    'info': 'fg:#FFFF00',
})

# --- // Logging:
logging.basicConfig(
    filename=os.path.join(LOG_DIR, 'vidutil.log'),
    level=logging.INFO,
    format='[%(asctime)s] %(levelname)s: %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)

# --- // Input Sanitization Function
def sanitize_input(user_input):
    if user_input is None:
        return ''
    return re.sub(r'[^a-zA-Z0-9_ ./:-]', '', user_input)

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

# --- // Get Video Properties Function
def get_video_properties(file):
    try:
        result = subprocess.run(
            ['ffprobe', '-v', 'error', '-select_streams', 'v:0',
             '-show_entries', 'stream=codec_name,width,height,r_frame_rate,duration,bit_rate,pix_fmt',
             '-of', 'default=noprint_wrappers=1:nokey=0', file],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=True
        )
        return result.stdout
    except subprocess.CalledProcessError as e:
        logging.warning(f"Failed to get properties for '{file}'. Error: {e.stderr.strip()}")
        return None

# --- // Format Verification and Repair:
def verify_and_repair_video_format(video):
    if not re.search(r'\.(mp4|avi|mkv|mov|flv|wmv|webm|m4v|gif)$', video, re.IGNORECASE):
        print_warning(f"Unsupported video format for '{video}'.")
        return False

    try:
        result = subprocess.run(['ffprobe', video], stderr=subprocess.PIPE, text=True)
        if 'moov atom not found' in result.stderr:
            logging.warning(f"File '{video}' is missing 'moov' atom. Attempting to fix.")
            temp_fixed_file = os.path.join(TEMP_DIR, os.path.basename(video))
            subprocess.run(
                ['ffmpeg', '-y', '-i', video, '-c', 'copy', '-movflags', 'faststart', temp_fixed_file],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=True
            )
            shutil.move(temp_fixed_file, video)
            logging.info(f"Successfully fixed '{video}'.")
    except subprocess.CalledProcessError as e:
        logging.warning(f"Failed to fix '{video}'. Error: {e.stderr.strip()}")
        return False

    return True

# --- // Clean:
def sanitize_filename(filename):
    return re.sub(r'[<>:"/\\|?*]', '', filename)

# --- // Determine Merging Mode Function
def determine_merging_mode(input_files):
    num_videos = len(input_files)
    landscape_count = 0
    portrait_count = 0

    for file in input_files:
        if not verify_and_repair_video_format(file):
            continue
        properties = get_video_properties(file)
        if properties is None:
            continue

        width_match = re.search(r'^width=(\d+)', properties, re.MULTILINE)
        height_match = re.search(r'^height=(\d+)', properties, re.MULTILINE)

        if not width_match or not height_match:
            logging.warning(f"Could not determine dimensions of '{file}'. Skipping.")
            continue

        width = int(width_match.group(1))
        height = int(height_match.group(1))

        if height > 0:
            aspect_ratio = width / height
            if aspect_ratio >= 1.3:
                landscape_count += 1
            else:
                portrait_count += 1
        else:
            logging.warning(f"Invalid height for '{file}'. Skipping.")
            continue

    if num_videos == 1:
        return "single"
    elif landscape_count == num_videos:
        return "concat"
    elif portrait_count == num_videos:
        return "vstack"
    else:
        return "grid"

# --- // Get Total Duration Function
def get_total_duration(input_files):
    total_duration = 0.0
    for file in input_files:
        properties = get_video_properties(file)
        if properties:
            duration_match = re.search(r'^duration=(\d+\.\d+)', properties, re.MULTILINE)
            if duration_match:
                duration = float(duration_match.group(1))
                total_duration += duration
    return total_duration

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
    pbar = tqdm(total=total_duration, desc=description, bar_format='{l_bar}{bar}| {n_fmt}/{total_fmt} sec', colour='cyan')
    time_pattern = re.compile(r'time=(\d+):(\d+):(\d+\.\d+)')
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
def normalize_video(file, temp_dir, target_resolution, target_framerate=60.00, crf=15, preset='medium', tune='zerolatency', denoise=False):
    if not verify_and_repair_video_format(file):
        logging.warning(f"Unsupported video format for '{file}'. Skipping.")
        return None

    properties = get_video_properties(file)
    if properties is None:
        logging.warning(f"Failed to get properties for '{file}'. Skipping normalization.")
        return None

    width_match = re.search(r'^width=(\d+)', properties, re.MULTILINE)
    height_match = re.search(r'^height=(\d+)', properties, re.MULTILINE)
    r_frame_rate_match = re.search(r'^r_frame_rate=(\d+)/(\d+)', properties, re.MULTILINE)

    if not width_match or not height_match or not r_frame_rate_match:
        logging.warning(f"Incomplete properties for '{file}'. Skipping.")
        return None

    width = int(width_match.group(1))
    height = int(height_match.group(1))
    r_frame_rate_num = int(r_frame_rate_match.group(1))
    r_frame_rate_den = int(r_frame_rate_match.group(2))
    frame_rate_decimal = r_frame_rate_num / (r_frame_rate_den or 1)

    if frame_rate_decimal < target_framerate:
        logging.warning(f"Source frame rate ({frame_rate_decimal}) is lower than target ({target_framerate}). Using source frame rate.")
        target_framerate = frame_rate_decimal

    target_width, target_height = map(int, target_resolution.split('x'))

    vf_chain = f"scale={target_width}:{target_height}:force_original_aspect_ratio=decrease,pad={target_width}:{target_height}:(ow-iw)/2:(oh-ih)/2"
    
    # Add denoising filter if selected
    if denoise:
        vf_chain += f",vaguedenoiser=threshold=3:method=soft:nsteps=5"

    pix_fmt = 'yuv420p'

    base_filename = os.path.basename(os.path.splitext(file)[0])
    base_filename = sanitize_filename(base_filename)
    normalized_file = os.path.join(temp_dir, f"{base_filename}_normalized.mp4")

    cmd = [
        'ffmpeg', '-y', '-i', file,
        '-c:v', 'libx264', '-crf', str(crf), '-preset', preset, '-tune', tune,
        '-pix_fmt', pix_fmt, '-r', str(target_framerate),
        '-vf', vf_chain,
        '-profile:v', 'high', '-level', '4.0',
        '-c:a', 'aac', '-b:a', '128k',
        normalized_file
    ]

    total_duration = get_total_duration([file])
    if total_duration == 0.0:
        logging.warning(f"Could not determine duration for '{file}'. Proceeding without progress bar.")
        try:
            subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
            logging.info(f"Normalized file saved: {normalized_file}")
            return normalized_file
        except subprocess.CalledProcessError as e:
            logging.warning(f"Failed to normalize '{file}'. Skipping. Error: {e}")
            return None

    try:
        run_ffmpeg_with_progress(cmd, f"Normalizing '{base_filename}'", total_duration)
        logging.info(f"Normalized file saved: {normalized_file}")
        return normalized_file
    except Exception as e:
        logging.warning(f"Failed to normalize '{file}'. Skipping. Error: {e}")
        return None

# --- // Merge Videos Function
def merge_videos(output_file, input_files, denoise=False):
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

    print_formatted_text(HTML("<ansicyan>Select target resolution:</ansicyan>"), style=style)
    options = {"1": "1280x720", "2": "1920x1080", "3": "2560x1440", "4": "3840x2160"}
    for key, value in options.items():
        print_formatted_text(f"{key}) {value}")
    choice = prompt(HTML('<ansicyan>Enter your choice: </ansicyan>'), style=style).strip()
    choice = sanitize_input(choice)
    target_resolution = options.get(choice, "1920x1080")

    print_formatted_text(HTML("<ansicyan>Select target frame rate:</ansicyan>"), style=style)
    options_fps = {"1": "30", "2": "60", "3": "120"}
    for key, value in options_fps.items():
        print_formatted_text(f"{key}) {value} fps")
    choice = prompt(HTML('<ansicyan>Enter your choice: </ansicyan>'), style=style).strip()
    choice = sanitize_input(choice)
    try:
        target_framerate = int(options_fps.get(choice, "60"))
    except ValueError:
        print_warning("Invalid frame rate choice. Defaulting to 60 fps.")
        target_framerate = 60

    # New prompt for denoising
    denoise_choice = prompt(
        HTML('<ansicyan>Do you want to apply denoising? (y/n): </ansicyan>'),
        style=style
    ).strip().lower()
    denoise_choice = sanitize_input(denoise_choice)
    denoise = denoise_choice == 'y'

    merging_mode = determine_merging_mode(valid_input_files)

    if merging_mode == "concat":
        temp_dir = tempfile.mkdtemp(prefix="tmp_concat_", dir=LOG_DIR)
        logging.info("Starting video normalization for concatenation...")
        normalized_files = []
        for input_file in valid_input_files:
            normalized_file = normalize_video(input_file, temp_dir, target_resolution, target_framerate, denoise=denoise)
            if normalized_file:
                normalized_files.append(normalized_file)

        if not normalized_files:
            error_exit("No valid videos to merge after normalization.")

        file_list_path = os.path.join(temp_dir, 'file_list.txt')
        with open(file_list_path, 'w') as f:
            for norm_file in normalized_files:
                f.write(f"file '{norm_file}'\n")

        cmd = [
            'ffmpeg', '-y', '-f', 'concat', '-safe', '0', '-i', file_list_path,
            '-c:v', 'libx264', '-preset', 'medium', '-crf', '15',
            '-pix_fmt', 'yuv420p',
            '-c:a', 'aac', '-b:a', '128k',
            output_file
        ]

        total_duration = get_total_duration(normalized_files)
        description = "Concatenating videos"
        try:
            run_ffmpeg_with_progress(cmd, description, total_duration)
            logging.info(f"Video concatenation completed successfully. Output file: '{output_file}'.")
            print_success(f"Video concatenation completed successfully. Output file: '{output_file}'.")
        except Exception as e:
            error_exit(f"Failed to concatenate videos. Error: {e}")

    elif merging_mode == "vstack":
        temp_dir = tempfile.mkdtemp(prefix="tmp_vstack_", dir=LOG_DIR)
        logging.info("Starting video normalization for vertical stacking...")
        normalized_files = []
        for input_file in valid_input_files:
            normalized_file = normalize_video(input_file, temp_dir, target_resolution, target_framerate, denoise=denoise)
            if normalized_file:
                normalized_files.append(normalized_file)

        if len(normalized_files) < 2:
            error_exit("Not enough valid videos for vertical stacking.")

        inputs = []
        filters = ''
        for idx, norm_file in enumerate(normalized_files):
            inputs.extend(['-i', norm_file])
            filters += f'[{idx}:v]'

        filters += f'vstack=inputs={len(normalized_files)}[outv]'

        cmd = [
            'ffmpeg', '-y', *inputs, '-filter_complex', filters,
            '-map', '[outv]',
            '-c:v', 'libx264', '-preset', 'medium', '-crf', '15',
            '-pix_fmt', 'yuv420p',
            output_file
        ]

        total_duration = get_total_duration(normalized_files)
        description = "Vertically stacking videos"
        try:
            run_ffmpeg_with_progress(cmd, description, total_duration)
            logging.info(f"Vertical stacking of videos completed successfully. Output file: '{output_file}'.")
            print_success(f"Vertical stacking of videos completed successfully. Output file: '{output_file}'.")
        except Exception as e:
            error_exit(f"Failed to vertically stack videos. Error: {e.stderr.strip()}")

    elif merging_mode == "grid":
        temp_dir = tempfile.mkdtemp(prefix="tmp_grid_", dir=LOG_DIR)
        logging.info("Starting video normalization for grid merging...")
        normalized_files = []
        for input_file in valid_input_files:
            normalized_file = normalize_video(input_file, temp_dir, target_resolution, target_framerate, denoise=denoise)
            if normalized_file:
                normalized_files.append(normalized_file)

        if len(normalized_files) < 2:
            error_exit("Not enough valid videos for grid merging.")

        num_inputs = len(normalized_files)
        grid_cols = int(num_inputs ** 0.5)
        if grid_cols * grid_cols < num_inputs:
            grid_cols += 1
        grid_rows = (num_inputs + grid_cols - 1) // grid_cols

        target_width, target_height = map(int, target_resolution.split('x'))
        width = target_width // grid_cols
        height = target_height // grid_rows

        inputs = []
        filters = ''
        for idx, norm_file in enumerate(normalized_files):
            inputs.extend(['-i', norm_file])
            filters += f'[{idx}:v] setpts=PTS-STARTPTS, scale={width}:{height} [v{idx}]; '

        concat_inputs = ''.join([f'[v{idx}]' for idx in range(num_inputs)])
        filters += f'{concat_inputs} xstack=inputs={num_inputs}:layout={grid_cols}x{grid_rows}[outv]'

        cmd = [
            'ffmpeg', '-y', *inputs, '-filter_complex', filters,
            '-map', '[outv]',
            '-c:v', 'libx264', '-preset', 'medium', '-crf', '15',
            '-pix_fmt', 'yuv420p',
            output_file
        ]

        total_duration = get_total_duration(normalized_files)
        description = "Grid merging videos"
        try:
            run_ffmpeg_with_progress(cmd, description, total_duration)
            logging.info(f"Grid merging of videos completed successfully. Output file: '{output_file}'.")
            print_success(f"Grid merging of videos completed successfully. Output file: '{output_file}'.")
        except Exception as e:
            error_exit(f"Failed to merge videos in a grid. Error: {e}")

    elif merging_mode == "single":
        logging.info("Only one valid video provided. Copying to output file.")
        try:
            shutil.copy(valid_input_files[0], output_file)
            logging.info(f"Single video copied successfully to '{output_file}'.")
            print_success(f"Single video copied successfully to '{output_file}'.")
        except Exception as e:
            error_exit(f"Failed to copy video to output file. Error: {e}")
    else:
        error_exit(f"Unknown merging mode '{merging_mode}'.")

# --- // Screencaps Mode Function
def screencaps_mode():
    logging.info("Screencaps mode selected.")

    try:
        find_cmd = [
            "find", os.getcwd(), "-type", "f",
            "(",
            "-iname", "*.mp4", "-o",
            "-iname", "*.avi", "-o",
            "-iname", "*.mkv", "-o",
            "-iname", "*.mov", "-o",
            "-iname", "*.flv", "-o",
            "-iname", "*.wmv", "-o",
            "-iname", "*.webm", "-o",
            "-iname", "*.m4v", "-o",
            "-iname", "*.gif",
            ")"
        ]
        all_videos = subprocess.run(
            find_cmd,
            stdout=subprocess.PIPE,
            text=True,
            check=True
        ).stdout.strip().split('\n')

        if not all_videos or all_videos == ['']:
            print_warning("No video files found in the current directory.")
            return

        source_video = subprocess.run(
            ['fzf', '--prompt=Select video for screencaps>'],
            input='\n'.join(all_videos),
            stdout=subprocess.PIPE,
            text=True,
            check=True
        ).stdout.strip()

    except subprocess.CalledProcessError:
        print_warning("fzf selection failed.")
        return

    if not source_video:
        print_warning("No video selected. Returning to menu.")
        return

    interval = prompt(HTML('<ansicyan>Enter capture interval in seconds (e.g., 5): </ansicyan>'), style=style).strip()
    interval = sanitize_input(interval)
    interval = interval or '5'

    output_dir = prompt(HTML('<ansicyan>Enter output directory for screenshots (default: ./screenshots): </ansicyan>'), style=style).strip()
    output_dir = sanitize_input(output_dir)
    output_dir = output_dir or './screenshots'
    os.makedirs(output_dir, exist_ok=True)

    logging.info(f"Starting screenshot extraction every {interval} seconds from '{source_video}'.")

    cmd = [
        'ffmpeg', '-y', '-i', source_video,
        '-vf', f"fps=1/{interval}",
        os.path.join(output_dir, 'screenshot_%04d.png')
    ]

    try:
        description = "Extracting screenshots"
        # Estimate total duration
        properties = get_video_properties(source_video)
        duration_match = re.search(r'^duration=(\d+\.\d+)', properties, re.MULTILINE) if properties else None
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
            "find", os.getcwd(), "-type", "f",
            "(",
            "-iname", "*.mp4", "-o",
            "-iname", "*.avi", "-o",
            "-iname", "*.mkv", "-o",
            "-iname", "*.mov", "-o",
            "-iname", "*.flv", "-o",
            "-iname", "*.wmv", "-o",
            "-iname", "*.webm", "-o",
            "-iname", "*.m4v", "-o",
            "-iname", "*.gif",
            ")"
        ]
        all_videos = subprocess.run(
            find_cmd,
            stdout=subprocess.PIPE,
            text=True,
            check=True
        ).stdout.strip().split('\n')

        if not all_videos or all_videos == ['']:
            print_warning("No video files found in the current directory.")
            return

        source_video = subprocess.run(
            ['fzf', '--prompt=Select video to clip>'],
            input='\n'.join(all_videos),
            stdout=subprocess.PIPE,
            text=True,
            check=True
        ).stdout.strip()

    except subprocess.CalledProcessError:
        print_warning("fzf selection failed.")
        return

    if not source_video:
        print_warning("No video selected. Returning to menu.")
        return

    start_time = prompt(HTML('<ansicyan>Enter start time (format: HH:MM:SS or seconds): </ansicyan>'), style=style).strip()
    start_time = sanitize_input(start_time)
    if not start_time:
        print_warning("Start time not provided. Aborting clip creation.")
        return

    duration = prompt(HTML('<ansicyan>Enter duration of the clip (format: HH:MM:SS or seconds): </ansicyan>'), style=style).strip()
    duration = sanitize_input(duration)
    if not duration:
        print_warning("Duration not provided. Aborting clip creation.")
        return

    output_file = prompt(HTML('<ansicyan>Enter output file name (default: clip.mp4): </ansicyan>'), style=style).strip()
    output_file = sanitize_input(output_file)
    output_file = output_file or 'clip.mp4'
    if not output_file.lower().endswith('.mp4'):
        output_file += '.mp4'
    output_file = sanitize_filename(output_file)

    cmd = [
        'ffmpeg', '-y', '-ss', start_time, '-i', source_video,
        '-t', duration, '-c', 'copy', output_file
    ]

    try:
        description = f"Creating clip '{output_file}'"
        # Estimate duration
        properties = get_video_properties(source_video)
        duration_match = re.search(r'^duration=(\d+\.\d+)', properties, re.MULTILINE) if properties else None
        if duration_match:
            total_duration = float(duration_match.group(1))
        else:
            total_duration = 60.0  # Default to 60 seconds if duration is unknown

        run_ffmpeg_with_progress(cmd, description, total_duration)
        logging.info(f"Clip created successfully as '{output_file}'.")
        print_success(f"Clip created successfully as '{output_file}'.")
    except Exception as e:
        error_exit(f"Failed to create clip. Error: {e}")

# --- // Merge Videos Mode
def merge_videos_mode():
    logging.info("Merge Videos mode selected.")

    try:
        find_cmd = [
            "find", os.getcwd(), "-type", "f",
            "(",
            "-iname", "*.mp4", "-o",
            "-iname", "*.avi", "-o",
            "-iname", "*.mkv", "-o",
            "-iname", "*.mov", "-o",
            "-iname", "*.flv", "-o",
            "-iname", "*.wmv", "-o",
            "-iname", "*.webm", "-o",
            "-iname", "*.m4v", "-o",
            "-iname", "*.gif",
            ")"
        ]
        all_videos = subprocess.run(
            find_cmd,
            stdout=subprocess.PIPE,
            text=True,
            check=True
        ).stdout.strip().split('\n')

        if not all_videos or all_videos == ['']:
            print_warning("No video files found in the current directory.")
            return

        videos = subprocess.run(
            ['fzf', '--multi', '--prompt=Select videos to merge>'],
            input='\n'.join(all_videos),
            stdout=subprocess.PIPE,
            text=True,
            check=True
        ).stdout.strip().split('\n')

    except subprocess.CalledProcessError:
        print_warning("fzf selection failed.")
        return

    if not videos or videos == ['']:
        print_warning("No videos selected for merging.")
        return

    output_file = prompt(HTML('<ansicyan>Enter output file name (default: merged_output.mp4): </ansicyan>'), style=style).strip()
    output_file = sanitize_input(output_file)
    output_file = output_file or 'merged_output.mp4'
    if not output_file.lower().endswith('.mp4'):
        output_file += '.mp4'
    output_file = sanitize_filename(output_file)

    if os.path.isfile(output_file):
        base, ext = os.path.splitext(output_file)
        i = 1
        while os.path.isfile(f"{base}_{i}{ext}"):
            i += 1
        output_file = f"{base}_{i}{ext}"
        logging.warning(f"Output file already exists. Saving as '{output_file}'.")

    logging.info(f"Merging videos into '{output_file}'...")
    merge_videos(output_file, videos)

# --- // Main Menu
def main_menu():
    menu_options = [
        'Screencaps',
        'Clip',
        'Merge Videos',
        'Exit'
    ]
    completer = WordCompleter(menu_options, ignore_case=True)

    while True:
        print_formatted_text(HTML('<ansicyan># --- // Vidutil.py //</ansicyan>\n'), style=style)
        # Uncomment below lines to display menu options dynamically
        # for key in menu_options:
        #     print_formatted_text(HTML(f"<ansicyan>{key.title()}</ansicyan>"), style=style)
        choice_input = prompt(
            HTML('<ansicyan>Menu: </ansicyan>'),
            completer=completer,
            style=style
        )
        if choice_input is None:
            print_warning("No input provided. Please try again.")
            continue
        choice = sanitize_input(choice_input).lower()
        if not choice:
            print_warning("No input provided. Please try again.")
            continue
        try:
            if choice == 'screencaps':
                screencaps_mode()
            elif choice == 'clip':
                clip_mode()
            elif choice == 'merge videos':
                merge_videos_mode()
            elif choice == 'exit':
                print_formatted_text(HTML('\n💥 <ansired>Terminated!</ansired>'), style=style)
                break
            else:
                print_warning(f"Unrecognized option: {choice}")
        except Exception as e:
            logging.error(f"Error: {e}")
            print_warning(f"An error occurred: {e}")

# --- // Entry Point
if __name__ == "__main__":
    main_menu()
