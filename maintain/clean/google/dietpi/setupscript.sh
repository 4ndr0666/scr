#!/bin/bash
#
# DietPi First-Boot Custom Script for Takeout Processor Appliance (v5.0 - Faithful Port)
# This version is a direct, faithful port of the working Colab script (v4.1.1).
# It assumes Google Drive is mounted at the target path by an external mechanism.

set -euo pipefail

# --- Configuration ---
INSTALL_DIR="/opt/google_takeout_organizer"
GDRIVE_MOUNT_POINT="/content/drive/MyDrive" # Prerequisite: This path must be mounted.

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
    # Clean up old rclone service if it exists
    systemctl stop gdrive-mount.service &>/dev/null || true
    systemctl disable gdrive-mount.service &>/dev/null || true
    rm -f /etc/systemd/system/gdrive-mount.service
    _log_ok "Services stopped and disabled."

    _log_info "Updating package lists and installing dependencies..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null
    apt-get install -y python3 jdupes sqlite3 python3-tqdm >/dev/null
    _log_ok "All dependencies are installed."

    _log_info "Creating directories..."
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$GDRIVE_MOUNT_POINT" # Ensure mount point exists
    _log_ok "Directories created."
    
    _log_info "Deploying the Takeout Processor script (Faithful Port)..."
    # --- BEGIN EMBEDDED PYTHON SCRIPT (v5.0) ---
    cat << 'EOF' > "$PROCESSOR_SCRIPT_PATH"
"""
Google Takeout Organizer (v5.0 - Faithful File System Port)
This script is a direct port of the working Colab v4.1.1. It assumes that
the Google Drive is already mounted at the specified BASE_DIR by an external
service (e.g., systemd mount, rclone service, etc.).
"""
import os, shutil, subprocess, tarfile, json, traceback, re, sys, argparse, sqlite3, hashlib, time, logging
from datetime import datetime
from pathlib import Path

try:
    from tqdm import tqdm
except ImportError:
    def tqdm(iterable, *args, **kwargs):
        logger.info(f"    > Processing {kwargs.get('desc', 'items')}...")
        return iterable

# ==============================================================================
# --- 1. CORE CONFIGURATION ---
# ==============================================================================
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s", handlers=[logging.StreamHandler(sys.stdout)])
logger = logging.getLogger(__name__)

BASE_DIR = Path("/content/drive/MyDrive/TakeoutProject")
DB_PATH = BASE_DIR / "takeout_archive.db"
CONFIG = {
    "SOURCE_ARCHIVES_DIR": BASE_DIR / "00-ALL-ARCHIVES",
    "PROCESSING_STAGING_DIR": BASE_DIR / "01-PROCESSING-STAGING",
    "ORGANIZED_PHOTOS_DIR": BASE_DIR / "03-organized/My-Photos",
    "ORGANIZED_FILES_DIR": BASE_DIR / "03-organized/My-Files",
    "TRASH_DIR": BASE_DIR / "04-trash",
    "COMPLETED_ARCHIVES_DIR": BASE_DIR / "05-COMPLETED-ARCHIVES",
}
CONFIG["QUARANTINE_DIR"] = CONFIG["TRASH_DIR"] / "quarantined_artifacts"
CONFIG["DUPES_DIR"] = CONFIG["TRASH_DIR"] / "duplicates"
VM_TEMP_EXTRACT_DIR = Path('/tmp/temp_extract')
PROCESSING_IDLE_SLEEP_SECONDS = 300
MAX_SAFE_ARCHIVE_SIZE_GB = 25

# ==============================================================================
# --- 2. WORKFLOW FUNCTIONS & HELPERS ---
# ==============================================================================
def initialize_database(db_path):
    logger.info("--> [DB] Initializing database...")
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.execute('''
    CREATE TABLE IF NOT EXISTS files (
        sha256_hash TEXT PRIMARY KEY,
        source_archive TEXT NOT NULL
    )''')
    conn.commit()
    logger.info("    ✅ Database ready.")
    return conn

def perform_startup_integrity_check():
    logger.info("--> [POST] Performing startup integrity check...")
    staging_dir = CONFIG["PROCESSING_STAGING_DIR"]
    source_dir = CONFIG["SOURCE_ARCHIVES_DIR"]
    if staging_dir.exists() and any(staging_dir.iterdir()):
        logger.warning(f"    ⚠️ Found {len(list(staging_dir.iterdir()))} orphaned file(s). Rolling back...")
        for orphan in staging_dir.iterdir():
            shutil.move(str(orphan), str(source_dir / orphan.name))
        logger.info("    ✅ Rollback complete.")
    else:
        logger.info("    ✅ No orphaned files found.")

