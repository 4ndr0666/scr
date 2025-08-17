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

# Explicitly import Google API client libraries
import google.auth # Import google.auth for default credential discovery
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

# Try to import tqdm for progress bars, fall back to dummy if not available
try:
    from tqdm.auto import tqdm
except ImportError:
    # If tqdm is not available, use a dummy function
    def tqdm(iterable, *args, **kwargs):
        """A dummy tqdm function that acts as a fallback if tqdm is not available."""
        description = kwargs.get("desc", "items")
        logging.info(f"    > Processing {description}...")
        return iterable

# COLAB_ENVIRONMENT flag remains for any potential future Colab-specific *behavior*
# beyond mounting, but the core mounting logic is now fixed for the canonical path.
COLAB_ENVIRONMENT = False
try:
    from google.colab import drive # Attempt import for flag, not for mounting logic
    COLAB_ENVIRONMENT = True
except ImportError:
    pass # Not in Colab environment

# ==============================================================================
# --- 1. CORE CONFIGURATION ---
# ==============================================================================
# Base directory for application data (DB)
APP_BASE_DIR = Path("/opt/google_takeout_organizer")

# Google Drive specific configurations
DRIVE_ROOT_FOLDER_NAME = (
    "TakeoutProject"  # This is the *name* of the root folder on Drive
)
# CREDENTIALS_PATH is now handled by GOOGLE_APPLICATION_CREDENTIALS env var, no longer needed here.

# Local temporary and database paths
DB_PATH = APP_BASE_DIR / "takeout_archive.db"
VM_TEMP_DOWNLOAD_DIR = Path("/tmp/temp_download")  # Directory for downloading archives
VM_TEMP_EXTRACT_DIR = Path(
    "/tmp/temp_extract"
)  # Directory for extracting archive contents
VM_TEMP_BATCH_DIR = Path(
    "/tmp/temp_batch"
)  # Directory for creating smaller repackaged archives

# Processing parameters
REPACKAGE_CHUNK_SIZE_GB = 15  # Size of chunks for repackaging large archives
MAX_SAFE_ARCHIVE_SIZE_GB = (
    25  # Threshold for archives to be considered "large" and require repackaging
)
TARGET_MAX_VM_USAGE_GB = (
    50  # Maximum allowed VM disk usage before critical error (e.g., in Colab)
)
PROCESSING_IDLE_SLEEP_SECONDS = 60 * 5  # Sleep time when no archives are found

# Canonical Google Drive mount point on the VM.
# The 'TakeoutProject' folder is expected to be directly within this.
LOCAL_DRIVE_MOUNT_POINT = Path("/content/drive/MyDrive")


# ==============================================================================
# --- 2. LOGGING SETUP ---
# ==============================================================================
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)], # Logs to stdout, which systemd captures to journalctl
)
logger = logging.getLogger(__name__)


# ==============================================================================
# --- 3. CUSTOM EXCEPTIONS ---
# ==============================================================================
class TakeoutOrganizerError(Exception):
    """Base exception for the Takeout Organizer application."""

    pass


class DriveAuthError(TakeoutOrganizerError):
    """Exception raised for Google Drive authentication errors."""

    pass


class DriveAPIError(TakeoutOrganizerError):
    """Exception raised for Google Drive API errors."""

    pass


class DatabaseError(TakeoutOrganizerError):
    """Exception raised for database-related errors."""

    pass


class ProcessingError(TakeoutOrganizerError):
    """Exception raised for errors during archive processing."""

    pass


