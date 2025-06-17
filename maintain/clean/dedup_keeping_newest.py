import os
import hashlib
from collections import defaultdict
from tqdm import tqdm


def md5sum(file_path):
    """Calculate the MD5 checksum for a file with error handling."""
    try:
        with open(file_path, "rb") as f:
            hash_md5 = hashlib.md5()
            for chunk in iter(lambda: f.read(4096), b""):
                hash_md5.update(chunk)
        return hash_md5.hexdigest()
    except OSError as e:
        print(f"Error reading file {file_path}: {e}")
        return None


def find_duplicates(directory):
    """Find duplicate files in the given directory with progress bar for feedback."""
    sizes = defaultdict(list)
    hashes = defaultdict(list)
    files_processed = 0

    for dirpath, _, filenames in os.walk(directory):
        for filename in tqdm(filenames, desc="Scanning files"):
            file_path = os.path.join(dirpath, filename)
            try:
                file_size = os.path.getsize(file_path)
                sizes[file_size].append(file_path)
                files_processed += 1
            except OSError as e:
                print(f"Error accessing file {file_path}: {e}")

    print(f"Total files scanned: {files_processed}")

    for size, files in tqdm(sizes.items(), desc="Calculating checksums"):
        if len(files) < 2:
            continue
        for file_path in files:
            file_hash = md5sum(file_path)
            if file_hash is not None:
                hashes[(size, file_hash)].append(file_path)

    return {file_hash: files for file_hash, files in hashes.items() if len(files) > 1}


def keep_newest_and_largest(duplicates):
    """Keep only the newest and largest file among duplicates, delete the rest with progress feedback."""
    for file_hash, files in tqdm(duplicates.items(), desc="Processing duplicates"):
        files.sort(
            key=lambda x: (os.path.getctime(x), os.path.getsize(x)), reverse=True
        )
        for file_path in files[1:]:
            response = input(f"Do you want to delete this file: {file_path}? (y/n): ")
            if response.lower() == "y":
                try:
                    os.remove(file_path)
                    print(f"Deleted: {file_path}")
                except OSError as e:
                    print(f"Error deleting file {file_path}: {e}")
            else:
                print(f"Skipped: {file_path}")


if __name__ == "__main__":
    directory = input("Enter the directory to search for duplicates: ")
    duplicates = find_duplicates(directory)
    if duplicates:
        print(
            f"Found {len(duplicates)} groups of duplicates. Reviewing files for deletion..."
        )
        keep_newest_and_largest(duplicates)
    else:
        print("No duplicates found.")
