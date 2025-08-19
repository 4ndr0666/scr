#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

echo "--> Starting Google Takeout Organizer setup script for Raspberry Pi..."

# --- 1. Define Variables ---
PYTHON_SCRIPT_NAME="takeout_organizer.py"
PYTHON_SCRIPT_PATH="/usr/local/bin/$PYTHON_SCRIPT_NAME" # Install to a standard bin location
TAKEOUT_BASE_DIR="${TAKEOUT_BASE_DIR:-$HOME/TakeoutOrganizer}" # Default to $HOME/TakeoutOrganizer if env var not set

# --- 2. Embed Python Script ---
echo "--> Embedding Python script..."
cat << 'EOF' > "$PYTHON_SCRIPT_PATH"
import os
import shutil
import subprocess
import tarfile
import json
from datetime import datetime
import traceback
import re
import sys
import argparse
import sqlite3
import hashlib
import stat # Import stat module for file permissions

# ==============================================================================
# --- 1. CORE CONFIGURATION ---
# ==============================================================================
TARGET_MAX_VM_USAGE_GB = 70 # This value is less relevant for Raspberry Pi with external storage, but keep it as a potential check.
REPACKAGE_CHUNK_SIZE_GB = 15
MAX_SAFE_ARCHIVE_SIZE_GB = 25

# Use an environment variable for the base directory for flexibility
TAKEOUT_BASE_DIR = os.environ.get("TAKEOUT_BASE_DIR", ".") # Default to current directory if env var not set

DB_PATH = os.path.join(TAKEOUT_BASE_DIR, "takeout_archive.db")
CONFIG = {
    "SOURCE_ARCHIVES_DIR": os.path.join(TAKEOUT_BASE_DIR, "00-ALL-ARCHIVES/"),
    "PROCESSING_STAGING_DIR": os.path.join(TAKEOUT_BASE_DIR, "01-PROCESSING-STAGING/"),
    "ORGANIZED_DIR": os.path.join(TAKEOUT_BASE_DIR, "03-organized/My-Photos/"),
    "TRASH_DIR": os.path.join(TAKEOUT_BASE_DIR, "04-trash/"),
    "COMPLETED_ARCHIVES_DIR": os.path.join(TAKEOUT_BASE_DIR, "05-COMPLETED-ARCHIVES/"),
}
CONFIG["QUARANTINE_DIR"] = os.path.join(CONFIG["TRASH_DIR"], "quarantined_artifacts/")
CONFIG["DUPES_DIR"] = os.path.join(CONFIG["TRASH_DIR"], "duplicates/")

# Use standard temporary directories instead of Colab-specific ones
VM_TEMP_EXTRACT_DIR = '/tmp/temp_extract'
VM_TEMP_BATCH_DIR = '/tmp/temp_batch_creation'

# ==============================================================================
# --- 2. WORKFLOW FUNCTIONS & HELPERS ---
# ==============================================================================
def dummy_tqdm(iterable, *args, **kwargs):
    """A dummy tqdm function that acts as a fallback if tqdm is not available."""
    description = kwargs.get('desc', 'items')
    print(f"    > Processing {description}...")
    return iterable

