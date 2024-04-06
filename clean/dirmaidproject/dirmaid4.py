#!/usr/bin/python3

import os
import shutil
import mimetypes
import hashlib
import zipfile
import tarfile
import py7zr
import rarfile
import logging
from pathlib import Path

import os

# Use a user-specific directory for logs
log_dir = os.path.expanduser('~/dirmaid_logs')
if not os.path.exists(log_dir):
    os.makedirs(log_dir)

log_file_path = os.path.join(log_dir, 'organize_files.log')

logging.basicConfig(filename=log_file_path, level=logging.INFO,
                    format='%(asctime)s - %(levelname)s - %(message)s')

def generate_file_hash(file_path):
    """Generates a SHA-256 hash for file content to handle duplicates."""
    BUF_SIZE = 65536  # Read in 64kb chunks
    sha256 = hashlib.sha256()
    try:
        with open(file_path, 'rb') as f:
            while True:
                data = f.read(BUF_SIZE)
                if not data:
                    break
                sha256.update(data)
        return sha256.hexdigest()
    except Exception as e:
        logging.error(f"Error generating hash for {file_path}: {e}")
        return None

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
    # Fallback to extension-based categorization
    ext = Path(file_path).suffix.lower()
    if ext in ['.pdf', '.doc', '.docx', '.txt']:
        return 'Documents'
    return 'Others'

def handle_duplicates(file_path, target_directory):
    """Renames file if a duplicate exists in the target directory."""
    original_path = Path(file_path)
    new_path = Path(target_directory) / original_path.name
    counter = 1
    while new_path.exists():
        new_path = Path(target_directory) / f"{original_path.stem}_{counter}{original_path.suffix}"
        counter += 1
    return new_path

def extract_archive(file_path, target_directory):
    """Extracts archive files."""
    try:
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
        logging.info(f"Extracted {os.path.basename(file_path)}")
    except Exception as e:
        logging.error(f"Failed to extract {file_path}: {e}")

def organize_files(directory):
    """Main function to organize files into categories based on type."""
    if not os.path.isdir(directory):
        logging.error(f"The specified directory does not exist: {directory}")
        return

    for root, _, files in os.walk(directory, topdown=False):
        for file in files:
            file_path = os.path.join(root, file)
            category = categorize_file(file_path)
            target_dir = os.path.join(directory, category)
            os.makedirs(target_dir, exist_ok=True)
            new_file_path = handle_duplicates(file_path, target_dir)
            try:
                shutil.move(file_path, new_file_path)
                logging.info(f"Moved {file_path} to {new_file_path}")
                if category == 'Archives':
                    extract_archive(new_file_path, target_dir)
            except Exception as e:
                logging.error(f"Failed to move {file_path} to {new_file_path}: {e}")

if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Organizes files into categories based on type.")
    parser.add_argument("directory", help="The directory to organize.")
    args = parser.parse_args()

    organize_files(args.directory)
