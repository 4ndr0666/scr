#!/usr/bin/env python3
"""
TITLE:       mkicons.py
AUTHOR:      4ndr0666
DESCRIPTION: Unified icon + banner generator. Produces arbitrary-sized outputs from a
             source image. Square targets use direct LANCZOS resize; non-square targets
             use center-crop-to-ratio to prevent distortion. Fully interactive: prompts
             for source file, output directory, and as many custom outputs as needed.
             Defaults mirror both legacy scripts so existing workflows require zero changes.

USAGE (interactive):
    python3 mkicons.py

USAGE (non-interactive / legacy drop-in for mkicons.py):
    SOURCE_FILE=source_icon.png OUTPUT_DIR=icons python3 mkicons.py --defaults-icons

USAGE (non-interactive / legacy drop-in for mkicons2.py):
    SOURCE_FILE=source_banner.png OUTPUT_DIR=dist python3 mkicons.py --defaults-banner
"""

import os
import sys
import argparse

try:
    from PIL import Image
except ImportError:
    print("Error: Pillow is required.  Install with:  pip install Pillow")
    sys.exit(1)


# ---------------------------------------------------------------------------
# Default size presets (preserved from both legacy scripts — superset)
# ---------------------------------------------------------------------------

DEFAULTS_ICONS: list[tuple[str, int, int]] = [
    ("icon16.png",  16,  16),
    ("icon48.png",  48,  48),
    ("icon128.png", 128, 128),
]

DEFAULTS_BANNER: list[tuple[str, int, int]] = [
    ("icon16.png",         16,   16),
    ("icon48.png",         48,   48),
    ("icon128.png",        128,  128),
    ("banner_1100x280.png", 1100, 280),
]


# ---------------------------------------------------------------------------
# Core image transforms (superset of both legacy scripts)
# ---------------------------------------------------------------------------

def center_crop_to_ratio(img: Image.Image, target_w: int, target_h: int) -> Image.Image:
    """
    Crop the image to the target aspect ratio from the center, then resize.
    Prevents stretching on non-square (e.g. banner) outputs.
    Sourced from mkicons2.py — preserved verbatim in logic.
    """
    orig_w, orig_h = img.size
    target_ratio   = target_w / target_h
    orig_ratio     = orig_w  / orig_h

    if orig_ratio > target_ratio:
        # Source wider than target → crop sides
        new_w  = int(target_ratio * orig_h)
        offset = (orig_w - new_w) // 2
        img    = img.crop((offset, 0, offset + new_w, orig_h))
    else:
        # Source taller than target → crop top/bottom
        new_h  = int(orig_w / target_ratio)
        offset = (orig_h - new_h) // 2
        img    = img.crop((0, offset, orig_w, offset + new_h))

    return img.resize((target_w, target_h), Image.Resampling.LANCZOS)


def resize_square(img: Image.Image, size: int) -> Image.Image:
    """Direct LANCZOS resize for square targets. Sourced from mkicons.py."""
    return img.resize((size, size), Image.Resampling.LANCZOS)


def process_target(
    img: Image.Image,
    filename: str,
    w: int,
    h: int,
    output_dir: str,
) -> None:
    """
    Dispatch to the correct transform and write the output file.
    Square  → direct resize (mkicons.py behaviour).
    Non-square → center-crop-to-ratio (mkicons2.py behaviour).
    """
    if w == h:
        final = resize_square(img, w)
    else:
        final = center_crop_to_ratio(img, w, h)

    out_path = os.path.join(output_dir, filename)
    final.save(out_path)
    print(f"  [+] {out_path}  ({w}×{h})")


# ---------------------------------------------------------------------------
# Interactive prompt helpers
# ---------------------------------------------------------------------------

def prompt(message: str, default: str = "") -> str:
    suffix = f" [{default}]" if default else ""
    try:
        val = input(f"{message}{suffix}: ").strip()
    except (EOFError, KeyboardInterrupt):
        print()
        sys.exit(0)
    return val if val else default


def prompt_source() -> str:
    while True:
        path = prompt("Source image path", "source_icon.png")
        if os.path.isfile(path):
            return path
        print(f"  [!] File not found: '{path}'.  Try again.")


def prompt_output_dir() -> str:
    return prompt("Output directory", "icons")