# ==============================================================================
# --- 4. GOOGLE DRIVE MANAGER CLASS ---
# ==============================================================================
class DriveManager:
    """Manages interactions with the Google Drive API."""

    def __init__(self, root_folder_name: str):
        """
        Initializes the DriveManager and authenticates with Google Drive.

        Args:
            root_folder_name: The name of the root folder for the project on Google Drive.
        Raises:
            DriveAuthError: If authentication fails.
        """
        self.root_folder_name = root_folder_name
        self.service = self._authenticate_headless()
        self.folder_ids: dict[str, str] = {}  # To store IDs of key folders

    def _authenticate_headless(self):
        """
        Authenticates with Google Drive using a service account (via GOOGLE_APPLICATION_CREDENTIALS).

        Returns:
            A Google Drive API service object.
        Raises:
            DriveAuthError: If authentication fails due to missing credentials or other issues.
        """
        logger.info("--> [Auth] Authenticating with Google Drive service account...")
        scopes = ["https://www.googleapis.com/auth/drive"]
        try:
            # google.auth.default() automatically looks for GOOGLE_APPLICATION_CREDENTIALS
            creds, project = google.auth.default(scopes=scopes)
            if not creds.valid:
                # Refresh token if expired or invalid; for service accounts, this is less common
                # but good practice.
                creds.refresh(google.auth.transport.requests.Request())
            return build("drive", "v3", credentials=creds)
        except Exception as e:
            raise DriveAuthError(
                f"Authentication failed: {e}. Ensure GOOGLE_APPLICATION_CREDENTIALS "
                "environment variable is set and points to a valid service account key file."
            ) from e

    def initialize_folder_structure(self):
        """
        Ensures the required Google Drive folder structure exists and retrieves their IDs.
        Folder structure is managed directly by this class as it's Drive-specific.

        Raises:
            DriveAPIError: If any Google Drive API operation fails.
        """
        logger.info("--> [API] Initializing Google Drive folder structure...")
        try:
            # 1. Find or create the root folder (e.g., "TakeoutProject")
            # We explicitly search for it under 'root' (My Drive)
            query = f"name='{self.root_folder_name}' and 'root' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false"
            response = (
                self.service.files()
                .list(q=query, spaces="drive", fields="files(id)")
                .execute()
            )
            root_files = response.get("files", [])
            if not root_files:
                logger.info(f"    > Creating root folder: {self.root_folder_name}")
                file_metadata = {
                    "name": self.root_folder_name,
                    "mimeType": "application/vnd.google-apps.folder",
                    "parents": ["root"],
                }
                folder = (
                    self.service.files()
                    .create(body=file_metadata, fields="id")
                    .execute()
                )
                root_folder_id = folder.get("id")
            else:
                root_folder_id = root_files[0].get("id")

            self.folder_ids["root"] = root_folder_id
            logger.info(
                f"    ✅ Found/Created root folder: {self.root_folder_name} (ID: {root_folder_id})"
            )

            # 2. Define and create/find sub-folders within the root folder
            folder_structure_map = {
                "00-ALL-ARCHIVES": {},
                "01-PROCESSING-STAGING": {},
                "03-organized": {"My-Photos": {}},
                "04-trash": {"quarantined_artifacts": {}, "duplicates": {}},
                "05-COMPLETED-ARCHIVES": {},
            }

            def _traverse_and_create(parent_id: str, structure: dict):
                for name, substructure in structure.items():
                    query = f"name='{name}' and '{parent_id}' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false"
                    response = (
                        self.service.files().list(q=query, fields="files(id)").execute()
                    )
                    sub_files = response.get("files", [])
                    if sub_files:
                        folder_id = sub_files[0].get("id")
                    else:
                        logger.info(f"    > Creating folder: {name}")
                        file_metadata = {
                            "name": name,
                            "mimeType": "application/vnd.google-apps.folder",
                            "parents": [parent_id],
                        }
                        folder = (
                            self.service.files()
                            .create(body=file_metadata, fields="id")
                            .execute()
                        )
                        folder_id = folder.get("id")
                    self.folder_ids[name] = folder_id
                    if substructure:
                        _traverse_and_create(folder_id, substructure)

            _traverse_and_create(root_folder_id, folder_structure_map)
            logger.info("--> [API] Folder structure synchronized.")
        except HttpError as error:
            raise DriveAPIError(
                f"An API error occurred during folder setup: {error}"
            ) from error
        except Exception as e:
            raise DriveAPIError(
                f"An unexpected error occurred during folder setup: {e}"
            ) from e

    def move_file(self, file_id: str, to_folder_id: str, from_folder_id: str):
        """
        Moves a file from one Google Drive folder to another.

        Args:
            file_id: The ID of the file to move.
            to_folder_id: The ID of the destination folder.
            from_folder_id: The ID of the current parent folder.
        Raises:
            DriveAPIError: If the move operation fails.
        """
        try:
            self.service.files().update(
                fileId=file_id, addParents=to_folder_id, removeParents=from_folder_id
            ).execute()
            logger.debug(
                f"Moved file {file_id} from {from_folder_id} to {to_folder_id}"
            )
        except HttpError as error:
            raise DriveAPIError(f"Failed to move file {file_id}: {error}") from error
        except Exception as e:
            raise DriveAPIError(
                f"An unexpected error occurred while moving file {file_id}: {e}"
            ) from e

    def get_next_archive_for_processing(self, source_folder_id: str) -> dict | None:
        """
        Retrieves the next archive file from the source folder for processing.

        Args:
            source_folder_id: The ID of the folder containing archives to process.
        Returns:
            A dictionary containing file details (id, name, size) or None if no files.
        Raises:
            DriveAPIError: If the API call fails.
        """
        try:
            query = f"'{source_folder_id}' in parents and trashed=false"
            response = (
                self.service.files()
                .list(
                    q=query,
                    orderBy="createdTime",
                    pageSize=1,
                    fields="files(id, name, size)",
                )
                .execute()
            )
            processing_queue = response.get("files", [])
            return processing_queue[0] if processing_queue else None
        except HttpError as error:
            raise DriveAPIError(
                f"Failed to list files in folder {source_folder_id}: {error}"
            ) from error
        except Exception as e:
            raise DriveAPIError(
                f"An unexpected error occurred while listing files: {e}"
            ) from e

    def download_file(self, file_id: str, file_name: str, dest_path: Path) -> Path:
        """
        Downloads a file from Google Drive.

        Args:
            file_id: The ID of the file to download.
            file_name: The name of the file (for local saving).
            dest_path: The directory where the file should be saved.
        Returns:
            The full path to the downloaded file.
        Raises:
            DriveAPIError: If the download fails.
        """
        download_filepath = dest_path / file_name
        logger.info(f"    > Downloading '{file_name}' to {download_filepath}...")
        try:
            request = self.service.files().get_media(fileId=file_id)
            with open(download_filepath, "wb") as fh:
                downloader = self.service._http.request(request.uri)
                response = downloader.next_chunk()
                while response[0]:
                    fh.write(response[0])
                    response = downloader.next_chunk()
            logger.info(f"    ✅ Downloaded '{file_name}'.")
            return download_filepath
        except HttpError as error:
            raise DriveAPIError(
                f"Failed to download file {file_name} (ID: {file_id}): {error}"
            ) from error
        except Exception as e:
            raise DriveAPIError(
                f"An unexpected error occurred during download of {file_name}: {e}"
            ) from e


