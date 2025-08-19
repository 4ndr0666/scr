#!/bin/bash
#
# DietPi First-Boot Custom Script for Takeout Processor Appliance (v5.0 - Faithful Port)
# This version is a direct, faithful port of the working Colab script (v4.1.1).
# It assumes Google Drive is mounted at the target path by an external mechanism.

set -euo pipefail

# --- Configuration ---
INSTALL_DIR="/opt/google_takeout_organizer"
# Corrected Google Drive mount point based on user feedback
GDRIVE_MOUNT_POINT="/content/drive/MyDrive"

PROCESSOR_FILENAME="google_takeout_organizer.py"
PROCESSOR_SCRIPT_PATH="${INSTALL_DIR}/${PROCESSOR_FILENAME}"
PROCESSOR_SERVICE_NAME="takeout-organizer.service"
PROCESSOR_SERVICE_PATH="/etc/systemd/system/${PROCESSOR_SERVICE_NAME}"

# --- Logging Utilities ---
_log_info() { printf "\n[INFO] %s\n" "$*"; }
_log_ok()   { printf "✅ %s\n" "$*"; }
_log_warn() { printf "⚠️  %s\n" "$*"; }
_log_fail() { printf "❌ ERROR: %s\n" "$*"; exit 1; }

# ==============================================================================
# --- Main Installation Logic ---
# ==============================================================================
main() {
    _log_info "--- Starting Takeout Processor Appliance Setup (v5.0 Faithful Port) ---"
    if [[ $EUID -ne 0 ]]; then _log_fail "This script must be run as root."; fi

    _log_info "Ensuring any old service is stopped..."
    systemctl stop ${PROCESSOR_SERVICE_NAME} &>/dev/null || true
    systemctl disable ${PROCESSOR_SERVICE_NAME} &>/dev/null || true
    # Clean up old rclone service if it exists (assuming rclone was used for mounting in previous setups)
    systemctl stop gdrive-mount.service &>/dev/null || true
    systemctl disable gdrive-mount.service &>/dev/null || true
    rm -f /etc/systemd/system/gdrive-mount.service
    _log_ok "Services stopped and disabled."

    _log_info "Updating package lists and installing dependencies..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y python3 python3-pip jdupes # Removed tar and gzip as they should be standard
    pip3 install tqdm # Install tqdm for the Python script
    pip3 install PyDrive2 # Install PyDrive2
    pip3 install PyDrive2 # Install PyDrive2
    _log_ok "Dependencies installed."

    _log_info "Creating installation directory..."
    mkdir -p "${INSTALL_DIR}"
    _log_ok "Directory created: ${INSTALL_DIR}"

    _log_info "Deploying the Python processor script..."
    cat <<'EOF' > "${PROCESSOR_SCRIPT_PATH}"
#!/usr/bin/env python3

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
from pydrive2.auth import GoogleAuth
from pydrive2.drive import GoogleDrive

# ==============================================================================
# --- 1. CORE CONFIGURATION ---
# ==============================================================================
TARGET_MAX_VM_USAGE_GB = 70
REPACKAGE_CHUNK_SIZE_GB = 15
MAX_SAFE_ARCHIVE_SIZE_GB = 25

# Assuming Google Drive is mounted at this path - THIS WILL BE REPLACED BY PYDRIVE2 LOGIC
# BASE_DIR will be determined by PyDrive2
# DB_PATH will be local
INSTALL_DIR = "/opt/google_takeout_organizer" # This comes from the bash script
DB_PATH = os.path.join(INSTALL_DIR, "takeout_archive.db")

# CONFIG will store PyDrive2 folder IDs instead of paths
CONFIG = {}

# Use standard temporary directories instead of Colab's VM specific ones
VM_TEMP_EXTRACT_DIR = '/tmp/temp_extract'
VM_TEMP_BATCH_DIR = '/tmp/temp_batch_creation'
VM_TEMP_DOWNLOAD_DIR = '/tmp/temp_download' # New temporary directory for downloads

# ==============================================================================
# --- 2. WORKFLOW FUNCTIONS & HELPERS ---
# ==============================================================================
def dummy_tqdm(iterable, *args, **kwargs):
    """A dummy tqdm function that acts as a fallback if tqdm is not available."""
    description = kwargs.get('desc', 'items')
    print(f"    > Processing {description}...")
    return iterable

try:
    from tqdm import tqdm
except ImportError:
    tqdm = dummy_tqdm

def authenticate_drive():
    """Authenticates with Google Drive using a service account."""
    print("--> [Auth] Authenticating with Google Drive...")
    gauth = GoogleAuth()
    # Load service account credentials from a JSON file
    # The path to client_secrets.json should be configured on the Raspberry Pi
    # For now, hardcode a likely path within the installation directory
    service_account_file = os.path.join(INSTALL_DIR, "client_secrets.json")
    if not os.path.exists(service_account_file):
         raise FileNotFoundError(f"Service account credentials file not found at {service_account_file}")

    gauth.DEFAULT_SETTINGS['client_config_file'] = service_account_file
    gauth.DEFAULT_SETTINGS['save_credentials'] = False # Don't save credentials to file
    gauth.CommandLineAuth() # Use this for service account
    drive = GoogleDrive(gauth)
    print("    ✅ Authentication successful.")
    return drive

def find_or_create_folder(drive, parent_folder_id, folder_name):
    """Finds a folder by name within a parent, or creates it if it doesn't exist."""
    query = f"title = '{folder_name}' and '{parent_folder_id}' in parents and trashed = false and mimeType = 'application/vnd.google-apps.folder'"
    file_list = drive.ListFile({'q': query}).GetList()
    if file_list:
        print(f"    ✅ Found folder '{folder_name}': {file_list[0]['id']}")
        return file_list[0]['id']
    else:
        print(f"    > Folder '{folder_name}' not found. Creating...")
        folder_metadata = {'title': folder_name, 'parents': [{'id': parent_folder_id}], 'mimeType': 'application/vnd.google-apps.folder'}
        folder = drive.CreateFile(folder_metadata)
        folder.Upload()
        print(f"    ✅ Created folder '{folder_name}': {folder['id']}")
        return folder['id']

def setup_drive_folders(drive):
    """Sets up the necessary folder structure on Google Drive and stores their IDs in CONFIG."""
    print("--> [Drive] Setting up base folder structure...")
    # Find or create the root TakeoutProject folder
    # 'root' is the special ID for the root folder
    takeout_project_folder_id = find_or_create_folder(drive, 'root', 'TakeoutProject')

    # Create subfolders within TakeoutProject
    CONFIG["SOURCE_ARCHIVES_DIR_ID"] = find_or_create_folder(drive, takeout_project_folder_id, "00-ALL-ARCHIVES")
    CONFIG["PROCESSING_STAGING_DIR_ID"] = find_or_create_folder(drive, takeout_project_folder_id, "01-PROCESSING-STAGING")
    CONFIG["TRASH_DIR_ID"] = find_or_create_folder(drive, takeout_project_folder_id, "04-trash")
    CONFIG["COMPLETED_ARCHIVES_DIR_ID"] = find_or_create_folder(drive, takeout_project_folder_id, "05-COMPLETED-ARCHIVES")

    # Create subfolders within TRASH
    CONFIG["QUARANTINE_DIR_ID"] = find_or_create_folder(drive, CONFIG["TRASH_DIR_ID"], "quarantined_artifacts")
    CONFIG["DUPES_DIR_ID"] = find_or_create_folder(drive, CONFIG["TRASH_DIR_ID"], "duplicates")

    # Handle the organized photos directory separately as it has a nested structure
    organized_base_id = find_or_create_folder(drive, takeout_project_folder_id, "03-organized")
    CONFIG["ORGANIZED_DIR_ID"] = find_or_create_folder(drive, organized_base_id, "My-Photos")

    print("    ✅ Google Drive folder structure ready.")

def list_drive_files(drive, folder_id):
    """Lists files in a specific Google Drive folder."""
    query = f"'{folder_id}' in parents and trashed = false"
    file_list = drive.ListFile({'q': query}).GetList()
    return file_list

def get_drive_file_by_name(drive, folder_id, file_name):
    """Finds a file by name within a specific Google Drive folder."""
    query = f"title = '{file_name}' and '{folder_id}' in parents and trashed = false"
    file_list = drive.ListFile({'q': query}).GetList()
    return file_list[0] if file_list else None

def download_drive_file(drive, file_id, local_path):
    """Downloads a file from Google Drive to a local path."""
    print(f"    > Downloading file ID {file_id} to {local_path}...")
    file_obj = drive.CreateFile({'id': file_id})
    file_obj.GetContentFile(local_path)
    print(f"    ✅ Download complete.")

def upload_drive_file(drive, local_path, parent_folder_id, file_name=None):
    """Uploads a local file to a specific Google Drive folder."""
    file_name = file_name if file_name else os.path.basename(local_path)
    print(f"    > Uploading '{file_name}' to folder ID {parent_folder_id}...")
    file_metadata = {'title': file_name, 'parents': [{'id': parent_folder_id}]}
    file_obj = drive.CreateFile(file_metadata)
    file_obj.SetContentFile(local_path)
    file_obj.Upload()
    print(f"    ✅ Upload complete. File ID: {file_obj['id']}")
    return file_obj['id']

def move_drive_file(drive, file_id, new_parent_folder_id):
    """Moves a Google Drive file to a new parent folder."""
    print(f"    > Moving file ID {file_id} to folder ID {new_parent_folder_id}...")
    file_obj = drive.CreateFile({'id': file_id})
    # Remove the old parent and add the new one
    original_parents = file_obj['parents']
    file_obj['parents'] = [{'id': new_parent_folder_id}]
    # Optionally remove old parents explicitly if needed, but PyDrive2 handles this usually
    # For robustness, especially if multiple parents were possible:
    # file_obj.RemoveParents(','.join([p['id'] for p in original_parents]))
    # file_obj.AddParents(new_parent_folder_id)
    file_obj.Upload()
    print(f"    ✅ Move complete.")

def delete_drive_file(drive, file_id):
    """Deletes a file from Google Drive (moves to trash)."""
    print(f"    > Deleting file ID {file_id}...")
    file_obj = drive.CreateFile({'id': file_id})
    file_obj.Delete()
    print(f"    ✅ Delete complete.")

def perform_startup_integrity_check(drive):
    """Performs a "Power-On Self-Test" to detect and correct inconsistent states."""
    print("--> [POST] Performing startup integrity check...")
    staging_folder_id = CONFIG["PROCESSING_STAGING_DIR_ID"]
    source_folder_id = CONFIG["SOURCE_ARCHIVES_DIR_ID"]
    quarantine_folder_id = CONFIG["QUARANTINE_DIR_ID"]

    # Check for orphaned files in staging
    staging_files = list_drive_files(drive, staging_folder_id)
    if staging_files:
        print("    ⚠️ Found orphaned files in staging. Rolling back transaction...")
        for file_obj in staging_files:
            move_drive_file(drive, file_obj['id'], source_folder_id)
        # Clean up local temp directories if they exist from a previous failed run
        if os.path.exists(VM_TEMP_EXTRACT_DIR):
            shutil.rmtree(VM_TEMP_EXTRACT_DIR, ignore_errors=True)
        if os.path.exists(VM_TEMP_BATCH_DIR):
            shutil.rmtree(VM_TEMP_BATCH_DIR, ignore_errors=True)
        if os.path.exists(VM_TEMP_DOWNLOAD_DIR):
            shutil.rmtree(VM_TEMP_DOWNLOAD_DIR, ignore_errors=True)
        print("    ✅ Rollback complete.")

    # Check for 0-byte artifacts in source (PyDrive2 file size is 'fileSize')
    source_files = list_drive_files(drive, source_folder_id)
    for file_obj in source_files:
        # Convert fileSize to integer, handle None or missing key
        file_size = int(file_obj.get('fileSize', 0) or 0)
        if file_size == 0:
            print(f"    ⚠️ Found 0-byte artifact: '{file_obj['title']}'. Quarantining...")
            move_drive_file(drive, file_obj['id'], quarantine_folder_id)

    print("--> [POST] Integrity check complete.")


def plan_and_repackage_archive(drive, archive_file_obj, dest_folder_id, conn, tqdm_module):
    """
    Scans a large archive (downloaded locally), hashes unique files, and repackages them into smaller,
    crash-resilient parts (uploaded to Drive) while populating the database.
    """
    archive_name = archive_file_obj['title']
    archive_id = archive_file_obj['id']
    original_basename_no_ext = os.path.splitext(archive_name)[0]
    print(f"--> Repackaging & Indexing '{archive_name}'...")

    # Download the large archive locally for processing
    os.makedirs(VM_TEMP_DOWNLOAD_DIR, exist_ok=True)
    local_archive_path = os.path.join(VM_TEMP_DOWNLOAD_DIR, archive_name)
    download_drive_file(drive, archive_id, local_archive_path)

    repackage_chunk_size_bytes = REPACKAGE_CHUNK_SIZE_GB * (1024**3)
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT sha256_hash FROM files")
        existing_hashes = {row[0] for row in cursor.fetchall()}
        print(f"    > Index loaded with {len(existing_hashes)} records.")

        # Check for existing parts in the destination folder on Google Drive
        existing_parts_files = list_drive_files(drive, dest_folder_id)
        existing_parts_names = [f['title'] for f in existing_parts_files]
        last_part_num = 0
        if existing_parts_names:
            part_numbers = [int(re.search(r'\.part-(\d+)\.tgz', f).group(1)) for f in existing_parts_names if re.search(r'\.part-(\d+)\.tgz', f)]
            if part_numbers: last_part_num = max(part_numbers)
            print(f"    ✅ Resuming after part {last_part_num}.")

        batches, current_batch, current_batch_size = [], [], 0
        with tarfile.open(local_archive_path, 'r:gz') as original_tar:
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
                with tarfile.open(local_archive_path, 'r:gz') as original_tar_stream:
                    for member in tqdm_module(batch, desc=f"Hashing & Staging Batch {part_number}"):
                        file_obj_stream = original_tar_stream.extractfile(member)
                        if not file_obj_stream: continue
                        file_content = file_obj_stream.read()
                        sha256 = hashlib.sha256(file_content).hexdigest()

                        # Check against DB and against files already added to this batch (in case of dupes within batch)
                        cursor.execute("SELECT 1 FROM files WHERE sha256_hash = ?", (sha256,))
                        if cursor.fetchone() is not None:
                             continue # Already processed this file (globally or in a previous part)

                        file_obj_stream.seek(0) # Reset stream position after reading for hash
                        temp_tar.addfile(member, file_obj_stream)

                        # Insert into DB *before* uploading to handle crashes during upload
                        # final_path is null initially, updated after successful move/upload
                        cursor.execute("INSERT INTO files (sha256_hash, original_path, file_size, source_archive) VALUES (?, ?, ?, ?)",
                                       (sha256, member.name, member.size, archive_name))
                        conn.commit() # Commit immediately for crash resilience
                        files_in_this_batch += 1

            # Upload the part only if it contains unique files
            if files_in_this_batch > 0:
                new_archive_name = f"{original_basename_no_ext}.part-{part_number:02d}.tgz"
                print(f"    --> Batch contains {files_in_this_batch} unique files. Uploading final part {part_number} to Google Drive...")
                # Upload the newly created part archive
                uploaded_file_id = upload_drive_file(drive, temp_batch_archive_path, dest_folder_id, new_archive_name)
                # In a repackaged scenario, the 'final_path' in the DB could potentially store the Google Drive File ID
                # for the *part archive itself*, or remain null until the individual files are processed later.
                # For now, we'll leave final_path null as the individual files within the part aren't yet organized.
                print(f"    ✅ Finished part {part_number}.")
            else:
                print(f"    > Batch {part_number} contained no unique files. Discarding empty batch.")

        return True # Indicate successful repackaging
    except Exception as e:
        print(f"
❌ ERROR during JIT repackaging: {e}")
        traceback.print_exc()
        return False # Indicate failure
    finally:
        # Clean up local temporary directories
        if os.path.exists(VM_TEMP_BATCH_DIR): shutil.rmtree(VM_TEMP_BATCH_DIR, ignore_errors=True)
        if os.path.exists(VM_TEMP_DOWNLOAD_DIR): shutil.rmtree(VM_TEMP_DOWNLOAD_DIR, ignore_errors=True)
        print("    > Cleaned up temporary local directories.")


def process_regular_archive(drive, archive_file_obj, conn, tqdm_module):
    """
    Handles a regular-sized archive by downloading it locally, extracting,
    processing files locally, and then uploading processed files to Drive.
    """
    archive_name = archive_file_obj['title']
    archive_id = archive_file_obj['id']
    print(f"
--> [Step 2a] Processing transaction for '{archive_name}'...")
    cursor = conn.cursor()

    # Download the archive locally for processing
    os.makedirs(VM_TEMP_DOWNLOAD_DIR, exist_ok=True)
    local_archive_path = os.path.join(VM_TEMP_DOWNLOAD_DIR, archive_name)
    download_drive_file(drive, archive_id, local_archive_path)

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
        with tarfile.open(local_archive_path, 'r:gz') as tf:
            all_members = [m for m in tf.getmembers() if m.isfile()]
            for member in tqdm_module(all_members, desc=f"Scanning and Extracting {archive_name}"):
                # Check if the file has already been processed (final_path is not NULL)
                cursor.execute("SELECT 1 FROM files WHERE original_path = ? AND source_archive = ? AND final_path IS NOT NULL", (member.name, archive_name))
                if cursor.fetchone() is None:
                    # File has not been processed, extract it
                    try:
                        tf.extract(member, path=VM_TEMP_EXTRACT_DIR, set_attrs=False)
                        files_to_process.append(member.name)
                        # Also ensure the file is in the database with final_path NULL
                        cursor.execute("INSERT OR IGNORE INTO files (sha256_hash, original_path, file_size, source_archive) VALUES (?, ?, ?, ?)",
                                       ('', member.name, member.size, archive_name)) # SHA256 will be calculated later if needed
                        conn.commit() # Commit after each extraction for resilience
                    except Exception as extract_e:
                        print(f"    ⚠️ Failed to extract '{member.name}': {extract_e}")
                        # Optionally log this or move to quarantine
                        continue # Skip this file

        if not files_to_process:
            print("    ✅ All files in this archive were already processed. Finalizing.")
            return True # Indicate successful processing

        print(f"    ✅ Unpacked {len(files_to_process)} new/missing files to local VM.")

        # Subsequent steps now operate on the much smaller "delta" of new files in VM_TEMP_EXTRACT_DIR.
        # These functions will need to be updated to handle local paths and then upload to Drive.
        organize_photos(drive, VM_TEMP_EXTRACT_DIR, CONFIG["ORGANIZED_DIR_ID"], conn, tqdm_module, archive_name)
        deduplicate_files(drive, VM_TEMP_EXTRACT_DIR, CONFIG["ORGANIZED_DIR_ID"], CONFIG["DUPES_DIR_ID"], conn, archive_name)

        # After processing, move any remaining unique files from VM_TEMP_EXTRACT_DIR to Google Drive
        print("    > Moving remaining unique files to Google Drive...")
        takeout_source = os.path.join(VM_TEMP_EXTRACT_DIR, "Takeout")
        files_uploaded_after_dedupe = 0
        if os.path.exists(takeout_source):
            for root, _, files in os.walk(takeout_source):
                for filename in files:
                    local_file_path = os.path.join(root, filename)
                    relative_path = os.path.relpath(local_file_path, takeout_source)
                    # Construct the intended final path on Google Drive (for DB update)
                    # This needs to map the local relative path to the Drive folder structure
                    # Assuming non-photo files go into a general organized folder or similar
                    # For simplicity, let's upload them to a 'misc' subfolder within 03-organized
                    misc_folder_id = find_or_create_folder(drive, CONFIG["ORGANIZED_DIR_ID"], "misc")
                    # Determine the target folder ID based on relative_path
                    # This is a simplified approach; a more robust solution might parse relative_path
                    # to recreate the directory structure on Drive.
                    target_folder_id = misc_folder_id # Default to misc

                    # Check if this file has already been moved/uploaded by organize_photos or deduplicate_files
                    # We need to look up the original_path in the DB
                    original_path_in_archive = os.path.relpath(local_file_path, VM_TEMP_EXTRACT_DIR)
                    cursor.execute("SELECT final_path FROM files WHERE original_path = ? AND source_archive = ?", (original_path_in_archive, archive_name))
                    db_record = cursor.fetchone()

                    if db_record and db_record[0] is not None:
                        # File was already handled by photo organization or deduplication
                        # print(f"    > Skipping '{relative_path}': already processed.")
                        # Clean up the local file if it was already processed in a previous run
                        if os.path.exists(local_file_path):
                            try: os.remove(local_file_path)
                            except Exception as remove_e: print(f"    ⚠️ Failed to remove already processed local file '{local_file_path}': {remove_e}")
                        continue # Skip files that already have a final_path

                    # File is unique and not a photo (or not handled by organize_photos)
                    # Upload the file and update the DB
                    try:
                        # Upload the file to the determined target folder on Drive
                        uploaded_file_id = upload_drive_file(drive, local_file_path, target_folder_id, os.path.basename(local_file_path))
                        # Update the DB with the Google Drive File ID as the final_path
                        cursor.execute("UPDATE files SET final_path = ? WHERE original_path = ? AND source_archive = ?",
                                       (uploaded_file_id, original_path_in_archive, archive_name))
                        conn.commit() # Commit immediately after each upload
                        files_uploaded_after_dedupe += 1
                        # Delete the local temporary file after successful upload
                        os.remove(local_file_path)
                    except Exception as upload_e:
                         print(f"    ❌ Failed to upload unique file '{local_file_path}': {upload_e}")
                         # Log the error but continue with other files
                         continue


        print(f"    ✅ Processing of delta complete. Uploaded {files_uploaded_after_dedupe} remaining unique files.")

        return True # Indicate successful processing
    except Exception as e:
        print(f"
❌ ERROR during archive processing transaction: {e}")
        traceback.print_exc()
        return False # Indicate failure
    finally:
        # Clean up local temporary directories
        if os.path.exists(VM_TEMP_EXTRACT_DIR): shutil.rmtree(VM_TEMP_EXTRACT_DIR, ignore_errors=True)
        if os.path.exists(VM_TEMP_DOWNLOAD_DIR): shutil.rmtree(VM_TEMP_DOWNLOAD_DIR, ignore_errors=True)
        print("    > Cleaned up temporary local directories.")

def deduplicate_files(drive, source_local_path, primary_storage_folder_id, trash_folder_id, conn, source_archive_name):
    """
    Deduplicates new files (in a local temporary directory) against files already
    in the primary Google Drive storage using jdupes, then handles moves/deletes via PyDrive2.
    """
    print("
--> [Step 2b] Deduplicating new files...")
    if not shutil.which('jdupes'):
        print("    ⚠️ 'jdupes' not found. Skipping deduplication.")
        # If jdupes is not available, files will be handled by the final move logic in process_regular_archive
        return

    # jdupes needs local paths. It will identify duplicates between source_local_path and
    # a local copy/representation of the primary_storage_folder_id.
    # However, creating a local copy of potentially the entire primary storage is not feasible.
    # A better approach:
    # 1. Calculate hashes for all files in source_local_path.
    # 2. Check these hashes against the database (which represents files already moved to primary storage).
    # 3. Move local unique files to a temp 'unique' folder.
    # 4. Move local duplicate files to a temp 'dupes' folder.
    # 5. Use PyDrive2 to upload files from the local 'unique' folder to the primary storage folder on Drive.
    # 6. Use PyDrive2 to upload files from the local 'dupes' folder to the duplicates folder on Drive.
    # 7. Update the database with the final Google Drive File IDs.
    # 8. Clean up local temp folders.

    temp_unique_dir = os.path.join('/tmp', 'jdupes_unique')
    temp_dupes_dir = os.path.join('/tmp', 'jdupes_dupes')
    os.makedirs(temp_unique_dir, exist_ok=True)
    os.makedirs(temp_dupes_dir, exist_ok=True)

    cursor = conn.cursor()
    files_identified_as_unique = []
    files_identified_as_dupes = []

    # The actual uncompressed data is often in a "Takeout" subdirectory.
    takeout_source_local = os.path.join(source_local_path, "Takeout")

    if os.path.exists(takeout_source_local):
        print("    > Hashing and identifying unique/duplicate files locally...")
        for root, _, files in os.walk(takeout_source_local):
            for filename in files:
                local_file_path = os.path.join(root, filename)
                relative_path_in_takeout = os.path.relpath(local_file_path, takeout_source_local)
                original_path_in_archive = os.path.relpath(local_file_path, source_local_path)

                # Skip files that have already been organized by organize_photos
                cursor.execute("SELECT final_path FROM files WHERE original_path = ? AND source_archive = ?", (original_path_in_archive, source_archive_name))
                db_record = cursor.fetchone()
                if db_record and db_record[0] is not None:
                    # File was already handled by photo organization
                    # print(f"    > Skipping '{original_path_in_archive}': already processed.")
                    # Clean up local file if already processed
                    if os.path.exists(local_file_path):
                        try: os.remove(local_file_path)
                        except Exception as remove_e: print(f"    ⚠️ Failed to remove already processed local file '{local_file_path}': {remove_e}")
                    continue

                try:
                    with open(local_file_path, 'rb') as f:
                        sha256 = hashlib.sha256(f.read()).hexdigest()

                    # Check if hash exists in the database (means it's already in primary storage)
                    cursor.execute("SELECT 1 FROM files WHERE sha256_hash = ?", (sha256,))
                    if cursor.fetchone() is not None:
                        # It's a duplicate
                        # Move the local file to a temporary dupes directory
                        temp_dupe_path = os.path.join(temp_dupes_dir, relative_path_in_takeout)
                        os.makedirs(os.path.dirname(temp_dupe_path), exist_ok=True)
                        shutil.move(local_file_path, temp_dupe_path)
                        files_identified_as_dupes.append({'local_path': temp_dupe_path, 'original_path_in_archive': original_path_in_archive, 'hash': sha256})
                        # Update DB to point to the trash/duplicates location
                        # Need to determine the final path on Drive for the duplicate (in the dupes folder)
                        # For now, we'll use the conceptual relative path within the Drive trash folder
                        final_dupe_path_on_drive_conceptual = os.path.join("04-trash/duplicates", relative_path_in_takeout) # This is a conceptual path for DB reference
                        cursor.execute("UPDATE files SET sha256_hash = ?, final_path = ? WHERE original_path = ? AND source_archive = ?",
                                       (sha256, final_dupe_path_on_drive_conceptual, original_path_in_archive, source_archive_name))
                        conn.commit() # Commit immediately
                    else:
                        # It's a unique file
                        # Move the local file to a temporary unique directory
                        temp_unique_path = os.path.join(temp_unique_dir, relative_path_in_takeout)
                        os.makedirs(os.path.dirname(temp_unique_path), exist_ok=True)
                        shutil.move(local_file_path, temp_unique_path)
                        files_identified_as_unique.append({'local_path': temp_unique_path, 'original_path_in_archive': original_path_in_archive, 'hash': sha256})
                        # Insert or update DB with the hash, final_path is NULL initially
                        cursor.execute("INSERT OR IGNORE INTO files (sha256_hash, original_path, file_size, source_archive) VALUES (?, ?, ?, ?)",
                                       (sha256, original_path_in_archive, os.path.getsize(temp_unique_path), source_archive_name))
                        cursor.execute("UPDATE files SET sha256_hash = ? WHERE original_path = ? AND source_archive = ?",
                                       (sha256, original_path_in_archive, source_archive_name))
                        conn.commit() # Commit immediately

                except Exception as hash_e:
                    print(f"    ⚠️ Failed to hash or process '{local_file_path}': {hash_e}")
                    # Decide how to handle files that fail hashing - for now, skip them.
                    # Clean up local file that failed processing
                    if os.path.exists(local_file_path):
                        try: os.remove(local_file_path)
                        except Exception as remove_e: print(f"    ⚠️ Failed to remove local file '{local_file_path}' after hashing error: {remove_e}")
                    continue

        print(f"    > Identified {len(files_identified_as_unique)} unique files and {len(files_identified_as_dupes)} duplicates.")

        # Upload unique files to primary storage on Google Drive
        print("    > Uploading unique files to primary storage on Google Drive...")
        files_uploaded_unique = 0
        for file_info in tqdm_module(files_identified_as_unique, desc="Uploading unique files"):
            local_file_path = file_info['local_path']
            relative_path_in_takeout = os.path.relpath(local_file_path, temp_unique_dir)
            original_path_in_archive = file_info['original_path_in_archive']

            # Determine target folder on Drive - needs to map the relative path within "Takeout"
            # This requires creating nested folders on Drive if they don't exist
            target_folder_id = primary_storage_folder_id # Start with the base organized folder
            current_parent_id = primary_storage_folder_id
            path_parts = relative_path_in_takeout.split(os.sep)
            # The last part is the filename, process the directory parts
            for part in path_parts[:-1]:
                 current_parent_id = find_or_create_folder(drive, current_parent_id, part)
            target_folder_id = current_parent_id

            try:
                uploaded_file_id = upload_drive_file(drive, local_file_path, target_folder_id, os.path.basename(local_file_path))
                # Update DB with the Google Drive File ID as the final_path
                cursor.execute("UPDATE files SET final_path = ? WHERE original_path = ? AND source_archive = ?",
                               (uploaded_file_id, original_path_in_archive, source_archive_name))
                conn.commit() # Commit immediately after each upload
                files_uploaded_unique += 1
                # Delete the local temporary file after successful upload
                os.remove(local_file_path)
            except Exception as upload_e:
                 print(f"    ❌ Failed to upload unique file '{local_file_path}': {upload_e}")
                 # Log the error but continue

        # Upload duplicate files to trash/duplicates on Google Drive
        # We don't necessarily need to upload the *content* of duplicates if they are exact copies
        # and we already have the original. We just need to record that this original_path was a dupe
        # and where the duplicate *would* have gone.
        # The current DB update logic already sets final_path to a conceptual location.
        # If we wanted to keep the duplicate files themselves (e.g., for verification or just in trash),
        # we would upload them here. For now, the script discards the local dupe files after identifying them.
        print("    > Discarding local duplicate files...")
        for file_info in files_identified_as_dupes:
            local_file_path = file_info['local_path']
            if os.path.exists(local_file_path):
                 try:
                    os.remove(local_file_path)
                 except Exception as remove_e:
                    print(f"    ⚠️ Failed to remove local duplicate file '{local_file_path}': {remove_e}")


        print(f"    ✅ Deduplication and file handling complete. Uploaded {files_uploaded_unique} unique files.")

    except Exception as e:
        print(f"
❌ ERROR during deduplication: {e}")
        traceback.print_exc()
    finally:
        # Clean up local temporary directories
        if os.path.exists(temp_unique_dir): shutil.rmtree(temp_unique_dir, ignore_errors=True)
        if os.path.exists(temp_dupes_dir): shutil.rmtree(temp_dupes_dir, ignore_errors=True)
        print("    > Cleaned up local temporary deduplication directories.")


def organize_photos(drive, source_local_path, final_drive_folder_id, conn, tqdm_module, source_archive_name):
    """
    Organizes photos (in a local temporary directory) based on their metadata,
    moves them to the final Google Drive location using PyDrive2, and updates the database.
    """
    print("
--> [Step 2c] Organizing photos...")
    photos_organized_count = 0
    photos_source_local_path = os.path.join(source_local_path, "Takeout", "Google Photos")
    if not os.path.isdir(photos_source_local_path):
        print("    > Local 'Google Photos' directory not found in temp extract. Skipping.")
        return

    cursor = conn.cursor()

    # Get existing filenames in the target Google Drive folder for conflict resolution
    # This might be slow for large folders. Consider optimizing if performance is an issue.
    print("    > Listing existing files in target Google Drive folder for conflict check...")
    existing_drive_files = list_drive_files(drive, final_drive_folder_id)
    existing_filenames = {f['title'] for f in existing_drive_files}
    print(f"    > Loaded {len(existing_filenames)} existing filenames from Drive.")

    all_json_files = [os.path.join(r, f) for r, _, files in os.walk(photos_source_local_path) for f in files if f.lower().endswith('.json')]

    files_to_upload = []

    # First pass: Identify and prepare files based on JSON metadata
    print("    > Identifying and preparing photos based on JSON metadata...")
    for json_path_local in tqdm_module(all_json_files, desc="Identifying photos"):
        media_path_local = os.path.splitext(json_path_local)[0]
        # Handle potential companion files like .jpg.json, .mp4.json
        # Check if the base path exists as a file (image or video)
        if not os.path.exists(media_path_local):
            # Check for common extensions if base name doesn't exist directly
            found_media = False
            for ext in ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.mp4', '.mov', '.avi']:
                 if os.path.exists(media_path_local + ext):
                     media_path_local = media_path_local + ext
                     found_media = True
                     break
            if not found_media:
                 continue # Skip if no corresponding media file is found

        original_path_in_archive = os.path.relpath(media_path_local, source_local_path)

        # Check if this file has already been processed
        cursor.execute("SELECT final_path FROM files WHERE original_path = ? AND source_archive = ?", (original_path_in_archive, source_archive_name))
        db_record = cursor.fetchone()
        if db_record and db_record[0] is not None:
            # File was already handled
            # print(f"    > Skipping '{original_path_in_archive}': already processed.")
            # Clean up the local file if it was already processed in a previous run
            if os.path.exists(media_path_local):
                try: os.remove(media_path_local)
                except Exception as remove_e: print(f"    ⚠️ Failed to remove already processed local file '{media_path_local}': {remove_e}")
            if os.path.exists(json_path_local):
                try: os.remove(json_path_local)
                except Exception as remove_e: print(f"    ⚠️ Failed to remove companion JSON '{json_path_local}': {remove_e}")
            continue


        try:
            with open(json_path_local, 'r', encoding='utf-8') as f:
                data = json.load(f)
            ts = data.get('photoTakenTime', {}).get('timestamp')
            if not ts:
                # If no timestamp, maybe use file modification time? Or skip?
                # For now, skip files without a timestamp in JSON
                # print(f"    > Skipping '{media_path_local}': No timestamp found in JSON.")
                continue

            dt = datetime.fromtimestamp(int(ts))
            new_name_base = dt.strftime('%Y-%m-%d_%Hh%Mm%Ss')
            ext = os.path.splitext(media_path_local)[1].lower()
            proposed_filename = f"{new_name_base}{ext}"

            # Handle filename conflicts on Google Drive
            final_filename = proposed_filename
            counter = 0
            while final_filename in existing_filenames:
                counter += 1
                final_filename = f"{new_name_base}_{counter}{ext}"

            files_to_upload.append({
                'local_path': media_path_local,
                'json_path_local': json_path_local,
                'original_path_in_archive': original_path_in_archive,
                'timestamp': int(ts),
                'final_filename': final_filename
            })

        except Exception as json_e:
            print(f"    ⚠️ Failed to process JSON for '{media_path_local}': {json_e}")
            # Decide how to handle files with bad JSON - for now, skip them.
            # Clean up local files that failed processing
            if os.path.exists(media_path_local):
                try: os.remove(media_path_local)
                except Exception as remove_e: print(f"    ⚠️ Failed to remove local photo file '{media_path_local}': {remove_e}")
            if os.path.exists(json_path_local):
                try: os.remove(json_path_local)
                except Exception as remove_e: print(f"    ⚠️ Failed to remove companion JSON '{json_path_local}': {remove_e}")

            continue

    # Second pass: Upload prepared files to Google Drive and update DB
    print(f"    > Uploading {len(files_to_upload)} photos to Google Drive...")
    for file_info in tqdm_module(files_to_upload, desc="Uploading photos"):
        local_file_path = file_info['local_path']
        json_path_local = file_info['json_path_local']
        original_path_in_archive = file_info['original_path_in_archive']
        timestamp = file_info['timestamp']
        final_filename = file_info['final_filename']

        try:
            # Upload the media file
            uploaded_file_id = upload_drive_file(drive, local_file_path, final_drive_folder_id, final_filename)

            # Update the database with the Google Drive File ID and timestamp
            cursor.execute("UPDATE files SET final_path = ?, timestamp = ?, sha256_hash = ? WHERE original_path = ? AND source_archive = ?",
                           (uploaded_file_id, timestamp, '', original_path_in_archive, source_archive_name)) # SHA256 is not critical for photos after organizing
            conn.commit() # Commit immediately after each photo upload

            photos_organized_count += 1

            # Clean up the local media file and its companion JSON
            try: os.remove(local_file_path)
            except Exception as remove_e: print(f"    ⚠️ Failed to remove local photo file '{local_file_path}': {remove_e}")
            if os.path.exists(json_path_local):
                try: os.remove(json_path_local)
                except Exception as remove_e: print(f"    ⚠️ Failed to remove companion JSON '{json_path_local}': {remove_e}")

        except Exception as upload_e:
            print(f"    ❌ Failed to upload photo '{local_file_path}': {upload_e}")
            # Log the error but continue with other files
            continue


    print(f"    ✅ Organized and updated DB for {photos_organized_count} new photos.")

# ==============================================================================
# --- MAIN EXECUTION SCRIPT ---
# ==============================================================================
def main(args):
    conn = None
    drive = None # Initialize drive object
    try:
        print("--> [Step 0] Initializing environment...")
        # Authenticate and set up Drive folders
        drive = authenticate_drive()
        setup_drive_folders(drive)

        # Use dummy tqdm if not installed
        tqdm_module = tqdm

        # Create local installation directory if it doesn't exist (should be handled by bash script, but for safety)
        os.makedirs(INSTALL_DIR, exist_ok=True)
        conn = initialize_database(DB_PATH)
        perform_startup_integrity_check(drive) # Pass drive object

        # Check disk usage using shutil.disk_usage on the temporary partition
        total_vm, used_vm, free_vm = shutil.disk_usage('/tmp')
        used_vm_gb = used_vm / (1024**3)
        if used_vm_gb > TARGET_MAX_VM_USAGE_GB:
            print(f"
❌ PRE-FLIGHT CHECK FAILED: Initial /tmp disk usage ({used_vm_gb:.2f} GB) is too high.")
            print("    >>> PLEASE FREE UP SPACE ON THE /tmp PARTITION AND TRY AGAIN. <<<")
            return
        print(f"✅ Pre-flight disk check passed. (Initial /tmp Usage: {used_vm_gb:.2f} GB)")

        # jdupes installation is assumed to be handled by the bash script

        print("✅ Workspace ready.")

        print("
--> [Step 1] Identifying unprocessed archives...")
        # List archives in the source folder on Google Drive
        source_archives_files = list_drive_files(drive, CONFIG["SOURCE_ARCHIVES_DIR_ID"])
        all_archives = {f['title']: f for f in source_archives_files} # Map name to file object

        # List completed archives in the completed folder on Google Drive
        completed_archives_files = list_drive_files(drive, CONFIG["COMPLETED_ARCHIVES_DIR_ID"])
        completed_archives_names = {f['title'] for f in completed_archives_files}

        # Determine which archives need processing
        processing_queue_names = sorted(list(all_archives.keys() - completed_archives_names))

        if not processing_queue_names:
            print("
✅🎉 All archives have been processed!")
        else:
            archive_name_to_process = processing_queue_names[0]
            archive_file_obj = all_archives[archive_name_to_process] # Get the PyDrive2 file object

            print(f"--> Locking and staging '{archive_name_to_process}' for processing...")

            # Simulate "staging" by moving the file on Google Drive to the staging folder
            move_drive_file(drive, archive_file_obj['id'], CONFIG["PROCESSING_STAGING_DIR_ID"])
            # Update the archive_file_obj to reflect its new location
            archive_file_obj['parents'] = [{'id': CONFIG["PROCESSING_STAGING_DIR_ID"]}]


            # Get the file size from the PyDrive2 file object
            staging_file_size_bytes = int(archive_file_obj.get('fileSize', 0) or 0)
            staging_file_size_gb = staging_file_size_bytes / (1024**3)

            # Check if repackaging is needed
            if staging_file_size_gb > MAX_SAFE_ARCHIVE_SIZE_GB and '.part-' not in archive_name_to_process:
                repackaging_ok = plan_and_repackage_archive(drive, archive_file_obj, CONFIG["SOURCE_ARCHIVES_DIR_ID"], conn, tqdm_module)
                if repackaging_ok:
                    # If repackaging was successful, move the *original large archive* to completed
                    move_drive_file(drive, archive_file_obj['id'], CONFIG["COMPLETED_ARCHIVES_DIR_ID"])
            else:
                # Process as a regular archive
                processed_ok = process_regular_archive(drive, archive_file_obj, conn, tqdm_module)
                if processed_ok:
                    # If processing was successful, move the archive to completed
                    move_drive_file(drive, archive_file_obj['id'], CONFIG["COMPLETED_ARCHIVES_DIR_ID"])
                else:
                    print(f"    ❌ Transaction failed for '{archive_name_to_process}'. It will be rolled back on the next run by the integrity check.")
                    # The integrity check will move the failed archive back to SOURCE_ARCHIVES_DIR_ID

            print("
--- WORKFLOW CYCLE COMPLETE. ---")
    except Exception as e:
        print(f"
❌ A CRITICAL UNHANDLED ERROR OCCURRED: {e}")
        traceback.print_exc()
    finally:
        if conn:
            conn.close()
            print("--> [DB] Database connection closed.")
        # Clean up all temporary local directories on exit
        if os.path.exists(VM_TEMP_EXTRACT_DIR): shutil.rmtree(VM_TEMP_EXTRACT_DIR, ignore_errors=True)
        if os.path.exists(VM_TEMP_BATCH_DIR): shutil.rmtree(VM_TEMP_BATCH_DIR, ignore_errors=True)
        if os.path.exists(VM_TEMP_DOWNLOAD_DIR): shutil.rmtree(VM_TEMP_DOWNLOAD_DIR, ignore_errors=True)
        # Also clean up jdupes temp directories
        if os.path.exists('/tmp/jdupes_unique'): shutil.rmtree('/tmp/jdupes_unique', ignore_errors=True)
        if os.path.exists('/tmp/jdupes_dupes'): shutil.rmtree('/tmp/jdupes_dupes', ignore_errors=True)

        print("--> Cleaned up all temporary local directories.")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Process Google Takeout archives.")
    parser.add_argument('--auto-delete-artifacts', action='store_true', help="Enable automatic deletion of 0-byte artifact files.")
    # Parse only known arguments, ignoring others from the notebook environment
    args, unknown = parser.parse_known_args()
    main(args)

EOF

    chmod +x "${PROCESSOR_SCRIPT_PATH}"
    _log_ok "Python script deployed and made executable."

    _log_info "Creating systemd service file..."
    cat <<EOF > "${PROCESSOR_SERVICE_PATH}"
[Unit]
Description=Google Takeout Organizer
After=network.target remote-fs.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 ${PROCESSOR_SCRIPT_PATH}
WorkingDirectory=${INSTALL_DIR}
User=root # Or a less privileged user if appropriate permissions are set
Group=root # Or a less privileged group
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    _log_ok "Systemd service file created: ${PROCESSOR_SERVICE_PATH}"

    _log_info "Reloading systemd and enabling the service..."
    systemctl daemon-reload
    systemctl enable ${PROCESSOR_SERVICE_NAME}
    _log_ok "Systemd reloaded and service enabled."

    _log_info "Starting the Takeout Organizer service..."
    systemctl start ${PROCESSOR_SERVICE_NAME}
    _log_ok "Service started. Use 'journalctl -u ${PROCESSOR_SERVICE_NAME}' to check logs."

    _log_info "--- Takeout Processor Appliance Setup Complete ---"
}

main "$@"