def prompt_targets() -> list[tuple[str, int, int]]:
    """
    Ask the user to enter size specs one at a time.
    Each entry:  WIDTHxHEIGHT  [optional_filename]
    e.g.:        128x128  icon128.png
         or just 128x128          → auto-named icon128.png
                 1100x280         → auto-named banner_1100x280.png
    Empty input ends the loop.
    """
    print("\nDefine output sizes.  Format: WxH [filename]")
    print("  Examples:  128x128        →  icon128.png")
    print("             1100x280       →  banner_1100x280.png")
    print("             48x48 thumb.png")
    print("  Press Enter with no input when done.\n")

    targets: list[tuple[str, int, int]] = []

    while True:
        raw = prompt(f"  Size {len(targets)+1} (or Enter to finish)", "")
        if not raw:
            if not targets:
                print("  [!] At least one size required.")
                continue
            break

        parts = raw.split()
        dims  = parts[0].lower().replace("×", "x")

        try:
            w_str, h_str = dims.split("x")
            w, h = int(w_str), int(h_str)
            assert w > 0 and h > 0
        except (ValueError, AssertionError):
            print(f"  [!] Invalid dimensions '{parts[0]}'. Use format WxH, e.g. 128x128")
            continue

        if len(parts) >= 2:
            filename = parts[1]
        elif w == h:
            filename = f"icon{w}.png"
        else:
            filename = f"banner_{w}x{h}.png"

        targets.append((filename, w, h))
        print(f"       → scheduled: {filename}  ({w}×{h})")

    return targets


def use_default_sizes() -> str:
    """Let the user pick from preset groups or go fully custom."""
    print("\nChoose a starting set of sizes:")
    print("  1  Extension icons only  (16, 48, 128)")
    print("  2  Icons + banner        (16, 48, 128, 1100×280)")
    print("  3  Custom                (you define every size)")
    choice = prompt("Selection", "1")
    return choice.strip()


# ---------------------------------------------------------------------------
# Main generation routine
# ---------------------------------------------------------------------------

def generate_assets(
    source_path: str,
    output_dir:  str,
    targets:     list[tuple[str, int, int]],
) -> None:
    os.makedirs(output_dir, exist_ok=True)

    try:
        with Image.open(source_path) as img:
            print(f"\nSource : {source_path}  ({img.width}×{img.height}  {img.mode})")
            print(f"Output : {output_dir}/\n")
            for filename, w, h in targets:
                process_target(img, filename, w, h, output_dir)

        print(f"\nDone. {len(targets)} asset(s) written to '{output_dir}/'.")

    except FileNotFoundError:
        print(f"[Error] Source image not found: '{source_path}'")
        sys.exit(1)
    except Exception as exc:
        print(f"[Error] {exc}")
        sys.exit(1)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Unified icon + banner generator",
        add_help=True,
    )
    parser.add_argument(
        "--defaults-icons",
        action="store_true",
        help="Non-interactive: run with mkicons.py defaults (icons 16/48/128).",
    )
    parser.add_argument(
        "--defaults-banner",
        action="store_true",
        help="Non-interactive: run with mkicons2.py defaults (icons + 1100×280 banner).",
    )
    args = parser.parse_args()

    # ---- Non-interactive legacy modes ----
    if args.defaults_icons:
        source = os.environ.get("SOURCE_FILE", "source_icon.png")
        outdir = os.environ.get("OUTPUT_DIR",  "icons")
        generate_assets(source, outdir, DEFAULTS_ICONS)
        return

    if args.defaults_banner:
        source = os.environ.get("SOURCE_FILE", "source_banner.png")
        outdir = os.environ.get("OUTPUT_DIR",  "dist")
        generate_assets(source, outdir, DEFAULTS_BANNER)
        return

    # ---- Fully interactive mode ----
    print("=" * 52)
    print("  mkicons  —  Icon & Banner Generator")
    print("=" * 52)

    source  = prompt_source()
    outdir  = prompt_output_dir()
    choice  = use_default_sizes()

    if choice == "2":
        targets = list(DEFAULTS_BANNER)
        print("\n  Loaded preset: Icons + Banner")
        add_more = prompt("Add additional custom sizes? (y/N)", "n").lower()
        if add_more == "y":
            targets += prompt_targets()
    elif choice == "3":
        targets = prompt_targets()
    else:
        # Default: icons only
        targets = list(DEFAULTS_ICONS)
        print("\n  Loaded preset: Extension Icons (16, 48, 128)")
        add_more = prompt("Add additional custom sizes? (y/N)", "n").lower()
        if add_more == "y":
            targets += prompt_targets()

    generate_assets(source, outdir, targets)


if __name__ == "__main__":
    main()