# ==============================================================================
# --- 5. DATABASE MANAGER CLASS ---
# ==============================================================================
class DatabaseManager:
    """Manages interactions with the SQLite database."""

    def __init__(self, db_path: Path):
        """
        Initializes the DatabaseManager and ensures the database schema exists.

        Args:
            db_path: Path to the SQLite database file.
        Raises:
            DatabaseError: If database initialization fails.
        """
        self.db_path = db_path
        self._initialize_database()

    def _initialize_database(self):
        """
        Connects to the database and creates necessary tables if they don't exist.
        """
        logger.info("--> [DB] Initializing database...")
        try:
            self.db_path.parent.mkdir(
                parents=True, exist_ok=True
            )  # Ensure DB directory exists
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                # Table for tracking processed Takeout archives themselves
                cursor.execute(
                    """
                    CREATE TABLE IF NOT EXISTS archives (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        drive_id TEXT UNIQUE NOT NULL,
                        name TEXT NOT NULL,
                        size_bytes INTEGER,
                        status TEXT NOT NULL, -- e.g., 'PENDING', 'STAGING', 'COMPLETED', 'FAILED'
                        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                        processed_at TEXT
                    )
                """
                )
                # Table for tracking individual files extracted from archives
                cursor.execute(
                    """
                    CREATE TABLE IF NOT EXISTS extracted_files (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        sha256_hash TEXT NOT NULL UNIQUE,
                        original_path TEXT NOT NULL, -- Path relative to the archive root (e.g., Takeout/Google Photos/photo.jpg)
                        final_path TEXT,            -- Full path in the organized Google Drive folder
                        timestamp INTEGER,          -- Unix timestamp (e.g., photoTakenTime for photos)
                        file_size INTEGER NOT NULL,
                        source_archive_name TEXT NOT NULL -- Name of the archive it came from (e.g., takeout-20231027T123456Z-001.zip)
                    )
                """
                )
                conn.commit()
            logger.info("    ✅ Database ready.")
        except sqlite3.Error as e:
            raise DatabaseError(
                f"Failed to initialize database at {self.db_path}: {e}"
            ) from e
        except Exception as e:
            raise DatabaseError(
                f"An unexpected error occurred during DB initialization: {e}"
            ) from e

    def record_archive_status(
        self, drive_id: str, name: str, size_bytes: int, status: str
    ):
        """
        Records or updates the status of a Takeout archive in the database.

        Args:
            drive_id: Google Drive ID of the archive.
            name: Name of the archive file.
            size_bytes: Size of the archive in bytes.
            status: Current status (e.g., 'PENDING', 'STAGING', 'COMPLETED', 'FAILED').
        Raises:
            DatabaseError: If the database operation fails.
        """
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                cursor.execute(
                    """
                    INSERT INTO archives (drive_id, name, size_bytes, status, processed_at)
                    VALUES (?, ?, ?, ?, ?)
                    ON CONFLICT(drive_id) DO UPDATE SET
                        status = ?,
                        processed_at = CASE WHEN ? IN ('COMPLETED', 'FAILED') THEN CURRENT_TIMESTAMP ELSE processed_at END
                    """,
                    (
                        drive_id,
                        name,
                        size_bytes,
                        status,
                        (
                            datetime.now().isoformat()
                            if status in ["COMPLETED", "FAILED"]
                            else None
                        ),
                        status,
                        status,
                    ),
                )
                conn.commit()
                logger.debug(
                    f"DB: Archive {name} ({drive_id}) status updated to {status}"
                )
        except sqlite3.Error as e:
            raise DatabaseError(
                f"Failed to record archive status for {drive_id}: {e}"
            ) from e

    def get_archive_status(self, drive_id: str) -> str | None:
        """
        Retrieves the status of an archive from the database.

        Args:
            drive_id: Google Drive ID of the archive.
        Returns:
            The status string or None if not found.
        Raises:
            DatabaseError: If the database operation fails.
        """
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                cursor.execute(
                    "SELECT status FROM archives WHERE drive_id = ?", (drive_id,)
                )
                result = cursor.fetchone()
                return result[0] if result else None
        except sqlite3.Error as e:
            raise DatabaseError(
                f"Failed to retrieve archive status for {drive_id}: {e}"
            ) from e

    def get_existing_file_hashes(self) -> set[str]:
        """
        Retrieves all SHA256 hashes of files already recorded in the database.

        Returns:
            A set of SHA256 hash strings.
        Raises:
            DatabaseError: If the database operation fails.
        """
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                cursor.execute("SELECT sha256_hash FROM extracted_files")
                return {row[0] for row in cursor.fetchall()}
        except sqlite3.Error as e:
            raise DatabaseError(f"Failed to retrieve existing file hashes: {e}") from e

    def get_processed_files_for_archive(self, archive_name: str) -> set[str]:
        """
        Retrieves original paths of files already processed and given a final_path
        for a specific archive. Used for rsync-like delta processing.

        Args:
            archive_name: The name of the source archive (e.g., takeout-...).
        Returns:
            A set of original_path strings.
        Raises:
            DatabaseError: If the database operation fails.
        """
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                cursor.execute(
                    "SELECT original_path FROM extracted_files WHERE source_archive_name = ? AND final_path IS NOT NULL",
                    (archive_name,),
                )
                return {row[0] for row in cursor.fetchall()}
        except sqlite3.Error as e:
            raise DatabaseError(
                f"Failed to retrieve processed files for archive {archive_name}: {e}"
            ) from e

    def insert_extracted_file(
        self,
        sha256_hash: str,
        original_path: str,
        file_size: int,
        source_archive_name: str,
    ):
        """
        Inserts a new extracted file record into the database.

        Args:
            sha256_hash: SHA256 hash of the file.
            original_path: Path of the file relative to the archive.
            file_size: Size of the file in bytes.
            source_archive_name: Name of the archive the file came from.
        Raises:
            DatabaseError: If the database operation fails.
        """
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                cursor.execute(
                    """
                    INSERT INTO extracted_files (sha256_hash, original_path, file_size, source_archive_name)
                    VALUES (?, ?, ?, ?)
                    """,
                    (sha256_hash, original_path, file_size, source_archive_name),
                )
                conn.commit()
        except sqlite3.Error as e:
            # Handle unique constraint violation gracefully, if needed for retries
            if "UNIQUE constraint failed" in str(e):
                logger.debug(
                    f"File with hash {sha256_hash} already exists in DB. Skipping insert."
                )
            else:
                raise DatabaseError(
                    f"Failed to insert extracted file record for {original_path}: {e}"
                ) from e

    def update_extracted_file_final_path(
        self,
        original_path: str,
        source_archive_name: str,
        final_path: Path,
        timestamp: int | None = None,
    ):
        """
        Updates the final path and optionally timestamp for an extracted file.

        Args:
            original_path: Original path of the file relative to the archive.
            source_archive_name: Name of the archive the file came from.
            final_path: The new final path of the file in the organized storage.
            timestamp: Optional Unix timestamp for the file.
        Raises:
            DatabaseError: If the database operation fails.
        """
        try:
            with sqlite3.connect(self.db_path) as conn:
                cursor = conn.cursor()
                if timestamp is not None:
                    cursor.execute(
                        """
                        UPDATE extracted_files SET final_path = ?, timestamp = ?
                        WHERE original_path = ? AND source_archive_name = ?
                        """,
                        (
                            str(final_path),
                            timestamp,
                            original_path,
                            source_archive_name,
                        ),
                    )
                else:
                    cursor.execute(
                        """
                        UPDATE extracted_files SET final_path = ?
                        WHERE original_path = ? AND source_archive_name = ?
                        """,
                        (str(final_path), original_path, source_archive_name),
                    )
                conn.commit()
        except sqlite3.Error as e:
            raise DatabaseError(
                f"Failed to update final path for {original_path}: {e}"
            ) from e


