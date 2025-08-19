#!/bin/bash

echo "--- Google Takeout Organizer Setup Script ---"

# Define the Python script content as a heredoc
read -r -d '' PYTHON_SCRIPT << 'EOF'
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
import time

# ==============================================================================
# --- 1. CORE CONFIGURATION ---
# ==============================================================================
TARGET_MAX_VM_USAGE_GB = 70
REPACKAGE_CHUNK_SIZE_GB = 15
MAX_SAFE_ARCHIVE_SIZE_GB = 25

# BASE_DIR will be set by the bash script or environment
BASE_DIR = os.environ.get("TAKEOUT_BASE_DIR", "/mnt/storage/TakeoutProject") # Default to a common mount point
DB_PATH = os.path.join(BASE_DIR, "takeout_archive.db")
CONFIG = {
    "SOURCE_ARCHIVES_DIR": os.path.join(BASE_DIR, "00-ALL-ARCHIVES/"),
    "PROCESSING_STAGING_DIR": os.path.join(BASE_DIR, "01-PROCESSING-STAGING/"),
    "ORGANIZED_DIR": os.path.join(BASE_DIR, "03-organized/My-Photos/"),
    "TRASH_DIR": os.path.join(BASE_DIR, "04-trash/"),
    "COMPLETED_ARCHIVES_DIR": os.path.join(BASE_DIR, "05-COMPLETED-ARCHIVES/"),
}
CONFIG["QUARANTINE_DIR"] = os.path.join(CONFIG["TRASH_DIR"], "quarantined_artifacts/")
CONFIG["DUPES_DIR"] = os.path.join(CONFIG["TRASH_DIR"], "duplicates/")
VM_TEMP_EXTRACT_DIR = '/tmp/temp_extract' # Use /tmp for temporary VM/system files
VM_TEMP_BATCH_DIR = '/tmp/temp_batch_creation' # Use /tmp for temporary VM/system files

# Placeholder for GOOGLE_APPLICATION_CREDENTIALS - not used in this script but requested in bash
# os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = os.path.join(os.path.expanduser("~"), ".secrets", "credentials.json")

# ==============================================================================
# --- 2. WORKFLOW FUNCTIONS & HELPERS ---
# ==============================================================================
def dummy_tqdm(iterable, *args, **kwargs):
    # A dummy tqdm function that acts as a fallback if tqdm is not available.
    description = kwargs.get('desc', 'items')
    print(f"    > Processing {description}...")
    return iterable

def initialize_database(db_path):
    # Creates the SQLite database and the necessary tables if they don't exist.
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
    # Performs a "Power-On Self-Test" to detect and correct inconsistent states.
    print("--> [POST] Performing startup integrity check...")
    staging_dir = CONFIG["PROCESSING_STAGING_DIR"]
    source_dir = CONFIG["SOURCE_ARCHIVES_DIR"]
    # Check and rollback orphaned files in staging
    if os.path.exists(staging_dir):
        orphaned_files = os.listdir(staging_dir)
        if orphaned_files:
            print("    ⚠️ Found orphaned files in staging. Rolling back transaction...")
            for orphan_file in orphaned_files:
                staging_file_path = os.path.join(staging_dir, orphan_file)
                source_file_path = os.path.join(source_dir, orphan_file)
                try:
                    shutil.move(staging_file_path, source_file_path)
                except FileNotFoundError:
                    print(f"    > Orphaned file '{orphan_file}' already moved or missing from source, deleting from staging.")
                    os.remove(staging_file_path)
            if os.path.exists(VM_TEMP_EXTRACT_DIR):
                shutil.rmtree(VM_TEMP_EXTRACT_DIR)
            print("    ✅ Rollback complete.")
    else:
        print("    > Staging directory not found or empty, no rollback needed.")

    # Check for 0-byte artifacts in source
    if os.path.exists(source_dir):
        for filename in os.listdir(source_dir):
            file_path = os.path.join(source_dir, filename)
            if os.path.isfile(file_path) and os.path.getsize(file_path) == 0:
                quarantine_path = os.path.join(CONFIG["QUARANTINE_DIR"], filename)
                print(f"    ⚠️ Found 0-byte artifact: '{filename}'. Quarantining to {quarantine_path}...")
                os.makedirs(CONFIG["QUARANTINE_DIR"], exist_ok=True)
                try:
                    shutil.move(file_path, quarantine_path)
                except FileNotFoundError:
                     print(f"    > 0-byte artifact '{filename}' already moved or missing from source.")
    else:
        print("    > Source directory not found.")

    print("--> [POST] Integrity check complete.")


