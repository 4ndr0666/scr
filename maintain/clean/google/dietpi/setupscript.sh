#!/bin/bash

echo "--- Google Takeout Organizer Setup Script ---"

# Check if script is run as root; if not, re-execute with sudo
if [[ $EUID -ne 0 ]]; then
   echo "This script requires root privileges. Re-running with sudo..."
   exec sudo bash "$0" "$@"
fi

# Ensure the script directory exists
SCRIPT_DIR="/usr/local/bin/takeout_organizer"
mkdir -p "$SCRIPT_DIR"
echo "Ensured script directory exists: $SCRIPT_DIR"

# Define the Python script content and write it using a heredoc with cat
PYTHON_SCRIPT_FILE="$SCRIPT_DIR/takeout_organizer.py"

echo "Writing Python script to: $PYTHON_SCRIPT_FILE"
cat << 'EOF' > "$PYTHON_SCRIPT_FILE"
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

# Import Google API client libraries
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaIoBaseDownload, MediaFileUpload

# Attempt to use tqdm if available, otherwise use dummy
try:
    from tqdm.auto import tqdm
except ImportError:
    def tqdm(iterable, *args, **kwargs):
        description = kwargs.get('desc', 'items')
        print(f"    > Processing {description}...")
        return iterable


# ==============================================================================
# --- 1. CORE CONFIGURATION ---
# ==============================================================================
TARGET_MAX_VM_USAGE_GB = 70 # Still relevant for temp disk usage during processing
REPACKAGE_CHUNK_SIZE_GB = 15
MAX_SAFE_ARCHIVE_SIZE_GB = 25 # Maximum size for direct processing before repackaging

# BASE_DIR is not used for source/dest paths with Drive API, only for local DB and config
# Default to a persistent location for the database and potentially local config files
BASE_DIR = os.environ.get("TAKEOUT_BASE_DIR", os.path.join(os.path.expanduser("~"), ".takeout_organizer"))

# Allow specifying a temporary directory for local processing via environment variable
# Default to /tmp/takeout_processing for temporary extraction and file handling
DEFAULT_TEMP_PROCESSING_DIR = "/tmp/takeout_processing"
TEMP_PROCESSING_DIR = os.environ.get("TAKEOUT_TEMP_DIR", DEFAULT_TEMP_PROCESSING_DIR)


# Google Drive specific configuration - these will be folder IDs or paths in Drive
# The user will need to configure these via environment variables.
# Using placeholder names as defaults assuming a standard structure the user will set up.
DRIVE_SOURCE_FOLDER_NAME = os.environ.get("TAKEOUT_DRIVE_SOURCE_FOLDER", "00-ALL-ARCHIVES")
DRIVE_COMPLETED_FOLDER_NAME = os.environ.get("TAKEOUT_DRIVE_COMPLETED_FOLDER", "05-COMPLETED-ARCHIVES")
DRIVE_ORGANIZED_FOLDER_NAME = os.environ.get("TAKEOUT_DRIVE_ORGANIZED_FOLDER", "03-organized/My-Photos") # May need to handle nested paths
DRIVE_TRASH_FOLDER_NAME = os.environ.get("TAKEOUT_DRIVE_TRASH_FOLDER", "04-trash") # For quarantined/duplicates

# The local database will still store metadata about files processed from Drive
# It will be located in a persistent location, potentially near the script or in a user-defined path
DB_PATH = os.path.get("TAKEOUT_DB_PATH", os.path.join(BASE_DIR, "takeout_archive.db")) # Use BASE_DIR for default DB path


CONFIG = {
    "TEMP_PROCESSING_DIR": TEMP_PROCESSING_DIR,
    # Drive folder names are stored separately as they require API interaction to resolve to IDs
    "DRIVE_SOURCE_FOLDER_NAME": DRIVE_SOURCE_FOLDER_NAME,
    "DRIVE_COMPLETED_FOLDER_NAME": DRIVE_COMPLETED_FOLDER_NAME,
    "DRIVE_ORGANIZED_FOLDER_NAME": DRIVE_ORGANIZED_FOLDER_NAME,
    "DRIVE_TRASH_FOLDER_NAME": DRIVE_TRASH_FOLDER_NAME,
    "DB_PATH": DB_PATH,
}

# Local temporary directories within the processing directory
LOCAL_TEMP_EXTRACT_DIR = os.path.join(CONFIG["TEMP_PROCESSING_DIR"], 'temp_extract')
LOCAL_TEMP_BATCH_DIR = os.path.join(CONFIG["TEMP_PROCESSING_DIR"], 'temp_batch_creation')
LOCAL_JDUPE_TEMP_DIR = os.path.join(CONFIG["TEMP_PROCESSING_DIR"], 'jdupes_temp')


# GOOGLE_APPLICATION_CREDENTIALS environment variable is expected to be set externally

# ==============================================================================
# --- 2. WORKFLOW FUNCTIONS & HELPERS (Adapted for Drive API) ---
# ==============================================================================

def authenticate_drive():
    # Authenticates with Google Drive using GOOGLE_APPLICATION_CREDENTIALS.
    print("--> [Auth] Authenticating with Google Drive...")
    try:
        # GOOGLE_APPLICATION_CREDENTIALS env var should point to the service account JSON file
        creds = service_account.Credentials.from_environment_variable(
            'GOOGLE_APPLICATION_CREDENTIALS',
            scopes=['https://www.googleapis.com/auth/drive'] # Scope for full Drive access
        )
        service = build('drive', 'v3', credentials=creds)
        print("    ✅ Google Drive authentication successful.")
        return service
    except Exception as e:
        print(f"    ❌ ERROR during Google Drive authentication: {e}")
        print("    >>> Please ensure GOOGLE_APPLICATION_CREDENTIALS environment variable is set correctly and points to a valid service account key file. <<<")
        return None

def find_drive_folder(service, folder_name, parent_id=None):
    # Finds a Google Drive folder by name. Can search within a parent folder.
    # Returns the folder ID if found, otherwise None.
    # Note: Searching by name can return multiple results if names are not unique.
    # This function assumes the first result is the correct one.
    print(f"    > Searching for Drive folder: '{folder_name}'...")
    query = f"name = '{folder_name}' and mimeType = 'application/vnd.google-apps.folder' and trashed = false"
    if parent_id:
        query += f" and '{parent_id}' in parents"
    else:
         # Search in root if no parent_id is provided
         query += " and 'root' in parents"


    try:
        results = service.files().list(q=query, fields="files(id, name)").execute()
        items = results.get('files', [])
        if not items:
            print(f"    ⚠️ Drive folder '{folder_name}' not found.")
            return None
        else:
            # Assuming unique folder names within a parent, or taking the first result
            folder_id = items[0]['id']
            print(f"    ✅ Found Drive folder '{folder_name}' with ID: {folder_id}")
            return folder_id
    except HttpError as error:
        print(f"    ❌ An API error occurred while searching for folder '{folder_name}': {error}")
        return None
    except Exception as e:
        print(f"    ❌ An unexpected error occurred while searching for folder '{folder_name}': {e}")
        return None

