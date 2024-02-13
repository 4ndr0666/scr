import os
import shutil
import zipfile
import tarfile
import rarfile
from collections import defaultdict

# Define the directory to organize and the default password for archives
search_dir = os.path.expanduser("~/Downloads")
default_password = "hef"

# Define the categories and their associated file extensions
categories = {
    "media": [".mp4", ".gif", ".mkv", ".avi", ".mov", ".webm"],
    "docs": [".md", ".txt", ".pdf", ".yaml", ".matlab"],
    "pics": [".jpeg", ".bmp", ".png", ".jpg", ".hvec"],
    "archives": [".zip", ".rar", ".tar", ".gz", ".7z"]
}

# Create a dictionary to store the MD5 hashes of the files
hashes = defaultdict(list)

# Function to extract archives with password
def extract_with_password(file, password):
    if file.endswith(".zip"):
        with zipfile.ZipFile(file) as archive:
            archive.extractall(path=search_dir, pwd=password.encode())
    elif file.endswith(".rar"):
        with rarfile.RarFile(file) as archive:
            archive.extractall(path=search_dir, pwd=password)
    elif file.endswith(".tar") or file.endswith(".gz"):
        with tarfile.open(file) as archive:
            archive.extractall(path=search_dir)

# Function to move and sort files into alphabetized subdirectories
def move_and_sort_files(category, files):
    for file in files:
        first_letter = os.path.basename(file)[0].upper()
        target_dir = os.path.join(search_dir, category, first_letter)
        os.makedirs(target_dir, exist_ok=True)
        shutil.move(file, target_dir)

# Process each category
for category, extensions in categories.items():
    category_files = []
    for root, dirs, files in os.walk(search_dir):
        for file in files:
            if any(file.endswith(ext) for ext in extensions):
                file_path = os.path.join(root, file)
                category_files.append(file_path)

    # If the category is archives, try to extract the files
    if category == "archives":
        for file in category_files:
            try:
                extract_with_password(file, default_password)
            except Exception:
                print(f"Failed to extract '{file}' with the default password")

    # Move and sort the files into alphabetized subdirectories
    move_and_sort_files(category, category_files)

# Remove empty directories
for root, dirs, files in os.walk(search_dir, topdown=False):
    for dir in dirs:
        dir_path = os.path.join(root, dir)
        if not os.listdir(dir_path):
            os.rmdir(dir_path)

print("Files have been organized and sorted.")

import hashlib

# Function to calculate md5 hash of file
def calculate_md5(file_path):
    hash_md5 = hashlib.md5()
    with open(file_path, "rb") as file:
        for chunk in iter(lambda: file.read(4096), b""):
            hash_md5.update(chunk)
    return hash_md5.hexdigest()

# Check for duplicates and organize files into A-Z folders
for root, dirs, files in os.walk(search_dir):
    for file in files:
        file_path = os.path.join(root, file)
        file_hash = calculate_md5(file_path)

        # If a file with the same hash already exists, it's a duplicate
        if file_hash in hashes:
            print(f"Duplicate found: '{file_path}' and '{hashes[file_hash]}'")
            continue

        # Add the file to the hashes dictionary
        hashes[file_hash].append(file_path)

        # Move the file to the corresponding alphabetized folder
        first_letter = os.path.basename(file)[0].upper()
        target_dir = os.path.join(search_dir, "alphabetized_folders", first_letter)
        os.makedirs(target_dir, exist_ok=True)
        shutil.move(file_path, target_dir)

# Remove empty directories
for root, dirs, files in os.walk(search_dir, topdown=False):
    for dir in dirs:
        dir_path = os.path.join(root, dir)
        if not os.listdir(dir_path):
            os.rmdir(dir_path)

print("Files have been organized and sorted.")

# Function to extract archives with password
def extract_with_password(file, password):
    try:
        if file.endswith(".zip"):
            with zipfile.ZipFile(file) as archive:
                archive.extractall(path=search_dir, pwd=password.encode())
        elif file.endswith(".rar"):
            with rarfile.RarFile(file) as archive:
                archive.extractall(path=search_dir, pwd=password)
        elif file.endswith(".tar") or file.endswith(".gz"):
            with tarfile.open(file) as archive:
                archive.extractall(path=search_dir)
        return True
    except Exception:
        return False

