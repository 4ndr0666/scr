#!/bin/python3

import os
import subprocess
import readline
import time
import sys
import json

# Helper function to use fzf for file selection
def use_fzf_to_select_files(multiple=False):
    """Use fzf to select files from the current directory."""
    fzf_command = ['fzf']
    if multiple:
        fzf_command.append('--multi')

    result = subprocess.run(fzf_command, capture_output=True, text=True)
    if result.returncode == 0:
        if multiple:
            return result.stdout.strip().split('\n')  # Return multiple selected files
        return result.stdout.strip()  # Return single selected file
    else:
        print_warning("No files selected or error with fzf.")
        return None

# Function to get video properties using ffprobe
def get_video_properties(file):
    """Get the resolution, frame rate, and codec of a video using ffprobe (JSON output)."""
    command = [
        'ffprobe', '-v', 'error', '-select_streams', 'v:0',
        '-show_entries', 'stream=width,height,r_frame_rate,codec_name',
        '-of', 'json', file
    ]
    
    result = subprocess.run(command, capture_output=True, text=True)
    
    if result.returncode != 0:
        raise Exception(f"Error getting video properties for {file}")
    
    # Parse the JSON output
    try:
        data = json.loads(result.stdout)
        stream = data['streams'][0]  # Assuming the first stream is the video stream
        
        width = stream.get('width')
        height = stream.get('height')
        codec = stream.get('codec_name')
        fps = stream.get('r_frame_rate')
        
        # Ensure width and height are valid integers
        if not width or not height:
            raise Exception(f"Invalid resolution: width={width}, height={height}")
        
        # Handle frame rate, which might be in fraction format (e.g., '30000/1001')
        try:
            fps = eval(fps) if fps else None
        except:
            raise Exception(f"Invalid frame rate: {fps}")
        
        return int(width), int(height), fps, codec
    
    except (KeyError, json.JSONDecodeError) as e:
        raise Exception(f"Error parsing ffprobe output for {file}: {e}")

# Function to check if normalization is required before concatenation
def check_normalization_needed(files):
    """Check if all files have the same resolution, frame rate, and codec."""
    properties = []
    for file in files:
        properties.append(get_video_properties(file))

    # Compare all files' properties to the first one
    first_properties = properties[0]
    for prop in properties[1:]:
        if prop != first_properties:
            return True  # Normalization is needed if any properties differ
    return False  # No normalization needed if all properties match

# Function to normalize videos before concatenation (if needed)
def normalize_videos_if_needed(files, resolution='1280x720', fps='30', codec='libx264'):
    """Normalize videos to a consistent resolution, frame rate, and codec if needed."""
    output_files = []
    for idx, file in enumerate(files):
        # Output file name
        output_file = f"normalized_{idx}.mp4"
        
        # Get video properties
        try:
            width, height, video_fps, video_codec = get_video_properties(file)
        except Exception as e:
            print_warning(f"Error retrieving video properties for {file}: {e}")
            continue

        # Determine if we need to re-encode based on resolution or frame rate change
        need_reencode = (int(width) != int(resolution.split('x')[0]) or
                         int(height) != int(resolution.split('x')[1]) or
                         float(video_fps) != float(fps))

        if video_codec == 'h264' and not need_reencode:
            # If the codec is h264 and no scaling/fps change is needed, use copy
            print(f"{file} is already in h264 format with matching resolution and fps, using copy for codec.")
            command = [
                'ffmpeg', '-i', file, '-c:v', 'copy', '-c:a', 'copy', output_file
            ]
        else:
            # If re-encoding is required (e.g., scaling or fps change), re-encode
            print(f"Re-encoding {file} to {output_file} with resolution={resolution}, fps={fps}.")
            command = [
                'ffmpeg', '-i', file, '-vf', f"scale={resolution},fps={fps}",
                '-c:v', codec, '-preset', 'fast', '-crf', '23', '-c:a', 'aac', output_file
            ]

        print(f"Normalizing {file} to {output_file}...")
        result = subprocess.run(command)
        if result.returncode != 0:
            print_warning(f"Error normalizing video: {file}. Skipping this file.")
        else:
            output_files.append(output_file)

    return output_files

