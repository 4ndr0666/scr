#!/usr/bin/env python3
"""
Ψ-4NDR0666 FFX Orchestrator (The Ephemeral State Machine)
Canonical Source of Truth: Final Superset v5.0.0 Port
Enforces strict isolation, aggressive resource reclamation, and definitive FFmpeg best practices.
"""

import os
import sys
import json
import shutil
import random
import argparse
import tempfile
import subprocess
from pathlib import Path
from dataclasses import dataclass, asdict
from typing import List, Dict, Optional, Tuple, Any

# =============================================================================
# XDG & GLOBAL CONSTANTS
# =============================================================================

XDG_CONFIG_HOME = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
XDG_DATA_HOME = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share"))
XDG_CACHE_HOME = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))

FFX_CONFIG_DIR = XDG_CONFIG_HOME / "ffx"
FFX_LOG_DIR = XDG_DATA_HOME / "ffx"
FFX_CACHE_DIR = XDG_CACHE_HOME / "ffx"
FFX_DEFAULTS = FFX_CONFIG_DIR / "defaults.json"

for d in (FFX_CONFIG_DIR, FFX_LOG_DIR, FFX_CACHE_DIR):
    d.mkdir(parents=True, exist_ok=True)

CANVAS_W = 1920
CANVAS_H = 1080

# =============================================================================
# CONFIGURATION MANAGEMENT
# =============================================================================

@dataclass
class Config:
    # Ephemeral/CLI Options
    verbose: bool = False
    dry_run: bool = False
    remove_audio: bool = False
    composite_mode: bool = False
    max_1080: bool = False
    output_dir: str = str(Path.cwd())
    fps: str = ""
    pts_factor: str = ""
    interpolate: bool = False
    timeout: int = 300
    
    # Persistent Advanced Options
    adv_container: str = "mp4"
    adv_res: str = f"{CANVAS_W}x{CANVAS_H}"
    adv_fps: str = "60"
    adv_codec: str = "libx264"
    adv_pix_fmt: str = "yuv420p"
    adv_crf: str = "18"
    adv_br: str = "10M"
    adv_multipass: str = "false"
    adv_quality_mode: str = "crf"

def load_config() -> Config:
    c = Config()
    if FFX_DEFAULTS.exists():
        try:
            with open(FFX_DEFAULTS, 'r') as f:
                data = json.load(f)
                for k, v in data.items():
                    if hasattr(c, k):
                        setattr(c, k, v)
        except Exception:
            pass
    return c

def save_config(c: Config):
    # Only save adv_ properties to avoid polluting defaults with ephemeral CLI flags
    save_data = {k: v for k, v in asdict(c).items() if k.startswith('adv_')}
    with open(FFX_DEFAULTS, 'w') as f:
        json.dump(save_data, f, indent=2)

# =============================================================================
# THE EPHEMERAL STATE MACHINE (SANDBOX)
# =============================================================================

class SandboxManager:
    """
    Context manager guaranteeing ruthless resource reclamation.
    Violently destroys the worktree on exit, regardless of exceptions.
    """
    def __init__(self, prefix: str = "ffx_sandbox_"):
        self.prefix = prefix
        self.path: Optional[Path] = None

    def __enter__(self) -> Path:
        self.path = Path(tempfile.mkdtemp(prefix=self.prefix))
        return self.path

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self.path and self.path.exists():
            shutil.rmtree(self.path, ignore_errors=True)

# =============================================================================
# LOGGING & EXECUTION ENGINE (EAFP)
# =============================================================================

def log(msg: str, level: str = "INFO"):
    prefix = {"INFO": "[Ψ]", "WARN": "[!]", "ERROR": "[X]"}.get(level, "[*]")
    out = f"{prefix} {msg}"
    print(out, file=sys.stderr if level == "ERROR" else sys.stdout)
    with open(FFX_LOG_DIR / "ffx.log", "a") as f:
        f.write(out + "\n")

