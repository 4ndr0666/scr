#!/bin/bash
#
# DietPi First-Boot Custom Script for Takeout Processor Appliance (v2.0 - Unified API Model)
# This version represents a complete architectural refactor to a pure API-driven model,
# inspired by the original Colab notebook's robust local processing logic.

set -euo pipefail

# --- Configuration ---
INSTALL_DIR="/opt/google_takeout_organizer"
PROCESSOR_FILENAME="google_takeout_organizer.py"
PROCESSOR_SCRIPT_PATH="${INSTALL_DIR}/${PROCESSOR_FILENAME}"
CREDENTIALS_PATH="${INSTALL_DIR}/credentials.json"
SYSTEMD_SERVICE_NAME="takeout-organizer.service"
SYSTEMD_SERVICE_PATH="/etc/systemd/system/${SYSTEMD_SERVICE_NAME}"

# --- Logging Utilities ---
_log_info() { printf "\n[INFO] %s\n" "$*"; }
_log_ok()   { printf "✅ %s\n" "$*"; }
_log_warn() { printf "⚠️  %s\n" "$*"; }
_log_fail() { printf "❌ ERROR: %s\n" "$*"; exit 1; }

# ==============================================================================
# --- Main Installation Logic ---
# ==============================================================================
main() {
    _log_info "--- Starting Takeout Processor Appliance Setup (v2.0 Unified API Model) ---"
    if [[ $EUID -ne 0 ]]; then _log_fail "This script must be run as root."; fi
    _log_ok "Root privileges confirmed."

    _log_info "Ensuring any old service version is stopped..."
    systemctl stop ${SYSTEMD_SERVICE_NAME} || true
    _log_ok "Service stopped."

    _log_info "Updating package lists and installing dependencies..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null
    apt-get install -y python3 jdupes sqlite3 python3-googleapi python3-google-auth-httplib2 python3-google-auth-oauthlib python3-tqdm >/dev/null
    _log_ok "All dependencies are installed."

    _log_info "Creating application directory..."
    mkdir -p "$INSTALL_DIR"
    _log_ok "Directory created."
    
    _log_info "Handling Service Account Credentials..."
    if [[ ! -f "$CREDENTIALS_PATH" ]]; then
        _log_warn "'credentials.json' not found. The service will fail until it is placed at ${CREDENTIALS_PATH}."
    else
        chmod 600 "$CREDENTIALS_PATH"
    fi
    _log_ok "Service account credentials handled."
    
    _log_info "Deploying the Takeout Processor script..."
    # --- BEGIN EMBEDDED PYTHON SCRIPT (v2.0) ---
    cat << 'EOF' > "$PROCESSOR_SCRIPT_PATH"
"""
Google Takeout Organizer (v2.0 - Unified API Model)

This script is a pure API-driven daemon for processing Google Takeout archives.
It adopts the robust local-processing logic from its Colab notebook origins
and adapts it for a headless, long-running service environment.

Core Workflow:
1.  API: Scan for new archives in '00-UPLOADS'.
2.  API: Move new archives to '00-ALL-ARCHIVES' queue.
3.  API: Lock and move the next archive to '01-PROCESSING-STAGING'.
4.  API: Download the staged archive to a local '/tmp' directory.
5.  LOCAL: Process the archive entirely on the local file system (extract,
    hash, deduplicate against a local DB, organize photos).
6.  API: Upload the resulting unique, organized files to the correct
    folders in '03-organized'.
7.  API: Move the original archive to '05-COMPLETED-ARCHIVES'.
8.  Loop and sleep.
"""

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
import logging
from pathlib import Path

# Google API Imports
import google.auth
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaIoBaseDownload, MediaFileUpload

try:
    from tqdm.auto import tqdm
except ImportError:
    def tqdm(iterable, *args, **kwargs): return iterable

# ==============================================================================
# --- 1. CORE CONFIGURATION ---
# ==============================================================================
APP_BASE_DIR = Path("/opt/google_takeout_organizer")
DB_PATH = APP_BASE_DIR / "takeout_archive.db"
DRIVE_ROOT_FOLDER_NAME = "TakeoutProject"
PROCESSING_IDLE_SLEEP_SECONDS = 60 * 5

# Local temporary directories, self-cleaning.
VM_TEMP_BASE_DIR = Path("/tmp/takeout_organizer")
VM_TEMP_DOWNLOAD_DIR = VM_TEMP_BASE_DIR / "download"
VM_TEMP_EXTRACT_DIR = VM_TEMP_BASE_DIR / "extract"

# ==============================================================================
# --- 2. LOGGING & EXCEPTIONS ---
# ==============================================================================
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s", handlers=[logging.StreamHandler(sys.stdout)])
logger = logging.getLogger(__name__)

class TakeoutError(Exception): pass
class DriveError(TakeoutError): pass
class DatabaseError(TakeoutError): pass
class ProcessingError(TakeoutError): pass

# ==============================================================================
# --- 3. GOOGLE DRIVE MANAGER ---
# ==============================================================================
class DriveManager:
    """A pure API-driven manager for all Google Drive interactions."""
    def __init__(self, root_folder_name: str):
        self.root_folder_name = root_folder_name
        self.service = self._authenticate()
        self.folder_ids: dict[str, str] = {}

    def _authenticate(self):
        logger.info("--> [Auth] Authenticating with Google Drive service account...")
        try:
            creds, _ = google.auth.default(scopes=["https://www.googleapis.com/auth/drive"])
            return build("drive", "v3", credentials=creds, cache_discovery=False)
        except Exception as e:
            raise DriveError(f"Authentication failed: {e}") from e

    def initialize_folder_structure(self):
        logger.info("--> [API] Initializing Google Drive folder structure...")
        try:
            root_query = f"name='{self.root_folder_name}' and 'root' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false"
            self.folder_ids["root"] = self._find_or_create_folder("root", self.root_folder_name, query=root_query)

            structure = {
                "00-UPLOADS": {}, "00-ALL-ARCHIVES": {}, "01-PROCESSING-STAGING": {},
                "03-organized": {"My-Photos": {}, "My-Files": {}},
                "04-trash": {"quarantined_artifacts": {}, "duplicates": {}},
                "05-COMPLETED-ARCHIVES": {}
            }
            def _traverse_and_create(parent_id: str, substructure: dict):
                for name, sub in substructure.items():
                    folder_id = self._find_or_create_folder(parent_id, name)
                    self.folder_ids[name] = folder_id
                    if sub: _traverse_and_create(folder_id, sub)
            _traverse_and_create(self.folder_ids["root"], structure)
            logger.info("--> [API] Folder structure synchronized.")
        except HttpError as e:
            raise DriveError(f"API error during folder setup: {e}") from e

    def _find_or_create_folder(self, parent_id: str, name: str, query: str = None) -> str:
        if not query:
            query = f"name='{name}' and '{parent_id}' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false"
        
        response = self.service.files().list(q=query, fields="files(id)", supportsAllDrives=True, includeItemsFromAllDrives=True).execute()
        files = response.get("files", [])
        
        if files: return files[0].get("id")
        
        logger.info(f"    > Creating folder: {name}")
        file_metadata = {'name': name, 'mimeType': 'application/vnd.google-apps.folder', 'parents': [parent_id]}
        folder = self.service.files().create(body=file_metadata, fields="id", supportsAllDrives=True).execute()
        return folder.get("id")

    def list_files(self, folder_id: str, page_size: int = 10) -> list:
        try:
            query = f"'{folder_id}' in parents and trashed=false and (mimeType='application/zip' or mimeType='application/gzip' or mimeType='application/x-gzip')"
            response = self.service.files().list(
                q=query, orderBy="createdTime", pageSize=page_size, fields="files(id, name, size)",
                supportsAllDrives=True, includeItemsFromAllDrives=True
            ).execute()
            return response.get("files", [])
        except HttpError as e:
            raise DriveError(f"Failed to list files in folder {folder_id}: {e}") from e

    def move_file(self, file_id: str, to_folder_id: str, from_folder_id: str):
        try:
            self.service.files().update(fileId=file_id, addParents=to_folder_id, removeParents=from_folder_id, supportsAllDrives=True).execute()
        except HttpError as e:
            raise DriveError(f"Failed to move file {file_id}: {e}") from e

    def download_file(self, file_id: str, file_name: str, dest_path: Path) -> Path:
        download_filepath = dest_path / file_name
        logger.info(f"    > Downloading '{file_name}' to {download_filepath}...")
        try:
            request = self.service.files().get_media(fileId=file_id, supportsAllDrives=True)
            with open(download_filepath, "wb") as fh:
                downloader = MediaIoBaseDownload(fh, request, chunksize=1024*1024*50) # 50MB chunks
                done = False
                while not done:
                    status, done = downloader.next_chunk()
            logger.info(f"    ✅ Download complete.")
            return download_filepath
        except HttpError as e:
            raise DriveError(f"Failed to download file {file_id}: {e}") from e

    def upload_file(self, local_path: Path, drive_folder_id: str):
        try:
            logger.debug(f"    > Uploading '{local_path.name}' to Drive folder ID {drive_folder_id}...")
            file_metadata = {'name': local_path.name, 'parents': [drive_folder_id]}
            media = MediaFileUpload(str(local_path), mimetype='application/octet-stream', resumable=True)
            self.service.files().create(body=file_metadata, media_body=media, fields='id', supportsAllDrives=True).execute()
        except HttpError as e:
            raise DriveError(f"Failed to upload file {local_path}: {e}") from e

# ==============================================================================
# --- 4. DATABASE MANAGER ---
# ==============================================================================
class DatabaseManager:
    """Manages the SQLite database for tracking file hashes and status."""
    def __init__(self, db_path: Path):
        self.db_path = db_path
        self._initialize()

    def _initialize(self):
        logger.info("--> [DB] Initializing database...")
        try:
            self.db_path.parent.mkdir(parents=True, exist_ok=True)
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                cursor.execute("""
                CREATE TABLE IF NOT EXISTS archives (
                    drive_id TEXT PRIMARY KEY, name TEXT NOT NULL, size_bytes INTEGER, status TEXT NOT NULL, processed_at TEXT
                )""")
                cursor.execute("""
                CREATE TABLE IF NOT EXISTS files (
                    sha256_hash TEXT PRIMARY KEY, original_path TEXT NOT NULL, source_archive_name TEXT NOT NULL
                )""")
            logger.info("    ✅ Database ready.")
        except sqlite3.Error as e:
            raise DatabaseError(f"Failed to initialize database: {e}") from e

    def record_archive_status(self, drive_id: str, name: str, size: int, status: str):
        with sqlite3.connect(self.db_path) as conn:
            processed_at = datetime.now().isoformat() if status in ['COMPLETED', 'FAILED'] else None
            conn.execute("INSERT OR REPLACE INTO archives (drive_id, name, size_bytes, status, processed_at) VALUES (?, ?, ?, ?, ?)",
                         (drive_id, name, size, status, processed_at))

    def get_all_file_hashes(self) -> set:
        with sqlite3.connect(self.db_path) as conn:
            cursor = conn.execute("SELECT sha256_hash FROM files")
            return {row[0] for row in cursor.fetchall()}

    def add_file_hashes(self, new_files: list):
        if not new_files: return
        with sqlite3.connect(self.db_path) as conn:
            conn.executemany("INSERT OR IGNORE INTO files (sha256_hash, original_path, source_archive_name) VALUES (?, ?, ?)", new_files)

# ==============================================================================
# --- 5. ARCHIVE PROCESSOR ---
# ==============================================================================
class ArchiveProcessor:
    """Handles the local processing of a downloaded archive."""
    def __init__(self, drive_manager: DriveManager, db_manager: DatabaseManager):
        self.drive_manager = drive_manager
        self.db_manager = db_manager

    def process_archive(self, archive_path: Path, archive_name: str):
        logger.info(f"--> [Step 3] Processing '{archive_name}' locally...")
        try:
            self._cleanup_temp_dirs()
            with tarfile.open(archive_path, "r:gz") as tf:
                logger.info(f"    > Extracting archive to {VM_TEMP_EXTRACT_DIR}...")
                tf.extractall(path=VM_TEMP_EXTRACT_DIR)
            
            photos_source = VM_TEMP_EXTRACT_DIR / "Takeout" / "Google Photos"
            files_source = VM_TEMP_EXTRACT_DIR / "Takeout"

            if photos_source.exists():
                self._organize_photos(photos_source, archive_name)
            
            if files_source.exists():
                self._deduplicate_and_upload_files(files_source, archive_name)

            logger.info(f"    ✅ Finished local processing for '{archive_name}'.")
        except Exception as e:
            raise ProcessingError(f"Error during local processing of '{archive_name}': {e}") from e
        finally:
            self._cleanup_temp_dirs()

    def _organize_photos(self, source_dir: Path, archive_name: str):
        logger.info("    > Organizing photos...")
        photo_hashes = self.db_manager.get_all_file_hashes()
        new_files_to_db = []

        for root, _, files in os.walk(source_dir):
            for file in files:
                if file.lower().endswith('.json'): continue
                
                media_path = Path(root) / file
                sha256 = self._calculate_file_hash(media_path)
                if sha256 in photo_hashes: continue

                timestamp = self._get_photo_timestamp(media_path)
                dt = datetime.fromtimestamp(timestamp)
                new_name = f"{dt.strftime('%Y-%m-%d_%Hh%Mm%Ss')}_{media_path.name}"
                
                self.drive_manager.upload_file(media_path, self.drive_manager.folder_ids["My-Photos"])
                new_files_to_db.append((sha256, str(media_path.relative_to(VM_TEMP_EXTRACT_DIR)), archive_name))
        
        self.db_manager.add_file_hashes(new_files_to_db)
        logger.info(f"        > Uploaded and indexed {len(new_files_to_db)} new photos.")

    def _deduplicate_and_upload_files(self, source_dir: Path, archive_name: str):
        logger.info("    > Deduplicating and uploading other files...")
        file_hashes = self.db_manager.get_all_file_hashes()
        new_files_to_db = []

        # We can't use jdupes against a remote target, so we check hashes before upload.
        for root, _, files in os.walk(source_dir):
            # Skip the Google Photos directory as it's handled separately
            if 'Google Photos' in Path(root).parts: continue
            
            for file in files:
                file_path = Path(root) / file
                sha256 = self._calculate_file_hash(file_path)
                if sha256 in file_hashes: continue
                
                self.drive_manager.upload_file(file_path, self.drive_manager.folder_ids["My-Files"])
                new_files_to_db.append((sha256, str(file_path.relative_to(VM_TEMP_EXTRACT_DIR)), archive_name))
        
        self.db_manager.add_file_hashes(new_files_to_db)
        logger.info(f"        > Uploaded and indexed {len(new_files_to_db)} new files.")

    def _get_photo_timestamp(self, media_path: Path) -> int:
        json_path = media_path.with_suffix(media_path.suffix + ".json")
        if not json_path.exists(): json_path = media_path.with_suffix(".json")
        
        if json_path.exists():
            try:
                with open(json_path, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                ts = data.get('photoTakenTime', {}).get('timestamp')
                if ts: return int(ts)
            except (json.JSONDecodeError, KeyError):
                pass
        return int(media_path.stat().st_mtime)

    def _calculate_file_hash(self, filepath: Path) -> str:
        h = hashlib.sha256()
        with open(filepath, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                h.update(chunk)
        return h.hexdigest()

    def _cleanup_temp_dirs(self):
        for temp_dir in [VM_TEMP_DOWNLOAD_DIR, VM_TEMP_EXTRACT_DIR]:
            if temp_dir.exists(): shutil.rmtree(temp_dir)
            temp_dir.mkdir(parents=True, exist_ok=True)

# ==============================================================================
# --- 6. MAIN WORKFLOW ---
# ==============================================================================
def main():
    """Main function to orchestrate the Takeout processing workflow."""
    parser = argparse.ArgumentParser()
    args, unknown = parser.parse_known_args() # For Jupyter/Colab compatibility

    logger.info("--> [Step 0] Initializing service...")
    drive_manager, db_manager, processor = None, None, None
    
    try:
        drive_manager = DriveManager(DRIVE_ROOT_FOLDER_NAME)
        drive_manager.initialize_folder_structure()
        
        db_manager = DatabaseManager(DB_PATH)
        processor = ArchiveProcessor(drive_manager, db_manager)

        logger.info("✅ Pre-flight checks passed. Starting main loop.")
        
        while True:
            # 1. Check for new uploads and move them to the main queue
            logger.info("\n--> [Step 1] Checking for new user uploads...")
            uploads = drive_manager.list_files(drive_manager.folder_ids["00-UPLOADS"])
            if uploads:
                logger.info(f"    > Found {len(uploads)} new archive(s). Moving to queue...")
                for up in uploads:
                    drive_manager.move_file(up['id'], drive_manager.folder_ids["00-ALL-ARCHIVES"], drive_manager.folder_ids["00-UPLOADS"])
            else:
                logger.info("    > No new files found in uploads folder.")

            # 2. Get the next archive from the main queue
            logger.info("--> [Step 2] Identifying next archive for processing...")
            queue = drive_manager.list_files(drive_manager.folder_ids["00-ALL-ARCHIVES"], page_size=1)

            if not queue:
                logger.info(f"✅ No archives to process. Idling for {PROCESSING_IDLE_SLEEP_SECONDS}s...")
                time.sleep(PROCESSING_IDLE_SLEEP_SECONDS)
                continue
            
            archive = queue[0]
            archive_id, archive_name, archive_size = archive['id'], archive['name'], int(archive.get('size', 0))
            logger.info(f"--> Selected '{archive_name}' ({archive_size / 1e9:.2f} GB).")
            
            try:
                # 3. Lock, download, process, and finalize
                db_manager.record_archive_status(archive_id, archive_name, archive_size, "STAGING")
                drive_manager.move_file(archive_id, drive_manager.folder_ids["01-PROCESSING-STAGING"], drive_manager.folder_ids["00-ALL-ARCHIVES"])
                
                downloaded_path = drive_manager.download_file(archive_id, archive_name, VM_TEMP_DOWNLOAD_DIR)
                
                processor.process_archive(downloaded_path, archive_name)
                
                drive_manager.move_file(archive_id, drive_manager.folder_ids["05-COMPLETED-ARCHIVES"], drive_manager.folder_ids["01-PROCESSING-STAGING"])
                db_manager.record_archive_status(archive_id, archive_name, archive_size, "COMPLETED")
                logger.info(f"✅ Successfully processed and committed '{archive_name}'.")

            except (DriveError, DatabaseError, ProcessingError) as e:
                logger.error(f"❌ Error processing '{archive_name}': {e}")
                db_manager.record_archive_status(archive_id, archive_name, archive_size, "FAILED")
                # Attempt to roll back
                try:
                    drive_manager.move_file(archive_id, drive_manager.folder_ids["00-ALL-ARCHIVES"], drive_manager.folder_ids["01-PROCESSING-STAGING"])
                    logger.info(f"    > Rolled back '{archive_name}' to the main queue.")
                except DriveError as rollback_e:
                    logger.critical(f"    ❌ CRITICAL: Failed to rollback '{archive_name}': {rollback_e}")

            except Exception as e:
                logger.critical(f"An unexpected critical error occurred with '{archive_name}': {e}", exc_info=True)
                db_manager.record_archive_status(archive_id, archive_name, archive_size, "FAILED")

            logger.info("\n--- WORKFLOW CYCLE COMPLETE ---")

    except (TakeoutError, Exception) as e:
        logger.critical(f"\n❌ A CRITICAL STARTUP ERROR OCCURRED: {e}", exc_info=True)
        sys.exit(1)

if __name__ == "__main__":
    main()
EOF
    # --- END EMBEDDED PYTHON SCRIPT ---

    chmod +x "$PROCESSOR_SCRIPT_PATH"
    _log_ok "Application script deployed successfully."
    
    _log_info "Creating and enabling the systemd service..."
    cat << EOF > "$SYSTEMD_SERVICE_PATH"
[Unit]
Description=Google Takeout Organizer Service (v2.0)
After=network-online.target

[Service]
Type=simple
Environment="GOOGLE_APPLICATION_CREDENTIALS=${CREDENTIALS_PATH}"
ExecStart=/usr/bin/python3 ${PROCESSOR_SCRIPT_PATH}
Restart=on-failure
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "$SYSTEMD_SERVICE_NAME"
    _log_ok "Systemd service '${SYSTEMD_SERVICE_NAME}' created and enabled."

    echo ""
    _log_ok "--------------------------------------------------------"
    _log_ok "Takeout Processor Appliance Setup is COMPLETE!"
    _log_info "The service has been reloaded. It will start automatically on boot."
    _log_info "To start it now, run: systemctl start ${SYSTEMD_SERVICE_NAME}"
    _log_info "To monitor progress, run: journalctl -fu ${SYSTEMD_SERVICE_NAME}"
    _log_ok "--------------------------------------------------------"
}

main
