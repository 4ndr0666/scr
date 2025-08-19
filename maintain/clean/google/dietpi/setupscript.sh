#!/bin/bash
set -e

# This script installs and configures the Google Takeout Archive Processor.
# It sets up directories, installs dependencies, and prepares for execution.

# ==============================================================================
# --- Configuration ---

# Define the base directory where Google Drive is mounted
BASE_DIR="/mnt/gdrive/TakeoutProject"

# Define directories relative to the base directory
SOURCE_ARCHIVES_DIR="${BASE_DIR}/00-ALL-ARCHIVES/"
PROCESSING_STAGING_DIR="${BASE_DIR}/01-PROCESSING-STAGING/"
ORGANIZED_DIR="${BASE_DIR}/03-organized/My-Photos/"
TRASH_DIR="${BASE_DIR}/04-trash/"
COMPLETED_ARCHIVES_DIR="${BASE_DIR}/05-COMPLETED-ARCHIVES/"
QUARANTINE_DIR="${TRASH_DIR}/quarantined_artifacts/"
DUPES_DIR="${TRASH_DIR}/duplicates/"

# Define local temporary directories on the Raspberry Pi
VM_TEMP_EXTRACT_DIR='/tmp/temp_extract'
VM_TEMP_BATCH_DIR='/tmp/temp_batch_creation'

# Define the database path
DB_PATH="${BASE_DIR}/takeout_archive.db"

# Define the path for the service account credentials
SERVICE_ACCOUNT_FILE="${HOME}/.secrets/credentials.json"

# ==============================================================================

# ==============================================================================
# --- Dependency Installation ---

# Update package lists and install dependencies
echo "Updating package lists and installing dependencies..."
sudo apt-get update -qq
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to update apt package lists." >&2
    exit 1
fi

# Check for and install jdupes
if ! command -v jdupes &> /dev/null
then
    echo "jdupes not found. Attempting to install..."
    sudo apt-get install jdupes -qq -y
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to install jdupes." >&2
        exit 1
    fi
    echo "jdupes installed successfully."
else
    echo "jdupes already installed."
fi

# Check for and install rclone
if ! command -v rclone &> /dev/null
then
    echo "rclone not found. Attempting to install..."
    # Use the official rclone installation script for the latest version
    curl https://rclone.org/install.sh | sudo bash
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to install rclone." >&2
        exit 1
    fi
    echo "rclone installed successfully."
else
    echo "rclone already installed."
fi

echo "Dependency installation complete."

# ==============================================================================

# ==============================================================================
# --- Google Drive Mount Check ---

# Check if Google Drive is mounted at /mnt/gdrive
echo "Checking for Google Drive mount at /mnt/gdrive..."
if ! mountpoint -q /mnt/gdrive;
then
    echo "
"
    echo "======================================================================"
    echo "ERROR: Google Drive is NOT mounted at /mnt/gdrive."
    echo "
"
    echo "Please ensure your Google Drive is mounted at this location."
    echo "If you are using rclone and fuse, a typical command might look like:"
    echo "  rclone mount my-google-drive: /mnt/gdrive --allow-other --daemon"
    echo "
"
    echo "Replace 'my-google-drive:' with the name of your rclone Google Drive remote."
    Consult the rclone documentation for detailed setup instructions:"
    echo "  https://rclone.org/googlephotos/"
    echo "  https://rclone.org/commands/rclone_mount/"
    echo "======================================================================"
    echo "
"
    exit 1
else
    echo "✅ Google Drive is mounted at /mnt/gdrive."
fi

# ==============================================================================

# ==============================================================================
# --- Directory Setup ---