def execute_ffmpeg(cmd: List[str], config: Config, cwd: Optional[Path] = None, capture_out: bool = False) -> subprocess.CompletedProcess:
    """Forces execution and strictly bounds the subprocess. Catches missing binaries."""
    if config.dry_run:
        log(f"[DRY-RUN] {' '.join(cmd)}")
        return subprocess.CompletedProcess(args=cmd, returncode=0, stdout="", stderr="")

    if not config.verbose and "-hide_banner" not in cmd:
        cmd.insert(1, "-hide_banner")
        if "-loglevel" not in cmd:
            cmd.insert(2, "-loglevel")
            cmd.insert(3, "error")

    if config.verbose:
        log(f"Executing: {' '.join(cmd)}")

    timeout_val = config.timeout if config.timeout > 0 else None

    try:
        res = subprocess.run(
            cmd, 
            cwd=cwd,
            check=True, 
            timeout=timeout_val,
            capture_output=capture_out,
            text=True if capture_out else False,
            stdout=sys.stdout if config.verbose and not capture_out else subprocess.PIPE,
            stderr=sys.stderr if config.verbose and not capture_out else subprocess.PIPE
        )
        return res
    except subprocess.CalledProcessError as e:
        log(f"FFmpeg execution failed with exit code {e.returncode}", "ERROR")
        if not config.verbose and getattr(e, 'stderr', None):
            log(f"FFmpeg Error Output:\n{e.stderr if isinstance(e.stderr, str) else e.stderr.decode('utf-8', errors='ignore')}", "ERROR")
        sys.exit(1)
    except subprocess.TimeoutExpired:
        log(f"FFmpeg execution exceeded timeout of {timeout_val} seconds. Terminated.", "ERROR")
        sys.exit(1)
    except FileNotFoundError:
        log(f"Executable not found: {cmd[0]}. Ensure it is installed and in PATH.", "ERROR")
        sys.exit(1)

# =============================================================================
# PROBE & UTILITY HELPERS
# =============================================================================

def format_bytes(b: int) -> str:
    for unit in ['B', 'KB', 'MB', 'GB']:
        if b < 1024.0:
            return f"{b:.2f}{unit}"
        b /= 1024.0
    return f"{b:.2f}TB"

def get_output_path(input_file: str, suffix: str, config: Config, manual_out: Optional[str] = None) -> Path:
    if manual_out:
        return Path(manual_out)
    in_p = Path(input_file)
    out_dir = Path(config.output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    return out_dir / f"{in_p.stem}_{suffix}.{config.adv_container}"

def probe_file(file_path: Path) -> dict:
    cmd = ["ffprobe", "-v", "quiet", "-print_format", "json", "-show_format", "-show_streams", str(file_path)]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return json.loads(res.stdout)
    except Exception:
        return {}

def is_interlaced(file_path: Path) -> bool:
    cmd = ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=field_order", "-of", "default=noprint_wrappers=1:nokey=1", str(file_path)]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, check=True).stdout.strip()
        return res in ['tt', 'bb', 'tb', 'bt']
    except Exception:
        return False

def get_audio_opts(config: Config) -> List[str]:
    return ["-an"] if config.remove_audio else ["-c:a", "copy"]

def get_encode_opts(config: Config) -> List[str]:
    if config.adv_quality_mode == "qp0":
        return ["-c:v", config.adv_codec, "-qp", "0", "-preset", "medium"]
    return ["-c:v", config.adv_codec, "-crf", config.adv_crf, "-preset", "medium"]

# =============================================================================
# MEDIA HEALING ARCHITECTURE
# =============================================================================

def check_moov_atom(file_path: Path) -> bool:
    cmd = ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "default=noprint_wrappers=1:nokey=1", str(file_path)]
    try:
        subprocess.run(cmd, capture_output=True, check=True)
        return True
    except subprocess.CalledProcessError:
        return False

def moov_fallback(in_file: Path, out_file: Path, config: Config):
    log(f"moov_fallback: re-encoding {in_file.name}", "WARN")
    cmd = ["ffmpeg", "-y", "-i", str(in_file)] + get_encode_opts(config) + get_audio_opts(config) + ["-movflags", "+faststart", str(out_file)]
    execute_ffmpeg(cmd, config)

def check_dts_for_file(file_path: Path) -> bool:
    cmd = ["ffprobe", "-v", "error", "-select_streams", "v", "-show_entries", "frame=pkt_dts_time", "-of", "csv=p=0", str(file_path)]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        pts_list = []
        for line in res.stdout.strip().split('\n'):
            if line.strip():
                try:
                    pts_list.append(float(line.strip()))
                except ValueError:
                    continue
        for i in range(1, len(pts_list)):
            if pts_list[i] < pts_list[i-1]:
                return False
        return True
    except Exception:
        return True # Default to true if unreadable

