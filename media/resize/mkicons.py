"""
TITLE: mkicons.py
AUTHOR: 4ndr0666
DESCRIPTION: Generates full set of extension icons in required sizes from source image.
USAGE:
1. Name the image to generate icons from 'source_icon.png'
2. Place this script in the same dir
3. Execute python3 mkicons.py
"""
import os
import sys
try:
    from PIL import Image
except ImportError:
    print("Error: This script requires the Pillow library for image processing.")
    print("Please install it using: pip install Pillow")
    sys.exit(1)


def generate_icons(source_image_path, output_dir="icons"):
    """
    Generates extension icons in required sizes from a source image.

    Args:
        source_image_path (str): Path to the source image file (e.g., 'source_icon.png').
        output_dir (str): Directory to save the generated icons. Defaults to 'icons'.
    """
    
    # 1. Check if the source image exists
    if not os.path.exists(source_image_path):
        print(f"[Error]: Image incorrectly named and/or not found at '{source_image_path}'")
        print("Rename -> 'source_icon.png' and place in same dir as this script.")
        sys.exit(1)

    # 2. Create the output directory if it doesn't exist
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
        print(f"Created output directory: '{output_dir}'")

    # 3. Define the required icon sizes for a Chrome extension
    icon_sizes = [(16, 16), (48, 48), (128, 128)]

    try:
        # 4. Open the source image once
        with Image.open(source_image_path) as img:
            print(f"Opened source image: '{source_image_path}'")
            
            # 5. Loop through each size and generate the icon
            for width, height in icon_sizes:
                # Create the output filename (e.g., icons/icon16.png)
                output_filename = f"icon{width}.png"
                output_path = os.path.join(output_dir, output_filename)
                
                # Resize the image using LANCZOS resampling for high quality
                resized_img = img.resize((width, height), Image.Resampling.LANCZOS)
                
                # Save the resized image
                resized_img.save(output_path)
                print(f"Generated: {output_path} ({width}x{height})")
                
        print("\nSuccess! All icons generated.")

    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        sys.exit(1)


if __name__ == "__main__":
    # Define the source image file name. You can change this if your source file is named differently.
    SOURCE_FILE = "source_icon.png"
    
    generate_icons(SOURCE_FILE)