def plan_and_repackage_archive(archive_path, dest_dir, conn, tqdm_module):
    # Scans a large archive, hashes unique files, and repackages them into smaller,
    # crash-resilient parts while populating the database.
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
                print(f"    --> Batch contains {files_in_this_batch} unique files. Moving final part {part_number} to destination...")
                shutil.move(temp_batch_archive_path, final_dest_path)
                print(f"    ✅ Finished part {part_number}.")
            else:
                print(f"    > Batch {part_number} contained no unique files. Discarding empty batch.")
        return True
    except Exception as e: print(f"\n❌ ERROR during JIT repackaging: {e}"); traceback.print_exc(); return False
    finally:
        if os.path.exists(VM_TEMP_BATCH_DIR): shutil.rmtree(VM_TEMP_BATCH_DIR)

def process_regular_archive(archive_path, conn, tqdm_module):
    # Handles a regular-sized archive with Rsync-like file-level resumption by checking the DB
    # for already processed files and only unpacking the missing ones ("the delta").
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
                if member.name not in completed_files:
                    try:
                        tf.extract(member, path=VM_TEMP_EXTRACT_DIR, set_attrs=False)
                        files_to_process.append(member.name)
                    except Exception as e:
                        print(f"    ⚠️ Could not extract '{member.name}': {e}")
                        # Optionally quarantine the problematic file/archive here
                        pass


        if not files_to_process:
            print("    ✅ All files in this archive were already processed. Finalizing.")
            return True

        print(f"    ✅ Unpacked {len(files_to_process)} new/missing files to VM.")

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
            print("    > Cleaned up temporary VM directory.")

def deduplicate_files(source_path, primary_storage_path, trash_path, conn, source_archive_name):
    # Deduplicates new files against the primary storage and updates the database for unique files.
    print("\n--> [Step 2b] Deduplicating new files...")
    if not shutil.which('jdupes'):
        print("    ⚠️ 'jdupes' not found. Skipping.")
        return

    # Use a temporary directory for jdupes output to avoid issues with long paths
    jdupes_temp_dir = os.path.join('/tmp', 'jdupes_temp')
    os.makedirs(jdupes_temp_dir, exist_ok=True)

    # jdupes command - finds duplicates in source_path compared to primary_storage_path
    # --linkhard: hardlink duplicates in source_path to the ones in primary_storage_path
    # --move: move non-linked (unique) files from source_path to trash_path
    # -r: recursive
    # -S: show size
    # -n: no action (just report, but we use --linkhard and --move)
    # -h: hardlink (redundant with --linkhard but harmless)

    # Command to find duplicates and link/move
    command = f'jdupes -r -S --linkhard --move="{trash_path}" "{source_path}" "{primary_storage_path}"'
    print(f"    > Running jdupes command: {command}")
    result = subprocess.run(command, shell=True, capture_output=True, text=True)
    print("    > jdupes stdout:\n", result.stdout)
    if result.stderr:
        print("    > jdupes stderr:\n", result.stderr)


    cursor = conn.cursor()
    files_processed = 0
    # The actual uncompressed data is often in a "Takeout" subdirectory.
    takeout_source = os.path.join(source_path, "Takeout")

    if os.path.exists(takeout_source):
        print("    > Processing files remaining in temp directory and updating database...")
        # Files remaining in takeout_source after jdupes are unique and were not moved by --move
        # This happens if the file is unique but not a photo in the Google Photos structure, or if --move failed for some reason.
        # We should move these to the primary storage based on their original path structure.
        # A more robust approach would map original paths to desired final paths.
        # For now, let's place everything else in a 'OtherTakeoutFiles' subdir under BASE_DIR
        other_files_base_dir = os.path.join(BASE_DIR, "03-organized", "OtherTakeoutFiles")
        for root, _, files in os.walk(takeout_source):
            for filename in files:
                unique_file_path_temp = os.path.join(root, filename)
                # Calculate the relative path from the original archive's root
                original_relative_path_in_extract = os.path.relpath(unique_file_path_temp, VM_TEMP_EXTRACT_DIR)

                final_path = os.path.join(other_files_base_dir, original_relative_path_in_extract)

                os.makedirs(os.path.dirname(final_path), exist_ok=True)
                try:
                    shutil.move(unique_file_path_temp, final_path)
                    files_processed += 1

                    # Update the database record for this file
                    # This is tricky because the original_path in the DB was relative to the TAR root,
                    # and the path in VM_TEMP_EXTRACT_DIR is relative to VM_TEMP_EXTRACT_DIR.
                    # Assuming the structure is preserved, we can use the path relative to the
                    # VM_TEMP_EXTRACT_DIR as the key to find the original_path in the DB. This is not ideal
                    # as the original_path in the DB was relative to the TAR. A better DB schema would store
                    # the path *within the archive* explicitly.

                    # Let's try to match based on the path relative to the VM_TEMP_EXTRACT_DIR,
                    # hoping it matches the original_path stored in the DB.
                    cursor.execute("UPDATE files SET final_path = ? WHERE original_path = ? AND source_archive = ?",
                                   (final_path, original_relative_path_in_extract, source_archive_name))

                except FileNotFoundError:
                    print(f"    > File '{unique_file_path_temp}' not found, likely moved by jdupes.")
                except Exception as e:
                    print(f"    ❌ Error processing file '{unique_file_path_temp}': {e}")

        conn.commit() # Commit updates for files moved manually
    else:
         print("    > 'Takeout' directory not found in extracted temp location. No other files to process.")

    print(f"    ✅ Deduplication and move complete. Processed {files_processed} unique files.")
    # Clean up jdupes temp directory
    if os.path.exists(jdupes_temp_dir):
        shutil.rmtree(jdupes_temp_dir)