def fix_dts(file_path: Path, config: Config, sandbox: Path) -> Path:
    tmp_out = sandbox / f"{file_path.stem}_dtsfix.mp4"
    cmd = ["ffmpeg", "-y", "-fflags", "+genpts", "-i", str(file_path), "-c:v", "copy"] + get_audio_opts(config) + ["-movflags", "+faststart", str(tmp_out)]
    try:
        execute_ffmpeg(cmd, config)
        return tmp_out
    except SystemExit:
        log(f"DTS remux failed; lossless re-encode for {file_path.name}", "WARN")
        cmd_enc = ["ffmpeg", "-y", "-fflags", "+genpts", "-i", str(file_path), "-c:v", config.adv_codec, "-qp", "0", "-preset", "ultrafast"] + get_audio_opts(config) + [str(tmp_out)]
        execute_ffmpeg(cmd_enc, config)
        return tmp_out

def ensure_dts_correct(file_path: str, config: Config, sandbox: Path) -> Path:
    p = Path(file_path)
    if not p.exists():
        log(f"ensure_dts_correct: {file_path} not found.", "ERROR")
        sys.exit(1)
    if not check_dts_for_file(p):
        log(f"DTS issues detected in {p.name}. Fixing...", "WARN")
        fixed = fix_dts(p, config, sandbox)
        if not fixed.exists() or fixed.stat().st_size == 0:
            log(f"DTS fix produced empty output for {p.name}.", "ERROR")
            sys.exit(1)
        return fixed
    return p

# =============================================================================
# SUB-COMMAND: PROBE
# =============================================================================

def cmd_probe(input_file: str, config: Config):
    p = Path(input_file)
    if not p.exists():
        log(f"File not found: {input_file}", "ERROR")
        sys.exit(1)
        
    data = probe_file(p)
    fmt = data.get("format", {})
    streams = data.get("streams", [])
    vid = next((s for s in streams if s.get("codec_type") == "video"), {})
    
    sz = p.stat().st_size
    duration = fmt.get("duration", "0")
    res = f"{vid.get('width', 'unknown')}x{vid.get('height', 'unknown')}"
    fps = vid.get("avg_frame_rate", "0/0")
    
    print(f"\n# === FFX Probe ===")
    print(f"File:       {p.name}")
    print(f"Size:       {format_bytes(sz)}")
    print(f"Format:     {fmt.get('format_name', 'unknown')}")
    print(f"Resolution: {res}")
    print(f"FPS:        {fps}")
    print(f"Duration:   {duration}s\n")

# =============================================================================
# SUB-COMMAND: PROCESS
# =============================================================================

def cmd_process(input_file: str, output_file: Optional[str], config: Config):
    out_path = get_output_path(input_file, "processed", config, output_file)
    
    with SandboxManager() as sandbox:
        fixed = ensure_dts_correct(input_file, config, sandbox)
        
        target_res = config.adv_res
        if config.max_1080:
            data = probe_file(fixed)
            vid = next((s for s in data.get("streams", []) if s.get("codec_type") == "video"), {})
            h = int(vid.get("height", 0))
            if h > 1080:
                log("Clamping to 1080p.")
                target_res = f"{CANVAS_W}x{CANVAS_H}"
                
        deint = "yadif=deint=interlaced" if is_interlaced(fixed) else "null"
        scale_f = f"scale={target_res}:flags=lanczos:force_original_aspect_ratio=decrease"
        vf = f"{deint},{scale_f}" if deint != "null" else scale_f
        
        target_fps = config.fps if config.fps else config.adv_fps
        
        cmd = ["ffmpeg", "-y", "-i", str(fixed), "-vf", vf, "-r", str(target_fps)] + get_encode_opts(config) + get_audio_opts(config) + ["-pix_fmt", config.adv_pix_fmt, "-movflags", "+faststart", str(out_path)]
        execute_ffmpeg(cmd, config)
        
        if not check_moov_atom(out_path):
            moov_fallback(fixed, out_path, config)
            
        log(f"Processed: {out_path}")

# =============================================================================
# SUB-COMMAND: MERGE (With Superset Filter Fallback)
# =============================================================================