def initialize_database(db_path):
    """Creates the SQLite database and the necessary tables if they don't exist."""
    print("--> [DB] Initializing database...")
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS files (
        id INTEGER PRIMARY KEY,
        sha256_hash TEXT NOT NULL UNIQUE,
        original_path TEXT NOT NULL,
        final_path TEXT,
        timestamp INTEGER,
        file_size INTEGER NOT NULL,
        source_archive TEXT NOT NULL
    )
    ''')
    conn.commit()
    print("    ✅ Database ready.")
    return conn

def perform_startup_integrity_check():
    """Performs a "Power-On Self-Test" to detect and correct inconsistent states."""
    print("--> [POST] Performing startup integrity check...")
    staging_dir = CONFIG["PROCESSING_STAGING_DIR"]
    source_dir = CONFIG["SOURCE_ARCHIVES_DIR"]
    if os.path.exists(staging_dir) and os.listdir(staging_dir):
        print("    ⚠️ Found orphaned files. Rolling back transaction...")
        for orphan_file in os.listdir(staging_dir):
            shutil.move(os.path.join(staging_dir, orphan_file), os.path.join(source_dir, orphan_file))
        if os.path.exists(VM_TEMP_EXTRACT_DIR):
            shutil.rmtree(VM_TEMP_EXTRACT_DIR)
        print("    ✅ Rollback complete.")
    # Handle 0-byte files based on the --auto-delete-artifacts flag
    delete_zero_byte = False
    # Check if --auto-delete-artifacts was passed during script execution
    if '--auto-delete-artifacts' in sys.argv:
         delete_zero_byte = True

    for filename in os.listdir(source_dir):
        file_path = os.path.join(source_dir, filename)
        if os.path.isfile(file_path) and os.path.getsize(file_path) == 0:
            print(f"    ⚠️ Found 0-byte artifact: '{filename}'.")
            quarantine_path = os.path.join(CONFIG["QUARANTINE_DIR"], filename)
            try:
                if delete_zero_byte:
                    os.remove(file_path)
                    print(f"    > Automatically deleted 0-byte artifact: '{filename}'")
                else:
                    shutil.move(file_path, quarantine_path)
                    print(f"    > Quarantined 0-byte artifact to: '{quarantine_path}'")
            except Exception as e:
                 print(f"    ❌ Failed to handle 0-byte artifact '{filename}': {e}")

    print("--> [POST] Integrity check complete.")


def plan_and_repackage_archive(archive_path, dest_dir, conn, tqdm_module):
    """
    Scans a large archive, hashes unique files, and repackages them into smaller,
    crash-resilient parts while populating the database.
    """
    original_basename_no_ext = os.path.splitext(os.path.basename(archive_path))[0]
    print(f"--> Repackaging & Indexing '{os.path.basename(archive_path)}'...")
    repackage_chunk_size_bytes = REPACKAGE_CHUNK_SIZE_GB * (1024**3)
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT sha256_hash FROM files")
        existing_hashes = {row[0] for row in cursor.fetchall()}
        print(f"    > Index loaded with {len(existing_hashes)} records.")
        existing_parts = [f for f in os.listdir(dest_dir) if f.startswith(original_basename_no_ext) and '.part-' in f]
        last_part_num = 0
        if existing_parts:
            part_numbers = [int(re.search(r'\.part-(\d+)\.tgz', f).group(1)) for f in existing_parts if re.search(r'\.part-(\d+)\.tgz', f)]
            if part_numbers: last_part_num = max(part_numbers)
            print(f"    ✅ Resuming after part {last_part_num}.")
        batches, current_batch, current_batch_size = [], [], 0
        with tarfile.open(archive_path, 'r:gz') as original_tar:
            all_members = [m for m in original_tar.getmembers() if m.isfile()]
            for member in all_members:
                if current_batch and (current_batch_size + member.size) > repackage_chunk_size_bytes:
                    batches.append(current_batch); current_batch, current_batch_size = [], 0
                current_batch.append(member); current_batch_size += member.size
            if current_batch: batches.append(current_batch)
        print(f"    > Plan complete: {len(all_members)} files -> up to {len(batches)} new archives.")
        for i, batch in enumerate(batches):
            part_number = i + 1
            if part_number <= last_part_num: continue
            os.makedirs(VM_TEMP_BATCH_DIR, exist_ok=True)
            temp_batch_archive_path = os.path.join(VM_TEMP_BATCH_DIR, f"temp_batch_{part_number}.tgz")
            files_in_this_batch = 0
            with tarfile.open(temp_batch_archive_path, 'w:gz') as temp_tar:
                with tarfile.open(archive_path, 'r:gz') as original_tar_stream:
                    for member in tqdm_module(batch, desc=f"Hashing & Staging Batch {part_number}"):
                        file_obj = original_tar_stream.extractfile(member)
                        if not file_obj: continue
                        file_content = file_obj.read()
                        sha256 = hashlib.sha256(file_content).hexdigest()
                        if sha256 in existing_hashes: continue
                        file_obj.seek(0)
                        temp_tar.addfile(member, file_obj)
                        cursor.execute("INSERT INTO files (sha256_hash, original_path, file_size, source_archive) VALUES (?, ?, ?, ?)",
                                       (sha256, member.name, member.size, os.path.basename(archive_path)))
                        existing_hashes.add(sha256)
                        files_in_this_batch += 1
            if files_in_this_batch > 0:
                conn.commit()
                new_archive_name = f"{original_basename_no_ext}.part-{part_number:02d}.tgz"
                final_dest_path = os.path.join(dest_dir, new_archive_name)
                print(f"    --> Batch contains {files_in_this_batch} unique files. Moving final part {part_number} to destination...") # Changed 'Google Drive' to 'destination'
                shutil.move(temp_batch_archive_path, final_dest_path)
                print(f"    ✅ Finished part {part_number}.")
            else:
                print(f"    > Batch {part_number} contained no unique files. Discarding empty batch.")
        return True
    except Exception as e: print(f"\n❌ ERROR during JIT repackaging: {e}"); traceback.print_exc(); return False
    finally:
        if os.path.exists(VM_TEMP_BATCH_DIR): shutil.rmtree(VM_TEMP_BATCH_DIR)

def process_regular_archive(archive_path, conn, tqdm_module):
    """
    Handles a regular-sized archive with Rsync-like file-level resumption by checking the DB
    for already processed files and only unpacking the missing ones ("the delta").
    """
    archive_name = os.path.basename(archive_path)
    print(f"\n--> [Step 2a] Processing transaction for '{archive_name}'...")
    cursor = conn.cursor()
    try:
        print("    > Checking database for previously completed files...")
        cursor.execute("SELECT original_path FROM files WHERE source_archive = ? AND final_path IS NOT NULL", (archive_name,))
        completed_files = {row[0] for row in cursor.fetchall()}
        if completed_files:
            print(f"    ✅ Found {len(completed_files)} completed files. Will skip unpacking them.")
        else:
            print("    > No completed files found for this archive.")

        os.makedirs(VM_TEMP_EXTRACT_DIR, exist_ok=True)

        files_to_process = []
        with tarfile.open(archive_path, 'r:gz') as tf:
            all_members = [m for m in tf.getmembers() if m.isfile()]
            for member in tqdm_module(all_members, desc=f"Scanning {archive_name}"):
                # Normalize path separators for comparison
                normalized_member_name = member.name.replace('\\', '/')
                if normalized_member_name not in completed_files:
                    try:
                        # Ensure the target directory exists before extracting
                        extract_path = os.path.join(VM_TEMP_EXTRACT_DIR, member.name)
                        os.makedirs(os.path.dirname(extract_path), exist_ok=True)
                        tf.extract(member, path=VM_TEMP_EXTRACT_DIR, set_attrs=False)
                        # Set execute permissions for directories for safer os.walk
                        if os.path.isdir(extract_path):
                             os.chmod(extract_path, os.stat(extract_path).st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
                        files_to_process.append(normalized_member_name)
                    except Exception as e:
                        print(f"    ❌ Failed to extract file '{member.name}': {e}")
                        # Decide whether to continue or abort based on severity
                        continue # Continue processing other files

        if not files_to_process:
            print("    ✅ All files in this archive were already processed. Finalizing.")
            return True

        print(f"    ✅ Unpacked {len(files_to_process)} new/missing files to temp directory.") # Changed 'VM' to 'temp directory'

        # Subsequent steps now operate on the much smaller "delta" of new files.
        organize_photos(VM_TEMP_EXTRACT_DIR, CONFIG["ORGANIZED_DIR"], conn, tqdm_module, archive_name)
        deduplicate_files(VM_TEMP_EXTRACT_DIR, CONFIG["ORGANIZED_DIR"], CONFIG["DUPES_DIR"], conn, archive_name)

        return True
    except Exception as e:
        print(f"\n❌ ERROR during archive processing transaction: {e}"); traceback.print_exc()
        return False
    finally:
        if os.path.exists(VM_TEMP_EXTRACT_DIR):
            shutil.rmtree(VM_TEMP_EXTRACT_DIR)
            print("    > Cleaned up temporary directory.") # Changed 'VM' to 'temporary'

def deduplicate_files(source_path, primary_storage_path, trash_path, conn, source_archive_name):
    """Deduplicates new files against the primary storage and updates the database for unique files."""
    print("\n--> [Step 2b] Deduplicating new files...")
    if not shutil.which('jdupes'):
        print("    ⚠️ 'jdupes' not found. Skipping.")
        return

    # Use absolute paths for jdupes command for clarity and robustness
    source_path_abs = os.path.abspath(source_path)
    primary_storage_path_abs = os.path.abspath(primary_storage_path)
    trash_path_abs = os.path.abspath(trash_path)

    command = f'jdupes -r -S -nh --linkhard --move="{trash_path_abs}" "{source_path_abs}" "{primary_storage_path_abs}"'
    print(f"    > Running command: {command}") # Added for debugging
    result = subprocess.run(command, shell=True, capture_output=True, text=True) # Added text=True for string output
    print(f"    > jdupes stdout:\n{result.stdout}") # Added for debugging
    if result.stderr:
        print(f"    > jdupes stderr:\n{result.stderr}") # Added for debugging


    cursor = conn.cursor()
    files_moved = 0
    # The actual uncompressed data is often in a "Takeout" subdirectory relative to the source_path.
    takeout_source = os.path.join(source_path_abs, "Takeout") # Use absolute path here
    if os.path.exists(takeout_source):
        print("    > Moving unique new files and updating database...")
        for root, _, files in os.walk(takeout_source):
            for filename in files:
                unique_file_path = os.path.join(root, filename)
                # Ensure the file still exists (jdupes might have moved it if it was a duplicate)
                if not os.path.exists(unique_file_path):
                    continue

                relative_path_to_takeout = os.path.relpath(unique_file_path, takeout_source)
                final_path = os.path.join(primary_storage_path_abs, relative_path_to_takeout) # Use absolute primary_storage_path

                os.makedirs(os.path.dirname(final_path), exist_ok=True)
                try:
                    shutil.move(unique_file_path, final_path)
                    # We need the original path relative to the TAR root for the DB.
                    # The files were extracted into VM_TEMP_EXTRACT_DIR/Takeout/..., so the original path
                    # inside the archive would be 'Takeout/Google Photos/...'.
                    original_path_in_archive = os.path.relpath(unique_file_path, source_path_abs) # Relative to the initial extraction path
                    cursor.execute("UPDATE files SET final_path = ?, timestamp = ? WHERE original_path = ? AND source_archive = ?",
                                   (final_path, int(ts), original_path_in_archive.replace('\\', '/'), source_archive_name)) # Normalize path separator
                    files_moved += 1
                except Exception as e:
                    print(f"    ❌ Failed to move unique file '{unique_file_path}' to '{final_path}': {e}")


        if files_moved > 0:
            conn.commit()
    print(f"    ✅ Deduplication and move complete. Processed {files_moved} unique files.")


def organize_photos(source_path, final_dir, conn, tqdm_module, source_archive_name):
    """Organizes photos and updates their final path and timestamp in the database."""
    print("\n--> [Step 2c] Organizing photos...")
    photos_organized_count = 0
    # Path is relative to the temporary extraction directory
    photos_source_path = os.path.join(source_path, "Takeout", "Google Photos")
    if not os.path.isdir(photos_source_path):
        print("    > 'Google Photos' directory not found in extracted path. Skipping.")
        return

    final_dir_abs = os.path.abspath(final_dir) # Use absolute path for final_dir

    try:
        # Need to list files in the *actual* final_dir, not just the current state of the temp dir
        # Also need to account for files potentially moved by jdupes from the temp dir to final_dir
        existing_filenames = set(os.listdir(final_dir_abs))
        # Add filenames of files that were just moved by jdupes from the current source_path to final_dir
        # This is tricky as jdupes handles the move, but we need the updated state.
        # A simpler approach is to rely solely on the database and target final_dir contents.
        # However, listing the target dir is a quick check for naming conflicts *before* moving.
        # Let's keep listing final_dir_abs for pre-check, and rely on DB for uniqueness after move.
    except FileNotFoundError:
        existing_filenames = set()

    all_json_files = [os.path.join(r, f) for r, _, files in os.walk(photos_source_path) for f in files if f.lower().endswith('.json')]
    cursor = conn.cursor()

    # Check for photos already in the database that might be in the final destination
    # This helps avoid re-processing or naming conflicts for files already organized.
    cursor.execute("SELECT final_path FROM files WHERE source_archive = ? AND final_path IS NOT NULL AND original_path LIKE ?", (source_archive_name, 'Takeout/Google Photos/%'))
    already_organized_final_paths = {os.path.basename(row[0]) for row in cursor.fetchall() if row[0]} # Use only the basename for comparison

    for json_path in tqdm_module(all_json_files, desc="Organizing photos"):
        media_path = os.path.splitext(json_path)[0]
        # Check if the corresponding media file exists in the source_path
        if not os.path.exists(media_path):
            # The media file might have been moved by jdupes if it was a duplicate of something already in the target directory.
            # We can skip processing this JSON if its media file is gone from the source_path.
            continue

        try:
            with open(json_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            ts = data.get('photoTakenTime', {}).get('timestamp')
            if not ts:
                # Skip if no timestamp is available in the JSON
                continue

            dt = datetime.fromtimestamp(int(ts))
            new_name_base = dt.strftime('%Y-%m-%d_%Hh%Mm%Ss')
            ext = os.path.splitext(media_path)[1].lower()

            # Ensure valid characters in filename (remove potentially problematic ones)
            new_filename = re.sub(r'[^\w.-]', '_', f"{new_name_base}{ext}")

            counter = 0
            proposed_filename = new_filename
            # Check against both files already in the final directory AND files already recorded in the DB for this archive as organized
            while proposed_filename in existing_filenames or proposed_filename in already_organized_final_paths:
                counter += 1
                proposed_filename = re.sub(r'[^\w.-]', '_', f"{new_name_base}_{counter}{ext}")

            final_filepath = os.path.join(final_dir_abs, proposed_filename) # Use absolute final_dir_abs

            try:
                 shutil.move(media_path, final_filepath)
                 # Remove the now-moved JSON file
                 os.remove(json_path)

                 # We need the original path relative to the TAR root for the DB.
                 # The media file was extracted into VM_TEMP_EXTRACT_DIR/Takeout/Google Photos/...,
                 # so the original path inside the archive would be 'Takeout/Google Photos/...'.
                 original_path_in_archive = os.path.relpath(media_path, source_path_abs) # Relative to the initial extraction path
                 cursor.execute("UPDATE files SET final_path = ?, timestamp = ? WHERE original_path = ? AND source_archive = ?",
                                (final_filepath, int(ts), original_path_in_archive.replace('\\', '/'), source_archive_name)) # Normalize path separator

                 # Add the new filename to our sets to prevent immediate conflicts within this run
                 existing_filenames.add(proposed_filename)
                 already_organized_final_paths.add(proposed_filename)

                 photos_organized_count += 1
            except Exception as e:
                 print(f"    ❌ Failed to move and organize photo '{media_path}' to '{final_filepath}': {e}")


        except Exception as e:
             print(f"    ❌ Failed to process photo JSON '{json_path}': {e}")
             continue # Continue processing other JSON files

    if photos_organized_count > 0:
        conn.commit()
        print(f"    ✅ Organized and updated DB for {photos_organized_count} new photos.")
    else:
         print("    > No new photos to organize in this batch.")


# ==============================================================================
# --- MAIN EXECUTION SCRIPT ---
# ==============================================================================
def main(args):
    conn = None
    try:
        print("--> [Step 0] Initializing environment...")
        # Use the fallback dummy_tqdm for headless execution
        tqdm = dummy_tqdm

        # Remove Google Colab specific mount command
        # from google.colab import drive
        # if not os.path.exists('/content/drive/MyDrive'): drive.mount('/content/drive')
        # else: print("✅ Google Drive already mounted.")
        print("✅ Environment initialization complete.") # Adjusted message

        # Ensure base directory is created if using a specific env var path
        os.makedirs(TAKEOUT_BASE_DIR, exist_ok=True)
        print(f"✅ Using base directory: {os.path.abspath(TAKEOUT_BASE_DIR)}") # Print actual base dir path

        for path in CONFIG.values(): os.makedirs(path, exist_ok=True)
        conn = initialize_database(DB_PATH)
        perform_startup_integrity_check()

        # Disk usage check for the root filesystem (where /tmp might be)
        # This is less critical if external storage is used for TAKEOUT_BASE_DIR,
        # but still relevant for the /tmp extract directory.
        total_vm, used_vm, free_vm = shutil.disk_usage('/') # Check root partition
        used_vm_gb = used_vm / (1024**3)
        # Adjusting the check threshold or removing it might be necessary depending on Pi setup
        # For now, keep a check but maybe make the threshold more flexible.
        # TARGET_MAX_VM_USAGE_GB is defined earlier, let's use that.
        if free_vm / (1024**3) < REPACKAGE_CHUNK_SIZE_GB * 2: # Check if there's enough space for extraction/batching
             print(f"\n❌ PRE-FLIGHT CHECK FAILED: Insufficient free disk space on root filesystem ({free_vm / (1024**3):.2f} GB free).")
             print(f"    >>> Need at least {REPACKAGE_CHUNK_SIZE_GB * 2} GB free for temporary operations. <<<")
             return

        print(f"✅ Pre-flight disk check passed. (Free space on root: {free_vm / (1024**3):.2f} GB)") # Adjusted message
        subprocess.run("apt-get update && apt-get -qq install jdupes", shell=True, check=True) # Added check=True to raise error if install fails
        print("✅ Workspace ready.")

        print("\n--> [Step 1] Identifying unprocessed archives...")
        all_archives = set(os.listdir(CONFIG["SOURCE_ARCHIVES_DIR"]))
        completed_archives = set(os.listdir(CONFIG["COMPLETED_ARCHIVES_DIR"]))
        processing_queue = sorted(list(all_archives - completed_archives))

        if not processing_queue:
            print("\n✅🎉 All archives have been processed!")
        else:
            archive_name = processing_queue[0]
            source_path = os.path.join(CONFIG["SOURCE_ARCHIVES_DIR"], archive_name)
            staging_path = os.path.join(CONFIG["PROCESSING_STAGING_DIR"], archive_name)

            print(f"--> Locking and staging '{archive_name}' for processing...")
            # Add check if source_path exists before moving
            if not os.path.exists(source_path):
                print(f"    ⚠️ Source archive '{archive_name}' not found at '{source_path}'. Skipping.")
                return

            try:
                 shutil.move(source_path, staging_path)
            except Exception as e:
                 print(f"    ❌ Failed to move '{source_path}' to staging '{staging_path}': {e}")
                 # Attempt to clean up staging if a partial move occurred?
                 if os.path.exists(staging_path) and os.path.getsize(staging_path) > 0:
                     print(f"    > Partial file found in staging. Attempting rollback...")
                     try:
                         shutil.move(staging_path, source_path)
                         print("    ✅ Rollback successful.")
                     except Exception as rollback_e:
                         print(f"    ❌ Rollback failed: {rollback_e}. Manual intervention needed for '{staging_path}'.")
                 return # Stop processing this archive

            # Check staged file size
            staged_file_size_gb = os.path.getsize(staging_path) / (1024**3)
            print(f"    > Staged file size: {staged_file_size_gb:.2f} GB")


            if staged_file_size_gb > MAX_SAFE_ARCHIVE_SIZE_GB and '.part-' not in archive_name:
                print(f"--> Archive '{archive_name}' ({staged_file_size_gb:.2f} GB) is larger than MAX_SAFE_ARCHIVE_SIZE_GB ({MAX_SAFE_ARCHIVE_SIZE_GB} GB). Repackaging...")
                repackaging_ok = plan_and_repackage_archive(staging_path, CONFIG["SOURCE_ARCHIVES_DIR"], conn, tqdm)
                if repackaging_ok:
                    print(f"--> Repackaging successful for '{archive_name}'. Moving to completed.")
                    try:
                        shutil.move(staging_path, os.path.join(CONFIG["COMPLETED_ARCHIVES_DIR"], archive_name))
                    except Exception as e:
                         print(f"    ❌ Failed to move staged file '{staging_path}' to completed: {e}")
                         # Manual intervention might be needed
                else:
                    print(f"    ❌ Repackaging failed for '{archive_name}'. It remains in staging for manual inspection or rollback on next run.")
            else:
                print(f"--> Archive '{archive_name}' ({staged_file_size_gb:.2f} GB) is within safe limits or is a part file. Processing directly.")
                processed_ok = process_regular_archive(staging_path, conn, tqdm)
                if processed_ok:
                    print(f"--> Direct processing successful for '{archive_name}'. Moving to completed.")
                    try:
                         shutil.move(staging_path, os.path.join(CONFIG["COMPLETED_ARCHIVES_DIR"], archive_name))
                    except Exception as e:
                         print(f"    ❌ Failed to move staged file '{staging_path}' to completed: {e}")
                         # Manual intervention might be needed
                else:
                    print(f"    ❌ Transaction failed for '{archive_name}'. It remains in staging for manual inspection or rollback on next run.")

            print("\n--- WORKFLOW CYCLE COMPLETE. ---")
    except Exception as e:
        print(f"\n❌ A CRITICAL UNHANDLED ERROR OCCURRED: {e}")
        traceback.print_exc()
    finally:
        if conn:
            conn.close()
            print("--> [DB] Database connection closed.")
        # Ensure temporary directories are cleaned up even on error
        if os.path.exists(VM_TEMP_EXTRACT_DIR):
            shutil.rmtree(VM_TEMP_EXTRACT_DIR, ignore_errors=True)
            print("    > Ensured cleanup of temporary extract directory.")
        if os.path.exists(VM_TEMP_BATCH_DIR):
            shutil.rmtree(VM_TEMP_BATCH_DIR, ignore_errors=True)
            print("    > Ensured cleanup of temporary batch directory.")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Process Google Takeout archives.")
    parser.add_argument('--auto-delete-artifacts', action='store_true', help="Enable automatic deletion of 0-byte artifact files.")
    # Parse known arguments and ignore unknown ones
    args, unknown = parser.parse_known_args()

    main(args)

EOF

echo "    ✅ Python script embedded."

# --- 3. Install Dependencies ---
echo "--> Installing dependencies..."
# Update package list and install jdupes and python3-pip
sudo apt-get update || { echo "❌ Error updating package list."; exit 1; }
sudo apt-get install -y jdupes python3-pip || { echo "❌ Error installing apt packages. Ensure you have sudo privileges."; exit 1; }
echo "    ✅ Apt dependencies installed."

echo "--> Installing Python dependencies..."
# Install tqdm using pip3
pip3 install tqdm || { echo "❌ Error installing pip package 'tqdm'. Ensure pip3 is installed and in your PATH."; exit 1; }
echo "    ✅ Python dependencies installed."

# --- 4. Create Directory Structure ---
echo "--> Creating directory structure under $TAKEOUT_BASE_DIR..."
# Use mkdir -p to create parent directories if they don't exist
mkdir -p "$TAKEOUT_BASE_DIR/00-ALL-ARCHIVES" \
         "$TAKEOUT_BASE_DIR/01-PROCESSING-STAGING" \
         "$TAKEOUT_BASE_DIR/03-organized/My-Photos" \
         "$TAKEOUT_BASE_DIR/04-trash/quarantined_artifacts" \
         "$TAKEOUT_BASE_DIR/04-trash/duplicates" \
         "$TAKEOUT_BASE_DIR/05-COMPLETED-ARCHIVES" || { echo "❌ Error creating directories. Check permissions for $TAKEOUT_BASE_DIR."; exit 1; }
echo "    ✅ Directory structure created."

# --- 5. Make Python Script Executable ---
echo "--> Making Python script executable..."
chmod +x "$PYTHON_SCRIPT_PATH" || { echo "❌ Error making script executable. Check permissions for $PYTHON_SCRIPT_PATH."; exit 1; }
echo "    ✅ Script is executable."

# --- 6. Provide Usage Instructions and Automation Examples ---
echo ""
echo "Setup complete!"
echo "The Google Takeout Organizer script has been installed to $PYTHON_SCRIPT_PATH."
echo ""
echo "To use the script, place your Google Takeout archives (.tgz or .tar.gz files) into the:"
echo "  $TAKEOUT_BASE_DIR/00-ALL-ARCHIVES/"
echo ""
echo "You can run the script manually from any directory. The script will use '$TAKEOUT_BASE_DIR' as its base directory."
echo ""
echo "Usage:"
echo "  $PYTHON_SCRIPT_PATH"
echo ""
echo "To specify a different base directory (e.g., on an external hard drive), set the TAKEOUT_BASE_DIR environment variable before running:"
echo "  export TAKEOUT_BASE_DIR=/path/to/your/external/drive/TakeoutOrganizer"
echo "  $PYTHON_SCRIPT_PATH"
echo ""
echo "To enable automatic deletion of 0-byte artifact files (use with caution):"
echo "  $PYTHON_SCRIPT_PATH --auto-delete-artifacts"
echo ""
echo "Processed files will be organized into:"
echo "  \$TAKEOUT_BASE_DIR/03-organized/My-Photos/"
echo "Duplicates and quarantined files will be moved to:"
echo "  \$TAKEOUT_BASE_DIR/04-trash/"
echo "Successfully processed archives will be moved to:"
echo "  \$TAKEOUT_BASE_DIR/05-COMPLETED-ARCHIVES/"
echo ""
echo "The database file is located at:"
echo "  \$TAKEOUT_BASE_DIR/takeout_archive.db"
echo ""
echo "For automation (e.g., daily runs), consider using cron or systemd. Examples are provided below (commented out):"
echo "--------------------------------------------------------------------------------"
echo "# Example: Running the script daily using cron"
echo "# Edit your crontab:  crontab -e"
echo "# Add the following line to run the script every day at 3 AM:"
echo "# 0 3 * * * TAKEOUT_BASE_DIR=\$TAKEOUT_BASE_DIR \$PYTHON_SCRIPT_PATH >> \$TAKEOUT_BASE_DIR/organizer.log 2>&1"
echo ""
echo "# Example: Running the script as a systemd service"
echo "# Create a service file (e.g., /etc/systemd/system/takeout-organizer.service) with content like:"
echo "# [Unit]"
echo "# Description=Google Takeout Organizer"
echo "# After=network.target"
echo ""
echo "# [Service]"
echo "# User=%i  # Use %i for instance user, or replace with a specific user like 'pi'"
echo "# Environment=\"TAKEOUT_BASE_DIR=\$TAKEOUT_BASE_DIR\""
echo "# ExecStart=\$PYTHON_SCRIPT_PATH"
echo "# WorkingDirectory=\$TAKEOUT_BASE_DIR"
echo "# Restart=on-failure"
echo ""
echo "# [Install]"
echo "# WantedBy=multi-user.target"
echo ""
echo "# Save the file, then run:"
echo "# sudo systemctl daemon-reload"
echo "# sudo systemctl enable takeout-organizer.service"
echo "# sudo systemctl start takeout-organizer.service"
"# You can check the status with: sudo systemctl status takeout-organizer.service"
"# And logs with: journalctl -u takeout-organizer.service"
echo "--------------------------------------------------------------------------------"
echo ""
echo "Remember to replace %i or \$USER in the systemd example with the actual user on your system (e.g., 'pi')."
echo "Consider running the script manually first to ensure everything is working correctly."
echo ""
echo "--> Setup script finished. Please copy the content of this cell, save it as a .sh file on your Raspberry Pi, and make it executable (chmod +x your_script_name.sh) before running it with sudo."