def organize_photos(source_path, final_dir, conn, tqdm_module, source_archive_name):
    # Organizes photos and updates their final path and timestamp in the database.
    print("\n--> [Step 2c] Organizing photos...")
    photos_organized_count = 0
    photos_source_path = os.path.join(source_path, "Takeout", "Google Photos")
    if not os.path.isdir(photos_source_path):
        print("    > 'Google Photos' directory not found. Skipping.")
        return

    # Use a set of existing filenames in the destination for quick lookup
    # This assumes the destination directory is not excessively large.
    # For very large collections, a database lookup might be more efficient.
    existing_filenames = set()
    if os.path.exists(final_dir):
         try:
            existing_filenames = set(os.listdir(final_dir))
         except Exception as e:
            print(f"    ⚠️ Could not list existing files in {final_dir}: {e}. Potential filename conflicts might occur.")
            existing_filenames = set() # Reset to empty set if listing fails


    all_json_files = []
    for root, _, files in os.walk(photos_source_path):
        for f in files:
            if f.lower().endswith('.json'):
                all_json_files.append(os.path.join(root, f))

    if not all_json_files:
        print("    > No JSON files found in Google Photos directory. Skipping photo organization.")
        return


    cursor = conn.cursor()
    organized_updates = [] # Collect updates to commit in a batch

    for json_path in tqdm_module(all_json_files, desc="Organizing photos"):
        media_path = os.path.splitext(json_path)[0]
        # Check for associated media file (image or video)
        media_exists = False
        media_file_to_process = None
        for ext in ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.mp4', '.mov', '.avi', '.webm']:
             potential_media_path = media_path + ext
             if os.path.exists(potential_media_path):
                  media_exists = True
                  media_file_to_process = potential_media_path
                  break # Found the associated media file

        if not media_exists or not media_file_to_process:
            # print(f"    > No associated media file found for {json_path}. Skipping.")
            continue # Skip if no associated media file


        try:
            with open(json_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            ts = data.get('photoTakenTime', {}).get('timestamp')
            if not ts:
                # print(f"    > No timestamp found in {json_path}. Skipping.")
                continue

            dt = datetime.fromtimestamp(int(ts))
            new_name_base = dt.strftime('%Y-%m-%d_%Hh%Mm%Ss')
            ext = os.path.splitext(media_file_to_process)[1].lower()
            new_filename = f"{new_name_base}{ext}"
            counter = 0
            original_new_filename = new_filename # Store the original filename before adding counter

            # Handle potential filename conflicts in the destination directory
            while new_filename in existing_filenames:
                counter += 1
                new_filename = f"{new_name_base}_{counter}{ext}"
                if counter > 1000: # Prevent infinite loops for extreme cases
                     print(f"    ⚠️ Too many conflicts for {original_new_filename}. Skipping.")
                     new_filename = None # Indicate skipping this file
                     break

            if new_filename is None:
                 continue # Skip if too many conflicts

            final_filepath = os.path.join(final_dir, new_filename)
            os.makedirs(final_dir, exist_ok=True) # Ensure destination directory exists

            # Move the media file
            shutil.move(media_file_to_process, final_filepath)
            photos_organized_count += 1
            existing_filenames.add(new_filename) # Add the new filename to the set

            # Delete the associated JSON file after processing
            try:
                os.remove(json_path)
            except OSError as e:
                print(f"    ⚠️ Could not delete JSON file {json_path}: {e}")


            # Prepare database update
            # The original_path in the DB was relative to the TAR root.
            # The path in VM_TEMP_EXTRACT_DIR is relative to VM_TEMP_EXTRACT_DIR.
            # We need to find the original_path that corresponds to media_file_to_process.
            # This is the same challenge as in deduplicate_files.
            # Let's use the path relative to VM_TEMP_EXTRACT_DIR as the key for now.
            original_path_in_extract = os.path.relpath(media_file_to_process, source_path)

            organized_updates.append((final_filepath, int(ts), original_path_in_extract, source_archive_name))


        except Exception as e:
            print(f"    ❌ Error processing JSON file {json_path}: {e}")
            traceback.print_exc()
            continue

    if organized_updates:
        print(f"    > Committing {len(organized_updates)} database updates...")
        cursor.executemany("UPDATE files SET final_path = ?, timestamp = ? WHERE original_path = ? AND source_archive = ?", organized_updates)
        conn.commit()
        print(f"    ✅ Organized and updated DB for {photos_organized_count} new files.")
    else:
        print("    > No new photos were organized.")


# ==============================================================================
# --- MAIN EXECUTION SCRIPT ---
# ==============================================================================
def main(args):
    conn = None
    try:
        print("--> [Step 0] Initializing environment...")
        try:
            # Use dummy_tqdm if tqdm is not available
            from tqdm.auto import tqdm
        except ImportError:
            tqdm = dummy_tqdm
            print("    ⚠️ tqdm not found. Using dummy progress indicator.")


        # Google Drive mounting code removed for standalone script


        for path in CONFIG.values():
             os.makedirs(path, exist_ok=True)
             print(f"    > Ensuring directory exists: {path}")

        conn = initialize_database(DB_PATH)
        perform_startup_integrity_check()

        # Check available disk space where temporary files will be extracted
        # On Raspberry Pi, /tmp is usually on the root filesystem or RAM.
        # We should check the disk where BASE_DIR resides if possible, but checking /tmp is crucial for extraction.
        # Let's check /tmp for extraction space
        if os.path.exists('/tmp'):
             total_tmp, used_tmp, free_tmp = shutil.disk_usage('/tmp')
             free_tmp_gb = free_tmp / (1024**3)
             # Need enough space for extracting at least one archive chunk
             required_tmp_gb = REPACKAGE_CHUNK_SIZE_GB + 5 # Add some buffer
             if free_tmp_gb < required_tmp_gb:
                 print(f"\n❌ PRE-FLIGHT CHECK FAILED: Insufficient free disk space in /tmp ({free_tmp_gb:.2f} GB). Required: ~{required_tmp_gb:.2f} GB.")
                 print("    >>> Please ensure enough free space in /tmp or configure a different temporary directory. <<<")
                 return
             print(f"✅ Pre-flight /tmp disk check passed. (Free Space: {free_tmp_gb:.2f} GB)")
        else:
             print("    ⚠️ /tmp directory not found. Skipping /tmp disk check.")


        # Check available disk space in the BASE_DIR where files will be stored
        if os.path.exists(BASE_DIR):
            total_base, used_base, free_base = shutil.disk_usage(BASE_DIR)
            free_base_gb = free_base / (1024**3)
            print(f"✅ Pre-flight BASE_DIR disk check passed. (Free Space in {BASE_DIR}: {free_base_gb:.2f} GB)")
        else:
            print(f"    ⚠️ BASE_DIR '{BASE_DIR}' not found. Cannot perform disk space check on destination.")


        # Install jdupes if not found
        if not shutil.which('jdupes'):
            print("\n    > jdupes not found. Attempting to install...")
            try:
                subprocess.run("sudo apt-get update && sudo apt-get install -y jdupes", shell=True, check=True)
                print("    ✅ jdupes installed successfully.")
            except subprocess.CalledProcessError as e:
                print(f"    ❌ Failed to install jdupes: {e}")
                print("    >>> Deduplication will be skipped. Please install jdupes manually. <<<")
        else:
             print("    ✅ jdupes already installed.")


        print("✅ Workspace ready.")

        print("\n--> [Step 1] Identifying unprocessed archives...")
        # Ensure source directory exists before listing
        if not os.path.exists(CONFIG["SOURCE_ARCHIVES_DIR"]):
            print(f"    ❌ Source archives directory not found: {CONFIG['SOURCE_ARCHIVES_DIR']}. Please place your archives here.")
            return

        all_archives = set(os.listdir(CONFIG["SOURCE_ARCHIVES_DIR']))
        completed_archives = set()
        # Ensure completed directory exists before listing
        if os.path.exists(CONFIG["COMPLETED_ARCHIVES_DIR"]):
             completed_archives = set(os.listdir(CONFIG["COMPLETED_ARCHIVES_DIR"]))
        else:
             print(f"    > Completed archives directory not found: {CONFIG['COMPLETED_ARCHIVES_DIR']}. Assuming no archives completed yet.")


        processing_queue = sorted(list(all_archives - completed_archives))

        if not processing_queue:
            print("\n✅🎉 All archives have been processed!")
        else:
            archive_name = processing_queue[0]
            source_path = os.path.join(CONFIG["SOURCE_ARCHIVES_DIR"], archive_name)
            staging_path = os.path.join(CONFIG["PROCESSING_STAGING_DIR"], archive_name)

            print(f"--> Locking and staging '{archive_name}' for processing...")
            try:
                shutil.move(source_path, staging_path)
                print(f"    ✅ '{archive_name}' moved to staging.")
            except FileNotFoundError:
                print(f"    ❌ Source archive not found at '{source_path}'. Skipping.")
                return # Skip this archive if not found

            archive_size_gb = os.path.getsize(staging_path) / (1024**3)
            print(f"    > Archive size: {archive_size_gb:.2f} GB")

            # Check if repackaging is needed or if it's already a part file
            if archive_size_gb > MAX_SAFE_ARCHIVE_SIZE_GB and '.part-' not in archive_name:
                print(f"    > Archive size exceeds safe limit ({MAX_SAFE_ARCHIVE_SIZE_GB} GB). Initiating repackaging...")
                repackaging_ok = plan_and_repackage_archive(staging_path, CONFIG["SOURCE_ARCHIVES_DIR"], conn, tqdm)
                if repackaging_ok:
                    print(f"\n--> Repackaging of '{archive_name}' complete. Moving original to completed.")
                    shutil.move(staging_path, os.path.join(CONFIG["COMPLETED_ARCHIVES_DIR"], archive_name))
                    print(f"    ✅ Original archive '{archive_name}' moved to completed.")
                else:
                    print(f"\n❌ Repackaging failed for '{archive_name}'. Leaving in staging.")
                    # Rollback happens on next run via integrity check
            else:
                print(f"    > Archive size is within safe limit or is a part file. Processing directly.")
                processed_ok = process_regular_archive(staging_path, conn, tqdm)
                if processed_ok:
                    print(f"\n--> Processing of '{archive_name}' complete. Moving to completed.")
                    shutil.move(staging_path, os.path.join(CONFIG["COMPLETED_ARCHIVES_DIR"], archive_name))
                    print(f"    ✅ Processed archive '{archive_name}' moved to completed.")
                else:
                    print(f"\n❌ Processing failed for '{archive_name}'. Leaving in staging.")
                    # Rollback happens on next run via integrity check

            print("\n--- WORKFLOW CYCLE COMPLETE. ---")
    except Exception as e:
        print(f"\n❌ A CRITICAL UNHANDLED ERROR OCCURRED: {e}")
        traceback.print_exc()
    finally:
        if conn:
            conn.close()
            print("--> [DB] Database connection closed.")
        # Clean up temporary directories regardless of success/failure
        if os.path.exists(VM_TEMP_EXTRACT_DIR):
             try: shutil.rmtree(VM_TEMP_EXTRACT_DIR)
             except Exception as e: print(f"    ⚠️ Failed to clean up {VM_TEMP_EXTRACT_DIR}: {e}")
        if os.path.exists(VM_TEMP_BATCH_DIR):
             try: shutil.rmtree(VM_TEMP_BATCH_DIR)
             except Exception as e: print(f"    ⚠️ Failed to clean up {VM_TEMP_BATCH_DIR}: {e}")
        print("--> Temporary directories cleaned up.")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Process Google Takeout archives.")
    parser.add_argument('--auto-delete-artifacts', action='store_true', help="Enable automatic deletion of 0-byte artifact files.")
    # The bash script will handle setting GOOGLE_APPLICATION_CREDENTIALS in the environment
    # parser.add_argument('--credentials', type=str, default=os.path.join(os.path.expand_user("~"), ".secrets", "credentials.json"), help="Path to Google Cloud credentials JSON file.")
    # parser.add_argument('--base-dir', type=str, default="/mnt/storage/TakeoutProject", help="Base directory for Takeout processing.")

    args = parser.parse_args()

    # Set BASE_DIR from environment variable if available
    # if args.base_dir:
    #     BASE_DIR = args.base_dir
    #     CONFIG["SOURCE_ARCHIVES_DIR"] = os.path.join(BASE_DIR, "00-ALL-ARCHIVES/")
    #     CONFIG["PROCESSING_STAGING_DIR"] = os.path.join(BASE_DIR, "01-PROCESSING-STAGING/")
    #     CONFIG["ORGANIZED_DIR"] = os.path.join(BASE_DIR, "03-organized/My-Photos/")
    #     CONFIG["TRASH_DIR"] = os.path.join(BASE_DIR, "04-trash/")
    #     CONFIG["COMPLETED_ARCHIVES_DIR"] = os.path.join(BASE_DIR, "05-COMPLETED-ARCHIVES/")
    #     CONFIG["QUARANTINE_DIR"] = os.path.join(CONFIG["TRASH_DIR"], "quarantined_artifacts/")
    #     CONFIG["DUPES_DIR"] = os.path.join(CONFIG["TRASH_DIR"], "duplicates/")
    #     DB_PATH = os.path.join(BASE_DIR, "takeout_archive.db")


    main(args)

EOF

echo "Installing dependencies (jdupes, tqdm)..."
sudo apt-get update -y
sudo apt-get install -y jdupes
pip install tqdm

echo "Creating installation directory..."
INSTALL_DIR="/usr/local/bin/takeout_organizer"
sudo mkdir -p "$INSTALL_DIR"

echo "Saving Python script..."
SCRIPT_NAME="takeout_organizer.py"
# Use printf to handle potential issues with echo and complex strings/newlines
printf "%s" "$PYTHON_SCRIPT" | sudo tee "$INSTALL_DIR/$SCRIPT_NAME" > /dev/null

echo "Making the script executable..."
sudo chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

echo "Setting GOOGLE_APPLICATION_CREDENTIALS environment variable..."
CREDENTIALS_PATH="$HOME/.secrets/credentials.json"
# Check if the export line already exists in the user's bash profile
if ! grep -q "export GOOGLE_APPLICATION_CREDENTIALS=\"$CREDENTIALS_PATH\"" "$HOME/.bashrc"; then
  echo "export GOOGLE_APPLICATION_CREDENTIALS=\"$CREDENTIALS_PATH\"" >> "$HOME/.bashrc"
  echo "Added export command to ~/.bashrc"
else
  echo "Export command already exists in ~/.bashrc"
fi

echo "Installation complete."
echo "The script is located at $INSTALL_DIR/$SCRIPT_NAME"
echo "The GOOGLE_APPLICATION_CREDENTIALS environment variable has been set in ~/.bashrc."
echo "You may need to source your ~/.bashrc file (source ~/.bashrc) for the environment variable to take effect in the current terminal session."
echo "Ensure your credentials file exists at $CREDENTIALS_PATH"
echo "You can now run the script using: python $INSTALL_DIR/$SCRIPT_NAME"