def cmd_merge(inputs: List[str], output_file: Optional[str], config: Config):
    out_path = get_output_path("output", "merged", config, output_file)
    
    with SandboxManager("ffx_merge_") as sandbox:
        fixed_files = [ensure_dts_correct(inp, config, sandbox) for inp in inputs]
        
        # Check resolution uniformity
        uniform = True
        first_res = None
        for f in fixed_files:
            data = probe_file(f)
            vid = next((s for s in data.get("streams", []) if s.get("codec_type") == "video"), {})
            res = f"{vid.get('width')}x{vid.get('height')}"
            if first_res is None:
                first_res = res
            elif res != first_res:
                uniform = False
                break
                
        requires_encode = not uniform or config.max_1080 or config.fps or config.pts_factor
        
        concat_list = sandbox / "concat.txt"
        with open(concat_list, "w", encoding="utf-8") as f:
            for inp in fixed_files:
                f.write(f"file '{inp.absolute()}'\n")

        cmd = ["ffmpeg", "-y"]
        
        if requires_encode:
            log("Streams non-uniform or filters requested; falling back to filter_complex re-encode.")
            vf_chain = []
            if config.max_1080 or not uniform:
                vf_chain.append(f"scale={CANVAS_W}:{CANVAS_H}:flags=lanczos:force_original_aspect_ratio=decrease,pad={CANVAS_W}:{CANVAS_H}:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1")
            if config.fps:
                vf_chain.append(f"fps={config.fps}")
            if config.pts_factor:
                vf_chain.append(f"setpts={config.pts_factor}*PTS")

            cmd.extend(["-f", "concat", "-safe", "0", "-i", str(concat_list)])
            if vf_chain:
                cmd.extend(["-vf", ",".join(vf_chain)])
            
            # If re-encoding, must encode audio if kept
            if config.remove_audio:
                cmd.append("-an")
            else:
                cmd.extend(["-c:a", "aac", "-b:a", "192k"])
                
            cmd.extend(get_encode_opts(config))
            cmd.extend(["-pix_fmt", config.adv_pix_fmt])
        else:
            log("Streams uniform; executing pristine stream copy.")
            cmd.extend(["-f", "concat", "-safe", "0", "-i", str(concat_list)])
            if config.remove_audio:
                cmd.extend(["-c:v", "copy", "-an"])
            else:
                cmd.extend(["-c", "copy"])

        cmd.extend(["-movflags", "+faststart", str(out_path)])
        execute_ffmpeg(cmd, config)
        log(f"Merged: {out_path}")

# =============================================================================
# SUB-COMMAND: LOOPERANG
# =============================================================================

def cmd_looperang(input_file: str, output_file: Optional[str], config: Config):
    out_path = get_output_path(input_file, "looperang", config, output_file)
    
    with SandboxManager() as sandbox:
        fixed = ensure_dts_correct(input_file, config, sandbox)
        tmp_rev = sandbox / f"{fixed.stem}_rev.mp4"
        
        cmd_rev = ["ffmpeg", "-y", "-i", str(fixed), "-vf", "reverse", "-af", "areverse"] + get_audio_opts(config) + ["-c:v", config.adv_codec, "-qp", "0", "-preset", "ultrafast", str(tmp_rev)]
        execute_ffmpeg(cmd_rev, config)
        
        cl = sandbox / "concat.txt"
        with open(cl, "w") as f:
            f.write(f"file '{fixed.absolute()}'\n")
            f.write(f"file '{tmp_rev.absolute()}'\n")
            
        cmd_cat = ["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", str(cl), "-c", "copy", str(out_path)]
        execute_ffmpeg(cmd_cat, config)
        
        if not check_moov_atom(out_path):
            moov_fallback(fixed, out_path, config)
            
        log(f"Looperang: {out_path}")

# =============================================================================
# SUB-COMMAND: SLOWMO
# =============================================================================

def cmd_slowmo(input_file: str, factor_str: str, output_file: Optional[str], config: Config):
    out_path = get_output_path(input_file, "slowmo", config, output_file)
    factor = config.pts_factor if config.pts_factor else factor_str
    try:
        f_val = float(factor)
        if f_val <= 0: raise ValueError
    except ValueError:
        log("Slow factor must be a positive number.", "ERROR")
        sys.exit(1)
        
    pts_adj = 1.0 / f_val
    fps = config.fps if config.fps else config.adv_fps
    vf = f"setpts={pts_adj}*PTS"
    
    if config.interpolate:
        if not config.fps:
            fps = "120"
        vf = f"minterpolate=fps={fps}:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1,{vf}"

    cmd = ["ffmpeg", "-y", "-i", input_file]
    
    if not config.remove_audio:
        # Construct atempo chain
        sp = 1.0 / pts_adj
        af = ""
        while sp < 0.5:
            af += "atempo=0.5,"
            sp /= 0.5
        while sp > 2.0:
            af += "atempo=2.0,"
            sp /= 2.0
        af += f"atempo={sp}"
        cmd.extend(["-filter_complex", f"[0:v]{vf}[v];[0:a]{af}[a]", "-map", "[v]", "-map", "[a]", "-c:a", "aac"])
    else:
        cmd.extend(["-vf", vf, "-an"])

    cmd.extend(["-r", fps] + get_encode_opts(config) + ["-pix_fmt", config.adv_pix_fmt, "-movflags", "+faststart", str(out_path)])
    
    with SandboxManager() as sandbox:
        execute_ffmpeg(cmd, config)
        if not check_moov_atom(out_path):
            moov_fallback(Path(input_file), out_path, config)
    log(f"Slowmo: {out_path}")