# ==============================================================================
# --- 6. ARCHIVE PROCESSING CLASS ---
# ==============================================================================
class ArchiveProcessor:
    """Handles the core logic of processing Google Takeout archives."""

    def __init__(
        self,
        drive_manager: DriveManager,
        db_manager: DatabaseManager,
    ):
        self.drive_manager = drive_manager
        self.db_manager = db_manager

        # Canonical local paths for temp and organized files
        self.temp_download_dir = VM_TEMP_DOWNLOAD_DIR
        self.temp_extract_dir = VM_TEMP_EXTRACT_DIR
        self.temp_batch_dir = VM_TEMP_BATCH_DIR

        # The base path for organized files on the local mount.
        # This assumes DRIVE_ROOT_FOLDER_NAME ("TakeoutProject") is a folder *within* LOCAL_DRIVE_MOUNT_POINT.
        self.drive_root_local_path = LOCAL_DRIVE_MOUNT_POINT / DRIVE_ROOT_FOLDER_NAME

        # Construct paths using the canonical folder names
        self.organized_photos_dir = self.drive_root_local_path / "03-organized" / "My-Photos"
        self.organized_files_dir = self.drive_root_local_path / "03-organized" # General organized files
        self.quarantine_dir = self.drive_root_local_path / "04-trash" / "quarantined_artifacts"
        self.duplicates_dir = self.drive_root_local_path / "04-trash" / "duplicates"

        # Ensure all necessary local directories exist for temporary operations
        self.temp_download_dir.mkdir(parents=True, exist_ok=True)
        self.temp_extract_dir.mkdir(parents=True, exist_ok=True)
        self.temp_batch_dir.mkdir(parents=True, exist_ok=True)

        # Ensure all necessary final destination directories exist on the mounted drive
        # These will create directories within /content/drive/MyDrive/TakeoutProject/...
        self.organized_photos_dir.mkdir(parents=True, exist_ok=True)
        self.organized_files_dir.mkdir(parents=True, exist_ok=True)
        self.quarantine_dir.mkdir(parents=True, exist_ok=True)
        self.duplicates_dir.mkdir(parents=True, exist_ok=True)


    def _cleanup_temp_dirs(self):
        """Cleans up all temporary local directories."""
        for temp_dir in [
            self.temp_download_dir,
            self.temp_extract_dir,
            self.temp_batch_dir,
        ]:
            if temp_dir.exists():
                shutil.rmtree(temp_dir)
                logger.debug(f"Cleaned up temporary directory: {temp_dir}")
            temp_dir.mkdir(parents=True, exist_ok=True)  # Recreate empty for next cycle

    def perform_startup_integrity_check(self):
        """Performs a "Power-On Self-Test" to detect and correct inconsistent states."""
        logger.info("--> [POST] Performing startup integrity check...")
        staging_folder_id = self.drive_manager.folder_ids["01-PROCESSING-STAGING"]
        source_folder_id = self.drive_manager.folder_ids["00-ALL-ARCHIVES"]

        try:
            # Check for files left in the Drive staging folder
            staged_files_resp = (
                self.drive_manager.service.files()
                .list(
                    q=f"'{staging_folder_id}' in parents and trashed=false",
                    fields="files(id, name)",
                )
                .execute()
            )
            staged_files = staged_files_resp.get("files", [])

            if staged_files:
                logger.warning(
                    f"    ⚠️ Found {len(staged_files)} orphaned files in Google Drive's 01-PROCESSING-STAGING. Rolling back..."
                )
                for staged_file in staged_files:
                    file_id = staged_file.get("id")
                    file_name = staged_file.get("name")
                    self.drive_manager.move_file(
                        file_id, source_folder_id, staging_folder_id
                    )
                    # Update DB status if it was stuck
                    # Note: We don't have size here, so we update existing entry or add minimal
                    self.db_manager.record_archive_status(
                        file_id, file_name, 0, "PENDING"
                    )
                    logger.info(
                        f"        > Rolled back '{file_name}' to 00-ALL-ARCHIVES."
                    )
                logger.info("    ✅ Google Drive rollback complete.")
            else:
                logger.info("    ✅ No orphaned files found in Google Drive staging.")

            # Clean up local temporary directories
            self._cleanup_temp_dirs()
            logger.info("    ✅ Local temporary directories cleaned.")

        except (DriveAPIError, DatabaseError) as e:
            logger.error(f"❌ Error during startup integrity check: {e}")
            raise  # Re-raise to halt execution if POST fails critically
        logger.info("--> [POST] Integrity check complete.")

    def plan_and_repackage_archive(self, archive_path: Path, archive_name: str):
        """
        Scans a large archive, hashes unique files, and repackages them into smaller,
        crash-resilient parts while populating the database.
        Args:
            archive_path: The local path to the large archive file.
            archive_name: The name of the original archive.
        Returns:
            True if repackaging was successful, False otherwise.
        Raises:
            ProcessingError: If repackaging fails.
        """
        original_basename_no_ext = archive_name.split(".")[
            0
        ]  # e.g., 'takeout-20231027T123456Z'
        logger.info(f"--> Repackaging & Indexing '{archive_name}'...")

        repackage_chunk_size_bytes = REPACKAGE_CHUNK_SIZE_GB * (1024**3)
        existing_hashes = self.db_manager.get_existing_file_hashes()
        logger.info(f"    > Index loaded with {len(existing_hashes)} file records.")

        # Check for existing partial archives in the completed folder on Drive
        completed_folder_id = self.drive_manager.folder_ids["05-COMPLETED-ARCHIVES"]
        part_query = f"name contains '{original_basename_no_ext}.part-' and '{completed_folder_id}' in parents and trashed=false"
        response = (
            self.drive_manager.service.files()
            .list(q=part_query, fields="files(name)")
            .execute()
        )
        existing_parts_on_drive = {f.get("name") for f in response.get("files", [])}

        last_part_num = 0
        if existing_parts_on_drive:
            part_numbers = [
                int(re.search(r"\.part-(\d+)\.tgz", f).group(1))
                for f in existing_parts_on_drive
                if re.search(r"\.part-(\d+)\.tgz", f)
            ]
            if part_numbers:
                last_part_num = max(part_numbers)
            logger.info(f"    ✅ Resuming repackaging from part {last_part_num + 1}.")

        try:
            batches: list[list[tarfile.TarInfo]] = []
            current_batch: list[tarfile.TarInfo] = []
            current_batch_size = 0

            with tarfile.open(archive_path, "r:gz") as original_tar:
                all_members = [m for m in original_tar.getmembers() if m.isfile()]
                if not all_members:
                    logger.warning(
                        f"    > Archive '{archive_name}' is empty or contains no files. Skipping repackaging."
                    )
                    return True  # Nothing to repackage

                for member in all_members:
                    # If adding this member exceeds chunk size, start a new batch
                    if (
                        current_batch
                        and (current_batch_size + member.size)
                        > repackage_chunk_size_bytes
                    ):
                        batches.append(current_batch)
                        current_batch, current_batch_size = [], 0
                    current_batch.append(member)
                    current_batch_size += member.size
                if current_batch:  # Add the last batch
                    batches.append(current_batch)

            logger.info(
                f"    > Plan complete: {len(all_members)} files -> up to {len(batches)} new archives."
            )

            for i, batch in enumerate(batches):
                part_number = i + 1
                new_archive_name = (
                    f"{original_basename_no_ext}.part-{part_number:02d}.tgz"
                )

                # Check if this part already exists on Drive
                if new_archive_name in existing_parts_on_drive:
                    logger.info(
                        f"    > Part {new_archive_name} already exists on Drive. Skipping."
                    )
                    continue

                # Skip parts already completed from a previous run if resuming
                if part_number <= last_part_num:
                    logger.info(
                        f"    > Skipping part {part_number} (already processed in a previous session)."
                    )
                    continue

                self.temp_batch_dir.mkdir(
                    parents=True, exist_ok=True
                )  # Ensure it exists
                temp_batch_archive_path = (
                    self.temp_batch_dir / new_archive_name
                )  # Use Path object

                files_in_this_batch = 0
                with tarfile.open(temp_batch_archive_path, "w:gz") as temp_tar:
                    with tarfile.open(
                        archive_path, "r:gz"
                    ) as original_tar_stream:  # Re-open for stream reading
                        for member in tqdm(
                            batch, desc=f"Hashing & Staging Batch {part_number}"
                        ):
                            file_obj = original_tar_stream.extractfile(member)
                            if not file_obj:
                                logger.warning(
                                    f"Failed to extract file object for {member.name}. Skipping."
                                )
                                continue

                            # Hash and check for duplicates
                            hasher = hashlib.sha256()
                            for chunk in iter(lambda: file_obj.read(4096), b""):
                                hasher.update(chunk)
                            sha256 = hasher.hexdigest()

                            if sha256 in existing_hashes:
                                logger.debug(
                                    f"File {member.name} (hash {sha256}) already exists. Skipping add to new archive."
                                )
                                continue

                            # If unique, add to the new small archive and record in DB
                            file_obj.seek(0)  # Reset stream position after hashing
                            temp_tar.addfile(member, file_obj)
                            self.db_manager.insert_extracted_file(
                                sha256, member.name, member.size, archive_name
                            )
                            existing_hashes.add(sha256)  # Add to our in-memory set
                            files_in_this_batch += 1

                if files_in_this_batch > 0:
                    # Upload the newly created part to Drive's 05-COMPLETED-ARCHIVES
                    logger.info(
                        f"    --> Batch contains {files_in_this_batch} unique files. Uploading new part {part_number} to Google Drive..."
                    )
                    file_metadata = {
                        "name": new_archive_name,
                        "parents": [
                            completed_folder_id
                        ],  # Upload directly to completed
                    }
                    media_body = {
                        "mimeType": "application/gzip",  # Or 'application/x-tar' depending on content
                        "body": temp_batch_archive_path.open(
                            "rb"
                        ),  # Pass file object for direct upload
                    }
                    self.drive_manager.service.files().create(
                        body=file_metadata, media_body=media_body, fields="id"
                    ).execute()
                    logger.info(f"    ✅ Uploaded part {new_archive_name}.")
                else:
                    logger.info(
                        f"    > Batch {part_number} contained no unique files. Discarding empty batch."
                    )
            return True # Indicate successful repackaging
        except Exception as e:
            raise ProcessingError(
                f"Error during repackaging of '{archive_name}': {e}"
            ) from e
        finally:
            self._cleanup_temp_dirs()  # Clean up temp directories after each large archive process

    def process_regular_archive(self, archive_path: Path, archive_name: str):
        """
        Handles a regular-sized archive with Rsync-like file-level resumption by checking the DB
        for already processed files and only unpacking the missing ones ("the delta").

        Args:
            archive_path: The local path to the archive file.
            archive_name: The name of the archive.
        Returns:
            True if processing was successful, False otherwise.
        Raises:
            ProcessingError: If processing fails.
        """
        logger.info(f"\n--> [Step 2a] Processing transaction for '{archive_name}'...")
        try:
            logger.info("    > Checking database for previously completed files...")
            # Files that have been unpacked AND moved to their final destination
            completed_files_original_paths = (
                self.db_manager.get_processed_files_for_archive(archive_name)
            )

            if completed_files_original_paths:
                logger.info(
                    f"    ✅ Found {len(completed_files_original_paths)} files previously processed for this archive."
                )
            else:
                logger.info(
                    "    > No previously processed files found for this archive."
                )

            self.temp_extract_dir.mkdir(parents=True, exist_ok=True)

            files_to_unpack_and_process = []
            with tarfile.open(archive_path, "r:gz") as tf:
                all_members = [m for m in tf.getmembers() if m.isfile()]
                if not all_members:
                    logger.warning(
                        f"    > Archive '{archive_name}' is empty or contains no files. Skipping processing."
                    )
                    return True  # Nothing to process

                for member in tqdm(
                    all_members, desc=f"Scanning & Unpacking Delta for {archive_name}"
                ):
                    # Check if the file's original_path (relative to archive root) is already processed
                    if member.name not in completed_files_original_paths:
                        # Google Takeout generally has a 'Takeout' root, so we should extract with original hierarchy.
                        # `tf.extract` handles directory traversal attacks internally for member names.
                        tf.extract(member, path=self.temp_extract_dir, set_attrs=False)
                        files_to_unpack_and_process.append(member.name)
                        # The initial insert into DB for truly unique files will happen in deduplicate_files/organize_photos.

            if not files_to_unpack_and_process:
                logger.info(
                    "    ✅ All files in this archive were already processed. Finalizing."
                )
                return True

            logger.info(
                f"    ✅ Unpacked {len(files_to_unpack_and_process)} new/missing files to VM for '{archive_name}'."
            )

            # Subsequent steps now operate on the extracted files in VM_TEMP_EXTRACT_DIR.
            # These functions will hash and update the DB, and move files to final locations.
            # Note: The Google Photos directory is typically `VM_TEMP_EXTRACT_DIR/Takeout/Google Photos`
            # Other files are often in `VM_TEMP_EXTRACT_DIR/Takeout/...`
            google_photos_source_path = (
                self.temp_extract_dir / "Takeout" / "Google Photos"
            )
            if google_photos_source_path.exists():
                self.organize_photos(
                    google_photos_source_path, self.organized_photos_dir, archive_name
                )

            # Deduplicate and move other unique files
            takeout_other_files_source_path = self.temp_extract_dir / "Takeout"
            if takeout_other_files_source_path.exists():
                self.deduplicate_files(
                    takeout_other_files_source_path,
                    self.organized_files_dir,
                    archive_name,
                )
            return True # Indicate successful processing
        except Exception as e:
            raise ProcessingError(
                f"Error during archive processing transaction for '{archive_name}': {e}"
            ) from e
        finally:
            self._cleanup_temp_dirs()  # Clean up temporary VM directory

    def deduplicate_files(
        self, source_path: Path, primary_storage_path: Path, source_archive_name: str
    ):
        """
        Deduplicates new files against the primary storage and updates the database for unique files.
        This focuses on files that are NOT photos (photos are handled by organize_photos).

        Args:
            source_path: The temporary directory where the archive content was extracted.
            primary_storage_path: The final destination for unique files (e.g., 03-organized).
            source_archive_name: The name of the archive the files came from.
        Raises:
            ProcessingError: If deduplication or file moving fails.
        """
        logger.info("\n--> [Step 2b] Deduplicating new files...")

        # Ensure target directories exist (already done in __init__ but harmless to re-check)
        primary_storage_path.mkdir(parents=True, exist_ok=True)
        self.duplicates_dir.mkdir(parents=True, exist_ok=True)

        jdupes_path = shutil.which("jdupes")
        if not jdupes_path:
            logger.warning(
                "    ⚠️ 'jdupes' command not found. Skipping deduplication. Please ensure it is installed."
            )
            # Fallback: Just move files without deduplication, assuming they are unique.
            logger.info("    > Moving files without deduplication...")
            for root, _, files in os.walk(source_path):
                for filename in files:
                    file_loc_path = Path(root) / filename
                    # Construct relative path from the original extracted root
                    relative_path = file_loc_path.relative_to(self.temp_extract_dir)
                    final_file_path = primary_storage_path / relative_path

                    try:
                        final_file_path.parent.mkdir(parents=True, exist_ok=True)
                        shutil.move(file_loc_path, final_file_path)
                        # Record in DB - need hash, so calculate it.
                        with open(final_file_path, "rb") as f:
                            sha256 = hashlib.sha256(f.read()).hexdigest()
                        self.db_manager.insert_extracted_file(
                            sha256,
                            str(relative_path),
                            final_file_path.stat().st_size,
                            source_archive_name,
                        )
                        self.db_manager.update_extracted_file_final_path(
                            str(relative_path), source_archive_name, final_file_path
                        )
                    except Exception as e:
                        logger.error(
                            f"Failed to move or record {file_loc_path} during fallback: {e}"
                        )
            return

        try:
            # Use a list for subprocess.run for security, especially with paths that might contain spaces
            # `jdupes -r` (recurse), `-S` (print size), `-nh` (no hardlinks for identified duplicates, which move handles),
            # `--linkhard` (create hardlinks for identical files within a single scan, not across scans)
            # `--move=DEST` (move duplicates to DEST, leave first copy)
            command = [
                str(jdupes_path),
                "-r",
                "-S",
                "-nh",
                f"--move={self.duplicates_dir}",
                str(source_path),  # Scan the extracted takeout content
                str(primary_storage_path),  # Scan the existing organized storage
            ]
            result = subprocess.run(command, capture_output=True, text=True, check=True)
            logger.debug(f"Jdupes stdout:\n{result.stdout}")
            if result.stderr:
                logger.warning(f"Jdupes stderr:\n{result.stderr}")

            # After jdupes, remaining files in source_path are unique to this archive and not duplicates of existing
            # files in primary_storage_path, or they are the "first" copy of a newly identified duplicate set.
            # We move them to primary storage and record in DB.
            files_moved_count = 0
            for root, _, files in os.walk(source_path):
                for filename in files:
                    file_loc_path = Path(root) / filename
                    # Construct relative path from the original extracted root
                    relative_path = file_loc_path.relative_to(self.temp_extract_dir)
                    final_file_path = primary_storage_path / relative_path

                    final_file_path.parent.mkdir(parents=True, exist_ok=True)
                    shutil.move(file_loc_path, final_file_path)

                    # Calculate hash and record in DB
                    with open(final_file_path, "rb") as f:
                        sha256 = hashlib.sha256(f.read()).hexdigest()

                    self.db_manager.insert_extracted_file(
                        sha256,
                        str(relative_path),
                        final_file_path.stat().st_size,
                        source_archive_name,
                    )
                    self.db_manager.update_extracted_file_final_path(
                        str(relative_path), source_archive_name, final_file_path
                    )
                    files_moved_count += 1

            logger.info(
                f"    ✅ Deduplication and move complete. Processed {files_moved_count} unique files."
            )
        except subprocess.CalledProcessError as e:
            raise ProcessingError(f"jdupes command failed: {e.stderr}") from e
        except Exception as e:
            raise ProcessingError(f"Error during deduplication: {e}") from e

    def organize_photos(
        self, source_path: Path, final_dir: Path, source_archive_name: str
    ):
        """
        Organizes photos based on their metadata (preferably JSON sidecar files)
        and updates their final path and timestamp in the database.

        Args:
            source_path: The temporary directory containing Google Photos (e.g., /tmp/temp_extract/Takeout/Google Photos).
            final_dir: The final destination for organized photos (e.g., /content/drive/MyDrive/TakeoutProject/03-organized/My-Photos).
            source_archive_name: The name of the archive the files came from.
        Raises:
            ProcessingError: If photo organization fails.
        """
        logger.info("\n--> [Step 2c] Organizing photos...")
        photos_organized_count = 0

        if not source_path.is_dir():
            logger.info(
                f"    > '{source_path}' directory not found. Skipping photo organization."
            )
            return

        final_dir.mkdir(parents=True, exist_ok=True)

        all_media_files = []
        for root, _, files in os.walk(source_path):
            for f in files:
                file_path = Path(root) / f
                if file_path.suffix.lower() not in [
                    ".jpg",
                    ".jpeg",
                    ".png",
                    ".gif",
                    ".mp4",
                    ".mov",
                    ".webp",
                ] and not file_path.name.lower().endswith(
                    ".json"
                ):  # Process JSON later
                    continue
                all_media_files.append(file_path)

        for media_path in tqdm(all_media_files, desc="Organizing photos"):
            if media_path.suffix.lower() == ".json":
                continue  # Skip JSON files for now, process them with their media

            json_path = media_path.with_suffix(media_path.suffix + ".json")
            if not json_path.exists():
                json_path = media_path.with_suffix(".json")  # Try without double suffix

            timestamp = None
            if json_path.exists():
                try:
                    with open(json_path, "r", encoding="utf-8") as f:
                        data = json.load(f)
                    ts = data.get("photoTakenTime", {}).get("timestamp")
                    if ts:
                        timestamp = int(ts)
                except Exception as e:
                    logger.warning(f"Failed to parse JSON for {media_path}: {e}")

            if (
                timestamp is None
            ):  # Fallback to file creation/modification time if no JSON timestamp
                try:
                    timestamp = int(media_path.stat().st_mtime)  # Use modification time
                except Exception as e:
                    logger.warning(f"Could not get timestamp for {media_path}: {e}")
                    continue  # Skip if no timestamp can be determined

            dt_object = datetime.fromtimestamp(timestamp)
            new_name_base = dt_object.strftime("%Y-%m-%d_%Hh%Mm%Ss")
            ext = media_path.suffix.lower()

            new_filename = f"{new_name_base}{ext}"
            counter = 0
            # Ensure unique filename in the destination directory
            while (final_dir / new_filename).exists():
                counter += 1
                new_filename = f"{new_name_base}_{counter:02d}{ext}"

            final_filepath = final_dir / new_filename

            try:
                # Calculate SHA256 before moving to record in DB
                with open(media_path, "rb") as f:
                    sha256 = hashlib.sha256(f.read()).hexdigest()

                # Construct relative path from the original extracted root
                relative_original_path = media_path.relative_to(self.temp_extract_dir)

                # First insert the file, then update its final_path and timestamp
                self.db_manager.insert_extracted_file(
                    sha256,
                    str(relative_original_path),
                    media_path.stat().st_size,
                    source_archive_name,
                )
                self.db_manager.update_extracted_file_final_path(
                    str(relative_original_path),
                    source_archive_name,
                    final_filepath,
                    timestamp,
                )

                shutil.move(media_path, final_filepath)  # Move the media file
                if json_path.exists():
                    os.remove(json_path)  # Remove the associated JSON file after use

                photos_organized_count += 1
            except Exception as e:
                logger.error(f"Failed to organize photo {media_path}: {e}")
                # Optionally move failed files to quarantine_dir
                try:
                    self.quarantine_dir.mkdir(parents=True, exist_ok=True)
                    shutil.move(media_path, self.quarantine_dir / media_path.name)
                except Exception as qc_e:
                    logger.critical(
                        f"Failed to quarantine problematic photo {media_path}: {qc_e}"
                    )
                continue

        logger.info(
            f"    ✅ Organized and updated DB for {photos_organized_count} new photos."
        )