def process_archive(archive_path, conn):
    archive_name = archive_path.name
    logger.info(f"\n--> [Step 2a] Processing transaction for '{archive_name}'...")
    try:
        if VM_TEMP_EXTRACT_DIR.exists(): shutil.rmtree(VM_TEMP_EXTRACT_DIR)
        VM_TEMP_EXTRACT_DIR.mkdir(parents=True)
        
        logger.info(f"    > Extracting '{archive_name}'...")
        with tarfile.open(archive_path, 'r:gz') as tf:
            tf.extractall(path=VM_TEMP_EXTRACT_DIR)

        organize_photos(VM_TEMP_EXTRACT_DIR, CONFIG["ORGANIZED_PHOTOS_DIR"], conn, archive_name)
        deduplicate_files(VM_TEMP_EXTRACT_DIR, CONFIG["ORGANIZED_FILES_DIR"], CONFIG["DUPES_DIR"], conn, archive_name)

        return True
    except Exception as e:
        logger.error(f"\n❌ ERROR during archive processing transaction: {e}")
        traceback.print_exc()
        return False
    finally:
        if VM_TEMP_EXTRACT_DIR.exists():
            shutil.rmtree(VM_TEMP_EXTRACT_DIR)

def deduplicate_files(source_path, primary_storage_path, trash_path, conn, source_archive_name):
    logger.info("\n--> [Step 2b] Deduplicating new general files...")
    takeout_source = source_path / "Takeout"
    if not takeout_source.exists(): return

    known_hashes = {row[0] for row in conn.execute("SELECT sha256_hash FROM files")}
    new_files_to_db = []
    
    for file_path in tqdm(list(takeout_source.rglob('*')), desc="Deduplicating files"):
        if file_path.is_dir() or "Google Photos" in file_path.parts: continue

        with open(file_path, 'rb') as f:
            sha256 = hashlib.sha256(f.read()).hexdigest()
        
        if sha256 in known_hashes:
            shutil.move(str(file_path), str(trash_path / file_path.name))
        else:
            relative_path = file_path.relative_to(takeout_source)
            final_path = primary_storage_path / relative_path
            final_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(file_path), str(final_path))
            new_files_to_db.append((sha256, source_archive_name))
            known_hashes.add(sha256)
    
    if new_files_to_db:
        conn.executemany("INSERT OR IGNORE INTO files (sha256_hash, source_archive) VALUES (?, ?)", new_files_to_db)
        conn.commit()
    logger.info(f"    ✅ Processed {len(new_files_to_db)} unique general files.")

def organize_photos(source_path, final_dir, conn, source_archive_name):
    logger.info("\n--> [Step 2c] Organizing photos...")
    photos_source_path = source_path / "Takeout" / "Google Photos"
    if not photos_source_path.is_dir():
        logger.info("    > 'Google Photos' directory not found. Skipping.")
        return

    known_hashes = {row[0] for row in conn.execute("SELECT sha256_hash FROM files")}
    new_files_to_db = []

    for media_path in tqdm(list(photos_source_path.rglob('*')), desc="Organizing photos"):
        if media_path.is_dir() or media_path.name.lower().endswith('.json'): continue
        
        with open(media_path, 'rb') as f:
            sha256 = hashlib.sha256(f.read()).hexdigest()
        if sha256 in known_hashes: continue

        json_path = media_path.with_suffix(media_path.suffix + '.json')
        if not json_path.exists(): json_path = media_path.with_suffix('.json')
        
        ts = int(media_path.stat().st_mtime)
        if json_path.exists():
            try:
                with open(json_path, 'r', encoding='utf-8') as f: data = json.load(f)
                ts = int(data.get('photoTakenTime', {}).get('timestamp', ts))
            except: pass

        dt = datetime.fromtimestamp(ts)
        new_name = f"{dt.strftime('%Y-%m-%d_%Hh%Mm%Ss')}_{media_path.name}"
        final_filepath = final_dir / new_name
        shutil.move(str(media_path), str(final_filepath))
        
        new_files_to_db.append((sha256, source_archive_name))
        known_hashes.add(sha256)

    if new_files_to_db:
        conn.executemany("INSERT OR IGNORE INTO files (sha256_hash, source_archive) VALUES (?, ?)", new_files_to_db)
        conn.commit()
    logger.info(f"    ✅ Processed {len(new_files_to_db)} unique photos.")