# =============================================================================
# SUB-COMMAND: FILTER (Pre-Set Engine)
# =============================================================================

def cmd_filter(input_file: str, preset: str, output_file: Optional[str], custom: Optional[str], config: Config):
    out_path = get_output_path(input_file, "filtered", config, output_file)
    
    presets = {
        "enhance": "eq=brightness=0.1:contrast=1.2:saturation=1.2",
        "skintone": "eq=brightness=0.15:contrast=1.3:saturation=0.9,colorbalance=rs=-0.1:gs=0.05:bs=0.05",
        "denoise": "hqdn3d=2:1:2:3",
        "cross_process": "curves=preset=cross_process",
        "hdr2sdr": "zscale=t=linear:npl=100,format=gbrpf32le,zscale=p=bt709,tonemap=tonemap=hable,zscale=t=bt709:m=bt709:r=tv,format=yuv420p",
        "smooth": "minterpolate=fps=60,tblend=all_mode=average,framestep=2",
        "whitecal": "colorbalance=rs=-0.05:gs=0.05:bs=0.10"
    }
    
    vfilter = custom if custom else presets.get(preset)
    if not vfilter:
        log(f"Unknown preset: {preset}", "ERROR")
        sys.exit(1)
        
    with SandboxManager() as sandbox:
        fixed = ensure_dts_correct(input_file, config, sandbox)
        deint = "yadif=deint=interlaced" if is_interlaced(fixed) else "null"
        full_vf = f"{deint},{vfilter}" if deint != "null" else vfilter
        
        cmd = ["ffmpeg", "-y", "-i", str(fixed), "-vf", full_vf] + get_encode_opts(config) + get_audio_opts(config) + ["-pix_fmt", config.adv_pix_fmt, "-movflags", "+faststart", str(out_path)]
        execute_ffmpeg(cmd, config)
        
        if not check_moov_atom(out_path):
            moov_fallback(fixed, out_path, config)
    log(f"Filtered: {out_path}")

# =============================================================================
# METADATA & UTILS
# =============================================================================

def cmd_fix(input_file: str, output_file: Optional[str], config: Config):
    out_path = get_output_path(input_file, "fixed", config, output_file)
    with SandboxManager() as sandbox:
        fixed = ensure_dts_correct(input_file, config, sandbox)
        if fixed.name != Path(input_file).name:
            shutil.move(str(fixed), str(out_path))
            log(f"Fixed (DTS corrected): {out_path}")
        else:
            shutil.copy(input_file, str(out_path))
            log(f"No DTS issues found; copied: {out_path}")

def cmd_clean(input_file: str, output_file: Optional[str], config: Config):
    out_path = get_output_path(input_file, "cleaned", config, output_file)
    cmd = ["ffmpeg", "-y", "-i", input_file, "-map_metadata", "-1", "-c", "copy"] + get_audio_opts(config) + [str(out_path)]
    execute_ffmpeg(cmd, config)
    log(f"Cleaned metadata: {out_path}")

def cmd_clip(input_file: str, start: str, end: str, output_file: Optional[str], config: Config):
    out_path = get_output_path(input_file, "clip", config, output_file)
    cmd = ["ffmpeg", "-y", "-ss", start, "-to", end, "-i", input_file, "-c", "copy"] + get_audio_opts(config) + [str(out_path)]
    execute_ffmpeg(cmd, config)
    log(f"Clipped: {out_path}")

def cmd_cache_clean():
    shutil.rmtree(FFX_CACHE_DIR, ignore_errors=True)
    FFX_CACHE_DIR.mkdir(parents=True, exist_ok=True)
    log("Cache cleaned.")

