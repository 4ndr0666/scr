import os
import shutil
import hashlib
import mimetypes
from collections import defaultdict
import zipfile
import tarfile
import rarfile
import py7zr  # Corrected import for handling .7z files
from colorama import init, Fore

init()

# Define categories for file organization
categories = {
    "media": [".mp4", ".mp3", ".avi", ".mov", ".webm"],
    "docs": [".md", ".txt", ".pdf", ".yaml", ".matlab"],
    "pics": [".jpeg", ".bmp", ".png", ".jpg", ".hvec"],
    "archives": [".zip", ".rar", ".tar", ".gz", ".7z"]
}

# Store MD5 hashes of files to manage duplicates
hashes = defaultdict(list)

def extract_archive(file_path, target_directory):
    """Extracts supported archive types into the target directory."""
    if file_path.endswith('.zip'):
        with zipfile.ZipFile(file_path, 'r') as zip_ref:
            zip_ref.extractall(target_directory)
    elif file_path.endswith('.tar.gz') or file_path.endswith('.tar'):
        with tarfile.open(file_path, 'r:*') as tar_ref:
            tar_ref.extractall(target_directory)
    elif file_path.endswith('.7z'):
        with py7zr.SevenZipFile(file_path, mode='r') as z_ref:
            z_ref.extractall(path=target_directory)
    elif file_path.endswith('.rar'):
        with rarfile.RarFile(file_path) as rar_ref:
            rar_ref.extractall(path=target_directory)
    print(f"{Fore.GREEN}Extracted: {os.path.basename(file_path)}")

def move_and_sort_files(category, files):
    """Move and sort files into alphabetized subdirectories."""
    for file in files:
        first_letter = os.path.basename(file)[0].upper()
        target_dir = os.path.join(os.path.dirname(file), category, first_letter)
        os.makedirs(target_dir, exist_ok=True)
        shutil.move(file, target_dir)
    print(f"{Fore.BLUE}Organized {len(files)} files into {category}/{first_letter}.")

def categorize_files(directory):
    """Categorize all files in the given directory."""
    for root, dirs, files in os.walk(directory):
        for file in files:
            file_path = os.path.join(root, file)
            file_ext = os.path.splitext(file_path)[1].lower()
            for category, extensions in categories.items():
                if file_ext in extensions:
                    move_and_sort_files(category, [file_path])
                    break
            else:  # File does not match any category
                print(f"{Fore.YELLOW}Non-categorized file: {file}")

def remove_empty_directories(directory):
    """Remove empty directories after organization."""
    for root, dirs, files in os.walk(directory, topdown=False):
        for dir_ in dirs:
            dir_path = os.path.join(root, dir_)
            if not os.listdir(dir_path):
                os.rmdir(dir_path)
                print(f"{Fore.RED}Removed empty directory: {dir_}")

def organize_directory(directory):
    """Main function to organize the directory."""
    print(f"{Fore.CYAN}Starting organization of {directory}")
    categorize_files(directory)
    remove_empty_directories(directory)
    print(f"{Fore.GREEN}Organization complete.")

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Organize files into predefined categories.")
    parser.add_argument("directory", help="Directory path to organize")
    args = parser.parse_args()

    if not os.path.exists(args.directory):
        print(f"{Fore.RED}Error: The specified directory does not exist.")
    else:
        organize_directory(args.directory)
