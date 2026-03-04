#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# vidline_alpha.py
# Ψ-4ndr0666 Comprehensive Media Orchestrator (v4.0.2)
#
# COHESION & SUPERSET REPORT:
# - GAP MITIGATION: Globally imported `shutil` (Fixed NameError).
# - SUPERSET COMPLIANCE: Restored all legacy bash features (deflicker, dedot, dehalo, removegrain, deband, deshake, slo-mo, speed-up, convert, color-correct, edge-detect, fps, scale super-res).
# - Replaced brittle Bash parsing with an interactive `prompt_toolkit` interface.
# - FFmpeg execution hardened: array-based command building prevents shell injection.
# - Audio synchronization logic implemented for speed manipulation filters.

import os
import sys
import subprocess
import logging
import argparse
import shutil
from pathlib import Path
from prompt_toolkit import prompt
from prompt_toolkit.completion import WordCompleter
from prompt_toolkit.formatted_text import HTML
from prompt_toolkit.shortcuts import print_formatted_text
from prompt_toolkit.styles import Style

# --- // Constants & Setup // ---
XDG_DATA_HOME = os.environ.get("XDG_DATA_HOME", os.path.join(os.environ["HOME"], ".local", "share"))
DATA_HOME = os.path.join(XDG_DATA_HOME, "vidline_alpha")
LOG_DIR = os.path.join(DATA_HOME, "logs")
os.makedirs(LOG_DIR, exist_ok=True)

logging.basicConfig(
    filename=os.path.join(LOG_DIR, "operations.log"),
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)

# --- // Theming // ---
style = Style.from_dict({
    "completion-menu.completion": "fg:#15FFFF bg:default",
    "completion-menu.completion.current": "fg:#15FFFF bg:#333333",
    "ansicyan": "#15ffff",
    "ansired": "#A80D1B",
    "ansigreen": "#2ECC71",
    "ansiyellow": "#F1C40F",
    "info": "fg:#15FFFF",
    "warning": "fg:#F1C40F",
    "error": "fg:#A80D1B bold",
    "success": "fg:#2ECC71 bold",
})

def print_cyan(text):
    print_formatted_text(HTML(f"<ansicyan>{text}</ansicyan>"), style=style)

def print_green(text):
    print_formatted_text(HTML(f"<ansigreen>[+] {text}</ansigreen>"), style=style)

def print_warning(text):
    print_formatted_text(HTML(f"<ansiyellow>[-] {text}</ansiyellow>"), style=style)

def print_error(text):
    print_formatted_text(HTML(f"<ansired>[!] {text}</ansired>"), style=style)