# ==============================================================================
# --- MAIN EXECUTION SCRIPT ---
# ==============================================================================
def main():
    conn = None
    try:
        logger.info("--> [Step 0] Initializing environment...")
        for path in CONFIG.values(): path.mkdir(parents=True, exist_ok=True)
        conn = initialize_database(DB_PATH)
        
        while True:
            try:
                if not BASE_DIR.exists() or not CONFIG["SOURCE_ARCHIVES_DIR"].exists():
                    logger.warning(f"Base directory '{BASE_DIR}' not found. Is drive mounted? Retrying in {PROCESSING_IDLE_SLEEP_SECONDS}s...")
                    time.sleep(PROCESSING_IDLE_SLEEP_SECONDS)
                    continue

                perform_startup_integrity_check()
                logger.info("✅ Workspace ready.")

                logger.info("\n--> [Step 1] Identifying unprocessed archives...")
                all_archives = {p.name for p in CONFIG["SOURCE_ARCHIVES_DIR"].iterdir() if p.is_file() and not p.name.startswith('.')}
                completed_archives = {p.name for p in CONFIG["COMPLETED_ARCHIVES_DIR"].iterdir() if p.is_file()}
                processing_queue = sorted(list(all_archives - completed_archives))

                if not processing_queue:
                    logger.info(f"✅🎉 No archives to process! Idling for {PROCESSING_IDLE_SLEEP_SECONDS}s...")
                    time.sleep(PROCESSING_IDLE_SLEEP_SECONDS)
                    continue

                archive_name = processing_queue[0]
                source_path = CONFIG["SOURCE_ARCHIVES_DIR"] / archive_name
                staging_path = CONFIG["PROCESSING_STAGING_DIR"] / archive_name

                logger.info(f"--> Locking and staging '{archive_name}' for processing...")
                shutil.move(str(source_path), str(staging_path))

                processed_ok = process_archive(staging_path, conn)
                
                if processed_ok:
                    shutil.move(str(staging_path), str(CONFIG["COMPLETED_ARCHIVES_DIR"] / archive_name))
                    logger.info(f"✅ Transaction for '{archive_name}' complete.")
                else:
                    logger.error(f"    ❌ Transaction failed for '{archive_name}'. Rolling back.")
                    shutil.move(str(staging_path), str(source_path))

                logger.info("\n--- WORKFLOW CYCLE COMPLETE ---")

            except Exception as loop_error:
                logger.error(f"An error occurred in the main loop: {loop_error}")
                traceback.print_exc()
                time.sleep(60)

    except Exception as e:
        logger.critical(f"\n❌ A CRITICAL STARTUP ERROR OCCURRED: {e}")
        traceback.print_exc()
    finally:
        if conn:
            conn.close()
            logger.info("--> [DB] Database connection closed.")

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.parse_known_args()
    main()
EOF
    # --- END EMBEDDED PYTHON SCRIPT ---

    chmod +x "$PROCESSOR_SCRIPT_PATH"
    _log_ok "Application script deployed successfully."
    
    _log_info "Creating and enabling the systemd service..."
    cat << EOF > "$PROCESSOR_SERVICE_PATH"
[Unit]
Description=Google Takeout Organizer Service (v5.0 - File System)
# This service should start after the network and any remote mounts are ready.
After=network-online.target remote-fs.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 ${PROCESSOR_SCRIPT_PATH}
Restart=on-failure
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "$PROCESSOR_SERVICE_NAME"
    _log_ok "Systemd service '${PROCESSOR_SERVICE_NAME}' created and enabled."

    echo ""
    _log_ok "--------------------------------------------------------"
    _log_ok "Takeout Processor Appliance Setup is COMPLETE!"
    _log_warn "ACTION REQUIRED: You MUST ensure that your Google Drive is mounted at"
    _log_warn "  '${GDRIVE_MOUNT_POINT}' for this service to work."
    _log_info "After ensuring the drive is mounted, reboot or run:"
    _log_info "  systemctl start ${PROCESSOR_SERVICE_NAME}"
    _log_info "To monitor, run: journalctl -fu ${PROCESSOR_SERVICE_NAME}"
    _log_ok "--------------------------------------------------------"
}

main