# Function to concatenate videos
def concatenate_videos(files, output_file):
    """Concatenate multiple video files using ffmpeg."""
    with open('input.txt', 'w') as f:
        for file in files:
            f.write(f"file '{file}'\n")
    
    command = ['ffmpeg', '-f', 'concat', '-safe', '0', '-i', 'input.txt', '-c', 'copy', output_file]
    print(f"Merging files into {output_file}...")
    result = subprocess.run(command)
    
    if result.returncode != 0:
        print_warning("Error during concatenation.")
    else:
        print_status(f"Concatenation successful. Output saved to {output_file}.")
        os.remove('input.txt')  # Clean up input.txt

# Function to analyze video using MediaInfo
def analyze_video_with_mediainfo(file):
    """Analyze a video file using MediaInfo to get detailed metadata."""
    command = ['mediainfo', file]
    print(f"Analyzing video {file} using MediaInfo...")
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        print_warning(f"Error analyzing video {file}.")
    else:
        print(result.stdout)

# Function to transcode videos
def transcode_video(file, output_file, codec='libx265'):
    """Transcode video to a different codec using ffmpeg."""
    command = ['ffmpeg', '-i', file, '-c:v', codec, '-crf', '28', output_file]
    print(f"Transcoding {file} to {codec}...")
    result = subprocess.run(command)
    if result.returncode != 0:
        print_warning(f"Error transcoding video: {file}")
    else:
        print_status(f"Transcoding successful. Output saved to {output_file}.")

# Function to compress videos
def compress_video(file, output_file, video_bitrate='1000k', audio_bitrate='128k'):
    """Compress video by adjusting the video and audio bitrate using ffmpeg."""
    command = [
        'ffmpeg', '-i', file, '-b:v', video_bitrate, '-b:a', audio_bitrate, output_file
    ]
    print(f"Compressing {file} to {output_file}...")
    result = subprocess.run(command)
    if result.returncode != 0:
        print_warning(f"Error compressing video: {file}")
    else:
        print_status(f"Compression successful. Output saved to {output_file}.")

# Function to extract audio from videos
def extract_audio_from_video(file, output_file):
    """Extract audio from a video using ffmpeg."""
    command = ['ffmpeg', '-i', file, '-q:a', '0', '-map', 'a', output_file]
    print(f"Extracting audio from {file}...")
    result = subprocess.run(command)
    if result.returncode != 0:
        print_warning(f"Error extracting audio from {file}")
    else:
        print_status(f"Audio extracted successfully. Output saved to {output_file}.")

# Handle metadata retention or removal
def handle_metadata(file, output_file, keep_metadata):
    """Handle metadata (retain or remove) from a video file."""
    if keep_metadata:
        command = ['ffmpeg', '-i', file, '-map_metadata', '0', '-c', 'copy', output_file]
    else:
        command = ['ffmpeg', '-i', file, '-map_metadata', '-1', '-c', 'copy', output_file]
    
    print(f"Processing metadata for {file}...")
    result = subprocess.run(command)
    if result.returncode != 0:
        print_warning(f"Error processing metadata for {file}")
    else:
        print_status(f"Metadata handling completed. Output saved to {output_file}.")

# Function for advanced concatenation across formats
def concatenate_across_formats(files, output_file):
    """Concatenate videos that may have different formats by re-encoding them."""
    temp_files = normalize_videos_if_needed(files)
    concatenate_videos(temp_files, output_file)

# Utility functions for printing
def print_header(title):
    """Print a header for the menu system."""
    print("\n" + "="*50)
    print(f"{title.center(50)}")
    print("="*50 + "\n")

def print_warning(message):
    """Print a styled warning message."""
    print(f"⚠️  {message}")

def print_status(message, status="OK"):
    """Print a status message with styled indicators."""
    status_symbol = "✓" if status == "OK" else "✗"
    print(f"{message} [{status_symbol}]\n")

# Function to display help
def print_help():
    """Display help information about the available commands."""
    print("Help Menu:")
    print("Use the following options:")
    print("1. Analyze video with MediaInfo")
    print("2. Normalize videos")
    print("3. Concatenate videos")
    print("4. Extract audio")
    print("5. Transcode video")
    print("6. Compress video")
    print("7. Handle metadata")
    print("8. Advanced concatenation")
    print("9. Exit")