# =============================================================================
# THE COMPOSITE ENGINE (v3.0 - AR Intelligence & Randomization)
# =============================================================================

def _probe_duration(file_path: str) -> float:
    data = probe_file(Path(file_path))
    try:
        return float(data.get("format", {}).get("duration", 60.0))
    except ValueError:
        return 60.0

def _probe_wh(file_path: str) -> Tuple[int, int]:
    data = probe_file(Path(file_path))
    vid = next((s for s in data.get("streams", []) if s.get("codec_type") == "video"), {})
    try:
        return int(vid.get("width", CANVAS_W)), int(vid.get("height", CANVAS_H))
    except ValueError:
        return CANVAS_W, CANVAS_H

def _ar_score(vw: int, vh: int, cw: int, ch: int) -> int:
    if vh <= 0 or ch <= 0:
        return 0
    v_ratio = vw / vh
    c_ratio = cw / ch
    r = v_ratio / c_ratio
    if r < 1:
        r = 1 / r
    return int(100 / r)

def _build_cell_vf(cw: int, ch: int, norm_fps: int = 30) -> str:
    # Essential v3.0 fix: fps+setpts zeroing
    return f"fps={norm_fps},setpts=PTS-STARTPTS,scale={cw}:{ch}:flags=lanczos:force_original_aspect_ratio=decrease,pad={cw}:{ch}:(ow-iw)/2:(oh-ih)/2:color=black,setsar=1"

LAYOUTS = [
    {"id": "fullscreen", "n": 1, "slots": [(1920,1080)], "fc": "[0:v]CELL0[v]"},
    {"id": "hstack", "n": 2, "slots": [(960,1080), (960,1080)], "fc": "[0:v]CELL0[s0];[1:v]CELL1[s1];[s0][s1]hstack=inputs=2[v]"},
    {"id": "vstack", "n": 2, "slots": [(1920,540), (1920,540)], "fc": "[0:v]CELL0[s0];[1:v]CELL1[s1];[s0][s1]vstack=inputs=2[v]"},
    {"id": "top1_bot2", "n": 3, "slots": [(1920,540), (960,540), (960,540)], "fc": "[0:v]CELL0[s0];[1:v]CELL1[s1];[2:v]CELL2[s2];[s1][s2]hstack=inputs=2[bot];[s0][bot]vstack=inputs=2[v]"},
    {"id": "top2_bot1", "n": 3, "slots": [(960,540), (960,540), (1920,540)], "fc": "[0:v]CELL0[s0];[1:v]CELL1[s1];[2:v]CELL2[s2];[s0][s1]hstack=inputs=2[top];[top][s2]vstack=inputs=2[v]"},
    {"id": "left1_right2", "n": 3, "slots": [(960,1080), (960,540), (960,540)], "fc": "[0:v]CELL0[s0];[1:v]CELL1[s1];[2:v]CELL2[s2];[s1][s2]vstack=inputs=2[right];[s0][right]hstack=inputs=2[v]"},
    {"id": "left2_right1", "n": 3, "slots": [(960,540), (960,540), (960,1080)], "fc": "[0:v]CELL0[s0];[1:v]CELL1[s1];[2:v]CELL2[s2];[s0][s1]vstack=inputs=2[left];[left][s2]hstack=inputs=2[v]"},
    {"id": "grid2x2", "n": 4, "slots": [(960,540), (960,540), (960,540), (960,540)], "fc": "[0:v]CELL0[s0];[1:v]CELL1[s1];[2:v]CELL2[s2];[3:v]CELL3[s3];[s0][s1]hstack=inputs=2[top];[s2][s3]hstack=inputs=2[bot];[top][bot]vstack=inputs=2[v]"},
    {"id": "row4", "n": 4, "slots": [(480,1080), (480,1080), (480,1080), (480,1080)], "fc": "[0:v]CELL0[s0];[1:v]CELL1[s1];[2:v]CELL2[s2];[3:v]CELL3[s3];[s0][s1][s2][s3]hstack=inputs=4[v]"}
]

def _eval_layout(layout: dict, files_wh: List[Tuple[str, int, int]]) -> Tuple[int, List[str]]:
    f_sorted = sorted(files_wh, key=lambda x: (x[1]/x[2]) if x[2] > 0 else 0)
    s_sorted = sorted(enumerate(layout["slots"]), key=lambda x: (x[1][0]/x[1][1]))
    
    total_score = 0
    assignment = [None] * layout["n"]
    for i in range(layout["n"]):
        s_idx, (cw, ch) = s_sorted[i]
        fname, vw, vh = f_sorted[i]
        assignment[s_idx] = fname
        total_score += _ar_score(vw, vh, cw, ch)
    return total_score, assignment