# If extraction failed with default password, prompt for another password
skipped_files = [file for file in category_files if not extract_with_password(file, default_password)]
while skipped_files:
    new_password = input("Enter another password, or type 'q' to quit: ")
    if new_password.lower() == 'q':
        print("Exiting.")
        break

    remaining_skipped_files = []
    for skipped_file in skipped_files:
        if not extract_with_password(skipped_file, new_password):
            remaining_skipped_files.append(skipped_file)
            print(f"Failed to extract '{skipped_file}' with the provided password")
        else:
            print(f"Successfully extracted '{skipped_file}' with the provided password")

    skipped_files = remaining_skipped_files

print("Files have been organized and sorted.")

# Function to categorize files based on their extension
def categorize_files(files):
    categorized_files = defaultdict(list)
    for file in files:
        _, extension = os.path.splitext(file)
        for category, extensions in categories.items():
            if extension in extensions:
                categorized_files[category].append(file)
                break
        else:
            categorized_files['other'].append(file)
    return categorized_files

# Get all files in the search directory
all_files = [os.path.join(root, file) for root, dirs, files in os.walk(search_dir) for file in files]

# Categorize the files
categorized_files = categorize_files(all_files)

# Process each category
for category, files in categorized_files.items():
    # If the category is archives, try to extract the files
    if category == "archives":
        for file in files:
            try:
                extract_with_password(file, default_password)
            except Exception:
                print(f"Failed to extract '{file}' with the default password")
        continue

    # Move and sort the files into alphabetized subdirectories
    move_and_sort_files(category, files)

# Remove empty directories
for root, dirs, files in os.walk(search_dir, topdown=False):
    for dir in dirs:
        dir_path = os.path.join(root, dir)
        if not os.listdir(dir_path):
            os.rmdir(dir_path)

print("Files have been organized and sorted.")

# Create a dictionary to store the MD5 hashes of the files
hashes = defaultdict(list)

# Check for duplicates and organize files into A-Z folders
for root, dirs, files in os.walk(search_dir):
    for file in files:
        file_path = os.path.join(root, file)
        file_hash = calculate_md5(file_path)

        # If a file with the same hash already exists, it's a duplicate
        if file_hash in hashes:
            print(f"Duplicate found: '{file_path}' and '{hashes[file_hash]}'")
            continue

        # Add the file to the hashes dictionary
        hashes[file_hash].append(file_path)

        # Move the file to the corresponding alphabetized folder
        first_letter = os.path.basename(file)[0].upper()
        target_dir = os.path.join(search_dir, "alphabetized_folders", first_letter)
        os.makedirs(target_dir, exist_ok=True)
        shutil.move(file_path, target_dir)

# Remove empty directories
for root, dirs, files in os.walk(search_dir, topdown=False):
    for dir in dirs:
        dir_path = os.path.join(root, dir)
        if not os.listdir(dir_path):
            os.rmdir(dir_path)

print("Files have been organized and sorted.")

# Function to process archives
def process_archives(files):
    for file in files:
        try:
            extract_with_password(file, default_password)
        except Exception:
            print(f"Failed to extract '{file}' with the default password")

    # Move and sort the extracted files into alphabetized subdirectories
    extracted_files = [os.path.join(root, file) for root, dirs, files in os.walk(search_dir) for file in files]
    move_and_sort_files("archives", extracted_files)

# Get all files in the search directory
all_files = [os.path.join(root, file) for root, dirs, files in os.walk(search_dir) for file in files]

# Categorize the files
categorized_files = categorize_files(all_files)

# Process each category
for category, files in categorized_files.items():
    if category == "archives":
        process_archives(files)
    else:
        move_and_sort_files(category, files)

# Remove empty directories
for root, dirs, files in os.walk(search_dir, topdown=False):
    for dir in dirs:
        dir_path = os.path.join(root, dir)
        if not os.listdir(dir_path):
            os.rmdir(dir_path)

print("Files have been organized and sorted.")

# Function to prompt for directory
def prompt_directory():
    dir = input("Enter the directory to organize: ")
    if not os.path.isdir(dir):
        print(f"Directory not found: {dir}")
        exit(1)
    return dir

# Function to create category directories
def create_category_directories(parent_dir):
    os.makedirs(os.path.join(parent_dir, "media"), exist_ok=True)
    os.makedirs(os.path.join(parent_dir, "docs"), exist_ok=True)
    os.makedirs(os.path.join(parent_dir, "pics"), exist_ok=True)
    os.makedirs(os.path.join(parent_dir, "archives"), exist_ok=True)

# Main logic
search_dir = prompt_directory()
parent_dir = os.path.dirname(search_dir)
create_category_directories(parent_dir)