# Main menu function with enhanced visuals and new functions
def main_menu():
    """Display the main menu and handle user selection."""
    while True:
        print_header("VIDEO PROCESSING TOOL")
        menu_options = [
            "1. Analyze video with MediaInfo",
            "2. Normalize videos",
            "3. Concatenate videos with ffmpeg",
            "4. Extract audio from video",
            "5. Transcode video to different codec",
            "6. Compress video",
            "7. Handle metadata (retain or remove)",
            "8. Advanced concatenation across formats",
            "9. Exit"
        ]

        for option in menu_options:
            print(f"  {option}")

        choice = input("\nSelect an option (or '-h' for help): ")

        if choice == '1':
            video_file = use_fzf_to_select_files()
            if video_file:
                analyze_video_with_mediainfo(video_file)

        elif choice == '2':
            video_files = use_fzf_to_select_files(multiple=True)
            if video_files:
                resolution, fps = select_resolution_and_fps()
                normalize_videos_if_needed(video_files, resolution, fps)

        elif choice == '3':
            video_files = use_fzf_to_select_files(multiple=True)
            if video_files:
                if check_normalization_needed(video_files):
                    print_warning("Files have different properties. Normalizing before concatenation.")
                    video_files = normalize_videos_if_needed(video_files)
                output_file = input("Enter the output file name (e.g., output.mp4): ")
                concatenate_videos(video_files, output_file)

        elif choice == '4':
            video_file = use_fzf_to_select_files()
            if video_file:
                output_file = input("Enter the output file name for the audio (e.g., audio.mp3): ")
                extract_audio_from_video(video_file, output_file)

        elif choice == '5':
            video_file = use_fzf_to_select_files()
            if video_file:
                output_file = input("Enter the output file name (e.g., output.mkv): ")
                codec = input("Enter the codec (default is libx265): ") or 'libx265'
                transcode_video(video_file, output_file, codec)

        elif choice == '6':
            video_file = use_fzf_to_select_files()
            if video_file:
                output_file = input("Enter the output file name (e.g., output_compressed.mp4): ")
                video_bitrate = input("Enter video bitrate (e.g., 1000k): ") or '1000k'
                audio_bitrate = input("Enter audio bitrate (e.g., 128k): ") or '128k'
                compress_video(video_file, output_file, video_bitrate, audio_bitrate)

        elif choice == '7':
            video_file = use_fzf_to_select_files()
            if video_file:
                output_file = input("Enter the output file name (e.g., output.mp4): ")
                keep_metadata = input("Would you like to retain metadata? (y/n): ").lower() == 'y'
                handle_metadata(video_file, output_file, keep_metadata)

        elif choice == '8':
            video_files = use_fzf_to_select_files(multiple=True)
            if video_files:
                output_file = input("Enter the output file name (e.g., output.mkv): ")
                concatenate_across_formats(video_files, output_file)

        elif choice == '9':
            print_status("Exiting program. Goodbye!", "OK")
            break

        elif choice == '-h':
            print_help()

        else:
            print_warning(f"Unrecognized option: {choice}")

# Function to select resolution and frame rate
def select_resolution_and_fps():
    print("Select resolution:")
    print("1. 1280x720 (720p)")
    print("2. 1920x1080 (1080p)")
    print("3. 3840x2160 (2160p, 4K)")
    print("4. Custom")

    resolution_choice = input("Enter your choice (1-4): ")

    if resolution_choice == '1':
        resolution = '1280x720'
    elif resolution_choice == '2':
        resolution = '1920x1080'
    elif resolution_choice == '3':
        resolution = '3840x2160'
    else:
        resolution = input("Enter custom resolution (e.g., 1920x1080): ")

    print("Select frame rate:")
    print("1. 30 fps")
    print("2. 60 fps")
    print("3. 120 fps")
    print("4. Custom")

    fps_choice = input("Enter your choice (1-4): ")

    if fps_choice == '1':
        fps = 30
    elif fps_choice == '2':
        fps = 60
    elif fps_choice == '3':
        fps = 120
    else:
        fps = int(input("Enter custom frame rate (e.g., 24): "))

    return resolution, fps

# Entry point for the script
if __name__ == "__main__":
    main_menu()