# Create necessary directories
echo "Setting up directories..."
mkdir -p "${SOURCE_ARCHIVES_DIR}"
if [ $? -ne 0 ]; then echo "ERROR: Failed to create directory ${SOURCE_ARCHIVES_DIR}." >&2; exit 1; fi
mkdir -p "${PROCESSING_STAGING_DIR}"
if [ $? -ne 0 ]; then echo "ERROR: Failed to create directory ${PROCESSING_STAGING_DIR}." >&2; exit 1; fi
mkdir -p "${ORGANIZED_DIR}"
if [ $? -ne 0 ]; then echo "ERROR: Failed to create directory ${ORGANIZED_DIR}." >&2; exit 1; fi
mkdir -p "${TRASH_DIR}"
if [ $? -ne 0 ]; then echo "ERROR: Failed to create directory ${TRASH_DIR}." >&2; exit 1; fi
mkdir -p "${COMPLETED_ARCHIVES_DIR}"
if [ $? -ne 0 ]; then echo "ERROR: Failed to create directory ${COMPLETED_ARCHIVES_DIR}." >&2; exit 1; fi
mkdir -p "${QUARANTINE_DIR}"
if [ $? -ne 0 ]; then echo "ERROR: Failed to create directory ${QUARANTINE_DIR}." >&2; exit 1; fi
mkdir -p "${DUPES_DIR}"
if [ $? -ne 0 ]; then echo "ERROR: Failed to create directory ${DUPES_DIR}." >&2; exit 1; fi

# Create the directory for service account credentials if it doesn't exist
mkdir -p "$(dirname "${SERVICE_ACCOUNT_FILE}")"
if [ $? -ne 0 ]; then echo "ERROR: Failed to create secrets directory." >&2; exit 1; fi

echo "Directory setup complete."

# ==============================================================================

# ==============================================================================
# --- Embed Python Script ---

# Write the Python script to a file
cat <<'EOF' > takeout_processor.py
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
# TARGET_MAX_VM_USAGE_GB = 70 # Not directly applicable to Raspberry Pi filesystem
REPACKAGE_CHUNK_SIZE_GB = 15
MAX_SAFE_ARCHIVE_SIZE_GB = 25

# Define the base directory for the Raspberry Pi environment
# Assuming Google Drive is mounted to /mnt/gdrive using rclone, fuse, or similar
BASE_DIR = "/mnt/gdrive/TakeoutProject"
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

# Use local temporary directories on the Raspberry Pi
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
    for filename in os.listdir(source_dir):
        file_path = os.path.join(source_dir, filename)
        if os.path.isfile(file_path) and os.path.getsize(file_path) == 0:
            print(f"    ⚠️ Found 0-byte artifact: '{filename}'. Quarantining...")
            shutil.move(file_path, os.path.join(CONFIG["QUARANTINE_DIR"], filename))
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
                print(f"    --> Batch contains {files_in_this_batch} unique files. Moving final part {part_number} to Google Drive...")
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
                if member.name not in completed_files:
                    tf.extract(member, path=VM_TEMP_EXTRACT_DIR, set_attrs=False)
                    files_to_process.append(member.name)

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
    """Deduplicates new files against the primary storage and updates the database for unique files."""
    print("\n--> [Step 2b] Deduplicating new files...")
    # Check if jdupes is available. If not, print a warning and skip.
    if not shutil.which('jdupes'):
        print("    ⚠️ 'jdupes' not found. Skipping.")
        return

    # Use jdupes for deduplication. This command links hard, moves duplicates to trash.
    command = f'jdupes -r -S -nh --linkhard --move="{trash_path}" "{source_path}" "{primary_storage_path}"'
    subprocess.run(command, shell=True, capture_output=True)

    cursor = conn.cursor()
    files_moved = 0
    # The actual uncompressed data is often in a "Takeout" subdirectory.
    takeout_source = os.path.join(source_path, "Takeout")
    if os.path.exists(takeout_source):
        print("    > Moving unique new files and updating database...")
        for root, _, files in os.walk(takeout_source):
            for filename in files:
                # This loop now handles all non-photo unique files left after jdupes.
                unique_file_path = os.path.join(root, filename)
                relative_path = os.path.relpath(unique_file_path, takeout_source)
                final_path = os.path.join(primary_storage_path, relative_path)

                # Create the directory structure if it doesn't exist
                os.makedirs(os.path.dirname(final_path), exist_ok=True)
                shutil.move(unique_file_path, final_path)

                # We need the original path relative to the TAR root, not the temp dir root.
                original_path = os.path.relpath(unique_file_path, source_path)
                cursor.execute("UPDATE files SET final_path = ?, timestamp = ? WHERE original_path = ? AND source_archive = ?",
                               (final_path, int(ts), original_path, source_archive_name))

                existing_filenames.add(new_filename)
                photos_organized_count += 1
        except Exception:
            continue

    if photos_organized_count > 0:
        conn.commit()
        print(f"    ✅ Organized and updated DB for {photos_organized_count} new files.")

