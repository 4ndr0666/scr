#!/usr/bin/env python3

'''
Script: merge_videos.py
Description: Normalize and merge multiple videos selected via an interactive CLI with user-friendly enhancements.
Enhancements: Improved error handling, fzf integration, logging, progress tracking, and user-friendly features.
Dependencies: ffmpeg, ffprobe, Python 3.x, optional fzf.
'''

import subprocess
import sys
import os
import tempfile
import shutil
import logging
import multiprocessing
import configparser
from pathlib import Path
from argparse import ArgumentParser
from datetime import datetime
import signal

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

class VideoProcessor:
    def __init__(self, crf, preset, codec, output_name):
        self.crf = crf
        self.preset = preset
        self.codec = codec
        self.output_name = output_name

    def check_dependencies(self):
        '''Ensure that ffmpeg, ffprobe, and optionally fzf are installed.'''
        if sys.version_info < (3, 0):
            logging.error("Python 3.x is required to run this script.")
            sys.exit(1)
        
        for cmd in ['ffmpeg', 'ffprobe']:
            if not shutil.which(cmd):
                logging.error(f"Error: {cmd} is not installed.")
                sys.exit(1)
        if not shutil.which('fzf'):
            logging.warning("fzf not found, falling back to basic file selection.")
        
        # Ensure FFmpeg version compatibility
        try:
            result = subprocess.run(['ffmpeg', '-version'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            logging.info(f"FFmpeg version: {result.stdout.splitlines()[0]}")
        except subprocess.CalledProcessError:
            logging.error("FFmpeg version check failed.")
            sys.exit(1)

    def select_video_files(self, use_fzf=True):
        '''Select video files to merge using fzf (if available) or basic input.'''
        if use_fzf and shutil.which('fzf'):
            logging.info("Using fzf for file selection.")
            cmd = ['fzf', '--multi', '--preview', 'ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 {}']
            result = subprocess.run(cmd, text=True, capture_output=True)
            video_files = result.stdout.strip().split('\n')
            if not video_files or result.returncode != 0:
                logging.error("fzf selection failed or no files selected.")
                sys.exit(1)
        else:
            logging.info("Interactive file selection started. Type 'done' when finished.")
            import glob
            import readline

            def completer(text, state):
                options = [x for x in glob.glob(text + '*') if os.path.isfile(x)]
                return options[state] if state < len(options) else None

            readline.set_completer(completer)
            readline.parse_and_bind('tab: complete')

            video_files = []
            while True:
                inp = input("Select a file or type 'done': ")
                if inp.strip().lower() == 'done':
                    break
                elif os.path.isfile(inp.strip()):
                    video_files.append(inp.strip())
                    logging.info(f"Selected: {inp.strip()}")
                else:
                    logging.error("Invalid file path. Please try again.")

            if not video_files:
                logging.error("No video files selected. Exiting.")
                sys.exit(1)

        return video_files

    def get_video_properties(self, file_path):
        '''Retrieve the width and height of a video using ffprobe.'''
        cmd = ['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=width,height', '-of', 'csv=p=0:s=x', file_path]
        try:
            result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
            if result.stdout.strip():
                width, height = map(int, result.stdout.strip().split('x'))
                return width, height
            else:
                raise ValueError(f"ffprobe returned empty output for {file_path}")
        except (subprocess.CalledProcessError, ValueError) as e:
            logging.error(f"Could not retrieve properties for {file_path}: {e}")
            return None, None

    def normalize_video(self, args):
        '''Normalize a single video to the target resolution dynamically.'''
        file_path, target_width, target_height, output_dir = args
        output_file = output_dir / f"normalized_{Path(file_path).name}"
        width, height = self.get_video_properties(file_path)

        if width is None or height is None:
            return None

        try:
            if width == target_width and height == target_height:
                logging.info(f"Skipping normalization for {file_path} as it already matches the target resolution.")
                shutil.copyfile(file_path, output_file)
            else:
                scale_filter = f"scale={target_width}:{target_height}:force_original_aspect_ratio=decrease"
                pad_filter = f"pad={target_width}:{target_height}:(ow-iw)/2:(oh-ih)/2"
                vf = f"{scale_filter},{pad_filter}"
                cmd = ['ffmpeg', '-y', '-i', file_path, '-vf', vf, '-c:v', self.codec, '-preset', self.preset, '-crf', str(self.crf), '-c:a', 'aac', '-strict', 'experimental', str(output_file)]
                subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, check=True)
            return output_file
        except subprocess.CalledProcessError as e:
            logging.error(f"Normalization failed for {file_path}: {e}")
            return None

    def merge_videos(self, normalized_files):
        '''Merge normalized videos into a single output file.'''
        with tempfile.NamedTemporaryFile('w', delete=False) as concat_file:
            for file in normalized_files:
                concat_file.write(f"file '{file}'\n")

        try:
            cmd = ['ffmpeg', '-y', '-f', 'concat', '-safe', '0', '-i', concat_file.name, '-c', 'copy', self.output_name]
            subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, check=True)
            logging.info(f"Videos merged successfully into '{self.output_name}'.")
        except subprocess.CalledProcessError as e:
            logging.error(f"Merging failed: {e}")
            sys.exit(1)
        finally:
            os.unlink(concat_file.name)

    def process_videos(self, video_files):
        logging.info("Analyzing video properties...")
        max_width = max_height = 0
        for file in video_files:
            width, height = self.get_video_properties(file)
            if width and height:
                max_width = max(max_width, width)
                max_height = max(max_height, height)
        logging.info(f"Target resolution: {max_width}x{max_height}")

        with tempfile.TemporaryDirectory() as tmpdir:
            output_dir = Path(tmpdir)
            logging.info("Normalizing videos...")
            args_list = [(file, max_width, max_height, output_dir) for file in video_files]

            pool_size = min(multiprocessing.cpu_count(), len(video_files))
            with multiprocessing.Pool(pool_size) as pool:
                results = pool.map(self.normalize_video, args_list)

            normalized_files = [result for result in results if result is not None]
            if not normalized_files:
                logging.error("No videos were successfully normalized. Exiting.")
                sys.exit(1)

            self.merge_videos(normalized_files)