def cmd_composite(inputs: List[str], output_file: Optional[str], config: Config):
    out_path = get_output_path("output", "composite", config, output_file)
    
    if not inputs:
        log("Composite requires input files.", "ERROR")
        sys.exit(1)

    norm_fps = int(config.fps) if config.fps else int(float(config.adv_fps))
    
    files = list(inputs)
    random.shuffle(files)

    with SandboxManager("ffx_composite_") as sandbox:
        # Pre-process DTS to avoid drops
        fixed_files = [ensure_dts_correct(f, config, sandbox) for f in files]
        
        part_files = []
        batch_num = 1
        idx = 0
        total = len(fixed_files)

        while idx < total:
            remaining = total - idx
            max_n = min(remaining, 4)
            n = random.randint(1, max_n)
            
            batch = fixed_files[idx : idx+n]
            idx += n
            
            batch_wh = [(str(f.absolute()), *_probe_wh(str(f))) for f in batch]
            cands = [l for l in LAYOUTS if l["n"] == n]
            
            best_score = -1
            best_order = []
            best_layout = None
            
            for l in cands:
                score, order = _eval_layout(l, batch_wh)
                if score > best_score:
                    best_score = score
                    best_order = order
                    best_layout = l
                elif score == best_score:
                    if random.choice([True, False]):
                        best_order = order
                        best_layout = l

            fc = best_layout["fc"]
            for i, (cw, ch) in enumerate(best_layout["slots"]):
                cvf = _build_cell_vf(cw, ch, norm_fps)
                fc = fc.replace(f"CELL{i}", cvf)

            trim_shortest = random.choice([True, False])
            ff_inputs = []
            dur_flags = []
            
            if trim_shortest:
                for f in best_order:
                    ff_inputs.extend(["-i", f])
                dur_flags = ["-shortest"]
            else:
                max_dur = 0.0
                for f in best_order:
                    ff_inputs.extend(["-stream_loop", "-1", "-i", f])
                    max_dur = max(max_dur, _probe_duration(f))
                dur_flags = ["-t", str(max_dur)]

            part_file = sandbox / f"part_{batch_num:04d}.mp4"
            
            cmd = ["ffmpeg", "-y"] + ff_inputs + [
                "-filter_complex", fc,
                "-map", "[v]",
                "-map", "0:a?"
            ] + get_encode_opts(config) + [
                "-profile:v", "high", "-level:v", "4.0",
                "-pix_fmt", config.adv_pix_fmt,
                "-threads", "0", "-r", str(norm_fps),
                "-c:a", "aac", "-b:a", "192k", "-ac", "2",
                "-max_muxing_queue_size", "1024",
                "-movflags", "+faststart"
            ] + dur_flags + [str(part_file)]
            
            execute_ffmpeg(cmd, config, cwd=sandbox)
            part_files.append(part_file)
            batch_num += 1

        if len(part_files) == 1:
            shutil.move(str(part_files[0]), str(out_path))
        else:
            concat_list = sandbox / "concat.txt"
            with open(concat_list, "w", encoding="utf-8") as f:
                for pf in part_files:
                    f.write(f"file '{pf.name}'\n")
            cmd_cat = [
                "ffmpeg", "-y",
                "-f", "concat", "-safe", "0",
                "-i", str(concat_list),
                "-c", "copy",
                "-movflags", "+faststart",
                str(out_path)
            ]
            execute_ffmpeg(cmd_cat, config, cwd=sandbox)

        log(f"Composite complete: {out_path}")

# =============================================================================
# CLI ROUTER
# =============================================================================

