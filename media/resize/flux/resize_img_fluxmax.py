import sys
import os
import math
import argparse
from pathlib import Path
from PIL import Image
from concurrent.futures import ProcessPoolExecutor, as_completed
from typing import List, Tuple

# To use the progress bar, you might need to install tqdm:
# pip install tqdm
try:
    from tqdm import tqdm
except ImportError:
    # A dummy tqdm function if the library isn't installed.
    def tqdm(iterable, *args, **kwargs):
        print("Warning: 'tqdm' not found. Progress bar will not be shown. Install with 'pip install tqdm'")
        return iterable

# Suppress DecompressionBombError for very large images. Use with caution.
Image.MAX_IMAGE_PIXELS = None

SUPPORTED_EXTENSIONS = ['.jpg', '.jpeg', '.png', '.webp']

def get_output_path(input_path: Path, output_dir: Path, suffix: str) -> Path:
    """
    Generates a unique output path within the specified output directory.
    Example: '/path/to/photo.jpg' -> 'output_dir/photo_resized.png'
    """
    base_name = input_path.stem
    output_name_base = f"{base_name}{suffix}"
    output_path = output_dir / f"{output_name_base}.png"

    counter = 1
    while output_path.exists():
        output_path = output_dir / f"{output_name_base}_{counter}.png"
        counter += 1
    return output_path

def process_image(
    input_path: Path,
    output_dir: Path,
    max_pixels: int,
    suffix: str
) -> Tuple[str, str]:
    """
    Resizes a single image to a max pixel count and saves it.
    Returns a tuple of (status, message) for reporting.
    """
    try:
        with Image.open(input_path) as img:
            # Convert RGBA to RGB for PNGs with alpha to avoid issues when saving to formats that don't support it
            if img.mode == 'RGBA':
                img = img.convert('RGB')
                
            original_width, original_height = img.size
            original_pixels = original_width * original_height

            output_path = get_output_path(input_path, output_dir, suffix)

            if original_pixels <= max_pixels:
                img.save(output_path, "PNG", optimize=True)
                return "SKIPPED", f"'{input_path.name}' is compliant. Copied to '{output_path.name}'."

            aspect_ratio = original_width / original_height
            new_height = math.sqrt(max_pixels / aspect_ratio)
            new_width = aspect_ratio * new_height

            new_width, new_height = math.floor(new_width), math.floor(new_height)

            resized_img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
            resized_img.save(output_path, "PNG", optimize=True)

            return "RESIZED", f"'{input_path.name}' ({original_width}x{original_height}) -> '{output_path.name}' ({new_width}x{new_height})."

    except Exception as e:
        return "ERROR", f"Failed to process '{input_path.name}': {e}"

def main():
    parser = argparse.ArgumentParser(
        description="A high-performance batch image resizer. Resizes images to a maximum total pixel count, ideal for ML model input constraints.",
        formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument(
        "inputs",
        nargs='+',
        type=Path,
        help="One or more paths to image files or directories to process."
    )
    parser.add_argument(
        "-o", "--output-dir",
        type=Path,
        default=Path("./resized"),
        help="Directory to save the resized images. (Default: ./resized)"
    )
    parser.add_argument(
        "-p", "--max-pixels",
        type=int,
        default=2096704, # Default for Fluxmax
        help="Maximum total number of pixels (width * height). (Default: 2096704)"
    )
    parser.add_argument(
        "-s", "--suffix",
        type=str,
        default="_resized",
        help="Suffix to append to the output filenames before the extension. (Default: _resized)"
    )
    parser.add_argument(
        "-w", "--workers",
        type=int,
        default=os.cpu_count(),
        help="Number of concurrent worker processes to use. (Default: all available CPU cores)"
    )
    args = parser.parse_args()

    # --- Collect all image files ---
    image_paths: List[Path] = []
    for input_path in args.inputs:
        if not input_path.exists():
            print(f"Warning: Input path does not exist, skipping: {input_path}")
            continue
        if input_path.is_dir():
            print(f"Scanning directory: {input_path}")
            for ext in SUPPORTED_EXTENSIONS:
                image_paths.extend(list(input_path.rglob(f"*{ext}")))
        elif input_path.is_file():
            if input_path.suffix.lower() in SUPPORTED_EXTENSIONS:
                image_paths.append(input_path)
            else:
                 print(f"Warning: Skipping unsupported file type: {input_path}")


    if not image_paths:
        print("Error: No supported image files found in the specified paths.")
        sys.exit(1)

    # --- Create output directory ---
    args.output_dir.mkdir(parents=True, exist_ok=True)
    print(f"Found {len(image_paths)} images to process.")
    print(f"Output will be saved to: {args.output_dir.resolve()}")
    print(f"Using {args.workers} worker processes.")

    # --- Process images concurrently ---
    with ProcessPoolExecutor(max_workers=args.workers) as executor:
        # Create a dictionary of future to its input path for progress tracking
        futures = {executor.submit(process_image, path, args.output_dir, args.max_pixels, args.suffix): path for path in image_paths}
        
        with tqdm(total=len(image_paths), desc="Processing Images") as pbar:
            for future in as_completed(futures):
                status, message = future.result()
                if status == "ERROR":
                    # Print errors to stderr to separate them from normal output
                    print(f"\nERROR: {message}", file=sys.stderr)
                pbar.update(1)

    print("\nBatch processing complete.")

if __name__ == "__main__":
    main()
