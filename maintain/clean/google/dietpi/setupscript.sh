#!/bin/bash
#
# DietPi First-Boot Custom Script for Takeout Processor Appliance (v3.1 - Final Corpora Fix)
# This version applies the critical 'corpora="allDrives"' parameter to the file
# listing method, which was the final point of failure.

set -euo pipefail

# --- Configuration ---
INSTALL_DIR="/opt/google_takeout_organizer"
PROCESSOR_FILENAME="google_takeout_organizer.py"
PROCESSOR_SCRIPT_PATH="${INSTALL_DIR}/${PROCESSOR_FILENAME}"
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
    _log_info "--- Starting Takeout Processor Appliance Setup (v3.1 Final Corpora Fix) ---"
    if [[ $EUID -ne 0 ]]; then _log_fail "This script must be run as root."; fi
    _log_ok "Root privileges confirmed."

    _log_info "Ensuring any old service version is stopped..."
    systemctl stop ${SYSTEMD_SERVICE_NAME} &>/dev/null || true
    _log_ok "Service stopped."

    _log_info "Updating package lists and installing dependencies..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null
    apt-get install -y python3 jdupes sqlite3 python3-googleapi python3-google-auth-httplib2 python3-google-auth-oauthlib python3-tqdm >/dev/null
    _log_ok "All dependencies are installed."

    _log_info "Creating application directory..."
    mkdir -p "$INSTALL_DIR"
    _log_ok "Directory created."
    
    _log_info "Detecting Service Account Credential file..."
    CREDENTIALS_FILE=$(find "$INSTALL_DIR" -maxdepth 1 -type f \( -name "*.json" -o -name "*.txt" \) -print -quit)

    if [[ -z "$CREDENTIALS_FILE" ]]; then
        _log_warn "No credential file (.json or .txt) found in ${INSTALL_DIR}."
        CREDENTIALS_PATH_FOR_SERVICE="${INSTALL_DIR}/credentials.json" # Placeholder
    else
        _log_ok "Found credential file: $(basename "$CREDENTIALS_FILE")"
        chmod 600 "$CREDENTIALS_FILE"
        CREDENTIALS_PATH_FOR_SERVICE="$CREDENTIALS_FILE"
    fi
    
    _log_info "Deploying the Takeout Processor script..."
    # --- BEGIN EMBEDDED PYTHON SCRIPT (v3.1) ---
    cat << 'EOF' > "$PROCESSOR_SCRIPT_PATH"
"""
Google Takeout Organizer (v3.1 - Unified API Model)
"""

import os, shutil, subprocess, tarfile, json, traceback, re, sys, argparse, sqlite3, hashlib, time, logging
from datetime import datetime
from pathlib import Path

import google.auth
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaIoBaseDownload, MediaFileUpload

try:
    from tqdm.auto import tqdm
except ImportError:
    def tqdm(iterable, *args, **kwargs): return iterable

# --- Core Configuration ---
APP_BASE_DIR = Path("/opt/google_takeout_organizer")
DB_PATH = APP_BASE_DIR / "takeout_archive.db"
DRIVE_ROOT_FOLDER_NAME = "TakeoutProject"
PROCESSING_IDLE_SLEEP_SECONDS = 300
VM_TEMP_BASE_DIR = Path("/tmp/takeout_organizer")
VM_TEMP_DOWNLOAD_DIR = VM_TEMP_BASE_DIR / "download"
VM_TEMP_EXTRACT_DIR = VM_TEMP_BASE_DIR / "extract"

# --- Logging & Exceptions ---
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s", handlers=[logging.StreamHandler(sys.stdout)])
logger = logging.getLogger(__name__)

class TakeoutError(Exception): pass
class DriveError(TakeoutError): pass
class DatabaseError(TakeoutError): pass
class ProcessingError(TakeoutError): pass

