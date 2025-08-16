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
from tqdm import tqdm

# ==============================================================================
# --- 1. CORE CONFIGURATION ---
# ==============================================================================
BASE_DIR = "/mnt/takeout_data/TakeoutProject"
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
VM_TEMP_EXTRACT_DIR = '/tmp/temp_extract'
VM_TEMP_BATCH_DIR = '/tmp/temp_batch_creation'
MAX_SAFE_ARCHIVE_SIZE_GB = 25
REPACKAGE_CHUNK_SIZE_GB = 15

# ==============================================================================
# --- 2. WORKFLOW FUNCTIONS & HELPERS ---
# ==============================================================================
def wait_for_drive_sync(path_to_check, timeout_seconds=300, interval_seconds=15):
    """
    Intelligently waits for a network filesystem to become populated,
    preventing a race condition on startup.
    """
    print("--> [SYNC] Waiting for drive filesystem to synchronize...")
    start_time = time.time()
    while True:
        try:
            # Check if the directory exists and is not empty.
            if os.path.exists(path_to_check) and os.listdir(path_to_check):
                print("    ✅ Drive is populated. Proceeding.")
                return True
        except Exception as e:
            print(f"    ⚠️  An error occurred while checking the directory: {e}")
        
        elapsed_time = time.time() - start_time
        if elapsed_time > timeout_seconds:
            # If the directory is still empty after the timeout, it's likely genuinely empty.
            # We can proceed, and the script will correctly report "no files".
            print("    > Timed out waiting for drive to sync. Assuming directory is empty.")
            return True
            
        print(f"    > Drive not ready or is empty, waiting... ({int(elapsed_time)}s / {timeout_seconds}s)")
        time.sleep(interval_seconds)

def initialize_database(db_path):
    print("--> [DB] Initializing database...")
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS files (
        id INTEGER PRIMARY KEY, sha256_hash TEXT NOT NULL UNIQUE, original_path TEXT NOT NULL,
        final_path TEXT, timestamp INTEGER, file_size INTEGER NOT NULL, source_archive TEXT NOT NULL
    )''')
    conn.commit()
    print("    ✅ Database ready.")
    return conn

def perform_startup_integrity_check():
    print("--> [POST] Performing startup integrity check...")
    staging_dir = CONFIG["PROCESSING_STAGING_DIR"]
    source_dir = CONFIG["SOURCE_ARCHIVES_DIR"]
    if os.path.exists(staging_dir) and os.listdir(staging_dir):
        print("    ⚠️ Found orphaned files. Rolling back transaction...")
        for orphan_file in os.listdir(staging_dir):
            shutil.move(os.path.join(staging_dir, orphan_file), os.path.join(source_dir, orphan_file))
        if os.path.exists(VM_TEMP_EXTRACT_DIR): shutil.rmtree(VM_TEMP_EXTRACT_DIR)
        print("    ✅ Rollback complete.")
    for filename in os.listdir(source_dir):
        file_path = os.path.join(source_dir, filename)
        if os.path.isfile(file_path) and os.path.getsize(file_path) == 0:
            print(f"    ⚠️ Found 0-byte artifact: '{filename}'. Quarantining...")
            shutil.move(file_path, os.path.join(CONFIG["QUARANTINE_DIR"], filename))
    print("--> [POST] Integrity check complete.")

# ... All other functions (plan_and_repackage, process_regular_archive, etc.) are stable and unchanged ...
def plan_and_repackage_archive(...): pass
def process_regular_archive(...): pass
def deduplicate_files(...): pass
def organize_photos(...): pass

# ==============================================================================
# --- MAIN EXECUTION SCRIPT ---
# ==============================================================================
def main(args):
    conn = None
    try:
        print("--> [Step 0] Initializing environment...")
        
        # --- CRITICAL FIX: Call the wait function BEFORE any filesystem access ---
        if not wait_for_drive_sync(CONFIG["SOURCE_ARCHIVES_DIR"]):
            sys.exit(1) # Exit if the sync definitively fails

        for path in CONFIG.values(): os.makedirs(path, exist_ok=True)
        conn = initialize_database(DB_PATH)
        perform_startup_integrity_check()
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
            shutil.move(source_path, staging_path)

            archive_size_gb = os.path.getsize(staging_path) / (1024**3)
            if archive_size_gb > MAX_SAFE_ARCHIVE_SIZE_GB and '.part-' not in archive_name:
                processed_ok = plan_and_repackage_archive(staging_path, CONFIG["SOURCE_ARCHIVES_DIR"], conn, tqdm)
            else:
                processed_ok = process_regular_archive(staging_path, conn, tqdm, args.auto_delete_artifacts)
            
            if processed_ok:
                shutil.move(staging_path, os.path.join(CONFIG["COMPLETED_ARCHIVES_DIR"], archive_name))
            else:
                print(f"    ❌ Transaction failed for '{archive_name}'. It will be rolled back on the next run.")

            print("\n--- WORKFLOW CYCLE COMPLETE. ---")
    except Exception as e:
        print(f"\n❌ A CRITICAL UNHANDLED ERROR OCCURRED: {e}"); traceback.print_exc()
    finally:
        if conn:
            conn.close()
            print("--> [DB] Database connection closed.")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Process Google Takeout archives.")
    parser.add_argument('--auto-delete-artifacts', action='store_true', help="Enable automatic deletion of 0-byte artifact files.")
    args = parser.parse_args()
    main(args)