# Get all files in the search directory
all_files = [os.path.join(root, file) for root, dirs, files in os.walk(search_dir) for file in files]

# Categorize the files
categorized_files = categorize_files(all_files)

# Process each category
for category, files in categorized_files.items():
    if category == "archives":
        process_archives(files)
    else:
        move_and_sort_files(category, files)

# Remove empty directories
for root, dirs, files in os.walk(search_dir, topdown=False):
    for dir in dirs:
        dir_path = os.path.join(root, dir)
        if not os.listdir(dir_path):
            os.rmdir(dir_path)

print("Files have been organized and sorted.")

# Function to remove duplicates
def remove_duplicates(files):
    for file in files:
        file_hash = calculate_md5(file)

        # If a file with the same hash already exists, it's a duplicate
        if file_hash in hashes:
            print(f"Duplicate found: '{file}' and '{hashes[file_hash]}'")
            os.remove(file)
            continue

        # Add the file to the hashes dictionary
        hashes[file_hash].append(file)

# Main logic
search_dir = prompt_directory()
parent_dir = os.path.dirname(search_dir)
create_category_directories(parent_dir)

# Get all files in the search directory
all_files = [os.path.join(root, file) for root, dirs, files in os.walk(search_dir) for file in files]

# Categorize the files
categorized_files = categorize_files(all_files)

# Process each category
for category, files in categorized_files.items():
    if category == "archives":
        process_archives(files)
    else:
        move_and_sort_files(category, files)

# Remove duplicates
remove_duplicates(all_files)

# Remove empty directories
for root, dirs, files in os.walk(search_dir, topdown=False):
    for dir in dirs:
        dir_path = os.path.join(root, dir)
        if not os.listdir(dir_path):
            os.rmdir(dir_path)

print("Files have been organized and sorted.")

# Function to handle password protected archives
def handle_protected_archives(files):
    skipped_files = [file for file in files if not extract_with_password(file, default_password)]
    while skipped_files:
        new_password = input("Enter another password, or type 'q' to quit: ")
        if new_password.lower() == 'q':
            print("Exiting.")
            break

        remaining_skipped_files = []
        for skipped_file in skipped_files:
            if not extract_with_password(skipped_file, new_password):
                remaining_skipped_files.append(skipped_file)
                print(f"Failed to extract '{skipped_file}' with the provided password")
            else:
                print(f"Successfully extracted '{skipped_file}' with the provided password")

        skipped_files = remaining_skipped_files

# Main logic
search_dir = prompt_directory()
parent_dir = os.path.dirname(search_dir)
create_category_directories(parent_dir)

# Get all files in the search directory
all_files = [os.path.join(root, file) for root, dirs, files in os.walk(search_dir) for file in files]

# Categorize the files
categorized_files = categorize_files(all_files)

# Process each category
for category, files in categorized_files.items():
    if category == "archives":
        process_archives(files)
        handle_protected_archives(files)
    else:
        move_and_sort_files(category, files)

# Remove duplicates
remove_duplicates(all_files)

# Remove empty directories
for root, dirs, files in os.walk(search_dir, topdown=False):
    for dir in dirs:
        dir_path = os.path.join(root, dir)
        if not os.listdir(dir_path):
            os.rmdir(dir_path)

print("Files have been organized and sorted.")

# Function to check if a file is an archive
def is_archive(file):
    return any(file.endswith(ext) for ext in categories["archives"])

# Function to extract archives
def extract_archives(files):
    for file in files:
        if is_archive(file):
            try:
                extract_with_password(file, default_password)
            except Exception:
                print(f"Failed to extract '{file}' with the default password")

# Main logic
search_dir = prompt_directory()
parent_dir = os.path.dirname(search_dir)
create_category_directories(parent_dir)

# Get all files in the search directory
all_files = [os.path.join(root, file) for root, dirs, files in os.walk(search_dir) for file in files]

# Categorize the files
categorized_files = categorize_files(all_files)

# Process each category
for category, files in categorized_files.items():
    if category == "archives":
        extract_archives(files)
        handle_protected_archives(files)
    else:
        move_and_sort_files(category, files)

# Remove duplicates
remove_duplicates(all_files)

# Remove empty directories
for root, dirs, files in os.walk(search_dir, topdown=False):
    for dir in dirs:
        dir_path = os.path.join(root, dir)
        if not os.listdir(dir_path):
            os.rmdir(dir_path)

print("Files have been organized and sorted.")

