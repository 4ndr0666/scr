#!/bin/bash
#
# DietPi First-Boot Custom Script for Takeout Processor Appliance (v6.0 - The Final Port)
# This version is a direct, faithful port of the user's working Colab script,
# using the PyDrive2 library and a robust systemd timer for transactional execution.

set -euo pipefail

# --- Configuration ---
INSTALL_DIR="/opt/google_takeout_organizer"
CREDENTIALS_FILE="client_secrets.json" # PyDrive2 uses this by default
CREDENTIALS_PATH="${INSTALL_DIR}/${CREDENTIALS_FILE}"

PROCESSOR_FILENAME="google_takeout_organizer.py"
PROCESSOR_SCRIPT_PATH="${INSTALL_DIR}/${PROCESSOR_FILENAME}"
PROCESSOR_SERVICE_NAME="takeout-organizer.service"
PROCESSOR_SERVICE_PATH="/etc/systemd/system/${PROCESSOR_SERVICE_NAME}"
PROCESSOR_TIMER_NAME="takeout-organizer.timer"
PROCESSOR_TIMER_PATH="/etc/systemd/system/${PROCESSOR_TIMER_NAME}"

# --- Logging Utilities ---
_log_info() { printf "\n[INFO] %s\n" "$*"; }
_log_ok()   { printf "✅ %s\n" "$*"; }
_log_warn() { printf "⚠️  %s\n" "$*"; }
_log_fail() { printf "❌ ERROR: %s\n" "$*"; exit 1; }