# ==============================================================================
# --- MAIN EXECUTION SCRIPT ---
# ==============================================================================
def main():
    """
    Main function to orchestrate the Google Takeout archive processing workflow.
    """
    # Argparse is kept for potential future arguments, but --google-drive-mount-point is removed
    # as the path is now canonical and hardcoded.
    parser = argparse.ArgumentParser(
        description="Process Google Takeout archives via the Google Drive API."
    )
    args = parser.parse_args() # Parse any future arguments

    logger.info("--> [Step 0] Initializing environment...")

    # Ensure application base directory exists
    APP_BASE_DIR.mkdir(parents=True, exist_ok=True)

    drive_manager: DriveManager | None = None
    db_manager: DatabaseManager | None = None
    processor: ArchiveProcessor | None = None

    try:
        # 0.1 Check for Google Drive mount point existence
        if not LOCAL_DRIVE_MOUNT_POINT.exists():
            # This is a critical error for the application to proceed
            raise TakeoutOrganizerError(
                f"Critical Error: Google Drive mount point '{LOCAL_DRIVE_MOUNT_POINT}' not found. "
                "Ensure your Google Drive is mounted to this canonical path (e.g., in Google Colab or via rclone)."
            )
        logger.info(f"✅ Confirmed Google Drive mount point exists at: {LOCAL_DRIVE_MOUNT_POINT}")
        logger.info(f"    Application will use '{LOCAL_DRIVE_MOUNT_POINT / DRIVE_ROOT_FOLDER_NAME}' for organized files.")

        # 0.2 Initialize Managers
        drive_manager = DriveManager(DRIVE_ROOT_FOLDER_NAME) # No credentials_path needed
        drive_manager.initialize_folder_structure()  # Populates drive_manager.folder_ids

        db_manager = DatabaseManager(DB_PATH)

        # 0.3 Initialize Archive Processor (needs managers)
        processor = ArchiveProcessor(
            drive_manager=drive_manager,
            db_manager=db_manager,
        )

        # 0.4 Pre-flight disk space check (relevant for VMs to prevent out-of-disk errors)
        total_vm_bytes, used_vm_bytes, free_vm_bytes = shutil.disk_usage(
            "/"
        )  # Check root filesystem
        used_vm_gb = used_vm_bytes / (1024**3)
        if used_vm_gb > TARGET_MAX_VM_USAGE_GB:
            raise TakeoutOrganizerError(
                f"Initial VM disk usage ({used_vm_gb:.2f} GB) is too high (> {TARGET_MAX_VM_USAGE_GB} GB). "
                "Please free up space or restart the runtime."
            )
        logger.info(
            f"✅ Pre-flight disk check passed. (Initial VM Usage: {used_vm_gb:.2f} GB)"
        )

        # 0.5 jdupes is assumed to be installed by the setup script. No check/install here.

        # 0.6 Perform integrity check (rollback if necessary)
        processor.perform_startup_integrity_check()

        logger.info("✅ Pre-flight checks passed. Workspace ready.")

        # --- Main Processing Loop ---
        while True:
            logger.info("\n--> [Step 1] Identifying unprocessed archives...")
            source_folder_id = drive_manager.folder_ids["00-ALL-ARCHIVES"]

            archive_to_process = drive_manager.get_next_archive_for_processing(
                source_folder_id
            )

            if not archive_to_process:
                logger.info(
                    f"\n✅🎉 All archives have been processed! Idling for {PROCESSING_IDLE_SLEEP_SECONDS} seconds..."
                )
                time.sleep(PROCESSING_IDLE_SLEEP_SECONDS)
                continue  # Continue the loop to check again

            archive_name = archive_to_process.get("name")
            archive_id = archive_to_process.get("id")
            archive_size_bytes = int(archive_to_process.get("size", 0))
            archive_size_gb = archive_size_bytes / (1024**3)

            logger.info(
                f"--> Selected '{archive_name}' for processing (Size: {archive_size_gb:.2f} GB)."
            )

            # Record initial status in DB
            db_manager.record_archive_status(
                archive_id, archive_name, archive_size_bytes, "PENDING"
            )

            logger.info(f"--> Locking and staging '{archive_name}'...")
            try:
                # Move archive on Drive to STAGING
                drive_manager.move_file(
                    archive_id,
                    drive_manager.folder_ids["01-PROCESSING-STAGING"],
                    source_folder_id,
                )
                db_manager.record_archive_status(
                    archive_id, archive_name, archive_size_bytes, "STAGING"
                )
                logger.info(
                    f"    ✅ Staged '{archive_name}' to 01-PROCESSING-STAGING on Google Drive."
                )

                # Download the archive to local VM temp directory
                downloaded_archive_path = drive_manager.download_file(
                    archive_id, archive_name, VM_TEMP_DOWNLOAD_DIR
                )

                processed_ok = False # Flag to track success of processing
                # Determine processing strategy
                if archive_size_gb > MAX_SAFE_ARCHIVE_SIZE_GB:
                    logger.info(
                        f"    > Archive '{archive_name}' is large ({archive_size_gb:.2f} GB). Repackaging..."
                    )
                    processed_ok = processor.plan_and_repackage_archive(
                        downloaded_archive_path, archive_name
                    )
                else:
                    logger.info(
                        f"    > Archive '{archive_name}' is regular size ({archive_size_gb:.2f} GB). Processing directly..."
                    )
                    processed_ok = processor.process_regular_archive(
                        downloaded_archive_path, archive_name
                    )

                if processed_ok:
                    logger.info(f"--> Committing transaction for '{archive_name}'...")
                    # Move archive on Drive to COMPLETED
                    drive_manager.move_file(
                        archive_id,
                        drive_manager.folder_ids["05-COMPLETED-ARCHIVES"],
                        drive_manager.folder_ids["01-PROCESSING-STAGING"],
                    )
                    db_manager.record_archive_status(
                        archive_id, archive_name, archive_size_bytes, "COMPLETED"
                    )
                    logger.info("    ✅ Transaction committed.")
                else:
                    # This branch should ideally not be reached if methods raise exceptions on failure.
                    logger.warning(
                        f"    ❌ Processing failed for '{archive_name}'. Moving to trash (quarantined_artifacts)."
                    )
                    # Move archive on Drive to TRASH
                    drive_manager.move_file(
                        archive_id,
                        drive_manager.folder_ids[
                            "04-trash"
                        ],
                        drive_manager.folder_ids["01-PROCESSING-STAGING"],
                    )
                    db_manager.record_archive_status(
                        archive_id, archive_name, archive_size_bytes, "FAILED"
                    )

            except (DriveAPIError, DatabaseError, ProcessingError) as e:
                logger.error(f"❌ Error during processing of '{archive_name}': {e}")
                # Attempt to roll back the archive on Drive if it's still in STAGING
                try:
                    # Re-query the staging folder to ensure the file is still there before attempting to move back
                    staged_file_check = drive_manager.get_next_archive_for_processing(
                        drive_manager.folder_ids["01-PROCESSING-STAGING"]
                    )
                    if staged_file_check and staged_file_check.get("id") == archive_id:
                        logger.info(
                            f"    > Attempting to move '{archive_name}' back to 00-ALL-ARCHIVES due to error."
                        )
                        drive_manager.move_file(
                            archive_id,
                            source_folder_id,
                            drive_manager.folder_ids["01-PROCESSING-STAGING"],
                        )
                        db_manager.record_archive_status(
                            archive_id, archive_name, archive_size_bytes, "PENDING"
                        )
                    else:
                        logger.warning(
                            f"    > Archive '{archive_name}' not found in STAGING folder. Cannot move back. It might be lost or already moved."
                        )
                except Exception as rollback_e:
                    logger.critical(
                        f"    ❌ CRITICAL: Failed to rollback or move '{archive_name}' after error: {rollback_e}"
                    )
                db_manager.record_archive_status(
                    archive_id, archive_name, archive_size_bytes, "FAILED"
                )
            finally:
                # Ensure local temp directories are cleaned up after each archive cycle
                if processor: # Check if processor was initialized
                    processor._cleanup_temp_dirs()
                    logger.debug(
                        "Cleaned up local temp directories after archive cycle."
                    )

            logger.info("\n--- WORKFLOW CYCLE COMPLETE. ---")

    except TakeoutOrganizerError as e:
        logger.critical(f"\n❌ A CRITICAL APPLICATION ERROR OCCURRED: {e}")
        logger.critical(traceback.format_exc())
        sys.exit(1)
    except Exception as e:
        logger.critical(f"\n❌ AN UNEXPECTED CRITICAL ERROR OCCURRED: {e}")
        logger.critical(traceback.format_exc())
        sys.exit(1)
    finally:
        logger.info("--> Application shutdown complete.")


if __name__ == "__main__":
    main()