class DriveManager:
    """Manages all Google Drive API interactions."""
    def __init__(self, root_folder_name: str):
        self.root_folder_name = root_folder_name
        self.service = self._authenticate()
        self.folder_ids: dict[str, str] = {}

    def _authenticate(self):
        logger.info("--> [Auth] Authenticating via service account...")
        try:
            creds, _ = google.auth.default(scopes=["https://www.googleapis.com/auth/drive"])
            return build("drive", "v3", credentials=creds, cache_discovery=False)
        except Exception as e:
            raise DriveError(f"Authentication failed: {e}") from e

    def initialize_folder_structure(self):
        logger.info("--> [API] Synchronizing folder structure...")
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
        except HttpError as e:
            raise DriveError(f"API error during folder setup: {e}") from e

    def _find_or_create_folder(self, parent_id: str, name: str, query: str = None) -> str:
        q = query or f"name='{name}' and '{parent_id}' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false"
        response = self.service.files().list(q=q, fields="files(id)", supportsAllDrives=True, includeItemsFromAllDrives=True, corpora="allDrives").execute()
        files = response.get("files", [])
        if files: return files[0].get("id")
        logger.info(f"    > Creating folder: {name}")
        meta = {'name': name, 'mimeType': 'application/vnd.google-apps.folder', 'parents': [parent_id]}
        return self.service.files().create(body=meta, fields="id", supportsAllDrives=True).execute().get("id")

    def list_files(self, folder_id: str, page_size: int = 10) -> list:
        try:
            query = f"'{folder_id}' in parents and trashed=false"
            # THE DEFINITIVE FIX: 'corpora' is required for service accounts to see shared files.
            response = self.service.files().list(
                q=query,
                orderBy="createdTime",
                pageSize=page_size,
                fields="files(id, name, size)",
                supportsAllDrives=True,
                includeItemsFromAllDrives=True,
                corpora="allDrives"
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
        logger.info(f"    > Downloading '{file_name}'...")
        try:
            request = self.service.files().get_media(fileId=file_id, supportsAllDrives=True)
            with open(download_filepath, "wb") as fh:
                downloader = MediaIoBaseDownload(fh, request, chunksize=1024*1024*50)
                done = False
                while not done: status, done = downloader.next_chunk()
            logger.info(f"    ✅ Download complete.")
            return download_filepath
        except HttpError as e:
            raise DriveError(f"Failed to download file {file_id}: {e}") from e

    def upload_file(self, local_path: Path, drive_folder_id: str):
        try:
            logger.debug(f"    > Uploading '{local_path.name}'...")
            meta = {'name': local_path.name, 'parents': [drive_folder_id]}
            media = MediaFileUpload(str(local_path), mimetype='application/octet-stream', resumable=True)
            self.service.files().create(body=meta, media_body=media, fields='id', supportsAllDrives=True).execute()
        except HttpError as e:
            raise DriveError(f"Failed to upload file {local_path}: {e}") from e

class DatabaseManager:
    def __init__(self, db_path: Path):
        self.db_path = db_path
        self._initialize()

    def _initialize(self):
        logger.info("--> [DB] Initializing database...")
        try:
            self.db_path.parent.mkdir(parents=True, exist_ok=True)
            with sqlite3.connect(self.db_path) as conn:
                conn.execute("CREATE TABLE IF NOT EXISTS archives (drive_id TEXT PRIMARY KEY, name TEXT, size INTEGER, status TEXT, processed_at TEXT)")
                conn.execute("CREATE TABLE IF NOT EXISTS files (sha256_hash TEXT PRIMARY KEY, source_archive_name TEXT)")
            logger.info("    ✅ Database ready.")
        except sqlite3.Error as e:
            raise DatabaseError(f"DB initialization failed: {e}") from e

    def record_archive_status(self, drive_id: str, name: str, size: int, status: str):
        with sqlite3.connect(self.db_path) as conn:
            ts = datetime.now().isoformat() if status in ['COMPLETED', 'FAILED'] else None
            conn.execute("INSERT OR REPLACE INTO archives VALUES (?, ?, ?, ?, ?)", (drive_id, name, size, status, ts))

    def get_all_file_hashes(self) -> set:
        with sqlite3.connect(self.db_path) as conn:
            return {row[0] for row in conn.execute("SELECT sha256_hash FROM files")}

    def add_processed_files(self, files_to_add: list):
        if not files_to_add: return
        with sqlite3.connect(self.db_path) as conn:
            conn.executemany("INSERT OR IGNORE INTO files VALUES (?, ?)", files_to_add)

class ArchiveProcessor:
    def __init__(self, drive: DriveManager, db: DatabaseManager):
        self.drive = drive
        self.db = db

    def process(self, archive_path: Path, archive_name: str):
        logger.info(f"--> [Step 3] Processing '{archive_name}' locally...")
        try:
            self._cleanup_temp_dirs()
            with tarfile.open(archive_path, "r:gz") as tf:
                logger.info(f"    > Extracting archive...")
                tf.extractall(path=VM_TEMP_EXTRACT_DIR)
            
            self._process_directory(VM_TEMP_EXTRACT_DIR, archive_name)
            logger.info(f"    ✅ Finished local processing for '{archive_name}'.")
        except Exception as e:
            raise ProcessingError(f"Local processing failed: {e}") from e
        finally:
            self._cleanup_temp_dirs()

    def _process_directory(self, source_dir: Path, archive_name: str):
        logger.info("    > Hashing, organizing, and uploading unique files...")
        known_hashes = self.db.get_all_file_hashes()
        new_files_to_db = []
        
        for path in tqdm(list(source_dir.rglob('*')), desc="Processing files"):
            if path.is_dir(): continue
            
            sha256 = self._calculate_file_hash(path)
            if sha256 in known_hashes: continue

            # Determine destination
            is_photo = "Google Photos" in path.parts
            if is_photo:
                ts = self._get_photo_timestamp(path)
                final_name = f"{datetime.fromtimestamp(ts).strftime('%Y-%m-%d_%Hh%Mm%Ss')}_{path.name}"
                new_path = path.rename(path.with_name(final_name))
                self.drive.upload_file(new_path, self.drive.folder_ids["My-Photos"])
            else:
                self.drive.upload_file(path, self.drive.folder_ids["My-Files"])
            
            new_files_to_db.append((sha256, archive_name))
            known_hashes.add(sha256) # Add to in-memory set to avoid re-hashing duplicates within the same archive

        self.db.add_processed_files(new_files_to_db)
        logger.info(f"        > Uploaded and indexed {len(new_files_to_db)} new files.")

    def _get_photo_timestamp(self, p: Path) -> int:
        json_p = p.with_suffix(p.suffix + ".json")
        if not json_p.exists(): json_p = p.with_suffix(".json")
        if json_p.exists():
            try:
                with open(json_p, 'r') as f: data = json.load(f)
                return int(data['photoTakenTime']['timestamp'])
            except (KeyError, json.JSONDecodeError): pass
        return int(p.stat().st_mtime)

    def _calculate_file_hash(self, p: Path) -> str:
        h = hashlib.sha256()
        with open(p, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""): h.update(chunk)
        return h.hexdigest()

    def _cleanup_temp_dirs(self):
        for d in [VM_TEMP_DOWNLOAD_DIR, VM_TEMP_EXTRACT_DIR]:
            shutil.rmtree(d, ignore_errors=True)
            d.mkdir(parents=True, exist_ok=True)

def main():
    parser = argparse.ArgumentParser()
    parser.parse_known_args()
    logger.info("--> [Step 0] Initializing service...")
    try:
        drive = DriveManager(DRIVE_ROOT_FOLDER_NAME)
        drive.initialize_folder_structure()
        db = DatabaseManager(DB_PATH)
        processor = ArchiveProcessor(drive, db)
        logger.info("✅ Pre-flight checks passed. Starting main loop.")
        while True:
            logger.info("\n--> [Step 1] Checking for new user uploads...")
            uploads = drive.list_files(drive.folder_ids["00-UPLOADS"])
            if uploads:
                logger.info(f"    > Found {len(uploads)} new archive(s). Moving to queue...")
                for up in uploads: drive.move_file(up['id'], drive.folder_ids["00-ALL-ARCHIVES"], drive.folder_ids["00-UPLOADS"])
            else:
                logger.info("    > No new files found in uploads folder.")
            
            logger.info("--> [Step 2] Identifying next archive for processing...")
            queue = drive.list_files(drive.folder_ids["00-ALL-ARCHIVES"], page_size=1)
            if not queue:
                logger.info(f"✅ No archives to process. Idling for {PROCESSING_IDLE_SLEEP_SECONDS}s...")
                time.sleep(PROCESSING_IDLE_SLEEP_SECONDS)
                continue
            
            archive = queue[0]
            archive_id, name, size = archive['id'], archive['name'], int(archive.get('size', 0))
            logger.info(f"--> Selected '{name}' ({size / 1e9:.2f} GB).")
            
            try:
                db.record_archive_status(archive_id, name, size, "STAGING")
                drive.move_file(archive_id, drive.folder_ids["01-PROCESSING-STAGING"], drive.folder_ids["00-ALL-ARCHIVES"])
                dl_path = drive.download_file(archive_id, name, VM_TEMP_DOWNLOAD_DIR)
                processor.process(dl_path, name)
                drive.move_file(archive_id, drive.folder_ids["05-COMPLETED-ARCHIVES"], drive.folder_ids["01-PROCESSING-STAGING"])
                db.record_archive_status(archive_id, name, size, "COMPLETED")
                logger.info(f"✅ Successfully processed '{name}'.")
            except (DriveError, DatabaseError, ProcessingError) as e:
                logger.error(f"❌ Error processing '{name}': {e}")
                db.record_archive_status(archive_id, name, size, "FAILED")
                try:
                    drive.move_file(archive_id, drive.folder_ids["00-ALL-ARCHIVES"], drive.folder_ids["01-PROCESSING-STAGING"])
                    logger.info(f"    > Rolled back '{name}' to the main queue.")
                except DriveError as rb_e:
                    logger.critical(f"    ❌ CRITICAL: Failed to rollback '{name}': {rb_e}")
            except Exception as e:
                logger.critical(f"An unexpected critical error occurred with '{name}': {e}", exc_info=True)
                db.record_archive_status(archive_id, name, size, "FAILED")

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
Description=Google Takeout Organizer Service (v3.1)
After=network-online.target

[Service]
Type=simple
Environment="GOOGLE_APPLICATION_CREDENTIALS=${CREDENTIALS_PATH_FOR_SERVICE}"
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