def cli_router():
    parser = argparse.ArgumentParser(description="Ψ-4NDR0666 FFX Orchestrator - v5.0.0 Superset", prog="fx")
    
    # Global Flags
    parser.add_argument("-v", "--verbose", action="store_true", help="Enable verbose output")
    parser.add_argument("--dry-run", action="store_true", help="Print FFmpeg commands without executing")
    parser.add_argument("-an", "--remove-audio", action="store_true", help="Strip audio tracks")
    parser.add_argument("-C", "--composite", action="store_true", help="Composite mode routing")
    parser.add_argument("-P", "--max-1080", action="store_true", help="Downscale to 1080p maximum")
    parser.add_argument("-o", "--output-dir", type=str, default=os.getcwd(), help="Specify output directory")
    parser.add_argument("-f", "--fps", type=str, help="Target FPS")
    parser.add_argument("-p", "--pts", type=str, help="Adjust PTS (e.g., 0.5 for 2x speed)")
    parser.add_argument("-i", "--interpolate", action="store_true", help="Enable motion interpolation")
    parser.add_argument("--timeout", type=int, default=0, help="Kill FFmpeg after SECS")

    subparsers = parser.add_subparsers(dest="command", required=True)

    # Subcommands
    p_probe = subparsers.add_parser("probe")
    p_probe.add_argument("input", help="Input file")

    p_proc = subparsers.add_parser("process")
    p_proc.add_argument("input", help="Input file")
    p_proc.add_argument("output", nargs="?", help="Output file")

    p_merge = subparsers.add_parser("merge")
    p_merge.add_argument("inputs", nargs="+", help="Input files")
    p_merge.add_argument("-o", "--output", help="Output file override")

    p_loop = subparsers.add_parser("looperang")
    p_loop.add_argument("input", help="Input file")
    p_loop.add_argument("output", nargs="?", help="Output file")

    p_slow = subparsers.add_parser("slowmo")
    p_slow.add_argument("input", help="Input file")
    p_slow.add_argument("factor", help="Slow factor")
    p_slow.add_argument("output", nargs="?", help="Output file")

    p_filter = subparsers.add_parser("filter")
    p_filter.add_argument("input", help="Input file")
    p_filter.add_argument("output", nargs="?", help="Output file")
    group = p_filter.add_mutually_exclusive_group(required=True)
    group.add_argument("--preset", "-P", type=str, choices=["enhance", "skintone", "denoise", "cross_process", "hdr2sdr", "smooth", "whitecal"])
    group.add_argument("--filter", "-F", type=str, help="Custom filter string")

    p_fix = subparsers.add_parser("fix")
    p_fix.add_argument("input", help="Input file")
    p_fix.add_argument("output", nargs="?", help="Output file")

    p_clean = subparsers.add_parser("clean")
    p_clean.add_argument("input", help="Input file")
    p_clean.add_argument("output", nargs="?", help="Output file")

    p_clip = subparsers.add_parser("clip")
    p_clip.add_argument("input", help="Input file")
    p_clip.add_argument("start", help="Start time")
    p_clip.add_argument("end", help="End time")
    p_clip.add_argument("output", nargs="?", help="Output file")

    p_comp = subparsers.add_parser("composite")
    p_comp.add_argument("inputs", nargs="+", help="Input files")

    subparsers.add_parser("cache-clean")

    args, unknown = parser.parse_known_args()

    # Implicit Routing
    if args.composite and args.command != "composite":
        inputs = []
        if hasattr(args, "input") and args.input: inputs.append(args.input)
        if hasattr(args, "inputs") and args.inputs: inputs.extend(args.inputs)
        inputs.extend(unknown)
        args.command = "composite"
        args.inputs = inputs

    # State Load
    config = load_config()
    config.verbose = args.verbose
    config.dry_run = args.dry_run
    config.remove_audio = args.remove_audio
    config.composite_mode = args.composite
    config.max_1080 = args.max_1080
    config.output_dir = args.output_dir
    config.fps = args.fps or ""
    config.pts_factor = args.pts or ""
    config.interpolate = args.interpolate
    config.timeout = args.timeout

    # Dispatch
    if args.command == "probe":
        cmd_probe(args.input, config)
    elif args.command == "process":
        cmd_process(args.input, args.output, config)
    elif args.command == "merge":
        cmd_merge(args.inputs, args.output if hasattr(args, 'output') else None, config)
    elif args.command == "looperang":
        cmd_looperang(args.input, args.output, config)
    elif args.command == "slowmo":
        cmd_slowmo(args.input, args.factor, args.output, config)
    elif args.command == "filter":
        cmd_filter(args.input, args.preset, args.output, args.filter, config)
    elif args.command == "fix":
        cmd_fix(args.input, args.output, config)
    elif args.command == "clean":
        cmd_clean(args.input, args.output, config)
    elif args.command == "clip":
        cmd_clip(args.input, args.start, args.end, args.output, config)
    elif args.command == "composite":
        cmd_composite(args.inputs, None, config)
    elif args.command == "cache-clean":
        cmd_cache_clean()

if __name__ == "__main__":
    cli_router()