# --- // FZF Target Acquisition // ---
def select_file_fzf():
    try:
        if not shutil.which("fzf"):
            print_error("FZF not installed. Please install fzf for target acquisition.")
            return None
            
        find_cmd = ["find", ".", "-type", "f", "-iregex", r".*\.\(mp4\|mkv\|mov\|avi\|webm\)"]
        fzf_cmd = ["fzf", "--prompt=Select Target > ", "--height=40%", "--layout=reverse"]
        
        p1 = subprocess.Popen(find_cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        p2 = subprocess.Popen(fzf_cmd, stdin=p1.stdout, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        p1.stdout.close()
        
        output, _ = p2.communicate()
        if p2.returncode == 0 and output:
            return output.decode("utf-8").strip()
    except Exception as e:
        print_error(f"FZF subsystem failure: {e}")
    return None

def sanitize_input(user_input):
    return user_input.strip()

# --- // FFmpeg Execution Engines // ---
def get_safe_output(input_file, suffix="_processed", new_ext=None):
    base, ext = os.path.splitext(input_file)
    if new_ext:
        ext = f".{new_ext.lstrip('.')}"
    output_file = f"{base}{suffix}{ext}"
    counter = 1
    while os.path.exists(output_file):
        output_file = f"{base}{suffix}_{counter}{ext}"
        counter += 1
    return output_file

def execute_ffmpeg(input_file, filter_graph, operation_desc):
    if not input_file or not os.path.exists(input_file):
        print_error(f"Target unreachable: {input_file}")
        return None

    output_file = get_safe_output(input_file)
    print_cyan(f"[Ψ] Engaging {operation_desc} Matrix...")
    logging.info(f"Operation: {operation_desc} | Input: {input_file} | Filter: {filter_graph}")

    cmd = [
        "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
        "-i", input_file,
        "-vf", filter_graph,
        "-c:a", "copy",
        output_file
    ]

    try:
        subprocess.run(cmd, check=True)
        print_green(f"Operation Complete: {output_file}")
        return output_file
    except subprocess.CalledProcessError as e:
        print_error(f"FFmpeg Execution Failure: {e}")
        return None

def execute_speed_change(input_file, factor, operation_desc):
    if not input_file or not os.path.exists(input_file):
        return None
        
    output_file = get_safe_output(input_file, suffix="_speed")
    print_cyan(f"[Ψ] Engaging {operation_desc} Matrix (Factor: {factor})...")
    
    # Audio atempo filter must be inverted to video setpts
    audio_factor = 1.0 / float(factor)
    
    cmd = [
        "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
        "-i", input_file,
        "-filter_complex", f"[0:v]setpts={factor}*PTS[v];[0:a]atempo={audio_factor}[a]",
        "-map", "[v]", "-map", "[a]",
        output_file
    ]
    
    try:
        subprocess.run(cmd, check=True)
        print_green(f"Operation Complete: {output_file}")
        return output_file
    except subprocess.CalledProcessError as e:
        print_error(f"FFmpeg Execution Failure: {e}")
        return None

def execute_conversion(input_file, target_format):
    if not input_file or not os.path.exists(input_file):
        return None
        
    output_file = get_safe_output(input_file, suffix="_converted", new_ext=target_format)
    print_cyan(f"[Ψ] Engaging Format Conversion ({target_format})...")
    
    cmd = [
        "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
        "-i", input_file,
        "-c", "copy",
        output_file
    ]
    try:
        subprocess.run(cmd, check=True)
        print_green(f"Operation Complete: {output_file}")
        return output_file
    except subprocess.CalledProcessError as e:
        print_error(f"FFmpeg Execution Failure: {e}")
        return None

# --- // Interactive Menu // ---
def interactive_menu():
    active_target = None
    menu_options = [
        "Select Target", "FPS", "Deflicker", "Dedot", "Dehalo", "Removegrain", 
        "Deband", "Sharpen", "Super-Res", "Deshake", "Edge-Detect", "Slo-mo", 
        "Speed-up", "Convert", "Color-Correct", "Crop", "Rotate", "Flip", 
        "Help", "Exit"
    ]
    completer = WordCompleter(menu_options, ignore_case=True)

    while True:
        print_formatted_text(HTML("<ansicyan>\n# --- // Vidline Alpha Menu //</ansicyan>"), style=style)
        if active_target:
            print_formatted_text(HTML(f"<ansigreen>Target Locked:</ansigreen> {active_target}"), style=style)
        else:
            print_formatted_text(HTML("<ansired>No Target Selected.</ansired>"), style=style)

        choice_input = prompt(HTML("<ansicyan>Operation: </ansicyan>"), completer=completer, style=style)
        if choice_input is None:
            continue
            
        choice = sanitize_input(choice_input).lower()

        try:
            if not active_target and choice not in ["select target", "help", "exit", ""]:
                print_warning("Select a target first.")
                continue

            if choice == "select target":
                target = select_file_fzf()
                if target: active_target = target
            
            elif choice == "fps":
                val = prompt(HTML("<info>Enter target FPS (e.g., 30): </info>"), style=style).strip()
                if val: active_target = execute_ffmpeg(active_target, f"fps={val}", "FPS Conversion") or active_target
            
            elif choice == "deflicker":
                active_target = execute_ffmpeg(active_target, "deflicker", "Deflicker") or active_target
            
            elif choice == "dedot":
                active_target = execute_ffmpeg(active_target, "dedot", "Dedot") or active_target
            
            elif choice == "dehalo":
                active_target = execute_ffmpeg(active_target, "dehalo", "Dehalo") or active_target
            
            elif choice == "removegrain":
                val = prompt(HTML("<info>Enter removegrain type (1-22): </info>"), style=style).strip()
                if val: active_target = execute_ffmpeg(active_target, f"removegrain=m1={val}", "Removegrain") or active_target
                
            elif choice == "deband":
                val = prompt(HTML("<info>Enter deband params (e.g., 1:0.02:0.02:1.2): </info>"), style=style).strip()
                if val: active_target = execute_ffmpeg(active_target, f"deband={val}", "Deband") or active_target
                
            elif choice == "sharpen":
                active_target = execute_ffmpeg(active_target, "unsharp=5:5:1.0:5:5:0.0", "Sharpen") or active_target
                
            elif choice == "super-res":
                active_target = execute_ffmpeg(active_target, "scale=iw*2:ih*2:flags=lanczos", "Super-Res Scale") or active_target
                
            elif choice == "deshake":
                active_target = execute_ffmpeg(active_target, "deshake", "Deshake") or active_target
                
            elif choice == "edge-detect":
                active_target = execute_ffmpeg(active_target, "edgedetect", "Edge-Detect") or active_target
                
            elif choice == "color-correct":
                active_target = execute_ffmpeg(active_target, "eq=contrast=1.1:brightness=0.05:saturation=1.2", "Color-Correct") or active_target
                
            elif choice == "slo-mo":
                val = prompt(HTML("<info>Enter slow-down factor (e.g., 2.0 for half speed): </info>"), style=style).strip()
                if val: active_target = execute_speed_change(active_target, val, "Slo-Mo") or active_target
                
            elif choice == "speed-up":
                val = prompt(HTML("<info>Enter speed-up factor (e.g., 2.0 for 2x speed): </info>"), style=style).strip()
                # To speed up by factor X, setpts needs 1/X
                if val: 
                    factor = str(1.0 / float(val))
                    active_target = execute_speed_change(active_target, factor, "Speed-Up") or active_target
                
            elif choice == "convert":
                ext = prompt(HTML("<info>Enter target extension (e.g., mkv): </info>"), style=style).strip()
                if ext: active_target = execute_conversion(active_target, ext) or active_target

            elif choice == "crop":
                dims = prompt(HTML("<info>Enter crop (W:H:X:Y): </info>"), style=style).strip()
                if dims: active_target = execute_ffmpeg(active_target, f"crop={dims}", "Crop") or active_target
                
            elif choice == "rotate":
                rot = prompt(HTML("<info>Enter rotation (90, 180, -90): </info>"), style=style).strip()
                if rot == "90": vf = "transpose=1"
                elif rot == "180": vf = "transpose=2,transpose=2"
                elif rot == "-90": vf = "transpose=2"
                else: print_warning("Invalid rotation."); continue
                active_target = execute_ffmpeg(active_target, vf, "Rotate") or active_target
                
            elif choice == "flip":
                fdir = prompt(HTML("<info>Enter flip direction (h or v): </info>"), style=style).strip()
                vf = "hflip" if fdir == "h" else ("vflip" if fdir == "v" else None)
                if vf: active_target = execute_ffmpeg(active_target, vf, "Flip") or active_target
                else: print_warning("Invalid flip direction.")
                
            elif choice == "help":
                print_cyan("Available Operations:\n- FPS, Deflicker, Dedot, Dehalo, Removegrain, Deband, Sharpen\n- Super-Res (2x Scale), Deshake, Edge-Detect, Color-Correct\n- Slo-mo, Speed-up, Convert (Container swap)\n- Crop, Rotate, Flip")
            elif choice == "exit":
                print_formatted_text(HTML("\n💥 <ansired>Terminated!</ansired>"), style=style)
                break
            elif choice == "":
                pass
            else:
                print_warning(f"Unrecognized sequence: {choice}")
        except KeyboardInterrupt:
            print_warning("Sequence aborted. Returning to menu.")
        except Exception as e:
            print_error(f"Critical Subsystem Error: {e}")
            logging.error(f"Exception: {e}")

# --- // CLI Argument Parser // ---
def main():
    parser = argparse.ArgumentParser(description="Ψ-4ndr0666 Vidline Alpha Orchestrator")
    parser.add_argument("file", nargs="?", help="Target input file (Optional)")
    parser.add_argument("--menu", action="store_true", help="Force interactive menu mode")
    
    # Transformation Arguments
    parser.add_argument("--fps", help="Convert frame rate")
    parser.add_argument("--deflicker", action="store_true", help="Apply deflicker")
    parser.add_argument("--dedot", action="store_true", help="Apply dedot")
    parser.add_argument("--dehalo", action="store_true", help="Apply dehalo")
    parser.add_argument("--removegrain", help="Removegrain type (1-22)")
    parser.add_argument("--deband", help="Deband params")
    parser.add_argument("--sharpen", action="store_true", help="Sharpen video")
    parser.add_argument("--scale", action="store_true", help="Double resolution (Super-Res)")
    parser.add_argument("--deshake", action="store_true", help="Stabilize footage")
    parser.add_argument("--edge-detect", action="store_true", help="Edge detection")
    parser.add_argument("--color-correct", action="store_true", help="Basic color correction")
    parser.add_argument("--crop", help="Crop video (W:H:X:Y)")
    parser.add_argument("--rotate", help="Rotate video (90, 180, -90)")
    parser.add_argument("--flip", help="Flip video (h or v)")
    
    # Complex/Structural Arguments
    parser.add_argument("--slo-mo", help="Slow down video by factor")
    parser.add_argument("--speed-up", help="Speed up video by factor")
    parser.add_argument("--convert", help="Convert video container (e.g., mkv)")

    if len(sys.argv) == 1:
        interactive_menu()
        return

    args = parser.parse_args()

    if args.menu:
        interactive_menu()
        return

    target = args.file
    if not target:
        target = select_file_fzf()
        if not target: sys.exit(1)

    # Note: For CLI sequential rapid-fire, operations are applied successively.
    if args.fps: target = execute_ffmpeg(target, f"fps={args.fps}", "FPS") or target
    if args.deflicker: target = execute_ffmpeg(target, "deflicker", "Deflicker") or target
    if args.dedot: target = execute_ffmpeg(target, "dedot", "Dedot") or target
    if args.dehalo: target = execute_ffmpeg(target, "dehalo", "Dehalo") or target
    if args.removegrain: target = execute_ffmpeg(target, f"removegrain=m1={args.removegrain}", "Removegrain") or target
    if args.deband: target = execute_ffmpeg(target, f"deband={args.deband}", "Deband") or target
    if args.sharpen: target = execute_ffmpeg(target, "unsharp=5:5:1.0:5:5:0.0", "Sharpen") or target
    if args.scale: target = execute_ffmpeg(target, "scale=iw*2:ih*2:flags=lanczos", "Super-Res") or target
    if args.deshake: target = execute_ffmpeg(target, "deshake", "Deshake") or target
    if args.edge_detect: target = execute_ffmpeg(target, "edgedetect", "Edge-Detect") or target
    if args.color_correct: target = execute_ffmpeg(target, "eq=contrast=1.1:brightness=0.05:saturation=1.2", "Color Correct") or target
    if args.crop: target = execute_ffmpeg(target, f"crop={args.crop}", "Crop") or target
    
    if args.rotate:
        vf = "transpose=1" if args.rotate == "90" else ("transpose=2,transpose=2" if args.rotate == "180" else "transpose=2")
        target = execute_ffmpeg(target, vf, "Rotate") or target
        
    if args.flip:
        vf = "hflip" if args.flip == "h" else "vflip"
        target = execute_ffmpeg(target, vf, "Flip") or target

    if args.slo_mo: target = execute_speed_change(target, args.slo_mo, "Slo-Mo") or target
    if args.speed_up: target = execute_speed_change(target, str(1.0/float(args.speed_up)), "Speed-up") or target
    if args.convert: target = execute_conversion(target, args.convert) or target

if __name__ == "__main__":
    main()
