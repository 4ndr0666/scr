import sys
import os
import math
from PIL import Image

# Hardcoded maximum number of pixels
MAX_PIXELS = 2096704


def get_unique_output_path(input_path: str) -> str:
    """
    Generates a unique, standardized output path in the current directory.
    Example: 'photo.jpg' -> 'photo_resized.png' or 'photo_resized_1.png' if the first exists.
    """
    # Get the file name without its extension (e.g., 'photo.jpg' -> 'photo')
    base_name = os.path.splitext(os.path.basename(input_path))[0]

    # Standardized output name format
    output_name_base = f"{base_name}_resized"
    output_path = f"{output_name_base}.png"

    # Check for existing files to ensure idempotency
    counter = 1
    while os.path.exists(output_path):
        output_path = f"{output_name_base}_{counter}.png"
        counter += 1

    return output_path


def resize_image_to_max_pixels(input_path: str):
    """
    Resizes an image to have a total pixel count no greater than MAX_PIXELS,
    maintaining aspect ratio and saving to a unique name in the current directory.
    """
    if not os.path.exists(input_path):
        print(f"Error: The file '{input_path}' was not found.")
        return

    try:
        img = Image.open(input_path)
        original_width, original_height = img.size
        original_pixels = original_width * original_height

        print(
            f"Original: '{os.path.basename(input_path)}' ({original_width}x{original_height}, {original_pixels:,} pixels)"
        )

        output_path = get_unique_output_path(input_path)

        # If the image is already within the limit, just save it as a lossless PNG
        if original_pixels <= MAX_PIXELS:
            print(f"Image is already within the size limit. Saving as lossless PNG.")
            img.save(output_path, "PNG")
            print(f"Successfully saved to: '{output_path}'")
            return

        # Calculate new dimensions while preserving aspect ratio
        aspect_ratio = original_width / original_height
        new_height = math.sqrt(MAX_PIXELS / aspect_ratio)
        new_width = aspect_ratio * new_height

        # Floor the dimensions to guarantee the pixel count is not exceeded
        new_width = math.floor(new_width)
        new_height = math.floor(new_height)
        new_pixels = new_width * new_height

        # Resize using the high-quality LANCZOS filter
        resized_img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)

        # Save the result
        resized_img.save(output_path, "PNG")

        print(
            f"Resized:  '{output_path}' ({new_width}x{new_height}, {new_pixels:,} pixels)"
        )

    except Exception as e:
        print(f"An error occurred while processing the image: {e}")


if __name__ == "__main__":
    # Check if the command-line argument is provided
    if len(sys.argv) != 2:
        print("Usage: python process_image.py <path_to_your_image>")
        # Create a dummy file for the example to work in environments without command line args
        try:
            print("Running with a dummy file as an example...")
            dummy_img_path = "example_image.jpg"
            dummy_img = Image.new("RGB", (5000, 4000), color="blue")  # > MAX_PIXELS
            dummy_img.save(dummy_img_path)
            resize_image_to_max_pixels(dummy_img_path)

            # Demonstrate idempotency
            print("\nRunning again on the same file to show unique naming...")
            resize_image_to_max_pixels(dummy_img_path)

        except Exception as e:
            # Silently fail if PIL is not available
            pass
    else:
        input_image_path = sys.argv[1]
        resize_image_to_max_pixels(input_image_path)