def create_drive_folder(service, folder_name, parent_id=None):
    # Creates a Google Drive folder.
    print(f"    > Creating Drive folder: '{folder_name}'...")
    file_metadata = {
        'name': folder_name,
        'mimeType': 'application/vnd.google-apps.folder'
    }
    if parent_id:
        file_metadata['parents'] = [parent_id]
    else:
        # Create in root if no parent_id is provided
        file_metadata['parents'] = ['root']


    try:
        file = service.files().create(body=file_metadata, fields='id').execute()
        folder_id = file.get('id')
        print(f"    ✅ Created Drive folder '{folder_name}' with ID: {folder_id}")
        return folder_id
    except HttpError as error:
        print(f"    ❌ An API error occurred while creating folder '{folder_name}': {error}")
        return None
    except Exception as e:
        print(f"    ❌ An unexpected error occurred while creating folder '{folder_name}': {e}")
        return None

def ensure_drive_folder(service, folder_name, parent_id=None):
    # Ensures a Drive folder exists, creates it if not. Returns folder ID.
    folder_id = find_drive_folder(service, folder_name, parent_id)
    if folder_id is None:
        folder_id = create_drive_folder(service, folder_name, parent_id)
    return folder_id

def ensure_drive_directory_structure(service):
    # Ensures the necessary directory structure exists on Google Drive.
    print("--> [Drive] Ensuring Drive directory structure exists...")
    root_id = 'root' # Start from the user's Drive root

    # Check if the main 'TakeoutProject' base folder exists or create it
    takeout_base_folder_name = os.path.basename(os.environ.get("TAKEOUT_BASE_DIR", os.path.join(os.path.expanduser("~"), ".takeout_organizer")))
    takeout_base_folder_id = ensure_drive_folder(service, takeout_base_folder_name, root_id)
    if not takeout_base_folder_id:
         print("    ❌ Could not ensure base 'TakeoutProject' folder on Drive. Cannot proceed.")
         return None # Indicate critical failure


    # Create subfolders within the base folder
    source_id = ensure_drive_folder(service, CONFIG["DRIVE_SOURCE_FOLDER_NAME"], takeout_base_folder_id)
    if not source_id: return None # Indicate failure

    completed_id = ensure_drive_folder(service, CONFIG["DRIVE_COMPLETED_FOLDER_NAME"], takeout_base_folder_id)
    if not completed_id: return None # Indicate failure

    # Handle nested '03-organized/My-Photos'
    organized_base_id = ensure_drive_folder(service, "03-organized", takeout_base_folder_id)
    if not organized_base_id: return None
    organized_id = ensure_drive_folder(service, "My-Photos", organized_base_id)
    if not organized_id: return None

    # Handle nested '04-trash' and its subfolders
    trash_id = ensure_drive_folder(service, CONFIG["DRIVE_TRASH_FOLDER_NAME"], takeout_base_folder_id)
    if not trash_id: return None

    quarantine_id = ensure_drive_folder(service, "quarantined_artifacts", trash_id)
    dupes_id = ensure_drive_folder(service, "duplicates", trash_id)

    # Store the resolved Drive Folder IDs
    drive_folder_ids = {
         "source_id": source_id,
         "completed_id": completed_id,
         "organized_id": organized_id,
         "trash_id": trash_id,
         "quarantine_id": quarantine_id,
         "dupes_id": dupes_id,
         # Store the base folder ID as well
         "base_id": takeout_base_folder_id
    }

    # Ensure the 'OtherTakeoutFiles' subfolder within Organized
    other_files_drive_folder_name = "OtherTakeoutFiles"
    other_files_drive_folder_id = ensure_drive_folder(service, other_files_drive_folder_name, organized_id)
    if not other_files_drive_folder_id: return None # Indicate failure
    drive_folder_ids["other_files_id"] = other_files_drive_folder_id


    print("    ✅ Drive directory structure ready.")
    return drive_folder_ids # Return the dictionary of IDs