def create_config(config_file):
    '''Interactively create a configuration file.'''
    config = configparser.ConfigParser()

    print("Creating configuration file...")
    ffmpeg_config = {
        'crf': input("Enter CRF value for FFmpeg (default: 15): ") or '15',
        'preset': input("Enter FFmpeg preset (default: faster): ") or 'faster',
        'codec': input("Enter video codec (default: libx264): ") or 'libx264'
    }

    output_config = {
        'filename': f'merged_output_{datetime.now().strftime("%Y%m%d_%H%M")}.mp4'
    }

    config['FFmpeg'] = ffmpeg_config
    config['Output'] = output_config

    with open(config_file, 'w') as configfile:
        config.write(configfile)
    print(f"Configuration saved to {config_file}")

def load_config(config_file):
    '''Load configuration from a file.'''
    config = configparser.ConfigParser()
    config.read(config_file)
    return config

def handle_exit_signal(signal_received, frame):
    logging.warning("Process interrupted. Cleaning up...")
    sys.exit(1)

def main():
    signal.signal(signal.SIGINT, handle_exit_signal)

    parser = ArgumentParser(description="Normalize and merge videos.")
    parser.add_argument('--config', help="Path to configuration file.")
    parser.add_argument('--crf', type=int, help="CRF value for FFmpeg.")
    parser.add_argument('--preset', help="FFmpeg preset.")
    parser.add_argument('--codec', help="Video codec for normalization.")
    parser.add_argument('--output', help="Output file name.")
    args = parser.parse_args()

    config_file = args.config or '/home/andro/.cache/tmp/merge_videos_config.ini'
    if not os.path.exists(config_file):
        create_config(config_file)

    config = load_config(config_file)

    crf = config.getint('FFmpeg', 'crf', fallback=15)
    preset = config.get('FFmpeg', 'preset', fallback='faster')
    codec = config.get('FFmpeg', 'codec', fallback='libx264')
    output_name = args.output if args.output else config.get('Output', 'filename')

    processor = VideoProcessor(crf, preset, codec, output_name)
    processor.check_dependencies()
    video_files = processor.select_video_files()
    processor.process_videos(video_files)

if __name__ == '__main__':
    main()