# ==============================================================================
# --- Main Installation Logic ---
# ==============================================================================
main() {
    _log_info "--- Starting Takeout Processor Appliance Setup (v6.0 Final Port) ---"
    if [[ $EUID -ne 0 ]]; then _log_fail "This script must be run as root."; fi

    _log_info "Ensuring any old services are stopped and removed..."
    systemctl stop ${PROCESSOR_SERVICE_NAME} &>/dev/null || true
    systemctl stop ${PROCESSOR_TIMER_NAME} &>/dev/null || true
    systemctl disable ${PROCESSOR_SERVICE_NAME} &>/dev/null || true
    systemctl disable ${PROCESSOR_TIMER_NAME} &>/dev/null || true
    # Clean up all old/failed service files
    rm -f /etc/systemd/system/gdrive-mount.service ${PROCESSOR_SERVICE_PATH} ${PROCESSOR_TIMER_PATH}
    _log_ok "Old services cleaned up."

    _log_info "Updating package lists and installing dependencies..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null
    apt-get install -y python3 python3-pip jdupes >/dev/null
    pip3 install --upgrade PyDrive2 tqdm >/dev/null
    _log_ok "Dependencies installed (PyDrive2, tqdm)."

    _log_info "Creating installation directory..."
    mkdir -p "${INSTALL_DIR}"
    _log_ok "Directory created: ${INSTALL_DIR}"

    _log_info "Checking for credentials file..."
    if [[ ! -f "${CREDENTIALS_PATH}" ]]; then
        _log_warn "ACTION REQUIRED: Place your '${CREDENTIALS_FILE}' in '${INSTALL_DIR}'."
        _log_warn "The service will fail to authenticate until this file is present."
    else
        chmod 600 "${CREDENTIALS_PATH}"
    fi

    _log_info "Deploying the Python processor script..."
    cat <<'EOF' > "${PROCESSOR_SCRIPT_PATH}"
#!/usr/bin/env python3
#
# Google Takeout Organizer (v6.0 - Faithful Port)
# A direct port of the working Colab v4.1.1, adapted for headless operation using PyDrive2.
# This script runs once, processes one archive, and then exits, to be run by a systemd timer.

import os, shutil, subprocess, tarfile, json, traceback, re, sys, argparse, sqlite3, hashlib, logging
from datetime import datetime

try:
    from tqdm import tqdm
except ImportError:
    def tqdm(iterable, *args, **kwargs):
        logging.info(f"    > Processing {kwargs.get('desc', 'items')}...")
        return iterable

from pydrive2.auth import GoogleAuth
from pydrive2.drive import GoogleDrive

# ==============================================================================
# --- 1. CORE CONFIGURATION & LOGGING ---
# ==============================================================================
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s", handlers=[logging.StreamHandler(sys.stdout)])
logger = logging.getLogger(__name__)

INSTALL_DIR = "/opt/google_takeout_organizer"
DB_PATH = os.path.join(INSTALL_DIR, "takeout_archive.db")
CONFIG = {} # Stores Google Drive Folder IDs

VM_TEMP_EXTRACT_DIR = '/tmp/temp_extract'
VM_TEMP_BATCH_DIR = '/tmp/temp_batch_creation'
VM_TEMP_DOWNLOAD_DIR = '/tmp/temp_download'

MAX_SAFE_ARCHIVE_SIZE_GB = 25

# ==============================================================================
# --- 2. GOOGLE DRIVE & WORKFLOW HELPERS ---
# ==============================================================================
def authenticate_drive():
    logger.info("--> [Auth] Authenticating with Google Drive...")
    gauth = GoogleAuth()
    service_account_file = os.path.join(INSTALL_DIR, "client_secrets.json")
    if not os.path.exists(service_account_file):
        raise FileNotFoundError(f"CRITICAL: Service account credentials not found at {service_account_file}")

    gauth.settings['client_config_file'] = service_account_file
    gauth.ServiceAuth()
    drive = GoogleDrive(gauth)
    logger.info("    ✅ Authentication successful.")
    return drive

def find_or_create_folder(drive, parent_id, folder_name):
    query = f"'{parent_id}' in parents and title = '{folder_name}' and trashed = false and mimeType = 'application/vnd.google-apps.folder'"
    file_list = drive.ListFile({'q': query}).GetList()
    if file_list:
        return file_list[0]['id']
    else:
        logger.info(f"    > Creating folder '{folder_name}'...")
        folder_meta = {'title': folder_name, 'parents': [{'id': parent_id}], 'mimeType': 'application/vnd.google-apps.folder'}
        folder = drive.CreateFile(folder_meta)
        folder.Upload()
        return folder['id']

def setup_drive_folders(drive):
    logger.info("--> [Drive] Setting up folder structure...")
    root_id = find_or_create_folder(drive, 'root', 'TakeoutProject')
    CONFIG["SOURCE_ARCHIVES_DIR_ID"] = find_or_create_folder(drive, root_id, "00-ALL-ARCHIVES")
    CONFIG["PROCESSING_STAGING_DIR_ID"] = find_or_create_folder(drive, root_id, "01-PROCESSING-STAGING")
    organized_id = find_or_create_folder(drive, root_id, "03-organized")
    CONFIG["ORGANIZED_PHOTOS_DIR_ID"] = find_or_create_folder(drive, organized_id, "My-Photos")
    CONFIG["ORGANIZED_FILES_DIR_ID"] = find_or_create_folder(drive, organized_id, "My-Files") # For non-photo files
    trash_id = find_or_create_folder(drive, root_id, "04-trash")
    CONFIG["QUARANTINE_DIR_ID"] = find_or_create_folder(drive, trash_id, "quarantined_artifacts")
    CONFIG["DUPES_DIR_ID"] = find_or_create_folder(drive, trash_id, "duplicates")
    CONFIG["COMPLETED_ARCHIVES_DIR_ID"] = find_or_create_folder(drive, root_id, "05-COMPLETED-ARCHIVES")
    logger.info("    ✅ Folder structure synchronized.")

def initialize_database(db_path):
    logger.info("--> [DB] Initializing database...")
    conn = sqlite3.connect(db_path, timeout=30)
    conn.execute('''
    CREATE TABLE IF NOT EXISTS files (
        sha256_hash TEXT PRIMARY KEY,
        source_archive TEXT NOT NULL
    )''')
    conn.commit()
    logger.info("    ✅ Database ready.")
    return conn

def get_known_hashes(conn):
    return {row[0] for row in conn.execute("SELECT sha256_hash FROM files")}

def process_archive(drive, archive_obj, conn):
    archive_name = archive_obj['title']
    logger.info(f"--> [Step 2a] Processing transaction for '{archive_name}'...")

    os.makedirs(VM_TEMP_DOWNLOAD_DIR, exist_ok=True)
    local_archive_path = os.path.join(VM_TEMP_DOWNLOAD_DIR, archive_name)

    try:
        logger.info(f"    > Downloading '{archive_name}'...")
        archive_obj.GetContentFile(local_archive_path)

        if VM_TEMP_EXTRACT_DIR.exists(): shutil.rmtree(VM_TEMP_EXTRACT_DIR)
        VM_TEMP_EXTRACT_DIR.mkdir()

        logger.info(f"    > Extracting '{archive_name}'...")
        with tarfile.open(local_archive_path, 'r:gz') as tf:
            tf.extractall(path=VM_TEMP_EXTRACT_DIR)

        organize_photos(drive, VM_TEMP_EXTRACT_DIR, conn, archive_name)
        deduplicate_files(drive, VM_TEMP_EXTRACT_DIR, conn, archive_name)

        return True
    except Exception as e:
        logger.error(f"\n❌ ERROR during archive processing: {e}")
        traceback.print_exc()
        return False
    finally:
        shutil.rmtree(VM_TEMP_DOWNLOAD_DIR, ignore_errors=True)
        shutil.rmtree(VM_TEMP_EXTRACT_DIR, ignore_errors=True)

def organize_photos(drive, source_path, conn, archive_name):
    logger.info("\n--> [Step 2c] Organizing photos...")
    photos_source = os.path.join(source_path, "Takeout", "Google Photos")
    if not os.path.isdir(photos_source): return

    known_hashes = get_known_hashes(conn)
    new_files_to_db = []

    for root, _, files in os.walk(photos_source):
        for filename in tqdm(files, desc="Organizing Photos"):
            if filename.lower().endswith('.json'): continue
            media_path = os.path.join(root, filename)

            with open(media_path, 'rb') as f: sha256 = hashlib.sha256(f.read()).hexdigest()
            if sha256 in known_hashes: continue

            json_path = os.path.splitext(media_path)[0] + '.json'
            ts = int(os.path.getmtime(media_path))
            if os.path.exists(json_path):
                try:
                    with open(json_path, 'r', encoding='utf-8') as f: data = json.load(f)
                    ts = int(data.get('photoTakenTime', {}).get('timestamp', ts))
                except: pass

            new_name = f"{datetime.fromtimestamp(ts).strftime('%Y-%m-%d_%Hh%Mm%Ss')}_{filename}"

            file_drive = drive.CreateFile({'title': new_name, 'parents': [{'id': CONFIG['ORGANIZED_PHOTOS_DIR_ID']}]})
            file_drive.SetContentFile(media_path)
            file_drive.Upload()

            new_files_to_db.append((sha256, archive_name))
            known_hashes.add(sha256)

    if new_files_to_db:
        conn.executemany("INSERT OR IGNORE INTO files (sha256_hash, source_archive) VALUES (?, ?)", new_files_to_db)
        conn.commit()
    logger.info(f"    ✅ Processed and uploaded {len(new_files_to_db)} unique photos.")

def deduplicate_files(drive, source_path, conn, archive_name):
    logger.info("\n--> [Step 2b] Deduplicating other files...")
    takeout_source = os.path.join(source_path, "Takeout")
    if not os.path.isdir(takeout_source): return

    known_hashes = get_known_hashes(conn)
    new_files_to_db = []

    for root, _, files in os.walk(takeout_source):
        if "Google Photos" in root: continue
        for filename in tqdm(files, desc="Deduplicating Files"):
            file_path = os.path.join(root, filename)

            with open(file_path, 'rb') as f: sha256 = hashlib.sha256(f.read()).hexdigest()
            if sha256 in known_hashes:
                # In this model, we just discard duplicates, not upload them to a dupes folder
                continue

            # This file is unique
            file_drive = drive.CreateFile({'title': filename, 'parents': [{'id': CONFIG['ORGANIZED_FILES_DIR_ID']}]})
            file_drive.SetContentFile(file_path)
            file_drive.Upload()

            new_files_to_db.append((sha256, archive_name))
            known_hashes.add(sha256)

    if new_files_to_db:
        conn.executemany("INSERT OR IGNORE INTO files (sha256_hash, source_archive) VALUES (?, ?)", new_files_to_db)
        conn.commit()
    logger.info(f"    ✅ Processed and uploaded {len(new_files_to_db)} unique other files.")

# ==============================================================================
# --- MAIN EXECUTION SCRIPT ---
# ==============================================================================
def main():
    conn = None
    drive = None
    archive_obj_in_staging = None
    try:
        logger.info("--- Starting Takeout Processor Run ---")
        drive = authenticate_drive()
        setup_drive_folders(drive)
        conn = initialize_database(DB_PATH)

        source_files = drive.ListFile({'q': f"'{CONFIG['SOURCE_ARCHIVES_DIR_ID']}' in parents and trashed=false"}).GetList()
        if not source_files:
            logger.info("✅ No archives to process. Exiting.")
            return

        archive_obj = source_files[0]
        archive_name = archive_obj['title']

        logger.info(f"--> [Step 1] Staging '{archive_name}' for processing...")
        archive_obj['parents'] = [{'id': CONFIG['PROCESSING_STAGING_DIR_ID']}]
        archive_obj.Upload()
        archive_obj_in_staging = archive_obj # For rollback purposes

        processed_ok = process_archive(drive, archive_obj, conn)

        if processed_ok:
            logger.info(f"--> [Step 4] Finalizing '{archive_name}'...")
            archive_obj['parents'] = [{'id': CONFIG['COMPLETED_ARCHIVES_DIR_ID']}]
            archive_obj.Upload()
            logger.info("    ✅ Transaction complete.")
        else:
            raise Exception("Processing function returned failure")

    except Exception as e:
        logger.critical(f"❌ A CRITICAL ERROR OCCURRED: {e}")
        traceback.print_exc()
        if drive and archive_obj_in_staging:
            try:
                logger.warning(f"Attempting to roll back '{archive_obj_in_staging['title']}'...")
                archive_obj_in_staging['parents'] = [{'id': CONFIG['SOURCE_ARCHIVES_DIR_ID']}]
                archive_obj_in_staging.Upload()
                logger.info("    ✅ Rollback successful.")
            except Exception as rollback_e:
                logger.critical(f"    ‼️ CRITICAL: ROLLBACK FAILED: {rollback_e}")
    finally:
        if conn:
            conn.close()
        for temp_dir in [VM_TEMP_DOWNLOAD_DIR, VM_TEMP_EXTRACT_DIR, VM_TEMP_BATCH_DIR]:
            shutil.rmtree(temp_dir, ignore_errors=True)
        logger.info("--- Takeout Processor Run Finished ---")

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.parse_known_args()
    main()
EOF
    # --- END EMBEDDED PYTHON SCRIPT ---

    chmod +x "${PROCESSOR_SCRIPT_PATH}"
    _log_ok "Python script deployed."

    _log_info "Creating systemd service and timer..."

    # --- SYSTEMD SERVICE FILE (runs the script once) ---
    cat <<EOF > "${PROCESSOR_SERVICE_PATH}"
[Unit]
Description=Google Takeout Organizer (One-Shot Service)
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/python3 ${PROCESSOR_SCRIPT_PATH}
WorkingDirectory=${INSTALL_DIR}
User=root

[Install]
WantedBy=multi-user.target
EOF

    # --- SYSTEMD TIMER FILE (runs the service every 15 minutes) ---
    cat <<EOF > "${PROCESSOR_TIMER_PATH}"
[Unit]
Description=Run Takeout Organizer every 15 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=15min
Unit=${PROCESSOR_SERVICE_NAME}

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable ${PROCESSOR_TIMER_NAME}
    systemctl start ${PROCESSOR_TIMER_NAME}
    _log_ok "Systemd timer enabled and started. Service will run periodically."

    echo ""
    _log_ok "--------------------------------------------------------"
    _log_ok "Takeout Processor Appliance Setup is COMPLETE!"
    _log_warn "ACTION REQUIRED: Place 'client_secrets.json' in '${INSTALL_DIR}'."
    _log_info "The script will run automatically. To trigger a run now:"
    _log_info "  systemctl start ${PROCESSOR_SERVICE_NAME}"
    _log_info "To monitor, run: journalctl -fu ${PROCESSOR_SERVICE_NAME}"
    _log_info "To check the timer status: systemctl list-timers"
    _log_ok "--------------------------------------------------------"
}

main "$@"