# ==============================================================================
# --- MAIN EXECUTION SCRIPT ---
# ==============================================================================
def main(args):
    conn = None
    try:
        print("--> [Step 0] Initializing environment...")
        try:
            # Use regular tqdm for terminal output on Raspberry Pi
            from tqdm import tqdm
        except ImportError:
            tqdm = dummy_tqdm

        # Removed Colab-specific drive mounting
        # from google.colab import drive
        # if not os.path.exists('/content/drive/MyDrive'): drive.mount('/content/drive')
        # else: print("✅ Google Drive already mounted.")
        print("Assuming Google Drive is already mounted at /mnt/gdrive")

        # Set the GOOGLE_APPLICATION_CREDENTIALS environment variable
        # This is needed for rclone to authenticate with the Google service account
        service_account_file = os.path.expanduser("~/.secrets/credentials.json")
        if os.path.exists(service_account_file):
            os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = service_account_file
            print(f"✅ Set GOOGLE_APPLICATION_CREDENTIALS to {service_account_file}")
        else:
            print(f"⚠️ Service account credentials file not found at {service_account_file}. Rclone may not authenticate correctly.")


        for path in CONFIG.values():
            os.makedirs(path, exist_ok=True)


        conn = initialize_database(DB_PATH)
        perform_startup_integrity_check()

        # Removed Colab-specific disk usage check
        # total_vm, used_vm, free_vm = shutil.disk_usage('/content/')
        # used_vm_gb = used_vm / (1024**3)
        # if used_vm_gb > TARGET_MAX_VM_USAGE_GB:
        #     print(f"