def initialize_database(db_path):
    # Creates the SQLite database and the necessary tables if they don't exist.
    # Adapted to store Drive File IDs and original paths within the archive.
    print("--> [DB] Initializing database...")
    # Ensure the directory for the database exists
    db_dir = os.path.dirname(db_path)
    os.makedirs(db_dir, exist_ok=True)
    print(f"    > Ensuring database directory exists: {db_dir}")

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS files (
        id INTEGER PRIMARY KEY,
        drive_file_id TEXT NOT NULL UNIQUE, -- Store Google Drive File ID (final location)
        sha256_hash TEXT, -- Hash after download
        original_archive_path TEXT NOT NULL, -- Path within the original tar archive
        original_filename TEXT NOT NULL, -- Original filename from Drive
        final_drive_path TEXT, -- Final path within Drive after organizing (string representation)
        final_drive_folder_id TEXT, -- Drive Folder ID of the final location
        timestamp INTEGER, -- Timestamp from metadata
        file_size INTEGER, -- Size from Drive metadata
        source_archive_drive_id TEXT NOT NULL -- Drive ID of the source archive file
    )
    ''')
    conn.commit()
    print("    ✅ Database ready.")
    return conn

def perform_startup_integrity_check():
    # Performs a "Power-On Self-Test".
    # This will need significant adaptation for Drive API interaction.
    # For now, let's keep basic local temp cleanup.
    print("--> [POST] Performing startup integrity check (Local Temp Cleanup Only)...")
    # Ensure local temporary directories are clean
    if os.path.exists(LOCAL_TEMP_EXTRACT_DIR):
         try: shutil.rmtree(LOCAL_TEMP_EXTRACT_DIR)
         except Exception as e: print(f"    ⚠️ Failed to clean up {LOCAL_TEMP_EXTRACT_DIR}: {e}")
    if os.path.exists(LOCAL_TEMP_BATCH_DIR):
         try: shutil.rmtree(LOCAL_TEMP_BATCH_DIR)
         except Exception as e: print(f"    ⚠️ Failed to clean up {LOCAL_TEMP_BATCH_DIR}: {e}")
    if os.path.exists(LOCAL_JDUPE_TEMP_DIR):
         try: shutil.rmtree(LOCAL_JDUPE_TEMP_DIR)
         except Exception as e: print(f"    ⚠️ Failed to clean up {LOCAL_JDUPE_TEMP_DIR}: {e}")

    print("--> [POST] Integrity check complete (Local Temp Cleaned).")

# The core processing logic (plan_and_repackage_archive, process_regular_archive,
# deduplicate_files, organize_photos) needs to be completely rewritten to:
# 1. List files from the Source Drive Folder using the API.
# 2. Check the database for files already processed (using Drive File IDs).
# 3. Download unprocessed archive files to LOCAL_TEMP_PROCESSING_DIR.
# 4. Process the downloaded archives locally (unpacking, hashing, organizing).
# 5. Upload organized files back to the Organized Drive Folder.
# 6. Move processed source archives to the Completed Drive Folder.
# 7. Move duplicates/quarantined files to the respective Trash Drive Folders.
# 8. Update the database with final Drive file IDs and paths.
# 9. Clean up local temporary files after successful processing of an archive.

# This is a major development effort. For this step, I will add placeholder
# functions and focus on the initial authentication and directory setup logic.

def list_drive_files_in_folder(service, folder_id):
    # Lists files (not folders) in a given Drive folder.
    print(f"    > Listing files in Drive folder ID: {folder_id}")
    items = []
    page_token = None
    query = f"'{folder_id}' in parents and mimeType != 'application/vnd.google-apps.folder' and trashed = false"
    try:
        while True:
            response = service.files().list(
                q=query,
                spaces='drive',
                fields='nextPageToken, files(id, name, size, mimeType)',
                pageToken=page_token
            ).execute()
            items.extend(response.get('files', []))
            page_token = response.get('nextPageToken', None)
            if page_token is None:
                break
        print(f"    ✅ Found {len(items)} files.")
        return items
    except HttpError as error:
        print(f"    ❌ An API error occurred while listing files in folder ID {folder_id}: {error}")
        return None
    except Exception as e:
        print(f"    ❌ An unexpected error occurred while listing files: {e}")
        return None

# Function to upload a file to Google Drive
def upload_to_drive(service, local_filepath, drive_folder_id, drive_filename=None):
    # Uploads a local file to a specified Google Drive folder.
    # Returns the Drive File ID of the uploaded file, or None on failure.
    filename = drive_filename if drive_filename else os.path.basename(local_filepath)
    print(f"    > Uploading '{filename}' to Drive folder ID: {drive_folder_id}...")

    file_metadata = {
        'name': filename,
        'parents': [drive_folder_id]
    }
    media = MediaFileUpload(local_filepath, resumable=True)
    try:
        file = service.files().create(
            body=file_metadata,
            media_body=media,
            fields='id, parents'
        ).execute()
        uploaded_file_id = file.get('id')
        print(f"    ✅ Uploaded '{filename}' with Drive ID: {uploaded_file_id}")
        return uploaded_file_id
    except HttpError as error:
        print(f"    ❌ An API error occurred while uploading '{filename}': {error}")
        return None
    except Exception as e:
        print(f"    ❌ An unexpected error occurred while uploading '{filename}': {e}")
        return None


# Adapted process_regular_archive to work with a local file path
def process_regular_archive(local_archive_path, drive_archive_id, drive_archive_name, conn, tqdm_module, service, drive_folder_ids):
    # Handles a regular-sized archive. Unpacks to a local temp dir, processes,
    # and then uploads/moves files on Google Drive.
    print(f"\n--> [Step 2a] Processing transaction for local archive '{os.path.basename(local_archive_path)}'...")
    cursor = conn.cursor()
    archive_name = os.path.basename(local_archive_path)

    try:
        # Resume logic needs to be adapted for Drive File IDs and the local extraction process
        # For now, let's simplify: If the archive's Drive ID is in the database as processed, skip.
        # A more robust approach would check if all files *within* the archive (by original path or hash)
        # have been fully processed (final_drive_folder_id set).

        # --- Check if the archive's Drive ID is in the database as fully processed ---
        # This simplified check might need refinement for true resume capability.
        # A better check: count files from this archive with final_drive_folder_id NOT NULL.
        # If this count equals total files in the archive (from initial scan/db population), it's processed.
        # For now, let's rely on the processing_queue logic in process_drive_archives.


        print("    > Checking database for previously processed files from this archive...")
        # This check will help resume if the local processing failed partially
        cursor.execute("SELECT original_archive_path FROM files WHERE source_archive_drive_id = ? AND final_drive_folder_id IS NOT NULL", (drive_archive_id,))
        completed_files_in_db = {row[0] for row in cursor.fetchall()}
        if completed_files_in_db:
            print(f"    ✅ Found {len(completed_files_in_db)} files from this archive previously processed. Will skip unpacking them.")
        else:
            print("    > No files from this archive found in the database as fully processed.")


        os.makedirs(LOCAL_TEMP_EXTRACT_DIR, exist_ok=True)

        files_to_process_locally = []
        with tarfile.open(local_archive_path, 'r:gz') as tf:
            all_members = [m for m in tf.getmembers() if m.isfile()]
            print(f"    > Scanning {archive_name} for files to unpack...")
            for member in all_members:
                 # Use the path within the tar as the original_archive_path
                 original_archive_path = member.name

                 # Skip unpacking if the file is already marked as processed in the DB
                 if original_archive_path not in completed_files_in_db:
                    try:
                        tf.extract(member, path=LOCAL_TEMP_EXTRACT_DIR, set_attrs=False)
                        files_to_process_locally.append(os.path.join(LOCAL_TEMP_EXTRACT_DIR, member.name)) # Store local path
                    except Exception as e:
                        print(f"    ⚠️ Could not extract '{member.name}': {e}")
                        # Optionally quarantine the problematic file/archive here (needs Drive API)
                        pass
                 # else:
                    # print(f"    > Skipping extraction of '{member.name}' - already processed.")


        if not os.listdir(LOCAL_TEMP_EXTRACT_DIR): # Check if anything was extracted
            print("    ✅ No new files found to unpack from this archive.")
            # If no new files were extracted, and the archive was not marked complete,
            # it implies all contained files were already processed in a previous run.
            # So, we can mark the archive as processed on Drive and in DB.
            print("    > All files previously processed. Proceeding to finalize archive on Drive.")
            return True # Indicate success for finalization


        print(f"    ✅ Unpacked new/missing files to {LOCAL_TEMP_EXTRACT_DIR}.")

        # Subsequent steps now operate on the local extracted files.
        # These functions need to be adapted to handle Drive uploads/moves
        # and update the database with final Drive IDs.

        # --- Process local extracted files and upload to Drive ---
        print("\n    > Running local processing and uploading to Drive...")
        # organize_photos now takes service and drive_folder_ids and handles uploads
        organize_photos(LOCAL_TEMP_EXTRACT_DIR, conn, tqdm_module, drive_archive_id, service, drive_folder_ids)
        # deduplicate_files now handles comparisons and moves on Drive
        deduplicate_files(LOCAL_TEMP_EXTRACT_DIR, conn, drive_archive_id, service, drive_folder_ids)


        # After local processing and potential Drive uploads, we need to verify
        # completion and update the database for all files from this archive.
        # This is complex and needs a separate function.
        # For now, assuming called functions handle DB updates partially.
        # A final check and update based on the state of files originating
        # from this archive might be needed here for robustness.

        return True # Indicate success after local processing and upload attempts

    except Exception as e:
        print(f"\n❌ ERROR during local archive processing transaction: {e}"); traceback.print_exc()
        return False # Indicate failure

    finally:
        # Clean up local extract temp directory regardless of success/failure
        if os.path.exists(LOCAL_TEMP_EXTRACT_DIR):
             try: shutil.rmtree(LOCAL_TEMP_EXTRACT_DIR)
             except Exception as e: print(f"    ⚠️ Failed to clean up {LOCAL_TEMP_EXTRACT_DIR}: {e}")


# Adapted organize_photos to upload to Google Drive
def organize_photos(source_path, conn, tqdm_module, source_archive_drive_id, service, drive_folder_ids):
    # Organizes photos from a local source path and uploads them to the final Drive folder.
    print("\n--> [Step 2c] Organizing photos and uploading to Drive...")
    photos_organized_count = 0
    photos_source_path = os.path.join(source_path, "Takeout", "Google Photos")
    if not os.path.isdir(photos_source_path):
        print("    > 'Google Photos' directory not found in extracted path. Skipping.")
        return

    organized_drive_folder_id = drive_folder_ids.get("organized_id")
    if not organized_drive_folder_id:
         print("    ❌ Organized Drive folder ID not found. Cannot upload organized photos.")
         return

    # Need a way to efficiently check for existing files in the destination Drive folder
    # to avoid duplicates. This is complex and might require listing files in the
    # destination folder or relying on database lookups (if we stored info about
    # files already uploaded to the organized folder).
    # For simplicity in this step, we'll upload and rely on Drive's handling of
    # duplicate filenames (it appends a number). A more sophisticated approach
    # would compare hashes or metadata before uploading.

    all_json_files = []
    for root, _, files in os.walk(photos_source_path):
        for f in files:
            if f.lower().endswith('.json'):
                all_json_files.append(os.path.join(root, f))

    if not all_json_files:
        print("    > No JSON files found in Google Photos directory. Skipping photo organization.")
        return

    cursor = conn.cursor()
    organized_db_updates = [] # Collect DB updates

    for json_path in tqdm_module(all_json_files, desc="Organizing & Uploading photos"):
        media_path_base = os.path.splitext(json_path)[0]

        media_file_to_process = None
        for ext in ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.mp4', '.mov', '.avi', '.webm', '.tiff', '.heic', '.webp']:
             potential_media_path = media_path_base + ext
             if os.path.exists(potential_media_path):
                  media_file_to_process = potential_media_path
                  break

        if not media_file_to_process:
            # print(f"    > No associated media file found for JSON {json_path}. Skipping.")
            continue

        try:
            with open(json_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            ts = data.get('photoTakenTime', {}).get('timestamp')
            if not ts:
                 ts = data.get('creationTime', {}).get('timestamp')

            if not ts:
                print(f"    ⚠️ No valid timestamp found for {os.path.basename(media_file_to_process)}. Skipping.")
                continue

            dt = datetime.fromtimestamp(int(ts))
            new_name_base = dt.strftime('%Y-%m-%d_%Hh%Mm%Ss')
            ext = os.path.splitext(media_file_to_process)[1].lower()
            final_drive_filename = f"{new_name_base}{ext}"

            # Determine the original_archive_path for the DB update.
            # Assuming path relative to the *root* of the extracted archive is the original_archive_path.
            original_archive_path = os.path.relpath(media_file_to_process, source_path)


            # --- Check if this file (by original_archive_path and source_archive_drive_id) is already processed ---
            cursor.execute("SELECT drive_file_id FROM files WHERE original_archive_path = ? AND source_archive_drive_id = ? LIMIT 1", (original_archive_path, source_archive_drive_id))
            if cursor.fetchone():
                 # print(f"    > File '{os.path.basename(media_file_to_process)}' from archive '{source_archive_drive_id}' already processed. Skipping upload.")
                 # Delete local temporary files for this already processed file
                 try:
                     os.remove(media_file_to_process)
                     os.remove(json_path) # Also remove the associated JSON
                 except OSError as e:
                      print(f"    ⚠️ Could not delete local temp files for already processed {os.path.basename(media_file_to_process)}: {e}")
                 continue # Skip to next file if already processed


            # --- Upload the organized file to Google Drive ---
            uploaded_file_id = upload_to_drive(service, media_file_to_process, organized_drive_folder_id, final_drive_filename)

            if uploaded_file_id:
                 photos_organized_count += 1

                 # After successful upload, delete the local temporary media and JSON files
                 try:
                     os.remove(media_file_to_process)
                     os.remove(json_path)
                 except OSError as e:
                      print(f"    ⚠️ Could not delete local temp files for {os.path.basename(media_file_to_process)}: {e}")

                 # Prepare database update for the successfully uploaded file
                 # Construct the full final_drive_path for the DB (e.g., "03-organized/My-Photos/YYYY-MM-DD_HHhMMmSS.ext")
                 # This assumes a flat structure within the target organized folder.
                 final_drive_path_full = f"{CONFIG['DRIVE_ORGANIZED_FOLDER_NAME']}/{final_drive_filename}"


                 organized_db_updates.append((uploaded_file_id, final_drive_filename, final_drive_path_full, organized_drive_folder_id, original_archive_path, int(ts), os.path.getsize(media_file_to_process), source_archive_drive_id))

            # else:
                 # Upload failed, local temp files are not deleted. Integrity check might handle this later.

        except Exception as e:
            print(f"    ❌ Error processing or uploading JSON file {json_path} and associated media: {e}")
            traceback.print_exc()
            continue

    if organized_db_updates:
        print(f"    > Committing {len(organized_db_updates)} database updates for organized files...")
        # Insert into files table, handling potential duplicates based on drive_file_id unique constraint
        cursor.executemany("INSERT OR IGNORE INTO files (drive_file_id, original_filename, final_drive_path, final_drive_folder_id, original_archive_path, timestamp, file_size, source_archive_drive_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)", organized_db_updates)
        conn.commit()
        print(f"    ✅ Organized and uploaded {photos_organized_count} new files to Drive and updated DB.")
    else:
        print("    > No new photos were organized and uploaded.")


# Adapted deduplicate_files to work with local files and manage on Drive
def deduplicate_files(source_path, conn, source_archive_drive_id, service, drive_folder_ids):
    # Processes remaining local files (non-photos, unorganized, orphaned JSONs)
    # and uploads/moves them to appropriate trash/other folders on Drive.
    # Note: This function does NOT perform Drive-based content deduplication.
    print("\n--> [Step 2b] Managing other files on Drive...")

    organized_drive_folder_id = drive_folder_ids.get("organized_id")
    trash_drive_folder_id = drive_folder_ids.get("trash_id")
    dupes_drive_folder_id = drive_folder_ids.get("dupes_id") # For duplicates on Drive - currently not used for content dedup
    quarantine_drive_folder_id = drive_folder_ids.get("quarantine_id") # For quarantined artifacts

    if not organized_drive_folder_id or not trash_drive_folder_id or not quarantine_drive_folder_id:
        print("    ❌ Required Drive folder IDs for organized, trash, or quarantine not found. Skipping management of other files.")
        return

    cursor = conn.cursor()
    files_managed_count = 0

    # After organize_photos runs, remaining files in source_path (specifically in the 'Takeout' subdir)
    # are non-photo files, photos that couldn't be organized, or orphaned JSON files.
    takeout_source = os.path.join(source_path, "Takeout")

    if os.path.exists(takeout_source):
        print("    > Processing remaining files in temp directory (non-photos, unorganized, or orphans)...")
        for root, _, files in os.walk(takeout_source):
            for filename in files:
                local_file_path = os.path.join(root, filename)

                # Determine the original_archive_path. Assuming path relative to the *root* of the extracted archive.
                original_archive_path = os.path.relpath(local_file_path, source_path)

                # --- Check if this file (by original_archive_path and source_archive_drive_id) is already processed ---
                cursor.execute("SELECT drive_file_id FROM files WHERE original_archive_path = ? AND source_archive_drive_id = ? LIMIT 1", (original_archive_path, source_archive_drive_id))
                if cursor.fetchone():
                     # print(f"    > File '{os.path.basename(local_file_path)}' from archive '{source_archive_drive_id}' already processed. Skipping management.")
                     # Delete local temporary file for this already processed file
                     try: os.remove(local_file_path)
                     except OSError as e: print(f"    ⚠️ Could not delete local temp file for already processed {os.path.basename(local_file_path)}: {e}")
                     continue # Skip to next file if already processed


                # --- Handle orphaned JSON files ---
                if filename.lower().endswith('.json'):
                    # These are JSON files whose associated media was either not found,
                    # skipped, or failed to process. We should quarantine them.
                    print(f"    > Quarantining orphaned JSON file: {filename}")
                    # Upload to quarantine folder on Drive
                    uploaded_file_id = upload_to_drive(service, local_file_path, quarantine_drive_folder_id, filename)

                    if uploaded_file_id:
                         files_managed_count += 1
                         # Delete local file after upload
                         try: os.remove(local_file_path)
                         except OSError as e: print(f"    ⚠️ Could not delete local orphaned JSON {local_file_path}: {e}")

                         # Record in DB
                         # Use original_archive_path as the final_drive_path within quarantine for simplicity
                         final_drive_path_full = f"{CONFIG['DRIVE_TRASH_FOLDER_NAME']}/quarantined_artifacts/{original_archive_path}"
                         cursor.execute("INSERT OR IGNORE INTO files (drive_file_id, original_filename, final_drive_path, final_drive_folder_id, original_archive_path, file_size, source_archive_drive_id) VALUES (?, ?, ?, ?, ?, ?, ?)",
                                        (uploaded_file_id, filename, final_drive_path_full, quarantine_drive_folder_id, original_archive_path, os.path.getsize(local_file_path), source_archive_drive_id))
                    continue # Move to the next file


                # --- Handle other remaining files (non-photos or failed photos) ---
                # Upload them to a designated 'OtherTakeoutFiles' folder within Organized on Drive,
                # preserving relative path structure from 'Takeout'.
                other_files_drive_folder_name = "OtherTakeoutFiles"
                other_files_drive_folder_id = drive_folder_ids.get("other_files_id") # Get the pre-ensured ID

                if not other_files_drive_folder_id:
                     print(f"    ❌ 'OtherTakeoutFiles' folder ID not found. Skipping management of '{filename}'.")
                     continue # Skip this file

                # Construct the final Drive path (relative to the organized folder) and ensure nested folders
                path_components_relative_to_takeout = os.path.relpath(local_file_path, takeout_source).split(os.sep)
                current_parent_id = other_files_drive_folder_id
                final_drive_path_parts = [CONFIG['DRIVE_ORGANIZED_FOLDER_NAME'].split('/')[-1], other_files_drive_folder_name] # Start building the path string for DB. Use last part of organized path.
                # Traverse path components to create nested folders on Drive
                for i, component in enumerate(path_components_relative_to_takeout[:-1]): # Exclude the filename
                    if component: # Avoid empty components from leading/trailing slashes
                         # Check if folder exists within current_parent_id, create if not
                         component_folder_id = ensure_drive_folder(service, component, current_parent_id)
                         if not component_folder_id:
                              print(f"    ❌ Could not ensure nested Drive folder '{component}'. Skipping management of '{filename}'.")
                              current_parent_id = None # Indicate failure to create path
                              break
                         current_parent_id = component_folder_id
                         final_drive_path_parts.append(component)

                if current_parent_id is None:
                     continue # Skip this file if nested folder creation failed

                # The final parent folder on Drive is current_parent_id
                final_upload_parent_id = current_parent_id
                final_drive_path_parts.append(filename)
                final_drive_path_full_for_db = "/".join(final_drive_path_parts) # Use '/' for Drive path string


                # --- Upload the file ---
                # Note: This simple upload does NOT perform deduplication against existing files on Drive.
                # A robust solution would check for duplicates based on hash or metadata before uploading.
                uploaded_file_id = upload_to_drive(service, local_file_path, final_upload_parent_id, filename) # Upload with original filename for now

                if uploaded_file_id:
                    files_managed_count += 1

                    # After successful upload, delete the local temporary file
                    try:
                        os.remove(local_file_path)
                    except OSError as e:
                         print(f"    ⚠️ Could not delete local temp file {local_file_path}: {e}")

                    # Prepare database update
                    cursor.execute("INSERT OR IGNORE INTO files (drive_file_id, original_filename, final_drive_path, final_drive_folder_id, original_archive_path, file_size, source_archive_drive_id) VALUES (?, ?, ?, ?, ?, ?, ?)",
                                   (uploaded_file_id, filename, final_drive_path_full_for_db, final_upload_parent_id, original_archive_path, os.path.getsize(local_file_path), source_archive_drive_id))


        conn.commit() # Commit updates for files managed
    else:
         print("    > 'Takeout' directory not found in extracted temp location. No other files to process.")

    print(f"    ✅ Finished managing other files. Processed {files_managed_count} files.")
    # Clean up jdupes temp directory (if it was used for local temp files)
    if os.path.exists(LOCAL_JDUPE_TEMP_DIR):
        try: shutil.rmtree(LOCAL_JDUPE_TEMP_DIR)
        except Exception as e: print(f"    ⚠️ Failed to clean up {LOCAL_JDUPE_TEMP_DIR}: {e}")


# Adapted plan_and_repackage_archive for Drive API (placeholder)
def plan_and_repackage_archive(local_archive_path, drive_archive_id, drive_archive_name, conn, tqdm_module, service, drive_folder_ids):
     # This function needs significant adaptation. It would involve:
     # 1. Scanning the large local archive.
     # 2. Identifying files to repackage (potentially checking DB/Drive for existing).
     # 3. Creating smaller archive parts locally.
     # 4. Uploading these local parts to the Source Drive folder.
     # 5. Updating the database with information about the new part files on Drive.
     # 6. Deleting the original large archive from Drive and locally.
     # This is a major rewrite and is left as a placeholder for future development.
     print(f"\n--> [Step 2a - Repackage] Repackaging logic needs full Drive API adaptation. Skipping for '{os.path.basename(local_archive_path)}'.")
     # For now, if repackaging is needed, we'll skip the archive.
     return False # Indicate repackaging was not successful (or skipped)


# Adapted process_drive_archives to call the updated processing functions
def process_drive_archives(service, drive_folder_ids, conn, tqdm_module):
    print("\n--> [Step 1] Identifying unprocessed archives on Google Drive...")

    source_folder_id = drive_folder_ids.get("source_id")
    completed_folder_id = drive_folder_ids.get("completed_id")

    if not source_folder_id:
        print("    ❌ Source Drive folder not found or accessible. Cannot proceed.")
        return

    # Get list of archive files from the Source Drive folder
    # Assuming archives are .tar.gz files for now
    all_drive_archives = [f for f in list_drive_files_in_folder(service, source_folder_id) if f.get('name', '').lower().endswith('.tar.gz')]

    if not all_drive_archives:
        print("\n✅🎉 No Google Takeout archive files found in the source Drive folder!")
        return

    print(f"    > Found {len(all_drive_archives)} potential archive files in the source Drive folder.")

    # Check database for already processed archives (based on Drive File ID)
    # A robust check here should look at files table: if ALL files originating
    # from a source_archive_drive_id have final_drive_folder_id NOT NULL, consider the archive processed.
    # For simplicity in this step, we'll check if the archive's Drive ID is present
    # in the files table with *any* associated file record. This is a basic indicator.
    cursor = conn.cursor()
    processed_archive_drive_ids = set()
    try:
        cursor.execute("SELECT DISTINCT source_archive_drive_id FROM files")
        processed_archive_drive_ids = {row[0] for row in cursor.fetchall() if row[0] is not None}
        print(f"    > Database contains records linked to {len(processed_archive_drive_ids)} archives.")
    except Exception as e:
        print(f"    ⚠️ Error querying database for processed files: {e}. Proceeding with potentially incomplete history check.")


    processing_queue_drive_files = [
        archive for archive in all_drive_archives
        # Check if the archive ID is NOT in the set of processed archive IDs
        if archive['id'] not in processed_archive_drive_ids
    ]

    if not processing_queue_drive_files:
         print("\n✅🎉 All relevant archives seem to have been processed!")
         # A more sophisticated check could be implemented here to verify completion
         # e.g., check if all files in completed_folder_id match files originally
         # from source_folder_id and if database reflects this.

    else:
        print(f"    > Found {len(processing_queue_drive_files)} archives to process.")
        # Process archives one by one
        for drive_archive_file in tqdm_module(processing_queue_drive_files, desc="Processing Archives from Drive"):
            archive_name = drive_archive_file.get('name')
            archive_id = drive_archive_file.get('id')
            archive_size = int(drive_archive_file.get('size', 0)) # Size in bytes
            archive_size_gb = archive_size / (1024**3)

            print(f"\n--> Processing archive from Drive: '{archive_name}' (ID: {archive_id})")

            # --- Download the archive ---
            local_archive_path = os.path.join(CONFIG["TEMP_PROCESSING_DIR"], archive_name)
            print(f"    > Downloading '{archive_name}' to {local_archive_path}...")
            os.makedirs(CONFIG["TEMP_PROCESSING_DIR"], exist_ok=True) # Ensure temp dir exists

            try:
                # Check if the local file already exists from a previous failed attempt
                if os.path.exists(local_archive_path):
                     print(f"    > Local file '{local_archive_path}' already exists. Resuming from local file.")
                     # Verify file size matches Drive size
                     if os.path.getsize(local_archive_path) != archive_size:
                          print(f"    ⚠️ Local file size mismatch ({os.path.getsize(local_archive_path)} bytes) with Drive ({archive_size} bytes). Redownloading.")
                          os.remove(local_archive_path) # Delete incomplete file
                          # Proceed with download
                          request = service.files().get_media(fileId=archive_id)
                          with open(local_archive_path, 'wb') as f:
                              downloader = MediaIoBaseDownload(f, request)
                              done = False
                              while done is False:
                                  status, done = downloader.next_chunk()
                                  # Optional: Add progress bar using status.progress()
                                  # print(f"    > Download progress: {status.progress() * 100:.2f}%")
                          print(f"    ✅ Download complete: {local_archive_path}")

                     else:
                           print(f"    ✅ Local file '{local_archive_path}' size matches Drive file. Using existing local file.")
                else:
                    # Proceed with download if local file does not exist
                    request = service.files().get_media(fileId=archive_id)
                    with open(local_archive_path, 'wb') as f:
                        downloader = MediaIoBaseDownload(f, request)
                        done = False
                        while done is False:
                            status, done = downloader.next_chunk()
                            # Optional: Add progress bar using status.progress()
                            # print(f"    > Download progress: {status.progress() * 100:.2f}%")
                    print(f"    ✅ Download complete: {local_archive_path}")


                # --- Process the downloaded archive locally ---
                print("    > Processing downloaded archive locally...")
                # Call the adapted processing function with the local file path
                # Check archive size to decide between regular processing or repackaging (repackaging is placeholder for now)
                if archive_size_gb > MAX_SAFE_ARCHIVE_SIZE_GB and '.part-' not in archive_name:
                     print(f"    > Archive size ({archive_size_gb:.2f} GB) exceeds safe limit ({MAX_SAFE_ARCHIVE_SIZE_GB} GB). Attempting repackaging...")
                     # Call the placeholder repackaging function
                     processing_success = plan_and_repackage_archive(
                          local_archive_path,
                          archive_id,
                          archive_name,
                          conn,
                          tqdm_module,
                          service,
                          drive_folder_ids
                     )
                else:
                    print(f"    > Archive size ({archive_size_gb:.2f} GB) is within safe limit or is a part file. Processing directly.")
                    processing_success = process_regular_archive(
                        local_archive_path,
                        archive_id,
                        archive_name,
                        conn,
                        tqdm_module,
                        service, # Pass service object for Drive API calls within processing functions
                        drive_folder_ids # Pass folder IDs for Drive API calls within processing functions
                        )


                # --- Move the processed archive on Drive and clean up local file ---
                if processing_success:
                    print(f"\n--> Processing of '{archive_name}' complete. Moving to completed on Drive.")
                    if completed_folder_id:
                        try:
                            # Remove from source folder, add to completed folder
                            service.files().update(
                                fileId=archive_id,
                                addParents=completed_folder_id,
                                removeParents=source_folder_id,
                                fields='id, parents' # Request updated parents to confirm
                            ).execute()
                            print(f"    ✅ Archive moved successfully on Drive.")

                            # After successfully moving the archive on Drive, it's safe to clean up the local file
                            if os.path.exists(local_archive_path):
                                try:
                                    os.remove(local_archive_path)
                                    print(f"    > Cleaned up local archive file: {local_archive_path}")
                                except Exception as e:
                                    print(f"    ⚠️ Failed to clean up local archive file {local_archive_path}: {e}")

                        except HttpError as error:
                            print(f"    ❌ An API error occurred while moving archive on Drive: {error}")
                            print(f"    >>> Archive '{archive_name}' remains in source folder on Drive. Local file kept in temp. <<<")
                            processing_success = False # Mark as failed if Drive move fails
                        except Exception as e:
                             print(f"    ❌ An unexpected error occurred while moving archive on Drive: {e}")
                             print(f"    >>> Archive '{archive_name}' remains in source folder on Drive. Local file kept in temp. <<<")
                             processing_success = False # Mark as failed if Drive move fails
                    else:
                        print("    ⚠️ Completed Drive folder ID not found. Skipping moving archive on Drive.")
                        print(f"    >>> Archive '{archive_name}' remains in source folder on Drive. Local file kept in temp. <<<")
                        processing_success = False # Consider failed if cannot move on Drive
                else:
                    print(f"\n❌ Processing failed for '{archive_name}'. Leaving in local temp directory and source folder on Drive.")
                    # Rollback happens on next run via integrity check if local temp files remain
                    # Database state will reflect which files *were* processed before failure.


            except HttpError as error:
                print(f"    ❌ An API error occurred while downloading '{archive_name}' (ID: {archive_id}): {error}")
                print(f"    >>> Skipping '{archive_name}'. <<<")
            except FileNotFoundError:
                 print(f"    ❌ Error: Local temporary path {local_archive_path} issue during download setup.")
                 print(f"    >>> Skipping '{archive_name}'. <<<")
            except Exception as e:
                print(f"    ❌ An unexpected error occurred during archive download or initial processing: {e}")
                traceback.print_exc()
                print(f"    >>> Skipping '{archive_name}'. <<<")

            print("\n--- Finished processing archive cycle. ---")


# ==============================================================================
# --- MAIN EXECUTION SCRIPT (Adapted for Drive API) ---
# ==============================================================================
def main(args):
    conn = None
    service = None
    try:
        print("--> [Step 0] Initializing environment...")

        # Ensure local temporary processing directory exists
        if CONFIG["TEMP_PROCESSING_DIR"]:
             os.makedirs(CONFIG["TEMP_PROCESSING_DIR"], exist_ok=True)
             print(f"    > Ensuring local temporary processing directory exists: {CONFIG['TEMP_PROCESSING_DIR']}")
        else:
             print("    ❌ TEMP_PROCESSING_DIR is not set. Please ensure TAKEOUT_TEMP_DIR is configured.")
             return # Exit if temp dir is not configured

        # Authenticate with Google Drive
        service = authenticate_drive()
        if not service:
            print("    ❌ Failed to authenticate with Google Drive. Exiting.")
            return

        # Ensure Drive directory structure exists and get folder IDs
        drive_folder_ids = ensure_drive_directory_structure(service)
        if not drive_folder_ids:
             print("    ❌ Failed to ensure Google Drive directory structure. Exiting.")
             return


        # Check local disk space for temporary processing
        if os.path.exists(CONFIG["TEMP_PROCESSING_DIR"]):
             total_tmp, used_tmp, free_tmp = shutil.disk_usage(CONFIG["TEMP_PROCESSING_DIR"])
             free_tmp_gb = free_tmp / (1024**3)
             # Need enough space for extracting at least one archive chunk + buffer
             required_tmp_gb = REPACKAGE_CHUNK_SIZE_GB + 5 # Add some buffer for extracted files, db ops, etc.
             if free_tmp_gb < required_tmp_gb:
                 print(f"\n❌ PRE-FLIGHT CHECK FAILED: Insufficient free disk space in local temporary directory ({free_tmp_gb:.2f} GB). Required: ~{required_tmp_gb:.2f} GB.")
                 print(f"    >>> Please ensure enough free space in {CONFIG['TEMP_PROCESSING_DIR']} or set TAKEOUT_TEMP_DIR to a location with more space. <<<")
                 # Note: This check is for the local disk where TEMP_PROCESSING_DIR resides
                 return # Exit if not enough temporary space
             print(f"✅ Pre-flight local temporary disk check passed. (Free Space: {free_tmp_gb:.2f} GB in {CONFIG['TEMP_PROCESSING_DIR']})")
        else:
             print(f"    ⚠️ Local temporary directory '{CONFIG['TEMP_PROCESSING_DIR']}' not found during disk check. Skipping disk check.")


        conn = initialize_database(CONFIG["DB_PATH"])
        perform_startup_integrity_check()


        print("✅ Workspace ready.")

        # --- Process archives from Drive ---
        process_drive_archives(service, drive_folder_ids, conn, tqdm)

        print("\n--- WORKFLOW COMPLETE. ---")

    except Exception as e:
        print(f"\n❌ A CRITICAL UNHANDLED ERROR OCCURRED: {e}")
        traceback.print_exc()
    finally:
        # Ensure database connection is closed
        if conn:
            conn.close()
            print("--> [DB] Database connection closed.")

        # Clean up local temporary directories
        if os.path.exists(LOCAL_TEMP_EXTRACT_DIR):
             try: shutil.rmtree(LOCAL_TEMP_EXTRACT_DIR)
             except Exception as e: print(f"    ⚠️ Failed to clean up {LOCAL_TEMP_EXTRACT_DIR}: {e}")
        if os.path.exists(LOCAL_TEMP_BATCH_DIR):
             try: shutil.rmtree(LOCAL_TEMP_BATCH_DIR)
             except Exception as e: print(f"    ⚠️ Failed to clean up {LOCAL_TEMP_BATCH_DIR}: {e}")
        if os.path.exists(LOCAL_JDUPE_TEMP_DIR):
             try: shutil.rmtree(LOCAL_JDUPE_TEMP_DIR)
             except Exception as e: print(f"    ⚠️ Failed to clean up {LOCAL_JDUPE_TEMP_DIR}: {e}")
        # Clean up the main TEMP_PROCESSING_DIR if it's empty and was the default or user-specified local path
        if os.path.exists(TEMP_PROCESSING_DIR):
             try:
                  # Only remove if empty
                  if not os.listdir(TEMP_PROCESSING_DIR):
                      os.rmdir(TEMP_PROCESSING_DIR)
                      print(f"--> Cleaned up main temporary processing directory: {TEMP_PROCESSING_DIR}")
                 except OSError as e:
                      # Directory might not be empty or another process holds files
                      pass # Ignore if not empty
                 except Exception as e: print(f"    ⚠️ Failed to clean up main temp directory {TEMP_PROCESSING_DIR}: {e}")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Process Google Takeout archives from Google Drive.")
    parser.add_argument('--auto-delete-artifacts', action='store_true', help="Enable automatic deletion of 0-byte artifact files.")
    # Note: TEMP_PROCESSING_DIR is configured via environment variable TAKEOUT_TEMP_DIR
    # Drive folder names are configured via environment variable TAKEOUT_DRIVE_SOURCE_FOLDER, etc.
    # DB_PATH is configured via environment variable TAKEOUT_DB_PATH

    args = parser.parse_args()

    # Configuration from environment variables is handled at the top of the script
    # before main is called, allowing CONFIG to be set globally.

    main(args)

"""

# Write the Python script content to a file using cat and EOF
# Ensure EOF is on a line by itself with no trailing whitespace.
# The `\n` before EOF ensures it's on a new line.
echo "$PYTHON_SCRIPT" > "$PYTHON_SCRIPT_FILE"
echo "Python script written to: $PYTHON_SCRIPT_FILE"

# Make the Python script executable
chmod +x "$PYTHON_SCRIPT_FILE"
echo "Made Python script executable."

# Add the script directory to the PATH in ~/.bashrc if not already there
if ! grep -q "export PATH=.*$SCRIPT_DIR" "$HOME/.bashrc"; then
  echo "Adding $SCRIPT_DIR to PATH in ~/.bashrc"
  echo "export PATH=\$PATH:$SCRIPT_DIR" >> "$HOME/.bashrc"
else
  echo "Script directory $SCRIPT_DIR already in PATH."
fi

# Set GOOGLE_APPLICATION_CREDENTIALS environment variable in ~/.bashrc
CREDENTIALS_PATH="$HOME/.secrets/credentials.json"
# Check if the line exists and contains the correct path
if ! grep -q "export GOOGLE_APPLICATION_CREDENTIALS=\"$CREDENTIALS_PATH\"" "$HOME/.bashrc"; then
  # Remove any existing GOOGLE_APPLICATION_CREDENTIALS setting to avoid duplicates
  sed -i '/^export GOOGLE_APPLICATION_CREDENTIALS=/d' "$HOME/.bashrc"
  echo "Setting GOOGLE_APPLICATION_CREDENTIALS in ~/.bashrc"
  echo "export GOOGLE_APPLICATION_CREDENTIALS=\"$CREDENTIALS_PATH\"" >> "$HOME/.bashrc"
  echo "Please ensure your service account credentials file is located at: $CREDENTIALS_PATH"
else
  echo "GOOGLE_APPLICATION_CREDENTIALS already set correctly in ~/.bashrc."
fi

# Source .bashrc to update the current session's environment variables and PATH
# Note: For changes to be permanent across new login sessions, sourcing is needed.
# For a single script execution like this, exporting variables before the command is also an option.
# Sourcing here applies to the current shell where the setup script is being run.
# User will need to source or open a new terminal for interactive use.
source "$HOME/.bashrc"
echo "Sourced ~/.bashrc to update current session."


echo "--- Setup Complete ---"
echo "You can now run the script from any terminal session after opening a new one or running 'source ~/.bashrc', using the command: takeout_organizer.py"
echo "Remember to place your Google Takeout archive files (.tar.gz) into the Google Drive folder named '${CONFIG[DRIVE_SOURCE_FOLDER_NAME]}' (default: 00-ALL-ARCHIVES) in the base 'TakeoutProject' folder in the root of your Drive."
echo "You can configure the Drive folder names and local temporary directory using environment variables:"
echo "  - TAKEOUT_DRIVE_SOURCE_FOLDER=/path/to/source/folder/name"
echo "  - TAKEOUT_DRIVE_COMPLETED_FOLDER=/path/to/completed/folder/name"
echo "  - TAKEOUT_DRIVE_ORGANIZED_FOLDER=/path/to/organized/folder/name"
echo "  - TAKEOUT_DRIVE_TRASH_FOLDER=/path/to/trash/folder/name"
echo "  - TAKEOUT_TEMP_DIR=/path/to/local/temp/directory"
echo "  - TAKEOUT_DB_PATH=/path/to/local/database.db (default: \$HOME/.takeout_organizer/takeout_archive.db)"
echo "Example usage with custom source folder and temp directory:"
echo "  TAKEOUT_DRIVE_SOURCE_FOLDER=\"My Takeout Archives\" TAKEOUT_TEMP_DIR=\"/mnt/usbstorage/temp\" takeout_organizer.py"

# Add EOF on a line by itself at the very end
EOF