# Function to get the initial letter of a file
def get_initial(file):
    return os.path.basename(file)[0].upper()

# Function to move a file to the corresponding alphabetized folder
def move_to_alphabetized_folder(file, parent_dir):
    initial = get_initial(file)
    target_dir = os.path.join(parent_dir, "alphabetized_folders", initial)
    os.makedirs(target_dir, exist_ok=True)
    shutil.move(file, target_dir)

# Main logic
search_dir = prompt_directory()
parent_dir = os.path.dirname(search_dir)
create_category_directories(parent_dir)

# Get all files in the search directory
all_files = [os.path.join(root, file) for root, dirs, files in os.walk(search_dir) for file in files]

# Categorize the files
categorized_files = categorize_files(all_files)

# Process each category
for category, files in categorized_files.items():
    if category == "archives":
        extract_archives(files)
        handle_protected_archives(files)
    else:
        move_and_sort_files(category, files)

# Move all files to the corresponding alphabetized folder
for file in all_files:
    move_to_alphabetized_folder(file, parent_dir)

# Remove duplicates
remove_duplicates(all_files)

# Remove empty directories
for root, dirs, files in os.walk(search_dir, topdown=False):
    for dir in dirs:
        dir_path = os.path.join(root, dir)
        if not os.listdir(dir_path):
            os.rmdir(dir_path)

print("Files have been organized and sorted.")

# Function to organize files into A-Z folders
def organize_files(files):
    for file in files:
        first_letter = os.path.basename(file)[0].upper()

        if first_letter.isalpha():
            target_dir = os.path.join(search_dir, "alphabetized_folders", first_letter)
        else:
            target_dir = os.path.join(search_dir, "rubbish_bin")

        os.makedirs(target_dir, exist_ok=True)
        shutil.move(file, target_dir)

# Main logic
search_dir = prompt_directory()
parent_dir = os.path.dirname(search_dir)
create_category_directories(parent_dir)

# Get all files in the search directory
all_files = [os.path.join(root, file) for root, dirs, files in os.walk(search_dir) for file in files]

# Categorize the files
categorized_files = categorize_files(all_files)

# Process each category
for category, files in categorized_files.items():
    if category == "archives":
        extract_archives(files)
        handle_protected_archives(files)
    else:
        move_and_sort_files(category, files)

# Organize all files into A-Z folders
organize_files(all_files)

# Remove duplicates
remove_duplicates(all_files)

# Remove empty directories
for root, dirs, files in os.walk(search_dir, topdown=False):
    for dir in dirs:
        dir_path = os.path.join(root, dir)
        if not os.listdir(dir_path):
            os.rmdir(dir_path)

print("Files have been organized and sorted.")

# Function to handle non categorized files
def handle_non_categorized_files(files):
    for file in files:
        if is_archive(file):
            try:
                extract_with_password(file, default_password)
            except Exception:
                print(f"Failed to extract '{file}' with the default password")

        # Move the file to the corresponding alphabetized folder
        move_to_alphabetized_folder(file, parent_dir)

# Main logic
search_dir = prompt_directory()
parent_dir = os.path.dirname(search_dir)
create_category_directories(parent_dir)

# Get all files in the search directory
all_files = [os.path.join(root, file) for root, dirs, files in os.walk(search_dir) for file in files]

# Categorize the files
categorized_files = categorize_files(all_files)

# Process each category
for category, files in categorized_files.items():
    if category == "archives":
        extract_archives(files)
        handle_protected_archives(files)
    elif category == "other":
        handle_non_categorized_files(files)
    else:
        move_and_sort_files(category, files)

# Remove duplicates
remove_duplicates(all_files)

# Remove empty directories
for root, dirs, files in os.walk(search_dir, topdown=False):
    for dir in dirs:
        dir_path = os.path.join(root, dir)
        if not os.listdir(dir_path):
            os.rmdir(dir_path)

# Handle non categorized files one more time after extraction
all_files = [os.path.join(root, file) for root, dirs, files in os.walk(search_dir) for file in files]
non_categorized_files = [file for file in all_files if not any(file.endswith(ext) for ext in sum(categories.values(), []))]
handle_non_categorized_files(non_categorized_files)

# Final removal of empty directories
for root, dirs, files in os.walk(search_dir, topdown=False):
    for dir in dirs:
        dir_path = os.path.join(root, dir)
        if not os.listdir(dir_path):
            os.rmdir(dir_path)

print("Files have been organized and sorted.")