❌ PRE-FLIGHT CHECK FAILED: Initial disk usage ({used_vm_gb:.2f} GB) is too high.")
        #     print("    >>> PLEASE RESTART THE COLAB RUNTIME (Runtime -> Restart runtime) AND TRY AGAIN. <<<")
        #     return
        # print(f"✅ Pre-flight disk check passed. (Initial Usage: {used_vm_gb:.2f} GB)")
        print("✅ Skipping VM disk usage check for Raspberry Pi.")

        # Install jdupes and rclone if not found - Handled by the bash script now
        # if not shutil.which('jdupes'):
        #     print("    > jdupes not found. Attempting to install...")
        #     try:
        #         subprocess.run("sudo apt-get update -qq && sudo apt-get install jdupes -qq -y", shell=True, check=True)
        #         print("    ✅ jdupes installed successfully.")
        #     except subprocess.CalledProcessError:
        #         print("    ❌ Failed to install jdupes. Deduplication will be skipped.")
        # else:
        #      print("✅ jdupes already installed.")

        print("✅ Workspace ready.")

        # Main processing loop for continuous operation
        while True:
            print("
--> [Step 1] Identifying unprocessed archives...")
            # Ensure the source directory exists before listing
            if not os.path.exists(CONFIG["SOURCE_ARCHIVES_DIR"]):
                 print(f"⚠️ Source archives directory not found: {CONFIG['SOURCE_ARCHIVES_DIR']}. Waiting 300 seconds.")
                 time.sleep(300)
                 continue

            all_archives = set(os.listdir(CONFIG["SOURCE_ARCHIVES_DIR"]))
            completed_archives = set(os.listdir(CONFIG["COMPLETED_ARCHIVES_DIR"]))
            processing_queue = sorted(list(all_archives - completed_archives))

            if not processing_queue:
                print("
✅🎉 All archives have been processed!")
                print("Idling for 300 seconds...")
                time.sleep(300) # Idle for 300 seconds before checking again
                continue # Go back to the start of the while loop
            else:
                archive_name = processing_queue[0]
                source_path = os.path.join(CONFIG["SOURCE_ARCHIVES_DIR"], archive_name)
                staging_path = os.path.join(CONFIG["PROCESSING_STAGING_DIR"], archive_name)

                if not os.path.exists(source_path):
                    print(f"⚠️ Source archive disappeared during check: {archive_name}. Skipping.")
                    continue

                print(f"--> Locking and staging '{archive_name}' for processing...")
                try:
                    shutil.move(source_path, staging_path)
                except FileNotFoundError:
                     print(f"⚠️ Source archive disappeared during move: {archive_name}. Skipping.")
                     continue


                if os.path.getsize(staging_path) / (1024**3) > MAX_SAFE_ARCHIVE_SIZE_GB and '.part-' not in archive_name:
                    repackaging_ok = plan_and_repackage_archive(staging_path, CONFIG["SOURCE_ARCHIVES_DIR"], conn, tqdm)
                    if repackaging_ok:
                        shutil.move(staging_path, os.path.join(CONFIG["COMPLETED_ARCHIVES_DIR"], archive_name))
                    else:
                         print(f"    ❌ Repackaging failed for '{archive_name}'. It will be rolled back on the next run.")
                         # Rollback the staged file to source
                         if os.path.exists(staging_path):
                            shutil.move(staging_path, source_path)
                else:
                    processed_ok = process_regular_archive(staging_path, conn, tqdm)
                    if processed_ok:
                        shutil.move(staging_path, os.path.join(CONFIG["COMPLETED_ARCHIVES_DIR"], archive_name))
                    else:
                        print(f"    ❌ Transaction failed for '{archive_name}'. It will be rolled back on the next run.")
                        # Rollback the staged file to source
                        if os.path.exists(staging_path):
                             shutil.move(staging_path, source_path)


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

# The if __name__ == "__main__": block and argparse are handled by the bash script
# if __name__ == '__main__':
#     parser = argparse.ArgumentParser(description="Process Google Takeout archives.")
#     parser.add_argument('--auto-delete-artifacts', action='store_true', help="Enable automatic deletion of 0-byte artifact files.")
#     try:
#         args = parser.parse_args([])
#     except SystemExit:
#         # This block handles interactive environments like Colab where args might not be passed
#         # In a script executed from the command line, this won't be triggered.
#         # We can simply parse the arguments directly in a script.
#         args = parser.parse_args() # Re-parse using sys.argv if needed for command line
#     main(args)

EOF

echo "Embedded Python script created as takeout_processor.py."
# ==============================================================================

# ==============================================================================
# --- Execute Python Script ---
# ==============================================================================

# ==============================================================================
# --- Systemd Service Setup ---

echo "Setting up systemd service..."

# Create the service installation directory if it doesn't exist
sudo mkdir -p /opt/takeout_processor/
if [ $? -ne 0 ]; then echo "ERROR: Failed to create /opt/takeout_processor directory." >&2; exit 1; fi

# Move the Python script to the installation directory
sudo mv takeout_processor.py /opt/takeout_processor/
if [ $? -ne 0 ]; then echo "ERROR: Failed to move takeout_processor.py to /opt/takeout_processor." >&2; exit 1; fi

# Create the systemd service file
echo "Writing systemd service file to /etc/systemd/system/takeout_processor.service..."
sudo cat <<'EOF_SERVICE' > /etc/systemd/system/takeout_processor.service
[Unit]
Description=Google Takeout Archive Processor
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/takeout_processor/takeout_processor.py
WorkingDirectory=/opt/takeout_processor/
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=takeout_processor
Restart=always
User=pi # Replace 'pi' with your desired non-root user

[Install]
WantedBy=multi-user.target
EOF_SERVICE
if [ $? -ne 0 ]; then echo "ERROR: Failed to create systemd service file." >&2; exit 1; fi

# Reload the systemd daemon
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload
if [ $? -ne 0 ]; then echo "ERROR: Failed to reload systemd daemon." >&2; exit 1; fi

# Enable the service to start on boot
echo "Enabling takeout_processor.service..."
sudo systemctl enable takeout_processor.service
if [ $? -ne 0 ]; then echo "ERROR: Failed to enable systemd service." >&2; exit 1; fi

# Start the service immediately
echo "Starting takeout_processor.service..."
sudo systemctl start takeout_processor.service
if [ $? -ne 0 ]; then echo "ERROR: Failed to start systemd service." >&2; exit 1; fi

echo "Systemd service setup complete."

# ==============================================================================
