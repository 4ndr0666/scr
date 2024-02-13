import os
import shutil
import mimetypes
from collections import defaultdict
import zipfile
import tarfile
import py7zr
import rarfile
from colorama import init, Fore

init(autoreset=True)

def generate_file_hash(file_path):
    """Generates a SHA-256 hash for file content to handle duplicates."""
    import hashlib
    BUF_SIZE = 65536
    sha256 = hashlib.sha256()
    with open(file_path, 'rb') as f:
        while True:
            data = f.read(BUF_SIZE)
            if not data:
                break
            sha256.update(data)
    return sha256.hexdigest()

def categorize_file(file_path):
    """Categorizes files based on MIME type or extension."""
    mime_type, _ = mimetypes.guess_type(file_path)
    if mime_type:
        if 'image' in mime_type:
            return 'Pictures'
        elif 'audio' in mime_type or 'video' in mime_type:
            return 'Media'
        elif 'text' in mime_type or mime_type in ['application/pdf', 'application/msword']:
            return 'Documents'
    return 'Others'

def handle_duplicates(file_path, target_directory):
    """Renames file if a duplicate exists in the target directory."""
    file_hash = generate_file_hash(file_path)
    basename = os.path.basename(file_path)
    name, ext = os.path.splitext(basename)
    new_path = os.path.join(target_directory, basename)
    counter = 1
    while os.path.exists(new_path):
        new_basename = f"{name}_{counter}{ext}"
        new_path = os.path.join(target_directory, new_basename)
        counter += 1
    return new_path

def extract_archive(file_path, target_directory):
    """Extracts archive files."""
    if file_path.endswith('.zip'):
        with zipfile.ZipFile(file_path, 'r') as zip_ref:
            zip_ref.extractall(target_directory)
    elif file_path.endswith('.tar.gz') or file_path.endswith('.tar'):
        with tarfile.open(file_path, 'r:*') as tar_ref:
            tar_ref.extractall(target_directory)
    elif file_path.endswith('.7z'):
        with py7zr.SevenZipFile(file_path, 'r') as z_ref:
            z_ref.extractall(target_directory)
    elif file_path.endswith('.rar'):
        with rarfile.RarFile(file_path, 'r') as rar_ref:
            rar_ref.extractall(target_directory)
    print(f"{Fore.GREEN}Extracted {os.path.basename(file_path)}")

def organize_files(directory):
    """Main function to organize files into categories."""
    if not os.path.isdir(directory):
        print(f"{Fore.RED}The specified directory does not exist: {directory}")
        return

    for root, _, files in os.walk(directory, topdown=False):
        for file in files:
            file_path = os.path.join(root, file)
            category = categorize_file(file_path)
            target_dir = os.path.join(directory, category)
            if not os.path.exists(target_dir):
                os.makedirs(target_dir)
            new_file_path = handle_duplicates(file_path, target_dir)
            shutil.move(file_path, new_file_path)
            if category == 'Archives':
                extract_archive(new_file_path, target_dir)

    print(f"{Fore.CYAN}Files have been organized.")

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Organizes files into categories based on type.")
    parser.add_argument("directory", help="The directory to organize.")
    args = parser.parse_args()

    organize_files(args.directory)
